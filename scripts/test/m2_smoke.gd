extends Node
## Headless M2 gate test: the cellular water sim — conservation, flow and
## settling, wake-on-change, displacement, buoyancy, currents, and the gate
## itself: seal a flooded room, pump it dry, and move in (bed + breathing).
## Run: godot --path . --headless res://scenes/test/m2_smoke.tscn

const B := Constants.BLOCK_SIZE

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
	print("\nM2 smoke: %d checks, %d failures" % [checks, failures.size()])
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

func sim() -> WaterSim:
	return World.water_sim

func lv(x: int, y: int) -> int:
	return sim().level_at(Vector2i(x, y))

## Total units in a cell rect (inclusive coords).
func region_units(x0: int, y0: int, x1: int, y1: int) -> int:
	var t := 0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			t += lv(x, y)
	return t

func _run() -> void:
	print("== A. seeded equilibrium")
	var total0 := sim().total_units()
	await ticks(60)
	check(sim().total_units() == total0, "water conserved at rest (%d units)" % total0)
	check(sim().awake_count() < 30, "settled body is dormant (awake %d)" % sim().awake_count())
	check(absf(World.water_surface_y(Vector2(6 * B, 20 * B)) - 18 * B) < 0.5, "surface at the waterline (row 18)")
	check(lv(25, 21) == 8 and lv(34, 18) == 8, "flooded floors and shaft are full")
	check(lv(20, 15) == 0, "dry floor 3 is dry")

	print("== B. flow: water finds its level")
	# Pour a column of water onto dry floor 3: it spreads and settles.
	for i in 6:
		sim().add_water(Vector2i(20, 13), 8)
		await ticks(4)
	check(await until(func(): return sim().awake_count() == 0, 600), "poured water settles to dormancy")
	var spread_w := 0
	for x in range(2, 33):
		if lv(x, 17) > 0:
			spread_w += 1
	check(spread_w >= 10, "water spread across the floor (%d wet cells)" % spread_w)
	check(lv(20, 13) == 0 and lv(20, 16) == 0, "no floating water left in the pour column")

	print("== C. wake-on-change + displacement (WS-24)")
	var before := sim().total_units()
	World.place_block("wood_block", Vector2i(20, 21)) # into the flooded floor 4
	check(lv(20, 21) == 0, "placed block's cell holds no water")
	check(sim().total_units() >= before - 1, "water displaced, not destroyed (%d -> %d)" % [before, sim().total_units()])
	check(sim().awake_count() > 0, "placement woke the neighbourhood")
	await until(func(): return sim().awake_count() == 0, 600)
	var removed := World.remove_block(Vector2i(20, 21))
	check(removed == "wood_block", "block removed again")
	check(await until(func(): return lv(20, 21) == 8, 300), "hole refills from the body")
	await until(func(): return sim().awake_count() == 0, 600)

	print("== D. buoyancy (CC-07 physics)")
	var float_item := World.spawn_item("wood", 1, Vector2(6 * B + 8, 20 * B)) # pool column, underwater
	check(await until(func(): return absf(float_item.global_position.y - (18 * B + 3)) < 2.0, 300),
		"wood floats up and bobs at the surface (y %.1f)" % float_item.global_position.y)
	var pinned := World.spawn_item("wood", 1, Vector2(17 * B + 8, 27 * B)) # floor 5, under slab 24
	check(await until(func(): return pinned.velocity == Vector2.ZERO and pinned.global_position.y < 25 * B + 6, 300),
		"wood under a ceiling pins against it (y %.1f)" % pinned.global_position.y)
	var sinker := World.spawn_item("glowstick", 1, Vector2(6 * B + 8, 19 * B))
	check(await until(func(): return sinker.global_position.y > 20 * B + 8, 600),
		"glowstick sinks below its spawn (y %.1f)" % sinker.global_position.y)
	float_item.queue_free(); pinned.queue_free(); sinker.queue_free()

	print("== E. the gate: seal floor 4, pump it dry, move in")
	# Patch every opening in slab 18 (pool + shaft) and the swim hole below.
	player.inventory.add("wood_block", 30)
	var patches: Array[Vector2i] = []
	for x in range(3, 10):
		patches.append(Vector2i(x, 18))
	for x in range(33, 36):
		patches.append(Vector2i(x, 18))
	patches.append(Vector2i(10, 24))
	for c in patches:
		check_quiet(World.place_block("wood_block", c), "patch at %s" % c)
	check(true, "room sealed with %d player blocks" % patches.size())
	await until(func(): return sim().awake_count() == 0, 900)
	var room_before := region_units(1, 19, 38, 23)
	check(room_before > 1000, "sealed room still full (%d units)" % room_before)
	# Pump inside the room, outlet up the (now sealed-off) shaft above the waterline.
	var pump := World.place_object("pump", Vector2i(30, 23), true)
	check(pump != null and World.pumps.has(pump), "pump placed underwater in the sealed room")
	# Outlet up on floor 2: floors 2+3 together can hold the room's volume,
	# so the outlet never ends up below the receiving surface.
	pump.outlet_cell = Vector2i(20, 10)
	check(await until(func(): return region_units(1, 19, 38, 23) <= 80, 4000),
		"pump drains the sealed room to a shallow film (%d units left)" % region_units(1, 19, 38, 23))
	check(region_units(1, 7, 38, 17) > room_before / 2, "pumped water ended up on floors 2-3 (conservation)")

	print("== F. move in: breathe, bed, station (GL-17)")
	player.global_position = Vector2(20 * B + 8, 24 * B - Player.FEET_Y)
	player.velocity = Vector2.ZERO
	await ticks(30)
	check(player.state == Player.State.GROUNDED and not player.submerged, "player stands dry in the drained room (%s)" % player.state_name())
	check(player.oxygen == Constants.BASE_OXYGEN_SECONDS, "breathable air refills O2 (LT-17)")
	player.inventory.add("bed", 1)
	check(World.can_place_object("bed", Vector2i(14, 23), player), "bed placeable in the drained room")
	var bed := World.place_object("bed", Vector2i(14, 23), true)
	bed.interact(player)
	check(absf(World.spawn_position.x - bed.bottom_center().x) < 0.5, "bed sets spawn in the forward camp")
	check(World.can_place_object("workbench", Vector2i(24, 23), player), "stations work in drained rooms")

	print("== G. currents push bodies (WS-16)")
	# Re-breach the room: remove a patch — the shaft water pours back in.
	World.remove_block(Vector2i(34, 18))
	var drift := World.spawn_item("wood", 1, Vector2(34 * B + 8, 19 * B + 8))
	await ticks(20)
	var pushed := false
	for i in 90:
		if World.current_at(Vector2(34 * B + 8, 19 * B + 8)) != Vector2.ZERO or drift.velocity.length() > 4.0:
			pushed = true
			break
		await get_tree().physics_frame
	check(pushed, "inflow current pushes a floating body")
	check(await until(func(): return region_units(1, 19, 38, 23) > 40, 1200), "breach refloods the room")

func check_quiet(cond: bool, msg: String) -> void:
	if not cond:
		checks += 1
		failures.append(msg)
		print("  FAIL: " + msg)
