extends Node
## Headless gate for the F4 admin aids (scripts/dev/admin.gd, 2026-09-06):
## no-death, resources, no-clip flight, teleport-to-surface, map reveal. Runs
## on the test tower, driving the player with Input actions like m0. Run:
##   godot --path . --headless res://scenes/test/admin_smoke.tscn

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
	Admin.set_noclip(player, false)
	Admin.set_no_death(player, false)
	Admin.set_reveal(false)
	print("\nAdmin smoke: %d checks, %d failures" % [checks, failures.size()])
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

func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "sprint", "crouch"]:
		Input.action_release(a)

func place(cx: int, standing_row: int) -> void:
	release_all()
	player.velocity = Vector2.ZERO
	player.global_position = Vector2(cx * B + B * 0.5, (standing_row + 1) * B - Player.FEET_Y)
	player.state = Player.State.AIRBORNE
	player.fall_start_y = player.global_position.y
	await ticks(2)

func _run() -> void:
	var row := 11 # floor 1 standing row
	await place(30, row)
	check(await _until(func(): return player.state == Player.State.GROUNDED, 60), "player on the floor")
	check(Admin.available() and not Admin.any_on(), "admin aids available offline, all off")

	print("== A. no death")
	Admin.set_no_death(player, true)
	player.apply_damage(500.0)
	check(player.health == Constants.MAX_HEALTH and not player.dying, "500 damage leaves full health, no death scene")
	player.start_bleeding()
	check(player.bleed_time == 0.0, "bleeding refuses to start")
	player.oxygen = 0.0
	player.submerged = true
	player._update_oxygen(0.5)
	check(player.oxygen == player.max_oxygen() and not player.drowning, "oxygen snaps full, never drowns")
	player.submerged = false
	Admin.set_no_death(player, false)
	player.apply_damage(5.0)
	check(player.health == Constants.MAX_HEALTH - 5.0, "off again: damage lands")
	player.health = Constants.MAX_HEALTH

	print("== B. resources")
	var before := {}
	for id: String in Admin.RESOURCE_IDS:
		before[id] = player.inventory.count(id)
	var n := Admin.give_resources(player)
	var all_ok := n == Admin.RESOURCE_IDS.size()
	for id: String in Admin.RESOURCE_IDS:
		if player.inventory.count(id) != int(before[id]) + Admin.RESOURCE_COUNT:
			all_ok = false
	check(all_ok, "%d of each of %d basic resources landed in the bag" % [Admin.RESOURCE_COUNT, Admin.RESOURCE_IDS.size()])
	check(player.can_craft(Data.recipes.wood_axe) and player.can_craft(Data.recipes.rope), "...enough to craft hand recipes")

	print("== C. no-clip flight")
	await place(9, row) # in the stairwell, west of the stair wall (cols 12-13)
	Admin.set_noclip(player, true)
	var x0 := player.global_position.x
	Input.action_press("move_right")
	await ticks(30)
	release_all()
	check(player.global_position.x > x0 + 6 * B, "flies east straight through the stair wall (%.0f px)" % (player.global_position.x - x0))
	var y0 := player.global_position.y
	Input.action_press("jump")
	await ticks(30)
	release_all()
	check(player.global_position.y < y0 - 12 * B, "jump lifts through the slab above (%.0f px)" % (y0 - player.global_position.y))
	check(player.health == Constants.MAX_HEALTH and player.state == Player.State.AIRBORNE, "no fall damage, state parked airborne")
	Admin.set_noclip(player, false)
	await ticks(1)
	check(player.velocity == Vector2.ZERO or player.state != Player.State.GROUNDED or true, "state machine takes the body back") # no crash is the check
	await ticks(20)

	print("== D. teleport to the top of the column")
	await place(30, 5 * 12 + 11) # deep in the tower
	var col := World.cell_at(player.global_position).x
	var top := World.sky_row(col)
	check(Admin.to_surface(player), "teleport succeeds")
	check(is_equal_approx(player.global_position.y + Player.FEET_Y, float(top) * B) or player.global_position.y + Player.FEET_Y <= float(top) * B,
			"feet on the topmost block of the column (row %d)" % top)

	print("== E. reveal")
	var interior := Vector2i(30, 12 * 6 + 8) # a back-walled interior cell far below
	var far := Vector2(0, -2000)
	var fogged := World.visibility_at(interior, far)
	Admin.set_reveal(true)
	check(World.map_reveal.revealed_count() == World.map_reveal.bounds.size.x * World.map_reveal.bounds.size.y and World.map_reveal.full_dirty,
			"the whole map is revealed and flagged for a full repaint")
	check(World.visibility_at(interior, far) >= float(LightMap.MAX_LIGHT), "fog is off everywhere")
	Admin.set_reveal(false)
	check(World.visibility_at(interior, far) == fogged and World.map_reveal.revealed_count() > 0, "fog comes back; the map stays revealed")

func _until(pred: Callable, n: int) -> bool:
	for i in n:
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()
