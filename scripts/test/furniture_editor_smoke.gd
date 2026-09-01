extends Node
## Headless checks for the Furniture Editor: boot, painting, resize keeps
## pixels, yields editing, save exports JSON + PNG, update-in-place.
var failures := 0
var checks := 0
func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok:   " if cond else "  FAIL: ") + msg)
	if not cond: failures += 1
func _ready() -> void:
	var ed = load("res://scenes/tools/furniture_editor.tscn").instantiate()
	ed.objects_path = "user://objects_test.json"
	ed.sprites_dir = "user://"
	add_child(ed)
	await get_tree().process_frame
	check(ed.image.get_width() == 32 and ed.image.get_height() == 32, "default canvas is 2x2 blocks (32px)")
	# Esc menu (user request): the in-game pause menu mounted with editor bindings.
	var pm = ed.get_tree().get_first_node_in_group("pause_menu")
	check(pm != null and not pm.open, "pause menu mounted, closed at start")
	pm.open_menu()
	check(pm.open and pm.quit_button.text == "QUIT TO TITLE", "Esc menu opens with QUIT TO TITLE")
	pm._show_controls(true)
	check(pm.controls_box.visible and pm.controls_box.get_child_count() > 3, "CONTROLS page lists editor bindings")
	pm.close()
	check(not pm.open, "Esc menu closes")
	check(ed.image.get_pixel(3, 3).a > 0.9, "box prefill painted the hull")
	ed.id_edit.text = "smoke_shelf"
	ed.name_edit.text = "Smoke Shelf"
	ed.zone_checks["commercial"].button_pressed = true
	ed.brush = Color8(200, 60, 50)
	ed.tool_mode = "pencil"
	ed._apply(Vector2i(5, 5), false)
	check(ed.image.get_pixel(5, 5).is_equal_approx(Color8(200, 60, 50)), "pencil paints the brush colour")
	ed._apply(Vector2i(5, 5), true)
	check(ed.image.get_pixel(5, 5).a < 0.1, "RMB erases")
	ed.w_spin.value = 3 # widen; existing pixels preserved
	check(ed.image.get_width() == 48 and ed.image.get_pixel(3, 3).a > 0.9, "resize keeps painted content")
	ed.def.yields = [{"item": "scrap_metal", "min": 2, "max": 4}]
	ed._save()
	var lib = JSON.parse_string(FileAccess.get_file_as_string("user://objects_test.json"))
	check(lib.objects.size() == 1 and lib.objects[0].id == "smoke_shelf", "furniture exported to the library")
	var o = lib.objects[0]
	check(o.zones.has("commercial") and o.zones.has("residential"), "zone applicability exported")
	check(int(o.size[0]) == 3 and o.yields[0].item == "scrap_metal", "size + yields exported")
	check(FileAccess.file_exists("user://smoke_shelf.png"), "sprite PNG exported")
	ed._save()
	lib = JSON.parse_string(FileAccess.get_file_as_string("user://objects_test.json"))
	check(lib.objects.size() == 1, "re-saving updates instead of duplicating")
	# Storage flag (user request): mark as having an inventory, save, reload.
	ed.storage_check.button_pressed = true
	ed.storage_slots_spin.value = 8
	ed._save()
	lib = JSON.parse_string(FileAccess.get_file_as_string("user://objects_test.json"))
	check(int(lib.objects[0].storage_slots) == 8, "inventory flag + slot count exported")
	# Load roundtrip: wipe the canvas, load the saved piece back.
	ed.image.fill(Color(0, 0, 0, 0))
	ed.def = ed._default_def()
	ed._refresh_load_list()
	ed._load_selected(1)
	check(ed.def.id == "smoke_shelf" and ed.storage_check.button_pressed and int(ed.storage_slots_spin.value) == 8, "load restores settings incl. inventory flag")
	check(ed.image.get_pixel(3, 3).a > 0.9, "load restores the sprite pixels")
	DirAccess.remove_absolute("user://objects_test.json")
	DirAccess.remove_absolute("user://smoke_shelf.png")
	print("\nFurniture editor smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
