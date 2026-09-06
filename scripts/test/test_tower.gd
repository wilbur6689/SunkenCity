extends Node2D
## Test tower, built programmatically from the placeholder palette:
## 3 dry floors over 12 flooded floors, an elevator shaft with a ladder down
## to the waterline, a rope through a floor hole, a crawl vent, and a swim
## hole between the flooded floors. Floor 1 is furnished as the starting
## medical room (GL-02) with scrappable objects. Materials map to atlas rows;
## the variant (atlas column 0-4) is picked by a position hash. Replaced by
## real world-gen in M3.
##
## Half-size blocks (2026-09-04): cells are 8 px, so every dimension below is
## 2x its pre-2026-09-04 value and the tower keeps its PIXEL geometry. Slabs
## and walls are SLAB_T / WALL_T cells thick; rows 0-60 are load-bearing for
## the m0/m1/m2/m4 smokes (the old rows 0-30).

enum Mat { STONE = 0, WOOD = 1, METAL = 2, PLASTIC = 3, WATER = 4, LADDER = 5, ROPE = 6 }

const WIDTH := 80          # tower width in cells
const FLOOR_H := 12        # floor-to-floor height (WS-11): FLOOR_OPEN open rows + SLAB_T slab rows
const SLAB_T := 2          # slab thickness (cells)
const WALL_T := 2          # interior wall thickness
const FLOOR_OPEN := FLOOR_H - SLAB_T
const DOOR_H := 6          # doorway height (a 22 px body needs 3; doors are 2x6 objects)
const CRAWL_GAP := 2       # rows the 12 px compact hitbox squeezes through
const JUMP_CELLS := 6      # = Constants.JUMP_HEIGHT_BLOCKS
const FLOOR_COUNT := 15    # 3 dry + 12 flooded (tripled 2026-08-31; rows 0-60 unchanged)
const DRY_FLOORS := 3
# Deep floors 6-15: west stairwell, themed rooms, sealed dry floors behind doors.
const NEW_FLOORS_START := 6
const STAIR_X0 := 6        # stairwell columns 6-11 (ladder at STAIR_X0+2..+3)
const STAIR_X1 := 11
const STAIR_WALL_X := 12   # wall (cols 12-13) between stairwell and rooms (doorway per floor)
const SEALED_WALL_X := 64  # sealed floors also close their shaft side (cols 64-65)
const SEALED_FLOORS := [8, 11, 14] # dry rooms behind closed doors; open = flood
const THEMES := ["office", "apartment", "commercial", "utility"]
const SHAFT_X := 66        # elevator-shaft gap, 6 cells wide (ladder at SHAFT_X+2..+3)
const SHAFT_W := 6
const ROPE_X := 30         # rope + 2-wide hole between floors 1 and 2 (cols 30-31)
const VENT_X := 32         # 4-wide wall with a CRAWL_GAP crawl gap on floor 3 (cols 32-35)
const POOL_X0 := 6         # collapsed slab section under floor 3: open water surface
const POOL_X1 := 19
const SWIM_HOLE_X := 20    # 2-wide hole between the flooded floors (cols 20-21)

## Medical room furniture: [object id, bottom-left x] on floor 1's standing row.
const MED_ROOM := [
	["bed_frame", 4], ["med_cart", 12], ["cabinet", 18], ["chair", 24],
	["desk", 36], ["chair", 44], ["locker", 48], ["fridge", 54],
]
## Starting kit (LT-30): plain clothes are implicit; a couple of bandages + one food item.
const START_KIT := [["bandage", 2], ["food_can", 1]]

@onready var structure_renderer: StructureRenderer = $StructureRenderer
@onready var water_renderer: WaterRenderer = $WaterRenderer
@onready var items_root: Node2D = $Items
@onready var objects_root: Node2D = $Objects
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var player: Player = $Player

func _ready() -> void:
	# Grid first (CT-28), then build through World.
	var bounds := Rect2i(0, 0, WIDTH, FLOOR_COUNT * FLOOR_H + SLAB_T)
	var spawn_cell := Vector2i(32, FLOOR_H - 1) # not 30: the rope hole is below it
	spawn_point.global_position = Vector2((spawn_cell.x + 1.0) * Constants.BLOCK_SIZE, (spawn_cell.y + 0.5) * Constants.BLOCK_SIZE)
	var feet := spawn_point.global_position + Vector2(0, Constants.BLOCK_SIZE * 0.5)
	World.register(WorldGrid.new(bounds), feet, items_root, objects_root, structure_renderer, DRY_FLOORS * FLOOR_H)
	World.object_window = Vector2i(400, 320) # the whole test tower stays live (held references in m1/m2/tower smokes)
	World.enemy_window = Vector2i(280, 200)
	_build_tower()
	_furnish() # before seeding: closed doors must already seal (WS-20 solidity)
	# Static seed at equilibrium: everything open at or below the waterline is full…
	var waterline := DRY_FLOORS * FLOOR_H
	World.water_sim.fill_rect(Rect2i(WALL_T, waterline, WIDTH - 2 * WALL_T, FLOOR_COUNT * FLOOR_H - waterline), WaterSim.MAX_LEVEL)
	# …except the sealed floors, which start dry behind their doors.
	for f: int in SEALED_FLOORS:
		World.water_sim.fill_rect(Rect2i(STAIR_WALL_X + WALL_T, (f - 1) * FLOOR_H + SLAB_T, SEALED_WALL_X - STAIR_WALL_X - WALL_T, FLOOR_OPEN), 0)
	water_renderer.setup(waterline * Constants.BLOCK_SIZE)
	# Shallows backdrop hangs from the waterline; start it well left of the tower.
	$Backdrop.setup(DRY_FLOORS * FLOOR_H * Constants.BLOCK_SIZE, -900.0)
	player.respawn()
	for kit in START_KIT:
		player.inventory.add(kit[0], kit[1])
	player.set_equipment("suit", {"id": "clothes", "count": 1}) # LT-30: plain clothes

func _set_block(x: int, y: int, mat: Mat) -> void:
	World.grid.set_structure(Vector2i(x, y), mat + 1) # Mat rows -> WorldGrid.M

func _set_back(x: int, y: int, mat: Mat) -> void:
	World.grid.set_back(Vector2i(x, y), mat + 1)

func _set_climbable(x: int, y: int, mat: Mat) -> void:
	World.grid.set_climb(Vector2i(x, y), WorldGrid.C.LADDER if mat == Mat.LADDER else WorldGrid.C.ROPE)

func _fill(x0: int, y0: int, x1: int, y1: int, mat: Mat, fn: Callable) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			fn.call(x, y, mat)

func _build_tower() -> void:
	var bottom := FLOOR_COUNT * FLOOR_H # ground slab top row
	var waterline := DRY_FLOORS * FLOOR_H # first flooded row (slab under floor 3)

	# Background walls (cosmetic, WS-20): stone interior facing
	_fill(WALL_T, SLAB_T, WIDTH - 1 - WALL_T, bottom - 1, Mat.STONE, _set_back)

	# Outer walls: stone, full height, WALL_T thick
	_fill(0, 0, WALL_T - 1, bottom + SLAB_T - 1, Mat.STONE, _set_block)
	_fill(WIDTH - WALL_T, 0, WIDTH - 1, bottom + SLAB_T - 1, Mat.STONE, _set_block)

	# Floor slabs: metal, every FLOOR_H rows, SLAB_T thick, with the shaft gap
	# (roof slab y=0 also gets the gap as the roof entrance)
	for f in range(FLOOR_COUNT + 1):
		var y := f * FLOOR_H
		for x in range(WALL_T, WIDTH - WALL_T):
			var in_shaft := x >= SHAFT_X and x < SHAFT_X + SHAFT_W
			var is_ground := y == bottom
			var rope_hole := x >= ROPE_X and x <= ROPE_X + 1 and y == FLOOR_H
			var pool := x >= POOL_X0 and x <= POOL_X1 and y == waterline
			var swim_hole := x >= SWIM_HOLE_X and x <= SWIM_HOLE_X + 1 and y == (DRY_FLOORS + 1) * FLOOR_H
			var stair_gap := x >= STAIR_X0 and x <= STAIR_X1 and y >= (NEW_FLOORS_START - 1) * FLOOR_H
			if is_ground or not (in_shaft or rope_hole or pool or swim_hole or stair_gap):
				for t in SLAB_T:
					_set_block(x, y + t, Mat.METAL)

	_build_deep_floors(bottom)

	# Two-jump ledges (WS-04): a wood platform JUMP_CELLS above each slab,
	# beside the shaft, so each floor is reachable in exactly two jumps.
	for f in range(1, FLOOR_COUNT + 1):
		var slab_y := f * FLOOR_H
		_fill(SHAFT_X - 8, slab_y - JUMP_CELLS, SHAFT_X - 3, slab_y - JUMP_CELLS + 1, Mat.WOOD, _set_block)

	# Interior dressing (old floors 2-5 only; deep floors get themes instead;
	# floor 1 is the furnished medical room; floor 3 is the obstacle course).
	for f in range(2, NEW_FLOORS_START):
		if f == DRY_FLOORS:
			continue
		var floor_y := f * FLOOR_H - 1 # standing row above each slab
		_fill(12, floor_y - 5, 17, floor_y - 4, Mat.WOOD, _set_block)   # table/shelf
		_fill(24, floor_y - 1, 27, floor_y, Mat.PLASTIC, _set_block)    # crates
		_fill(24, floor_y - 3, 25, floor_y - 2, Mat.PLASTIC, _set_block)
		_fill(40, floor_y - 5, 45, floor_y - 4, Mat.WOOD, _set_block)
		_fill(54, floor_y - 1, 55, floor_y, Mat.PLASTIC, _set_block)

	# Crawl vent (WS-05): a 4-wide wall on floor 3 leaving a CRAWL_GAP-row gap
	# at floor level — passable only in the compact form.
	var vent_slab := DRY_FLOORS * FLOOR_H
	_fill(VENT_X, vent_slab - FLOOR_OPEN, VENT_X + 3, vent_slab - CRAWL_GAP - 1, Mat.STONE, _set_block)

	# Ladder (WS-16): shaft centre pair, roof down to the waterline.
	_fill(SHAFT_X + 2, SLAB_T, SHAFT_X + 3, waterline - 1, Mat.LADDER, _set_climbable)

	# Rope (WS-16): hangs from the floor-1 hole down to floor 2's standing row.
	_fill(ROPE_X, FLOOR_H, ROPE_X + 1, 2 * FLOOR_H - 1, Mat.ROPE, _set_climbable)

## Floors 6-15, tile work only (runs before World.register): stairwell
## ladder, per-floor walls with doorways, sealed partitions, machinery.
func _build_deep_floors(bottom: int) -> void:
	var top := (NEW_FLOORS_START - 1) * FLOOR_H # slab 60, the old ground
	_fill(STAIR_X0 + 2, top, STAIR_X0 + 3, bottom - 1, Mat.LADDER, _set_climbable)
	for f in range(NEW_FLOORS_START, FLOOR_COUNT + 1):
		var y0 := (f - 1) * FLOOR_H + SLAB_T # top open row of the room
		var sr := f * FLOOR_H - 1             # standing row
		# Stairwell wall with a DOOR_H-tall doorway at floor level
		_fill(STAIR_WALL_X, y0, STAIR_WALL_X + WALL_T - 1, sr - DOOR_H, Mat.STONE, _set_block)
		if SEALED_FLOORS.has(f):
			# East partition seals the room from the elevator shaft
			_fill(SEALED_WALL_X, y0, SEALED_WALL_X + WALL_T - 1, sr, Mat.STONE, _set_block)
		if _theme_of(f) == "utility":
			_fill(48, sr - 1, 51, sr, Mat.METAL, _set_block) # machinery blocks

func _theme_of(f: int) -> String:
	return THEMES[(f - NEW_FLOORS_START) % THEMES.size()]

## Objects for floors 6-15 (runs from _furnish, after World.register):
## closed doors on sealed floors, themed furniture, wired ceiling lamps.
func _furnish_deep_floors() -> void:
	for f in range(NEW_FLOORS_START, FLOOR_COUNT + 1):
		var y0 := (f - 1) * FLOOR_H + SLAB_T
		var sr := f * FLOOR_H - 1
		if SEALED_FLOORS.has(f):
			World.place_object("wood_door", Vector2i(STAIR_WALL_X, sr), false)
		var put := func(id: String, x: int) -> void:
			World.place_object(id, Vector2i(x, sr), false)
		match _theme_of(f):
			"office":
				put.call("desk", 18); put.call("chair", 26); put.call("cabinet", 30)
				put.call("desk", 38); put.call("chair", 46); put.call("desk", 52)
			"apartment":
				put.call("bed_frame", 18); put.call("chair", 26); put.call("fridge", 30)
				put.call("cabinet", 36); put.call("desk", 42); put.call("chair", 50)
			"commercial":
				put.call("cabinet", 18); put.call("locker", 24); put.call("med_cart", 28)
				put.call("cabinet", 34); put.call("locker", 40); put.call("cabinet", 46)
				put.call("chair", 52)
			"utility":
				put.call("breaker", 20); put.call("locker", 24); put.call("pump", 30)
				put.call("locker", 36); put.call("med_cart", 42)
		# Ceiling lamps are 2x2 (bottom-left anchored): hang from the slab.
		World.place_object("ceiling_lamp", Vector2i(24, y0 + 1), false)
		World.place_object("ceiling_lamp", Vector2i(52, y0 + 1), false)

func _furnish() -> void:
	var standing_row := FLOOR_H - 1
	for entry in MED_ROOM:
		World.place_object(entry[0], Vector2i(entry[1], standing_row), false)
	# Building power test rig (WS-17): a breaker on floor 2 wired to two
	# ceiling lamps. E flips it; flooding it trips it off.
	World.place_object("breaker", Vector2i(50, 2 * FLOOR_H - 1), false)
	World.place_object("ceiling_lamp", Vector2i(20, FLOOR_H + SLAB_T + 1), false)
	World.place_object("ceiling_lamp", Vector2i(56, FLOOR_H + SLAB_T + 1), false)
	_furnish_deep_floors()
