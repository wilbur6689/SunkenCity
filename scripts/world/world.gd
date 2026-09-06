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
## Per-column cache of the first solid row from the sky (structure or a closed
## door); -1 = not computed yet. Invalidated by _cell_changed and door changes.
## Lets the relight skip the empty rows above the window (2026-09-04 perf).
var _sky_cache := PackedInt32Array()
var _light_key: Array = []
# The full relight runs on a worker thread (2026-09-04 perf): a scratch
# LightMap computes the static field (sun + lamps) off the main thread and the
# live map adopts it when done; players' own glow is re-applied per move.
var _light_task: int = -1
var _light_pending: LightMap = null
var _light_pending_key: Array = []
var _light_rerun: bool = false
var _light_dyn_key: int = 0
var _water_relight_at: int = 0 # next _light_tick water motion may relight at

## Depth bands (GD-16): world data every system can query.
var waterline_row: int = 0
## The city proper (map, edge clamp, spawns). The grid may extend east of it
## into the VOID annex that holds the interior pockets.
var city_bounds: Rect2i
var map_bounds: Rect2i # city_bounds in map cells (Constants.MAP_CELL); the annex is never mapped
## Tower footprints {x0, x1, top, floors, floor_h, district} for floor-level
## band lookups (DistrictsOverhaul "Bands"); set by the city scene, saved.
var towers: Array = []
## Interior pockets (user request 2026-09-01): {rect: interior Rect2i,
## exit: doorway cell in the city, entry: doorway cell inside}. Saved.
var pockets: Array = []
const NO_LINK := Vector2i(-99999, -99999)
const SIGHT_RAY_STEP_PX := 6.4 # sight raycast sample step in world px (0.4 of the old 16 px block; independent of BLOCK_SIZE)
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
var next_net_id: int = 1 # host-assigned ids for dropped items / backpacks / enemy records (LAN)
## net_id -> live WorldItem / Backpack node, on both ends (LAN Step 5): the
## host fills it in spawn_item/spawn_backpack, a client from WorldSync's
## replicas; nodes drop themselves out in _exit_tree.
var item_by_net_id: Dictionary = {}
var _suppress_record_hooks: bool = false # _replace_object_record sends one replace, not add + replace
var _window_key: Array = [] # snapped centres of every player the last time the windows were rebuilt
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
		p_objects_root: Node, p_renderer: StructureRenderer, p_waterline_row: int,
		p_city_w: int = -1) -> void:
	grid = p_grid
	items_root = p_items_root
	objects_root = p_objects_root
	renderer = p_renderer
	spawn_position = p_spawn
	waterline_row = p_waterline_row
	city_bounds = grid.bounds if p_city_w < 0 else Rect2i(grid.bounds.position, Vector2i(p_city_w, grid.bounds.size.y))
	map_bounds = MapReveal.macro_bounds(city_bounds)
	pockets.clear()
	towers.clear()
	placed_blocks.clear()
	structure_damage.clear()
	damage_rev += 1
	object_records.clear()
	object_cells.clear()
	pumps.clear()
	_obj_window_center = Vector2i(-99999, -99999)
	enemy_records.clear()
	_enemy_window_center = Vector2i(-99999, -99999)
	_window_key = []
	next_net_id = 1
	item_by_net_id.clear()
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
	_sky_cache.resize(grid.bounds.size.x)
	_sky_cache.fill(-1)

func is_ready() -> bool:
	return grid != null

func set_spawn(feet_position: Vector2) -> void:
	if Net.is_client():
		return
	spawn_position = feet_position

func _physics_process(delta: float) -> void:
	if water_sim == null:
		return
	# The simulation is the host's (Multiplayer.md §3): a client only draws the
	# replicated clock, water, records and enemies; its own light/fog, map
	# reveal and streaming windows stay local.
	if Net.is_server():
		var prev_time := time_of_day
		time_of_day = fposmod(time_of_day + delta / Constants.DAY_LENGTH_SECONDS, 1.0)
		if time_of_day < prev_time:
			day_count += 1 # midnight wrap
		# Trees grow at dawn, not midnight (user request 2026-09-02): each morning
		# every planted/seeded stage advances once - a sapling planted on day N is
		# fully grown on the morning of day N+2 (a 2-day period).
		if prev_time < Constants.MORNING_TIME and time_of_day >= Constants.MORNING_TIME:
			_grow_trees()
		_tick_night(delta)
		_tick_red_moon(delta)
		_tick_pumps()
		var t0 := Time.get_ticks_usec()
		water_sim.tick()
		perf.water_ms = (Time.get_ticks_usec() - t0) / 1000.0
	else:
		# Cosmetic: run the sun between the host's once-a-second clock
		# replicas (WorldSync._clock) so the tint never steps. Days, growth
		# and the red moon are the host's alone.
		time_of_day = fposmod(time_of_day + delta / Constants.DAY_LENGTH_SECONDS, 1.0)
	_light_tick += 1
	if Net.is_server() and _light_tick % Constants.BREAKER_CHECK_TICKS == 0:
		_check_breakers()
	if _light_tick % Constants.LIGHT_RECOMPUTE_TICKS == 0:
		var p := Net.local_player() as Node2D
		if p != null:
			var center := cell_at(p.global_position)
			var radius: int = p.reveal_radius() if p.has_method("reveal_radius") else Constants.MAP_REVEAL_RADIUS
			map_reveal.reveal_disc(map_macro_for(p.global_position), radius)
			_update_object_window(center)
			_update_enemy_window(center)
			_tick_light(center)

## Relight scheduling. The window snaps to a LIGHT_SNAP cell grid around the
## player; the static field (sun, lamps, dropped lights) recomputes on a
## worker thread whenever its key changes or something dirtied it, and the
## live map adopts the result on completion. Players' glow is layered on by
## a small BFS each time their cell changes - cheap, and it never stalls.
func _tick_light(center: Vector2i) -> void:
	var snap: int = Constants.LIGHT_SNAP
	var anchor := Vector2i(floori(float(center.x) / snap) * snap, floori(float(center.y) / snap) * snap)
	var half := Vector2i(Constants.LIGHT_WINDOW.x / 2.0, Constants.LIGHT_WINDOW.y / 2.0)
	var window := Rect2i(anchor - half, Constants.LIGHT_WINDOW).intersection(grid.bounds)
	var static_sources := _gather_light_sources(false)
	var key: Array = [window, int(roundf(sun_strength() * LightMap.MAX_LIGHT)), hash(str(static_sources))]
	# Finish a running relight first.
	if _light_pending != null and WorkerThreadPool.is_task_completed(_light_task):
		WorkerThreadPool.wait_for_task_completion(_light_task)
		light_map.adopt(_light_pending)
		perf.light_ms = _light_pending.compute_ms
		_light_key = _light_pending_key
		_light_pending = null
		_light_task = -1
		_light_dyn_key = 0 # force the dynamic pass over the fresh field
		if _light_rerun:
			_light_rerun = false
			_light_dirty = true
	# Water in motion (a pump, a slosh that never settles) must not force the
	# full relight every cycle — its light effect is subtle, so it refreshes
	# at most once a second. Blocks, doors, lamps, and the window/sun/sources
	# key stay instant.
	var water_due: bool = water_sim.changed_last_tick > 0 and _light_tick >= _water_relight_at
	if _light_dirty or water_due or key != _light_key:
		if _light_pending != null:
			_light_rerun = true # a relight is in flight: run again when it lands
		else:
			if water_due:
				_water_relight_at = _light_tick + 60
				if Net.is_client():
					water_sim.changed_last_tick = 0 # replica writes set it; the sim never ticks here
			_light_dirty = false
			_light_pending_key = key
			var sky_rows := PackedInt32Array()
			sky_rows.resize(window.size.x)
			for i in window.size.x:
				sky_rows[i] = sky_row(window.position.x + i)
			var lm := LightMap.new()
			_light_pending = lm
			_light_task = WorkerThreadPool.add_task(lm.compute_window.bind(window, grid.bounds, grid.structure,
				water_sim.levels, closed_door_cells(), sky_rows, waterline_row, static_sources, sun_strength()),
				false, "relight")
	# Players' glow over the static field, whenever they moved a cell.
	var dyn := _gather_light_sources(true)
	var dkey := hash(str(dyn))
	if dkey != _light_dyn_key and not light_map.static_light.is_empty():
		_light_dyn_key = dkey
		light_map.apply_dynamic(dyn)

## Block until any in-flight relight has landed (tests; scene teardown).
func flush_light() -> void:
	if _light_pending != null:
		WorkerThreadPool.wait_for_task_completion(_light_task)
		light_map.adopt(_light_pending)
		_light_key = _light_pending_key
		_light_pending = null
		_light_task = -1
		light_map.apply_dynamic(_gather_light_sources(true))
		_light_dyn_key = hash(str(_gather_light_sources(true)))

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

## Per-cell band: the physical gates (cold/crush) and anything that bites
## at the exact depth use this.
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

## Floor-level band (DistrictsOverhaul "Bands", 2026-09-04): inside a tower
## the whole floor takes the band of its CEILING row, so a floor straddling
## a boundary resolves to the shallower band. Enemies, loot and the HUD
## label use this; outside a tower it equals band_at.
func floor_band_at(cell: Vector2i) -> String:
	return band_at(Vector2i(cell.x, CityGen.band_row(towers, cell)))

# --- Interior pockets ---

## East of the city proper: the VOID annex where the pockets live.
func in_annex(cell: Vector2i) -> bool:
	return cell.x >= city_bounds.end.x

## The pocket whose interior holds `cell` ({} when none).
func pocket_at(cell: Vector2i) -> Dictionary:
	for p: Dictionary in pockets:
		if (p.rect as Rect2i).has_point(cell):
			return p
	return {}

## Where a position "is" on the city map: itself, or — inside a pocket — the
## doorway it was entered through (the minimap/map never show the annex).
func map_cell_for(pos: Vector2) -> Vector2i:
	var cell := cell_at(pos)
	if not in_annex(cell):
		return cell
	var p := pocket_at(cell)
	return p.exit if not p.is_empty() else cell

## The same anchor in MAP cells (the reveal bitset / minimap / map grid).
func map_macro_for(pos: Vector2) -> Vector2i:
	var c := map_cell_for(pos)
	return Vector2i(floori(float(c.x) / Constants.MAP_CELL), floori(float(c.y) / Constants.MAP_CELL))

## Feet position on the far side of the portal at `cell` (Vector2.INF when
## it links nowhere). The twin swings open too — you came through it.
func portal_target(cell: Vector2i) -> Vector2:
	var rec: Dictionary = object_cells.get(cell, {})
	var link: Vector2i = rec.get("link", NO_LINK) if not rec.is_empty() else NO_LINK
	if link == NO_LINK:
		return Vector2.INF
	var twin: Dictionary = object_cells.get(link, {})
	if not twin.is_empty():
		twin.open = true
		if twin.node != null and is_instance_valid(twin.node):
			twin.node.set_open_look(true)
	# Land centred on the twin DOORWAY (DOOR_W cells wide since the 8 px cell):
	# the record anchors bottom-left, and a body centred on that one cell would
	# overlap the wall beside it and get unstuck out of the room.
	var dw := int(Data.objects.get(twin.get("id", ""), {}).get("size", [2, 6])[0])
	return Vector2((link.x + dw * 0.5) * Constants.BLOCK_SIZE, (link.y + 1) * Constants.BLOCK_SIZE)

## Release a barred door (user request 2026-09-02): a hidden button's record
## carries the door's cell in `door`. Opens + unlocks that door for good.
func release_barred_door(button_cell: Vector2i) -> bool:
	if Net.is_client():
		return false
	var brec: Dictionary = object_cells.get(button_cell, {})
	if brec.is_empty() or not brec.has("door"):
		return false
	var drec: Dictionary = object_cells.get(brec.door, {})
	if drec.is_empty():
		return false
	drec.open = true
	drec.unlocked = true
	if drec.node != null and is_instance_valid(drec.node):
		drec.node.unlocked = true
		drec.node.set_open_look(true)
	Net.on_record_changed(drec)
	return true

# --- Queries ---

## Cells of every closed door record (Vector2i -> true): solid to light and
## the connectivity flood, as is_solid_cell says.
func closed_door_cells() -> Dictionary:
	var out := {}
	for rec: Dictionary in object_records:
		if rec.def.kind == "door" and not rec.open:
			for c in _record_cells(rec):
				out[c] = true
	return out

## First solid row from the sky in column x (structure or closed door), or a
## huge number when the column is open to the bottom of the grid. Cached.
func sky_row(x: int) -> int:
	var ix := x - grid.bounds.position.x
	if ix < 0 or ix >= _sky_cache.size():
		return 1 << 30
	var cached := _sky_cache[ix]
	if cached >= 0:
		return cached
	var gw := grid.bounds.size.x
	var gi := ix
	var found := 1 << 30
	for y in range(grid.bounds.position.y, grid.bounds.end.y):
		if grid.structure[gi] != WorldGrid.M.AIR:
			found = y
			break
		var rec: Dictionary = object_cells.get(Vector2i(x, y), {})
		if not rec.is_empty() and _record_solid(rec):
			found = y
			break
		gi += gw
	_sky_cache[ix] = found
	return found

func _invalidate_sky(cell: Vector2i) -> void:
	var ix := cell.x - grid.bounds.position.x
	if ix >= 0 and ix < _sky_cache.size():
		_sky_cache[ix] = -1

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

## Global x of the center of the climbable RUN containing global_pos: since
## the 8 px cell (2026-09-04) generated ladders are two cells wide, so the
## player centres on the pair, not on whichever half it grabbed.
func climbable_center_x(global_pos: Vector2) -> float:
	var cell := cell_at(global_pos)
	var x0 := cell.x
	var x1 := cell.x
	while x0 - cell.x > -3 and is_climbable_cell(Vector2i(x0 - 1, cell.y)):
		x0 -= 1
	while x1 - cell.x < 3 and is_climbable_cell(Vector2i(x1 + 1, cell.y)):
		x1 += 1
	return (x0 + x1 + 1) * 0.5 * Constants.BLOCK_SIZE

## Highest contiguous water cell in the column above global_pos.
func _surface_cell(global_pos: Vector2) -> Vector2i:
	var cell := cell_at(global_pos)
	var limit := 128 # safety bound for the column scan
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
	if m == WorldGrid.M.STONE or m == WorldGrid.M.METAL or m == WorldGrid.M.VOID:
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
	var steps := int(dist / SIGHT_RAY_STEP_PX) + 1
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
	if grid.structure_at(cell) == WorldGrid.M.VOID:
		return 0.0 # the blackness around interior pockets: never lit, no ray spent
	if not has_back_wall_cell(cell):
		# Exterior (WS-20): fully revealed by day, but dark at night (user
		# request 2026-09-02) - only a small moonlit radius, placed lights,
		# dropped glowsticks, and a worn head lamp cut through.
		var day := clampf((sun_strength() - 0.12) / 0.88, 0.0, 1.0)
		var ambient := lerpf(Constants.NIGHT_AMBIENT_VIS, float(LightMap.MAX_LIGHT), day)
		if ambient >= float(LightMap.MAX_LIGHT):
			return float(LightMap.MAX_LIGHT)
		var v := maxf(ambient, _night_moonlight(viewer_pos, cell))
		for b: Vector2 in light_beacons():
			v = maxf(v, _sight_from(b, cell, Constants.BEACON_FULL_BLOCKS))
			if v >= float(LightMap.MAX_LIGHT):
				break
		return v
	var vis := _sight_from(viewer_pos, cell, Constants.SIGHT_FULL_BLOCKS)
	if vis >= float(LightMap.MAX_LIGHT):
		return vis
	for b: Vector2 in light_beacons():
		vis = maxf(vis, _sight_from(b, cell, Constants.BEACON_FULL_BLOCKS))
		if vis >= float(LightMap.MAX_LIGHT):
			break
	return vis

## The player's unaided night vision outdoors (user request 2026-09-02): a
## tight moonlit radius that falls off fast, so you can see your own feet but
## need a light to see the area - not the long sight-fade a torch gets.
func _night_moonlight(from_pos: Vector2, cell: Vector2i) -> float:
	var d := cell_center(cell).distance_to(from_pos) / Constants.BLOCK_SIZE
	if d >= Constants.NIGHT_VIEWER_BLOCKS + 3.0:
		return 0.0
	var cap := float(LightMap.MAX_LIGHT)
	if d > Constants.NIGHT_VIEWER_BLOCKS:
		cap *= 1.0 - (d - Constants.NIGHT_VIEWER_BLOCKS) / 3.0
	return cap * sight_transmission(from_pos, cell)

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
	# A worn head lamp is a moving beacon (user request 2026-09-02): it lets
	# the player see at night the way a placed light does, but hands-free.
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node2D and ((p.has_method("equipped") \
				and float(Data.item(p.equipped("head")).get("stats", {}).get("light", 0.0)) > 0.0) \
				or p.get("puppet_lamp") == true): # LAN: remote bodies carry a lamp bit, not gear
			_beacon_cache.append((p as Node2D).global_position)
	return _beacon_cache

## dynamic = players (re-applied per move); static = lamps and dropped lights.
func _gather_light_sources(dynamic: bool = false) -> Array:
	var out := []
	if dynamic:
		for p in get_tree().get_nodes_in_group("player"):
			var level := Constants.PLAYER_SIGHT_LIGHT
			var held: Dictionary = Data.item(p.held_item())
			if held.get("use", {}).has("drop_light"):
				level = Constants.GLOWSTICK_LIGHT
			if p.has_method("equip_stat"): # helmet lamp / glow band (M5 gear)
				level = maxi(level, int(p.equip_stat("light")))
			if p.get("puppet_lamp") == true: # LAN: a remote body's lamp (no gear replica)
				level = maxi(level, Constants.PUPPET_LAMP_LIGHT)
			out.append({"cell": cell_at(p.global_position), "level": level})
		return out
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
	return out

## Building power (WS-17).
func update_power() -> void:
	if objects_root == null or Net.is_client(): # a client's powered set arrives from WorldSync._power
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
	Net.on_power_changed()

func _check_breakers() -> void:
	if objects_root == null:
		return
	var tripped := false
	for obj in objects_root.get_children():
		if obj is WorldObject and obj.def.kind == "breaker" and obj.powered_on:
			if water_sim.level_at(obj.cell) > 2:
				obj.powered_on = false
				notify_record_state(obj)
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
			if int(def.atlas_row) == 5:
				# A ladder item builds a 2-cell-wide ladder (user request 2026-09-05):
				# the aimed cell + the one to its right, both free; it hangs off any
				# neighbouring ladder cell or a solid neighbour of either half.
				var r := cell + Vector2i.RIGHT
				if not grid.in_bounds(r):
					return false
				for c: Vector2i in [cell, r]:
					if has_block_cell(c) or is_climbable_cell(c) or object_cells.has(c):
						return false
				return _has_neighbor_support(cell) or _has_neighbor_support(r) \
					or is_climbable_cell(cell + Vector2i.UP) or is_climbable_cell(cell + Vector2i.DOWN) \
					or is_climbable_cell(r + Vector2i.UP) or is_climbable_cell(r + Vector2i.DOWN) \
					or is_climbable_cell(cell + Vector2i.LEFT) or is_climbable_cell(r + Vector2i.RIGHT)
			return not has_block_cell(cell) and not is_climbable_cell(cell) and not object_cells.has(cell) \
				and (_has_neighbor_support(cell) or is_climbable_cell(cell + Vector2i.UP) or is_climbable_cell(cell + Vector2i.DOWN) \
					or is_climbable_cell(cell + Vector2i.LEFT) or is_climbable_cell(cell + Vector2i.RIGHT))
		_:
			return not has_block_cell(cell) and not object_cells.has(cell) \
				and not _cell_overlaps_body(cell, by) and _has_neighbor_support(cell)

func place_block(id: String, cell: Vector2i) -> bool:
	var def: Dictionary = Data.blocks.get(id, {})
	if def.is_empty() or not grid.in_bounds(cell) or Net.is_client():
		return false
	match def.layer:
		"back":
			grid.set_back(cell, _mat_for_block(def))
		"climb":
			if int(def.atlas_row) == 5: # a ladder is a 2-cell pair: both halves are player blocks
				var r := cell + Vector2i.RIGHT
				grid.set_climb(r, WorldGrid.C.LADDER)
				placed_blocks[_key(r, def.layer)] = {"id": id, "hp": float(def.hp), "layer": def.layer}
				_cell_changed(r)
			grid.set_climb(cell, WorldGrid.C.LADDER if int(def.atlas_row) == 5 else WorldGrid.C.ROPE)
		_:
			if water_sim != null:
				water_sim.displace(cell) # WS-24
			grid.set_structure(cell, _mat_for_block(def))
	placed_blocks[_key(cell, def.layer)] = {"id": id, "hp": float(def.hp), "layer": def.layer}
	_cell_changed(cell)
	return true

## The 2-cell ladder pair `cell` belongs to (left half first): a cell with a
## ladder to its left is a right half, one with a ladder to its right a left
## half; a lone cell is its own pair.
func ladder_pair(cell: Vector2i) -> Array:
	if grid.climb_at(cell) != WorldGrid.C.LADDER:
		return []
	if grid.climb_at(cell + Vector2i.LEFT) == WorldGrid.C.LADDER:
		return [cell + Vector2i.LEFT, cell]
	if grid.climb_at(cell + Vector2i.RIGHT) == WorldGrid.C.LADDER:
		return [cell, cell + Vector2i.RIGHT]
	return [cell]

## Rope placement (user request 2026-09-02, one cell per click since
## 2026-09-04): clicking anywhere on an existing rope adds the next cell at its
## BOTTOM, so you lengthen a line from a ledge click by click. Anchors need support above
## or a neighbour; the cells below just hang.
func can_place_rope(cell: Vector2i) -> bool:
	if grid == null or not grid.in_bounds(cell):
		return false
	if grid.climb_at(cell) == WorldGrid.C.ROPE:
		return true # extend an existing column
	return not has_block_cell(cell) and not is_climbable_cell(cell) and not object_cells.has(cell) \
		and (_has_neighbor_support(cell) or is_climbable_cell(cell + Vector2i.UP))

## Places up to `max_cells` rope cells downward from `cell` (or from the bottom
## of the column `cell` is part of). Returns how many were placed.
func place_rope(cell: Vector2i, max_cells: int) -> int:
	if grid == null or Net.is_client():
		return 0
	if grid.climb_at(cell) == WorldGrid.C.ROPE:
		while grid.climb_at(cell + Vector2i.DOWN) == WorldGrid.C.ROPE:
			cell += Vector2i.DOWN
		cell += Vector2i.DOWN # first cell below the column
	var hp := float(Data.blocks.get("rope", {}).get("hp", 5))
	var placed := 0
	while placed < max_cells and grid.in_bounds(cell) and not has_block_cell(cell) \
			and not is_climbable_cell(cell) and not object_cells.has(cell):
		grid.set_climb(cell, WorldGrid.C.ROPE)
		placed_blocks[_key(cell, "climb")] = {"id": "rope", "hp": hp, "layer": "climb"}
		_cell_changed(cell)
		placed += 1
		cell += Vector2i.DOWN
	return placed

## Plant a tree sapling on a planter (user request 2026-09-02): it sits one
## cell above the pot and grows via _grow_trees. Returns false if the space
## above is blocked (a plant already there, or a low ceiling).
## `at_cell` picks the SECTION of a wide planter (a planter box holds three
## trees, one per sapling-width section - user request 2026-09-04); the pot
## has a single section.
func plant_in_planter(planter, at_cell: Vector2i = Vector2i(-1, -1)) -> bool:
	var sd: Dictionary = Data.objects.get("tree_sapling", {})
	if sd.is_empty() or Net.is_client():
		return false
	var sw := maxi(int(sd.get("size", [2, 4])[0]), 1)
	var slots := maxi(int(planter.size.x) / sw, 1)
	var slot := 0
	if at_cell.x >= 0:
		slot = clampi((at_cell.x - int(planter.cell.x)) / sw, 0, slots - 1)
	var base: Vector2i = planter.cell + Vector2i(slot * sw, -int(planter.size.y)) # the row above the pot
	for dy in int(sd.get("size", [1, 2])[1]):
		for dx in sw:
			var c := base + Vector2i(dx, -dy)
			if not grid.in_bounds(c) or has_block_cell(c) or object_cells.has(c) or is_solid_cell(c):
				return false
	place_object("tree_sapling", base, true)
	return true

## Water the plant growing on a planter (user request 2026-09-02): a bucket of
## water surges it one growth stage right now. Returns 1 grew, 0 can't (mature
## / drowned / no room), -1 no plant to water.
## A wide planter waters the first section (west to east) whose plant can grow.
func water_plant_above(planter_cell: Vector2i) -> int:
	if Net.is_client():
		return 0
	var prec: Dictionary = object_cells.get(planter_cell, {})
	var psize: Array = prec.def.size if not prec.is_empty() else Data.objects.get("planter", {}).get("size", [2, 2])
	var sw := maxi(int(Data.objects.get("tree_sapling", {}).get("size", [2, 4])[0]), 1)
	var rec: Dictionary = {}
	var best := -1 # -1 no plant, 0 nothing can grow, 1 grew
	for slot in maxi(int(psize[0]) / sw, 1):
		var r: Dictionary = object_cells.get(planter_cell + Vector2i(slot * sw, -int(psize[1])), {})
		if r.is_empty() or r.get("def", {}).get("category", "") != "flora":
			continue
		best = maxi(best, 0)
		if r.def.get("grows_into", "") != "" and not is_water_cell(r.cell):
			rec = r
			break
	if rec.is_empty():
		return best
	var next_id: String = rec.def.get("grows_into", "")
	if next_id == "" or is_water_cell(rec.cell):
		return 0
	var nd: Dictionary = Data.objects.get(next_id, {})
	if nd.is_empty():
		return 0
	var ncell := Vector2i(rec.cell.x - (int(nd.size[0]) - int(rec.def.size[0])) / 2, rec.cell.y)
	if not _tree_space_free(rec, nd, ncell):
		return 0
	_replace_object_record(rec, next_id, ncell)
	return 1

func _key(cell: Vector2i, layer_name: String) -> Variant:
	return cell if layer_name == "blocks" else "%s:%d,%d" % [layer_name, cell.x, cell.y]

func _cell_changed(cell: Vector2i) -> void:
	_light_dirty = true
	_invalidate_sky(cell)
	if water_sim != null:
		water_sim.notify_changed(cell)
	if renderer != null:
		renderer.refresh_cell(cell)
	Net.on_cell_changed(cell) # the one funnel every grid/ledger write passes through

## Removes a player-placed block on the given layer; returns its item id or "".
func remove_block(cell: Vector2i, layer_name: String = "blocks") -> String:
	var key = _key(cell, layer_name)
	if not placed_blocks.has(key) or Net.is_client():
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

## Lift a ladder or rope cell out whole (user request 2026-09-04): generated
## runs included - the piece goes back to the bag as its item.
## A ladder lifts out as its whole 2-cell pair (one item).
func pickup_climbable(cell: Vector2i) -> String:
	var c := grid.climb_at(cell)
	if c == WorldGrid.C.NONE or Net.is_client():
		return ""
	var cells: Array = ladder_pair(cell) if c == WorldGrid.C.LADDER else [cell]
	for pc: Vector2i in cells:
		grid.set_climb(pc, WorldGrid.C.NONE)
		placed_blocks.erase(_key(pc, "climb"))
		_cell_changed(pc)
	return "ladder" if c == WorldGrid.C.LADDER else "rope"

## Background walls are cosmetic (WS-20/21): any wall can be knocked out.
func erase_back_wall(cell: Vector2i) -> bool:
	if not has_back_wall_cell(cell) or Net.is_client():
		return false
	placed_blocks.erase(_key(cell, "back"))
	grid.set_back(cell, WorldGrid.M.AIR)
	_cell_changed(cell)
	return true

## Tool hit. Returns "broken" | "damaged" | "too_hard" | "structure" | "none".
## `by` (the miner's position) makes the drop toss toward them.
func damage_block(cell: Vector2i, damage: float, tool_tier: int, by: Vector2 = Vector2.INF) -> String:
	if Net.is_client():
		return "none"
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
		Net.on_cell_changed(cell) # ledger hp changed, cell value didn't
		return "damaged"
	if layer_name == "climb" and entry.id == "ladder": # the other half of the pair goes with it (one drop)
		for pc: Vector2i in ladder_pair(cell):
			if pc != cell:
				remove_block(pc, layer_name)
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
		Net.on_cell_changed(cell) # crack state changed, cell value didn't
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
	var node = rec.get("node") if not rec.is_empty() else null
	return node if node != null and is_instance_valid(node) else null

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
	if def.has("grows_into"): # trees track the day this stage began (2026-09-02)
		rec["grow_day"] = day_count
	object_records.append(rec)
	if _record_solid(rec):
		_light_dirty = true
	for c in _record_cells(rec):
		object_cells[c] = rec
		if rec.def.kind == "door":
			_invalidate_sky(c)
		if water_sim != null and _record_solid(rec):
			water_sim.notify_changed(c)
	if rec.storage != null: # chest slot edits replicate as a record change
		rec.storage.changed.connect(func() -> void: Net.on_record_changed(rec))
	if not _suppress_record_hooks:
		Net.on_record_added(rec)
	return rec

## A live node's replicable state changed (door unlocked, breaker flipped,
## pump outlet set): bank it on the record and tell the peers.
func notify_record_state(obj: WorldObject) -> void:
	var rec: Dictionary = object_cells.get(obj.cell, {})
	if rec.is_empty() or rec.node != obj:
		return
	sync_record(rec, obj)
	Net.on_record_changed(rec)

## A record's fields changed with no node involved (UI chest edits, growth
## clocks): replicate as-is.
func notify_record_changed(rec: Dictionary) -> void:
	if not rec.is_empty():
		Net.on_record_changed(rec)

func _record_cells(rec: Dictionary) -> Array:
	var cells := []
	for dy in int(rec.def.size[1]):
		for dx in int(rec.def.size[0]):
			cells.append(Vector2i(rec.cell.x + dx, rec.cell.y - dy))
	return cells

## Place an object and instantiate it right away (player actions and tests
## always act near the camera, so the node exists from the start).
func place_object(id: String, cell: Vector2i, placed_by_player: bool) -> WorldObject:
	if Net.is_client():
		return null
	return _instantiate_record(add_object_record(id, cell, placed_by_player))

func _instantiate_record(rec: Dictionary) -> WorldObject:
	var obj: WorldObject = WORLD_OBJECT_SCENE.instantiate()
	obj.setup(rec.id, rec.cell, rec.placed)
	obj.storage = rec.storage # the record's inventory is the canonical one
	obj.global_position = cell_center(rec.cell) - Vector2.ONE * Constants.BLOCK_SIZE * 0.5
	objects_root.add_child(obj)
	obj.restore_state({"open": rec.open, "powered": rec.powered, "outlet": rec.outlet,
		"unlocked": rec.unlocked})
	if rec.def.kind == "light" and bool(rec.def.get("powered", false)):
		obj.set_powered(bool(rec.powered)) # a client never recomputes power: the record is the truth
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
	var key := _windows_key(center)
	if (_obj_window_center - center).length_squared() < 144 and key == _window_key: # < 12 cells moved
		return
	_obj_window_center = center
	_window_key = key
	var wins := _player_windows(center, Constants.OBJECT_WINDOW)
	var live := 0
	var changed := false
	for rec: Dictionary in object_records:
		var inside := _in_windows(wins, rec.cell)
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
	if Net.is_client():
		return
	_light_dirty = true
	var rec: Dictionary = object_cells.get(obj.cell, {})
	if rec.is_empty() or rec.get("node") != obj:
		# The cell lookup can miss when two gen-stamped objects overlap a cell
		# (the later record owns it). Fall back to an identity search so the
		# record always dies with its node - otherwise it keeps a freed `node`
		# and the next hover crashes (the curtains bug, 2026-09-01).
		rec = {}
		for r: Dictionary in object_records:
			if r.node == obj:
				rec = r
				break
	if not rec.is_empty():
		object_records.erase(rec)
		for c in _record_cells(rec):
			if object_cells.get(c) == rec:
				object_cells.erase(c)
			if rec.def.kind == "door":
				_invalidate_sky(c)
			if water_sim != null:
				water_sim.notify_changed(c)
		Net.on_record_removed(rec)
	pumps.erase(obj)
	obj.queue_free()

## Rooftop trees (user request 2026-09-01): each midnight every record whose
## def names a `grows_into` stage rolls `grow_chance` to swap itself for the
## next stage (sapling -> young -> mature). Records grow whether or not the
## node is streamed in; drowned or hemmed-in trees simply wait. Stages are
## plain scrap objects, so harvesting stays the normal scrap flow.
func _grow_trees() -> void:
	for rec: Dictionary in object_records.duplicate():
		var next_id: String = rec.def.get("grows_into", "")
		if next_id == "":
			continue
		# Deterministic, one stage per day (user request 2026-09-02): skip if
		# this stage began today; grow_day is set when the record is created.
		if int(rec.get("grow_day", day_count)) >= day_count:
			continue
		if is_water_cell(rec.cell):
			continue # drowned trees wait
		var nd: Dictionary = Data.objects.get(next_id, {})
		if nd.is_empty():
			continue
		var ncell := Vector2i(rec.cell.x - (int(nd.size[0]) - int(rec.def.size[0])) / 2, rec.cell.y)
		if _tree_space_free(rec, nd, ncell):
			_replace_object_record(rec, next_id, ncell)

## True when the next stage's footprint is clear (its own cells aside).
func _tree_space_free(rec: Dictionary, nd: Dictionary, ncell: Vector2i) -> bool:
	var own := _record_cells(rec)
	for dy in int(nd.size[1]):
		for dx in int(nd.size[0]):
			var c := Vector2i(ncell.x + dx, ncell.y - dy)
			if not grid.in_bounds(c):
				return false
			if own.has(c):
				continue
			if has_block_cell(c) or object_cells.has(c):
				return false
	return true

## Swap a record for another object id in place (tree growth): cells
## re-register, a live node rebuilds, placed/ownership carries over.
func _replace_object_record(rec: Dictionary, new_id: String, new_cell: Vector2i) -> void:
	var had_node: bool = rec.node != null
	_despawn_record(rec)
	object_records.erase(rec)
	for c in _record_cells(rec):
		if object_cells.get(c) == rec:
			object_cells.erase(c)
	_suppress_record_hooks = true # one replace delta, not add + replace
	var nrec := add_object_record(new_id, new_cell, rec.placed)
	_suppress_record_hooks = false
	if had_node:
		_instantiate_record(nrec)
	Net.on_record_replaced(rec, nrec)

## Called when an object's solidity changes in place (door toggled).
func notify_object_changed(obj: WorldObject) -> void:
	_light_dirty = true
	var rec: Dictionary = object_cells.get(obj.cell, {})
	if not rec.is_empty() and rec.node == obj:
		rec.open = obj.open
	if obj.def.kind == "door":
		for c in obj.covered_cells():
			_invalidate_sky(c)
	if water_sim != null:
		for c in obj.covered_cells():
			water_sim.notify_changed(c)
	if not rec.is_empty() and rec.node == obj:
		sync_record(rec, obj)
		Net.on_record_changed(rec)

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
	var band := floor_band_at(cell_at(pos)) # the floor's band, not the cell's (DistrictsOverhaul)
	var base := Data.enemy_stats(type_id, band)
	if base.is_empty():
		return {}
	var stats := {"hp": float(base.hp) * hp_mult, "damage": float(base.damage) * hp_mult,
		"speed": float(base.speed), "aggro": float(base.aggro)}
	var rec := {"type": type_id, "pos": pos, "hp": stats.hp, "band": band,
		"stats": stats, "mult": hp_mult, "night": night_spawn, "node": null}
	if Data.enemies[type_id].get("mode", "") == "fish":
		rec["stock"] = randi_range(Constants.FISH_STOCK_MIN, Constants.FISH_STOCK_MAX)
	rec["nid"] = next_net_id
	next_net_id += 1
	enemy_records.append(rec)
	Net.on_enemy_added(rec)
	return rec

## LAN Step 6 (client): mirror a host record as given — the host's nid, hp
## and band, stats re-derived from the same table; no hook, no id
## allocation. Idempotent by nid (a queued add after a reset updates in
## place). Returns the record ({} for an unknown type).
func add_enemy_replica(d: Dictionary) -> Dictionary:
	var type_id := String(d.type)
	if not Data.enemies.has(type_id):
		return {}
	var nid := int(d.nid)
	var band := String(d.get("band", "dry"))
	var mult := float(d.get("mult", 1.0))
	var base := Data.enemy_stats(type_id, band)
	if base.is_empty():
		return {}
	var stats := {"hp": float(base.hp) * mult, "damage": float(base.damage) * mult,
		"speed": float(base.speed), "aggro": float(base.aggro)}
	var rec: Dictionary = {}
	for r: Dictionary in enemy_records:
		if int(r.get("nid", -1)) == nid:
			rec = r
			break
	var fresh := rec.is_empty()
	if fresh:
		rec = {"type": type_id, "node": null, "nid": nid}
		enemy_records.append(rec)
	rec.pos = d.pos
	rec.hp = float(d.get("hp", stats.hp))
	rec.band = band
	rec.stats = stats
	rec.mult = mult
	rec.night = bool(d.get("night", false))
	if d.has("stock"):
		rec["stock"] = int(d.stock)
	var n = rec.node
	if n != null and is_instance_valid(n):
		n.puppet_state(rec.pos, rec.hp, 0, false)
	elif _enemy_in_window(rec):
		_instantiate_enemy(rec)
	return rec

## Client: drop every record + node (a `_reset` from the host follows).
func clear_enemy_replicas() -> void:
	for rec: Dictionary in enemy_records:
		_despawn_enemy(rec)
	enemy_records.clear()
	_enemy_window_center = Vector2i(-99999, -99999)

## Client: rebuild the enemy window around the local player right now
## (streamed positions moved records in or out of view).
func refresh_enemy_window() -> void:
	var p := Net.local_player() as Node2D
	if p == null or grid == null:
		return
	_enemy_window_center = Vector2i(-99999, -99999)
	_update_enemy_window(cell_at(p.global_position))

func _instantiate_enemy(rec: Dictionary) -> void:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.setup(rec) # puppet on a client (Enemy.setup reads Net.is_client)
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
	Net.on_enemy_removed(rec)

## Instantiate records near `center`, freeze the rest (the object-window
## pattern; enemies outside the window don't think or move).
func _update_enemy_window(center: Vector2i) -> void:
	var key := _windows_key(center)
	if (_enemy_window_center - center).length_squared() < 144 and key == _enemy_window_key:
		return
	_enemy_window_center = center
	_enemy_window_key = key
	var wins := _player_windows(center, Constants.ENEMY_WINDOW)
	var live := 0
	for rec: Dictionary in enemy_records:
		var inside := _in_windows(wins, cell_at(rec.pos))
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
	if Net.is_client():
		return # LAN: enemies pound on the host only
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
			Net.on_record_removed(rec)

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
		var cell := _open_surface_near(p.global_position, 40, 90)
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
	if x <= city_bounds.position.x + 2 or x >= city_bounds.end.x - 2:
		return # never into the pocket annex
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
	return _in_windows(_player_windows(_enemy_window_center, Constants.ENEMY_WINDOW), cell_at(rec.pos))

## Streaming windows follow players (LAN Step 1): on the host every player's
## surroundings run as nodes (the union of their windows); on a client only
## the local player's. `center` is the local player's cell (the caller's).
var _enemy_window_key: Array = []

func _player_windows(center: Vector2i, size: Vector2i) -> Array:
	var half: Vector2i = size / 2
	var wins: Array = [Rect2i(center - half, size)]
	if Net.is_server():
		for p in get_tree().get_nodes_in_group("player"):
			if p is Player and is_instance_valid(p):
				var c := cell_at(p.global_position)
				if c != center:
					wins.append(Rect2i(c - half, size))
	return wins

func _in_windows(wins: Array, cell: Vector2i) -> bool:
	for w: Rect2i in wins:
		if w.has_point(cell):
			return true
	return false

## Snapped (12-cell) centres of every other player: the windows rebuild when
## any of them moves a step, not only the local one.
func _windows_key(center: Vector2i) -> Array:
	var key: Array = []
	if Net.is_server():
		for p in get_tree().get_nodes_in_group("player"):
			if p is Player and is_instance_valid(p):
				var c := cell_at(p.global_position)
				if c != center:
					key.append(Vector2i(floori(c.x / 12.0), floori(c.y / 12.0)))
	return key

# --- Items ---

## Debris tint per material, for the break burst (user request 2026-09-02).
const HARVEST_TINT := {
	"wood": Color(0.60, 0.42, 0.24), "scrap_metal": Color(0.56, 0.61, 0.67),
	"plastic": Color(0.42, 0.72, 0.52), "stone": Color(0.55, 0.55, 0.56),
	"cloth": Color(0.78, 0.72, 0.58), "iron": Color(0.62, 0.64, 0.68),
	"steel": Color(0.70, 0.72, 0.78), "tree_seed": Color(0.50, 0.36, 0.22),
}
var _puff_tex: ImageTexture

## A short one-shot debris burst where an object breaks into resources (user
## request 2026-09-02): the icons then pop out and hover for pickup.
func spawn_break_puff(pos: Vector2, item_id: String, local_only: bool = false) -> void:
	if items_root == null:
		return
	if _puff_tex == null:
		var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_puff_tex = ImageTexture.create_from_image(img)
	var p := CPUParticles2D.new()
	p.texture = _puff_tex
	p.one_shot = true
	p.emitting = true
	p.amount = 12
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 120.0
	p.gravity = Vector2(0, 18.0 * Constants.BLOCK_SIZE)
	p.initial_velocity_min = 4.0 * Constants.BLOCK_SIZE
	p.initial_velocity_max = 10.0 * Constants.BLOCK_SIZE
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color = HARVEST_TINT.get(item_id, Color(0.62, 0.56, 0.5))
	p.global_position = pos
	items_root.add_child(p)
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)
	if not local_only:
		Net.on_effect("puff", pos, item_id)

## Host-only (LAN): a client's items arrive as WorldSync replicas with the
## host's net ids, so a local spawn would only ever be a duplicate.
func spawn_item(id: String, count: int, pos: Vector2, velocity: Vector2 = Vector2.ZERO) -> WorldItem:
	if Net.is_client() or items_root == null:
		return null
	var it: WorldItem = WORLD_ITEM_SCENE.instantiate()
	it.setup(id, count, velocity)
	it.global_position = pos
	it.net_id = next_net_id
	next_net_id += 1
	item_by_net_id[it.net_id] = it
	items_root.add_child(it)
	Net.on_item_spawned(it)
	return it

## Death backpack (CC-07): holds the dropped inventory, floats like any
## buoyant item, recovered on touch. Lives under items_root so saves see it.
func spawn_backpack(slots: Array, pos: Vector2) -> Node2D:
	if Net.is_client() or items_root == null:
		return null
	var pack: Node2D = BACKPACK_SCENE.instantiate()
	pack.slots = slots
	pack.global_position = pos
	pack.net_id = next_net_id
	next_net_id += 1
	item_by_net_id[pack.net_id] = pack
	items_root.add_child(pack)
	Net.on_backpack_spawned(pack)
	return pack

# --- LAN replicas (client side; Net/WorldSync calls these, MultiplayerImpl §6) ---
# Each writes the replica exactly as the host's delta says and repaints —
# no Net hooks, no water wake, no game logic, so nothing echoes back.

## One cell delta: the three layers, the placed-block ledger entries per
## layer ({layer: entry} or null) and the structure crack hp (or null).
func apply_cell_replica(cell: Vector2i, structure: int, back: int, climb: int, placed, damage) -> void:
	if grid == null or not grid.in_bounds(cell):
		return
	grid.set_structure(cell, structure)
	grid.set_back(cell, back)
	grid.set_climb(cell, climb)
	for layer in ["blocks", "back", "climb"]:
		var key = _key(cell, layer)
		if placed is Dictionary and placed.has(layer):
			placed_blocks[key] = (placed[layer] as Dictionary).duplicate()
		else:
			placed_blocks.erase(key)
	if damage == null:
		structure_damage.erase(cell)
	else:
		structure_damage[cell] = float(damage)
	damage_rev += 1
	_light_dirty = true
	_invalidate_sky(cell)
	if renderer != null:
		renderer.refresh_cell(cell)

## [index, level] pairs (the sim's own indexing) — the per-tick water delta.
func apply_water_replica(pairs: PackedInt32Array) -> void:
	if water_sim == null:
		return
	var n := water_sim.levels.size()
	var i := 0
	while i + 1 < pairs.size():
		var idx := pairs[i]
		if idx >= 0 and idx < n:
			water_sim.levels[idx] = clampi(pairs[i + 1], 0, WaterSim.MAX_LEVEL)
		i += 2
	water_sim.changed_last_tick += pairs.size() / 2 # the light pass watches this

## A whole window of levels, row-major (the periodic resync).
func apply_water_rect_replica(rect: Rect2i, bytes: PackedByteArray) -> void:
	if water_sim == null:
		return
	rect = rect.intersection(water_sim.bounds)
	if rect.size.x <= 0 or bytes.size() < rect.size.x * rect.size.y:
		return
	var src := 0
	for y in range(rect.position.y, rect.end.y):
		var i0: int = water_sim._idx(Vector2i(rect.position.x, y))
		for dx in rect.size.x:
			water_sim.levels[i0 + dx] = bytes[src + dx]
		src += rect.size.x
	water_sim.changed_last_tick += rect.size.x * rect.size.y

## Compact record dict (WorldSync._compact) -> a new record, instantiated
## right away when it lands inside the local window.
func add_record_replica(d: Dictionary) -> Dictionary:
	var id := String(d.get("id", ""))
	if not Data.objects.has(id) or not d.has("cell"):
		return {}
	var rec := add_object_record(id, d.cell, bool(d.get("placed", false)))
	_copy_record_fields(rec, d)
	if _in_windows(_player_windows(_obj_window_center, Constants.OBJECT_WINDOW), rec.cell):
		_instantiate_record(rec)
	return rec

func _copy_record_fields(rec: Dictionary, d: Dictionary) -> void:
	rec.open = bool(d.get("open", rec.open))
	rec.powered = bool(d.get("powered", rec.powered))
	rec.unlocked = bool(d.get("unlocked", rec.get("unlocked", false)))
	rec.outlet = d.get("outlet", rec.outlet)
	for k in ["link", "door", "grow_day"]:
		if d.has(k):
			rec[k] = d[k]
	if rec.storage != null and d.has("storage"):
		var slots: Array = (d.storage as Array).duplicate(true)
		for i in slots.size():
			slots[i] = ItemMods.clean_stack(slots[i]) # D3: old-format mods drop off, the item stays
		slots.resize(rec.storage.slots.size())
		rec.storage.slots = slots
		rec.storage.changed.emit() # an open chest UI refreshes; the Net hook is a no-op here
	if rec.def.kind == "door":
		_light_dirty = true
		for c in _record_cells(rec):
			_invalidate_sky(c)

## The record anchored at `cell` with this id (a later record may own the
## shared cell in object_cells, so fall back to a scan).
func _record_replica_at(cell: Vector2i, id: String) -> Dictionary:
	var rec: Dictionary = object_cells.get(cell, {})
	if not rec.is_empty() and rec.cell == cell and (id == "" or String(rec.id) == id):
		return rec
	for r: Dictionary in object_records:
		if r.cell == cell and (id == "" or String(r.id) == id):
			return r
	return {}

func remove_record_replica(cell: Vector2i, id: String) -> void:
	var rec := _record_replica_at(cell, id)
	if rec.is_empty():
		return
	var obj = rec.node
	rec.node = null
	if obj != null and is_instance_valid(obj):
		pumps.erase(obj)
		obj.queue_free()
	object_records.erase(rec)
	for c in _record_cells(rec):
		if object_cells.get(c) == rec:
			object_cells.erase(c)
		if rec.def.kind == "door":
			_invalidate_sky(c)
	_light_dirty = true

func change_record_replica(cell: Vector2i, fields: Dictionary) -> void:
	var rec := _record_replica_at(cell, String(fields.get("id", "")))
	if rec.is_empty():
		return
	_copy_record_fields(rec, fields)
	refresh_record_node(rec)

## Push a record's replicable state onto its live node (open look, lock,
## power, outlet) without emitting the host hooks. Storage is shared already.
func refresh_record_node(rec: Dictionary) -> void:
	var obj = rec.get("node")
	if obj == null or not is_instance_valid(obj):
		return
	obj.apply_replica_state({"open": rec.open, "powered": rec.powered, "unlocked": rec.get("unlocked", false),
		"outlet": rec.outlet})

## Items (client): created with the host's net id, physics runs locally,
## pickup never (WorldItem._try_pickup is host-only).
func spawn_item_replica(net_id: int, id: String, count: int, pos: Vector2, vel: Vector2) -> WorldItem:
	if items_root == null:
		return null
	var existing = item_by_net_id.get(net_id)
	if existing != null and is_instance_valid(existing):
		return existing as WorldItem
	var it: WorldItem = WORLD_ITEM_SCENE.instantiate()
	it.setup(id, count, vel)
	it.global_position = pos
	it.net_id = net_id
	item_by_net_id[net_id] = it
	items_root.add_child(it)
	return it

func spawn_backpack_replica(net_id: int, slots: Array, pos: Vector2) -> Node2D:
	if items_root == null:
		return null
	var existing = item_by_net_id.get(net_id)
	if existing != null and is_instance_valid(existing):
		return existing
	var pack: Node2D = BACKPACK_SCENE.instantiate()
	pack.slots = slots.duplicate(true)
	pack.global_position = pos
	pack.net_id = net_id
	item_by_net_id[net_id] = pack
	items_root.add_child(pack)
	return pack

## Item or backpack by net id (both share the id space).
func remove_item_replica(net_id: int) -> void:
	var node = item_by_net_id.get(net_id)
	item_by_net_id.erase(net_id)
	if node != null and is_instance_valid(node):
		node.queue_free()

## [net_id, pos, vel] x N: the host's periodic position resync.
func apply_item_positions(packed: Array) -> void:
	var i := 0
	while i + 2 < packed.size():
		var node = item_by_net_id.get(int(packed[i]))
		if node != null and is_instance_valid(node):
			node.global_position = packed[i + 1]
			node.velocity = packed[i + 2]
		i += 3

## READY handshake: drop every item/backpack (the host re-lists them with ids).
func reset_items_replica() -> void:
	item_by_net_id.clear()
	if items_root == null:
		return
	for it in items_root.get_children():
		if it is WorldItem or it is Backpack:
			it.queue_free()

func apply_clock_replica(p_time_of_day: float, p_day_count: int, p_next_red_moon_day: int, p_red_moon_active: bool) -> void:
	time_of_day = p_time_of_day
	day_count = p_day_count
	next_red_moon_day = p_next_red_moon_day
	red_moon_active = p_red_moon_active

## [[cell, on], ...] for wired lights and breakers: records + live nodes,
## never recomputed here (update_power is host-only).
func apply_power_replica(lights: Array, breakers: Array) -> void:
	for row in lights + breakers:
		var rec: Dictionary = object_cells.get(row[0], {})
		if rec.is_empty():
			continue
		rec.powered = bool(row[1])
		refresh_record_node(rec)
	_light_dirty = true
