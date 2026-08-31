extends Node
## Headless M3 gate test: deterministic seeds (CT-21), skyline and structure,
## connectivity flooding with sealed dry pockets (CT-12/13), depth bands and
## the cold/crush gates (GD-16, CC-16, GL-12), day/night (CC-11).
## Run: godot --path . --headless res://scenes/test/m3_smoke.tscn

const B := Constants.BLOCK_SIZE

var city: Node2D
var player: Player
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
	print("== A. determinism (CT-21)")
	var t0 := Time.get_ticks_msec()
	var r1 := CityGen.generate(101, 800)
	var gen_ms := Time.get_ticks_msec() - t0
	var r2 := CityGen.generate(101, 800)
	var r3 := CityGen.generate(202, 800)
	check(r1.grid.content_hash() == r2.grid.content_hash(), "same seed = same grid (%d ms per 800-wide gen)" % gen_ms)
	check(hash(str(r1.objects)) == hash(str(r2.objects)) and hash(str(r1.doors)) == hash(str(r2.doors)), "same seed = same objects and doors")
	check(r1.grid.content_hash() != r3.grid.content_hash(), "different seed = different city")
	check(r1.towers >= 8, "800-wide slice holds %d towers" % r1.towers)

	print("== B. the full city")
	city = load("res://scenes/city/city.tscn").instantiate()
	add_child(city)
	player = city.get_node("Player")
	player.set_multiplayer_authority(2)
	await get_tree().physics_frame
	var gen: Dictionary = city.gen
	check(gen.towers >= 25, "city holds %d towers" % gen.towers)
	check(World.spawn_position.y < CityGen.WATERLINE * B, "hospital spawn is above the waterline (GL-02)")
	check(await until(func(): return player.state == Player.State.GROUNDED, 120), "player lands in the medical room")
	check(World.band_at(World.cell_at(player.global_position)) == "dry", "spawn floor is in The Dry")
	var ground_ok := true
	for gx in [10, 400, 1200, 2000, 2390]:
		if not World.has_block_cell(Vector2i(gx, CityGen.GROUND)):
			ground_ok = false
	check(ground_ok, "bare concrete ground spans the city (CT-07)")

	print("== C. connectivity flooding (CT-12/13)")
	var sim := World.water_sim
	check(sim.level_at(Vector2i(6, CityGen.WATERLINE + 20)) == WaterSim.MAX_LEVEL, "open ocean is flooded")
	check(sim.level_at(Vector2i(6, CityGen.WATERLINE - 4)) == 0, "no water above the waterline")
	var dry_rooms := 0
	for rect: Rect2i in gen.sealed:
		var has_water := false
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if sim.level_at(Vector2i(x, y)) > 0:
					has_water = true
					break
			if has_water:
				break
		if not has_water:
			dry_rooms += 1
	check(gen.sealed.size() >= 10, "generator sealed %d submerged floors" % gen.sealed.size())
	check(dry_rooms >= gen.sealed.size() / 3, "%d/%d sealed floors kept their air (wear breached the rest)" % [dry_rooms, gen.sealed.size()])

	print("== D. depth bands (GD-16)")
	check(World.band_at(Vector2i(6, CityGen.WATERLINE - 10)) == "dry", "above waterline: dry")
	check(World.band_at(Vector2i(6, CityGen.WATERLINE + 10)) == "shallows", "shallows band")
	check(World.band_at(Vector2i(6, CityGen.WATERLINE + 60)) == "cold", "cold band")
	check(World.band_at(Vector2i(6, CityGen.WATERLINE + 150)) == "dark", "dark band")
	check(World.band_at(Vector2i(6, CityGen.WATERLINE + 260)) == "crush", "crush band")

	print("== E. cold and crush gates (CC-16, GL-12)")
	player.global_position = Vector2(8 * B, (CityGen.WATERLINE + 150) * B)
	player.velocity = Vector2.ZERO
	await ticks(60)
	check(player.band == "dark" and player.env_slow < 1.0, "The Dark slows an unsuited diver (x%.2f)" % player.env_slow)
	check(player.health < Constants.MAX_HEALTH, "and chills them (hp %.1f)" % player.health)
	var hp_before := player.health
	player.global_position = Vector2(8 * B, (CityGen.WATERLINE + 260) * B)
	await ticks(30)
	check(player.health < hp_before - 8.0, "The Crush hurts fast without a hard suit (hp %.1f)" % player.health)
	player.respawn()

	print("== F. day/night (CC-11)")
	World.time_of_day = 0.0
	check(World.sun_strength() <= 0.2, "midnight sun is a dim glow (%.2f)" % World.sun_strength())
	World.time_of_day = 0.5
	check(World.sun_strength() >= 0.99, "midday sun is full (%.2f)" % World.sun_strength())
	World.time_of_day = 0.35

	print("\nM3 smoke: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
