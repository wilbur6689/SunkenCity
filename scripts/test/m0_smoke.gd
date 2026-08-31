extends Node
## Headless M0 gate test. Drives the player through the test tower with
## simulated input actions and asserts the state machine, speeds, and
## vitals behave per canon. Run:
##   godot --path . --headless res://scenes/test/m0_smoke.tscn
## Exit code 0 = all checks passed.

const B := Constants.BLOCK_SIZE

var tower: Node2D
var player: Player
var failures: PackedStringArray = []
var checks := 0

func _ready() -> void:
	tower = load("res://scenes/test/test_tower.tscn").instantiate()
	add_child(tower)
	player = tower.get_node("Player")
	await get_tree().physics_frame
	await _run()
	print("\nM0 smoke: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)

# --- Helpers ---

func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)
		print("  FAIL: " + msg)
	else:
		print("  ok:   " + msg)

func ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func press(actions: Array) -> void:
	for a in actions:
		Input.action_press(a)

func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "sprint", "crouch", "zoom_in", "zoom_out"]:
		Input.action_release(a)

func hold(actions: Array, n: int) -> void:
	press(actions)
	await ticks(n)
	release_all()

## Teleport so the feet rest on the bottom edge of cell (cx, standing_row).
func place(cx: int, standing_row: int) -> void:
	release_all()
	player.velocity = Vector2.ZERO
	player.global_position = Vector2(cx * B + B * 0.5, (standing_row + 1) * B - Player.FEET_Y)
	player.state = Player.State.AIRBORNE
	player.fall_start_y = player.global_position.y
	await ticks(2)

func st() -> String:
	return player.state_name()

func feet_y() -> float:
	return player.global_position.y + Player.FEET_Y

func bx() -> float:
	return player.global_position.x / B

## Wait up to n ticks for the predicate; returns true if it became true.
func until(pred: Callable, n: int) -> bool:
	for i in n:
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()

func grounded() -> bool:
	return player.state == Player.State.GROUNDED

# --- Scenario ---
# Tower layout reminders (see test_tower.gd): floors 1-3 dry (rows 1-17),
# slab rows 0/6/12/18/24/30; shaft x=33-35 with ladder at x=34; rope at
# x=15 rows 6-11; floor 3 = vent wall x=16-17 rows 13-16 + pool x=3-9 open
# at row 18; floors 4-5 flooded; swim hole at (10, 24).

func _run() -> void:
	print("== A. spawn + landing")
	check(await until(grounded, 60), "lands GROUNDED after spawn")
	check(absf(feet_y() - 6 * B) < 0.5, "spawn feet on floor-1 slab (y=%.1f)" % feet_y())
	check(player.health == Constants.MAX_HEALTH, "no fall damage from spawn drop")

	print("== B. walk / sprint / friction")
	press(["move_right"]); await ticks(20)
	check(absf(player.velocity.x - Constants.WALK_SPEED) < 1.0, "walk speed 5 bl/s (%.2f)" % (player.velocity.x / B))
	press(["sprint"]); await ticks(20)
	check(absf(player.velocity.x - Constants.SPRINT_SPEED) < 1.0, "sprint speed 7 bl/s (%.2f)" % (player.velocity.x / B))
	release_all(); await ticks(15)
	check(absf(player.velocity.x) < 0.01, "friction stops the player")
	check(grounded(), "still GROUNDED after run (%s)" % st())

	print("== C. jump height")
	# On the roof: interior rooms are 5 blocks, so a 2.8-block-tall player
	# legitimately taps the ceiling on a full 3-block jump indoors.
	await place(20, -1)
	await until(grounded, 30)
	var start_y := player.global_position.y
	var min_y := start_y
	press(["jump"])
	for i in 50:
		await get_tree().physics_frame
		min_y = minf(min_y, player.global_position.y)
	release_all()
	var rise := (start_y - min_y) / B
	check(absf(rise - Constants.JUMP_HEIGHT_BLOCKS) < 0.25, "jump apex ~3 blocks (%.2f)" % rise)
	check(await until(grounded, 60), "lands after jump")

	print("== D. crawl vent (floor 3, 1-block gap)")
	await place(14, 17)
	await until(grounded, 30)
	press(["crouch"]); await ticks(3)
	check(st() == "CRAWLING" and player.compact, "crouch → CRAWLING [compact] (%s)" % st())
	press(["move_right"]); await ticks(45)
	check(absf(player.velocity.x - Constants.CRAWL_SPEED) < 1.0, "crawl speed 2.5 bl/s (%.2f)" % (player.velocity.x / B))
	var mid_x := bx()
	Input.action_release("crouch"); await ticks(5)
	check(st() == "CRAWLING", "cannot stand inside the vent at x=%.1f (%s)" % [mid_x, st()])
	check(await until(grounded, 120), "stands up once clear of the vent")
	check(bx() > 18.0, "crawled through to x=%.1f" % bx())
	release_all()

	print("== E. ladder (shaft)")
	await place(34, 10)
	press(["move_up"]); await ticks(5)
	check(st() == "CLIMBING", "up on ladder → CLIMBING (%s)" % st())
	var y0 := player.global_position.y
	await ticks(30)
	check(y0 - player.global_position.y > 1.5 * B, "climbs upward (%.2f blocks)" % ((y0 - player.global_position.y) / B))
	check(absf(player.global_position.x - (34 * B + B * 0.5)) < 0.5, "centered on ladder column")
	check(absf(player.velocity.y + Constants.CLIMB_SPEED) < 1.0, "climb speed 4 bl/s")
	release_all(); await ticks(5)
	check(st() == "CLIMBING" and absf(player.velocity.y) < 0.01, "holds position on ladder with no input")
	press(["jump"]); await ticks(3)
	check(st() == "AIRBORNE", "jump leaves the ladder (%s)" % st())
	release_all()

	print("== E2. standing on the ladder top")
	await place(34, 10)
	press(["move_up"])
	check(await until(func(): return grounded() and absf(feet_y() - 1 * B) < 1.0, 300),
		"climbs off the top and stands on the ladder (feet row %.1f, %s)" % [feet_y() / B, st()])
	release_all(); await ticks(10)
	check(grounded() and absf(feet_y() - 1 * B) < 1.0, "keeps standing on the ladder top")
	press(["move_down"]); await ticks(20)
	check(st() == "CLIMBING" and feet_y() > 1 * B + 4.0, "down input climbs back down through the top (%s)" % st())
	release_all()
	await place(34, 10)
	press(["move_up"])
	await until(func(): return grounded(), 300)
	release_all()
	press(["jump"]); await ticks(5)
	check(player.velocity.y < 0.0 or st() == "AIRBORNE", "can jump from the ladder top")
	release_all()
	check(await until(func(): return grounded(), 120), "falls back and lands on the ladder top again")

	print("== F. rope through 1-block hole (floor 2 → floor 1)")
	await place(15, 11)
	await until(grounded, 30)
	press(["move_up"]); await ticks(5)
	check(st() == "CLIMBING", "up on rope → CLIMBING (%s)" % st())
	press(["move_right"])
	check(await until(func(): return grounded() and feet_y() <= 6 * B + 0.5, 180),
		"tops out through the hole onto floor 1 (feet row %.1f, %s)" % [feet_y() / B, st()])
	release_all()

	print("== G. water entry from height is safe (shaft drop)")
	await place(34, 2) # 16 blocks down to the waterline
	check(await until(func(): return player.state == Player.State.SURFACE_SWIM, 150), "enters SURFACE_SWIM (%s)" % st())
	check(player.health == Constants.MAX_HEALTH, "no fall damage on water entry (hp %d)" % player.health)
	check(player.compact, "compact hitbox while swimming")
	await ticks(60)
	check(st() == "SURFACE_SWIM" and absf(player.velocity.y) < 2.0, "auto-tread settles at the surface (vy %.2f)" % player.velocity.y)
	var top := player.global_position.y + player.hitbox_top()
	var surface := World.water_surface_y(Vector2(player.global_position.x, top + 8.0)) # query from inside the water
	check(absf((surface - top) - Constants.SURFACE_FLOAT_HEIGHT_PX) < 1.0, "floats with head above the waterline (top %.1f px above)" % (surface - top))
	check(not player.submerged and player.oxygen == Constants.BASE_OXYGEN_SECONDS, "breathing at the surface")

	print("== H. dive + neutral buoyancy (pool under floor 3)")
	await place(4, 19) # inside the flooded floor 4, just below the pool opening (clear of dressing)
	check(await until(func(): return player.state == Player.State.UNDERWATER, 10), "submerged entry → UNDERWATER (%s)" % st())
	await ticks(30)
	check(player.oxygen < Constants.BASE_OXYGEN_SECONDS, "oxygen drains while submerged (%.1f)" % player.oxygen)
	var y_rest := player.global_position.y
	await ticks(30)
	check(absf(player.global_position.y - y_rest) < 0.5 and st() == "UNDERWATER", "neutral buoyancy: holds depth")
	press(["move_right"]); await ticks(25)
	check(absf(player.velocity.x - Constants.UNDERWATER_SWIM_SPEED) < 1.0, "underwater swim 4 bl/s (%.2f)" % (player.velocity.x / B))
	release_all()
	await hold(["move_left"], 25)

	print("== I. ceiling is not a surface")
	await place(12, 21) # under the solid slab at row 18 (outside the pool)
	press(["move_up"]); await ticks(40)
	check(st() == "UNDERWATER" and player.submerged, "pinned to a flooded ceiling stays UNDERWATER (%s)" % st())
	var o2_before := player.oxygen
	await ticks(30)
	check(player.oxygen < o2_before, "oxygen keeps draining against the ceiling")
	release_all()

	print("== J. surface + refill + surface speed")
	await place(4, 21)
	press(["move_up"])
	check(await until(func(): return player.state == Player.State.SURFACE_SWIM, 150), "swims up to SURFACE_SWIM through the pool")
	release_all(); await ticks(5)
	check(player.oxygen == Constants.BASE_OXYGEN_SECONDS, "oxygen refills instantly in air")
	press(["move_right"]); await ticks(18)
	check(absf(player.velocity.x - Constants.SURFACE_SWIM_SPEED) < 1.0, "surface swim 5 bl/s (%.2f)" % (player.velocity.x / B))
	release_all()
	await hold(["move_left"], 18)
	await ticks(20)

	print("== K. water-jump ~2 blocks")
	var wj_start := player.global_position.y
	var wj_min := wj_start
	press(["jump"])
	for i in 45:
		await get_tree().physics_frame
		wj_min = minf(wj_min, player.global_position.y)
	release_all()
	var wj_rise := (wj_start - wj_min) / B
	check(absf(wj_rise - Constants.WATER_EXIT_JUMP_BLOCKS) < 0.35, "water-jump apex ~2 blocks (%.2f)" % wj_rise)
	check(await until(func(): return player.state == Player.State.SURFACE_SWIM, 90), "falls back into SURFACE_SWIM")

	print("== L. swim through 1-block hole between flooded floors")
	await place(10, 22)
	await ticks(5)
	press(["move_down"])
	check(await until(func(): return player.global_position.y > 25 * B, 240), "passes through the 1-block hole (row %.1f)" % (player.global_position.y / B))
	release_all()

	print("== M. drowning → death → respawn")
	player.oxygen = 0.5
	press(["move_down"]); await ticks(60)
	check(player.drowning, "drowning after oxygen hits zero")
	check(player.health < Constants.MAX_HEALTH, "drowning drains health (hp %.0f)" % player.health)
	check(await until(func(): return player.health == Constants.MAX_HEALTH and not player.drowning, 700), "dies and respawns with full health")
	release_all()
	check(absf(player.global_position.x - World.spawn_position.x) < 0.5, "respawned at world spawn")
	check(await until(grounded, 60), "lands after respawn (%s)" % st())
	check(player.oxygen == Constants.BASE_OXYGEN_SECONDS, "oxygen full after respawn")

	print("== N. fall damage on land")
	await place(17, 3)
	player.fall_start_y = player.global_position.y - 12 * B # pretend a 12+ block drop
	await until(grounded, 60)
	check(player.health < Constants.MAX_HEALTH and player.health > 0.0, "12+ block land fall damages (hp %.0f)" % player.health)
	player.health = Constants.MAX_HEALTH
	await place(17, 3)
	await until(grounded, 60)
	check(player.health == Constants.MAX_HEALTH, "≤8 block fall is free")

	print("== O. camera: centred on the player, wheel zoom")
	await place(5, 5)
	await until(grounded, 30)
	press(["move_right", "sprint"]); await ticks(60)
	check(player.camera.offset == Vector2.ZERO, "no lookahead offset while sprinting")
	release_all()
	var z0 := player.camera.zoom.x
	press(["zoom_in"]); await ticks(2); release_all(); await ticks(2)
	check(player.camera.zoom.x > z0, "wheel up zooms in (%.2f -> %.2f)" % [z0, player.camera.zoom.x])
	press(["zoom_out"]); await ticks(2); release_all(); await ticks(2)
	press(["zoom_out"]); await ticks(2); release_all(); await ticks(2)
	check(player.camera.zoom.x < z0, "wheel down zooms out (%.2f)" % player.camera.zoom.x)
	for i in 10:
		press(["zoom_out"]); await ticks(2); release_all(); await ticks(2)
	check(player.camera.zoom.x == Constants.CAMERA_ZOOM_LEVELS[0], "zoom clamps at the smallest level")
