extends Node
## Dev aid: boots the test tower and opens the character menu on a given
## screen so it can be screenshotted without input. Usage:
##   godot --path . res://scenes/test/menu_preview.tscn -- --screen=crafting
## Screens: inventory (default), crafting, chest (places a chest and opens it).

func _ready() -> void:
	var screen := "inventory"
	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			screen = a.substr(9)
		elif a.begins_with("--shot="):
			shot = a.substr(7)
	if screen == "multiplayer": # the title-side Multiplayer screen (2026-09-05): no tower needed
		var mp = load("res://scenes/ui/multiplayer_menu.tscn").instantiate()
		add_child(mp)
		if OS.get_cmdline_user_args().has("--page=join"):
			mp._show_page("join")
		if shot != "":
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png(shot)
			print("shot saved: ", shot)
			get_tree().quit()
		return
	var tower = load("res://scenes/test/test_tower.tscn").instantiate()
	add_child(tower)
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
			World.place_object("mod_bench", World.cell_at(player.global_position) + Vector2i(3, -1), true)
			# A few cells across the grid, one hybrid, a clean knife to apply to.
			player.mod_library = {"ind_1": 3, "ind_2": 1, "con_3": 2, "bus_2": 1, "res_1": 2, "com_4": 1, "civ_3": 1, "demolition_2": 1}
			player.inventory.add_stack({"id": "iron_knife", "count": 1,
				"mods": {"prefix": {"id": "ind_3", "count": 1}, "suffix": {"id": "civ_3"}}})
			player.inventory.add("scrap_knife", 1)
			ui.open_panel("mod_bench")
		_:
			ui.open_panel()
			if screen != "inventory":
				ui.show_screen(screen)
	for a in OS.get_cmdline_user_args(): # --hover=N: show bag slot N's tooltip (badge preview, 2026-09-06)
		if a.begins_with("--hover=hotbar:"): # the HUD's hotbar tooltip (2026-09-06)
			var hud := get_tree().root.find_child("HUD", true, false)
			if hud != null:
				ui.close()
				hud._set_hotbar_hover(a.substr(15).to_int())
		elif a.begins_with("--hover="):
			ui._set_hover("inv", a.substr(8).to_int())
			ui._update_hover_plate()
	if shot != "":
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png(shot)
		print("shot saved: ", shot)
		get_tree().quit()
