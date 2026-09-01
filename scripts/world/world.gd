extends Node
## World authority layer (CC-06). Owns the canonical world state — the tile
## grid (CT-28: whole world in RAM), water, lighting, placed blocks, objects,
## dropped items, spawn, clock — and answers every world query. In
## single-player this node *is* the host; in LAN it runs only on the host.
## Gameplay code never touches tile layers directly: it asks World, and the
## StructureRenderer windows the grid into collision tiles near the camera.

const WORLD_ITEM_SCENE := preload("res://scenes/items/world_item.tscn")
const WORLD_OBJECT_SCENE := preload("res://scenes/objects/world_object.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const BACKPACK_SCENE := preload("res://scenes/items/backpack.tscn")

var grid: WorldGrid
var renderer: StructureRenderer
var items_root: Node
var objects_root: Node
var spawn_position: Vector2 # feet position (bottom-center) of the spawn
var water_sim: WaterSim
var pumps: Array = [] # WorldObjects of kind "pump"
var light_map: LightMap
var map_reveal: MapReveal # fog-of-war world map (CC-25); saved per character
var _light_tick: int = 0
## The window relight is the priciest tick job, so it only reruns when
## something it depends on changed: blocks/doors/power (_light_dirty),
## active water, or the window/sun/sources key.
var _light_dirty: bool = true
var _light_key: Array = []
var _water_relight_at: int = 0 # next _light_tick water motion may relight at

## Depth bands (GD-16): world data every system can query.
var waterline_row: int = 0
## Day/night (CC-11): 0..1, 0 = midnight; advances in real time.
var time_of_day: float = 0.35 # start in the morning

## Player-placed blocks (WS-22): key -> {id, hp, layer}. Anything in the
## grid NOT here is building structure and unbreakable (GL-01).
var placed_blocks: Dictionary = {}
## Canonical object store — one record per object in the whole city:
## {id, def, cell, placed, open, powered, outlet, storage: Inventory|null,
## node: WorldObject|null}. Nodes are only a *windowed view*: records near
## the camera get instantiated, everything else stays data (a full city
## holds thousands of objects — sprites, point lights, and door bodies for
## all of them is what tanked the spawn framerate). Solidity and sight
## queries read the record, so far doors still seal water.
var object_records: Array = []
## Every cell covered by an object -> its record.
var object_cells: Dictionary = {}
var _obj_window_center := Vector2i(-99999, -99999)
## Canonical enemy store (M4) — same windowed pattern as objects: one record
## per enemy in the city {type, pos, hp, band, stats, night, node}; records
## near the player run as Enemy nodes, the rest are frozen data. Killing an
## enemy erases its record — cleared stays cleared (GD-02/03).
var enemy_records: Array = []
var enemies_root: Node = null
var _enemy_window_center := Vector2i(-99999, -99999)
## Day counter + red moon schedule (CC-14, GL-15): a red moon rises at dusk
## once day_count reaches next_red_moon_day, waves converge on players all
## night, and the survivors ("stragglers") persist and re-seed (GD-02).
var day_count: int = 0
var next_red_moon_day: int = 7
var red_moon_active: bool = false
var _was_night: bool = false
var _wave_timer: float = 0.0
var _floater_timer: float = 0.0
## Per-system frame costs + counters for the F3 debug overlay.
var perf: Dictionary = {"water_ms": 0.0, "light_ms": 0.0, "fog_ms": 0.0,
	"objects_live": 0, "objects_total": 0, "enemies_live": 0, "enemies_total": 0}

func register(p_grid: WorldGrid, p_spawn: Vector2, p_items_root: Node,
		p_objects_root: Node, p_renderer: StructureRenderer, p_waterline_row: int) -> void:
	grid = p_grid
	items_root = p_items_root
	objects_root = p_objects_root
	renderer = p_renderer
	spawn_position = p_spawn
	waterline_row = p_waterline_row
	placed_blocks.clear()
	structure_damage.clear()
	damage_rev += 1
	object_records.clear()
	object_cells.clear()
	pumps.clear()
	_obj_window_center = Vector2i(-99999, -99999)
	enemy_records.clear()
	_enemy_window_center = Vector2i(-99999, -99999)
	enemies_root = Node2D.new()
	enemies_root.name = "Enemies"
	# Under the items root: draws below the fog-of-war layer, so unlit
	# interiors hide their occupants (WS-20) — a scene-order guarantee.
	items_root.add_child.call_deferred(enemies_root)
	day_count = 0
	next_red_moon_day = randi_range(Constants.RED_MOON_MIN_DAYS, Constants.RED_MOON_MAX_DAYS)
	red_moon_active = false
	_wave_timer = 0.0
	water_sim = WaterSim.new(grid.bounds, is_solid_cell)
	water_sim.budget_per_tick = Constants.WATER_BUDGET_PER_TICK
	light_map = LightMap.new()
	map_reveal = MapReveal.new(grid.bounds)
	_light_dirty = true
	_light_key = []

func is_ready() -> bool:
	return grid != null

func set_spawn(feet_position: Vector2) -> void:
	spawn_position = feet_position

func _physics_process(delta: float) -> void:
	if water_sim == null:
		return
	var prev_time := time_of_day
	time_of_day = fposmod(time_of_day + delta / Constants.DAY_LENGTH_SECONDS, 1.0)
	if time_of_day < prev_time:
		day_count += 1 # midnight wrap
	_tick_night(delta)
	_tick_red_moon(delta)
	_tick_pumps()
	var t0 := Time.get_ticks_usec()
	water_sim.tick()
	perf.water_ms = (Time.get_ticks_usec() - t0) / 1000.0
	_light_tick += 1
	if _light_tick % Constants.BREAKER_CHECK_TICKS == 0:
		_check_breakers()
	if _light_tick % Constants.LIGHT_RECOMPUTE_TICKS == 0:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p != null:
			var center := cell_at(p.global_position)
			var radius: int = p.reveal_radius() if p.has_method("reveal_radius") else Constants.MAP_REVEAL_RADIUS
			map_reveal.reveal_disc(center, radius)
			_update_object_window(center)
			_update_enemy_window(center)
			var half := Vector2i(Constants.LIGHT_WINDOW.x / 2.0, Constants.LIGHT_WINDOW.y / 2.0)
			var window := Rect2i(center - half, Constants.LIGHT_WINDOW).intersection(grid.bounds)
			var sources := _gather_light_sources()
			var key: Array = [window, int(roundf(sun_strength() * LightMap.MAX_LIGHT)), hash(str(sources))]
			# Water in motion (a pump, a slosh that never settles) must not
			# force the full 40ms relight every cycle — its light effect is
			# subtle, so it refreshes at most once a second. Blocks, doors,
			# lamps, and the window/sun/sources key stay instant.
			var water_due: bool = water_sim.changed_last_tick > 0 and _light_tick >= _water_relight_at
			if _light_dirty or water_due or key != _light_key:
				if water_due:
					_water_relight_at = _light_tick + 60
				_light_dirty = false
				_light_key = key
				var lt0 := Time.get_ticks_usec()
				light_map.compute_window(window, grid.bounds.position.y, is_solid_cell,
					water_sim.level_at, sources, sun_strength())
				perf.light_ms = (Time.get_ticks_usec() - lt0) / 1000.0

## Daylight factor (CC-11): full sun by day, a dim glow at night.
func sun_strength() -> float:
	var day := clampf(sin(time_of_day * TAU - PI * 0.5) * 1.6 + 0.5, 0.12, 1.0)
	return day

## Night (GD-29): the stretch where the sun sits at its clamp floor.
func is_night() -> bool:
	return sun_strength() <= 0.14

# --- Coordinate helpers (pure math; tiles are only a render window) ---

func cell_at(global_pos: Vector2) -> Vector2i:
	return Vector2i(floori(global_pos.x / Constants.BLOCK_SIZE), floori(global_pos.y / Constants.BLOCK_SIZE))

func cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * Constants.BLOCK_SIZE, (cell.y + 0.5) * Constants.BLOCK_SIZE)

func cell_top_y(cell: Vector2i) -> float:
	return cell.y * Constants.BLOCK_SIZE

func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell.x * Constants.BLOCK_SIZE, cell.y * Constants.BLOCK_SIZE, Constants.BLOCK_SIZE, Constants.BLOCK_SIZE)

# --- Depth bands (GD-16) ---

## Blocks below the waterline (negative above it).
func depth_below_waterline(cell: Vector2i) -> int:
	return cell.y - waterline_row

func band_at(cell: Vector2i) -> String:
	var d := depth_below_waterline(cell)
	if d < 0:
		return "dry"
	if d < Constants.BAND_SHALLOWS_DEPTH:
		return "shallows"
	if d < Constants.BAND_COLD_DEPTH:
		return "cold"
	if d < Constants.BAND_DARK_DEPTH:
		return "dark"
	return "crush"

# --- Queries ---

func is_solid_cell(cell: Vector2i) -> bool:
	if grid.structure_at(cell) != WorldGrid.M.AIR:
		return true
	var rec: Dictionary = object_cells.get(cell, {})
	return not rec.is_empty() and _record_solid(rec)

## Solidity from the record (valid whether or not the node is instantiated).
func _record_solid(rec: Dictionary) -> bool:
	return rec.def.kind == "door" and not rec.open

func is_solid(global_pos: Vector2) -> bool:
	return is_solid_cell(cell_at(global_pos))

func has_block_cell(cell: Vector2i) -> bool:
	return grid.structure_at(cell) != WorldGrid.M.AIR

func has_back_wall_cell(cell: Vector2i) -> bool:
	return grid.back_at(cell) != WorldGrid.M.AIR

func is_water_cell(cell: Vector2i) -> bool:
	return water_sim != null and water_sim.level_at(cell) > 0

## Partial-cell aware: a point is in water only below the cell's fill surface.
func is_water(global_pos: Vector2) -> bool:
	var cell := cell_at(global_pos)
	if not is_water_cell(cell):
		return false
	return global_pos.y >= water_sim.surface_y_in_cell(cell)

func is_climbable_cell(cell: Vector2i) -> bool:
	return grid != null and grid.climb_at(cell) != WorldGrid.C.NONE

func is_climbable(global_pos: Vector2) -> bool:
	return is_climbable_cell(cell_at(global_pos))

func is_ladder_cell(cell: Vector2i) -> bool:
	return grid != null and grid.climb_at(cell) == WorldGrid.C.LADDER

## The topmost cell of a ladder acts as a stand-on surface (one-way platform).
func is_ladder_top_cell(cell: Vector2i) -> bool:
	return is_ladder_cell(cell) and not is_ladder_cell(cell + Vector2i.UP)

func is_player_block(cell: Vector2i) -> bool:
	return placed_blocks.has(cell)

## Global x of the center of the climbable column containing global_pos.
func climbable_center_x(global_pos: Vector2) -> float:
	return cell_center(cell_at(global_pos)).x

## Highest contiguous water cell in the column above global_pos.
func _surface_cell(global_pos: Vector2) -> Vector2i:
	var cell := cell_at(global_pos)
	var limit := 64 # safety bound for the column scan
	while limit > 0 and is_water_cell(cell + Vector2i.UP):
		cell += Vector2i.UP
		limit -= 1
	return cell

## Global y of the water surface above global_pos (fill surface of the
## highest contiguous water cell in that column).
func water_surface_y(global_pos: Vector2) -> float:
	return water_sim.surface_y_in_cell(_surface_cell(global_pos))

## True if the water column above global_pos meets air (not a ceiling).
func surface_has_air(global_pos: Vector2) -> bool:
	return not is_solid_cell(_surface_cell(global_pos) + Vector2i.UP)

## Current push (px/s) on a body at global_pos (WS-16).
func current_at(global_pos: Vector2) -> Vector2:
	if water_sim == null:
		return Vector2.ZERO
	return water_sim.flow_at(cell_at(global_pos)) * Constants.CURRENT_PUSH

## True if no solid block overlaps the given global-space rect.
func rect_is_clear(rect: Rect2) -> bool:
	var shrunk := rect.grow(-0.5)
	var c0 := cell_at(shrunk.position)
	var c1 := cell_at(shrunk.end)
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			if is_solid_cell(Vector2i(x, y)):
				return false
	return true

func _cell_overlaps_body(cell: Vector2i, body: CharacterBody2D) -> bool:
	if body == null:
		return false
	var shape: RectangleShape2D = body.get_node("CollisionShape2D").shape
	var brect := Rect2(body.global_position + body.get_node("CollisionShape2D").position - shape.size * 0.5, shape.size)
	return cell_rect(cell).grow(-0.5).intersects(brect)

func _has_neighbor_support(cell: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n: Vector2i = cell + d
		if has_block_cell(n) or object_cells.has(n) or has_back_wall_cell(n):
			return true
	return has_back_wall_cell(cell)

# --- Lighting (WS-17) + fog of war ---

func light_at(cell: Vector2i) -> int:
	return light_map.light_at(cell) if light_map != null else LightMap.MAX_LIGHT

## How much sight passes through a cell: structure (stone/metal, closed
## doors) blacks out; obstacle materials (wood, plastic) attenuate.
func sight_transparency_cell(cell: Vector2i) -> float:
	var rec: Dictionary = object_cells.get(cell, {})
	if not rec.is_empty() and _record_solid(rec):
		return 0.0
	var m := grid.structure_at(cell)
	if m == WorldGrid.M.AIR:
		return 1.0
	if m == WorldGrid.M.STONE or m == WorldGrid.M.METAL:
		return 0.0
	return Constants.OBSTACLE_SIGHT_TRANSMISSION

## Raycast: the fraction of sight surviving the path to `to_cell`.
func sight_transmission(from_pos: Vector2, to_cell: Vector2i) -> float:
	var target := cell_center(to_cell)
	var delta := target - from_pos
	var dist := delta.length()
	if dist < 1.0:
		return 1.0
	var trans := 1.0
	var last := cell_at(from_pos)
	var steps := int(dist / (Constants.BLOCK_SIZE * 0.4)) + 1
	for i in range(1, steps):
		var c := cell_at(from_pos + delta * (float(i) / steps))
		if c == to_cell:
			break
		if c == last:
			continue
		last = c
		trans *= sight_transparency_cell(c)
		if trans < 0.05:
			return 0.0
	return trans

func line_of_sight(from_pos: Vector2, to_cell: Vector2i) -> bool:
	return sight_transmission(from_pos, to_cell) > 0.01

## Fog of war: applies inside buildings only (back-wall cells, WS-20); in
## sight and in range = fully illuminated, scaled by obstacle transmission.
## Player-placed lights act as beacons (user request): the area around a
## placed lamp or dropped glowstick stays revealed even with no line of
## sight from the player — each beacon casts its own sight.
func visibility_at(cell: Vector2i, viewer_pos: Vector2) -> float:
	if not has_back_wall_cell(cell):
		return float(LightMap.MAX_LIGHT)
	var vis := _sight_from(viewer_pos, cell, Constants.SIGHT_FULL_BLOCKS)
	if vis >= float(LightMap.MAX_LIGHT):
		return vis
	for b: Vector2 in light_beacons():
		vis = maxf(vis, _sight_from(b, cell, Constants.BEACON_FULL_BLOCKS))
		if vis >= float(LightMap.MAX_LIGHT):
			break
	return vis

func _sight_from(from_pos: Vector2, cell: Vector2i, full_blocks: float) -> float:
	var d := cell_center(cell).distance_to(from_pos) / Constants.BLOCK_SIZE
	var cap := float(LightMap.MAX_LIGHT)
	if d > full_blocks:
		cap = maxf(cap - (d - full_blocks) * Constants.SIGHT_FADE_PER_BLOCK, 0.0)
	if cap <= 0.0:
		return 0.0 # out of range: no raycast spent
	return cap * sight_transmission(from_pos, cell)

## Fog-beacon positions, rebuilt at most once per frame: player-PLACED light
## objects (from records, so far floors count too) + dropped glowsticks.
var _beacon_cache: Array = []
var _beacon_frame: int = -1

func light_beacons() -> Array:
	var f := Engine.get_process_frames()
	if _beacon_frame == f:
		return _beacon_cache
	_beacon_frame = f
	_beacon_cache = []
	for rec: Dictionary in object_records:
		if not rec.placed or rec.def.get("kind", "") != "light":
			continue
		if bool(rec.def.get("powered", false)):
			# live node knows best; streamed-out records carry the last state
			var on: bool = rec.node.powered_on if rec.node != null else bool(rec.get("powered", false))
			if not on:
				continue # a wired lamp with no power reveals nothing
		_beacon_cache.append(cell_center(rec.cell))
	if items_root != null:
		for it in items_root.get_children():
			if it is WorldItem and it.light != null and not it.is_queued_for_deletion():
				_beacon_cache.append((it as Node2D).global_position)
	return _beacon_cache

func _gather_light_sources() -> Array:
	var out := []
	if objects_root != null:
		for obj in objects_root.get_children():
			if not (obj is WorldObject) or obj.is_queued_for_deletion():
				continue
			if obj.def.kind == "light" and (not obj.def.get("powered", false) or obj.powered_on):
				out.append({"cell": cell_at(obj.center()), "level": Constants.LAMP_LIGHT})
	if items_root != null:
		for it in items_root.get_children():
			if it is WorldItem and it.light != null and not it.is_queued_for_deletion():
				out.append({"cell": cell_at(it.global_position), "level": Constants.GLOWSTICK_LIGHT})
	for p in get_tree().get_nodes_in_group("player"):
		var level := Constants.PLAYER_SIGHT_LIGHT
		var held: Dictionary = Data.item(p.held_item())
		if held.get("use", {}).has("drop_light"):
			level = Constants.GLOWSTICK_LIGHT
		if p.has_method("equip_stat"): # helmet lamp / glow band (M5 gear)
			level = maxi(level, int(p.equip_stat("light")))
		out.append({"cell": cell_at(p.global_position), "level": level})
	return out

## Building power (WS-17).
func update_power() -> void:
	if objects_root == null:
		return
	_light_dirty = true
	var breakers := []
	for obj in objects_root.get_children():
		if obj is WorldObject and obj.def.kind == "breaker" and not obj.is_queued_for_deletion():
			breakers.append(obj)
	for obj in objects_root.get_children():
		if obj is WorldObject and obj.def.kind == "light" and obj.def.get("powered", false):
			var on := false
			for b in breakers:
				if b.powered_on and b.center().distance_to(obj.center()) <= Constants.POWER_RADIUS_BLOCKS * Constants.BLOCK_SIZE:
					on = true
			obj.set_powered(on)

func _check_breakers() -> void:
	if objects_root == null:
		return
	var tripped := false
	for obj in objects_root.get_children():
		if obj is WorldObject and obj.def.kind == "breaker" and obj.powered_on:
			if water_sim.level_at(obj.cell) > 2:
				obj.powered_on = false
				tripped = true
	if tripped:
		update_power()

# --- Blocks (WS-12/21/22, GL-01) ---

func _mat_for_block(def: Dictionary) -> int:
	return int(def.atlas_row) + 1

func can_place_block(id: String, cell: Vector2i, by: CharacterBody2D = null) -> bool:
	var def: Dictionary = Data.blocks.get(id, {})
	if def.is_empty() or not grid.in_bounds(cell):
		return false
	match def.layer:
		"back":
			return not has_back_wall_cell(cell) and not has_block_cell(cell) and not object_cells.has(cell) and _has_neighbor_support(cell)
		"climb":
			return not has_block_cell(cell) and not is_climbable_cell(cell) and not object_cells.has(cell) \
				and (_has_neighbor_support(cell) or is_climbable_cell(cell + Vector2i.UP) or is_climbable_cell(cell + Vector2i.DOWN))
		_:
			return not has_block_cell(cell) and not object_cells.has(cell) \
				and not _cell_overlaps_body(cell, by) and _has_neighbor_support(cell)

func place_block(id: String, cell: Vector2i) -> bool:
	var def: Dictionary = Data.blocks.get(id, {})
	if def.is_empty() or not grid.in_bounds(cell):
		return false
	match def.layer:
		"back":
			grid.set_back(cell, _mat_for_block(def))
		"climb":
			grid.set_climb(cell, WorldGrid.C.LADDER if int(def.atlas_row) == 5 else WorldGrid.C.ROPE)
		_:
			if water_sim != null:
				water_sim.displace(cell) # WS-24
			grid.set_structure(cell, _mat_for_block(def))
	placed_blocks[_key(cell, def.layer)] = {"id": id, "hp": float(def.hp), "layer": def.layer}
	_cell_changed(cell)
	return true

func _key(cell: Vector2i, layer_name: String) -> Variant:
	return cell if layer_name == "blocks" else "%s:%d,%d" % [layer_name, cell.x, cell.y]

func _cell_changed(cell: Vector2i) -> void:
	_light_dirty = true
	if water_sim != null:
		water_sim.notify_changed(cell)
	if renderer != null:
		renderer.refresh_cell(cell)

## Removes a player-placed block on the given layer; returns its item id or "".
func remove_block(cell: Vector2i, layer_name: String = "blocks") -> String:
	var key = _key(cell, layer_name)
	if not placed_blocks.has(key):
		return ""
	var entry: Dictionary = placed_blocks[key]
	match layer_name:
		"back":
			grid.set_back(cell, WorldGrid.M.AIR)
		"climb":
			grid.set_climb(cell, WorldGrid.C.NONE)
		_:
			grid.set_structure(cell, WorldGrid.M.AIR)
	placed_blocks.erase(key)
	_cell_changed(cell)
	return entry.id

## Background walls are cosmetic (WS-20/21): any wall can be knocked out.
func erase_back_wall(cell: Vector2i) -> bool:
	if not has_back_wall_cell(cell):
		return false
	placed_blocks.erase(_key(cell, "back"))
	grid.set_back(cell, WorldGrid.M.AIR)
	_cell_changed(cell)
	return true

## Tool hit. Returns "broken" | "damaged" | "too_hard" | "structure" | "none".
## `by` (the miner's position) makes the drop toss toward them.
func damage_block(cell: Vector2i, damage: float, tool_tier: int, by: Vector2 = Vector2.INF) -> String:
	var layer_name := "blocks"
	if not has_block_cell(cell):
		if is_climbable_cell(cell):
			layer_name = "climb"
		else:
			return "none"
	var key = _key(cell, layer_name)
	if not placed_blocks.has(key):
		if layer_name == "blocks":
			return _damage_structure(cell, damage, tool_tier, by)
		return "structure" # stairwell ladders/ropes stay fixed
	var entry: Dictionary = placed_blocks[key]
	var def: Dictionary = Data.blocks[entry.id]
	if tool_tier < int(def.hardness) or damage <= 0.0:
		return "too_hard"
	entry.hp -= damage
	damage_rev += 1 # crack overlay watches this
	if entry.hp > 0.0:
		return "damaged"
	remove_block(cell, layer_name)
	var it := spawn_item(entry.id, 1, cell_center(cell), _toss_velocity(cell_center(cell), by))
	if it != null:
		it.magnet = true
	return "broken"

## Velocity that arcs a mined drop toward the miner (lands at their feet /
## inside pickup range instead of dropping at the far wall).
func _toss_velocity(from: Vector2, by: Vector2) -> Vector2:
	if by == Vector2.INF:
		return Vector2.ZERO
	return (by - from) * Constants.MINE_TOSS_FACTOR + Vector2(0, -Constants.MINE_TOSS_UP)

## Structure demolition (GL-01 amended): any structure block breaks under
## the right tool tier (Constants.STRUCTURE_TIER), drops one matching
## material, and — like any removal — wakes water, light, and fog.
var structure_damage: Dictionary = {} # cell -> hp left (partially hit cells)
var damage_rev: int = 0 # bumped on any block damage; the crack overlay redraws on change

func _damage_structure(cell: Vector2i, damage: float, tool_tier: int, by: Vector2 = Vector2.INF) -> String:
	var mat := grid.structure_at(cell)
	var need: int = Constants.STRUCTURE_TIER.get(mat, 99)
	if tool_tier < need or damage <= 0.0:
		return "too_hard"
	var hp: float = structure_damage.get(cell, float(Constants.STRUCTURE_HP.get(mat, 60.0)))
	hp -= damage
	damage_rev += 1
	if hp > 0.0:
		structure_damage[cell] = hp
		return "damaged"
	structure_damage.erase(cell)
	grid.set_structure(cell, WorldGrid.M.AIR)
	_cell_changed(cell)
	var drop: String = Constants.STRUCTURE_DROP.get(mat, "")
	if drop != "":
		var it := spawn_item(drop, 1, cell_center(cell), _toss_velocity(cell_center(cell), by))
		if it != null:
			it.magnet = true
	return "broken"

# --- Objects ---

## The instantiated node covering this cell (null when none, or when the
## object is outside the window — gameplay only touches nearby objects).
func object_at(cell: Vector2i) -> WorldObject:
	var rec: Dictionary = object_cells.get(cell, {})
	return rec.get("node") if not rec.is_empty() else null

func object_record_at(cell: Vector2i) -> Dictionary:
	return object_cells.get(cell, {})

func can_place_object(id: String, cell: Vector2i, by: CharacterBody2D = null) -> bool:
	var def: Dictionary = Data.objects.get(id, {})
	if def.is_empty():
		return false
	var w: int = def.size[0]
	var h: int = def.size[1]
	var allow_water: bool = def.get("place_in_water", false)
	for dy in h:
		for dx in w:
			var c := Vector2i(cell.x + dx, cell.y - dy)
			var deep_water := water_sim != null and water_sim.level_at(c) > 2
			if has_block_cell(c) or object_cells.has(c) or (deep_water and not allow_water):
				return false
			if def.kind == "door" and _cell_overlaps_body(c, by):
				return false
	if def.get("wall_mounted", false):
		# Wall art hangs on background walls — no floor needed (WS-20/21).
		for dy in h:
			for dx in w:
				if not has_back_wall_cell(Vector2i(cell.x + dx, cell.y - dy)):
					return false
		return true
	for dx in w:
		if not has_block_cell(Vector2i(cell.x + dx, cell.y + 1)):
			return false
	return true

## Register an object as data only (no node) — the bulk path city boot uses
## for its thousands of objects; the window instantiates the nearby ones.
func add_object_record(id: String, cell: Vector2i, placed_by_player: bool) -> Dictionary:
	var def: Dictionary = Data.objects[id]
	var slots := int(def.get("storage_slots", def.get("slots", 0)))
	if def.kind == "chest" and slots == 0:
		slots = Constants.CHEST_SLOTS
	var rec := {"id": id, "def": def, "cell": cell, "placed": placed_by_player,
		"open": false, "powered": false, "unlocked": false, "outlet": WorldObject.NO_OUTLET,
		"storage": Inventory.new(slots) if slots > 0 else null, "node": null}
	object_records.append(rec)
	if _record_solid(rec):
		_light_dirty = true
	for c in _record_cells(rec):
		object_cells[c] = rec
		if water_sim != null and _record_solid(rec):
			water_sim.notify_changed(c)
	return rec

func _record_cells(rec: Dictionary) -> Array:
	var cells := []
	for dy in int(rec.def.size[1]):
		for dx in int(rec.def.size[0]):
			cells.append(Vector2i(rec.cell.x + dx, rec.cell.y - dy))
	return cells

## Place an object and instantiate it right away (player actions and tests
## always act near the camera, so the node exists from the start).
func place_object(id: String, cell: Vector2i, placed_by_player: bool) -> WorldObject:
	return _instantiate_record(add_object_record(id, cell, placed_by_player))

func _instantiate_record(rec: Dictionary) -> WorldObject:
	var obj: WorldObject = WORLD_OBJECT_SCENE.instantiate()
	obj.setup(rec.id, rec.cell, rec.placed)
	obj.storage = rec.storage # the record's inventory is the canonical one
	obj.global_position = cell_center(rec.cell) - Vector2.ONE * Constants.BLOCK_SIZE * 0.5
	objects_root.add_child(obj)
	obj.restore_state({"open": rec.open, "powered": rec.powered, "outlet": rec.outlet,
		"unlocked": rec.unlocked})
	rec.node = obj
	if rec.def.kind == "pump":
		pumps.append(obj)
	return obj

## Free a far node, banking its live state back into the record.
func _despawn_record(rec: Dictionary) -> void:
	var obj: WorldObject = rec.node
	rec.node = null
	if obj == null or not is_instance_valid(obj):
		return
	sync_record(rec, obj)
	pumps.erase(obj)
	obj.queue_free()

func sync_record(rec: Dictionary, obj: WorldObject) -> void:
	rec.open = obj.open
	rec.powered = obj.powered_on
	rec.unlocked = obj.unlocked
	rec.outlet = obj.outlet_cell

## Force an immediate window fill (scene boot: objects must exist before
## the first frame renders or the first test assertion runs).
func refresh_objects_around(pos: Vector2) -> void:
	_obj_window_center = Vector2i(-99999, -99999)
	_update_object_window(cell_at(pos))
	_enemy_window_center = Vector2i(-99999, -99999)
	_update_enemy_window(cell_at(pos))

## Instantiate records near `center`, free the rest. Runs when the player
## has moved a few cells; the window is generous so teleport-happy tests
## and normal play never see furniture pop.
func _update_object_window(center: Vector2i) -> void:
	if (_obj_window_center - center).length_squared() < 36: # < 6 cells moved
		return
	_obj_window_center = center
	var half: Vector2i = Constants.OBJECT_WINDOW / 2
	var win := Rect2i(center - half, Constants.OBJECT_WINDOW)
	var live := 0
	var changed := false
	for rec: Dictionary in object_records:
		var inside := win.has_point(rec.cell)
		if inside != (rec.node != null):
			if inside:
				_instantiate_record(rec)
			else:
				_despawn_record(rec)
			changed = true
		if inside:
			live += 1
	perf.objects_live = live
	perf.objects_total = object_records.size()
	if changed:
		update_power() # newly loaded wired lights resolve against breakers

func remove_object(obj: WorldObject) -> void:
	_light_dirty = true
	var rec: Dictionary = object_cells.get(obj.cell, {})
	if not rec.is_empty() and rec.node == obj:
		object_records.erase(rec)
		for c in _record_cells(rec):
			if object_cells.get(c) == rec:
				object_cells.erase(c)
			if water_sim != null:
				water_sim.notify_changed(c)
	pumps.erase(obj)
	obj.queue_free()

## Called when an object's solidity changes in place (door toggled).
func notify_object_changed(obj: WorldObject) -> void:
	_light_dirty = true
	var rec: Dictionary = object_cells.get(obj.cell, {})
	if not rec.is_empty() and rec.node == obj:
		rec.open = obj.open
	if water_sim != null:
		for c in obj.covered_cells():
			water_sim.notify_changed(c)

## Station ids within `reach` px of `pos` (GL-04).
func stations_near(pos: Vector2, reach: float) -> Array:
	var out := ["hand"]
	if objects_root == null:
		return out
	for obj in objects_root.get_children():
		if obj is WorldObject and obj.def.kind == "station" and obj.center().distance_to(pos) <= reach:
			if not out.has(obj.def.station):
				out.append(obj.def.station)
	return out

## Pumps (GL-16): suction and insertion through the connected body/airspace.
func _tick_pumps() -> void:
	for pump in pumps:
		if not is_instance_valid(pump) or pump.outlet_cell == WorldObject.NO_OUTLET:
			continue
		var intake: Vector2i = pump.cell
		var taken := water_sim.remove_water_spread(intake, Constants.PUMP_UNITS_PER_TICK)
		if taken > 0:
			var leftover := water_sim.add_water_spread(pump.outlet_cell, taken)
			if leftover > 0:
				water_sim.add_water_spread(intake, leftover)

# --- Enemies (M4, GD-01..29) ---

## Register an enemy as data. Stats resolve from the authored band table at
## the spawn position (GD-23); `hp_mult` scales red-moon waves by day count.
## Returns {} when the type has no stats anywhere (bad id).
func add_enemy_record(type_id: String, pos: Vector2, hp_mult: float = 1.0,
		night_spawn: bool = false) -> Dictionary:
	var band := band_at(cell_at(pos))
	var base := Data.enemy_stats(type_id, band)
	if base.is_empty():
		return {}
	var stats := {"hp": float(base.hp) * hp_mult, "damage": float(base.damage) * hp_mult,
		"speed": float(base.speed), "aggro": float(base.aggro)}
	var rec := {"type": type_id, "pos": pos, "hp": stats.hp, "band": band,
		"stats": stats, "mult": hp_mult, "night": night_spawn, "node": null}
	if Data.enemies[type_id].get("mode", "") == "fish":
		rec["stock"] = randi_range(Constants.FISH_STOCK_MIN, Constants.FISH_STOCK_MAX)
	enemy_records.append(rec)
	return rec

func _instantiate_enemy(rec: Dictionary) -> void:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.setup(rec)
	enemies_root.add_child(e)
	rec.node = e

func _despawn_enemy(rec: Dictionary) -> void:
	var e = rec.node
	rec.node = null
	if e != null and is_instance_valid(e):
		rec.pos = e.global_position # bank the chase position
		e.queue_free()

## Kill/removal: the record goes with the node — no ambient respawn ever
## brings it back (GD-02/03).
func remove_enemy(rec: Dictionary) -> void:
	enemy_records.erase(rec)
	var e = rec.node
	rec.node = null
	if e != null and is_instance_valid(e):
		e.queue_free()

## Instantiate records near `center`, freeze the rest (the object-window
## pattern; enemies outside the window don't think or move).
func _update_enemy_window(center: Vector2i) -> void:
	if (_enemy_window_center - center).length_squared() < 36:
		return
	_enemy_window_center = center
	var half: Vector2i = Constants.ENEMY_WINDOW / 2
	var win := Rect2i(center - half, Constants.ENEMY_WINDOW)
	var live := 0
	for rec: Dictionary in enemy_records:
		var inside := win.has_point(cell_at(rec.pos))
		if inside != (rec.node != null):
			if inside:
				_instantiate_enemy(rec)
			else:
				_despawn_enemy(rec)
		if inside:
			live += 1
	perf.enemies_live = live
	perf.enemies_total = enemy_records.size()

## True if pounding this cell can achieve anything: a player-placed block or
## a player-placed closed door. Structure is safe from zombies (GD-04; the
## red-moon rule is the same one).
func pound_target(cell: Vector2i) -> bool:
	if placed_blocks.has(cell):
		return true
	var rec: Dictionary = object_cells.get(cell, {})
	return not rec.is_empty() and rec.placed and _record_solid(rec)

## A zombie pound: chews through player-placed blocks (any hardness — mass
## beats craftsmanship) or a placed door (fixed hp pool on the record).
func pound(cell: Vector2i, damage: float) -> void:
	if placed_blocks.has(cell):
		damage_block(cell, damage, 99)
		return
	var rec: Dictionary = object_cells.get(cell, {})
	if rec.is_empty() or not rec.placed or not _record_solid(rec):
		return
	rec["pound_hp"] = float(rec.get("pound_hp", 60.0)) - damage
	if float(rec.pound_hp) <= 0.0:
		Audio.play_sfx("wood_break", cell_center(cell), 4)
		if rec.node != null and is_instance_valid(rec.node):
			remove_object(rec.node)
		else:
			object_records.erase(rec)
			for c in _record_cells(rec):
				if object_cells.get(c) == rec:
					object_cells.erase(c)
			_light_dirty = true

## Night extras (GD-29): floaters drift in near players after dark — the one
## ambient-spawn exception — and disperse at dawn.
func _tick_night(delta: float) -> void:
	var night := is_night()
	if _was_night and not night:
		for i in range(enemy_records.size() - 1, -1, -1):
			if enemy_records[i].get("night", false):
				remove_enemy(enemy_records[i])
	_was_night = night
	if not night:
		return
	_floater_timer -= delta
	if _floater_timer > 0.0:
		return
	_floater_timer = Constants.NIGHT_FLOATER_INTERVAL
	var live_night := 0
	for rec in enemy_records:
		if rec.get("night", false):
			live_night += 1
	for p in get_tree().get_nodes_in_group("player"):
		if live_night >= Constants.NIGHT_FLOATER_MAX:
			break
		var cell := _open_surface_near(p.global_position, 20, 45)
		if cell.x != -99999:
			add_enemy_record("floater", cell_center(cell), 1.0, true)
			live_night += 1

## An open-water surface cell a random ring away from `pos` (for floaters
## drifting in / red-moon spawns over water); sentinel x on failure.
func _open_surface_near(pos: Vector2, min_blocks: int, max_blocks: int) -> Vector2i:
	for attempt in 8:
		var dx := randi_range(min_blocks, max_blocks) * (1 if randi() % 2 == 0 else -1)
		var cell := Vector2i(cell_at(pos).x + dx, waterline_row)
		if grid.bounds.has_point(cell) and is_water_cell(cell) \
				and not is_solid_cell(cell + Vector2i.UP) and not has_back_wall_cell(cell):
			return cell
	return Vector2i(-99999, -99999)

# --- Red moons (CC-14, GL-15) ---

func _tick_red_moon(delta: float) -> void:
	if not red_moon_active:
		if is_night() and day_count >= next_red_moon_day:
			red_moon_active = true
			_wave_timer = 0.0 # first wave lands immediately
			Audio.play_sfx("red_moon_stinger", spawn_position, 1, 2.0)
		return
	if not is_night():
		# Dawn: the moon sets, spawning stops, stragglers stay (GD-02) and
		# slowly re-seed whatever the player had cleared.
		red_moon_active = false
		next_red_moon_day = day_count + randi_range(Constants.RED_MOON_MIN_DAYS, Constants.RED_MOON_MAX_DAYS)
		return
	_wave_timer -= delta
	if _wave_timer > 0.0:
		return
	_wave_timer = Constants.RED_MOON_WAVE_INTERVAL
	var mult := 1.0 + day_count * Constants.RED_MOON_STAT_PER_DAY
	for p in get_tree().get_nodes_in_group("player"):
		var n := Constants.RED_MOON_BASE_WAVE + int(day_count * Constants.RED_MOON_WAVE_PER_DAY)
		for i in n:
			_spawn_wave_zombie(p.global_position, mult)

## One wave zombie converging on a player (GD-23 scaling via `mult`): lands
## on the first roof/floor top in a ring column around them, or bobs in as a
## floater when the column is open water.
func _spawn_wave_zombie(pos: Vector2, mult: float) -> void:
	var dx := randi_range(Constants.RED_MOON_SPAWN_MIN_BLOCKS, Constants.RED_MOON_SPAWN_MAX_BLOCKS) \
		* (1 if randi() % 2 == 0 else -1)
	var x := cell_at(pos).x + dx
	if x <= grid.bounds.position.x + 2 or x >= grid.bounds.end.x - 2:
		return
	for y in range(grid.bounds.position.y + 2, waterline_row + 1):
		var cell := Vector2i(x, y)
		if is_solid_cell(cell) and not is_solid_cell(cell + Vector2i.UP):
			var rec := add_enemy_record("walker", cell_center(cell + Vector2i.UP) + Vector2(0, -6), mult)
			if not rec.is_empty() and _enemy_in_window(rec):
				_instantiate_enemy(rec)
			return
		if is_water_cell(cell): # open water column: a floater drifts in
			var frec := add_enemy_record("floater", cell_center(Vector2i(x, waterline_row)), mult)
			if not frec.is_empty() and _enemy_in_window(frec):
				_instantiate_enemy(frec)
			return

func _enemy_in_window(rec: Dictionary) -> bool:
	var half: Vector2i = Constants.ENEMY_WINDOW / 2
	return Rect2i(_enemy_window_center - half, Constants.ENEMY_WINDOW).has_point(cell_at(rec.pos))

# --- Items ---

func spawn_item(id: String, count: int, pos: Vector2, velocity: Vector2 = Vector2.ZERO) -> WorldItem:
	var it: WorldItem = WORLD_ITEM_SCENE.instantiate()
	it.setup(id, count, velocity)
	it.global_position = pos
	items_root.add_child(it)
	return it

## Death backpack (CC-07): holds the dropped inventory, floats like any
## buoyant item, recovered on touch. Lives under items_root so saves see it.
func spawn_backpack(slots: Array, pos: Vector2) -> Node2D:
	var pack: Node2D = BACKPACK_SCENE.instantiate()
	pack.slots = slots
	pack.global_position = pos
	items_root.add_child(pack)
	return pack
