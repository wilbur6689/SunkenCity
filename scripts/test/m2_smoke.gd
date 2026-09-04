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
	check(absf(World.water_surface_y(Vector2(12 * B, 40 * B)) - 36 * B) < 0.5, "surface at the waterline (row 36)")
	check(lv(50, 43) == 8 and lv(68, 36) == 8, "flooded floors and shaft are full")
	check(lv(40, 31) == 0, "dry floor 3 is dry")

	print("== B. flow: water finds its level")
	# Pour a column of water onto dry floor 3: it spreads and settles.
	for i in 24: # 4x the cells per area since the 8 px cell
		sim().add_water(Vector2i(40, 27), 8)
		await ticks(4)
	check(await until(func(): return sim().awake_count() == 0, 600), "poured water settles to dormancy")
	var spread_w := 0
	for x in range(4, 66):
		if lv(x, 35) > 0:
			spread_w += 1
	check(spread_w >= 20, "water spread across the floor (%d wet cells)" % spread_w)
	check(lv(40, 27) == 0 and lv(40, 33) == 0, "no floating water left in the pour column")

	print("== C. wake-on-change + displacement (WS-24)")
	var before := sim().total_units()
	World.place_block("wood_block", Vector2i(36, 43)) # into the flooded floor 4 (clear of the wood shelf at cols 40-45)
	check(lv(36, 43) == 0, "placed block's cell holds no water")
	check(sim().total_units() >= before - 1, "water displaced, not destroyed (%d -> %d)" % [before, sim().total_units()])
	check(sim().awake_count() > 0, "placement woke the neighbourhood")
	await until(func(): return sim().awake_count() == 0, 600)
	var removed := World.remove_block(Vector2i(36, 43))
	check(removed == "wood_block", "block removed again")
	check(await until(func(): return lv(36, 43) == 8, 300), "hole refills from the body (level %d, above %d, awake %d)" % [lv(36, 43), lv(36, 42), sim().awake_count()])
	await until(func(): return sim().awake_count() == 0, 600)

	print("== D. buoyancy (CC-07 physics)")
	var float_item := World.spawn_item("wood", 1, Vector2(12 * B + 8, 40 * B)) # pool column, underwater
	check(await until(func(): return absf(float_item.global_position.y - (36 * B + 3)) < 2.0, 300),
		"wood floats up and bobs at the surface (y %.1f)" % float_item.global_position.y)
	var pinned := World.spawn_item("wood", 1, Vector2(34 * B + 8, 54 * B)) # floor 5, under slab 48
	check(await until(func(): return pinned.velocity == Vector2.ZERO and pinned.global_position.y < 50 * B + 6, 300),
		"wood under a ceiling pins against it (y %.1f)" % pinned.global_position.y)
	var sinker := World.spawn_item("glowstick", 1, Vector2(12 * B + 8, 38 * B))
	check(await until(func(): return sinker.global_position.y > 40 * B + 8, 600),
		"glowstick sinks below its spawn (y %.1f)" % sinker.global_position.y)
	float_item.queue_free(); pinned.queue_free(); sinker.queue_free()

	print("== E. the gate: seal floor 4, pump it dry, move in")
	print("== plunge drag: a max-speed dive stops within blocks (2026-09-01)")
	player.global_position = Vector2(12 * B + 8, 26 * B)
	player.velocity = Vector2(0, Constants.MAX_FALL_SPEED)
	var deepest := 0.0
	for i in 240:
		await get_tree().physics_frame
		deepest = maxf(deepest, player.global_position.y)
	check(deepest < (36.0 + 16.0) * B,
		"dive from max fall speed stops %.1f blocks under the surface (< 16)" % ((deepest - 36.0 * B) / B))
	player.velocity = Vector2.ZERO

	# Patch every opening in slab 36 (pool + shaft) and the swim hole below
	# (slabs are 2 cells thick; one solid row seals).
	player.inventory.add("wood_block", 60)
	var patches: Array[Vector2i] = []
	for x in range(6, 20):
		patches.append(Vector2i(x, 36))
	for x in range(66, 72):
		patches.append(Vector2i(x, 36))
		patches.append(Vector2i(x, 48)) # the shaft continues DOWN too — seal or pump the ocean
	patches.append(Vector2i(20, 48))
	patches.append(Vector2i(21, 48))
	for c in patches:
		check_quiet(World.place_block("wood_block", c), "patch at %s" % c)
	check(true, "room sealed with %d player blocks" % patches.size())
	await until(func(): return sim().awake_count() == 0, 900)
	var room_before := region_units(2, 38, 77, 47)
	check(room_before > 4000, "sealed room still full (%d units)" % room_before)
	# Pump inside the room, outlet up the (now sealed-off) shaft above the waterline.
	var pump := World.place_object("pump", Vector2i(60, 47), true)
	check(pump != null and World.pumps.has(pump), "pump placed underwater in the sealed room")
	# Outlet up on floor 2: floors 2+3 together can hold the room's volume,
	# so the outlet never ends up below the receiving surface.
	pump.outlet_cell = Vector2i(40, 21)
	check(await until(func(): return region_units(2, 38, 77, 47) <= 320, 4000),
		"pump drains the sealed room to a shallow film (%d units left)" % region_units(2, 38, 77, 47))
	check(region_units(2, 14, 77, 35) > room_before / 2, "pumped water ended up on floors 2-3 (conservation)")

	print("== F. move in: breathe, bed, station (GL-17)")
	player.global_position = Vector2(40 * B + 8, 48 * B - Player.FEET_Y)
	player.velocity = Vector2.ZERO
	await ticks(30)
	check(player.state == Player.State.GROUNDED and not player.submerged, "player stands dry in the drained room (%s)" % player.state_name())
	check(player.oxygen == Constants.BASE_OXYGEN_SECONDS, "breathable air refills O2 (LT-17)")
	player.inventory.add("bed", 1)
	check(World.can_place_object("bed", Vector2i(28, 47), player), "bed placeable in the drained room")
	var bed := World.place_object("bed", Vector2i(28, 47), true)
	bed.interact(player)
	check(absf(World.spawn_position.x - bed.bottom_center().x) < 0.5, "bed sets spawn in the forward camp")
	check(World.can_place_object("workbench", Vector2i(36, 47), player), "stations work in drained rooms")

	print("== G. currents push bodies (WS-16)")
	# Re-breach the room: remove a patch — the shaft water pours back in.
	World.remove_block(Vector2i(68, 36))
	var drift := World.spawn_item("wood", 1, Vector2(68 * B + 8, 38 * B + 8))
	await ticks(20)
	var pushed := false
	for i in 90:
		if World.current_at(Vector2(68 * B + 8, 38 * B + 8)) != Vector2.ZERO or drift.velocity.length() > 4.0:
			pushed = true
			break
		await get_tree().physics_frame
	check(pushed, "inflow current pushes a floating body")
	check(await until(func(): return region_units(2, 38, 77, 47) > 160, 1200), "breach refloods the room")

	print("== H. lighting (WS-17) + fog of war")
	# Shut the pump off (breach + pump would circulate water forever),
	# park the player back on floor 1, and let the water resettle.
	pump.outlet_cell = WorldObject.NO_OUTLET
	player.global_position = Vector2(32 * B + 8, 12 * B - Player.FEET_Y)
	player.velocity = Vector2.ZERO
	check(await until(func(): return sim().awake_count() == 0, 3000), "world resettles after the breach")
	await ticks(10)
	var lm: LightMap = World.light_map
	check(lm.light_at(Vector2i(68, 21)) == LightMap.MAX_LIGHT, "sun falls down the open shaft")
	check(lm.light_at(Vector2i(68, 43)) < lm.light_at(Vector2i(68, 39)), "light falls off faster through water (%d < %d)" % [lm.light_at(Vector2i(68, 43)), lm.light_at(Vector2i(68, 39))])
	var interior_before := lm.light_at(Vector2i(10, 21))
	check(interior_before <= 6, "unlit interior is dark (%d)" % interior_before)
	var pc := World.cell_at(player.global_position)
	check(World.visibility_at(pc, player.global_position) >= 16.0, "the player lights their own surroundings")
	check(World.visibility_at(Vector2i(68, 21), player.global_position) == 0.0, "fog of war: interior out of sight range = invisible")
	check(World.visibility_at(Vector2i(-6, 11), player.global_position) == float(LightMap.MAX_LIGHT), "exterior/background fully revealed at any distance")
	check(World.line_of_sight(player.global_position, Vector2i(40, 11)), "clear line of sight along the player's own floor")
	check(not World.line_of_sight(player.global_position, Vector2i(32, 17)), "the floor slab blocks line of sight downward")
	check(World.visibility_at(Vector2i(32, 17), player.global_position) == 0.0, "room below the floor stays hidden even in sight range")
	# Obstacles (wood/plastic) only attenuate sight; structure blacks out.
	player.inventory.add("wood_block", 3)
	World.place_block("wood_block", Vector2i(28, 11)) # a 22 px body's sightline needs 3 cells of cover
	World.place_block("wood_block", Vector2i(28, 10))
	World.place_block("wood_block", Vector2i(28, 9))
	var behind := World.visibility_at(Vector2i(24, 9), player.global_position)
	check(behind > 6.0 and behind < 24.0, "sight bleeds dimly past a wooden obstacle (%.1f)" % behind)
	World.remove_block(Vector2i(28, 11))
	World.remove_block(Vector2i(28, 10))
	World.remove_block(Vector2i(28, 9))
	player.inventory.add("standing_lamp", 1)
	World.place_object("standing_lamp", Vector2i(12, 23), true)
	await ticks(10)
	check(lm.light_at(Vector2i(12, 21)) >= 20, "placed lamp lights its room (%d -> %d)" % [interior_before, lm.light_at(Vector2i(12, 21))])
	# Placed lights are fog beacons (user request): their surroundings stay
	# revealed even with no line of sight from the player (a floor away).
	check(not World.line_of_sight(player.global_position, Vector2i(12, 21)), "the lamp's room is out of the player's sight")
	check(World.visibility_at(Vector2i(12, 21), player.global_position) >= 16.0, "…but the placed lamp keeps it revealed (fog beacon)")

	print("== I. building power: breaker + wired lamps (WS-17)")
	var bkr := World.object_at(Vector2i(50, 23))
	check(bkr != null and bkr.def.kind == "breaker", "breaker present on floor 2")
	var lamp_cell := Vector2i(20, 17) # below the west ceiling lamp
	var dark_before := lm.light_at(lamp_cell)
	# mop up the pumping episode's leftover water (the outlet filled the whole
	# floor-2 room, rows 14-23) so the breaker is dry
	for y in range(14, 24):
		for x in range(2, 78):
			sim().remove_water(Vector2i(x, y), 8)
	await ticks(30)
	bkr.interact(player)
	await ticks(10)
	check(bkr.powered_on, "breaker switched on")
	var lit_level := lm.light_at(lamp_cell)
	check(lit_level > dark_before + 8, "wired ceiling lamp lights up (%d -> %d)" % [dark_before, lit_level])
	for x in range(46, 56):
		sim().add_water(Vector2i(x, 23), 8)
	check(await until(func(): return not bkr.powered_on, 120), "flooding trips the breaker (WS-17)")
	await ticks(10)
	check(lm.light_at(lamp_cell) <= lit_level - 8, "wired lamps go dark when tripped (%d -> %d)" % [lit_level, lm.light_at(lamp_cell)])

func check_quiet(cond: bool, msg: String) -> void:
	if not cond:
		checks += 1
		failures.append(msg)
		print("  FAIL: " + msg)
