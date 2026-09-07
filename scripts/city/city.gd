extends Node2D
## The game scene (M3): a seeded, procedurally generated drowned city —
## or a reloaded one (CC-09) when SaveGame.pending_world is set.
## Pass a seed with:  godot --path . -- --seed=12345
## Quick keys in-game: F5 saves world + character, F9 reloads the last save.

var gen: Dictionary
var seed_value := 1
var world_name := ""  # the world's FILE KEY (save file stem, character position tables)
var world_title := "" # its display name (title list, beacon, JOIN list, pause menu); = world_name by default
var character_name := "diver"

@onready var structure_renderer: StructureRenderer = $StructureRenderer
@onready var water_renderer: WaterRenderer = $WaterRenderer
@onready var items_root: Node2D = $Items
@onready var objects_root: Node2D = $Objects
@onready var players: Players = $Players
var player: Player # the host's own body (peer 1 offline); clients get theirs via Players.spawn_for

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))
	if SaveGame.pending_seed >= 0:
		seed_value = SaveGame.pending_seed
		SaveGame.pending_seed = -1
	if SaveGame.pending_character != "":
		character_name = SaveGame.pending_character
	# LAN Step 1: the local player lives in the Players container (one per peer).
	# Step 4 (D): on a CLIENT this is the local PUPPET, parked at the payload's
	# spawn and silent until Net/PlayerSpawn._spawn_player (host READY) places it
	# and opens its input stream; spawn_for is idempotent, so that RPC reuses it.
	player = players.spawn_for(Net.local_peer(), character_name)
	var loaded := false
	# LAN Step 3: a joining client boots from the host's snapshot through the
	# disk-load path (no generation, no LootGen/EnemyGen, no character from
	# disk - the host owns the body and its state).
	if Net.is_client() and not Net.pending_snapshot.is_empty():
		var snap: Dictionary = Net.pending_snapshot
		Net.pending_snapshot = {}
		SaveGame.pending_world = ""
		SaveGame.pending_world_name = ""
		world_name = String(snap.get("key", snap.get("name", "")))
		world_title = SaveGame.display_name_of(snap, world_name)
		_boot_loaded(snap)
		loaded = true
		if Net.world_sync != null and Net.world_sync.has_method("_ready_for_world"):
			Net.world_sync.rpc_id(1, "_ready_for_world")
		else:
			print("[net] client world up; no WorldSync yet - _ready_for_world not sent")
	elif SaveGame.pending_world != "":
		var data := SaveGame.read_world(SaveGame.pending_world)
		if not data.is_empty():
			world_name = SaveGame.pending_world
			world_title = SaveGame.display_name_of(data, world_name)
			SaveGame.pending_world = ""
			SaveGame.pending_world_name = ""
			_boot_loaded(data)
			loaded = true
		else:
			SaveGame.pending_world = ""
	if not loaded:
		# Key + display name: `world_<seed>` for both unless the player typed
		# a name (SaveGame.new_world_key slugs it and dodges an existing file).
		var named := SaveGame.new_world_key(SaveGame.pending_world_name, seed_value)
		SaveGame.pending_world_name = ""
		world_name = named.key
		world_title = named.name
		_boot_generated()
	if Net.mode == Net.Mode.HOST:
		print("NETHOST ready port=%d" % Net.port) # MultiplayerImpl §8: drivers wait for this
	for a in OS.get_cmdline_user_args(): # dev probe (MultiplayerImpl §8): NETPROBE lines, --net-drive
		if a.begins_with("--net-probe="):
			var probe := Node.new()
			probe.name = "NetProbe"
			probe.set_script(load("res://scripts/net/net_probe.gd"))
			add_child(probe)
			break
	# Dev aids: --at=col,row puts the player's feet on that cell (e.g. inside
	# an interior pocket); --shot=path[:zoom_steps] saves a screenshot and quits.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			var xy := a.substr(5).split(",")
			if xy.size() == 2:
				player.travel_to(Vector2((int(xy[0]) + 0.5) * Constants.BLOCK_SIZE, (int(xy[1]) + 1) * Constants.BLOCK_SIZE))
		elif a.begins_with("--time="): # dev aid: set time_of_day (0=midnight, 0.5=noon)
			World.time_of_day = clampf(a.substr(7).to_float(), 0.0, 1.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_take_shot(a.substr(7))
	# Perf probe (2026-09-05): --perf=SECS samples frame costs and quits;
	# --zoom=IDX / --objwin=WxH / --enemywin=WxH set the view + streaming
	# windows for a render test; --walk drives the body right meanwhile.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zoom="):
			player.zoom_index = clampi(a.substr(7).to_int(), 0, Constants.CAMERA_ZOOM_LEVELS.size() - 1)
		elif a.begins_with("--objwin="):
			var wh := a.substr(9).split("x")
			if wh.size() == 2:
				World.object_window = Vector2i(wh[0].to_int(), wh[1].to_int())
				World.refresh_objects_around(player.global_position)
		elif a.begins_with("--enemywin="):
			var wh := a.substr(11).split("x")
			if wh.size() == 2:
				World.enemy_window = Vector2i(wh[0].to_int(), wh[1].to_int())
				World.refresh_objects_around(player.global_position)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--perf="):
			var probe := Node.new()
			probe.name = "PerfProbe"
			probe.set_script(load("res://scripts/test/perf_probe.gd"))
			add_child(probe)
			break

func local_player() -> Player:
	return player

func _boot_generated() -> void:
	var t0 := Time.get_ticks_msec()
	gen = CityGen.generate(seed_value)
	var t_gen := Time.get_ticks_msec() - t0
	World.register(gen.grid, gen.spawn_feet, items_root, objects_root, structure_renderer,
		gen.waterline_row, int(gen.get("city_w", -1)))
	World.towers = _tower_summaries(gen.tower_list)
	# Data-only records: the object window instantiates the ones near spawn.
	for o in gen.objects:
		var rec := World.add_object_record(o.id, o.cell, false)
		if o.has("link"): # interior doorway: its twin's cell + shared open state
			rec["link"] = o.link
			rec.open = bool(o.get("open", false))
		if o.has("door"): # release button: the barred door it opens
			rec["door"] = o.door
	for dc in gen.doors:
		var drec := World.add_object_record(dc.id, dc.cell, false)
		if bool(dc.get("open", false)):
			drec.open = true # a drainable floor's door is found open (the flood passes)
	var n_parts := CityGen.place_parts(World, gen, seed_value) # found bench parts (2026-09-06)
	if "--f3" in OS.get_cmdline_user_args():
		print("CityGen: %d bench parts placed" % n_parts)
	for p in gen.get("pockets", []):
		World.pockets.append({"rect": p.rect, "exit": p.exit, "entry": p.entry})
	LootGen.fill_containers(World.object_records, gen.waterline_row, seed_value, World.towers, World.pockets)
	for e in EnemyGen.seed_city(gen, seed_value): # M4: seeded once, no respawn (GD-02)
		World.add_enemy_record(e.type, e.pos, float(e.get("mult", 1.0))) # pocket guardians come in at x2
	var t_flood0 := Time.get_ticks_msec()
	CityGen.flood(World) # after doors exist: sealing is solidity (WS-20)
	var t_flood := Time.get_ticks_msec() - t_flood0
	# Pockets touch no ocean: the generator decided which ones drowned.
	for p in gen.get("pockets", []):
		if p.flooded:
			World.water_sim.fill_rect(p.rect, WaterSim.MAX_LEVEL)
	print("City seed %d: %d towers, %d enemies, generated in %d ms (gen %d · records+loot+enemies %d · flood %d)" % [seed_value, gen.towers,
		World.enemy_records.size(), Time.get_ticks_msec() - t0, t_gen, t_flood0 - t0 - t_gen, t_flood])
	_setup_visuals()
	player.respawn()
	player.inventory.add("bandage", 2) # LT-30 starting kit
	player.inventory.add("food_can", 1)
	player.set_equipment("suit", {"id": "clothes", "count": 1})
	var char_data := SaveGame.read_character(character_name)
	if not char_data.is_empty(): # returning character entering a fresh world
		SaveGame.apply_character(char_data, player, world_name)
	World.refresh_objects_around(player.global_position)

func _boot_loaded(data: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	seed_value = int(data.seed)
	var grid := SaveGame.build_grid(data)
	World.register(grid, data.spawn, items_root, objects_root, structure_renderer, int(data.waterline_row),
		int(data.get("city_w", -1)))
	for p in data.get("pockets", []):
		World.pockets.append((p as Dictionary).duplicate())
	for t in data.get("towers", []):
		World.towers.append((t as Dictionary).duplicate())
	World.time_of_day = float(data.time_of_day)
	World.placed_blocks = (data.placed_blocks as Dictionary).duplicate(true)
	World.structure_damage = (data.get("structure_damage", {}) as Dictionary).duplicate()
	World.damage_rev += 1 # loaded damage: the crack overlay redraws
	# Compact object records (SaveGame.WORLD_VERSION 3): id table + 4 ints per record + sparse extras.
	var ids: Array = data.object_ids
	var cells: PackedInt32Array = data.object_cells
	var extra: Dictionary = data.object_extra
	for i in cells.size() / 4:
		var flags: int = cells[i * 4 + 3]
		var rec := World.add_object_record(String(ids[cells[i * 4]]), Vector2i(cells[i * 4 + 1], cells[i * 4 + 2]),
			flags & SaveGame.OBJ_PLACED != 0)
		rec.open = flags & SaveGame.OBJ_OPEN != 0
		rec.powered = flags & SaveGame.OBJ_POWERED != 0
		rec.unlocked = flags & SaveGame.OBJ_UNLOCKED != 0
		if extra.has(i):
			var st: Dictionary = extra[i]
			rec.outlet = st.get("outlet", WorldObject.NO_OUTLET)
			if st.has("link"):
				rec["link"] = st.link
			if st.has("door"):
				rec["door"] = st.door
			if st.has("grow_day"):
				rec["grow_day"] = st.grow_day
			if rec.storage != null and st.has("storage"):
				var slots: Array = (st.storage as Array).duplicate(true)
				slots.resize(rec.storage.slots.size())
				rec.storage.slots = slots
	for it in data.items:
		World.spawn_item(it.id, int(it.count), it.pos)
	for bp in data.get("backpacks", []):
		World.spawn_backpack((bp.slots as Array).duplicate(true), bp.pos)
	for en in data.get("enemies", []):
		var erec := World.add_enemy_record(en.type, en.pos, float(en.get("mult", 1.0)))
		if not erec.is_empty():
			erec.hp = float(en.hp)
			if en.has("stock"):
				erec.stock = int(en.stock)
	if data.has("map"): # shared fog-of-war map (2026-09-06)
		World.map_reveal.from_bytes(data.map)
	World.day_count = int(data.get("day_count", 0))
	World.next_red_moon_day = int(data.get("next_red_moon_day", World.next_red_moon_day))
	World.red_moon_active = bool(data.get("red_moon_active", false))
	# Water restores exactly as saved; nothing is awake until disturbed.
	World.water_sim.levels = (data.water as PackedByteArray).decompress(
		grid.bounds.size.x * grid.bounds.size.y, FileAccess.COMPRESSION_ZSTD)
	World.update_power()
	print("Loaded '%s' (seed %d) in %d ms" % [data.name, seed_value, Time.get_ticks_msec() - t0])
	_setup_visuals()
	player.respawn() # a client's local body starts at the payload's spawn; the host's state stream moves it
	if not Net.is_client(): # the host places and dresses every body (MultiplayerImpl §3.5)
		SaveGame.apply_character(SaveGame.read_character(character_name), player, String(data.name))
	World.refresh_objects_around(player.global_position)

func _setup_visuals() -> void:
	water_renderer.setup(World.waterline_row * Constants.BLOCK_SIZE)
	$Backdrop.setup(World.waterline_row * Constants.BLOCK_SIZE, -900.0,
		World.city_bounds.size.x * Constants.BLOCK_SIZE)

## Red moon dressing (CC-14): a blood tint while the moon is up, a warning
## line when it rises. The World runs the actual waves.
@onready var _daynight: CanvasModulate = $CanvasModulate # the scene's world-layer tint
var _red_moon_seen := false

func _process(_delta: float) -> void:
	if not World.is_ready():
		return
	# Visible day/night cycle (user request 2026-09-02): the world fades to a
	# moonlit blue at deepest night and back to full daylight by noon, driven
	# by the sun. The blood moon layers its red over whatever the night tint is.
	var s := World.sun_strength() # [0.12, 1.0]
	var t := clampf((s - 0.12) / 0.88, 0.0, 1.0)
	var col: Color = Constants.NIGHT_TINT.lerp(Color.WHITE, t)
	if World.red_moon_active:
		col = col * Constants.RED_MOON_TINT
	_daynight.color = col
	if World.red_moon_active != _red_moon_seen:
		_red_moon_seen = World.red_moon_active
		player.message.emit("The moon rises red — they are coming"
			if _red_moon_seen else "Dawn breaks; the red moon sets")

## Write both save files for the current run. LAN (Step 7): a client only
## writes its character (from the host's replica - the host keeps the
## world); the host also banks every connected character and pushes each
## client its final state so they write their own files.
func save_now() -> void:
	if Net.is_client():
		_save_local_character()
		return
	SaveGame.save_world(world_name, seed_value, world_title)
	SaveGame.save_character(character_name, player, world_name)
	if Net.mode == Net.Mode.HOST and Net.char_sync != null and Net.char_sync.has_method("save_all_characters"):
		Net.char_sync.save_all_characters()

## This process's own body (a client's is spawned late by Net/PlayerSpawn).
func _local_body() -> Player:
	if player != null and is_instance_valid(player):
		return player
	return Net.local_player()

## Client: the character file from the replica + the local map reveal.
func _save_local_character() -> void:
	var body := _local_body()
	if body != null and World.is_ready():
		SaveGame.save_character(character_name, body, world_name)

## Esc from the game: bank everything, then back to the title. Without this
## a fresh world/character only became files on F5, so quitting made them
## look like they were never created (the pickers list files). Hosting: the
## world closes for everyone first (each client gets its final state).
func save_and_exit_to_title() -> void:
	if Net.is_client():
		leave_world()
		return
	save_now()
	if Net.is_online():
		Net.close_world()
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")

## LEAVE on a client (pause menu): character from the replica, drop the
## connection, back to the title. On the host it is Save & Quit.
func leave_world() -> void:
	if not Net.is_client():
		save_and_exit_to_title()
		return
	_save_local_character()
	Net.leave("")
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")

## The host went away (Net.disconnected, via Net/CharSync): keep what the
## replica holds, tell the title why.
func on_net_disconnected(reason: String) -> void:
	_save_local_character()
	SaveGame.pending_notice = "Disconnected: " + reason
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and World.is_ready() and _local_body() != null:
		save_now() # closing the window mid-run loses nothing (host: pushes final states too)
		if Net.is_client():
			Net.leave("")
		elif Net.is_online():
			Net.close_world()

## Quick save/load (CC-09): F5 writes both files, F9 reboots from them.
## LAN: a client's F5 saves only its character; F9 is host-only.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var body := _local_body()
		if body == null:
			return
		if event.keycode == KEY_F5:
			save_now()
			if Net.is_client():
				body.message.emit("Saved '%s' (the host keeps the world)" % character_name)
			else:
				body.message.emit("Saved '%s' / '%s'" % [world_title, character_name])
		elif event.keycode == KEY_F9:
			if Net.is_client():
				body.message.emit("Only the host can reload the world")
				return
			if Net.is_online():
				body.message.emit("Close the world before reloading it")
				return
			if SaveGame.read_world(world_name).is_empty():
				player.message.emit("No save for '%s' yet (F5 saves)" % world_name)
				return
			SaveGame.pending_world = world_name
			SaveGame.pending_character = character_name
			get_tree().reload_current_scene()

func _take_shot(spec: String) -> void:
	var parts := spec.rsplit(":", true, 1)
	var path := spec
	if parts.size() > 1 and parts[1].is_valid_int(): # else the colon was a drive letter
		path = parts[0]
		for i in absi(int(parts[1])):
			player.zoom_step(-1 if int(parts[1]) < 0 else 1)
		player.camera.reset_smoothing()
	await get_tree().create_timer(2.5).timeout # past the generation hitch
	if OS.get_cmdline_user_args().has("--hover"): # park the mouse on furniture
		var nearest: WorldObject = null
		var best := 1e9
		for obj in World.objects_root.get_children():
			if obj is WorldObject and obj.is_interactable():
				var d: float = obj.center().distance_to(player.global_position)
				if d < best and d < 10 * Constants.BLOCK_SIZE:
					best = d
					nearest = obj
		if nearest != null:
			var vp := get_viewport()
			Input.warp_mouse(vp.get_screen_transform() * vp.get_canvas_transform() * nearest.center())
			await get_tree().create_timer(0.5).timeout # let the card slide up
	get_viewport().get_texture().get_image().save_png(path)
	print("shot saved: ", path)
	var hud := get_node_or_null("HUD")
	if hud != null and hud.get("_debug_text") != null and OS.get_cmdline_user_args().has("--f3"):
		print("F3 at shot:
" + hud._debug_text.text) # dev aid: exact perf numbers alongside the picture
	get_tree().quit()

## The small per-tower record World keeps for floor-level band lookups
## (and the world save carries): footprint, crown row, floor count and pitch.
func _tower_summaries(tower_list: Array) -> Array:
	var out: Array = []
	for t in tower_list:
		out.append({"x0": int(t.x0), "x1": int(t.x1), "top": int(t.top), "floors": int(t.floors),
			"floor_h": int(t.get("floor_h", CityGen.FLOOR_H)), "district": String(t.get("district", "residential"))})
	return out
