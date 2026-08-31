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

func _ready() -> void:
	var city: Node2D = load("res://scenes/city/city.tscn").instantiate()
	add_child(city)
	var player: Player = city.get_node("Player")
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

	print("== B. suits lift the depth gates (GL-09/12)")
	player.global_position = Vector2(8 * B, (World.waterline_row + 60) * B)
	player.velocity = Vector2.ZERO
	await ticks(20)
	check(player.env_slow < 1.0, "The Cold slows plain clothes")
	player.set_equipment("suit", {"id": "wetsuit", "count": 1})
	await ticks(10)
	check(player.env_slow == 1.0, "a wetsuit shrugs The Cold off")
	player.set_equipment("suit", {"id": "hard_suit", "count": 1})
	player.health = Constants.MAX_HEALTH
	player.global_position = Vector2(8 * B, (World.waterline_row + 260) * B)
	await ticks(30)
	check(player.health >= Constants.MAX_HEALTH - 0.01, "a hard suit survives The Crush undamaged")
	player.set_equipment("suit", {"id": "clothes", "count": 1})
	player.respawn()
	await until(func(): return player.state == Player.State.GROUNDED, 120)

	print("== C. locked doors (GL-09 ladder)")
	var mdoor := World.place_object("metal_door", sc + Vector2i(9, -1), true)
	player.inventory.slots.fill(null)
	player.selected_slot = 0
	mdoor.interact(player)
	check(not mdoor.open, "a chained metal door refuses bare hands")
	player.inventory.set_slot(0, {"id": "bolt_cutters", "count": 1})
	mdoor.interact(player)
	check(mdoor.open and mdoor.unlocked, "bolt cutters shear it open")
	var vdoor := World.place_object("vault_door", sc + Vector2i(11, -1), true)
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
			if rec.id == obj_id and rec.node != null and absi(rec.cell.x - sc.x) < 12:
				World.remove_object(rec.node)
	World.place_object("workbench", sc + Vector2i(2, -1), true)
	World.place_object("forge", sc + Vector2i(6, -1), true)
	World.place_object("dive_station", sc + Vector2i(13, -1), true)
	player.inventory.slots.fill(null)
	player.inventory.add("iron", 20)
	player.inventory.add("stone", 6)
	player.inventory.add("scrap_metal", 20)
	player.inventory.add("plastic", 20)
	player.inventory.add("cloth", 20)
	player.inventory.add("wood", 6)
	for i in 6:
		player.craft(Data.recipes["steel"])
	check(player.inventory.count("steel") >= 6, "forge turns iron into steel (%d)" % player.inventory.count("steel"))
	check(player.craft(Data.recipes["bolt_cutters"]), "bolt cutters forged")
	check(player.craft(Data.recipes["cutting_torch"]), "cutting torch forged from steel")
	check(player.craft(Data.recipes["wetsuit"]), "wetsuit sewn at the dive station")
	check(player.craft(Data.recipes["tank_iron"]), "iron tank built")
	check(player.craft(Data.recipes["hard_suit"]), "hard suit built after learning it")
	check(player.inventory.count("hard_suit") == 1, "the ladder tops out: knife to hard suit through play")

	print("\nM5 smoke: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
