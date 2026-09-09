extends Node
## Headless M5 gate test — The Long Game: gear ladder effects (GL-09/10/13),
## suit band gates, locked doors + safes (LT-14), generated container loot
## (LT-12/13/27), schematic learning, and the recipe chain to the deep.
## Run: godot --path . --headless res://scenes/test/m5_smoke.tscn

const B := Constants.BLOCK_SIZE

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

## Iron cost of crafting one `item`, expanding intermediate recipes (steel).
func _iron_cost(item: String, depth: int = 0) -> int:
	if item == "iron":
		return 1
	if depth > 4 or not Data.recipes.has(item):
		return 0
	var total := 0
	for inp in Data.recipes[item].inputs:
		total += _iron_cost(String(inp.item), depth + 1) * int(inp.count)
	return total

## Iron the full gear chain consumes (GL-27 ladder top: tools, tank, suits).
func _chain_iron_need() -> int:
	var total := 0
	for id in ["bolt_cutters", "cutting_torch", "tank_iron", "hard_suit", "rebreather"]:
		total += _iron_cost(id)
	return total

func _world_item_count(id: String) -> int:
	var n := 0
	for it in World.items_root.get_children():
		if it is WorldItem and it.id == id:
			n += it.count
	return n

func _ready() -> void:
	# Isolation: never inherit a real character save from this machine (the
	# default character name may exist and carry gear that skews checks).
	SaveGame.pending_character = "__m5_smoke__"
	var city: Node2D = load("res://scenes/city/city.tscn").instantiate()
	add_child(city)
	var player: Player = city.player
	player.set_multiplayer_authority(2)
	check(await until(func(): return player.state == Player.State.GROUNDED, 120), "player lands")
	var sc := World.cell_at(World.spawn_position)

	print("== A. gear stats stack (GL-13)")
	check(player.max_oxygen() == Constants.BASE_OXYGEN_SECONDS, "base air is %d s" % int(Constants.BASE_OXYGEN_SECONDS))
	player.set_equipment("accessory1", {"id": "tank_iron", "count": 1})
	check(player.max_oxygen() == Constants.BASE_OXYGEN_SECONDS + 60.0, "iron tank +60s")
	player.set_equipment("accessory2", {"id": "rebreather", "count": 1})
	check(player.max_oxygen() == Constants.BASE_OXYGEN_SECONDS + 210.0, "rebreather stacks: +150s more")
	player.set_equipment("head", {"id": "helmet_lamp", "count": 1})
	check(int(player.equip_stat("light")) >= 9, "helmet lamp carries light")
	var base_swim := player.swim_factor()
	player.set_equipment("accessory1", {"id": "fins", "count": 1})
	check(player.swim_factor() > base_swim, "fins speed up the swim")
	player.set_equipment("accessory1", {"id": "compass", "count": 1})
	check(player.reveal_radius() > Constants.MAP_REVEAL_RADIUS, "compass widens map reveal")
	player.set_equipment("accessory1", {"id": "tool_belt", "count": 1})
	check(player.scrap_speed_mult() > Constants.SCRAP_SPEED_MULT, "tool belt scraps faster")
	player.set_equipment("accessory1", null)
	player.set_equipment("accessory2", null)

	print("== A2. the weapon slot: worn weapon fights from an empty hand, its mods count as gear")
	check(player.can_equip("weapon", "speargun") and player.can_equip("weapon", "fire_axe"), "weapons and tool-weapons fit the weapon slot")
	check(not player.can_equip("weapon", "wetsuit") and not player.can_equip("suit", "speargun"), "a suit refuses the weapon slot and vice versa")
	player.inventory.slots.fill(null)
	player.selected_slot = 0
	player.bare_hands = false
	var worn := {"id": "speargun", "count": 1, "mods": {"suffix": {"id": "com_3"}}}
	player.set_equipment("weapon", worn)
	check(player.held_item() == "speargun" and player.holding_worn_weapon(), "an empty hotbar hand holds the worn weapon")
	check(player.max_oxygen() == Constants.BASE_OXYGEN_SECONDS + 18.0, "its Commercial suffix (of the Showroom III) adds +18s air as worn gear")
	player.inventory.set_slot(0, {"id": "hammer", "count": 1})
	check(player.held_item() == "hammer" and not player.holding_worn_weapon(), "a hotbar item in hand takes precedence")
	player.bare_hands = true
	check(player.held_item() == "speargun", "Q (bare hands) brings the worn weapon back")
	var drops_before := World.items_root.get_child_count()
	player.drop_held(1)
	check(World.items_root.get_child_count() == drops_before and player.equipment.weapon != null, "dropping never sheds the worn weapon")
	player.bare_hands = false
	player.inventory.set_slot(0, {"id": "hammer", "count": 1})
	player.selected_slot = Constants.WEAPON_HOTBAR
	check(player.held_item() == "speargun" and player.holding_worn_weapon(), "the weapon hotbar slot (key 1) selects the worn weapon over a full hand")
	check(player.inventory.remove_from_slot(Constants.WEAPON_HOTBAR, 1) == 0, "the weapon slot is never a bag slot")
	player.selected_slot = 0
	player.inventory.slots.fill(null)
	player.set_equipment("weapon", null)

	print("== B. suits lift the depth gates (GL-09/12)")
	player.global_position = Vector2(16 * B, (World.waterline_row + 120) * B)
	player.velocity = Vector2.ZERO
	await ticks(20)
	check(player.env_slow < 1.0, "The Cold slows plain clothes")
	player.set_equipment("suit", {"id": "wetsuit", "count": 1})
	await ticks(10)
	check(player.env_slow == 1.0, "a wetsuit shrugs The Cold off")
	player.set_equipment("suit", {"id": "hard_suit", "count": 1})
	player.health = Constants.MAX_HEALTH
	player.global_position = Vector2(16 * B, (World.waterline_row + 520) * B)
	await ticks(30)
	check(player.health >= Constants.MAX_HEALTH - 0.01, "a hard suit survives The Crush undamaged")
	player.set_equipment("suit", {"id": "clothes", "count": 1})
	player.respawn()
	await until(func(): return player.state == Player.State.GROUNDED, 120)

	print("== C. locked doors (GL-09 ladder)")
	var mdoor := World.place_object("metal_door", sc + Vector2i(18, -1), true)
	player.inventory.slots.fill(null)
	player.selected_slot = 0
	mdoor.interact(player)
	check(not mdoor.open, "a chained metal door refuses bare hands")
	player.inventory.set_slot(0, {"id": "bolt_cutters", "count": 1})
	mdoor.interact(player)
	check(mdoor.open and mdoor.unlocked, "bolt cutters shear it open")
	var vdoor := World.place_object("vault_door", sc + Vector2i(22, -1), true)
	vdoor.interact(player)
	check(not vdoor.open, "a vault door refuses bolt cutters")
	player.inventory.add("vault_key", 1)
	vdoor.interact(player)
	check(vdoor.open and player.inventory.count("vault_key") == 0, "a vault key opens it (and is spent)")

	print("== D. generated loot (LT-12/13/14/27)")
	var total := 0
	var filled := 0
	var safes := 0
	var deep_gear := false
	const GEAR := ["tank_scrap", "tank_iron", "vault_key", "fins", "glow_band", "compass",
		"tool_belt", "weight_belt", "dive_watch", "schematic_hard_suit", "schematic_rebreather", "wetsuit", "rebreather", "bolt_cutters"]
	for rec: Dictionary in World.object_records:
		if rec.placed or rec.storage == null:
			continue
		total += 1
		if not rec.storage.is_empty():
			filled += 1
		if rec.def.get("kind", "") == "safe":
			safes += 1
		if rec.cell.y - World.waterline_row > Constants.BAND_COLD_DEPTH:
			for s in rec.storage.slots:
				if s != null and GEAR.has(String(s.id)):
					deep_gear = true
	check(total >= 50, "%d generated containers in the city" % total)
	check(filled >= total * 9 / 10, "%d/%d containers rolled loot" % [filled, total])
	check(safes >= 3, "%d wall safes hidden in the rooms (LT-14)" % safes)
	check(deep_gear, "deep containers hold gear/schematics/keys")

	print("== E. schematics gate the top recipes")
	var dive_before := Data.recipes_for_station("dive_station", player.knows_recipe)
	check(not dive_before.any(func(r): return r.id == "hard_suit"), "hard suit starts unknown")
	player.inventory.set_slot(3, {"id": "schematic_hard_suit", "count": 1})
	player.use_item(3)
	var dive_after := Data.recipes_for_station("dive_station", player.knows_recipe)
	check(dive_after.any(func(r): return r.id == "hard_suit"), "its schematic teaches it")

	print("== F. the crafting chain to the deep (GATE: knife to hard suit)")
	for obj_id in ["med_cart", "cabinet", "locker", "chair"]: # clear bench space
		for rec: Dictionary in World.object_records.duplicate():
			if rec.id == obj_id and rec.node != null and absi(rec.cell.x - sc.x) < 24:
				World.remove_object(rec.node)
	World.place_object("workbench", sc + Vector2i(4, -1), true)
	World.place_object("forge", sc + Vector2i(12, -1), true)
	World.place_object("dive_station", sc + Vector2i(26, -1), true)
	player.inventory.slots.fill(null)
	# Stocked for the 5x tool economy (2026-09-01): the torch alone eats
	# 10 steel, the cutters 15 iron.
	player.inventory.add("iron", 60)
	player.inventory.add("stone", 20)
	player.inventory.add("scrap_metal", 30)
	player.inventory.add("plastic", 25)
	player.inventory.add("cloth", 20)
	player.inventory.add("wood", 16)
	for i in 16:
		player.craft(Data.recipes["steel"])
	check(player.inventory.count("steel") >= 6, "forge turns iron into steel (%d)" % player.inventory.count("steel"))
	check(player.craft(Data.recipes["bolt_cutters"]), "bolt cutters forged")
	check(player.craft(Data.recipes["cutting_torch"]), "cutting torch forged from steel")
	check(player.craft(Data.recipes["wetsuit"]), "wetsuit sewn at the dive station")
	check(player.craft(Data.recipes["tank_iron"]), "iron tank built")
	check(player.craft(Data.recipes["hard_suit"]), "hard suit built after learning it")
	check(player.inventory.count("hard_suit") == 1, "the ladder tops out: knife to hard suit through play")

	print("== G. modifiers v2: the district x band grid (Modifiers.md)")
	check(Data.modifier_families.size() == 6 and Data.modifier_hybrids.size() == 30, "6 families x 5 tiers + 30 hybrids loaded (%d hybrids)" % Data.modifier_hybrids.size())
	var knife := {"id": "iron_knife", "count": 1, "mods": {"prefix": {"id": "ind_3"}, "suffix": {"id": "civ_3"}}}
	check(ItemMods.display_name(knife) == "Forged Iron Knife of the Ward", "prefix+suffix title: '%s'" % ItemMods.display_name(knife))
	check(ItemMods.rarity(knife) == "rare", "tier 3 on the piece = rare (blue)")
	check(ItemMods.rarity({"id": "iron_knife", "count": 1, "mods": {"prefix": {"id": "ind_1"}}}) == "uncommon", "tier 1 = uncommon (green)")
	check(ItemMods.rarity({"id": "iron_knife", "count": 1, "mods": {"prefix": {"id": "ind_5"}}}) == "epic", "a single tier 5 = epic (purple)")
	check(ItemMods.rarity({"id": "iron_knife", "count": 1, "mods": {"prefix": {"id": "ind_5"}, "suffix": {"id": "civ_5"}}}) == "legendary", "both slots at tier 5 = legendary (gold, D2)")
	check(ItemMods.rarity({"id": "iron_knife", "count": 1}) == "common", "clean gear is common (gray)")
	player.inventory.slots.fill(null)
	player.inventory.set_slot(0, knife)
	player.selected_slot = 0
	player.bare_hands = false
	var base_dmg := float(Data.tool_of("iron_knife").damage)
	check(player.held_tool().damage == base_dmg + 3.0, "Forged III adds +3 damage to the held tool (tier-authored, no power)")
	check(ItemMods.stat(knife, "cold") == 1.0 and ItemMods.stat(knife, "defense") == 3.0, "of the Ward III carries cold 1 + defense 3")
	var res_knife := {"id": "iron_knife", "count": 1, "mods": {"suffix": {"id": "res_2"}}}
	check(ItemMods.unit_weight(res_knife) < Data.weight("iron_knife"), "a Residential suffix lightens the item")
	var suit := {"id": "wetsuit", "count": 1, "mods": {"suffix": {"id": "com_5"}}}
	player.set_equipment("suit", suit)
	check(player.max_oxygen() == Constants.BASE_OXYGEN_SECONDS + 30.0, "of the Vault V grants +30s air from the suit")
	var ward := {"id": "wetsuit", "count": 1, "mods": {"suffix": {"id": "civ_5"}}}
	player.set_equipment("suit", ward)
	check(player.suit_stat("cold") == 3.0, "of the Morgue V lifts a wetsuit's cold rating by 2")
	player.set_equipment("suit", {"id": "clothes", "count": 1})
	check(not player.apply_mods({"id": "wetsuit", "count": 1}, "ind_1", ""), "a prefix (weapon) family refuses a suit")
	# Rolled mods match their container's district (family) and band (tier).
	var modded_in_city := 0
	var wrong_cell := 0
	var powered_instances := 0
	var families_seen := {}
	var tiers_seen := {}
	for rec: Dictionary in World.object_records:
		if rec.storage == null:
			continue
		var district := LootGen.district_of(World.towers, World.pockets, rec.cell)
		var tier: int = ItemMods.TIER_OF_BAND[World.floor_band_at(rec.cell)]
		for s in rec.storage.slots:
			if s == null or not s.has("mods"):
				continue
			modded_in_city += 1
			for part in s.mods.values():
				var mid := String(part.id)
				if part.has("power"):
					powered_instances += 1
				if ItemMods.def_of(mid).get("junk", false):
					continue
				families_seen[ItemMods.family_of(mid)] = true
				tiers_seen[ItemMods.tier_of(mid)] = true
				if ItemMods.family_of(mid) != district or ItemMods.tier_of(mid) != tier:
					wrong_cell += 1
	check(modded_in_city >= 10, "found gear rolls mods at loot gen (%d modded items in city)" % modded_in_city)
	check(powered_instances == 0, "instances carry no power (%d did)" % powered_instances)
	check(wrong_cell == 0, "every rolled mod matches its container's district/band (%d off-grid)" % wrong_cell)
	check(families_seen.size() >= 4, "several families roll across the city (%s)" % str(families_seen.keys()))
	check(tiers_seen.size() >= 3, "several tiers roll across the depth (%s)" % str(tiers_seen.keys()))

	print("== H. Modification Bench backend: library stock, apply, combine")
	player.mod_library.clear()
	var donor := {"id": "scrap_knife", "count": 1, "mods": {"prefix": {"id": "ind_3"}}}
	check(not player.learnable_mods(donor).is_empty(), "a modded donor offers something to learn")
	var learned := player.learn_mods(donor)
	check(player.library_count("ind_3") == 1, "Forged stocked once (%s)" % str(learned))
	player.learn_mods(donor)
	check(player.library_count("ind_3") == 2, "a duplicate donor stocks a second (the library is a count, not an unlock)")
	var clean := {"id": "iron_knife", "count": 1}
	check(player.apply_mods(clean, "ind_3", ""), "a library mod applies to clean crafted gear")
	check(player.library_count("ind_3") == 1, "...and APPLY consumes it")
	check(not clean.mods.prefix.has("power"), "applied instance is {id} only")
	check(not player.apply_mods(clean, "ind_3", ""), "once modded the item is locked (LT-09)")
	check(not player.apply_mods({"id": "wetsuit", "count": 1}, "ind_3", ""), "a weapon prefix refuses a suit")
	var junk := {"id": "scrap_knife", "count": 1, "mods": {"prefix": {"id": "rusty"}}}
	check(player.learnable_mods(junk).is_empty(), "Rusty junk cannot be learned")
	# Vertical: two of a kind climb the ladder; the ceiling is tier 5.
	player.mod_library = {"ind_3": 2, "con_3": 1, "civ_5": 2, "res_3": 1, "res_4": 1}
	check(ItemMods.combine_result("ind_3", "ind_3") == "ind_4", "2 x Forged (T3) -> Hardened (T4)")
	check(ItemMods.combine_result("ind_3", "con_3") == "demolition_3", "Forged + Riveted -> the demolition hybrid at T3")
	check(ItemMods.combine_result("ind_3", "res_3") == "", "no cross-slot combine (prefix + suffix)")
	check(ItemMods.combine_result("res_3", "res_4") == "", "no mixed-tier combine")
	check(ItemMods.combine_result("civ_5", "civ_5") == "", "tier 5 is the ceiling")
	check(player.combine_mods("ind_3", "con_3") == "demolition_3", "COMBINE stocks the hybrid")
	check(player.library_count("ind_3") == 1 and player.library_count("con_3") == 0 and player.library_count("demolition_3") == 1, "...and consumes both inputs")
	check(player.combine_mods("ind_3", "ind_3") == "", "a vertical combine needs two in stock")
	player.mod_library["ind_3"] = 2
	check(player.combine_mods("ind_3", "ind_3") == "ind_4" and player.library_count("ind_4") == 1 and player.library_count("ind_3") == 0, "2 x Forged in stock -> one Hardened")
	var hy := {"id": "scrap_sword", "count": 1}
	check(player.apply_mods(hy, "demolition_3", "") and ItemMods.display_name(hy) == "Bulldozing Scrap Sword", "a hybrid applies like any prefix: '%s'" % ItemMods.display_name(hy))
	check(ItemMods.weapon_of(hy).damage > float(Data.item("scrap_sword").weapon.damage), "the hybrid's damage folds into the weapon block")
	# D3: old-format instances load clean.
	var legacy = ItemMods.clean_stack({"id": "iron_knife", "count": 1, "mods": {"prefix": {"id": "sharp", "power": 3}}})
	check(legacy != null and not legacy.has("mods"), "a pre-grid modded instance strips to a clean item")
	var powered = ItemMods.clean_stack({"id": "iron_knife", "count": 1, "mods": {"prefix": {"id": "ind_2", "power": 2}}})
	check(powered.mods.prefix.size() == 1 and powered.mods.prefix.id == "ind_2", "a known id keeps its mod and drops `power`")

	print("== I. ability tech tree (CC-18)")
	var sk := player.skills
	sk.xp = {"scrapping": 0.0, "swimming": 0.0, "building": 0.0}
	sk.spent_points = 0
	sk.abilities.clear()
	check(not sk.can_unlock("field_strip"), "no points, no unlock")
	sk.xp["scrapping"] = 5.0 * Constants.SKILL_XP_PER_LEVEL * Constants.SKILL_LEVELS_PER_PLAYER_LEVEL
	check(sk.available_points() == 5, "25 skill levels bank 5 ability points")
	check(not sk.can_unlock("tool_harness"), "tier 2 locked behind its tier-1 requirement")
	check(sk.unlock("field_strip"), "tier 1 unlocks with a point")
	check(sk.unlock("tool_harness"), "tier 2 opens once its requirement is owned")
	check(sk.available_points() == 3, "each unlock spends one point")
	check(sk.effect("field_yield", Constants.FIELD_SCRAP_YIELD) == 0.75, "Field Strip raises the field yield")
	check(player.can_equip("accessory3", "fins"), "Tool Harness opens the third accessory mount")
	check(not player.can_equip("accessory4", "fins"), "the fourth mount stays locked")
	var reach_before := player.reach_blocks()
	sk.unlock("long_reach")
	check(player.reach_blocks() == reach_before + 1.0, "Long Reach adds a block of reach")
	sk.unlock("strong_kick")
	check(player.equip_stat("swim") >= 0.1, "Strong Kick feeds the swim stat")

	print("== J. found-only pools (LT-18)")
	for gun in ["pistol", "smg", "rifle"]:
		check(Data.item(gun).get("found_only", false), "%s is found-only" % gun)
	for r: Dictionary in Data.recipe_list:
		check(not Data.item(r.output.item).get("found_only", false), "recipe %s does not craft found-only gear" % r.id)
	var gun_in_tables := false
	for zone in Data.loot.tables:
		for band in Data.loot.tables[zone]:
			for e in Data.loot.tables[zone][band]:
				if e.item in ["pistol", "smg", "rifle"]:
					gun_in_tables = true
	check(gun_in_tables, "firearms drop from the deep loot tables")

	print("== K. harvest gates across material tiers (GL-28)")
	for o: Dictionary in Data.objects.values():
		var mats := {}
		for y in o.get("yields", []):
			mats[y.item] = true
		if mats.has("steel"):
			check(int(o.get("skill", 0)) >= 3, "%s (steel) needs Scrapping 3+" % o.id)
		elif mats.has("iron"):
			check(int(o.get("skill", 0)) >= 2, "%s (iron) needs Scrapping 2+" % o.id)
	sk.xp["scrapping"] = 0.0
	player.inventory.slots.fill(null)
	player.inventory.add("safe", 1)
	check(not player.scrap_item("safe", 1, true), "an iron-tier object refuses Scrapping 0")
	sk.xp["scrapping"] = 2.0 * Constants.SKILL_XP_PER_LEVEL
	check(player.scrap_item("safe", 1, true), "...and yields at Scrapping 2")

	print("== K2. plain weapons do not dismantle (user request 2026-09-06)")
	var chair := World.place_object("chair", sc + Vector2i(30, -1), true)
	check(chair != null, "a chair stands on the spawn floor")
	player.inventory.slots.fill(null)
	player.bare_hands = false
	player.selected_slot = 0
	check(player.interaction.can_harvest(chair), "bare hands dismantle a tier-0 chair")
	player.inventory.set_slot(0, {"id": "scrap_sword", "count": 1})
	check(not player.interaction.can_harvest(chair), "a sword in hand cannot dismantle it")
	player.inventory.set_slot(0, {"id": "pry_bar", "count": 1})
	check(player.interaction.can_harvest(chair), "a pry bar (tool) can")
	player.inventory.set_slot(0, {"id": "fire_axe", "count": 1})
	check(player.interaction.can_harvest(chair), "a tool-weapon (fire axe) counts as a tool - as bare hands off trees")
	player.inventory.set_slot(0, null)
	player.set_equipment("weapon", {"id": "scrap_sword", "count": 1})
	check(player.interaction.can_harvest(chair), "a WORN sword with an empty hand is still bare hands")
	player.set_equipment("weapon", null)
	World.remove_object(chair)

	print("== K3. found bench parts, stage benches, floor doors (2026-09-06)")
	var part_counts := {}
	var wing_doors := 0
	for rec: Dictionary in World.object_records:
		if rec.def.get("part", false):
			part_counts[rec.id] = int(part_counts.get(rec.id, 0)) + 1
		if rec.def.kind == "door" and not rec.placed and rec.id == "wood_door":
			wing_doors += 1
	var missing := []
	for oid in Data.objects:
		if Data.objects[oid].get("part", false) and int(part_counts.get(oid, 0)) == 0:
			missing.append(oid)
	check(missing.is_empty(), "every found part spawns somewhere in the city (missing: %s) - %s" % [str(missing), str(part_counts)])
	var short := []
	for oid in Data.objects:
		if Data.objects[oid].get("part", false) and int(part_counts.get(oid, 0)) < Constants.PART_COPIES:
			short.append(oid)
	check(short.is_empty(), "every part reaches PART_COPIES (%d) copies - exhaustive band-floor search (short: %s)" % [Constants.PART_COPIES, str(short)])
	check(wing_doors >= 200, "wing doorways carry doors by band (%d wood doors)" % wing_doors)
	for bench in ["workbench", "forge", "machine_shop", "steel_works", "pressure_works", "weapon_bench", "pump_works", "dive_station", "med_station", "mod_bench"]:
		var needs_part := false
		for inp in Data.recipes[bench].inputs:
			if Data.objects.get(String(inp.item), {}).get("part", false):
				needs_part = true
		check(needs_part, "%s costs its found part" % bench)
	check(Data.recipes["sledgehammer"].station == "weapon_bench" and Data.recipes["steel"].station == "steel_works" and Data.recipes["pump"].station == "pump_works", "recipes moved to the stage benches")
	check(Data.STATIONS.has("machine_shop") and Data.STATIONS.has("pressure_works"), "the new benches are stations")

	print("== L. depletion pressure (GL-28/LT-27): the surface cannot finish the chain")
	for zone in Data.loot.tables:
		for band in ["dry", "shallows"]:
			for e in Data.loot.tables[zone].get(band, []):
				check(not e.item in ["iron", "steel"], "%s/%s table holds no iron or steel" % [zone, band])
	var chain_iron := _chain_iron_need()
	var surface_iron := 0
	var cold_row: int = World.waterline_row + Constants.BAND_SHALLOWS_DEPTH # The Cold starts here
	for rec: Dictionary in World.object_records:
		if rec.cell.y >= cold_row:
			continue
		if rec.storage != null:
			for s in rec.storage.slots:
				if s != null and s.id == "iron":
					surface_iron += s.count
		for y in rec.def.get("yields", []):
			if y.item == "iron":
				surface_iron += int(y.max)
	var _dbg := {}
	for rec: Dictionary in World.object_records:
		if rec.cell.y >= cold_row:
			continue
		for y in rec.def.get("yields", []):
			if y.item == "iron":
				_dbg[rec.id] = _dbg.get(rec.id, 0) + int(y.max)
		if rec.storage != null:
			for s in rec.storage.slots:
				if s != null and s.id == "iron":
					_dbg["storage:" + rec.id] = _dbg.get("storage:" + rec.id, 0) + s.count
	print("  breakdown: ", _dbg)
	print("  surface iron obtainable: %d · chain needs: %d" % [surface_iron, chain_iron])
	check(surface_iron < chain_iron, "iron above The Cold (%d) cannot cover the gear chain (%d) — you must dive" % [surface_iron, chain_iron])

	print("== M. structure demolition (GL-01 re-amended 2026-09-06: a plain hammer breaks any block, nothing drops)")
	var demo := sc + Vector2i(0, -20)
	while World.has_block_cell(demo): # find open air above the spawn room
		demo.y -= 1
	World.grid.set_structure(demo, WorldGrid.M.WOOD)
	check(World.damage_block(demo, 200.0, 0) == "too_hard", "bare hands cannot break structure")
	var wood_drops_before := _world_item_count("wood")
	check(World.damage_block(demo, 200.0, 1) == "broken", "a plain hammer (tier 1) breaks wood structure")
	check(_world_item_count("wood") == wood_drops_before, "demolished wood yields nothing")
	World.grid.set_structure(demo, WorldGrid.M.STONE)
	var stone_before := _world_item_count("stone")
	var rev := World.damage_rev
	check(World.damage_block(demo, 25.0, 1) == "damaged", "the same hammer chips stone away")
	check(World.structure_damage.has(demo), "partial damage tracked (crack stages + save)")
	check(World.damage_rev > rev, "damage bumps the crack-overlay revision")
	check(World.damage_block(demo, 40.0, 1) == "broken", "...and cracks through")
	check(_world_item_count("stone") == stone_before, "demolished stone yields nothing")
	World.grid.set_structure(demo, WorldGrid.M.METAL)
	var scrap_before := _world_item_count("scrap_metal")
	check(World.damage_block(demo, 25.0, 1) == "damaged", "tier 1 dents metal too (more hits, no better tool needed)")
	check(World.damage_block(demo, 50.0, 1) == "broken", "...and through")
	check(_world_item_count("scrap_metal") == scrap_before, "demolished metal yields nothing")
	check(not World.has_block_cell(demo), "the demolished cell is open air")
	World.grid.set_structure(demo, WorldGrid.M.VOID)
	check(World.damage_block(demo, 500.0, 5) == "too_hard", "VOID stays unbreakable")
	World.grid.set_structure(demo, WorldGrid.M.AIR)

	print("\nM5 smoke: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
