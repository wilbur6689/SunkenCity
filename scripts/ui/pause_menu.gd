extends CanvasLayer
## Esc menu: a small centred panel over a dimmed world with the sound
## sliders (Music / SFX / Ambient, persisted via Audio.save_settings) and
## the leave-the-run action. The sim keeps running behind it (LAN-readiness
## rule: nothing here assumes a pausable world). Esc closes it again; while
## it is open the character menu stays shut and the player ignores input.

const BUSES := ["Music", "SFX", "Ambient"]

var open: bool = false
var root: Control
var quit_button: Button
var main_box: VBoxContainer
var controls_box: VBoxContainer
var _sliders: Dictionary = {}
var _pct_labels: Dictionary = {}

## The controls list: [label, actions-array (keys read live from InputMap,
## joined with " / ") or a literal string]. Curated so mouse semantics and
## fixed function keys (not InputMap actions) can be described too.
const CONTROL_ROWS := [
	["Move", ["move_left", "move_right"]],
	["Climb / swim", ["move_up", "move_down"]],
	["Jump", ["jump"]],
	["Sprint", ["sprint"]],
	["Crouch / crawl", ["crouch"]],
	["Use / place / hit", "LMB · click interacts, hold picks up"],
	["Scrap / back wall", "RMB (hold)"],
	["Interact (legacy)", ["interact"]],
	["Inventory", ["inventory"]],
	["Map", ["map"]],
	["Bare hands", ["drop"]],
	["Hotbar", "1–0 · wheel cycles"],
	["Zoom", "Ctrl + wheel"],
	["Save / load", "F5 / F9"],
	["Debug overlay", "F3"],
	["Menu", "Esc"],
]

func _ready() -> void:
	add_to_group("pause_menu")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	layer = 6 # above the character menu (5)

	# Dimmer: also soaks up clicks so the world cannot be poked through it.
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.05, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var centering := CenterContainer.new()
	centering.set_anchors_preset(Control.PRESET_FULL_RECT)
	centering.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(centering)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.flat_panel())
	panel.custom_minimum_size = Vector2(180, 0)
	centering.add_child(panel)
	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 5)
	panel.add_child(main_box)

	var title := UITheme.label("MENU", 10, Color(0.56, 0.75, 0.81))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_box.add_child(title)

	var resume := Button.new()
	resume.text = "RESUME"
	UITheme.style_button(resume)
	resume.custom_minimum_size = Vector2(0, 16)
	resume.pressed.connect(close)
	main_box.add_child(resume)

	main_box.add_child(UITheme.label("SOUND", 8, Color(0.56, 0.75, 0.81)))
	for bus_name in BUSES:
		main_box.add_child(_volume_row(bus_name))

	var controls_btn := Button.new()
	controls_btn.text = "CONTROLS"
	UITheme.style_button(controls_btn)
	controls_btn.custom_minimum_size = Vector2(0, 16)
	controls_btn.pressed.connect(_show_controls.bind(true))
	main_box.add_child(controls_btn)

	quit_button = Button.new()
	quit_button.text = "SAVE & QUIT"
	UITheme.style_button(quit_button)
	quit_button.custom_minimum_size = Vector2(0, 16)
	quit_button.pressed.connect(_quit)
	main_box.add_child(quit_button)

	var hint := UITheme.label("F5 saves any time", 8, Color(0.55, 0.6, 0.68))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_box.add_child(hint)

	# Controls page (user request): every binding, read live from the
	# InputMap so rebinds show correctly; mouse/function keys described.
	controls_box = VBoxContainer.new()
	controls_box.add_theme_constant_override("separation", 2)
	controls_box.visible = false
	panel.add_child(controls_box)
	var ct := UITheme.label("CONTROLS", 10, Color(0.56, 0.75, 0.81))
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_box.add_child(ct)
	for row in CONTROL_ROWS:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var name_l := UITheme.label(String(row[0]), 8, Color(0.7, 0.78, 0.85))
		name_l.custom_minimum_size = Vector2(72, 0)
		hb.add_child(name_l)
		var keys: String = row[1] if row[1] is String else " / ".join((row[1] as Array).map(_key_of))
		hb.add_child(UITheme.label(keys, 8))
		controls_box.add_child(hb)
	var back := Button.new()
	back.text = "BACK"
	UITheme.style_button(back)
	back.custom_minimum_size = Vector2(0, 16)
	back.pressed.connect(_show_controls.bind(false))
	controls_box.add_child(back)

## First bound key/button of an InputMap action, cleaned for display.
func _key_of(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		return ev.as_text().replace(" - Physical", "").replace(" (Physical)", "")
	return "—"

func _show_controls(show_it: bool) -> void:
	controls_box.visible = show_it
	main_box.visible = not show_it

## "Music  [====-----]  80%" — slider drives the bus live.
func _volume_row(bus_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var name_label := UITheme.label(bus_name if bus_name != "Ambient" else "Ambient", 8)
	name_label.custom_minimum_size = Vector2(38, 0)
	row.add_child(name_label)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.custom_minimum_size = Vector2(78, 10)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.style_slider(s)
	s.value_changed.connect(func(val: float):
		Audio.set_volume(bus_name, val / 100.0)
		_pct_labels[bus_name].text = "%d%%" % int(val))
	row.add_child(s)
	_sliders[bus_name] = s
	var pct := UITheme.label("100%", 8, Color(0.7, 0.78, 0.85))
	pct.custom_minimum_size = Vector2(24, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)
	_pct_labels[bus_name] = pct
	return row

func _process(_delta: float) -> void:
	if not Input.is_action_just_pressed("ui_cancel"):
		return
	if open:
		if controls_box.visible: # Esc from the controls page goes back first
			_show_controls(false)
		else:
			close()
		return
	# The character menu / map view own Esc while open (each closes itself
	# and marks the frame so this menu does not pop on the same keypress).
	var inv = get_tree().get_first_node_in_group("inventory_ui")
	if inv != null and (inv.open or inv.esc_consumed_frame == Engine.get_process_frames()):
		return
	var mv = get_tree().get_first_node_in_group("map_view")
	if mv != null and (mv.open or mv.esc_consumed_frame == Engine.get_process_frames()):
		return
	open_menu()

func open_menu() -> void:
	open = true
	root.visible = true
	_show_controls(false)
	for bus_name in BUSES:
		_sliders[bus_name].set_value_no_signal(Audio.volume(bus_name) * 100.0)
		_pct_labels[bus_name].text = "%d%%" % int(Audio.volume(bus_name) * 100.0)
	var scene := get_tree().current_scene
	quit_button.text = "SAVE & QUIT" if scene != null and scene.has_method("save_and_exit_to_title") else "QUIT"
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		player.ui_blocks_mouse = true

func close() -> void:
	open = false
	root.visible = false
	Audio.save_settings()
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		player.ui_blocks_mouse = false

func _quit() -> void:
	Audio.save_settings()
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("save_and_exit_to_title"):
		scene.save_and_exit_to_title()
	else:
		get_tree().quit()
