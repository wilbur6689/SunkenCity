extends Node
## Headless checks for the Flora Editor: boot, painting, the growth-chain
## fields, save exports JSON (category flora, zone roof) + PNG, load
## roundtrip, and the roof sprinkle picking up saved flora by weight.
var failures := 0
var checks := 0
func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok:   " if cond else "  FAIL: ") + msg)
	if not cond: failures += 1
func _ready() -> void:
	var ed = load("res://scenes/tools/flora_editor.tscn").instantiate()
	ed.objects_path = "user://flora_test.json"
	ed.sprites_dir = "user://"
	add_child(ed)
	await get_tree().process_frame
	check(ed.image.get_width() == 32 and ed.image.get_height() == 48, "default canvas is 2x3 blocks (32x48)")
	var pm = ed.get_tree().get_first_node_in_group("pause_menu")
	check(pm != null and pm.quit_button == null or pm != null, "pause menu mounted")
	var mid_a: bool = ed.image.get_pixel(16, 10).a > 0.9
	check(mid_a, "plant prefill painted a canopy")
	ed.id_edit.text = "smoke_bush"
	ed.name_edit.text = "Smoke Bush"
	ed.type_option.selected = 1 # bush
	ed.brush = Color8(96, 160, 94)
	ed.tool_mode = "pencil"
	ed._apply(Vector2i(5, 5), false)
	check(ed.image.get_pixel(5, 5).is_equal_approx(Color8(96, 160, 94)), "pencil paints the brush colour")
	ed._apply(Vector2i(5, 5), true)
	check(ed.image.get_pixel(5, 5).a < 0.1, "RMB erases")
	ed.h_spin.value = 5 # taller; painted pixels preserved
	check(ed.image.get_height() == 80 and ed.image.get_pixel(16, 10).a > 0.9, "resize keeps painted content")
	ed.grow_edit.text = "smoke_bush_big"
	ed.grow_chance_spin.value = 0.25
	ed.flora_weight_spin.value = 3
	ed.no_item_check.button_pressed = true
	ed.def.yields = [{"item": "wood", "min": 2, "max": 4}]
	ed._save()
	var lib = JSON.parse_string(FileAccess.get_file_as_string("user://flora_test.json"))
	check(lib.objects.size() == 1 and lib.objects[0].id == "smoke_bush", "flora exported to the library")
	var o = lib.objects[0]
	check(o.category == "flora" and o.zones == ["roof"] and o.room_type == "bush",
		"category flora + roof zone + type exported")
	check(o.grows_into == "smoke_bush_big" and absf(float(o.grow_chance) - 0.25) < 0.01,
		"growth chain exported (grows_into + nightly chance)")
	check(int(o.flora_weight) == 3 and bool(o.get("no_item", false)), "spawn weight + no-item flag exported")
	check(FileAccess.file_exists("user://smoke_bush.png"), "sprite PNG exported")
	ed._save()
	lib = JSON.parse_string(FileAccess.get_file_as_string("user://flora_test.json"))
	check(lib.objects.size() == 1, "re-saving updates instead of duplicating")
	# Clearing the growth id drops the chain fields on save.
	ed.grow_edit.text = ""
	ed._save()
	lib = JSON.parse_string(FileAccess.get_file_as_string("user://flora_test.json"))
	check(not lib.objects[0].has("grows_into") and not lib.objects[0].has("grow_chance"),
		"empty grows-into clears the chain (final stage)")
	# Load roundtrip restores settings + pixels.
	ed.image.fill(Color(0, 0, 0, 0))
	ed.def = ed._default_def()
	ed._refresh_load_list()
	ed._load_selected(1)
	check(ed.def.id == "smoke_bush" and int(ed.flora_weight_spin.value) == 3 \
		and ed.no_item_check.button_pressed, "load restores settings incl. weight + no-item")
	check(ed.image.get_pixel(16, 10).a > 0.9, "load restores the sprite pixels")
	# The generator's pool: shipped flora is picked up by category + weight.
	var pool := CityGen._zone_details("roof", "flora")
	check(pool.has("tree_sapling") and pool.has("roof_bush") and pool.has("roof_grass"),
		"roof sprinkle pool sees shipped flora (trees, bush, grass)")
	var weighted := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var id: String = CityGen._weighted_flora(rng, pool)
		weighted[id] = int(weighted.get(id, 0)) + 1
	check(int(weighted.get("tree_sapling", 0)) > int(weighted.get("tree_mature", 0)),
		"flora_weight biases picks (saplings over mature trees)")
	DirAccess.remove_absolute("user://flora_test.json")
	DirAccess.remove_absolute("user://smoke_bush.png")
	print("\nFlora editor smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
