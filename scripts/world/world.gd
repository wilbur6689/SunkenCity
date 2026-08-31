extends Node
## World authority layer (CC-06). Owns the canonical world state — tile
## layers, water, climbables, spawn — and answers every world query. In
## single-player this node *is* the host; in LAN it runs only on the host
## and clients receive replicated state. Gameplay code never touches the
## TileMapLayers directly: it asks World.
##
## M0: static placeholder water (a tile layer). The cellular sim (M2)
## replaces the storage behind is_water()/water_surface_y() without
## changing callers.

var blocks: TileMapLayer
var water: TileMapLayer
var climbables: TileMapLayer
var spawn_position: Vector2 # feet position (bottom-center) of the spawn

func register(p_blocks: TileMapLayer, p_water: TileMapLayer, p_climbables: TileMapLayer,
		p_spawn: Vector2) -> void:
	blocks = p_blocks
	water = p_water
	climbables = p_climbables
	spawn_position = p_spawn

func is_ready() -> bool:
	return blocks != null

# --- Coordinate helpers ---

func cell_at(global_pos: Vector2) -> Vector2i:
	return blocks.local_to_map(blocks.to_local(global_pos))

func cell_center(cell: Vector2i) -> Vector2:
	return blocks.to_global(blocks.map_to_local(cell))

func cell_top_y(cell: Vector2i) -> float:
	return cell_center(cell).y - Constants.BLOCK_SIZE * 0.5

# --- Queries ---

func is_solid_cell(cell: Vector2i) -> bool:
	return blocks.get_cell_source_id(cell) != -1

func is_solid(global_pos: Vector2) -> bool:
	return is_solid_cell(cell_at(global_pos))

func is_water_cell(cell: Vector2i) -> bool:
	return water != null and water.get_cell_source_id(cell) != -1

func is_water(global_pos: Vector2) -> bool:
	return is_water_cell(cell_at(global_pos))

func is_climbable_cell(cell: Vector2i) -> bool:
	return climbables != null and climbables.get_cell_source_id(cell) != -1

func is_climbable(global_pos: Vector2) -> bool:
	return is_climbable_cell(cell_at(global_pos))

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
