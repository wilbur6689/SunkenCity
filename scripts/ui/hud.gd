extends CanvasLayer
## In-game HUD: health, oxygen (only while it matters), hotbar, scrap
## progress, transient messages, debug state readout. Polls the local
## player each frame; M1 UI keeps it simple.

@onready var health_bar: ProgressBar = %HealthBar
@onready var oxygen_bar: ProgressBar = %OxygenBar
@onready var debug_label: Label = %DebugLabel
@onready var hotbar: HBoxContainer = %Hotbar
@onready var message_label: Label = %MessageLabel
@onready var scrap_bar: ProgressBar = %ScrapBar

var player: Player
var _slots: Array = []
var _message: String = ""
var _message_timer: float = 0.0
var _minimap: TextureRect
var _minimap_img: Image
var _minimap_tex: ImageTexture
var _minimap_timer: float = 0.0
var _fps_label: Label
var _debug_panel: PanelContainer
var _debug_text: Label
var _debug_timer: float = 0.0
var _hover_panel: PanelContainer
var _hover_title: Label
var _hover_desc: Label
var _hover_action: Label
var _hover_shown: float = 0.0 # 0 = fully hidden, 1 = fully up
var _hover_obj: WorldObject = null
var _weight_icon: TextureRect

func _ready() -> void:
	for i in Constants.HOTBAR_SLOTS:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(20, 20)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.05, 0.08, 0.75)
		style.border_color = Color(0.5, 0.5, 0.55, 0.8)
		style.set_border_width_all(1)
		panel.add_theme_stylebox_override("panel", style)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(16, 16)
		panel.add_child(icon)
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.add_theme_font_size_override("font_size", 8)
		count.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_child(count)
		panel.gui_input.connect(_on_hotbar_click.bind(i))
		hotbar.add_child(panel)
		_slots.append({"panel": panel, "style": style, "icon": icon, "count": count})
	# The vitals bars must not swallow world clicks (ui_blocking checks the
	# hovered control now that the hotbar is clickable).
	for bar: Control in [health_bar, oxygen_bar, scrap_bar]:
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Overweight marker (user request): shows right of the hotbar once the
	# load is heavy enough to slow swimming, reddening as it worsens.
	_weight_icon = TextureRect.new()
	var wat := AtlasTexture.new()
	wat.atlas = load("res://assets/sprites/items.png")
	wat.region = Rect2(4 * 16, 5 * 16, 16, 16)
	_weight_icon.texture = wat
	_weight_icon.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_weight_icon.position = Vector2(116, -26)
	_weight_icon.tooltip_text = "Carrying too much — swimming is slowed"
	_weight_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weight_icon.visible = false
	get_node("Root").add_child(_weight_icon)
	_build_minimap()
	_build_debug()
	_build_hover_panel()

func _on_hotbar_click(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and player != null:
		player.selected_slot = i
		player.bare_hands = false

## Bottom-right info card: slides up while an interactable glows under the
## mouse — name, what it is, and how to use it (interact / container).
func _build_hover_panel() -> void:
	_hover_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.9)
	style.border_color = Color(0.55, 0.6, 0.65, 0.9)
	style.set_border_width_all(1)
	style.set_content_margin_all(5)
	_hover_panel.add_theme_stylebox_override("panel", style)
	_hover_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	_hover_title = Label.new()
	_hover_title.add_theme_font_size_override("font_size", 10)
	_hover_title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	_hover_desc = Label.new()
	_hover_desc.add_theme_font_size_override("font_size", 8)
	_hover_desc.add_theme_color_override("font_color", Color(0.75, 0.8, 0.82))
	_hover_action = Label.new()
	_hover_action.add_theme_font_size_override("font_size", 8)
	_hover_action.add_theme_color_override("font_color", Color(0.55, 0.8, 0.95))
	for l: Label in [_hover_title, _hover_desc, _hover_action]:
		box.add_child(l)
	_hover_panel.add_child(box)
	get_node("Root").add_child(_hover_panel)
	_hover_panel.visible = false

func _hover_lines(obj: WorldObject) -> Array:
	var def: Dictionary = obj.def
	var title: String = def.get("name", obj.id.capitalize())
	var what := ""
	var how := ""
	match def.kind:
		"door":
			what = "Door — blocks water while closed"
			how = "LMB: " + ("close" if obj.open else "open")
		"breaker":
			what = "Circuit breaker — powers nearby wired lights"
			how = "LMB: switch " + ("off" if obj.powered_on else "on")
		"bed":
			what = "Rest point"
			how = "LMB: set spawn"
		"pump":
			what = "Water pump — moves water to a targeted outlet"
			how = "LMB: aim the outlet"
		"station":
			what = "Crafting station (%s)" % def.get("station", "")
			how = "LMB: craft here"
		"chest":
			what = "Container — %d slots" % obj.storage.slots.size()
			how = "LMB: open · hold LMB: pick up (when empty) · RMB: scrap"
		_:
			if obj.storage != null:
				what = "Container — %d slots" % obj.storage.slots.size()
				how = "LMB: open · hold LMB: pick up (when empty) · RMB: scrap"
			elif def.get("fixed", false):
				what = "Furniture — wired into the building"
				how = "RMB: scrap"
			else:
				what = "Furniture"
				how = "Hold LMB: pick up · RMB: scrap"
	if what.begins_with("Furniture") or def.kind == "chest" or obj.storage != null:
		var mats: Array = []
		for y in def.get("yields", []):
			if not mats.has(String(y.item)):
				mats.append(String(y.item))
		if not mats.is_empty():
			what += " · scraps into " + ", ".join(PackedStringArray(mats)).replace("_", " ")
	return [title, what, how]

func _update_hover_panel(delta: float) -> void:
	var obj: WorldObject = player.interaction.hovered
	if obj != null and is_instance_valid(obj):
		if obj != _hover_obj:
			_hover_obj = obj
			var lines := _hover_lines(obj)
			_hover_title.text = lines[0]
			_hover_desc.text = lines[1]
			_hover_action.text = lines[2]
		_hover_shown = minf(_hover_shown + delta * 6.0, 1.0)
	else:
		_hover_obj = null
		_hover_shown = maxf(_hover_shown - delta * 6.0, 0.0)
	_hover_panel.visible = _hover_shown > 0.0
	if _hover_panel.visible:
		var sz := _hover_panel.get_combined_minimum_size()
		var rs: Vector2 = (get_node("Root") as Control).size
		# Slide up out of the bottom edge; ease the tail of the motion.
		var t := 1.0 - pow(1.0 - _hover_shown, 2.0)
		_hover_panel.position = Vector2(rs.x - sz.x - 6, rs.y - t * (sz.y + 6))

## FPS counter (always on, top right beside the minimap) + the F3 debug
## overlay: build info, height/depth, and per-system perf counters.
func _build_debug() -> void:
	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 9)
	_fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.position = Vector2(-Constants.MINIMAP_WINDOW.x - 62, 6)
	_fps_label.custom_minimum_size = Vector2(48, 0)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_node("Root").add_child(_fps_label)

	_debug_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.85)
	style.border_color = Color(0.4, 0.45, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_content_margin_all(4)
	_debug_panel.add_theme_stylebox_override("panel", style)
	_debug_panel.position = Vector2(6, 34)
	_debug_panel.visible = false
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_text = Label.new()
	_debug_text.add_theme_font_size_override("font_size", 8)
	_debug_text.add_theme_color_override("font_color", Color(0.85, 0.9, 0.92))
	_debug_panel.add_child(_debug_text)
	get_node("Root").add_child(_debug_panel)
	debug_label.visible = false # the old always-on state line lives behind F3 now
	debug_label.position.y -= 24 # clear of the bottom-centre hotbar
	if OS.get_cmdline_user_args().has("--f3"): # dev aid for screenshots
		_debug_panel.visible = true
		debug_label.visible = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_debug_panel.visible = not _debug_panel.visible
		debug_label.visible = _debug_panel.visible

func _refresh_debug() -> void:
	if not _debug_panel.visible or not World.is_ready():
		return
	var v := Engine.get_version_info()
	var cell := World.cell_at(player.global_position)
	var depth := World.depth_below_waterline(cell)
	var lines: Array = [
		"SunkenCity %s (%s) · Godot %s · %s" % [
			ProjectSettings.get_setting("application/config/version", "dev"),
			"debug" if OS.is_debug_build() else "release", v.string, OS.get_name()],
		"GPU: %s" % RenderingServer.get_video_adapter_name(),
		"fps %d · frame %.1f ms · physics %.1f ms · draw calls %d · nodes %d" % [
			Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)],
		"pos (%.0f, %.0f) px · cell (%d, %d) · depth %+d blk (%+d ft) · band %s" % [
			player.global_position.x, player.global_position.y, cell.x, cell.y,
			depth, depth * 2, World.band_at(cell)],
		"water: awake %d · processed %d · tick %.2f ms" % [
			World.water_sim.awake.size(), World.water_sim.processed_last_tick, World.perf.water_ms],
		"light: window %dx%d · compute %.2f ms · fog raycast %.2f ms" % [
			Constants.LIGHT_WINDOW.x, Constants.LIGHT_WINDOW.y, World.perf.light_ms, World.perf.fog_ms],
		"objects: %d live / %d total · items %d · placed blocks %d" % [
			World.perf.objects_live, World.perf.objects_total,
			World.items_root.get_child_count(), World.placed_blocks.size()],
		"map revealed %d cells · clock %.2f · sun %.2f" % [
			World.map_reveal.revealed_count(), World.time_of_day, World.sun_strength()],
		"music: %s" % Audio.debug_status(),
	]
	_debug_text.text = "\n".join(PackedStringArray(lines))

## Top-right minimap (CC-25): a window of the fog-of-war world map centred
## on the player, redrawn a few times a second from World.map_reveal.
func _build_minimap() -> void:
	var w: Vector2i = Constants.MINIMAP_WINDOW
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	style.border_color = Color(0.5, 0.5, 0.55, 0.8)
	style.set_border_width_all(1)
	style.set_content_margin_all(2)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-w.x - 10, 6)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap = TextureRect.new()
	_minimap.custom_minimum_size = Vector2(w)
	_minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_minimap)
	get_node("Root").add_child(panel)
	_minimap_img = Image.create(w.x, w.y, false, Image.FORMAT_RGBA8)
	_minimap_tex = ImageTexture.create_from_image(_minimap_img)
	_minimap.texture = _minimap_tex

# Cell colors live in MapColors (shared with the full-screen map view).

func _redraw_minimap() -> void:
	if not World.is_ready() or World.map_reveal == null:
		return
	var w: Vector2i = Constants.MINIMAP_WINDOW
	var center := World.cell_at(player.global_position)
	var org := center - w / 2
	for py in w.y:
		for px in w.x:
			var cell := org + Vector2i(px, py)
			var col := MapColors.cell_color(cell) if World.map_reveal.is_revealed(cell) else MapColors.UNREVEALED
			_minimap_img.set_pixel(px, py, col)
	# The player: a bright 2x2 dot dead centre.
	for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var p := w / 2 + d
		_minimap_img.set_pixel(p.x, p.y, Color.WHITE)
	_minimap_tex.update(_minimap_img)

func show_message(text: String) -> void:
	_message = text
	_message_timer = 2.5

func _process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		if player == null:
			return
		player.message.connect(show_message)
	health_bar.max_value = Constants.MAX_HEALTH
	health_bar.value = player.health
	oxygen_bar.max_value = player.max_oxygen()
	oxygen_bar.value = player.oxygen
	oxygen_bar.visible = player.submerged or player.oxygen < player.max_oxygen()
	oxygen_bar.modulate = Color(1.0, 0.35, 0.35) if player.drowning else Color.WHITE

	for i in _slots.size():
		var s = player.inventory.slots[i]
		var ui = _slots[i]
		ui.icon.texture = Data.icon(s.id) if s != null else null
		ui.count.text = str(s.count) if (s != null and s.count > 1) else ""
		ui.style.border_color = Color(1.0, 0.85, 0.4) if i == player.selected_slot else Color(0.5, 0.5, 0.55, 0.8)

	var wf: float = player.weight_swim_factor()
	_weight_icon.visible = wf <= 0.8
	if _weight_icon.visible: # amber -> red as the load approaches the floor
		var t := clampf(inverse_lerp(0.8, Constants.WEIGHT_SWIM_MIN_FACTOR, wf), 0.0, 1.0)
		_weight_icon.modulate = Color(1.0, lerpf(0.85, 0.35, t), 0.3)

	_minimap_timer -= delta
	if _minimap_timer <= 0.0:
		_minimap_timer = Constants.MINIMAP_REFRESH_SECONDS
		_redraw_minimap()
	_debug_timer -= delta
	if _debug_timer <= 0.0:
		_debug_timer = 0.25
		var fps := Engine.get_frames_per_second()
		_fps_label.text = "%d FPS" % fps
		_fps_label.add_theme_color_override("font_color",
			Color(0.5, 0.95, 0.55) if fps >= 50 else (Color(0.95, 0.85, 0.4) if fps >= 30 else Color(0.95, 0.45, 0.4)))
		_refresh_debug()

	_update_hover_panel(delta)

	var inter := player.interaction
	scrap_bar.visible = inter.scrapping != null
	scrap_bar.value = inter.scrap_progress * 100.0
	if inter.message != "" and inter.message != _message:
		show_message(inter.message)
	_message_timer = maxf(_message_timer - delta, 0.0)
	message_label.text = _message if _message_timer > 0.0 else ""

	var v := player.velocity / Constants.BLOCK_SIZE
	debug_label.text = "%s%s  hp %d  o2 %.1f  v (%.1f, %.1f) bl/s  wt %.1f  lvl %d (scr %d swim %d bld %d)" % [
		player.state_name(), " [compact]" if player.compact else "",
		roundi(player.health), player.oxygen, v.x, v.y, player.inventory.total_weight(),
		player.skills.player_level(), player.skills.level("scrapping"), player.skills.level("swimming"),
		player.skills.level("building")]
