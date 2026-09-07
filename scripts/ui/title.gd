extends Control
## Title screen (CC-09): the world picker <-> character picker flow. Worlds
## and characters save separately (Terraria model) — pick a saved world or a
## fresh seed on the left, a saved character or a new name on the right,
## then dive. Saved rows can be deleted (two-click confirm). Old-format saves
## (a version this build refuses) are listed greyed: they can't be dived but
## CAN be selected and deleted, and "Clear old saves" removes them all
## (user request 2026-09-05). The picker columns themselves live in
## SavePickers (shared with the Multiplayer screen, 2026-09-05). Dev runs
## passing --seed / --shot skip straight into the city; --host / --join
## (docs/technical/MultiplayerImpl.md §8) start a LAN session without the menu.

const CITY_SCENE := "res://scenes/city/city.tscn"
const MULTIPLAYER_SCENE := "res://scenes/ui/multiplayer_menu.tscn"
const FONT := SavePickers.FONT
const HINT_TEXT := "Pick or create on both sides, then dive. Progress saves when you leave (Esc) — F5 saves any time."
const STALE_COLOR := SavePickers.STALE_COLOR

var frame: Control # fixed 640x360 design frame, centred on wide screens
var pickers := SavePickers.new()
var world_list: ItemList
var char_list: ItemList
var seed_spin: SpinBox
var name_edit: LineEdit
var world_del: Button
var char_del: Button
var clear_old: Button # deletes every old-format world + character (shown only when some exist)
var hint: Label

static var _dev_args_used := false # --host/--join fire once per process, not on every return to the title

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if SaveGame.pending_notice != "": # dev probe (tools/lan_smoke.py --host-closes): report the reason and exit
		for a in args:
			if a.begins_with("--net-probe="):
				print("NETPROBE disconnected: " + SaveGame.pending_notice)
				get_tree().quit()
				return
	# Dev aids: --host[=port] / --join=ip[:port] (+ --character= --world= --seed=)
	# start a LAN session straight from the command line (MultiplayerImpl §8).
	if not _dev_args_used:
		for a in args:
			if a == "--host" or a.begins_with("--host="):
				_dev_args_used = true
				_dev_host(args)
				return
			if a.begins_with("--join="):
				_dev_args_used = true
				_dev_join(args)
				return
	for a in args:
		if a.begins_with("--seed=") or a.begins_with("--shot="):
			get_tree().change_scene_to_file.call_deferred(CITY_SCENE)
			return
	_build_ui()
	if SaveGame.pending_notice != "": # e.g. "Disconnected: host closed the world" (LAN Step 7)
		hint.text = SaveGame.pending_notice
		SaveGame.pending_notice = ""
	for a in args: # dev aid: --titleshot=path
		if a.begins_with("--titleshot="):
			await get_tree().create_timer(0.5).timeout
			get_viewport().get_texture().get_image().save_png(a.substr(12))
			get_tree().quit()

static func _arg(args: PackedStringArray, key: String, default_value: String) -> String:
	for a in args:
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return default_value

func _dev_host(args: PackedStringArray) -> void:
	var port := Constants.LAN_PORT
	for a in args:
		if a.begins_with("--host=") and a.substr(7).is_valid_int():
			port = int(a.substr(7))
	var world := _arg(args, "--world", "")
	var seed_value := int(_arg(args, "--seed", "0"))
	var character := _arg(args, "--character", "diver")
	var cap := int(_arg(args, "--cap", str(Constants.NET_MAX_PLAYERS)))
	var display := _arg(args, "--name", "") # a display name for a NEW world (2026-09-06)
	var err := Net.start_hosting(world, seed_value, character, port, cap, display)
	if err != OK:
		push_error("--host: could not start hosting (%s)" % error_string(err))
		get_tree().quit(2)

func _dev_join(args: PackedStringArray) -> void:
	var target := _arg(args, "--join", "127.0.0.1")
	var character := _arg(args, "--character", "diver")
	# The Multiplayer screen runs the join flow and shows/prints its status.
	Net.auto_join = {"target": target, "character": character}
	get_tree().change_scene_to_file.call_deferred(MULTIPLAYER_SCENE)

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

	pickers.build_world(frame, 120)
	pickers.build_char(frame, 350)
	pickers.build_clear_old(frame, Vector2(120, 224))
	pickers.message.connect(func(t: String): hint.text = t)
	world_list = pickers.world_list
	char_list = pickers.char_list
	seed_spin = pickers.seed_spin
	name_edit = pickers.name_edit
	world_del = pickers.world_del
	char_del = pickers.char_del
	clear_old = pickers.clear_old

	hint = Label.new()
	hint.text = HINT_TEXT
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
	play.position = Vector2(-42, -86)
	play.custom_minimum_size = Vector2(84, 28)
	play.pressed.connect(_play)
	frame.add_child(play)

	# MULTIPLAYER between DIVE and QUIT (2026-09-05): host a world on the LAN
	# or join one — docs/technical/Multiplayer.md §8.
	var mp := Button.new()
	mp.text = "MULTIPLAYER"
	UITheme.style_button(mp)
	mp.add_theme_font_size_override("font_size", 10)
	mp.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	mp.position = Vector2(-42, -54)
	mp.custom_minimum_size = Vector2(84, 18)
	mp.pressed.connect(func(): get_tree().change_scene_to_file(MULTIPLAYER_SCENE))
	frame.add_child(mp)

	# QUIT under DIVE (user request 2026-09-01): out of the game entirely.
	var quit := Button.new()
	quit.text = "QUIT"
	UITheme.style_button(quit)
	quit.add_theme_font_size_override("font_size", 10)
	quit.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	quit.position = Vector2(-42, -32)
	quit.custom_minimum_size = Vector2(84, 18)
	quit.pressed.connect(func(): get_tree().quit())
	frame.add_child(quit)

	_refresh_lists()

# Thin wrappers over SavePickers (the title smoke drives these directly).
func _delete_pressed(which: String) -> void:
	pickers.delete_pressed(which)

func _clear_old_pressed() -> void:
	pickers.clear_old_pressed()

func _reset_confirms() -> void:
	pickers.reset_confirms()

func _stale_selected() -> bool:
	return pickers.stale_selected()

func _refresh_lists() -> void:
	pickers.refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit() # Esc at the title quits the game

## Turn the pickers' selection into SaveGame's pending handoff.
func _apply_selection() -> void:
	pickers.apply_selection()

func _play() -> void:
	if _stale_selected():
		hint.text = "That save is an old format this build can't load - delete it (or Clear old saves) and pick another."
		return
	hint.text = HINT_TEXT
	_apply_selection()
	get_tree().change_scene_to_file(CITY_SCENE)
