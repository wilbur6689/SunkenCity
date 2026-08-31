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
	DirAccess.remove_absolute("user://objects_test.json")
	DirAccess.remove_absolute("user://smoke_shelf.png")
	print("\nFurniture editor smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
