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
var water: TileMapLayer
var climbables: TileMapLayer
var items_root: Node
var objects_root: Node
var spawn_position: Vector2 # feet position (bottom-center) of the spawn

## Player-placed blocks (WS-22): cell -> {id, hp, layer}. Anything in a tile
## layer that is NOT here is building structure and unbreakable (GL-01).
var placed_blocks: Dictionary = {}
## Every cell covered by an object -> WorldObject.
var object_cells: Dictionary = {}

func register(p_blocks: TileMapLayer, p_water: TileMapLayer, p_climbables: TileMapLayer,
		p_spawn: Vector2, p_back_walls: TileMapLayer = null, p_items_root: Node = null,
		p_objects_root: Node = null) -> void:
	blocks = p_blocks
	water = p_water
	climbables = p_climbables
	back_walls = p_back_walls
	items_root = p_items_root
	objects_root = p_objects_root
	spawn_position = p_spawn
	placed_blocks.clear()
	object_cells.clear()

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
	return water != null and water.get_cell_source_id(cell) != -1

func is_water(global_pos: Vector2) -> bool:
	return is_water_cell(cell_at(global_pos))

func is_climbable_cell(cell: Vector2i) -> bool:
	return climbables != null and climbables.get_cell_source_id(cell) != -1

func is_climbable(global_pos: Vector2) -> bool:
	return is_climbable_cell(cell_at(global_pos))

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

## Global y of the water surface above global_pos (top edge of the
## highest contiguous water cell in that column).
func water_surface_y(global_pos: Vector2) -> float:
	return cell_top_y(_surface_cell(global_pos))

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
			return not has_block_cell(cell) and not object_cells.has(cell) and not is_water_cell(cell) \
				and not _cell_overlaps_body(cell, by) and _has_neighbor_support(cell)

func place_block(id: String, cell: Vector2i) -> bool:
	var def: Dictionary = Data.blocks.get(id, {})
	if def.is_empty():
		return false
	var layer := _layer_for(def.layer)
	if layer == null:
		return false
	var variant := posmod(hash(cell), 5)
	layer.set_cell(cell, 0, Vector2i(variant, def.atlas_row))
	placed_blocks[_key(cell, def.layer)] = {"id": id, "hp": float(def.hp), "layer": def.layer}
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
	for dy in h:
		for dx in w:
			var c := Vector2i(cell.x + dx, cell.y - dy)
			if has_block_cell(c) or object_cells.has(c) or is_water_cell(c):
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
	return obj

func remove_object(obj: WorldObject) -> void:
	for c in obj.covered_cells():
		if object_cells.get(c) == obj:
			object_cells.erase(c)
	obj.queue_free()

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
