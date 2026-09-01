class_name WorldGrid
extends RefCounted
## The whole world's tile state in RAM (CT-28): three byte layers over one
## rect — structure materials, background walls, climbables. Rendering and
## collision are windowed around the camera by StructureRenderer; every
## gameplay query reads these arrays directly.

enum M { AIR = 0, STONE = 1, WOOD = 2, METAL = 3, PLASTIC = 4, VOID = 8 } # = atlas row + 1
## VOID (atlas row 7, solid black): the nothing around interior pockets —
## solid to physics, water, and sight; unbreakable (no STRUCTURE_TIER entry).
enum C { NONE = 0, LADDER = 1, ROPE = 2 }

var bounds: Rect2i
var structure := PackedByteArray()
var back := PackedByteArray()
var climb := PackedByteArray()

func _init(p_bounds: Rect2i) -> void:
	bounds = p_bounds
	var n := bounds.size.x * bounds.size.y
	structure.resize(n)
	back.resize(n)
	climb.resize(n)

func in_bounds(cell: Vector2i) -> bool:
	return bounds.has_point(cell)

func _idx(cell: Vector2i) -> int:
	return (cell.y - bounds.position.y) * bounds.size.x + (cell.x - bounds.position.x)

func structure_at(cell: Vector2i) -> int:
	return structure[_idx(cell)] if in_bounds(cell) else M.AIR

func back_at(cell: Vector2i) -> int:
	return back[_idx(cell)] if in_bounds(cell) else M.AIR

func climb_at(cell: Vector2i) -> int:
	return climb[_idx(cell)] if in_bounds(cell) else C.NONE

func set_structure(cell: Vector2i, mat: int) -> void:
	if in_bounds(cell):
		structure[_idx(cell)] = mat

func set_back(cell: Vector2i, mat: int) -> void:
	if in_bounds(cell):
		back[_idx(cell)] = mat

func set_climb(cell: Vector2i, kind: int) -> void:
	if in_bounds(cell):
		climb[_idx(cell)] = kind

## Stable content hash for determinism checks (CT-21).
func content_hash() -> int:
	return hash([structure, back, climb])
