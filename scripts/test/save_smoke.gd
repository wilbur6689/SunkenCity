extends Node
## Headless persistence gate test (CC-09/25): boot the city, play a little
## (build, stash loot, drop an item, open a door, explore), save world +
## character, wreck the live state, then reboot the scene from the files and
## verify everything came back — grid, water, objects, storage, character,
## map reveal, position.
## Run: godot --path . --headless res://scenes/test/save_smoke.tscn

const B := Constants.BLOCK_SIZE
const WNAME := "__test_world"
const CNAME := "__test_char"

var failures: PackedStringArray = []
var checks := 0

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

func _ready() -> void:
	# Start clean: no leftovers from a crashed run.
	_delete_saves()

	print("== A. play a little")
	var city: Node2D = load("res://scenes/city/city.tscn").instantiate()
	add_child(city)
	var player: Player = city.get_node("Player")
	player.set_multiplayer_authority(2)
	check(await until(func(): return player.state == Player.State.GROUNDED, 120), "player lands")
	var sc := World.cell_at(World.spawn_position)
	check(World.place_block("wood_block", sc + Vector2i(4, -1)), "player block placed")
	var chest := World.place_object("chest", sc + Vector2i(7, -1), true)
	chest.storage.slots[0] = {"id": "scrap_metal", "count": 7}
	World.spawn_item("plastic", 3, World.cell_center(sc + Vector2i(2, -1)))
	var door := World.place_object("wood_door", sc + Vector2i(9, -1), true)
	door.interact(player)
	check(door.open, "a door stands open")
	player.inventory.add("wood", 9)
	player.skills.add_xp("scrapping", 42.0)
	# M5 state: a modded instance, learned mods/recipes, and a tree ability
	player.inventory.add_stack({"id": "iron_knife", "count": 1, "mods": {"prefix": {"id": "sharp", "power": 2}}})
	player.known_recipes["iron_knife"] = true
	player.known_mods["of_the_deep"] = 3
	player.skills.abilities["field_strip"] = true
	World.time_of_day = 0.123
	await ticks(8) # let reveal + water run a moment
	var revealed := World.map_reveal.revealed_count()
	check(revealed > 100, "map reveal tracked %d cells (CC-25)" % revealed)
	var pockets_before := World.pockets.size()
	var links_before := 0
	for rec in World.object_records:
		if rec.has("link"):
			links_before += 1
	check(pockets_before > 0 and links_before == pockets_before * 2, "interior pockets present (%d, %d doorways)" % [pockets_before, links_before])

	print("== B. save")
	var t0 := Time.get_ticks_msec()
	SaveGame.save_world(WNAME, city.seed_value)
	SaveGame.save_character(CNAME, player, WNAME)
	var grid_hash := World.grid.content_hash()
	var water_hash := hash(World.water_sim.levels)
	var pos := player.global_position
	print("  (saved in %d ms)" % (Time.get_ticks_msec() - t0))
	check(not SaveGame.read_world(WNAME).is_empty(), "world file written and readable")
	check(SaveGame.world_names().has(WNAME) and SaveGame.character_names().has(CNAME), "saves appear in the pickers' lists")

	print("== C. wreck the live state")
	World.remove_block(sc + Vector2i(4, -1))
	player.inventory.slots.fill(null)
	check(World.grid.content_hash() != grid_hash, "live world diverged from the save")

	print("== D. reboot from the files")
	remove_child(city)
	city.queue_free()
	SaveGame.pending_world = WNAME
	SaveGame.pending_character = CNAME
	var city2: Node2D = load("res://scenes/city/city.tscn").instantiate()
	add_child(city2) # _ready -> _boot_loaded runs synchronously here
	var player2: Player = city2.get_node("Player")
	player2.set_multiplayer_authority(2)
	check(World.grid.content_hash() == grid_hash, "grid restored bit-for-bit (placed block included)")
	check(hash(World.water_sim.levels) == water_hash, "water levels restored exactly")
	check(absf(World.time_of_day - 0.123) < 0.01, "clock restored (%.3f)" % World.time_of_day)
	check(World.placed_blocks.size() >= 1, "placed-blocks ledger restored (GL-01)")
	var chest2 := World.object_at(sc + Vector2i(7, -1))
	check(chest2 != null and chest2.storage != null and chest2.storage.slots[0] != null \
			and chest2.storage.slots[0].id == "scrap_metal" and int(chest2.storage.slots[0].count) == 7,
			"chest and its loot restored")
	var door2 := World.object_at(door.cell) if door != null else null
	check(door2 != null and door2.open and not door2.is_solid(), "door still open (and non-solid)")
	var item_found := false
	for it in World.items_root.get_children():
		if it is WorldItem and it.id == "plastic" and it.count == 3:
			item_found = true
	check(item_found, "dropped item restored")
	check(player2.inventory.count("wood") >= 9, "character inventory restored")
	check(player2.skills.level("scrapping") >= 1, "character skills restored")
	var modded_ok := false
	for s in player2.inventory.slots:
		if s != null and s.id == "iron_knife" and s.get("mods", {}).get("prefix", {}).get("id", "") == "sharp":
			modded_ok = true
	check(modded_ok, "modded item instance restored with its mods (LT-05..07)")
	check(player2.knows_recipe("iron_knife"), "learned recipes restored (GL-06)")
	check(int(player2.known_mods.get("of_the_deep", 0)) == 3, "learned modifiers restored (LT-09)")
	check(player2.skills.has_ability("field_strip"), "tech-tree abilities restored (CC-18)")
	check(World.map_reveal.revealed_count() == revealed, "map reveal restored per character+world")
	var links_after := 0
	for rec in World.object_records:
		if rec.has("link"):
			links_after += 1
	check(World.pockets.size() == pockets_before and links_after == links_before 			and World.city_bounds.size.x == CityGen.WORLD_W, "interior pockets, doorway links and city width restored")
	check(player2.global_position.distance_to(pos) < 8.0, "character position restored in this world")
	await ticks(5)
	check(player2.state == Player.State.GROUNDED or player2.state == Player.State.AIRBORNE, "loaded game keeps running")

	_delete_saves()
	print("\nSave smoke: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)

func _delete_saves() -> void:
	for p: String in [SaveGame.WORLD_DIR + WNAME + SaveGame.WORLD_EXT, SaveGame.CHAR_DIR + CNAME + SaveGame.CHAR_EXT]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
