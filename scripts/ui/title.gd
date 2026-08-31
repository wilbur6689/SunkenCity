extends Control
## Title screen (CC-09): the world picker <-> character picker flow. Worlds
## and characters save separately (Terraria model) — pick a saved world or a
## fresh seed on the left, a saved character or a new name on the right,
## then dive. Dev runs passing --seed / --shot skip straight into the city.

const CITY_SCENE := "res://scenes/city/city.tscn"

var world_list: ItemList
var char_list: ItemList
var seed_spin: SpinBox
var name_edit: LineEdit

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed=") or a.begins_with("--shot="):
			get_tree().change_scene_to_file.call_deferred(CITY_SCENE)
			return
	_build_ui()
	for a in OS.get_cmdline_user_args(): # dev aid: --titleshot=path
		if a.begins_with("--titleshot="):
			await get_tree().create_timer(0.5).timeout
			get_viewport().get_texture().get_image().save_png(a.substr(12))
			get_tree().quit()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "SUNKEN CITY"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.55, 0.85, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 24
	add_child(title)

	var sub := Label.new()
	sub.text = "The city drowned to keep the virus down. Dive."
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color(0.5, 0.6, 0.65))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 58
	add_child(sub)

	world_list = _picker_panel(96, "WORLD")
	char_list = _picker_panel(344, "CHARACTER")

	# New-world seed row under the world panel.
	var seed_label := Label.new()
	seed_label.text = "Seed"
	seed_label.add_theme_font_size_override("font_size", 10)
	seed_label.position = Vector2(96, 262)
	add_child(seed_label)
	seed_spin = SpinBox.new()
	seed_spin.min_value = 1
	seed_spin.max_value = 999999
	seed_spin.value = randi_range(1, 999999)
	seed_spin.position = Vector2(126, 258)
	seed_spin.custom_minimum_size = Vector2(110, 0)
	add_child(seed_spin)
	var rand_btn := Button.new()
	rand_btn.text = "Reroll"
	rand_btn.position = Vector2(242, 258)
	rand_btn.pressed.connect(func(): seed_spin.value = randi_range(1, 999999))
	add_child(rand_btn)

	# New-character name row under the character panel.
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "new character name"
	name_edit.position = Vector2(344, 258)
	name_edit.custom_minimum_size = Vector2(200, 0)
	add_child(name_edit)

	var play := Button.new()
	play.text = "DIVE"
	play.add_theme_font_size_override("font_size", 16)
	play.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	play.position = Vector2(-40, -46)
	play.custom_minimum_size = Vector2(80, 30)
	play.pressed.connect(_play)
	add_child(play)

	_refresh_lists()

func _picker_panel(x: float, label_text: String) -> ItemList:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.9))
	label.position = Vector2(x, 86)
	add_child(label)
	var list := ItemList.new()
	list.position = Vector2(x, 104)
	list.custom_minimum_size = Vector2(200, 148)
	list.size = Vector2(200, 148)
	add_child(list)
	return list

func _refresh_lists() -> void:
	world_list.clear()
	world_list.add_item("+ New world")
	for w in SaveGame.world_names():
		world_list.add_item(w)
	world_list.select(mini(1, world_list.item_count - 1))
	char_list.clear()
	char_list.add_item("+ New character")
	for c in SaveGame.character_names():
		char_list.add_item(c)
	char_list.select(mini(1, char_list.item_count - 1))

func _play() -> void:
	var wi := world_list.get_selected_items()
	if wi.size() > 0 and wi[0] > 0:
		SaveGame.pending_world = world_list.get_item_text(wi[0])
	else:
		SaveGame.pending_seed = int(seed_spin.value)
	var ci := char_list.get_selected_items()
	if ci.size() > 0 and ci[0] > 0:
		SaveGame.pending_character = char_list.get_item_text(ci[0])
	elif name_edit.text.strip_edges() != "":
		SaveGame.pending_character = name_edit.text.strip_edges()
	get_tree().change_scene_to_file(CITY_SCENE)
