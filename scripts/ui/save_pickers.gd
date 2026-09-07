class_name SavePickers
extends RefCounted
## The world / character picker columns shared by the title screen and the
## Multiplayer screen (2026-09-05): a bordered panel with a header, the list
## ("+ New ..." first, saved rows after, old-format rows greyed but selectable
## so Delete can reach them), a two-click Delete, and the new-world seed row /
## new-character name row. Layout coordinates are the title's 640x360 design
## frame; callers pass the column x. Any screen that wants only one column
## builds only that one.

const FONT := 10 # compact control font (user request: the menu ran large)
const STALE_COLOR := Color(0.5, 0.45, 0.4)

signal message(text: String) # hint-line updates ("Removed 2 old-format saves.")
signal selection_changed

var frame: Control
var world_list: ItemList
var char_list: ItemList
var seed_spin: SpinBox
var name_edit: LineEdit
var world_name_edit: LineEdit # optional display name for a new world (2026-09-06); editable only on "+ New world"
var world_del: Button
var char_del: Button
var clear_old: Button # deletes every old-format world + character (shown only when some exist)
var _confirm_gen := 0 # invalidates pending delete confirms

## The WORLD column: picker, Delete, and the seed row for a new world.
func build_world(p_frame: Control, x: float) -> void:
	frame = p_frame
	# The world list is a row shorter than the character list: the name field
	# for a new world sits under it (user request 2026-09-06).
	world_list = picker_panel(frame, x, "WORLD", 70.0, 106.0)
	world_del = _delete_button(x + 170 - 52, "world")
	world_list.item_selected.connect(func(i):
		world_del.disabled = i == 0
		world_name_edit.editable = i == 0
		reset_confirms()
		selection_changed.emit())
	world_name_edit = LineEdit.new()
	world_name_edit.placeholder_text = "new world name (optional)"
	world_name_edit.max_length = SaveGame.WORLD_NAME_MAX
	world_name_edit.add_theme_font_size_override("font_size", FONT)
	UITheme.style_input(world_name_edit)
	world_name_edit.position = Vector2(x, 202)
	world_name_edit.custom_minimum_size = Vector2(170, 0)
	world_name_edit.tooltip_text = "Shown in the list and on the LAN. Blank = world_<seed>."
	frame.add_child(world_name_edit)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	seed_label.add_theme_font_size_override("font_size", FONT)
	seed_label.position = Vector2(x, 252)
	frame.add_child(seed_label)
	seed_spin = SpinBox.new()
	seed_spin.min_value = 1
	seed_spin.max_value = 999999
	seed_spin.value = randi_range(1, 999999)
	seed_spin.position = Vector2(x + 28, 248)
	seed_spin.custom_minimum_size = Vector2(84, 0)
	seed_spin.get_line_edit().add_theme_font_size_override("font_size", FONT)
	UITheme.style_input(seed_spin.get_line_edit())
	frame.add_child(seed_spin)
	var rand_btn := Button.new()
	rand_btn.text = "Reroll"
	UITheme.style_button(rand_btn)
	rand_btn.add_theme_font_size_override("font_size", FONT)
	rand_btn.position = Vector2(x + 118, 248)
	rand_btn.custom_minimum_size = Vector2(44, 18)
	rand_btn.pressed.connect(func(): seed_spin.value = randi_range(1, 999999))
	frame.add_child(rand_btn)

## The CHARACTER column: picker, Delete, and the name row for a new character.
func build_char(p_frame: Control, x: float) -> void:
	frame = p_frame
	char_list = picker_panel(frame, x, "CHARACTER")
	char_del = _delete_button(x + 170 - 52, "char")
	char_list.item_selected.connect(func(i): char_del.disabled = i == 0; reset_confirms(); selection_changed.emit())
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "new character name"
	name_edit.add_theme_font_size_override("font_size", FONT)
	UITheme.style_input(name_edit)
	name_edit.position = Vector2(x, 248)
	name_edit.custom_minimum_size = Vector2(170, 0)
	frame.add_child(name_edit)

## The "Clear old saves (N)" button (visible only while old-format files exist).
func build_clear_old(p_frame: Control, pos: Vector2) -> void:
	frame = p_frame
	clear_old = Button.new()
	clear_old.text = "Clear old saves"
	UITheme.style_button(clear_old)
	clear_old.add_theme_font_size_override("font_size", FONT - 1)
	clear_old.position = pos
	clear_old.custom_minimum_size = Vector2(96, 16)
	clear_old.tooltip_text = "Delete every world and character saved in a format this build no longer loads."
	clear_old.pressed.connect(clear_old_pressed)
	frame.add_child(clear_old)

## A bordered column panel: header, list. Also used bare (the JOIN page's host list).
static func picker_panel(p_frame: Control, x: float, label_text: String, y: float = 70.0, list_h: float = 124.0) -> ItemList:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.flat_panel())
	panel.position = Vector2(x - 8, y)
	panel.custom_minimum_size = Vector2(186, 206)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_frame.add_child(panel)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", FONT)
	label.add_theme_color_override("font_color", Color(0.56, 0.75, 0.81))
	label.position = Vector2(x, y + 6)
	p_frame.add_child(label)
	var list := ItemList.new()
	list.position = Vector2(x, y + 22)
	list.custom_minimum_size = Vector2(170, list_h)
	list.size = Vector2(170, list_h)
	list.add_theme_font_size_override("font_size", FONT)
	UITheme.style_list(list)
	p_frame.add_child(list)
	return list

func _delete_button(x: float, which: String) -> Button:
	var b := Button.new()
	b.text = "Delete"
	UITheme.style_button(b)
	b.position = Vector2(x, 224)
	b.custom_minimum_size = Vector2(52, 16)
	b.pressed.connect(delete_pressed.bind(which))
	frame.add_child(b)
	return b

## Delete a saved world/character: first click arms ("Really?"), a second
## click within a few seconds deletes the file for good.
func delete_pressed(which: String) -> void:
	var list := world_list if which == "world" else char_list
	var btn := world_del if which == "world" else char_del
	if list == null:
		return
	var sel := list.get_selected_items()
	if sel.is_empty() or sel[0] == 0:
		return # the "+ New" rows aren't deletable
	var save_name: String = list.get_item_metadata(sel[0]).name # the raw file name (old-format rows carry a suffix)
	if btn.text != "Really?":
		_arm(btn)
		return
	if which == "world":
		SaveGame.delete_world(save_name)
	else:
		SaveGame.delete_character(save_name)
	reset_confirms()
	refresh()

## Delete EVERY old-format world and character (two-click confirm, like Delete).
func clear_old_pressed() -> void:
	if clear_old.text != "Really?":
		_arm(clear_old)
		return
	var n := SaveGame.delete_stale_saves()
	reset_confirms()
	refresh()
	message.emit("Removed %d old-format save%s." % [n, "" if n == 1 else "s"])

func _arm(btn: Button) -> void:
	btn.text = "Really?"
	btn.modulate = Color(1.0, 0.55, 0.5)
	_confirm_gen += 1
	var gen := _confirm_gen
	frame.get_tree().create_timer(3.0).timeout.connect(func():
		if _confirm_gen == gen:
			reset_confirms())

func reset_confirms() -> void:
	_confirm_gen += 1
	for b: Button in [world_del, char_del]:
		if b != null:
			b.text = "Delete"
			b.modulate = Color.WHITE
	if clear_old != null:
		var st := SaveGame.stale_saves()
		clear_old.text = "Clear old saves (%d)" % (st.worlds.size() + st.chars.size())
		clear_old.modulate = Color.WHITE

## A saved row: greyed "(old format)" when this build refuses the file. Such
## rows stay selectable so Delete can reach them; DIVE / HOST refuse them.
## `save_name` is the file key (the metadata `name`); `display` is the row
## text (a world's stored display name; defaults to the key).
static func add_save_row(list: ItemList, save_name: String, stale: bool, display: String = "") -> void:
	var shown := display if display != "" else save_name
	list.add_item(shown + "  (old format)" if stale else shown)
	var idx := list.item_count - 1
	list.set_item_metadata(idx, {"name": save_name, "stale": stale, "display": shown})
	if shown != save_name:
		list.set_item_tooltip(idx, "file: " + save_name)
	if stale:
		list.set_item_custom_fg_color(idx, STALE_COLOR)

static func row_stale(list: ItemList, idx: int) -> bool:
	var md = list.get_item_metadata(idx)
	return md is Dictionary and bool(md.stale)

## The selected world / character is an old-format save (not loadable).
func stale_selected() -> bool:
	for list: ItemList in [world_list, char_list]:
		if list == null:
			continue
		var sel := list.get_selected_items()
		if sel.size() > 0 and sel[0] > 0 and row_stale(list, sel[0]):
			return true
	return false

func refresh() -> void:
	if world_list != null:
		world_list.clear()
		world_list.add_item("+ New world")
		for w in SaveGame.world_names():
			var data := SaveGame.read_world(w) # {} = older save format (e.g. pre-8 px cells): listed, not loadable
			add_save_row(world_list, w, data.is_empty(), SaveGame.display_name_of(data, w))
		var first_world := 0 # newest loadable world, else "+ New world" (old-format rows are never preselected)
		for i in range(1, world_list.item_count):
			if not row_stale(world_list, i):
				first_world = i
				break
		world_list.select(first_world)
		world_del.disabled = first_world == 0
		if world_name_edit != null:
			world_name_edit.editable = first_world == 0
	if char_list != null:
		char_list.clear()
		char_list.add_item("+ New character")
		for c in SaveGame.character_names():
			add_save_row(char_list, c, SaveGame.character_is_stale(c))
		var first_char := 0
		for i in range(1, char_list.item_count):
			if not row_stale(char_list, i):
				first_char = i
				break
		char_list.select(first_char)
		char_del.disabled = first_char == 0
	if clear_old != null:
		var st := SaveGame.stale_saves()
		var n_old: int = st.worlds.size() + st.chars.size()
		clear_old.visible = n_old > 0
		if n_old > 0:
			clear_old.text = "Clear old saves (%d)" % n_old
	selection_changed.emit()

## The picked saved world name, or "" for "+ New world".
func selected_world() -> String:
	if world_list == null:
		return ""
	var wi := world_list.get_selected_items()
	if wi.size() > 0 and wi[0] > 0:
		return world_list.get_item_metadata(wi[0]).name
	return ""

func seed_value() -> int:
	return int(seed_spin.value) if seed_spin != null else 1

## The display name typed for a new world ("" = default `world_<seed>`).
func new_world_name() -> String:
	return SaveGame.clean_world_name(world_name_edit.text) if world_name_edit != null else ""

## The picked saved character, else the typed name (trimmed), else "".
func selected_character() -> String:
	if char_list == null:
		return ""
	var ci := char_list.get_selected_items()
	if ci.size() > 0 and ci[0] > 0:
		return char_list.get_item_metadata(ci[0]).name
	return name_edit.text.strip_edges() if name_edit != null else ""

## Turn the pickers' selection into SaveGame's pending handoff.
func apply_selection() -> void:
	var w := selected_world()
	SaveGame.pending_world_name = ""
	if w != "":
		SaveGame.pending_world = w
	elif world_list != null:
		SaveGame.pending_seed = seed_value()
		SaveGame.pending_world_name = new_world_name()
	var c := selected_character()
	if c != "":
		SaveGame.pending_character = c
