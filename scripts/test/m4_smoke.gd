extends Node
## Headless M4 gate test: danger. Enemy framework + walker/crawler/Drowned
## behaviour, the shared proximity aggro (night radii included), melee /
## firearms / speargun combat, bleeding + regen, zombie pounding of
## player-placed blocks, the death-loop backpack (dies underwater, pack pins
## to the ceiling, dive back and recover), red moon trigger + waves, fish
## hand-grab, and the world-save round trip for all of it. Run:
##   godot --path . --headless res://scenes/test/m4_smoke.tscn

const B := Constants.BLOCK_SIZE

var tower: Node2D
var player: Player
var failures: PackedStringArray = []
var checks := 0

func _ready() -> void:
	tower = load("res://scenes/test/test_tower.tscn").instantiate()
	add_child(tower)
	player = tower.get_node("Player")
	player.set_multiplayer_authority(2) # we feed the snapshot, not Input
	await get_tree().physics_frame
	await _run()
	print("\nM4 smoke: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)

# --- Helpers ---

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

## Teleport the player's feet onto standing row `row` at column `cx`.
func place(cx: int, row: int) -> void:
	player.velocity = Vector2.ZERO
	player.global_position = Vector2((cx + 0.5) * B, (row + 1) * B - Player.FEET_Y)
	await ticks(3)

func aim(pos: Vector2) -> void:
	player.aim_position = pos

## Spawn an enemy standing on `row` at column `cx` and return its record.
func spawn(type_id: String, cx: int, row: int) -> Dictionary:
	var h := float(Data.enemies[type_id].size[1])
	var rec := World.add_enemy_record(type_id, Vector2((cx + 0.5) * B, (row + 1) * B - h * 0.5 - 1.0))
	World.refresh_objects_around(player.global_position)
	return rec

func clear_enemies() -> void:
	for rec in World.enemy_records.duplicate():
		World.remove_enemy(rec)
	await ticks(2)

func hold_item(id: String) -> bool:
	var inv := player.inventory
	for i in inv.size():
		if inv.slots[i] != null and inv.slots[i].id == id:
			var tmp = inv.slots[0]
			inv.set_slot(0, inv.slots[i])
			inv.set_slot(i, tmp)
			player.selected_slot = 0
			player.bare_hands = false
			return true
	return false

func inv_count(id: String) -> int:
	return player.inventory.count(id)

func items_of(id: String) -> int:
	var n := 0
	for it in World.items_root.get_children():
		if it is WorldItem and it.id == id and not it.is_queued_for_deletion():
			n += it.count
	return n

# --- Scenario ---

func _run() -> void:
	World.time_of_day = 0.5 # broad daylight unless a check says otherwise
	var row := 11 # floor 2 standing row (dry band)

	print("== A. data + framework (GD-01/16/23)")
	check(Data.enemies.size() == 6, "6 enemy types loaded (roster + fish)")
	for band in ["dry", "shallows", "cold", "dark", "crush"]:
		check(not Data.enemy_stats("walker", band).is_empty(), "walker stats authored for " + band)
	check(float(Data.enemy_stats("walker", "crush").hp) > float(Data.enemy_stats("walker", "dry").hp),
		"per-band tables scale strength with depth")
	check(float(Data.enemy_stats("drowned", "shallows").hp) == float(Data.enemy_stats("drowned", "dark").hp),
		"missing-band lookup falls back to the nearest authored row")
	check(float(Data.enemy_stats("drowned", "dark").speed) * B > Constants.UNDERWATER_SWIM_SPEED,
		"the Drowned out-swim the player (GD-14)")

	print("== B. proximity aggro — the one shared sense (GD-06/29)")
	await place(10, row)
	var w1 := spawn("walker", 23, row) # 13 blocks: outside the day radius (10)
	await ticks(3)
	var wnode: Enemy = w1.node
	check(wnode != null, "record inside the window runs as a node")
	check(wnode.target == null, "13 blocks away by day: not noticed (radius 10)")
	World.time_of_day = 0.0 # midnight
	check(World.is_night(), "midnight is night")
	await ticks(4)
	check(wnode.target != null, "night grows surface aggro radii (GD-29): now hunted")
	World.time_of_day = 0.5

	print("== C. walker: chase, contact damage, bleeding (GD-04/21)")
	var hp0 := player.health
	check(await until(func(): return wnode.global_position.x < 22.0 * B, 240), "walker chases toward the player")
	check(await until(func(): return player.health < hp0, 600), "contact does damage")
	check(player.combat_timer < 1.0, "taking damage resets the regen delay (GL-21)")
	await clear_enemies()

	print("== D. pound player-placed blocks only (GD-04)")
	player.health = Constants.MAX_HEALTH
	await place(12, row)
	for dy in 3: # a wall between player and zombie
		World.place_block("wood_block", Vector2i(16, row - dy))
	var wall_key := Vector2i(16, row)
	var wall_hp: float = World.placed_blocks[wall_key].hp
	var w2 := spawn("walker", 19, row)
	check(await until(func(): return not World.placed_blocks.has(wall_key) \
		or World.placed_blocks[wall_key].hp < wall_hp, 600), "blocked walker pounds the placed block")
	check(World.grid.structure_at(Vector2i(16, row + 1)) != WorldGrid.M.AIR, "building structure is never pounded")
	for dy in 3:
		World.remove_block(Vector2i(16, row - dy))
	await clear_enemies()

	print("== E. melee (GD-07/08)")
	player.inventory.add("scrap_sword", 1)
	check(hold_item("scrap_sword"), "scrap sword in hand")
	var w3 := spawn("walker", 14, row)
	await place(12, row)
	var killed := false
	for i in 900:
		if not World.enemy_records.has(w3):
			killed = true
			break
		player.health = Constants.MAX_HEALTH # the walker fights back; stay standing
		if w3.node != null:
			aim(w3.node.global_position)
		player.wants_use = true
		await get_tree().physics_frame
	player.wants_use = false
	check(killed, "sword swings kill the walker")
	check(not World.enemy_records.has(w3), "killed record is gone — cleared stays cleared (GD-02/03)")
	# Underwater melee is slowed (knives least): compare swing cooldowns.
	player.interaction.attack_cooldown = 0.0
	player.wants_use = true
	await ticks(1)
	player.wants_use = false
	var dry_cd := player.interaction.attack_cooldown
	await place(8, 21) # flooded floor 4
	check(player.in_water, "standing in the flooded floor")
	player.interaction.attack_cooldown = 0.0
	player.wants_use = true
	await ticks(1)
	player.wants_use = false
	check(player.interaction.attack_cooldown > dry_cd, "melee swings slower underwater (GD-08)")
	player.wants_use = false

	print("== F. firearms: loud above, dead below (LT-01)")
	player.inventory.add("pistol", 1)
	player.inventory.add("pistol_rounds", 12)
	check(hold_item("pistol"), "pistol in hand")
	await place(15, row) # clear lane: no authored blocks between 15 and 19
	var w4 := spawn("walker", 19, row)
	var whp: float = w4.hp
	aim(Vector2(19.5 * B, (row + 1) * B - 12.0))
	player.interaction.attack_cooldown = 0.0
	player.wants_use = true
	await ticks(2)
	player.wants_use = false
	check(float(w4.hp) < whp, "hitscan shot lands (walker hp %d -> %d)" % [int(whp), int(w4.hp)])
	check(inv_count("pistol_rounds") == 11, "one round consumed")
	await clear_enemies()
	await place(8, 21) # submerged
	check(player.submerged, "head under water")
	player.interaction.attack_cooldown = 0.0
	player.wants_use = true
	await ticks(2)
	player.wants_use = false
	check(inv_count("pistol_rounds") == 11, "firearms refuse to fire submerged")

	print("== G. speargun + retrievable bolts vs the Drowned (GD-08/13, LT-16)")
	player.inventory.add("speargun", 1)
	player.inventory.add("speargun_bolt", 20)
	check(hold_item("speargun"), "speargun in hand")
	var d1 := spawn("drowned", 16, 21)
	await place(8, 21)
	var d_killed := false
	for i in 900:
		if not World.enemy_records.has(d1):
			d_killed = true
			break
		player.health = Constants.MAX_HEALTH
		player.oxygen = player.max_oxygen()
		if d1.node != null:
			aim(d1.node.global_position)
		player.wants_use = true
		await get_tree().physics_frame
	player.wants_use = false
	check(d_killed, "speargun bolts kill the Drowned underwater")
	check(items_of("speargun_bolt") > 0, "spent bolts drop as retrievable items")
	await clear_enemies()

	print("== H. shark drops + light loot (GD-11/24)")
	var s1 := spawn("shark", 6, 20)
	await ticks(2)
	check(s1.node != null, "shark spawned in open water")
	while World.enemy_records.has(s1):
		(s1.node as Enemy).hurt(50.0, player.global_position)
		await ticks(1)
	check(items_of("fish_meat") >= 2, "shark drops fish meat (GD-24)")

	print("== I. bleeding + cures + regen (GD-21, GL-21)")
	player.health = Constants.MAX_HEALTH
	player.start_bleeding()
	await ticks(60)
	check(player.health < Constants.MAX_HEALTH, "bleeding drips health")
	check(hold_item("bandage"), "bandage in hand")
	player.use_item(0)
	check(player.bleed_time == 0.0, "bandage stops the bleeding")
	player.health = 50.0
	player.combat_timer = Constants.PASSIVE_REGEN_COMBAT_DELAY + 1.0
	await ticks(90)
	check(player.health > 50.0, "slow out-of-combat regen")

	print("== J. death loop: pack floats to the ceiling, dive to recover (CC-07)")
	player.inventory.add("wood", 10)
	var wood_held := inv_count("wood")
	# A flooded column with the waterline slab overhead and open water below.
	var death_x := -1
	for x in range(12, 32):
		if not World.is_solid_cell(Vector2i(x, 18)):
			continue
		var open := true
		for y in range(19, 23):
			if World.is_solid_cell(Vector2i(x, y)) or not World.is_water_cell(Vector2i(x, y)):
				open = false
				break
		if open:
			death_x = x
			break
	check(death_x > 0, "found an open flooded column under the slab (x=%d)" % death_x)
	await place(death_x, 21)
	player.apply_damage(9999.0)
	await ticks(2)
	var packs := get_tree().get_nodes_in_group("backpacks")
	check(packs.size() == 1, "death spawned the backpack where you fell")
	check(inv_count("wood") == 0, "inventory transferred into the pack")
	check(player.equipped("suit") == "clothes", "equipped gear stays on the body")
	check(player.health == Constants.MAX_HEALTH and player.global_position.distance_to(
		World.spawn_position) < 8.0 * B, "respawned at the spawn point")
	var pack: Node2D = packs[0]
	check(await until(func(): return pack.global_position.y < 19.5 * B and pack.velocity == Vector2.ZERO, 300),
		"unobstructed pack floats up and pins under the flooded ceiling")
	player.global_position = pack.global_position + Vector2(0, 8) # dive back to it
	player.velocity = Vector2.ZERO
	check(await until(func(): return inv_count("wood") == wood_held, 240), "recover-on-touch returns everything")

	print("== K. red moon (CC-14, GL-15, GD-23)")
	await place(10, row)
	player.health = Constants.MAX_HEALTH
	await clear_enemies()
	World.day_count = 6
	World.next_red_moon_day = 6
	World.time_of_day = 0.95 # dusk-night
	await ticks(2)
	check(World.red_moon_active, "a due red moon rises with the night")
	check(World._wave_timer > 0.0, "the first wave fired with the moonrise")
	for i in 30: # the ring spawner, driven directly for a deterministic count
		World._spawn_wave_zombie(player.global_position, 1.3)
	check(World.enemy_records.size() >= 3,
		"waves spawn converging on the player (%d zombies)" % World.enemy_records.size())
	var wave_rec: Dictionary = World.enemy_records[0]
	check(float(wave_rec.stats.hp) > float(Data.enemy_stats(wave_rec.type, wave_rec.band).hp),
		"wave stats scale up with the day count (GD-23)")
	World.time_of_day = 0.5
	await ticks(2)
	check(not World.red_moon_active, "dawn ends the red moon")
	check(World.next_red_moon_day >= World.day_count + Constants.RED_MOON_MIN_DAYS,
		"next moon scheduled 5-10 days out")
	check(not World.enemy_records.is_empty(), "stragglers persist after dawn (GD-02)")

	print("== L. night floaters disperse at dawn (GD-29)")
	World.time_of_day = 0.0
	await ticks(2)
	var nf := World.add_enemy_record("floater", Vector2(6.5 * B, 18.5 * B), 1.0, true)
	check(not nf.is_empty(), "night floater spawned on the surface")
	World.time_of_day = 0.5
	await ticks(2)
	check(not World.enemy_records.has(nf), "night extras disperse at dawn")

	print("== M. fish: swim close + interact (GD-09/28)")
	var fish := World.add_enemy_record("fish_school", Vector2(6.5 * B, 20.5 * B))
	World.refresh_objects_around(player.global_position)
	var stock0: int = fish.stock
	player.global_position = Vector2(6.5 * B, 20.5 * B) + Vector2(16, 0)
	player.velocity = Vector2.ZERO
	await ticks(2)
	aim(Vector2(6.5 * B, 20.5 * B))
	player.wants_interact = true
	await ticks(2)
	check(inv_count("fish_meat") >= 1, "grabbed a fish by hand")
	check(int(fish.get("stock", stock0)) == stock0 - 1 or not World.enemy_records.has(fish),
		"the school's stock went down")

	print("== N. world-save round trip (M4 state)")
	var live := 0
	for rec in World.enemy_records:
		if not rec.get("night", false):
			live += 1
	SaveGame.save_world("m4_smoke_tmp", 1)
	var data := SaveGame.read_world("m4_smoke_tmp")
	check((data.enemies as Array).size() == live, "enemy records persist (%d)" % live)
	check(int(data.day_count) == World.day_count and int(data.next_red_moon_day) == World.next_red_moon_day,
		"day counter + red moon schedule persist")
	check(data.has("backpacks"), "backpacks are part of the world save")
	SaveGame.delete_world("m4_smoke_tmp")
