extends Node
## World authority layer (CC-06). Owns the canonical world state — tile
## layers, water, climbables, placed blocks, objects, dropped items, spawn —
## and answers every world query. In single-player this node *is* the host;
## in LAN it runs only on the host and clients receive replicated state.
## Gameplay code never touches the TileMapLayers directly: it asks World.
##
## M0/M1: static placeholder water (a tile layer). The cellular sim (M2)
## replaces the storage behind is_water()/water_surface_y() without
## changing callers.

const WORLD_ITEM_SCENE := preload("res://scenes/items/world_item.tscn")
const WORLD_OBJECT_SCENE := preload("res://scenes/objects/world_object.tscn")

var blocks: TileMapLayer
var back_walls: TileMapLayer
var climbables: TileMapLayer
var items_root: Node
var objects_root: Node
var spawn_position: Vector2 # feet position (bottom-center) of the spawn
var water_sim: WaterSim
var pumps: Array = [] # WorldObjects of kind "pump"
var light_map: LightMap
var _light_tick: int = 0

## Player-placed blocks (WS-22): cell -> {id, hp, layer}. Anything in a tile
## layer that is NOT here is building structure and unbreakable (GL-01).
var placed_blocks: Dictionary = {}
## Every cell covered by an object -> WorldObject.
var object_cells: Dictionary = {}

func register(p_blocks: TileMapLayer, p_water_bounds: Rect2i, p_climbables: TileMapLayer,
		p_spawn: Vector2, p_back_walls: TileMapLayer = null, p_items_root: Node = null,
		p_objects_root: Node = null) -> void:
	blocks = p_blocks
	climbables = p_climbables
	back_walls = p_back_walls
	items_root = p_items_root
	objects_root = p_objects_root
	spawn_position = p_spawn
	placed_blocks.clear()
	object_cells.clear()
	pumps.clear()
	water_sim = WaterSim.new(p_water_bounds, is_solid_cell)
	water_sim.budget_per_tick = Constants.WATER_BUDGET_PER_TICK
	light_map = LightMap.new(p_water_bounds)

func _physics_process(_delta: float) -> void:
	if water_sim == null:
		return
	_tick_pumps()
	water_sim.tick()
	_light_tick += 1
	if _light_tick % Constants.BREAKER_CHECK_TICKS == 0:
		_check_breakers()
	if _light_tick % Constants.LIGHT_RECOMPUTE_TICKS == 0:
		light_map.compute(is_solid_cell, water_sim.level_at, _gather_light_sources())

# --- Lighting (WS-17) + fog of war ---

func light_at(cell: Vector2i) -> int:
	return light_map.light_at(cell) if light_map != null else LightMap.MAX_LIGHT

## What a viewer at `viewer_pos` actually sees at `cell`: tile light capped
## by sight falloff with distance — the fog of war.
func visibility_at(cell: Vector2i, viewer_pos: Vector2) -> float:
	var d := cell_center(cell).distance_to(viewer_pos) / Constants.BLOCK_SIZE
	var cap := float(LightMap.MAX_LIGHT)
	if d > Constants.SIGHT_FULL_BLOCKS:
		cap = maxf(cap - (d - Constants.SIGHT_FULL_BLOCKS) * Constants.SIGHT_FADE_PER_BLOCK, 0.0)
	return minf(float(light_at(cell)), cap)

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
			level = Constants.GLOWSTICK_LIGHT # carried glowstick glows in hand
		out.append({"cell": cell_at(p.global_position), "level": level})
	return out

## Building power (WS-17): wired lights turn on when a switched-on breaker
## is in range; flooding a breaker trips it off.
func update_power() -> void:
	if objects_root == null:
		return
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
				obj.powered_on = false # flooding trips the breaker (WS-17)
				tripped = true
	if tripped:
		update_power()

## Pumps (GL-16): move water from the pump's intake cell to its outlet at a
## fixed rate; the sim's own flow refills the intake from the connected body.
func _tick_pumps() -> void:
	for pump in pumps:
		if not is_instance_valid(pump) or pump.outlet_cell == WorldObject.NO_OUTLET:
			continue
		var intake: Vector2i = pump.cell
		var taken := water_sim.remove_water_spread(intake, Constants.PUMP_UNITS_PER_TICK)
		if taken > 0:
			var leftover := water_sim.add_water_spread(pump.outlet_cell, taken)
			if leftover > 0: # receiving side completely full: stall (put it back)
				water_sim.add_water_spread(intake, leftover)

func is_ready() -> bool:
	return blocks != null

func set_spawn(feet_position: Vector2) -> void:
	spawn_position = feet_position

# --- Coordinate helpers ---

func cell_at(global_pos: Vector2) -> Vector2i:
	return blocks.local_to_map(blocks.to_local(global_pos))

func cell_center(cell: Vector2i) -> Vector2:
	return blocks.to_global(blocks.map_to_local(cell))

func cell_top_y(cell: Vector2i) -> float:
	return cell_center(cell).y - Constants.BLOCK_SIZE * 0.5

func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell_center(cell) - Vector2.ONE * Constants.BLOCK_SIZE * 0.5, Vector2.ONE * Constants.BLOCK_SIZE)

# --- Queries ---

func is_solid_cell(cell: Vector2i) -> bool:
	if blocks.get_cell_source_id(cell) != -1:
		return true
	var obj: WorldObject = object_cells.get(cell)
	return obj != null and obj.is_solid()

func is_solid(global_pos: Vector2) -> bool:
	return is_solid_cell(cell_at(global_pos))

func has_block_cell(cell: Vector2i) -> bool:
	return blocks.get_cell_source_id(cell) != -1

func has_back_wall_cell(cell: Vector2i) -> bool:
	return back_walls != null and back_walls.get_cell_source_id(cell) != -1

func is_water_cell(cell: Vector2i) -> bool:
	return water_sim != null and water_sim.level_at(cell) > 0

## Partial-cell aware: a point is in water only below the cell's fill surface.
func is_water(global_pos: Vector2) -> bool:
	var cell := cell_at(global_pos)
	if not is_water_cell(cell):
		return false
	return global_pos.y >= water_sim.surface_y_in_cell(cell)

func is_climbable_cell(cell: Vector2i) -> bool:
	return climbables != null and climbables.get_cell_source_id(cell) != -1

func is_climbable(global_pos: Vector2) -> bool:
	return is_climbable_cell(cell_at(global_pos))

const LADDER_ATLAS_ROW := 5 # ropes (row 6) stay pass-through

func is_ladder_cell(cell: Vector2i) -> bool:
	return climbables != null and climbables.get_cell_source_id(cell) != -1 \
		and climbables.get_cell_atlas_coords(cell).y == LADDER_ATLAS_ROW

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

## Current push (px/s) on a body at global_pos (WS-16).
func current_at(global_pos: Vector2) -> Vector2:
	if water_sim == null:
		return Vector2.ZERO
	return water_sim.flow_at(cell_at(global_pos)) * Constants.CURRENT_PUSH

## True if the water column above global_pos meets air (not a ceiling), so
## a swimmer there can surface and breathe.
func surface_has_air(global_pos: Vector2) -> bool:
	return not is_solid_cell(_surface_cell(global_pos) + Vector2i.UP)

## True if no solid block overlaps the given global-space rect.
func rect_is_clear(rect: Rect2) -> bool:
	var shrunk := rect.grow(-0.5) # ignore exact edge contact
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

# --- Blocks (WS-12/21/22, GL-01) ---

func _layer_for(layer_name: String) -> TileMapLayer:
	match layer_name:
		"back":
			return back_walls
		"climb":
			return climbables
		_:
			return blocks

func can_place_block(id: String, cell: Vector2i, by: CharacterBody2D = null) -> bool:
	var def: Dictionary = Data.blocks.get(id, {})
	if def.is_empty():
		return false
	match def.layer:
		"back":
			return not has_back_wall_cell(cell) and not has_block_cell(cell) and not object_cells.has(cell) and _has_neighbor_support(cell)
		"climb":
			return not has_block_cell(cell) and not is_climbable_cell(cell) and not object_cells.has(cell) \
				and (_has_neighbor_support(cell) or is_climbable_cell(cell + Vector2i.UP) or is_climbable_cell(cell + Vector2i.DOWN))
		_:
			# Placing into water is allowed — it displaces or destroys (WS-24).
			return not has_block_cell(cell) and not object_cells.has(cell) \
				and not _cell_overlaps_body(cell, by) and _has_neighbor_support(cell)

func place_block(id: String, cell: Vector2i) -> bool:
	var def: Dictionary = Data.blocks.get(id, {})
	if def.is_empty():
		return false
	var layer := _layer_for(def.layer)
	if layer == null:
		return false
	if def.layer == "blocks" and water_sim != null:
		water_sim.displace(cell) # WS-24: displace if possible, destroy if enclosed
	var variant := posmod(hash(cell), 5)
	layer.set_cell(cell, 0, Vector2i(variant, def.atlas_row))
	placed_blocks[_key(cell, def.layer)] = {"id": id, "hp": float(def.hp), "layer": def.layer}
	if water_sim != null:
		water_sim.notify_changed(cell)
	return true

func _key(cell: Vector2i, layer_name: String) -> Variant:
	return cell if layer_name == "blocks" else "%s:%d,%d" % [layer_name, cell.x, cell.y]

## Removes a player-placed block on the given layer; returns its item id or "".
func remove_block(cell: Vector2i, layer_name: String = "blocks") -> String:
	var key = _key(cell, layer_name)
	if not placed_blocks.has(key):
		return ""
	var entry: Dictionary = placed_blocks[key]
	_layer_for(layer_name).erase_cell(cell)
	placed_blocks.erase(key)
	if layer_name == "blocks" and water_sim != null:
		water_sim.notify_changed(cell) # removing a block wakes adjacent water
	return entry.id

## Background walls are cosmetic (WS-20/21): any wall can be knocked out with
## a hammer. Player-placed walls return their item id; structure walls return
## "" (no free materials) but are still erased.
func erase_back_wall(cell: Vector2i) -> bool:
	if not has_back_wall_cell(cell):
		return false
	placed_blocks.erase(_key(cell, "back"))
	back_walls.erase_cell(cell)
	return true

## Tool hit on the block at cell. Returns "broken" | "damaged" | "too_hard" | "structure" | "none".
func damage_block(cell: Vector2i, damage: float, tool_tier: int) -> String:
	var layer_name := "blocks"
	if not has_block_cell(cell):
		if is_climbable_cell(cell):
			layer_name = "climb"
		else:
			return "none"
	var key = _key(cell, layer_name)
	if not placed_blocks.has(key):
		return "structure"
	var entry: Dictionary = placed_blocks[key]
	var def: Dictionary = Data.blocks[entry.id]
	if tool_tier < int(def.hardness) or damage <= 0.0:
		return "too_hard"
	entry.hp -= damage
	if entry.hp > 0.0:
		return "damaged"
	remove_block(cell, layer_name)
	spawn_item(entry.id, 1, cell_center(cell))
	return "broken"

# --- Objects ---

func object_at(cell: Vector2i) -> WorldObject:
	return object_cells.get(cell)

func can_place_object(id: String, cell: Vector2i, by: CharacterBody2D = null) -> bool:
	var def: Dictionary = Data.objects.get(id, {})
	if def.is_empty():
		return false
	var w: int = def.size[0]
	var h: int = def.size[1]
	var allow_water: bool = def.get("place_in_water", false) # pumps work submerged
	for dy in h:
		for dx in w:
			var c := Vector2i(cell.x + dx, cell.y - dy)
			# A shallow film (level <= 2, the residue a pump cannot lift) does
			# not block furniture; deeper water does.
			var deep_water := water_sim != null and water_sim.level_at(c) > 2
			if has_block_cell(c) or object_cells.has(c) or (deep_water and not allow_water):
				return false
			if def.kind == "door" and _cell_overlaps_body(c, by):
				return false
	# stands on a fully solid row (doors also need a lintel-free frame, ignored for M1)
	for dx in w:
		if not has_block_cell(Vector2i(cell.x + dx, cell.y + 1)):
			return false
	return true

func place_object(id: String, cell: Vector2i, placed_by_player: bool) -> WorldObject:
	var obj: WorldObject = WORLD_OBJECT_SCENE.instantiate()
	obj.setup(id, cell, placed_by_player)
	obj.global_position = cell_center(cell) - Vector2.ONE * Constants.BLOCK_SIZE * 0.5
	objects_root.add_child(obj)
	for c in obj.covered_cells():
		object_cells[c] = obj
		if water_sim != null and obj.is_solid():
			water_sim.notify_changed(c)
	if obj.def.kind == "pump":
		pumps.append(obj)
	return obj

func remove_object(obj: WorldObject) -> void:
	for c in obj.covered_cells():
		if object_cells.get(c) == obj:
			object_cells.erase(c)
		if water_sim != null:
			water_sim.notify_changed(c)
	pumps.erase(obj)
	obj.queue_free()

## Called when an object's solidity changes in place (door opened/closed).
func notify_object_changed(obj: WorldObject) -> void:
	if water_sim != null:
		for c in obj.covered_cells():
			water_sim.notify_changed(c)

## Station ids within `reach` px of `pos` (GL-04: station-filtered crafting).
func stations_near(pos: Vector2, reach: float) -> Array:
	var out := ["hand"]
	if objects_root == null:
		return out
	for obj in objects_root.get_children():
		if obj is WorldObject and obj.def.kind == "station" and obj.center().distance_to(pos) <= reach:
			if not out.has(obj.def.station):
				out.append(obj.def.station)
	return out

# --- Items ---

func spawn_item(id: String, count: int, pos: Vector2, velocity: Vector2 = Vector2.ZERO) -> WorldItem:
	var it: WorldItem = WORLD_ITEM_SCENE.instantiate()
	it.setup(id, count, velocity)
	it.global_position = pos
	items_root.add_child(it)
	return it
