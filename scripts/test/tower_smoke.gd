extends Node
## Headless checks for the deep tower (floors 6-15): geometry, stairwell,
## themed furnishing, sealed dry floors behind doors, and the door-opening
## flood. Run: godot --path . --headless res://scenes/test/tower_smoke.tscn

const B := Constants.BLOCK_SIZE
const FLOOR_H := 6

var tower: Node2D
var player: Player
var failures: PackedStringArray = []
var checks := 0

func _ready() -> void:
	tower = load("res://scenes/test/test_tower.tscn").instantiate()
	add_child(tower)
	player = tower.get_node("Player")
	player.set_multiplayer_authority(2)
	await get_tree().physics_frame
	await _run()
	print("\nTower smoke: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)

func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok:   " if cond else "  FAIL: ") + msg)
	if not cond:
		failures.append(msg)

func ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func until(pred: Callable, n: int) -> bool:
	for i in n:
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()

func room_units(f: int) -> int:
	var y0 := (f - 1) * FLOOR_H + 1
	var t := 0
	for y in range(y0, y0 + FLOOR_H - 1):
		for x in range(7, 32):
			t += World.water_sim.level_at(Vector2i(x, y))
	return t

func objects_on_floor(f: int, kind: String = "") -> Array:
	var y0 := (f - 1) * FLOOR_H + 1
	var out := []
	for o in tower.get_node("Objects").get_children():
		if o is WorldObject and o.cell.y >= y0 and o.cell.y < y0 + FLOOR_H and o.cell.x > 6:
			if kind == "" or o.def.kind == kind:
				out.append(o)
	return out

func _run() -> void:
	print("== A. tripled geometry")
	check(World.water_sim.bounds.size.y == 91, "world grid is 91 rows (15 floors)")
	check(World.has_block_cell(Vector2i(20, 90)), "new ground slab at row 90")
	check(not World.has_block_cell(Vector2i(4, 30)), "stairwell entry gap in the old ground slab")
	check(World.has_block_cell(Vector2i(20, 30)), "old ground row is now a regular slab elsewhere")
	await ticks(60)
	check(World.water_sim.awake_count() == 0, "deep water seeded at equilibrium (awake %d)" % World.water_sim.awake_count())

	print("== B. stairwell")
	check(World.is_climbable_cell(Vector2i(4, 40)) and World.is_climbable_cell(Vector2i(4, 85)), "ladder runs the stairwell")
	check(not World.has_block_cell(Vector2i(4, 42)), "stairwell landings open through each slab")
	check(World.has_block_cell(Vector2i(6, 32)), "stairwell wall above each doorway")
	check(not World.has_block_cell(Vector2i(6, 41)), "doorway open at floor level (floor 7)")

	print("== C. themes")
	var desks := 0
	for o in objects_on_floor(6):
		if o.id == "desk":
			desks += 1
	check(desks >= 3, "floor 6 is an office (%d desks)" % desks)
	var beds := objects_on_floor(7).filter(func(o): return o.id == "bed_frame").size()
	check(beds == 1, "floor 7 is an apartment (bed frame)")
	check(objects_on_floor(9, "breaker").size() == 1 and objects_on_floor(13, "breaker").size() == 1, "utility floors 9 and 13 have breakers")
	check(objects_on_floor(9, "pump").size() == 1, "utility floor has a found pump")
	var lamps := objects_on_floor(10, "light").size()
	check(lamps == 2, "every deep floor has two wired ceiling lamps (%d)" % lamps)

	print("== D. sealed floors behind doors")
	for f: int in [8, 11, 14]:
		check(room_units(f) == 0, "sealed floor %d starts dry" % f)
	check(room_units(7) > 800, "unsealed floor 7 is flooded (%d units)" % room_units(7))
	var sr := 8 * FLOOR_H - 1
	var door := World.object_at(Vector2i(6, sr - 1))
	check(door != null and door.def.kind == "door" and World.is_solid_cell(Vector2i(6, sr - 1)), "floor 8's closed door seals the room")

	print("== E. opening the door floods the room with the water above")
	var before := room_units(8)
	door.interact(player)
	check(not World.is_solid_cell(Vector2i(6, sr - 1)), "door open")
	check(await until(func(): return room_units(8) > 400, 2400), "stairwell water pours in (%d -> %d units)" % [before, room_units(8)])
	check(await until(func(): return World.water_sim.awake_count() == 0, 4000), "flood settles")
	check(room_units(11) == 0 and room_units(14) == 0, "other sealed floors stay dry")
