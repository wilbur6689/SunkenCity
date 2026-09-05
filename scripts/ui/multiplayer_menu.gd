extends Control
## The Multiplayer screen (2026-09-05, docs/technical/Multiplayer.md §8):
## two pages in the title's picker style. HOST: world picker (saved / new
## seed), character picker, port, player cap, HOST ON LAN — boots the city
## exactly like DIVE and starts the beacon. JOIN: the live LAN host list
## (from beacons), an ip:port field for hosts the broadcast can't reach, a
## character picker, JOIN, and a status line (connecting -> handshake ->
## downloading world N % -> in game, refusals in plain words). BACK / Esc
## return to the title. `Net.auto_join` (set by the --join dev arg) runs the
## join flow on open without any clicks.

const TITLE_SCENE := "res://scenes/ui/title.tscn"
const FONT := SavePickers.FONT
const HOST_HINT := "Pick a world and a character, then host. Others on your network join from the JOIN page."
const JOIN_HINT := "Hosts on your network appear as they broadcast. Type ip:port for one that doesn't."

var frame: Control
var page: String = "host"
var host_page: Control
var join_page: Control
var host_tab: Button
var join_tab: Button
var hint: Label
var status: Label # join progress line

# HOST page
var host_pickers := SavePickers.new()
var port_edit: LineEdit
var cap_spin: SpinBox
var host_btn: Button

# JOIN page
var join_pickers := SavePickers.new()
var host_list: ItemList
var addr_edit: LineEdit
var join_btn: Button
var browser: LanBrowser
var _joining := false

func _ready() -> void:
	_build_ui()
	browser = LanBrowser.new()
	add_child(browser)
	browser.changed.connect(_refresh_hosts)
	if browser.start() != OK:
		_set_status("LAN browsing unavailable: " + browser.last_error)
	Net.status.connect(_set_status)
	Net.join_failed.connect(_on_join_failed)
	Net.joined.connect(func(_id): _set_status("accepted - downloading world"))
	Net.snapshot_progress.connect(func(f: float): _set_status("downloading world %d %%" % int(round(f * 100.0))))
	Net.snapshot_ready.connect(func(_d): _set_status("in game"))
	Net.disconnected.connect(func(r: String): _joining = false; _set_status(r); _update_buttons())
	if not Net.auto_join.is_empty():
		var aj: Dictionary = Net.auto_join
		Net.auto_join = {}
		_show_page("join")
		addr_edit.text = String(aj.get("target", ""))
		join_pickers.name_edit.text = String(aj.get("character", ""))
		_select_character(join_pickers, String(aj.get("character", "")))
		_join()

func _exit_tree() -> void:
	if browser != null:
		browser.stop()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/backgrounds/menu_backdrop.png")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.24, 0.3, 0.36)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	frame = Control.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -320
	frame.offset_top = -180
	frame.offset_right = 320
	frame.offset_bottom = 180
	add_child(frame)

	var title := Label.new()
	title.text = "MULTIPLAYER"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.55, 0.85, 0.95))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.05, 0.1, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 18
	frame.add_child(title)

	# Page tabs under the title.
	host_tab = _tab_button("HOST", Vector2(232, 46), "host")
	join_tab = _tab_button("JOIN", Vector2(322, 46), "join")

	host_page = Control.new()
	host_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	host_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(host_page)
	join_page = Control.new()
	join_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	join_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(join_page)
	_build_host_page()
	_build_join_page()

	hint = Label.new()
	hint.text = HOST_HINT
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.45, 0.55, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -14
	frame.add_child(hint)

	var back := Button.new()
	back.text = "BACK"
	UITheme.style_button(back)
	back.add_theme_font_size_override("font_size", 10)
	back.position = Vector2(20, 322)
	back.custom_minimum_size = Vector2(60, 18)
	back.pressed.connect(_back)
	frame.add_child(back)

	_show_page("host")

func _tab_button(text: String, pos: Vector2, which: String) -> Button:
	var b := Button.new()
	b.text = text
	UITheme.style_button(b)
	b.add_theme_font_size_override("font_size", 11)
	b.position = pos
	b.custom_minimum_size = Vector2(84, 18)
	b.pressed.connect(_show_page.bind(which))
	frame.add_child(b)
	return b

func _build_host_page() -> void:
	host_pickers.build_world(host_page, 120)
	host_pickers.build_char(host_page, 350)
	host_pickers.build_clear_old(host_page, Vector2(120, 224))
	host_pickers.message.connect(func(t: String): hint.text = t)
	host_pickers.selection_changed.connect(_update_buttons)
	# Port · Players · HOST ON LAN row.
	var port_label := _small_label("Port", Vector2(120, 282))
	host_page.add_child(port_label)
	port_edit = LineEdit.new()
	port_edit.text = str(Constants.LAN_PORT)
	port_edit.add_theme_font_size_override("font_size", FONT)
	UITheme.style_input(port_edit)
	port_edit.position = Vector2(148, 278)
	port_edit.custom_minimum_size = Vector2(60, 0)
	host_page.add_child(port_edit)
	host_page.add_child(_small_label("Players", Vector2(222, 282)))
	cap_spin = SpinBox.new()
	cap_spin.min_value = 2
	cap_spin.max_value = Constants.NET_MAX_PLAYERS
	cap_spin.value = Constants.NET_MAX_PLAYERS
	cap_spin.position = Vector2(264, 278)
	cap_spin.custom_minimum_size = Vector2(48, 0)
	cap_spin.get_line_edit().add_theme_font_size_override("font_size", FONT)
	UITheme.style_input(cap_spin.get_line_edit())
	host_page.add_child(cap_spin)
	host_btn = Button.new()
	host_btn.text = "HOST ON LAN"
	UITheme.style_button(host_btn)
	host_btn.add_theme_font_size_override("font_size", 12)
	host_btn.position = Vector2(350, 276)
	host_btn.custom_minimum_size = Vector2(170, 24)
	host_btn.pressed.connect(_host)
	host_page.add_child(host_btn)
	host_pickers.refresh()

func _build_join_page() -> void:
	host_list = SavePickers.picker_panel(join_page, 120, "HOSTS ON YOUR NETWORK")
	host_list.item_selected.connect(_host_row_selected)
	addr_edit = LineEdit.new()
	addr_edit.placeholder_text = "ip:port  (e.g. 192.168.1.20:%d)" % Constants.LAN_PORT
	addr_edit.add_theme_font_size_override("font_size", FONT)
	UITheme.style_input(addr_edit)
	addr_edit.position = Vector2(120, 248)
	addr_edit.custom_minimum_size = Vector2(170, 0)
	addr_edit.text_changed.connect(func(_t): _update_buttons())
	join_page.add_child(addr_edit)
	var refresh := Button.new()
	refresh.text = "Refresh"
	UITheme.style_button(refresh)
	refresh.position = Vector2(120 + 170 - 52, 224)
	refresh.custom_minimum_size = Vector2(52, 16)
	refresh.pressed.connect(_refresh_hosts)
	join_page.add_child(refresh)

	join_pickers.build_char(join_page, 350)
	join_pickers.message.connect(func(t: String): hint.text = t)
	join_pickers.selection_changed.connect(_update_buttons)
	join_pickers.name_edit.text_changed.connect(func(_t): _update_buttons())

	join_btn = Button.new()
	join_btn.text = "JOIN"
	UITheme.style_button(join_btn)
	join_btn.add_theme_font_size_override("font_size", 12)
	join_btn.position = Vector2(350, 276)
	join_btn.custom_minimum_size = Vector2(170, 24)
	join_btn.pressed.connect(_join)
	join_page.add_child(join_btn)

	status = Label.new()
	status.text = "idle"
	status.add_theme_font_size_override("font_size", 9)
	status.add_theme_color_override("font_color", Color(0.75, 0.85, 0.9))
	status.position = Vector2(120, 306)
	status.size = Vector2(400, 14)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	join_page.add_child(status)
	join_pickers.refresh()
	_refresh_hosts()

func _small_label(text: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT)
	l.position = pos
	return l

func _show_page(which: String) -> void:
	page = which
	host_page.visible = which == "host"
	join_page.visible = which == "join"
	host_tab.modulate = Color.WHITE if which == "host" else Color(0.7, 0.7, 0.7)
	join_tab.modulate = Color.WHITE if which == "join" else Color(0.7, 0.7, 0.7)
	if not _joining:
		hint.text = HOST_HINT if which == "host" else JOIN_HINT
	_update_buttons()

func _update_buttons() -> void:
	if host_btn != null:
		host_btn.disabled = host_pickers.stale_selected() or host_pickers.selected_character() == ""
	if join_btn != null:
		var has_target := addr_edit.text.strip_edges() != "" or not host_list.get_selected_items().is_empty()
		var no_char := join_pickers.stale_selected() or join_pickers.selected_character() == ""
		join_btn.disabled = _joining or not has_target or no_char

# --- HOST ---

func _host() -> void:
	if host_pickers.stale_selected():
		hint.text = "That save is an old format this build can't load - delete it and pick another."
		return
	var character := host_pickers.selected_character()
	if character == "":
		hint.text = "Pick or name a character first."
		return
	var p_port := int(port_edit.text) if port_edit.text.strip_edges().is_valid_int() else Constants.LAN_PORT
	if p_port < 1024 or p_port > 65535:
		hint.text = "Port must be between 1024 and 65535."
		return
	var err := Net.start_hosting(host_pickers.selected_world(), host_pickers.seed_value(), character,
		p_port, int(cap_spin.value))
	if err != OK:
		hint.text = "Could not open port %d (%s) - is another host running?" % [p_port, error_string(err)]

# --- JOIN ---

func _refresh_hosts() -> void:
	if host_list == null:
		return
	var sel := host_list.get_selected_items()
	var keep: String = host_list.get_item_metadata(sel[0]).key if not sel.is_empty() else ""
	host_list.clear()
	var rows: Array = browser.hosts() if browser != null else []
	for h in rows:
		var same_build: bool = h.build == Net.BUILD_ID
		host_list.add_item("%s  %d/%d  %s:%d%s" % [h.world, h.players, h.cap, h.address, h.port,
			"" if same_build else "  (other build)"])
		var idx := host_list.item_count - 1
		var key := "%s:%d" % [h.address, h.port]
		host_list.set_item_metadata(idx, {"key": key, "address": h.address, "port": h.port, "build": h.build})
		host_list.set_item_tooltip(idx, "build %s" % h.build)
		if not same_build:
			host_list.set_item_custom_fg_color(idx, SavePickers.STALE_COLOR)
		if key == keep:
			host_list.select(idx)
	if rows.is_empty():
		host_list.add_item("(listening for hosts...)")
		host_list.set_item_disabled(0, true)
		host_list.set_item_selectable(0, false)
	_update_buttons()

func _host_row_selected(idx: int) -> void:
	var md = host_list.get_item_metadata(idx)
	if md is Dictionary:
		addr_edit.text = "%s:%d" % [md.address, md.port]
	_update_buttons()

func _join() -> void:
	if _joining:
		return
	if join_pickers.stale_selected():
		hint.text = "That character is an old format this build can't load - delete it and pick another."
		return
	var character := join_pickers.selected_character()
	var target := addr_edit.text.strip_edges()
	if target == "":
		var sel := host_list.get_selected_items()
		if not sel.is_empty() and host_list.get_item_metadata(sel[0]) is Dictionary:
			var md: Dictionary = host_list.get_item_metadata(sel[0])
			target = "%s:%d" % [md.address, md.port]
	if target == "":
		_set_status("pick a host from the list or type ip:port")
		return
	_joining = true
	_update_buttons()
	var err := Net.start_joining(target, character)
	if err != OK:
		_joining = false
		_set_status("could not start joining (%s)" % error_string(err))
		_update_buttons()

func _on_join_failed(reason: String) -> void:
	_joining = false
	_set_status("refused: " + reason if not reason.begins_with("could not") else reason)
	_update_buttons()

func _set_status(text: String) -> void:
	if status != null:
		status.text = text

func _select_character(pickers: SavePickers, char_name: String) -> void:
	for i in pickers.char_list.item_count:
		var md = pickers.char_list.get_item_metadata(i)
		if md is Dictionary and md.name == char_name:
			pickers.char_list.select(i)
			return
	pickers.char_list.select(0)

# --- Back / Esc ---

func _back() -> void:
	if Net.is_online():
		Net.leave()
	get_tree().change_scene_to_file(TITLE_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
