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
		and int(ed.variants_spin.value) == 7, "walker loads with frames + variants")
	check(ed.flag_checks["bleeds"].button_pressed and not ed.flag_checks["passive"].button_pressed,
		"flags load (bleeds on, passive off)")
	check(ed.band_rows["dry"].on.button_pressed and int(ed.band_rows["dry"]["hp"].value) == 30,
		"dry band row enabled with authored hp 30")
	check(ed.def.drops.size() == 2, "walker's drops table loads")
	check(ed.variant_option.item_count == 7, "preview lists all 7 walker sprite files")
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
	DirAccess.remove_absolute("user://enemies_test.json")
	print("\nMonster editor smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
