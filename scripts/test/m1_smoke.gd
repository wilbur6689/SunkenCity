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
	var row := 11 # floor 1 standing row (8 px cells)
	print("== A. wake in the medical room")
	check(await until(func(): return player.state == Player.State.GROUNDED, 60), "on the floor")
	check(inv_count("bandage") == 2 and inv_count("food_can") == 1, "starting kit: 2 bandages + 1 food (LT-30)")
	var scrap_count := 0
	for o in tower.get_node("Objects").get_children():
		if o.def.kind == "scrap" and o.cell.y <= 11: # the medical room only
			scrap_count += 1
	check(scrap_count == 8, "medical room furnished with 8 scrappable objects (%d)" % scrap_count)
	check(obj_at(Vector2i(24, row)) != null and obj_at(Vector2i(24, row)).id == "chair", "chair registered on its cells")

	print("== B. hand-scrap a chair (hold-to-scrap)")
	await goto(28)
	var chair := obj_at(Vector2i(24, row))
	check(await hold_scrap(Vector2i(24, row), func(): return player.interaction.scrap_progress > 0.2, 60), "progress builds while holding scrap (RMB)")
	player.wants_use_secondary = true
	await ticks(2)
	check(player.clip == "harvest_chop", "scrapping plays the harvest chop body clip (%s)" % player.clip)
	player.wants_use_secondary = false
	var t0 := Time.get_ticks_msec()
	check(await hold_scrap(Vector2i(24, row), func(): return obj_at(Vector2i(24, row)) == null, 300), "chair scrapped and removed")
	# Resources pop OUT as bobbing world items now (2026-09-02), not straight
	# into the bag: they must be collected by walking over them.
	var popped := 0
	for it in World.items_root.get_children():
		if it is WorldItem and it.id == "wood":
			popped += it.count
	check(popped >= 3, "field yield ~half pops out as world items (wood %d)" % popped)
	await goto(24) # stand on the drop; the 1 s pickup delay then elapses
	check(await until(func(): return inv_count("wood") >= 3, 180), "walking over collects the wood (%d)" % inv_count("wood"))
	check(player.skills.xp["scrapping"] >= 3.0, "scrapping XP awarded")

	print("== C. gates: tool tier and skill")
	await goto(50)
	await hold_scrap(Vector2i(54, row), func(): return false, 10)
	check(obj_at(Vector2i(54, row)) != null and player.interaction.message.begins_with("Needs a tool"), "fridge refuses bare hands (%s)" % player.interaction.message)

	print("== D. scrap the room by hand")
	await goto(38)
	check(await hold_scrap(Vector2i(36, row), func(): return obj_at(Vector2i(36, row)) == null, 400), "desk scrapped")
	await goto(16)
	check(await hold_scrap(Vector2i(18, row), func(): return obj_at(Vector2i(18, row)) == null, 400), "cabinet scrapped")
	check(await hold_scrap(Vector2i(12, row), func(): return obj_at(Vector2i(12, row)) == null, 400), "med cart scrapped")
	await goto(10)
	check(await hold_scrap(Vector2i(6, row), func(): return obj_at(Vector2i(6, row)) == null, 400), "bed frame scrapped")
	check(player.skills.level("scrapping") >= 1, "Scrapping reached level 1 (xp %.0f)" % player.skills.xp["scrapping"])

	print("== E. the workbench gate (2026-09-01 economy): no scrap tools by hand")
	# Scrapping pops drops OUT for the player to collect now (2026-09-02); the
	# room's yield is no longer in the bag, so set the gate state directly -
	# enough for the hand wood axe (8 wood + 1 scrap) but not the workbench-only
	# scrap knife (10 scrap + 5 cloth).
	inv.add("wood", 60)
	inv.add("scrap_metal", 9)
	check(not player.can_craft(Data.recipes.scrap_knife), "scrap tools refuse hand crafting (workbench-gated)")
	check(player.can_craft(Data.recipes.wood_axe), "the wooden axe stays hand-craftable (wood tier)")
	# Stock the rest for the workbench + tool crafts below.
	inv.add("scrap_metal", 80)
	inv.add("cloth", 15)
	inv.add("plastic", 8)
	player.inventory.add("part_drafting_table", 1) # the found part (docs/CraftingStages.md, 2026-09-06)
	check(craft("workbench"), "workbench crafted by hand")
	await goto(26)
	check(hold_item("workbench"), "workbench in hand")
	await press_use(Vector2i(20, row))
	var wb := obj_at(Vector2i(20, row))
	check(wb != null and wb.id == "workbench" and inv_count("workbench") == 0, "workbench placed at (20,11)")
	check(World.stations_near(player.global_position, Constants.REACH_BLOCKS * B * 1.5).has("workbench"), "workbench in crafting range")
	check(player.can_craft(Data.recipes.scrap_knife), "the bench unlocks the scrap knife")
	check(craft("scrap_knife") and inv_count("scrap_knife") == 1, "scrap knife crafted")
	check(hold_item("scrap_knife"), "knife in hand")
	await goto(50)
	var metal0 := inv_count("scrap_metal")
	var plastic0 := inv_count("plastic")
	check(await hold_scrap(Vector2i(48, row), func(): return obj_at(Vector2i(48, row)) == null, 300), "locker scrapped with knife")
	check(await hold_scrap(Vector2i(54, row), func(): return obj_at(Vector2i(54, row)) == null, 400), "fridge scrapped (tool + skill gate passed)")
	# Their metal + plastic pop OUT and the gentle magnet draws them in.
	check(await until(func(): return inv_count("scrap_metal") > metal0 and inv_count("plastic") > plastic0, 240),
			"locker+fridge yield metal + plastic, drawn in (%d/%d -> %d/%d)" % [metal0, plastic0, inv_count("scrap_metal"), inv_count("plastic")])

	print("== F. three starter tools at the bench (GL-03, costs run 5x)")
	await goto(26)
	check(craft("hammer") and craft("pry_bar"), "hammer + pry bar crafted at the bench")
	check(inv_count("scrap_knife") == 1 and inv_count("hammer") == 1 and inv_count("pry_bar") == 1, "all three tools in the bag")

	print("== G. station crafting + full-yield scrapping")
	var wood_before := inv_count("wood")
	await goto(42)
	# Long LMB press picks furniture up whole - with the HAMMER only (2026-09-06;
	# a bare/knife hold no longer lifts anything, so LMB stays free to fight).
	check(hold_item("scrap_knife"), "knife in hand")
	aim(Vector2i(44, row))
	player.wants_use = true
	await ticks(40)
	player.wants_use = false
	await ticks(2)
	check(inv_count("chair") == 0 and obj_at(Vector2i(44, row)) != null, "a long press without the hammer leaves the chair where it is")
	check(hold_item("hammer"), "hammer in hand")
	aim(Vector2i(44, row))
	player.wants_use = true
	await ticks(40)
	player.wants_use = false
	await ticks(2)
	check(inv_count("chair") == 1 and obj_at(Vector2i(44, row)) == null, "the hammer's long press picked up the second chair whole")
	await goto(26)
	check(player.scrap_item("chair", 1) and inv_count("wood") >= wood_before + 5, "station scrap = full yield (wood %d -> %d)" % [wood_before, inv_count("wood")])
	var stations := World.stations_near(player.global_position, Constants.REACH_BLOCKS * B * 1.5)
	var bed_recipe: Dictionary = Data.recipes.bed
	check(stations.has(bed_recipe.station), "bed recipe unlocked by the workbench")

	print("== H. bed -> spawn point")
	check(craft("bed") and hold_item("bed"), "bed crafted")
	await goto(10)
	await press_use(Vector2i(4, row))
	var bed := obj_at(Vector2i(4, row))
	check(bed != null and bed.id == "bed", "bed placed at (2,5)")
	await interact(Vector2i(6, row))
	check(absf(World.spawn_position.x - bed.bottom_center().x) < 0.5, "bed set the spawn point (GL-23)")
	player.apply_damage(999.0)
	await ticks(5)
	check(player.dying, "death plays a 3 s scene before the respawn (2026-09-01)")
	# M4 death loop (CC-07): the bag moved into a backpack the moment of
	# death - checked DURING the scene, because respawning at the bed (the
	# death spot here) walks straight over the pack.
	check(not get_tree().get_nodes_in_group("backpacks").is_empty() and inv.is_empty(), "death dropped the bag as a backpack (CC-07)")
	check(await until(func(): return not player.dying and player.health == Constants.MAX_HEALTH, 260), "the scene ends in a respawn")
	await ticks(10)
	check(absf(player.global_position.x - bed.bottom_center().x) < 0.5 and player.health == Constants.MAX_HEALTH, "died and respawned at the bed")
	await goto(10)
	check(await until(func(): return get_tree().get_nodes_in_group("backpacks").is_empty(), 240), "backpack recovered on touch")

	print("== I. light the base")
	check(craft("standing_lamp") and hold_item("standing_lamp"), "lamp crafted")
	await goto(12)
	await press_use(Vector2i(14, row))
	var lamp := obj_at(Vector2i(14, row))
	check(lamp != null and lamp.id == "standing_lamp", "lamp placed")
	var has_light := false
	if lamp != null:
		for c in lamp.get_children():
			if c is PointLight2D:
				has_light = true
	check(has_light, "lamp emits light")

	print("== J. blocks: place, HP + tool-gated break, structure unbreakable")
	check(craft("wood_block") and hold_item("wood_block"), "wood blocks crafted")
	await goto(34)
	await press_use(Vector2i(40, row))
	await press_use(Vector2i(40, row - 1))
	check(World.has_block_cell(Vector2i(40, row)) and World.is_player_block(Vector2i(40, row - 1)), "two blocks placed (adjacency ok)")
	check(not World.can_place_block("wood_block", Vector2i(90, 5), player), "no floating placement without a neighbour (outside the tower)")
	check(hold_item("hammer"), "hammer in hand")
	check(await hold_use(Vector2i(40, row - 1), func(): return not World.has_block_cell(Vector2i(40, row - 1)), 120), "hammer breaks the placed block after several hits")
	var dropped := tower.get_node("Items").get_child_count()
	check(dropped >= 1, "broken block dropped as an item")
	await hold_use(Vector2i(40, row), func(): return not World.has_block_cell(Vector2i(40, row)), 120)
	# Mined drops toss toward the miner and magnet home once grabbable.
	check(await until(func(): return inv_count("wood_block") >= 2, 240), "mined drops home to the miner and are picked up (%d)" % inv_count("wood_block"))
	await goto(34)
	await hold_use(Vector2i(34, row + 1), func(): return false, 5)
	check(World.has_block_cell(Vector2i(34, row + 1)) and World.structure_damage.has(Vector2i(34, row + 1))
			and not player.interaction.message.begins_with("Needs a better tool"),
			"the plain hammer dents a metal slab too (GL-01 re-amended 2026-09-06: one tier for all structure)")
	World.structure_damage.erase(Vector2i(34, row + 1)) # leave the floor whole for the rest of the run

	print("== J2. ladders build two cells wide (user request 2026-09-05)")
	var lc := Vector2i(40, row)
	check(World.can_place_block("ladder", lc, player) and World.place_block("ladder", lc), "a ladder places on the floor")
	check(World.is_ladder_cell(lc) and World.is_ladder_cell(lc + Vector2i.RIGHT) and World.placed_blocks.has(World._key(lc + Vector2i.RIGHT, "climb")),
			"...as a 2-cell pair, both halves player-owned")
	check(not World.can_place_block("ladder", lc + Vector2i.LEFT, player), "the pair blocks a second ladder overlapping its left half")
	check(str(World.ladder_pair(lc + Vector2i.RIGHT)) == str([lc, lc + Vector2i.RIGHT]), "either half resolves to the same pair")
	check(World.pickup_climbable(lc + Vector2i.RIGHT) == "ladder" and not World.is_ladder_cell(lc) and not World.is_ladder_cell(lc + Vector2i.RIGHT),
			"picking up one half lifts the whole ladder as one item")

	print("== J3. an axe chops placed wood only (user request 2026-09-06)")
	inv.add("wood_axe", 1)
	var wb_before := inv_count("wood_block")
	check(hold_item("wood_block"), "wood block in hand")
	await press_use(Vector2i(40, row))
	check(World.placed_block_id(Vector2i(40, row)) == "wood_block", "a wood block placed for the axe")
	check(hold_item("wood_axe"), "wooden axe in hand")
	check(await hold_use(Vector2i(40, row), func(): return not World.has_block_cell(Vector2i(40, row)), 120), "the axe chops the placed wood block down")
	check(await until(func(): return inv_count("wood_block") >= wb_before, 240), "...and the drop homes back to the bag")
	check(World.place_block("scrap_block", Vector2i(40, row)), "a scrap metal block placed")
	await hold_use(Vector2i(40, row), func(): return false, 12)
	check(World.placed_block_id(Vector2i(40, row)) == "scrap_block" and World.placed_blocks[Vector2i(40, row)].hp == float(Data.blocks["scrap_block"].hp)
			and player.interaction.message.begins_with("An axe only cuts"), "the axe leaves a placed metal block untouched")
	World.remove_block(Vector2i(40, row)) # tidy up: the cell is reused below
	await hold_use(Vector2i(34, row + 1), func(): return false, 12)
	check(World.has_block_cell(Vector2i(34, row + 1)) and not World.structure_damage.has(Vector2i(34, row + 1)), "the axe cannot dent a structure slab")
	# RMB with the axe takes a PLACED wood back wall down (the tower's own
	# back walls still want the hammer). Test grant, removed again below so
	# K's exact wood-wall count holds.
	await goto(38)
	var wc := Vector2i(42, row - 3)
	World.erase_back_wall(wc) # the tower's structure wall; a placed one goes here
	inv.add("wood_wall", 1)
	check(hold_item("wood_wall"), "a wood wall in hand")
	await press_secondary(wc)
	check(World.placed_block_id(wc, "back") == "wood_wall", "a wood back wall placed")
	check(hold_item("wood_axe"), "wooden axe back in hand")
	await ticks(20) # let the hit cooldown expire so the RMB press lands
	await press_secondary(wc)
	check(not World.has_back_wall_cell(wc) and inv_count("wood_wall") == 1, "the axe takes a placed wood wall back down")
	inv.remove("wood_wall", 1)

	print("== J4. bare hands lift a placed wood block (user request 2026-09-07)")
	check(hold_item("wood_block"), "wood block in hand")
	await press_use(Vector2i(40, row))
	check(World.placed_block_id(Vector2i(40, row)) == "wood_block", "a wood block placed")
	check(player._action_clip == "place", "placing plays the place clip (%s)" % player._action_clip)
	player.bare_hands = true
	aim(Vector2i(40, row))
	player.wants_use = true
	await ticks(2)
	check(player._action_clip == "pick_up" and player.clip == "pick_up", "the long press starts the pick-up clip (%s)" % player.clip)
	player.wants_use = false
	await ticks(2)
	var wb_hand := inv_count("wood_block")
	check(await hold_use(Vector2i(40, row), func(): return not World.has_block_cell(Vector2i(40, row)), 60), "a long bare-hand press lifts it out")
	check(inv_count("wood_block") == wb_hand + 1, "...straight into the bag")
	player.bare_hands = false

	print("== J5. a hand-made torch lights the way (user request 2026-09-07)")
	inv.add("wood", 2)
	inv.add("cloth", 1)
	check(craft("torch") and inv_count("torch") == 2, "two torches from 2 wood + 1 cloth by hand")
	check(hold_item("torch"), "torch in hand")
	var torch_lvl := 0
	for src in World._gather_light_sources(true):
		torch_lvl = maxi(torch_lvl, int(src.level))
	check(torch_lvl == Constants.TORCH_LIGHT, "the held torch seeds TORCH_LIGHT (%d)" % torch_lvl)
	await ticks(1)
	check(World.light_beacons().has(player.global_position), "...and the body is a fog beacon")
	player.submerged = true
	check(World.held_light_level(player) == 0, "a submerged torch is out")
	player.submerged = false
	# Planting (user request 2026-09-07): on a floor, then on a back wall with no floor, then back.
	var floor_cell := Vector2i(41, row)
	await press_use(floor_cell)
	var planted := obj_at(floor_cell)
	check(planted != null and planted.id == "torch_placed" and inv_count("torch") == 1, "LMB plants the torch on the floor (%s)" % (planted.id if planted else "nothing"))
	check(World.light_beacons().has(World.cell_center(floor_cell)) or World.placed_light_records.size() > 0, "the planted torch is a light source")
	var wall_cell := Vector2i(41, row - 4) # mid-air on the room's back wall
	check(World.has_back_wall_cell(wall_cell) and not World.has_block_cell(wall_cell + Vector2i(0, 1)), "the wall cell has a back wall and no floor")
	await press_use(wall_cell)
	check(obj_at(wall_cell) != null and inv_count("torch") == 0, "...and on a wall with nothing under it")
	check(hold_item("hammer"), "hammer in hand")
	check(await hold_use(floor_cell, func(): return obj_at(floor_cell) == null, 60), "the hammer lifts the floor torch")
	check(inv_count("torch") == 1, "...back into the bag as a torch")
	await hold_use(wall_cell, func(): return obj_at(wall_cell) == null, 60)
	inv.remove("torch", inv_count("torch"))

	print("== J6. Shift-click CRAFT makes five batches (user request 2026-09-07)")
	inv.remove("cloth", inv_count("cloth")) # exactly three batches' worth of cloth
	inv.add("wood", 6)
	inv.add("cloth", 3)
	var torches0 := inv_count("torch")
	var cui = tower.get_node("InventoryUI")
	cui.open_panel()
	cui.show_screen("crafting")
	cui.selected_recipe = Data.recipes["torch"]
	var made: int = cui._craft_n(5)
	check(made == 3 and inv_count("torch") == torches0 + 6, "five presses stop when the cloth runs out: 3 batches, 6 torches (made %d, torches %d -> %d)" % [made, torches0, inv_count("torch")])
	cui.close()
	inv.remove("torch", inv_count("torch"))

	print("== K. background walls (WS-21)")
	await goto(38)
	check(hold_item("hammer"), "hammer back in hand (J3 left the axe there)")
	await ticks(20) # let the hammer's hit cooldown from the slab test expire
	await press_secondary(Vector2i(42, row - 2))
	check(not World.has_back_wall_cell(Vector2i(42, row - 2)), "hammer knocks out a back wall")
	check(craft("wood_wall") and hold_item("wood_wall"), "wood walls crafted")
	await press_secondary(Vector2i(42, row - 2))
	check(World.has_back_wall_cell(Vector2i(42, row - 2)) and inv_count("wood_wall") == 3, "wood wall placed with secondary use")

	print("== L. consumables + schematic")
	player.apply_damage(30.0)
	check(hold_item("bandage"), "bandage in hand")
	player.use_item(0)
	check(player.health == Constants.MAX_HEALTH - 5.0 and inv_count("bandage") == 1, "bandage heals 25 and is consumed")
	inv.add("schematic_iron_knife", 1)
	check(hold_item("schematic_iron_knife"), "schematic in hand")
	player.use_item(0)
	check(player.knows_recipe("iron_knife") and Data.recipes_for_station(Data.recipes["iron_knife"].station, player.knows_recipe).any(func(r): return r.id == "iron_knife"), "schematic teaches the iron knife at its bench (GL-06; the Machine Shop since 2026-09-06)")

	print("== M. chest + quick stack (LT-23)")
	inv.add("chest", 1) # test grant: the chest UI path, not part of the gate
	check(hold_item("chest"), "chest in hand")
	await goto(30)
	await press_use(Vector2i(26, row))
	var chest := obj_at(Vector2i(26, row))
	check(chest != null and chest.storage != null, "chest placed with storage")
	var opened: Array = []
	player.container_opened.connect(func(o): opened.append(o))
	await interact(Vector2i(26, row))
	check(opened.size() == 1 and opened[0] == chest, "E opens the chest")
	chest.storage.add("scrap_metal", 1)
	var metal := inv_count("scrap_metal")
	var moved: int = inv.quick_stack_into(chest.storage)
	check(moved == metal and inv_count("scrap_metal") == 0 and chest.storage.count("scrap_metal") == metal + 1, "quick-stack moved all matching metal")
	check(hold_item("hammer"), "hammer in hand")
	await press_use(Vector2i(26, row))
	check(obj_at(Vector2i(26, row)) == chest and player.interaction.message.begins_with("Empty the chest"), "hammer refuses to pick up a full chest")
	chest.storage.remove("scrap_metal", metal + 1)
	inv.add("scrap_metal", metal + 1)

	print("== N. drop + pickup, weight -> swim slowdown (WS-10/14)")
	await goto(38) # clear floor to the right (the rope hole at x=15 would swallow the throw)
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
	# Normalise the bag first: stocking + collected harvest drops (2026-09-02)
	# left it heavy enough to already sit at the swim floor, so measure from a
	# light bag and then pile on stone to prove weight slows swimming.
	for mid: String in ["wood", "scrap_metal", "plastic", "cloth", "stone", "iron"]:
		inv.remove(mid, 999)
	var f0 := player.swim_factor()
	inv.add("stone", 200)
	check(player.swim_factor() < f0 and player.swim_factor() >= Constants.WEIGHT_SWIM_MIN_FACTOR, "heavy bag slows swimming (%.2f -> %.2f), never below the floor" % [f0, player.swim_factor()])
	inv.remove("stone", 200)

	print("== O. door")
	inv.add("wood_door", 1)
	check(hold_item("wood_door"), "door in hand")
	await goto(46)
	await press_use(Vector2i(52, row))
	check(obj_at(Vector2i(52, row - 1)) != null and World.is_solid_cell(Vector2i(52, row - 1)), "closed door is solid")
	await interact(Vector2i(52, row - 1))
	check(not World.is_solid_cell(Vector2i(52, row - 1)), "E opens the door")

	print("== P. skills summary")
	var s := player.skills
	check(s.level("scrapping") >= 2 and s.level("building") >= 0, "Scrapping %d, Building %d (xp %.0f)" % [s.level("scrapping"), s.level("building"), s.xp["building"]])
	check(s.player_level() == s.total_levels() / 5 and s.available_points() == s.player_level(), "player level = total / 5, points banked")

	print("== Q. UI gestures through PlayerActions (LAN Step 7: reference cursor, slot-index actions)")
	var ui = tower.get_node("InventoryUI")
	var actions: PlayerActions = player.get_node("Actions")
	check(actions != null, "every Player carries an Actions child")
	ui.player = player
	ui.open_panel()
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	lmb.pressed = true
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	rmb.pressed = true
	var shift_lmb := InputEventMouseButton.new()
	shift_lmb.button_index = MOUSE_BUTTON_LEFT
	shift_lmb.pressed = true
	shift_lmb.shift_pressed = true
	var worn_suit = player.equipment.get("suit")
	player.set_equipment("suit", null)
	inv.slots.fill(null)
	inv.set_slot(0, {"id": "wood", "count": 10})
	inv.set_slot(1, {"id": "scrap_metal", "count": 3})
	inv.set_slot(2, {"id": "wood", "count": 5})
	ui._on_slot_input(lmb, "inv", 0)
	check(not ui.cursor.is_empty() and inv.slots[0] != null, "lifting a stack is a reference - the slot keeps it")
	ui._on_slot_input(lmb, "inv", 5)
	check(inv.slots[5] != null and inv.slots[5].id == "wood" and inv.slots[5].count == 10 and inv.slots[0] == null and ui.cursor.is_empty(), "put down on an empty slot = move_slot")
	ui._on_slot_input(lmb, "inv", 5)
	ui._on_slot_input(lmb, "inv", 1)
	var swapped = ui._cursor_stack()
	check(inv.slots[1].id == "wood" and inv.slots[5].id == "scrap_metal" and swapped != null and swapped.id == "scrap_metal", "swap: the cursor now holds the swapped-out item")
	ui._on_slot_input(lmb, "inv", 5)
	check(ui.cursor.is_empty() and inv.slots[5].id == "scrap_metal", "clicking its own slot sets it back down")
	ui._on_slot_input(lmb, "inv", 2)
	ui._on_slot_input(lmb, "inv", 1)
	check(inv.slots[1].count == 15 and inv.slots[2] == null and ui.cursor.is_empty(), "merge onto the same item")
	ui._on_slot_input(rmb, "inv", 1)
	var half = ui._cursor_stack()
	check(half != null and half.count == 8 and inv.slots[1].count == 15, "RMB lifts half (8 of 15) without moving anything")
	ui._on_slot_input(rmb, "inv", 3)
	check(inv.slots[3] != null and inv.slots[3].count == 1 and inv.slots[1].count == 14 and ui._cursor_stack().count == 7, "RMB places one (split_slot)")
	ui._on_slot_input(lmb, "inv", 4)
	check(inv.slots[4].count == 7 and inv.slots[1].count == 7 and ui.cursor.is_empty(), "LMB puts the remainder down")
	inv.set_slot(6, {"id": "clothes", "count": 1})
	ui._on_slot_input(lmb, "inv", 6)
	ui._on_slot_input(lmb, "equip:suit", 0)
	check(player.equipped("suit") == "clothes" and inv.slots[6] == null and ui.cursor.is_empty(), "equip from the lifted stack (equip action)")
	ui._on_slot_input(lmb, "equip:suit", 0)
	check(ui.cursor.get("which", "") == "equip" and player.equipped("suit") == "clothes", "lifting a worn piece is a reference too")
	ui._on_slot_input(lmb, "inv", 7)
	check(inv.slots[7] != null and inv.slots[7].id == "clothes" and player.equipped("suit") == "" and ui.cursor.is_empty(), "put down in the bag = unequip")
	ui._on_slot_input(lmb, "inv", 7)
	ui._on_slot_input(lmb, "equip:suit", 0)
	check(player.equipped("suit") == "clothes" and inv.slots[7] == null, "and worn again")
	await goto(30)
	ui.open_container(chest)
	ui._on_slot_input(shift_lmb, "inv", 1)
	check(chest.storage.count("wood") == 7 and inv.slots[1] == null, "shift-click moves into the chest (container_move)")
	var ci := -1
	for i in chest.storage.size():
		if chest.storage.slots[i] != null and chest.storage.slots[i].id == "wood":
			ci = i
			break
	ui._on_slot_input(lmb, "chest", ci)
	ui._on_slot_input(lmb, "inv", 1)
	check(inv.slots[1] != null and inv.slots[1].count == 7 and chest.storage.count("wood") == 0 and ui.cursor.is_empty(), "chest -> bag through the cursor")
	chest.storage.add("scrap_metal", 1)
	ui._quick_stack()
	check(chest.storage.count("scrap_metal") == 4 and inv_count("scrap_metal") == 0, "Stack button = quick_stack action")
	chest.storage.add("wood", 3)
	chest.storage.add_stack({"id": "scrap_knife", "count": 1, "mods": {"prefix": {"id": "rusty"}}})
	var take_wood := inv_count("wood")
	ui._take_all()
	var knife_moved := false
	for st in inv.slots:
		if st != null and st.id == "scrap_knife" and st.has("mods"):
			knife_moved = true
	check(chest.storage.is_empty() and inv_count("scrap_metal") == 4 and inv_count("wood") == take_wood + 3 and knife_moved,
		"Take button empties the unit into the bag (take_all action; modded gear keeps its mods)")
	var r_id := ""
	for r in Data.recipe_list:
		if r.station == "hand" and r.inputs.size() == 1 and r.inputs[0].item == "wood" and (r.get("known", false) or player.knows_recipe(r.id)):
			r_id = r.id
			break
	inv.add("wood", 60)
	var out_id: String = Data.recipes[r_id].output.item if r_id != "" else ""
	var out_before := inv_count(out_id)
	check(r_id != "" and actions.act("craft", [r_id]) and inv_count(out_id) > out_before, "craft action by recipe id (%s)" % r_id)
	check(not actions.act("craft", ["no_such_recipe"]), "unknown recipe refused")
	check(not actions.act("move_slot", [0, 99]), "out-of-range slot refused")
	ui.close()
	check(ui.cursor.is_empty() and ui.bench.is_empty() and not player.equipment.suit == null, "closing clears the references - nothing to hand back")
	player.set_equipment("suit", worn_suit)
