extends Node2D
## The game scene (M3): a seeded, procedurally generated drowned city —
## or a reloaded one (CC-09) when SaveGame.pending_world is set.
## Pass a seed with:  godot --path . -- --seed=12345
## Quick keys in-game: F5 saves world + character, F9 reloads the last save.

var gen: Dictionary
var seed_value := 1
var world_name := ""
var character_name := "diver"

@onready var structure_renderer: StructureRenderer = $StructureRenderer
@onready var water_renderer: WaterRenderer = $WaterRenderer
@onready var items_root: Node2D = $Items
@onready var objects_root: Node2D = $Objects
@onready var player: Player = $Player

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))
	if SaveGame.pending_seed >= 0:
		seed_value = SaveGame.pending_seed
		SaveGame.pending_seed = -1
	if SaveGame.pending_character != "":
		character_name = SaveGame.pending_character
	var loaded := false
	if SaveGame.pending_world != "":
		var data := SaveGame.read_world(SaveGame.pending_world)
		if not data.is_empty():
			world_name = SaveGame.pending_world
			SaveGame.pending_world = ""
			_boot_loaded(data)
			loaded = true
		else:
			SaveGame.pending_world = ""
	if not loaded:
		world_name = "world_%d" % seed_value
		_boot_generated()
	# Dev aid: --shot=path[:zoom_steps] saves a screenshot and quits.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_take_shot(a.substr(7))

func _boot_generated() -> void:
	var t0 := Time.get_ticks_msec()
	gen = CityGen.generate(seed_value)
	World.register(gen.grid, gen.spawn_feet, items_root, objects_root, structure_renderer, gen.waterline_row)
	# Data-only records: the object window instantiates the ones near spawn.
	for o in gen.objects:
		World.add_object_record(o.id, o.cell, false)
	for dc in gen.doors:
		World.add_object_record(dc.id, dc.cell, false)
	LootGen.fill_containers(World.object_records, gen.waterline_row, seed_value)
	CityGen.flood(World) # after doors exist: sealing is solidity (WS-20)
	print("City seed %d: %d towers, generated in %d ms" % [seed_value, gen.towers, Time.get_ticks_msec() - t0])
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
	World.register(grid, data.spawn, items_root, objects_root, structure_renderer, int(data.waterline_row))
	World.time_of_day = float(data.time_of_day)
	World.placed_blocks = (data.placed_blocks as Dictionary).duplicate(true)
	World.structure_damage = (data.get("structure_damage", {}) as Dictionary).duplicate()
	for st in data.objects:
		var rec := World.add_object_record(st.id, st.cell, bool(st.placed))
		rec.open = bool(st.get("open", false))
		rec.powered = bool(st.get("powered", false))
		rec.unlocked = bool(st.get("unlocked", false))
		rec.outlet = st.get("outlet", WorldObject.NO_OUTLET)
		if rec.storage != null and st.has("storage"):
			var slots: Array = (st.storage as Array).duplicate(true)
			slots.resize(rec.storage.slots.size())
			rec.storage.slots = slots
	for it in data.items:
		World.spawn_item(it.id, int(it.count), it.pos)
	# Water restores exactly as saved; nothing is awake until disturbed.
	World.water_sim.levels = (data.water as PackedByteArray).decompress(
		grid.bounds.size.x * grid.bounds.size.y, FileAccess.COMPRESSION_ZSTD)
	World.update_power()
	print("Loaded '%s' (seed %d) in %d ms" % [data.name, seed_value, Time.get_ticks_msec() - t0])
	_setup_visuals()
	player.respawn()
	SaveGame.apply_character(SaveGame.read_character(character_name), player, String(data.name))
	World.refresh_objects_around(player.global_position)

func _setup_visuals() -> void:
	water_renderer.setup(World.waterline_row * Constants.BLOCK_SIZE)
	$Backdrop.setup(World.waterline_row * Constants.BLOCK_SIZE, -900.0)

## Write both save files for the current run.
func save_now() -> void:
	SaveGame.save_world(world_name, seed_value)
	SaveGame.save_character(character_name, player, world_name)

## Esc from the game: bank everything, then back to the title. Without this
## a fresh world/character only became files on F5, so quitting made them
## look like they were never created (the pickers list files).
func save_and_exit_to_title() -> void:
	save_now()
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and World.is_ready() and player != null:
		save_now() # closing the window mid-run loses nothing

## Quick save/load (CC-09): F5 writes both files, F9 reboots from them.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			save_now()
			player.message.emit("Saved '%s' / '%s'" % [world_name, character_name])
		elif event.keycode == KEY_F9:
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
				if d < best and d < 5 * Constants.BLOCK_SIZE:
					best = d
					nearest = obj
		if nearest != null:
			var vp := get_viewport()
			Input.warp_mouse(vp.get_screen_transform() * vp.get_canvas_transform() * nearest.center())
			await get_tree().create_timer(0.5).timeout # let the card slide up
	get_viewport().get_texture().get_image().save_png(path)
	print("shot saved: ", path)
	get_tree().quit()
