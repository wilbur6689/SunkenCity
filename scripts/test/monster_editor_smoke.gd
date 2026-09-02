extends Node
## Headless checks for the Monster Editor: boot, the mode-grouped type list,
## load a type (fields + band rows + drops), edit + save (type replaced,
## band row rewritten, disabled band erased), new-type export, drop-item
## validation, and the load roundtrip.
var failures := 0
var checks := 0
func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok:   " if cond else "  FAIL: ") + msg)
	if not cond: failures += 1
func _find(ed, id: String) -> int:
	for i in ed.load_option.item_count:
		if ed.load_option.get_item_text(i).ends_with(" · " + id):
			return i
	return -1
func _ready() -> void:
	var ed = load("res://scenes/tools/monster_editor.tscn").instantiate()
	ed.enemies_path = "user://enemies_test.json"
	add_child(ed)
	await get_tree().process_frame
	check(ed.load_option.item_count == 7, "type list holds all 6 monsters (+ placeholder row)")
	var pm = ed.get_tree().get_first_node_in_group("pause_menu")
	check(pm != null, "pause menu mounted")
	ed._load_selected(_find(ed, "walker"))
	check(ed.id_edit.text == "walker" and int(ed.frames_spin.value) == 8 \
		and int(ed.variants_spin.value) == 11, "walker loads with frames + variants")
	check(ed.flag_checks["bleeds"].button_pressed and not ed.flag_checks["passive"].button_pressed,
		"flags load (bleeds on, passive off)")
	check(ed.band_rows["dry"].on.button_pressed and int(ed.band_rows["dry"]["hp"].value) == 30,
		"dry band row enabled with authored hp 30")
	check(ed.def.drops.size() == 2, "walker's drops table loads")
	check(ed.variant_option.item_count == 11, "preview lists all 11 walker sprite files")
	# edit: tweak a stat, drop a band, add a drop, save
	ed.band_rows["dry"]["hp"].value = 33
	ed.band_rows["crush"].on.button_pressed = false
	ed.def.drops.append({"item": "wood", "min": 1, "max": 1, "chance": 0.2})
	ed._save()
	var lib = JSON.parse_string(FileAccess.get_file_as_string("user://enemies_test.json"))
	check(lib.types.size() == 6, "saving replaces the type instead of duplicating")
	check(int(lib.bands.dry.walker.hp) == 33, "edited band stat saved")
	check(not lib.bands.crush.has("walker"), "disabled band row erased (seeds nowhere in The Crush)")
	for t in lib.types:
		if t.id == "walker":
			check(t.drops.size() == 3 and t.drops[2].item == "wood", "added drop saved")
	check(lib.seeding.has("wing_zombie_weights"), "seeding block preserved untouched")
	# bad drop item refuses to save (the game asserts drops at boot)
	ed.def.drops.append({"item": "no_such_item", "min": 1, "max": 1, "chance": 1.0})
	ed._save()
	check(ed.status_label.text.begins_with("Unknown drop item"), "unknown drop item refuses to save")
	ed.def.drops.pop_back()
	# a new monster exports with its band rows
	ed.def = ed._default_def()
	ed._sync_to_ui()
	ed.id_edit.text = "smoke_imp"
	ed.mode_option.selected = 2 # swim
	ed.band_rows["shallows"].on.button_pressed = true
	ed.band_rows["shallows"]["hp"].value = 12
	ed._save()
	lib = JSON.parse_string(FileAccess.get_file_as_string("user://enemies_test.json"))
	check(lib.types.size() == 7 and int(lib.bands.shallows.smoke_imp.hp) == 12,
		"new monster exported with its shallows row")
	# roundtrip: the list regrouped by mode and the new type loads back
	ed._load_selected(_find(ed, "smoke_imp"))
	check(ed.id_edit.text == "smoke_imp" and ed.mode_option.selected == 2 \
		and ed.band_rows["shallows"].on.button_pressed, "load restores the new monster")
	# frame stepping (user request): arrows pause playback and wrap
	ed._load_selected(_find(ed, "walker"))
	ed.play_check.button_pressed = true
	ed._step_frame(1)
	check(ed.cur_frame == 1 and not ed.play_check.button_pressed, "arrow steps a frame and pauses playback")
	ed._step_frame(-2)
	check(ed.cur_frame == 7, "stepping wraps around the strip")
	check(ed.frame_label.text == "frame 8/8", "frame label tracks (%s)" % ed.frame_label.text)
	# frame pixel editor: edit one pixel of a user:// copy and save
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://assets/sprites/enemies/walker.png"),
		ProjectSettings.globalize_path("user://walker.png"))
	ed.sprites_dir = "user://"
	ed._refresh_variants()
	ed.cur_frame = 2
	ed._open_frame_edit()
	check(ed.fe_layer != null and ed.fe_layer.visible, "Edit opens the frame window")
	check(ed.fe_img.get_width() == 28 and ed.fe_img.get_height() == 26, "the window holds one 28x26 frame")
	check(ed.fe_swatch_box.get_child_count() > 1, "swatches build from the frame's palette")
	check(ed.fe_swatch_box.get_parent().get_child_count() >= 16,
		"the shared MATERIALS + ACCENTS palette joins the frame palette")
	ed.fe_brush = Color8(250, 40, 200)
	ed.fe_pick = false
	ed._fe_apply(Vector2i(3, 3), false)
	ed.fe_brush2 = Color8(10, 200, 90)
	ed._fe_apply(Vector2i(4, 3), true)
	check(ed.fe_img.get_pixel(4, 3).is_equal_approx(Color8(10, 200, 90)), "RMB paints the secondary colour")
	ed.fe_erase = true
	ed._fe_apply(Vector2i(4, 3), false)
	check(ed.fe_img.get_pixel(4, 3).a < 0.1, "only the eraser clears")
	ed.fe_erase = false
	# select / cut / paste inside the frame window
	ed.fe_sel_a = Vector2i(3, 3)
	ed.fe_sel_b = Vector2i(3, 3)
	ed._fe_copy(true)
	check(ed.fe_img.get_pixel(3, 3).a < 0.1, "Cut clears the selected pixel")
	ed._fe_begin_paste()
	ed._fe_stamp(Vector2i(6, 6))
	check(ed.fe_img.get_pixel(6, 6).is_equal_approx(Color8(250, 40, 200)), "Paste stamps it elsewhere")
	ed.fe_pasting = false
	ed.fe_brush = Color8(250, 40, 200)
	ed._fe_apply(Vector2i(3, 3), false) # restore for the save-pixel check below
	ed._fe_apply(Vector2i(4, 3), false)
	var mev := InputEventMouseButton.new()
	mev.pressed = true
	mev.button_index = MOUSE_BUTTON_MIDDLE
	mev.position = Vector2(4 * ed.FE_PX + 2, 3 * ed.FE_PX + 2)
	ed._fe_input(mev)
	check(ed.fe_img.get_pixel(4, 3).a < 0.1, "MMB click clears the pixel")
	# in-window frame flow (user request): step, banked edits, +FRAME copy
	ed._fe_step(1)
	check(ed.cur_frame == 3, "in-window > advances to the next frame")
	ed._fe_step(-1)
	check(ed.cur_frame == 2 and ed.fe_img.get_pixel(3, 3).is_equal_approx(Color8(250, 40, 200)),
		"edits survive stepping away and back (banked in the strip)")
	ed._fe_add_frame()
	check(int(ed.frames_spin.value) == 9 and ed.cur_frame == 3, "+FRAME inserts after the current frame")
	check(ed.fe_img.get_pixel(3, 3).is_equal_approx(Color8(250, 40, 200)),
		"the new frame starts as a copy of its source")
	ed._fe_step(-1) # back to the painted frame before saving
	ed._save_frame()
	var edited := Image.load_from_file(ProjectSettings.globalize_path("user://walker.png"))
	check(edited.get_width() == 9 * 28, "the saved strip carries the added frame (9 x 28 px)")
	var libf = JSON.parse_string(FileAccess.get_file_as_string("user://enemies_test.json"))
	for t in libf.types:
		if t.id == "walker":
			check(int(t.get("frames", 0)) == 9, "frame count syncs into enemies.json on save")
	check(edited.get_pixel(2 * 28 + 3, 3).is_equal_approx(Color8(250, 40, 200)),
		"SAVE FRAME writes the pixel into the right frame of the strip")
	var lib2 = JSON.parse_string(FileAccess.get_file_as_string("user://enemies_test.json"))
	var auth := false
	for t in lib2.types:
		if t.id == "walker" and t.get("authored_sprites", false):
			auth = true
	check(auth, "saving a frame claims the type's sprites (authored_sprites)")
	ed._close_frame_edit()
	check(not ed.fe_layer.visible, "BACK returns to the monster editor")
	DirAccess.remove_absolute("user://walker.png")
	DirAccess.remove_absolute("user://enemies_test.json")
	print("\nMonster editor smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
