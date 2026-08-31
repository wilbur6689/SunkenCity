extends Node2D
## The game scene (M3): a seeded, procedurally generated drowned city.
## Pass a seed with:  godot --path . -- --seed=12345

var gen: Dictionary

@onready var structure_renderer: StructureRenderer = $StructureRenderer
@onready var water_renderer: WaterRenderer = $WaterRenderer
@onready var items_root: Node2D = $Items
@onready var objects_root: Node2D = $Objects
@onready var player: Player = $Player

func _ready() -> void:
	var seed_value := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))
	var t0 := Time.get_ticks_msec()
	gen = CityGen.generate(seed_value)
	World.register(gen.grid, gen.spawn_feet, items_root, objects_root, structure_renderer, gen.waterline_row)
	for o in gen.objects:
		World.place_object(o.id, o.cell, false)
	for dc in gen.doors:
		World.place_object("wood_door", dc, false)
	CityGen.flood(World) # after doors exist: sealing is solidity (WS-20)
	print("City seed %d: %d towers, generated in %d ms" % [seed_value, gen.towers, Time.get_ticks_msec() - t0])
	water_renderer.setup(gen.waterline_row * Constants.BLOCK_SIZE)
	$Backdrop.setup(gen.waterline_row * Constants.BLOCK_SIZE, -900.0)
	player.respawn()
	player.inventory.add("bandage", 2) # LT-30 starting kit
	player.inventory.add("food_can", 1)
	player.set_equipment("suit", {"id": "clothes", "count": 1})
	# Dev aid: --shot=path[:zoom_steps] saves a screenshot and quits.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_take_shot(a.substr(7))

func _take_shot(spec: String) -> void:
	var parts := spec.rsplit(":", true, 1)
	var path := spec
	if parts.size() > 1 and parts[1].is_valid_int(): # else the colon was a drive letter
		path = parts[0]
		for i in absi(int(parts[1])):
			player.zoom_step(-1 if int(parts[1]) < 0 else 1)
		player.camera.reset_smoothing()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	print("shot saved: ", path)
	get_tree().quit()
