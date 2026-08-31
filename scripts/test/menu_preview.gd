extends Node
## Dev aid: boots the test tower and opens the character menu on a given
## screen so it can be screenshotted without input. Usage:
##   godot --path . res://scenes/test/menu_preview.tscn -- --screen=crafting
## Screens: inventory (default), crafting, chest (places a chest and opens it).

func _ready() -> void:
	var tower = load("res://scenes/test/test_tower.tscn").instantiate()
	add_child(tower)
	var screen := "inventory"
	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			screen = a.substr(9)
		elif a.begins_with("--shot="):
			shot = a.substr(7)
	await get_tree().create_timer(0.5).timeout
	var player: Player = tower.get_node("Player")
	var ui = tower.get_node("InventoryUI")
	# a little content so the screens are not empty
	player.inventory.add("wood", 14)
	player.inventory.add("scrap_metal", 6)
	player.inventory.add("cloth", 3)
	match screen:
		"world":
			# No menu: park the player at the floor-3 pool and zoom out to show the backdrop.
			player.global_position = Vector2(6 * 16 + 8, 17 * 16 + 16 - Player.FEET_Y)
			player.zoom_step(-2)
			player.camera.reset_smoothing()
		"deep":
			# Park in the deep-tower stairwell beside a themed floor.
			player.global_position = Vector2(4 * 16 + 8, 53 * 16 + 16 - Player.FEET_Y)
			player.zoom_step(-1)
			player.camera.reset_smoothing()
		"chest":
			var chest := World.place_object("chest", Vector2i(13, 5), true)
			chest.storage.add("plastic", 9)
			chest.storage.add("bandage", 2)
			ui.open_container(chest)
		"crafting":
			World.place_object("workbench", Vector2i(10, 5), true)
			ui.open_panel("workbench")
		"skills":
			# Banked points + one owned ability so the tree shows all states.
			player.skills.xp["scrapping"] = 10.0 * Constants.SKILL_XP_PER_LEVEL
			player.skills.xp["building"] = 5.0 * Constants.SKILL_XP_PER_LEVEL
			player.skills.unlock("field_strip")
			ui.open_panel()
			ui.show_screen("skills")
		"modify":
			World.place_object("mod_bench", Vector2i(10, 5), true)
			player.known_mods = {"sharp": 2, "of_the_deep": 3}
			player.inventory.add_stack({"id": "iron_knife", "count": 1,
				"mods": {"prefix": {"id": "swift", "power": 3}, "suffix": {"id": "of_the_shore", "power": 3}}})
			ui.open_panel("mod_bench")
		_:
			ui.open_panel()
			if screen != "inventory":
				ui.show_screen(screen)
	if shot != "":
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png(shot)
		print("shot saved: ", shot)
		get_tree().quit()
