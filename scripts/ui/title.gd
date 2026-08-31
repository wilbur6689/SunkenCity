extends Control
## Title screen (CC-09): the world picker <-> character picker flow. Worlds
## and characters save separately (Terraria model) — pick a saved world or a
## fresh seed on the left, a saved character or a new name on the right,
## then dive. Saved rows can be deleted (two-click confirm). Dev runs
## passing --seed / --shot skip straight into the city.

const CITY_SCENE := "res://scenes/city/city.tscn"
const FONT := 10 # compact control font (user request: the menu ran large)

var frame: Control # fixed 640x360 design frame, centred on wide screens
var world_list: ItemList
var char_list: ItemList
var seed_spin: SpinBox
var name_edit: LineEdit
var world_del: Button
var char_del: Button
var _confirm_gen := 0 # invalidates pending delete confirms

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
	# The underwater rock art behind everything (same plate the character
	# menu uses), dimmed so the panels stay readable.
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/backgrounds/menu_backdrop.png")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.24, 0.3, 0.36)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# Wide screens (expand stretch) widen the viewport past 640x360; the
	# layout keeps its design coordinates inside this centred frame.
	frame = Control.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -320
	frame.offset_top = -180
	frame.offset_right = 320
	frame.offset_bottom = 180
	add_child(frame)

	var title := Label.new()
	title.text = "SUNKEN CITY"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.55, 0.85, 0.95))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.05, 0.1, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 26
	frame.add_child(title)

	var sub := Label.new()
	sub.text = "The city drowned to keep the virus down. Dive."
	sub.add_theme_font_size_override("font_size", 9)
	sub.add_theme_color_override("font_color", Color(0.5, 0.6, 0.65))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 56
	frame.add_child(sub)

	world_list = _picker_panel(120, "WORLD")
	char_list = _picker_panel(350, "CHARACTER")
	world_del = _delete_button(120 + 170 - 52, "world")
	char_del = _delete_button(350 + 170 - 52, "char")
	world_list.item_selected.connect(func(i): world_del.disabled = i == 0; _reset_confirms())
	char_list.item_selected.connect(func(i): char_del.disabled = i == 0; _reset_confirms())

	# New-world seed row under the world panel.
	var seed_label := Label.new()
	seed_label.text = "Seed"
	seed_label.add_theme_font_size_override("font_size", FONT)
	seed_label.position = Vector2(120, 252)
	frame.add_child(seed_label)
	seed_spin = SpinBox.new()
	seed_spin.min_value = 1
	seed_spin.max_value = 999999
	seed_spin.value = randi_range(1, 999999)
	seed_spin.position = Vector2(148, 248)
	seed_spin.custom_minimum_size = Vector2(84, 0)
	seed_spin.get_line_edit().add_theme_font_size_override("font_size", FONT)
	UITheme.style_input(seed_spin.get_line_edit())
	frame.add_child(seed_spin)
	var rand_btn := Button.new()
	rand_btn.text = "Reroll"
	UITheme.style_button(rand_btn)
	rand_btn.add_theme_font_size_override("font_size", FONT)
	rand_btn.position = Vector2(238, 248)
	rand_btn.custom_minimum_size = Vector2(44, 18)
	rand_btn.pressed.connect(func(): seed_spin.value = randi_range(1, 999999))
	frame.add_child(rand_btn)

	# New-character name row under the character panel.
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "new character name"
	name_edit.add_theme_font_size_override("font_size", FONT)
	UITheme.style_input(name_edit)
	name_edit.position = Vector2(350, 248)
	name_edit.custom_minimum_size = Vector2(170, 0)
	frame.add_child(name_edit)

	var hint := Label.new()
	hint.text = "Pick or create on both sides, then dive. Progress saves when you leave (Esc) — F5 saves any time."
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.45, 0.55, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -14
	frame.add_child(hint)

	var play := Button.new()
	play.text = "DIVE"
	UITheme.style_button(play)
	play.add_theme_font_size_override("font_size", 14)
	play.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	play.position = Vector2(-42, -48)
	play.custom_minimum_size = Vector2(84, 28)
	play.pressed.connect(_play)
	frame.add_child(play)

	_refresh_lists()

func _picker_panel(x: float, label_text: String) -> ItemList:
	# A bordered column panel groups each side: header, list, delete, and
	# the new-world/new-character row all read as one unit.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.flat_panel())
	panel.position = Vector2(x - 8, 70)
	panel.custom_minimum_size = Vector2(186, 206)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(panel)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", FONT)
	label.add_theme_color_override("font_color", Color(0.56, 0.75, 0.81))
	label.position = Vector2(x, 76)
	frame.add_child(label)
	var list := ItemList.new()
	list.position = Vector2(x, 92)
	list.custom_minimum_size = Vector2(170, 124)
	list.size = Vector2(170, 124)
	list.add_theme_font_size_override("font_size", FONT)
	UITheme.style_list(list)
	frame.add_child(list)
	return list

func _delete_button(x: float, which: String) -> Button:
	var b := Button.new()
	b.text = "Delete"
	UITheme.style_button(b)
	b.position = Vector2(x, 224)
	b.custom_minimum_size = Vector2(52, 16)
	b.pressed.connect(_delete_pressed.bind(which))
	frame.add_child(b)
	return b

## Delete a saved world/character: first click arms ("Really?"), a second
## click within a few seconds deletes the file for good.
func _delete_pressed(which: String) -> void:
	var list := world_list if which == "world" else char_list
	var btn := world_del if which == "world" else char_del
	var sel := list.get_selected_items()
	if sel.is_empty() or sel[0] == 0:
		return # the "+ New" rows aren't deletable
	var save_name := list.get_item_text(sel[0])
	if btn.text != "Really?":
		btn.text = "Really?"
		btn.modulate = Color(1.0, 0.55, 0.5)
		_confirm_gen += 1
		var gen := _confirm_gen
		get_tree().create_timer(3.0).timeout.connect(func():
			if _confirm_gen == gen:
				_reset_confirms())
		return
	if which == "world":
		SaveGame.delete_world(save_name)
	else:
		SaveGame.delete_character(save_name)
	_reset_confirms()
	_refresh_lists()

func _reset_confirms() -> void:
	_confirm_gen += 1
	for b: Button in [world_del, char_del]:
		if b != null:
			b.text = "Delete"
			b.modulate = Color.WHITE

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
	world_del.disabled = world_list.get_selected_items()[0] == 0
	char_del.disabled = char_list.get_selected_items()[0] == 0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit() # Esc at the title quits the game

## Turn the pickers' selection into SaveGame's pending handoff.
func _apply_selection() -> void:
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

func _play() -> void:
	_apply_selection()
	get_tree().change_scene_to_file(CITY_SCENE)
