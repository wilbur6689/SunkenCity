extends Node
## Headless M1 gate test: wake in the medical room -> scrap it -> craft the
## three starter tools -> build and light a small base with a working bed
## spawn — through the same player API the UI uses, no debug items for the
## gate itself. Feeds the player's input snapshot directly (the LAN path)
## instead of Input. Run:
##   godot --path . --headless res://scenes/test/m1_smoke.tscn

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
	player.interaction.rng.seed = 7
	await get_tree().physics_frame
	await _run()
	print("\nM1 smoke: %d checks, %d failures" % [checks, failures.size()])
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

func goto(cx: int) -> void:
	player.velocity = Vector2.ZERO
	player.global_position.x = cx * B + B * 0.5
	await ticks(3)

func aim(cell: Vector2i) -> void:
	player.aim_position = World.cell_center(cell)

## Hold scrap (RMB) on a cell until pred or timeout.
func hold_scrap(cell: Vector2i, pred: Callable, n: int) -> bool:
	aim(cell)
	player.wants_use_secondary = true
	var ok := await until(pred, n)
	player.wants_use_secondary = false
	await ticks(2)
	return ok

## Hold primary use on a cell until pred or timeout.
func hold_use(cell: Vector2i, pred: Callable, n: int) -> bool:
	aim(cell)
	player.wants_use = true
	var ok := await until(pred, n)
	player.wants_use = false
	await ticks(2)
	return ok

func press_use(cell: Vector2i) -> void:
	aim(cell)
	player.wants_use = true
	await ticks(1)
	player.wants_use = false
	await ticks(2)

func press_secondary(cell: Vector2i) -> void:
	aim(cell)
	player.wants_use_secondary = true
	await ticks(1)
	player.wants_use_secondary = false
	await ticks(2)

func interact(cell: Vector2i) -> void:
	aim(cell)
	player.wants_interact = true
	await ticks(2)

## Put the first stack of `id` into hotbar slot 0 and select it.
func hold_item(id: String) -> bool:
	var inv := player.inventory
	for i in inv.size():
		if inv.slots[i] != null and inv.slots[i].id == id:
			var tmp = inv.slots[0]
			inv.set_slot(0, inv.slots[i])
			inv.set_slot(i, tmp)
			player.selected_slot = 0
			return true
	return false

func obj_at(cell: Vector2i) -> WorldObject:
	return World.object_at(cell)

func craft(id: String) -> bool:
	return player.craft(Data.recipes[id])

func inv_count(id: String) -> int:
	return player.inventory.count(id)

# --- Scenario ---

func _run() -> void:
	var inv := player.inventory
	var row := 5 # floor 1 standing row
	print("== A. wake in the medical room")
	check(await until(func(): return player.state == Player.State.GROUNDED, 60), "on the floor")
	check(inv_count("bandage") == 2 and inv_count("food_can") == 1, "starting kit: 2 bandages + 1 food (LT-30)")
	var scrap_count := 0
	for o in tower.get_node("Objects").get_children():
		if o.def.kind == "scrap" and o.cell.y <= 5: # the medical room only
			scrap_count += 1
	check(scrap_count == 8, "medical room furnished with 8 scrappable objects (%d)" % scrap_count)
	check(obj_at(Vector2i(12, row)) != null and obj_at(Vector2i(12, row)).id == "chair", "chair registered on its cells")

	print("== B. hand-scrap a chair (hold-to-scrap)")
	await goto(14)
	var chair := obj_at(Vector2i(12, row))
	check(await hold_scrap(Vector2i(12, row), func(): return player.interaction.scrap_progress > 0.2, 60), "progress builds while holding scrap (RMB)")
	var t0 := Time.get_ticks_msec()
	check(await hold_scrap(Vector2i(12, row), func(): return obj_at(Vector2i(12, row)) == null, 300), "chair scrapped and removed")
	check(inv_count("wood") >= 3, "field yield ~half (wood %d)" % inv_count("wood"))
	check(player.skills.xp["scrapping"] >= 3.0, "scrapping XP awarded")

	print("== C. gates: tool tier and skill")
	await goto(25)
	await hold_scrap(Vector2i(27, row), func(): return false, 10)
	check(obj_at(Vector2i(27, row)) != null and player.interaction.message.begins_with("Needs a tool"), "fridge refuses bare hands (%s)" % player.interaction.message)

	print("== D. scrap the room by hand")
	await goto(19)
	check(await hold_scrap(Vector2i(18, row), func(): return obj_at(Vector2i(18, row)) == null, 400), "desk scrapped")
	await goto(8)
	check(await hold_scrap(Vector2i(9, row), func(): return obj_at(Vector2i(9, row)) == null, 400), "cabinet scrapped")
	check(await hold_scrap(Vector2i(6, row), func(): return obj_at(Vector2i(6, row)) == null, 400), "med cart scrapped")
	await goto(5)
	check(await hold_scrap(Vector2i(3, row), func(): return obj_at(Vector2i(3, row)) == null, 400), "bed frame scrapped")
	check(player.skills.level("scrapping") >= 1, "Scrapping reached level 1 (xp %.0f)" % player.skills.xp["scrapping"])

	print("== E. craft the scrap knife, use it on the metal furniture")
	check(player.can_craft(Data.recipes.scrap_knife), "can craft scrap knife")
	check(craft("scrap_knife") and inv_count("scrap_knife") == 1, "scrap knife crafted")
	check(hold_item("scrap_knife"), "knife in hand")
	await goto(25)
	check(await hold_scrap(Vector2i(24, row), func(): return obj_at(Vector2i(24, row)) == null, 300), "locker scrapped with knife")
	check(await hold_scrap(Vector2i(27, row), func(): return obj_at(Vector2i(27, row)) == null, 400), "fridge scrapped (tool + skill gate passed)")
	check(inv_count("scrap_metal") >= 10 and inv_count("plastic") >= 2, "metal %d plastic %d" % [inv_count("scrap_metal"), inv_count("plastic")])

	print("== F. three starter tools (GL-03)")
	check(craft("hammer") and craft("pry_bar"), "hammer + pry bar crafted")
	check(inv_count("scrap_knife") == 1 and inv_count("hammer") == 1 and inv_count("pry_bar") == 1, "all three tools in the bag")

	print("== G. workbench -> station crafting + full-yield scrapping")
	check(craft("workbench"), "workbench crafted by hand")
	await goto(13)
	check(hold_item("workbench"), "workbench in hand")
	await press_use(Vector2i(10, row))
	var wb := obj_at(Vector2i(10, row))
	check(wb != null and wb.id == "workbench" and inv_count("workbench") == 0, "workbench placed at (10,5)")
	check(World.stations_near(player.global_position, Constants.REACH_BLOCKS * B * 1.5).has("workbench"), "workbench in crafting range")
	var wood_before := inv_count("wood")
	await goto(21)
	# Long LMB press picks furniture up whole (short click only hints)
	aim(Vector2i(22, row))
	player.wants_use = true
	await ticks(40)
	player.wants_use = false
	await ticks(2)
	check(inv_count("chair") == 1 and obj_at(Vector2i(22, row)) == null, "long press picked up the second chair whole")
	await goto(13)
	check(player.scrap_item("chair", 1) and inv_count("wood") >= wood_before + 5, "station scrap = full yield (wood %d -> %d)" % [wood_before, inv_count("wood")])
	var stations := World.stations_near(player.global_position, Constants.REACH_BLOCKS * B * 1.5)
	var bed_recipe: Dictionary = Data.recipes.bed
	check(stations.has(bed_recipe.station), "bed recipe unlocked by the workbench")

	print("== H. bed -> spawn point")
	check(craft("bed") and hold_item("bed"), "bed crafted")
	await goto(5)
	await press_use(Vector2i(2, row))
	var bed := obj_at(Vector2i(2, row))
	check(bed != null and bed.id == "bed", "bed placed at (2,5)")
	await interact(Vector2i(3, row))
	check(absf(World.spawn_position.x - bed.bottom_center().x) < 0.5, "bed set the spawn point (GL-23)")
	player.apply_damage(999.0)
	await ticks(30)
	check(absf(player.global_position.x - bed.bottom_center().x) < 0.5 and player.health == Constants.MAX_HEALTH, "died and respawned at the bed")
	# M4 death loop (CC-07): dying moved the whole bag into a backpack at the
	# death spot — walk back over it to take everything back.
	check(not get_tree().get_nodes_in_group("backpacks").is_empty() and inv.is_empty(), "death dropped the bag as a backpack (CC-07)")
	await goto(5)
	check(await until(func(): return get_tree().get_nodes_in_group("backpacks").is_empty(), 240), "backpack recovered on touch")

	print("== I. light the base")
	check(craft("standing_lamp") and hold_item("standing_lamp"), "lamp crafted")
	await goto(6)
	await press_use(Vector2i(7, row))
	var lamp := obj_at(Vector2i(7, row))
	check(lamp != null and lamp.id == "standing_lamp", "lamp placed")
	var has_light := false
	if lamp != null:
		for c in lamp.get_children():
			if c is PointLight2D:
				has_light = true
	check(has_light, "lamp emits light")

	print("== J. blocks: place, HP + tool-gated break, structure unbreakable")
	check(craft("wood_block") and hold_item("wood_block"), "wood blocks crafted")
	await goto(17)
	await press_use(Vector2i(20, row))
	await press_use(Vector2i(20, row - 1))
	check(World.has_block_cell(Vector2i(20, row)) and World.is_player_block(Vector2i(20, row - 1)), "two blocks placed (adjacency ok)")
	check(not World.can_place_block("wood_block", Vector2i(45, 2), player), "no floating placement without a neighbour (outside the tower)")
	check(hold_item("hammer"), "hammer in hand")
	check(await hold_use(Vector2i(20, row - 1), func(): return not World.has_block_cell(Vector2i(20, row - 1)), 120), "hammer breaks the placed block after several hits")
	var dropped := tower.get_node("Items").get_child_count()
	check(dropped >= 1, "broken block dropped as an item")
	await hold_use(Vector2i(20, row), func(): return not World.has_block_cell(Vector2i(20, row)), 120)
	# Mined drops toss toward the miner and magnet home once grabbable.
	check(await until(func(): return inv_count("wood_block") >= 2, 240), "mined drops home to the miner and are picked up (%d)" % inv_count("wood_block"))
	await goto(17)
	await hold_use(Vector2i(17, row + 1), func(): return false, 5)
	check(World.has_block_cell(Vector2i(17, row + 1)) and player.interaction.message.begins_with("Needs a better tool"),
			"metal slab shrugs off a scrap-tier hammer (GL-01 amended: metal needs steel)")

	print("== K. background walls (WS-21)")
	await goto(19)
	await ticks(20) # let the hammer's hit cooldown from the slab test expire
	await press_secondary(Vector2i(21, row - 2))
	check(not World.has_back_wall_cell(Vector2i(21, row - 2)), "hammer knocks out a back wall")
	check(craft("wood_wall") and hold_item("wood_wall"), "wood walls crafted")
	await press_secondary(Vector2i(21, row - 2))
	check(World.has_back_wall_cell(Vector2i(21, row - 2)) and inv_count("wood_wall") == 3, "wood wall placed with secondary use")

	print("== L. consumables + schematic")
	player.apply_damage(30.0)
	check(hold_item("bandage"), "bandage in hand")
	player.use_item(0)
	check(player.health == Constants.MAX_HEALTH - 5.0 and inv_count("bandage") == 1, "bandage heals 25 and is consumed")
	inv.add("schematic_iron_knife", 1)
	check(hold_item("schematic_iron_knife"), "schematic in hand")
	player.use_item(0)
	check(player.knows_recipe("iron_knife") and Data.recipes_for_station("forge", player.knows_recipe).any(func(r): return r.id == "iron_knife"), "schematic teaches the forge recipe (GL-06)")

	print("== M. chest + quick stack (LT-23)")
	inv.add("chest", 1) # test grant: the chest UI path, not part of the gate
	check(hold_item("chest"), "chest in hand")
	await goto(15)
	await press_use(Vector2i(13, row))
	var chest := obj_at(Vector2i(13, row))
	check(chest != null and chest.storage != null, "chest placed with storage")
	var opened: Array = []
	player.container_opened.connect(func(o): opened.append(o))
	await interact(Vector2i(13, row))
	check(opened.size() == 1 and opened[0] == chest, "E opens the chest")
	chest.storage.add("scrap_metal", 1)
	var metal := inv_count("scrap_metal")
	var moved: int = inv.quick_stack_into(chest.storage)
	check(moved == metal and inv_count("scrap_metal") == 0 and chest.storage.count("scrap_metal") == metal + 1, "quick-stack moved all matching metal")
	check(hold_item("hammer"), "hammer in hand")
	await press_use(Vector2i(13, row))
	check(obj_at(Vector2i(13, row)) == chest and player.interaction.message.begins_with("Empty the chest"), "hammer refuses to pick up a full chest")
	chest.storage.remove("scrap_metal", metal + 1)
	inv.add("scrap_metal", metal + 1)

	print("== N. drop + pickup, weight -> swim slowdown (WS-10/14)")
	await goto(19) # clear floor to the right (the rope hole at x=15 would swallow the throw)
	check(hold_item("wood"), "wood in hand")
	var wood := inv_count("wood")
	player.drop_held(1)
	await ticks(5)
	var items_root := tower.get_node("Items")
	check(inv_count("wood") == wood - 1 and items_root.get_child_count() >= 1, "dropped one wood as a world item")
	var drop := items_root.get_child(items_root.get_child_count() - 1)
	await ticks(75) # thrown item lands; pickup delay expires
	await goto(int(drop.global_position.x / B))
	check(await until(func(): return inv_count("wood") == wood, 120), "walked over the thrown item and picked it back up")
	var f0 := player.swim_factor()
	inv.add("stone", 200)
	check(player.swim_factor() < f0 and player.swim_factor() >= Constants.WEIGHT_SWIM_MIN_FACTOR, "heavy bag slows swimming (%.2f -> %.2f), never below the floor" % [f0, player.swim_factor()])
	inv.remove("stone", 200)

	print("== O. door")
	inv.add("wood_door", 1)
	check(hold_item("wood_door"), "door in hand")
	await goto(23)
	await press_use(Vector2i(26, row))
	check(obj_at(Vector2i(26, row - 1)) != null and World.is_solid_cell(Vector2i(26, row - 1)), "closed door is solid")
	await interact(Vector2i(26, row - 1))
	check(not World.is_solid_cell(Vector2i(26, row - 1)), "E opens the door")

	print("== P. skills summary")
	var s := player.skills
	check(s.level("scrapping") >= 2 and s.level("building") >= 0, "Scrapping %d, Building %d (xp %.0f)" % [s.level("scrapping"), s.level("building"), s.xp["building"]])
	check(s.player_level() == s.total_levels() / 5 and s.available_points() == s.player_level(), "player level = total / 5, points banked")
