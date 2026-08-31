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
	ed.id_edit.text = "smoke_room"
	ed.type_edit.text = "test ward"
	ed.zone_option.selected = 3 # hospital
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
	ed._save()
	var lib = JSON.parse_string(FileAccess.get_file_as_string("user://rooms_test.json"))
	check(lib.rooms.size() == 1 and lib.rooms[0].id == "smoke_room", "room exported to the library")
	var r = lib.rooms[0]
	check(r.zone == "hospital" and r.depth_min == 10 and r.depth_max == 80 and r.type == "test ward", "settings exported (zone, type, depth range)")
	check(r.objects.size() == 2 and r.blocks.size() == 1, "contents exported")
	ed._save() # update path
	lib = JSON.parse_string(FileAccess.get_file_as_string("user://rooms_test.json"))
	check(lib.rooms.size() == 1, "re-saving updates instead of duplicating")
	DirAccess.remove_absolute("user://rooms_test.json")
	print("\nRoom editor smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
