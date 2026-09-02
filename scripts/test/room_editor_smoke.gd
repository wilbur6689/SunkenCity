extends Node
## Headless checks for the Room Editor: boot, block painting, furniture
## placement rules, save/load roundtrip against a scratch library.
var failures := 0
var checks := 0
func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok:   " if cond else "  FAIL: ") + msg)
	if not cond: failures += 1
func _ready() -> void:
	var ed = load("res://scenes/tools/room_editor.tscn").instantiate()
	ed.rooms_path = "user://rooms_test.json"
	add_child(ed)
	await get_tree().process_frame
	check(ed.room.width == 12 and ed.room.height == 5, "default room is 12x5")
	# Esc menu (user request): the in-game pause menu mounted with editor bindings.
	var pm = ed.get_tree().get_first_node_in_group("pause_menu")
	check(pm != null and not pm.open, "pause menu mounted, closed at start")
	pm.open_menu()
	check(pm.open and pm.quit_button.text == "QUIT GAME", "Esc menu opens with QUIT GAME (standalone tool)")
	pm._show_controls(true)
	check(pm.controls_box.visible and pm.controls_box.get_child_count() > 3, "CONTROLS page lists editor bindings")
	pm.close()
	check(not pm.open, "Esc menu closes")
	ed.id_edit.text = "smoke_room"
	ed.type_edit.text = "test ward"
	ed.zone_option.selected = ed.ZONES.find("civil") # civil (was hospital, renamed 2026-09-01)
	ed.depth_min_spin.value = 10
	ed.depth_max_spin.value = 80
	ed._apply_settings()
	ed._set_tool("block:2")
	ed._paint(Vector2i(3, 2))
	check(ed.room.blocks.size() == 1 and ed.room.blocks[0].mat == 2, "block painted (wood)")
	check(ed._fits_object("med_cart", 5), "furniture fits in empty space")
	ed.room.objects.append({"id": "med_cart", "x": 5})
	check(not ed._fits_object("cabinet", 6), "overlap rejected")
	check(ed._fits_object("cabinet", 8), "adjacent placement fits")
	ed.room.objects.append({"id": "cabinet", "x": 8})
	# Free placement: any object may sit off the floor; footprints collide as rectangles.
	ed._set_tool("object:chair")
	ed._use_tool(Vector2i(0, ed._standing_row() - 2)) # bottom row 2 above the floor
	check(ed.room.objects.size() == 3 and int(ed.room.objects[2].get("dy", 0)) == 2, "furniture placed off the floor keeps dy")
	check(not ed._fits_object("chair", 0, null, 2), "elevated overlap rejected")
	check(ed._fits_object("chair", 0, null, 0), "same column on the floor still fits below it")
	ed._save()
	var lib = JSON.parse_string(FileAccess.get_file_as_string("user://rooms_test.json"))
	check(lib.rooms.size() == 1 and lib.rooms[0].id == "smoke_room", "room exported to the library")
	var r = lib.rooms[0]
	check(r.zone == "civil" and r.depth_min == 10 and r.depth_max == 80 and r.type == "test ward", "settings exported (zone, type, depth range)")
	check(r.objects.size() == 3 and r.blocks.size() == 1, "contents exported")
	check(int(r.objects[2].get("dy", 0)) == 2, "elevated dy exported")
	ed._save() # update path
	lib = JSON.parse_string(FileAccess.get_file_as_string("user://rooms_test.json"))
	check(lib.rooms.size() == 1, "re-saving updates instead of duplicating")
	# Load list keys off the selected zone (user request 2026-09-01).
	ed._refresh_load_list()
	check(ed.load_option.item_count == 2 and ed.load_option.get_item_text(1) == "smoke_room", "load list shows the selected zone's rooms (civil)")
	ed.zone_option.selected = ed.ZONES.find("residential")
	ed._refresh_load_list()
	check(ed.load_option.item_count == 1, "load list hides rooms of other zones")
	DirAccess.remove_absolute("user://rooms_test.json")
	print("\nRoom editor smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
