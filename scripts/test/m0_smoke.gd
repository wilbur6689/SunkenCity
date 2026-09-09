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
# Tower layout reminders (see test_tower.gd; 8 px cells, 2x the old rows):
# floors 1-3 dry (rows 2-35), slab rows 0/12/24/36/48/60 (2 thick); shaft
# x=66-71 with ladder at x=68-69; rope at x=30-31 rows 12-23; floor 3 = vent
# wall x=32-35 rows 26-33 + pool x=6-19 open at row 36; floors 4-5 flooded;
# swim hole at (20-21, 48).

func _run() -> void:
	print("== A. spawn + landing")
	check(await until(grounded, 60), "lands GROUNDED after spawn")
	check(absf(feet_y() - 12 * B) < 0.5, "spawn feet on floor-1 slab (y=%.1f)" % feet_y())
	check(player.health == Constants.MAX_HEALTH, "no fall damage from spawn drop")

	print("== B. walk / sprint / friction")
	press(["move_right"]); await ticks(20)
	check(absf(player.velocity.x - Constants.WALK_SPEED) < 1.0, "walk speed 5 bl/s (%.2f)" % (player.velocity.x / B))
	press(["sprint"]); await ticks(20)
	check(absf(player.velocity.x - Constants.SPRINT_SPEED) < 1.0, "sprint speed 7 bl/s (%.2f)" % (player.velocity.x / B))
	check(player.clip == "sprint" and player.sprite.texture == Player.CLIP_SHEET, "sprint plays the composed sprint clip (%s)" % player.clip)
	release_all(); await ticks(15)
	check(absf(player.velocity.x) < 0.01, "friction stops the player")
	check(grounded(), "still GROUNDED after run (%s)" % st())

	print("== C. jump height")
	# On the roof: interior rooms are 5 blocks, so a 2.8-block-tall player
	# legitimately taps the ceiling on a full 3-block jump indoors.
	await place(40, -1)
	await until(grounded, 30)
	var start_y := player.global_position.y
	var min_y := start_y
	press(["jump"])
	await ticks(2)
	check(player.clip == "jump_launch", "a jump starts with the launch one-shot (%s)" % player.clip)
	var saw_rise := false
	var saw_fall := false
	for i in 50:
		await get_tree().physics_frame
		min_y = minf(min_y, player.global_position.y)
		saw_rise = saw_rise or player.clip == "rise"
		saw_fall = saw_fall or player.clip == "fall"
	release_all()
	check(saw_rise and saw_fall, "rise then fall clips in the air")
	var rise := (start_y - min_y) / B
	check(absf(rise - Constants.JUMP_HEIGHT_BLOCKS) < 0.5, "jump apex ~6 blocks (%.2f)" % rise)
	check(await until(grounded, 60), "lands after jump")
	check(player.clip == "land", "landing plays the land one-shot (%s)" % player.clip)
	await ticks(30)
	check(player.clip == "idle", "then settles to idle (%s)" % player.clip)

	print("== D. crawl vent (floor 3, 2-cell / 16 px gap)")
	await place(28, 35)
	await until(grounded, 30)
	press(["crouch"]); await ticks(3)
	check(st() == "CRAWLING" and player.compact, "crouch → CRAWLING [compact] (%s)" % st())
	press(["move_right"]); await ticks(45)
	check(absf(player.velocity.x - Constants.CRAWL_SPEED) < 1.0, "crawl speed 2.5 bl/s (%.2f)" % (player.velocity.x / B))
	var mid_x := bx()
	Input.action_release("crouch"); await ticks(5)
	check(st() == "CRAWLING", "cannot stand inside the vent at x=%.1f (%s)" % [mid_x, st()])
	check(await until(grounded, 120), "stands up once clear of the vent")
	check(bx() > 36.0, "crawled through to x=%.1f" % bx())
	release_all()

	print("== E. ladder (shaft)")
	await place(68, 21)
	press(["move_up"]); await ticks(5)
	check(st() == "CLIMBING", "up on ladder → CLIMBING (%s)" % st())
	var y0 := player.global_position.y
	await ticks(30)
	check(y0 - player.global_position.y > 3.0 * B, "climbs upward (%.2f blocks)" % ((y0 - player.global_position.y) / B))
	check(absf(player.global_position.x - 69 * B) < 0.5, "centered on the 2-wide ladder (x=%.1f)" % player.global_position.x)
	check(absf(player.velocity.y + Constants.CLIMB_SPEED) < 1.0, "climb speed 4 bl/s")
	check(player.clip == "climb", "climbing plays the climb clip (%s)" % player.clip)
	release_all(); await ticks(5)
	check(st() == "CLIMBING" and absf(player.velocity.y) < 0.01, "holds position on ladder with no input")
	check(player.clip == "climb_idle" or player.clip == "climb_hang", "stopped on the rungs: climb idle/hang (%s)" % player.clip)
	press(["jump"]); await ticks(3)
	check(st() == "AIRBORNE", "jump leaves the ladder (%s)" % st())
	release_all()

	print("== E2. standing on the ladder top")
	await place(68, 21)
	press(["move_up"])
	check(await until(func(): return grounded() and absf(feet_y() - 2 * B) < 1.0, 300),
		"climbs off the top and stands on the ladder (feet row %.1f, %s)" % [feet_y() / B, st()])
	release_all(); await ticks(10)
	check(grounded() and absf(feet_y() - 2 * B) < 1.0, "keeps standing on the ladder top")
	press(["move_down"]); await ticks(20)
	check(st() == "CLIMBING" and feet_y() > 2 * B + 4.0, "down input climbs back down through the top (%s)" % st())
	release_all()
	await place(68, 21)
	press(["move_up"])
	await until(func(): return grounded(), 300)
	release_all()
	press(["jump"]); await ticks(5)
	check(player.velocity.y < 0.0 or st() == "AIRBORNE", "can jump from the ladder top")
	release_all()
	check(await until(func(): return grounded(), 120), "falls back and lands on the ladder top again")

	print("== F. rope through the floor hole (floor 2 → floor 1)")
	await place(30, 23)
	await until(grounded, 30)
	press(["move_up"]); await ticks(5)
	check(st() == "CLIMBING", "up on rope → CLIMBING (%s)" % st())
	press(["move_right"])
	check(await until(func(): return grounded() and feet_y() <= 12 * B + 0.5, 180),
		"tops out through the hole onto floor 1 (feet row %.1f, %s)" % [feet_y() / B, st()])
	release_all()
	# Rope tops are platforms like ladder tops (user request 2026-09-06): a
	# fall onto the rope's top cell lands there instead of dropping through.
	await place(30, 9)
	check(await until(grounded, 90) and absf(feet_y() - 12 * B) < 1.0, "falling onto the rope top lands on it (feet row %.1f)" % (feet_y() / B))
	press(["move_down"]); await ticks(6)
	check(st() == "CLIMBING", "pressing down climbs through the rope top (%s)" % st())
	release_all()

	print("== G. water entry from height is safe (shaft drop)")
	await place(68, 5) # 32 cells down to the waterline
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
	await place(8, 39) # inside the flooded floor 4, just below the pool opening (clear of dressing)
	check(await until(func(): return player.state == Player.State.UNDERWATER, 10), "submerged entry → UNDERWATER (%s)" % st())
	await ticks(30)
	check(player.oxygen < Constants.BASE_OXYGEN_SECONDS, "oxygen drains while submerged (%.1f)" % player.oxygen)
	var y_rest := player.global_position.y
	await ticks(30)
	check(absf(player.global_position.y - y_rest) < 0.5 and st() == "UNDERWATER", "neutral buoyancy: holds depth")
	check(player.clip == "underwater_float" and player.sprite.rotation == 0.0, "still underwater: the float clip, body not rotated (%s)" % player.clip)
	press(["move_right"]); await ticks(25)
	check(absf(player.velocity.x - Constants.UNDERWATER_SWIM_SPEED) < 1.0, "underwater swim %.0f bl/s (%.2f)" % [Constants.UNDERWATER_SWIM_SPEED / B, player.velocity.x / B])
	check(player.clip == "prone_swim", "swimming plays the prone swim (%s)" % player.clip)
	release_all()
	await hold(["move_left"], 25)

	print("== I. ceiling is not a surface")
	await place(24, 43) # under the solid slab at row 18 (outside the pool)
	press(["move_up"]); await ticks(40)
	check(st() == "UNDERWATER" and player.submerged, "pinned to a flooded ceiling stays UNDERWATER (%s)" % st())
	var o2_before := player.oxygen
	await ticks(30)
	check(player.oxygen < o2_before, "oxygen keeps draining against the ceiling")
	release_all()

	print("== J. surface + refill + surface speed")
	await place(8, 43)
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

	print("== L. swim through the 2-cell hole between flooded floors")
	await place(20, 45)
	player.global_position.x = 21 * B # centred on the 2-wide hole (cols 20-21)
	await ticks(5)
	press(["move_down"])
	check(await until(func(): return player.global_position.y > 50 * B, 240), "passes through the 2-cell hole (row %.1f)" % (player.global_position.y / B))
	release_all()

	print("== M. drowning → death → respawn")
	player.oxygen = 0.5
	press(["move_down"]); await ticks(60)
	check(player.drowning, "drowning after oxygen hits zero")
	check(player.health < Constants.MAX_HEALTH, "drowning drains health (hp %.0f)" % player.health)
	check(player.clip == "drowning", "the drowning struggle clip plays (%s)" % player.clip)
	check(await until(func(): return player.dying, 900), "dies")
	await ticks(3)
	check(player.clip == "death_water", "the water death clip plays through the scene (%s)" % player.clip)
	check(await until(func(): return player.health == Constants.MAX_HEALTH and not player.drowning and not player.dying, 1100), "dies (3 s scene) and respawns with full health")
	check(player._action_clip == "wake_bed", "waking at the spawn plays wake_bed (%s)" % player._action_clip)
	release_all()
	check(absf(player.global_position.x - World.spawn_position.x) < 0.5, "respawned at world spawn")
	check(await until(grounded, 60), "lands after respawn (%s)" % st())
	check(player.oxygen == Constants.BASE_OXYGEN_SECONDS, "oxygen full after respawn")

	print("== N. fall damage on land")
	await place(34, 7)
	player.fall_start_y = player.global_position.y - 24 * B # pretend a 24+ block (12 ft over safe) drop
	await until(grounded, 60)
	check(player.health < Constants.MAX_HEALTH and player.health > 0.0, "24+ block land fall damages (hp %.0f)" % player.health)
	player.health = Constants.MAX_HEALTH
	await place(34, 7)
	await until(grounded, 60)
	check(player.health == Constants.MAX_HEALTH, "≤16 block fall is free")

	print("== P. block stairs are walked, not jumped (user request 2026-09-07)")
	await place(40, 11) # floor 0, standing row 11 (the slab is rows 12-13)
	await until(grounded, 30)
	# Two 2-cell-wide steps, 2 and 4 cells tall, in the open floor ahead.
	check(World.rect_is_clear(Rect2(44 * B, 5 * B, 4 * B, 7 * B)), "floor 0 is clear where the stairs go")
	var placed := 0
	for x in [44, 45]:
		for y in [10, 11]:
			placed += int(World.place_block("wood_block", Vector2i(x, y)))
	for x in [46, 47]:
		for y in [8, 9, 10, 11]:
			placed += int(World.place_block("wood_block", Vector2i(x, y)))
	check(placed == 12, "12 stair blocks placed (%d)" % placed)
	var left_floor := false
	press(["move_right"])
	for i in 40: # ~53 px: onto the top step, short of its far edge
		await get_tree().physics_frame
		left_floor = left_floor or st() != "GROUNDED"
	release_all()
	check(absf(feet_y() - 8 * B) < 1.0 and grounded(), "walked up two 2-cell steps onto the top (feet row %.1f, %s)" % [feet_y() / B, st()])
	check(not left_floor, "never left GROUNDED on the way up")
	left_floor = false
	press(["move_left"])
	for i in 60:
		await get_tree().physics_frame
		left_floor = left_floor or st() != "GROUNDED"
	release_all()
	check(absf(feet_y() - 12 * B) < 1.0 and grounded(), "walked back down to the floor (feet row %.1f)" % (feet_y() / B))
	check(not left_floor, "stepped down without a fall")
	for x in [44, 45, 46, 47]:
		for y in [8, 9, 10, 11]:
			World.remove_block(Vector2i(x, y))

	print("== O. camera: centred on the player, wheel zoom")
	await place(10, 11)
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
	check(is_equal_approx(player.camera.zoom.x, Constants.CAMERA_ZOOM_LEVELS[0] / UIScale.content_scale()), "zoom clamps at the smallest level")
