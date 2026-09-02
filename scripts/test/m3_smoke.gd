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
	check(r1.towers >= 6, "800-wide slice holds %d towers (double-wide)" % r1.towers)

	print("== B. the full city")
	SaveGame.pending_character = "__m3_smoke__" # never inherit a real save
	city = load("res://scenes/city/city.tscn").instantiate()
	add_child(city)
	player = city.get_node("Player")
	player.set_multiplayer_authority(2)
	await get_tree().physics_frame
	var gen: Dictionary = city.gen
	check(gen.towers >= 20, "city holds %d double-wide towers" % gen.towers)
	check(World.spawn_position.y < CityGen.WATERLINE * B, "hospital spawn is above the waterline (GL-02)")
	check(await until(func(): return player.state == Player.State.GROUNDED, 120), "player lands on the hospital roof (drop-off start)")
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
	# Tower interiors must flood to the waterline (user bug 2026-09-01:
	# fully vent-sealed towers stayed dry inside - a 50-block air fall).
	var hosp3: Dictionary = gen.hospital
	check(sim.level_at(Vector2i(int(hosp3.x0) + 4, CityGen.WATERLINE + 10)) > 0,
		"the tallest tower's stairwell holds water below the waterline")
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

	print("== G. room packs (sheet sprites + wall art)")
	var pack_count := 0
	for oid in Data.objects:
		if Data.objects[oid].has("sheet"):
			pack_count += 1
	check(pack_count >= 70, "objects.json carries %d sheet-packed items" % pack_count)
	var gurney_tex := Data.object_texture("hos_gurney")
	check(gurney_tex is AtlasTexture and gurney_tex.get_size() == Vector2(48, 32),
			"pack sprite loads as an AtlasTexture region (hos_gurney 48x32)")
	# Wall art needs back walls behind every cell (WS-20/21): a spot inside
	# the medical room has them; the open sky above the city does not.
	var med := Vector2i(int(city.gen.hospital.zones[0][0]) + 3, int(city.gen.hospital.top) + CityGen.FLOOR_H - 1)
	var sc := med + Vector2i(0, -3) # above the medical room, one floor under the spawn roof
	check(World.has_back_wall_cell(sc) and World.can_place_object("hos_eye_chart", sc),
			"wall art hangs on an interior back wall")
	check(not World.can_place_object("hos_eye_chart", Vector2i(6, 10)), "but not on open sky")
	var sofa := World.place_object("res_sofa", med + Vector2i(6, 0), true)
	check(sofa != null and sofa.sprite.texture != null, "a pack item places with its sheet sprite")

	print("== H. edge walls, stations, debris, two-jump (CT-22/08/23, WS-04)")
	player.global_position = Vector2(-40 * B, (CityGen.WATERLINE - 6) * B)
	player.velocity = Vector2.ZERO
	await ticks(2)
	check(player.global_position.x >= 0.0, "invisible west edge wall clamps the player (x=%.0f)" % player.global_position.x)
	player.respawn()
	check(gen.has("central"), "central pump station shell stands on the ground (CT-08)")
	check(gen.relays.size() == 3, "%d relay pylons at the band boundaries (CC-26)" % gen.relays.size())
	if gen.relays.size() == 3:
		var relay_ok := true
		for i in 3:
			var shell: Rect2i = gen.relays[i]
			var interior := Vector2i(shell.position.x + 5, shell.end.y - 1)
			if World.has_block_cell(interior) or not World.has_back_wall_cell(interior):
				relay_ok = false
		check(relay_ok, "relay machine rooms are hollow with back walls")
	check(int(gen.debris) >= 5, "%d floating debris rafts on the surface (CT-23)" % int(gen.debris))
	var blockages := 0
	for tw in gen.tower_list:
		blockages += CityGen.floor_blockages(World.grid, tw).size()
	check(blockages == 0, "two-jump rule holds on every assembled floor (WS-04)")
	# Twin-wing towers: ladders on both sides, shaft down the middle, and
	# submerged ladder runs broken into repairable gaps (user request).
	var tw0: Dictionary = gen.tower_list[gen.tower_list.size() / 2]
	check(World.is_climbable_cell(Vector2i(int(tw0.x0) + 4, int(tw0.top) + 2)) \
			and World.is_climbable_cell(Vector2i(int(tw0.x1) - 4, int(tw0.top) + 2)),
			"ladders run on both sides of a tower (hugging the room-side wall)")
	check(not World.has_block_cell(Vector2i(int(tw0.mid), int(tw0.top) + CityGen.FLOOR_H)),
			"the central elevator shaft is open through the slabs")
	var broken := 0
	for rec: Dictionary in World.object_records:
		if rec.id == "broken_ladder":
			broken += 1
	check(broken >= 20, "%d broken ladder pieces await scrapping and repair" % broken)

	print("== J. audio director")
	check(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("Ambient") >= 0 \
			and AudioServer.get_bus_index("SFX") >= 0, "Music/Ambient/SFX buses exist")
	check(Audio.desired_pool() == "adventure", "safe band scores adventure music")
	player.global_position = Vector2(8 * B, (CityGen.WATERLINE + 150) * B)
	player.velocity = Vector2.ZERO
	await ticks(3)
	check(Audio.desired_pool() == "threat", "The Dark calls up threat music")
	await ticks(45) # submerged in open water: the outside bed fades in
	check(Audio.amb_outside.volume_db > -50.0, "open-water ambient bed fading in (%.0f dB)" % Audio.amb_outside.volume_db)
	check(Audio.amb_inside.volume_db <= -50.0, "interior bed stays quiet outside")
	player.respawn()

	print("\nM3 smoke: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
