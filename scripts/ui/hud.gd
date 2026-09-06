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
var _hover_mats: HBoxContainer
var _hover_badge: Control

const TIER_BADGE := preload("res://scripts/ui/tier_badge.gd") # shared with the inventory tooltips (2026-09-06)
var _gain_box: VBoxContainer
var _gain_rows: Dictionary = {} # item id -> {row, count_label, count, t}
var _weight_icon: TextureRect
var _weapon_slot: Dictionary = {} # {panel, style, icon, glyph}: the worn weapon, left of the hotbar (2026-09-06)
## Hotbar tooltip (user request 2026-09-06): a plate above the hovered slot
## with the item's name (rarity colour), tool tier badge, modifier lines and
## description - the same facts the bag tooltip shows.
const NO_HOTBAR_HOVER := -99
var _hotbar_hover: int = NO_HOTBAR_HOVER
var _tip_plate: PanelContainer
var _tip_name: Label
var _tip_tier_row: HBoxContainer
var _tip_badge: Control
var _tip_tier: Label
var _tip_lines: Label

func _ready() -> void:
	UIScale.register($Root) # UI size scaling (2026-09-02)
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
		panel.mouse_entered.connect(_set_hotbar_hover.bind(i))
		panel.mouse_exited.connect(_set_hotbar_hover.bind(NO_HOTBAR_HOVER))
		_slots.append({"panel": panel, "style": style, "icon": icon, "count": count})
	# Weapon slot (user request 2026-09-06): the worn weapon, left of the
	# hotbar with a gap; key 1 / click / the wheel select it.
	var wpanel := PanelContainer.new()
	wpanel.custom_minimum_size = Vector2(20, 20)
	var wstyle := StyleBoxFlat.new()
	wstyle.bg_color = Color(0.05, 0.05, 0.08, 0.75)
	wstyle.border_color = Color(0.5, 0.5, 0.55, 0.8)
	wstyle.set_border_width_all(1)
	wpanel.add_theme_stylebox_override("panel", wstyle)
	var wglyph := TextureRect.new()
	var gat := AtlasTexture.new()
	gat.atlas = load("res://assets/ui/equip_glyphs.png")
	gat.region = Rect2(4 * Data.ICON_PX, 0, Data.ICON_PX, Data.ICON_PX)
	wglyph.texture = gat
	wglyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wglyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wglyph.custom_minimum_size = Vector2(16, 16)
	wglyph.modulate = Color(1, 1, 1, 0.5)
	wpanel.add_child(wglyph)
	var wicon := TextureRect.new()
	wicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wicon.set_anchors_preset(Control.PRESET_FULL_RECT)
	wpanel.add_child(wicon)
	wpanel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	wpanel.position = Vector2(hotbar.offset_left - 8 - 20, hotbar.offset_top) # gap of 8 px left of the bar
	wpanel.gui_input.connect(_on_hotbar_click.bind(Constants.WEAPON_HOTBAR))
	wpanel.mouse_entered.connect(_set_hotbar_hover.bind(Constants.WEAPON_HOTBAR))
	wpanel.mouse_exited.connect(_set_hotbar_hover.bind(NO_HOTBAR_HOVER))
	get_node("Root").add_child(wpanel)
	_weapon_slot = {"panel": wpanel, "style": wstyle, "icon": wicon, "glyph": wglyph}
	# The vitals bars must not swallow world clicks (ui_blocking checks the
	# hovered control now that the hotbar is clickable).
	for bar: Control in [health_bar, oxygen_bar, scrap_bar]:
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Overweight marker (user request): shows right of the hotbar once the
	# load is heavy enough to slow swimming, reddening as it worsens.
	_weight_icon = TextureRect.new()
	var wat := AtlasTexture.new()
	wat.atlas = load("res://assets/sprites/items.png")
	wat.region = Rect2(4 * Data.ICON_PX, 5 * Data.ICON_PX, Data.ICON_PX, Data.ICON_PX)
	_weight_icon.texture = wat
	_weight_icon.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_weight_icon.position = Vector2(116, -26)
	_weight_icon.tooltip_text = "Carrying too much — swimming is slowed"
	_weight_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weight_icon.visible = false
	get_node("Root").add_child(_weight_icon)
	_build_minimap()
	_build_debug()
	_build_admin()
	_build_hover_panel()
	_build_gain_feed()
	_build_hotbar_tip()

func _build_hotbar_tip() -> void:
	_tip_plate = PanelContainer.new()
	_tip_plate.add_theme_stylebox_override("panel", UITheme.flat_panel(Color(0.03, 0.06, 0.09, 0.95)))
	_tip_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_plate.visible = false
	_tip_plate.z_index = 30
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	_tip_plate.add_child(v)
	_tip_name = UITheme.label("", 8)
	v.add_child(_tip_name)
	_tip_tier_row = HBoxContainer.new()
	_tip_tier_row.add_theme_constant_override("separation", 3)
	_tip_badge = TIER_BADGE.new()
	_tip_tier_row.add_child(_tip_badge)
	_tip_tier = UITheme.label("", 8, Color(0.75, 0.8, 0.82))
	_tip_tier_row.add_child(_tip_tier)
	v.add_child(_tip_tier_row)
	_tip_lines = UITheme.label("", 8, Color(0.75, 0.79, 0.83))
	_tip_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_lines.custom_minimum_size = Vector2(120, 0)
	v.add_child(_tip_lines)
	get_node("Root").add_child(_tip_plate)

func _set_hotbar_hover(i: int) -> void:
	_hotbar_hover = i

## The stack under the hovered hotbar slot (null when empty / no hover).
func _hotbar_hover_stack():
	if player == null or _hotbar_hover == NO_HOTBAR_HOVER:
		return null
	if _hotbar_hover == Constants.WEAPON_HOTBAR:
		return player.equipped_weapon()
	return player.inventory.slots[_hotbar_hover] if _hotbar_hover < player.inventory.slots.size() else null

func _update_hotbar_tip() -> void:
	var st = _hotbar_hover_stack()
	var anchor: Control = null
	if _hotbar_hover == Constants.WEAPON_HOTBAR and not _weapon_slot.is_empty():
		anchor = _weapon_slot.panel
	elif _hotbar_hover >= 0 and _hotbar_hover < _slots.size():
		anchor = _slots[_hotbar_hover].panel
	if st == null or anchor == null:
		if _hotbar_hover == Constants.WEAPON_HOTBAR and anchor != null:
			_tip_name.text = "Weapon slot"
			_tip_name.add_theme_color_override("font_color", Color(0.75, 0.79, 0.83))
			_tip_tier_row.visible = false
			_tip_lines.text = "Wear a weapon in the inventory screen; key 1 selects it."
			_tip_lines.visible = true
		else:
			_tip_plate.visible = false
			return
	else:
		_tip_name.text = ItemMods.display_name(st)
		_tip_name.add_theme_color_override("font_color", ItemMods.rarity_color(st))
		var it := Data.item(String(st.id))
		var tool: Dictionary = it.get("tool", {})
		_tip_tier_row.visible = false
		if not tool.is_empty():
			var tier := int(tool.get("tier", 0))
			_tip_badge.set_tier(tier)
			_tip_badge.visible = true
			_tip_tier.text = "Fells trees (tier %d)" % tier if String(tool.get("type", "")) == "axe" else "Dismantles tier %d and below" % tier
			_tip_tier_row.visible = true
		elif it.has("weapon"):
			_tip_badge.visible = false
			_tip_tier.text = "Weapon: no dismantling"
			_tip_tier_row.visible = true
		var lines: Array = ItemMods.describe(st)
		var desc := Data.item_desc(String(st.id))
		if desc != "":
			lines.append(desc)
		if int(st.get("count", 1)) > 1:
			lines.append("x%d · %.1f wt" % [int(st.count), ItemMods.unit_weight(st) * int(st.count)])
		_tip_lines.text = "
".join(PackedStringArray(lines))
		_tip_lines.visible = not lines.is_empty()
	_tip_plate.visible = true
	_tip_plate.reset_size()
	var root: Control = get_node("Root")
	var a := anchor.global_position
	var pos := Vector2(a.x + anchor.size.x * 0.5 - _tip_plate.size.x * 0.5, a.y - _tip_plate.size.y - 4)
	pos.x = clampf(pos.x, 2.0, root.size.x - _tip_plate.size.x - 2.0)
	_tip_plate.position = pos

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
	# Category line: a tier badge (shield with the required tool tier) + label.
	var descrow := HBoxContainer.new()
	descrow.add_theme_constant_override("separation", 3)
	descrow.alignment = BoxContainer.ALIGNMENT_BEGIN
	_hover_badge = TIER_BADGE.new()
	_hover_desc = Label.new()
	_hover_desc.add_theme_font_size_override("font_size", 8)
	_hover_desc.add_theme_color_override("font_color", Color(0.75, 0.8, 0.82))
	_hover_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	descrow.add_child(_hover_badge)
	descrow.add_child(_hover_desc)
	_hover_action = Label.new()
	_hover_action.add_theme_font_size_override("font_size", 8)
	_hover_action.add_theme_color_override("font_color", Color(0.55, 0.8, 0.95))
	_hover_mats = HBoxContainer.new()
	_hover_mats.add_theme_constant_override("separation", 4)
	for c: Control in [_hover_title, descrow, _hover_mats, _hover_action]:
		box.add_child(c)
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
		"scrapper":
			var st: int = int(def.get("scrap_stage", 1))
			var tier: String = {1: "wood", 2: "scrap & stone", 3: "iron", 4: "steel", 5: "any-tier"}.get(st, "")
			what = "Scrap bench (%s) — melts collected furniture to materials" % tier
			how = "LMB: grind all %s furniture in your bag" % ("scrappable" if st == 5 else tier)
		"planter":
			what = "Planter box — three trees, one per section" if obj.id == "planter_box" else "Planter — grows a tree for wood under open sky"
			how = "LMB: plant a held seed · pour a full bucket to water it up a stage"
		"chest":
			what = "Container — %d slots" % obj.storage.slots.size()
			how = "LMB: open · hold LMB: pick up (when empty) · RMB: scrap"
		"heater":
			what = "Pot-belly stove — lit in a SEALED room it slowly boils the water off"
			how = "LMB: %s · hold LMB: pick up" % ("snuff it" if obj.powered_on else "light it")
		_:
			if def.has("needed_for"): # a found bench part (docs/CraftingStages.md)
				var bench_name: String = Data.objects.get(def.needed_for, {}).get("name", String(def.needed_for))
				return [title, "Bench part — builds the %s" % bench_name,
					"Hold LMB: pick up and carry it home · RMB scraps it (you'd lose the part)"]
			if obj.storage != null:
				what = "Container — %d slots" % obj.storage.slots.size()
				how = "LMB: open · hold LMB: pick up (when empty) · RMB: scrap"
			elif def.get("fixed", false):
				what = "Furniture — wired into the building"
				how = "RMB: scrap"
			else:
				what = "Furniture"
				how = "Hold LMB: pick up · RMB: scrap"
	# Scrap yields render as an icon row now (user request 2026-09-01),
	# not appended text - see _fill_hover_mats.
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
			# Tier badge on harvestable furniture only (user request 2026-09-02).
			if obj.def.get("kind", "") == "scrap":
				_hover_badge.set_tier(int(obj.def.get("tool_tier", 0)))
				_hover_badge.visible = true
			else:
				_hover_badge.visible = false
			_fill_hover_mats(obj)
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
	if OS.get_cmdline_user_args().has("--f4"): # dev aid: open the admin panel at boot
		call_deferred("_toggle_admin")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_debug_panel.visible = not _debug_panel.visible
		debug_label.visible = _debug_panel.visible
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		_toggle_admin()

# --- F4 admin panel (user request 2026-09-06; scripts/dev/admin.gd) ---
var _admin_panel: PanelContainer
var _admin_status: Label
var _admin_checks: Dictionary = {} # key -> CheckBox

func _build_admin() -> void:
	_admin_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.03, 0.03, 0.9)
	style.border_color = Color(0.8, 0.35, 0.3, 0.9)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	_admin_panel.add_theme_stylebox_override("panel", style)
	_admin_panel.position = Vector2(6, 200)
	_admin_panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_admin_panel.add_child(box)
	var title := Label.new()
	title.text = "ADMIN (F4) — testing aids"
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.6))
	box.add_child(title)
	for spec in [["noclip", "No-clip fly (move keys · jump up · crouch down · sprint fast)"],
			["no_death", "No death (no damage, bleeding or drowning)"],
			["reveal", "Reveal map + no fog"]]:
		var cb := CheckBox.new()
		cb.text = spec[1]
		cb.add_theme_font_size_override("font_size", 8)
		cb.add_theme_icon_override("unchecked", _check_icon(false))
		cb.add_theme_icon_override("checked", _check_icon(true))
		cb.add_theme_icon_override("unchecked_disabled", _check_icon(false))
		cb.add_theme_icon_override("checked_disabled", _check_icon(true))
		cb.toggled.connect(_on_admin_toggle.bind(spec[0]))
		box.add_child(cb)
		_admin_checks[spec[0]] = cb
	var give := Button.new()
	give.text = "Give %d of every crafting resource" % Admin.RESOURCE_COUNT
	give.add_theme_font_size_override("font_size", 8)
	give.pressed.connect(func() -> void:
		var n := Admin.give_resources(player)
		_admin_say("%d resource stacks added" % n if n > 0 else "bag full"))
	box.add_child(give)
	var surf := Button.new()
	surf.text = "Teleport to the top of this column"
	surf.add_theme_font_size_override("font_size", 8)
	surf.pressed.connect(func() -> void:
		_admin_say("on the surface" if Admin.to_surface(player) else "nothing solid in this column"))
	box.add_child(surf)
	_admin_status = Label.new()
	_admin_status.add_theme_font_size_override("font_size", 8)
	_admin_status.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	box.add_child(_admin_status)
	get_node("Root").add_child(_admin_panel)

## A crisp 9 px box (the default theme's check icons vanish at this UI scale).
func _check_icon(on: bool) -> ImageTexture:
	var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 9:
		for c: Vector2i in [Vector2i(i, 0), Vector2i(i, 8), Vector2i(0, i), Vector2i(8, i)]:
			img.set_pixelv(c, Color(0.9, 0.75, 0.7))
	if on:
		img.fill_rect(Rect2i(2, 2, 5, 5), Color(0.5, 1.0, 0.55))
	return ImageTexture.create_from_image(img)

func _toggle_admin() -> void:
	_admin_panel.visible = not _admin_panel.visible
	if _admin_panel.visible:
		_admin_checks.noclip.button_pressed = Admin.noclip
		_admin_checks.no_death.button_pressed = Admin.no_death
		_admin_checks.reveal.button_pressed = Admin.reveal
		for cb: CheckBox in _admin_checks.values():
			cb.disabled = not Admin.available()
		_admin_say("" if Admin.available() else "host only — the host simulates your body")

func _on_admin_toggle(on: bool, key: String) -> void:
	if not Admin.available():
		return
	match key:
		"noclip":
			Admin.set_noclip(player, on)
			_admin_say("flying — jump up, crouch down" if on else "walking")
		"no_death":
			Admin.set_no_death(player, on)
			_admin_say("nothing can hurt you" if on else "mortal again")
		"reveal":
			Admin.set_reveal(on)
			_admin_say("map revealed, fog off" if on else "fog back (the map stays revealed)")

func _admin_say(text: String) -> void:
	if _admin_status != null:
		_admin_status.text = text

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
			depth, depth, World.floor_band_at(cell)],
		"water: awake %d · processed %d · tick %.2f ms" % [
			World.water_sim.awake.size(), World.water_sim.processed_last_tick, World.perf.water_ms],
		"light: window %dx%d · compute %.2f ms · fog raycast %.2f ms" % [
			Constants.LIGHT_WINDOW.x, Constants.LIGHT_WINDOW.y, World.perf.light_ms, World.perf.fog_ms],
		"objects: %d live / %d total · items %d · placed blocks %d" % [
			World.perf.objects_live, World.perf.objects_total,
			World.items_root.get_child_count(), World.placed_blocks.size()],
		"enemies: %d live / %d total · day %d · red moon %s (next day %d)" % [
			World.perf.enemies_live, World.perf.enemies_total, World.day_count,
			"UP" if World.red_moon_active else "down", World.next_red_moon_day],
		"map revealed %d cells · clock %.2f · sun %.2f" % [
			World.map_reveal.revealed_count(), World.time_of_day, World.sun_strength()],
		"music: %s" % Audio.debug_status(),
	]
	# Perf drill-down (2026-09-05): what the view costs and what is streamed.
	var cam := get_viewport().get_camera_2d()
	var zoom: float = cam.zoom.x if cam != null else 1.0
	var view_px: Vector2 = get_viewport().get_visible_rect().size / maxf(zoom, 0.01)
	var view_cells := Vector2i(ceili(view_px.x / Constants.BLOCK_SIZE), ceili(view_px.y / Constants.BLOCK_SIZE))
	var fh: int = int(CityGen.tower_at(World.towers, cell).get("floor_h", CityGen.FLOOR_H))
	var items_asleep := 0
	var items_hidden := 0
	var items_total := 0
	var live_enemies_on_screen := 0
	var half_view := view_px * 0.5
	for it in World.items_root.get_children():
		if it is WorldItem:
			items_total += 1
			if it.asleep:
				items_asleep += 1
			if not it.visible:
				items_hidden += 1
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and absf(e.global_position.x - player.global_position.x) < half_view.x \
				and absf(e.global_position.y - player.global_position.y) < half_view.y:
			live_enemies_on_screen += 1
	lines.append_array([
		"view: zoom %.2f · %dx%d cells (%.0f x %.0f px) · ~%.1f floors tall (pitch %d)" % [
			zoom, view_cells.x, view_cells.y, view_px.x, view_px.y, float(view_cells.y) / fh, fh],
		"render ms: water draw %.2f (%d cells) · fog %.2f (%d cells) · tiles %.2f (%d painted)" % [
			World.perf.water_draw_ms, World.perf.water_cells, World.perf.fog_ms, World.perf.fog_cells,
			World.perf.struct_ms, World.perf.struct_cells],
		"stream: objects window %dx%d (%.1f floors) · scan %.2f ms (%d scans, %d spawned) · enemies window %dx%d (%.1f floors) · scan %.2f ms" % [
			World.object_window.x, World.object_window.y, float(World.object_window.y) / fh,
			World.perf.obj_scan_ms, World.perf.obj_scans, World.perf.obj_spawned,
			World.enemy_window.x, World.enemy_window.y, float(World.enemy_window.y) / fh, World.perf.enemy_scan_ms],
		"items: %d nodes (all dropped items live as nodes; none are unloaded) · %d asleep beyond %d blk · %d hidden by fog · enemies on screen %d / %d live" % [
			items_total, items_asleep, int(Constants.ITEM_SLEEP_BLOCKS), items_hidden, live_enemies_on_screen, World.perf.enemies_live],
		"memory: static %.1f MB · objects %d · orphan nodes %d · physics bodies %d" % [
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)],
	])
	if Net.is_online(): # LAN session (2026-09-05): peer id, role, ping, traffic
		var ping: float = Net.ping_ms
		if Net.mode == Net.Mode.HOST:
			for id in Net.peers: # host: the slowest client's round trip
				ping = maxf(ping, float(Net.peers[id].get("ping_ms", 0.0)))
		lines.append("net: peer %d · %s · %d players · ping %d ms · in %.1f KB/s · out %.1f KB/s" % [
			Net.local_peer(), "host" if Net.mode == Net.Mode.HOST else "client", Net.peers.size(),
			int(ping), Net.bytes_in_per_s / 1024.0, Net.bytes_out_per_s / 1024.0])
		if Net.mode == Net.Mode.HOST and Net.world_sync != null and Net.world_sync.get("stats_last") != null:
			var st: Dictionary = Net.world_sync.stats_last
			lines.append("sync: %d packets/s · %d cells/s · %d water pairs/s" % [int(st.get("packets", 0)),
				int(st.get("cells", 0)), int(st.get("water_pairs", 0))])
	if Admin.any_on():
		lines.append("admin: %s%s%s" % ["noclip " if Admin.noclip else "", "no-death " if Admin.no_death else "", "reveal" if Admin.reveal else ""])
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
	# Inside an interior pocket the minimap stays on the city: it centres on
	# the doorway you came through (the pocket itself is off the map).
	var center := World.map_macro_for(player.global_position)
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
	if player != null:
		visible = not player.dying # the death scene clears the UI (2026-09-01)
	if player == null:
		player = Net.local_player()
		if player == null:
			return
		player.message.connect(show_message)
	health_bar.max_value = Constants.MAX_HEALTH
	health_bar.value = player.health
	# Bleeding (GD-21): the health bar pulses red until bandaged.
	health_bar.modulate = Color(1.0, 0.4, 0.4) if player.bleed_time > 0.0 		and int(Time.get_ticks_msec() / 300) % 2 == 0 else Color.WHITE
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
	if not _weapon_slot.is_empty():
		var worn = player.equipped_weapon()
		_weapon_slot.icon.texture = Data.icon(worn.id) if worn != null else null
		_weapon_slot.glyph.visible = worn == null
		_weapon_slot.style.border_color = Color(1.0, 0.85, 0.4) if player.selected_slot == Constants.WEAPON_HOTBAR else Color(0.5, 0.5, 0.55, 0.8)

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
	_update_hotbar_tip()
	_tick_gain_feed(delta)

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

## Scrap yields as an icon row on the hover card (user request 2026-09-01):
## each material's icon with its min-max roll, instead of a text list.
func _fill_hover_mats(obj: WorldObject) -> void:
	for c in _hover_mats.get_children():
		c.queue_free()
	var yields: Array = obj.def.get("yields", [])
	_hover_mats.visible = not yields.is_empty()
	for y in yields:
		var ic := TextureRect.new()
		ic.texture = Data.icon(String(y.item))
		ic.custom_minimum_size = Vector2(14, 14)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.tooltip_text = Data.item_name(String(y.item))
		_hover_mats.add_child(ic)
		var lb := Label.new()
		lb.add_theme_font_size_override("font_size", 8)
		lb.add_theme_color_override("font_color", Color(0.75, 0.8, 0.82))
		lb.text = ("%d-%d" % [int(y.min), int(y.max)]) if int(y.min) != int(y.max) else str(int(y.max))
		_hover_mats.add_child(lb)

## Left-side harvest feed (user request 2026-09-01): each material gained
## shows its icon and a running +count; repeat gains bump the row and reset
## its clock; rows fade out after a beat.
func _build_gain_feed() -> void:
	_gain_box = VBoxContainer.new()
	_gain_box.add_theme_constant_override("separation", 2)
	_gain_box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_gain_box.position = Vector2(8, -50)
	_gain_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_node("Root").add_child(_gain_box)

func _tick_gain_feed(delta: float) -> void:
	for g in player.gain_feed:
		var id: String = g.id
		if _gain_rows.has(id):
			var r: Dictionary = _gain_rows[id]
			r.count += int(g.count)
			r.t = 0.0
			(r.count_label as Label).text = "+%d" % int(r.count)
			(r.row as Control).modulate.a = 1.0
		else:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 3)
			var ic := TextureRect.new()
			ic.texture = Data.icon(id)
			ic.custom_minimum_size = Vector2(14, 14)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(ic)
			var lb := Label.new()
			lb.add_theme_font_size_override("font_size", 9)
			lb.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8))
			lb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
			lb.text = "+%d" % int(g.count)
			row.add_child(lb)
			_gain_box.add_child(row)
			_gain_rows[id] = {"row": row, "count_label": lb, "count": int(g.count), "t": 0.0}
	player.gain_feed.clear()
	for id in _gain_rows.keys():
		var r: Dictionary = _gain_rows[id]
		r.t += delta
		(r.row as Control).modulate.a = clampf((2.6 - float(r.t)) / 0.6, 0.0, 1.0)
		if float(r.t) >= 2.6:
			(r.row as Node).queue_free()
			_gain_rows.erase(id)
