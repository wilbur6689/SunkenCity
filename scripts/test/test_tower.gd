extends Node2D
## Test tower, built programmatically from the placeholder palette:
## 3 dry floors over 2 flooded floors, an elevator shaft with a ladder down
## to the waterline, a rope through a 1-block floor hole, a 1-block crawl
## vent, and a 1-block swim hole between the flooded floors. Floor 1 is
## furnished as the starting medical room (GL-02) with scrappable objects.
## Materials map to atlas rows; the variant (atlas column 0-4) is picked by a
## position hash. Replaced by real world-gen in M3.

enum Mat { STONE = 0, WOOD = 1, METAL = 2, PLASTIC = 3, WATER = 4, LADDER = 5, ROPE = 6 }

const WIDTH := 40          # tower width in blocks
const FLOOR_H := 6         # floor-to-floor height (WS-11)
const FLOOR_COUNT := 5     # 3 dry + 2 flooded
const DRY_FLOORS := 3
const SHAFT_X := 33        # elevator-shaft gap, 3 blocks wide
const SHAFT_W := 3
const ROPE_X := 15         # rope + 1-block hole between floors 1 and 2
const VENT_X := 16         # 2-wide wall with a 1-block crawl gap on floor 3
const POOL_X0 := 3         # collapsed slab section under floor 3: open water surface
const POOL_X1 := 9
const SWIM_HOLE_X := 10    # 1-block hole between the flooded floors

## Medical room furniture: [object id, bottom-left x] on floor 1's standing row.
const MED_ROOM := [
	["bed_frame", 2], ["med_cart", 6], ["cabinet", 9], ["chair", 12],
	["desk", 18], ["chair", 22], ["locker", 24], ["fridge", 27],
]
## Starting kit (LT-30): plain clothes are implicit; a couple of bandages + one food item.
const START_KIT := [["bandage", 2], ["food_can", 1]]

@onready var blocks: TileMapLayer = $Blocks
@onready var back_walls: TileMapLayer = $BackWalls
@onready var water_renderer: WaterRenderer = $WaterRenderer
@onready var climbables: TileMapLayer = $Climbables
@onready var items_root: Node2D = $Items
@onready var objects_root: Node2D = $Objects
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var player: Player = $Player

func _ready() -> void:
	_build_tower()
	# Spawn on floor 1 (the medical room); feet on the standing row's bottom edge.
	var spawn_cell := Vector2i(16, FLOOR_H - 1) # not 15: the rope hole is below it
	spawn_point.global_position = blocks.map_to_local(spawn_cell)
	var feet := spawn_point.global_position + Vector2(0, Constants.BLOCK_SIZE * 0.5)
	var water_bounds := Rect2i(0, 0, WIDTH, FLOOR_COUNT * FLOOR_H + 1)
	World.register(blocks, water_bounds, climbables, feet, back_walls, items_root, objects_root)
	# Static seed at equilibrium: everything open at or below the waterline is full.
	var waterline := DRY_FLOORS * FLOOR_H
	World.water_sim.fill_rect(Rect2i(1, waterline, WIDTH - 2, FLOOR_COUNT * FLOOR_H - waterline), WaterSim.MAX_LEVEL)
	water_renderer.setup(waterline * Constants.BLOCK_SIZE)
	_furnish()
	# Shallows backdrop hangs from the waterline; start it well left of the tower.
	$Backdrop.setup(DRY_FLOORS * FLOOR_H * Constants.BLOCK_SIZE, -900.0)
	player.respawn()
	for kit in START_KIT:
		player.inventory.add(kit[0], kit[1])
	player.set_equipment("suit", {"id": "clothes", "count": 1}) # LT-30: plain clothes

func _set_block(x: int, y: int, mat: Mat) -> void:
	blocks.set_cell(Vector2i(x, y), 0, Vector2i(_shade(x, y), mat))

func _set_back(x: int, y: int, mat: Mat) -> void:
	back_walls.set_cell(Vector2i(x, y), 0, Vector2i(_shade(x + 7, y + 3), mat))

func _set_climbable(x: int, y: int, mat: Mat) -> void:
	climbables.set_cell(Vector2i(x, y), 0, Vector2i(0, mat))

func _shade(x: int, y: int) -> int:
	return posmod(hash(Vector2i(x, y)), 5)

func _fill(x0: int, y0: int, x1: int, y1: int, mat: Mat, fn: Callable) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			fn.call(x, y, mat)

func _build_tower() -> void:
	var bottom := FLOOR_COUNT * FLOOR_H # ground slab row
	var waterline := DRY_FLOORS * FLOOR_H # first flooded row (slab under floor 3)

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
			var rope_hole := x == ROPE_X and y == FLOOR_H
			var pool := x >= POOL_X0 and x <= POOL_X1 and y == waterline
			var swim_hole := x == SWIM_HOLE_X and y == (DRY_FLOORS + 1) * FLOOR_H
			if is_ground or not (in_shaft or rope_hole or pool or swim_hole):
				_set_block(x, y, Mat.METAL)

	# Two-jump ledges (WS-04): a wood platform 3 blocks above each slab,
	# beside the shaft, so each floor is reachable in exactly two jumps.
	for f in range(1, FLOOR_COUNT + 1):
		var slab_y := f * FLOOR_H
		_fill(SHAFT_X - 4, slab_y - 3, SHAFT_X - 2, slab_y - 3, Mat.WOOD, _set_block)

	# Interior dressing per floor: wood platforms and plastic crates
	# (floor 1 is the furnished medical room; floor 3 is the obstacle course).
	for f in range(2, FLOOR_COUNT + 1):
		if f == DRY_FLOORS:
			continue
		var floor_y := f * FLOOR_H - 1 # standing row above each slab
		_fill(6, floor_y - 2, 8, floor_y - 2, Mat.WOOD, _set_block)   # table/shelf
		_set_block(12, floor_y, Mat.PLASTIC)                           # crate
		_set_block(13, floor_y, Mat.PLASTIC)
		_set_block(12, floor_y - 1, Mat.PLASTIC)
		_fill(20, floor_y - 2, 22, floor_y - 2, Mat.WOOD, _set_block)
		_set_block(27, floor_y, Mat.PLASTIC)

	# Crawl vent (WS-05): a 2-wide wall on floor 3 leaving a 1-block gap
	# at floor level — passable only in the compact form.
	var vent_slab := DRY_FLOORS * FLOOR_H
	_fill(VENT_X, vent_slab - 5, VENT_X + 1, vent_slab - 2, Mat.STONE, _set_block)

	# Ladder (WS-16): shaft center column, roof down to the waterline.
	_fill(SHAFT_X + 1, 1, SHAFT_X + 1, waterline - 1, Mat.LADDER, _set_climbable)

	# Rope (WS-16): hangs from the floor-1 hole down to floor 2's standing row.
	_fill(ROPE_X, FLOOR_H, ROPE_X, 2 * FLOOR_H - 1, Mat.ROPE, _set_climbable)

func _furnish() -> void:
	var standing_row := FLOOR_H - 1
	for entry in MED_ROOM:
		World.place_object(entry[0], Vector2i(entry[1], standing_row), false)
