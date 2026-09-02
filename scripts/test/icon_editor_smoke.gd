extends Node
## Headless checks for the Icon Editor: boot, the material list, loading an
## icon from the sheet, painting (LMB/RMB/eraser), save exports the PNG and
## flags authored_icon, and the standalone-first reload roundtrip.
var failures := 0
var checks := 0
func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok:   " if cond else "  FAIL: ") + msg)
	if not cond: failures += 1
func _ready() -> void:
	var ed = load("res://scenes/tools/icon_editor.tscn").instantiate()
	ed.items_path = "user://items_test.json"
	ed.icons_dir = "user://icons/"
	add_child(ed)
	await get_tree().process_frame
	var pm = ed.get_tree().get_first_node_in_group("pause_menu")
	check(pm != null, "pause menu mounted")
	var has_wood := false
	var has_tool := false
	for i in ed.load_option.item_count:
		var t: String = ed.load_option.get_item_text(i)
		if t == "material · wood":
			has_wood = true
		if t.begins_with("tool · ") or t.begins_with("weapon · "):
			has_tool = true
	check(has_wood and has_tool and ed.load_option.item_count >= 20,
		"list holds materials AND tools/weapons/armor (%d items)" % ed.load_option.item_count)
	ed._load_id("wood")
	var opaque := 0
	for y in 16:
		for x in 16:
			if ed.image.get_pixel(x, y).a > 0.5:
				opaque += 1
	check(opaque > 20, "wood icon loads from the item sheet (%d px)" % opaque)
	ed.brush = Color8(240, 200, 40)
	ed._apply(Vector2i(2, 2), false)
	check(ed.image.get_pixel(2, 2).is_equal_approx(Color8(240, 200, 40)), "LMB paints the primary colour")
	ed.brush2 = Color8(40, 80, 200)
	ed._apply(Vector2i(3, 2), true)
	check(ed.image.get_pixel(3, 2).is_equal_approx(Color8(40, 80, 200)), "RMB paints the secondary colour")
	ed._erase_at(Vector2i(3, 2))
	check(ed.image.get_pixel(3, 2).a < 0.1, "MMB / eraser clears")
	# select / cut / paste moves a section (user request 2026-09-01)
	ed._apply(Vector2i(2, 2), false) # ensure the source pixel exists
	ed.sel_a = Vector2i(2, 2)
	ed.sel_b = Vector2i(3, 3)
	ed._copy_selection(true)
	check(ed.image.get_pixel(2, 2).a < 0.1, "Cut clears the selection")
	ed._begin_paste()
	check(ed.pasting, "Paste arms the ghost")
	ed._stamp_clipboard(Vector2i(9, 9))
	check(ed.image.get_pixel(9, 9).is_equal_approx(Color8(240, 200, 40)), "stamp lands the section at the new spot")
	ed.pasting = false
	ed._save()
	check(FileAccess.file_exists("user://icons/wood.png"), "icon PNG exported")
	var lib = JSON.parse_string(FileAccess.get_file_as_string("user://items_test.json"))
	var flagged := false
	for it in lib.items:
		if it.id == "wood" and it.get("authored_icon", false):
			flagged = true
	check(flagged, "saving flags authored_icon (raw-load + regen protection)")
	# roundtrip: standalone wins over the sheet
	ed.image.fill(Color(0, 0, 0, 0))
	ed._load_id("wood")
	check(ed.image.get_pixel(9, 9).is_equal_approx(Color8(240, 200, 40)), "reload prefers the saved standalone icon")
	DirAccess.remove_absolute("user://icons/wood.png")
	DirAccess.remove_absolute("user://items_test.json")
	print("\nIcon editor smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
