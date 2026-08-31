extends Node2D
## M0 test tower, built programmatically from the placeholder palette.
## Materials map to atlas rows; the shade (atlas column 0-4) is picked by a
## position hash so repeated materials get variety. Replaced by real
## world-gen in M3; the palette PNG is swapped for real sprite sheets later.

enum Mat { STONE = 0, WOOD = 1, METAL = 2, PLASTIC = 3 }

const WIDTH := 40          # tower width in blocks
const FLOOR_H := 6         # floor-to-floor height (WS-11)
const FLOOR_COUNT := 4
const SHAFT_X := 33        # elevator-shaft gap, 3 blocks wide
const SHAFT_W := 3

@onready var blocks: TileMapLayer = $Blocks
@onready var back_walls: TileMapLayer = $BackWalls
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var player: CharacterBody2D = $Player

func _ready() -> void:
	_build_tower()
	var spawn_cell := Vector2i(5, FLOOR_COUNT * FLOOR_H - 1)
	spawn_point.global_position = blocks.map_to_local(spawn_cell)
	player.global_position = spawn_point.global_position

func _set_block(x: int, y: int, mat: Mat) -> void:
	blocks.set_cell(Vector2i(x, y), 0, Vector2i(_shade(x, y), mat))

func _set_back(x: int, y: int, mat: Mat) -> void:
	back_walls.set_cell(Vector2i(x, y), 0, Vector2i(_shade(x + 7, y + 3), mat))

func _shade(x: int, y: int) -> int:
	return posmod(hash(Vector2i(x, y)), 5)

func _fill(x0: int, y0: int, x1: int, y1: int, mat: Mat, fn: Callable) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			fn.call(x, y, mat)

func _build_tower() -> void:
	var bottom := FLOOR_COUNT * FLOOR_H # ground slab row

	# Background walls (cosmetic, WS-20): stone interior facing
	_fill(1, 1, WIDTH - 2, bottom - 1, Mat.STONE, _set_back)

	# Outer walls: stone, full height
	_fill(0, 0, 0, bottom, Mat.STONE, _set_block)
	_fill(WIDTH - 1, 0, WIDTH - 1, bottom, Mat.STONE, _set_block)

	# Floor slabs: metal, every FLOOR_H rows, with the shaft gap
	# (roof slab y=0 also gets the gap as the roof entrance)
	for f in range(FLOOR_COUNT + 1):
		var y := f * FLOOR_H
		for x in range(1, WIDTH - 1):
			var in_shaft := x >= SHAFT_X and x < SHAFT_X + SHAFT_W
			var is_ground := y == bottom
			if not in_shaft or is_ground:
				_set_block(x, y, Mat.METAL)

	# Two-jump ledges (WS-04): a wood platform 3 blocks above each slab,
	# beside the shaft, so each floor is reachable in exactly two jumps.
	for f in range(1, FLOOR_COUNT + 1):
		var slab_y := f * FLOOR_H
		_fill(SHAFT_X - 4, slab_y - 3, SHAFT_X - 2, slab_y - 3, Mat.WOOD, _set_block)

	# Interior dressing per floor: wood platforms and plastic crates
	for f in range(1, FLOOR_COUNT + 1):
		var floor_y := f * FLOOR_H - 1 # standing row above each slab
		_fill(6, floor_y - 2, 8, floor_y - 2, Mat.WOOD, _set_block)   # table/shelf
		_set_block(12, floor_y, Mat.PLASTIC)                           # crate
		_set_block(13, floor_y, Mat.PLASTIC)
		_set_block(12, floor_y - 1, Mat.PLASTIC)
		_fill(20, floor_y - 2, 22, floor_y - 2, Mat.WOOD, _set_block)
		_set_block(27, floor_y, Mat.PLASTIC)
