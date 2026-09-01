extends Control
## Flora Editor: author rooftop vegetation — trees, bushes, grass, shrubs —
## that CityGen scatters across dry roofs (user request 2026-09-01).
## Run standalone:  godot --path . res://scenes/tools/flora_editor.tscn
##
## Left: settings (id, name, type, size in blocks, harvest stats, spawn
## weight, the growth chain — grows-into id + nightly chance — and the
## no-item flag) plus the yields table. Center: a pixel canvas (4x zoom,
## scrollable — mature trees run 16 blocks tall). Right: leaf/bark ramps
## and accents. Save writes data/objects.json (category "flora", zone
## "roof") AND assets/sprites/objects/<id>.png; the roof sprinkle picks
## every flora def by its flora_weight, so a saved plant is in the next
## generated world with no further wiring.

const FLORA_TYPES := ["tree", "bush", "grass", "shrub"]
const YIELD_ITEMS := ["wood", "scrap_metal", "plastic", "cloth", "stone", "iron"]
const PX := 4 # canvas zoom
const MAX_W := 8
const MAX_H := 16

## TileArt ramps (outline, tones..., highlight) — leaves first, then bark.
const PALETTE := [
	["Leaf", [Color8(18, 34, 22), Color8(40, 84, 48), Color8(56, 110, 62), Color8(74, 136, 78), Color8(96, 160, 94), Color8(124, 184, 116)]],
	["Wood", [Color8(40, 26, 14), Color8(94, 62, 38), Color8(120, 82, 50), Color8(146, 104, 66), Color8(168, 126, 86), Color8(192, 152, 108)]],
	["Stone", [Color8(30, 28, 26), Color8(66, 64, 62), Color8(90, 88, 86), Color8(114, 112, 110), Color8(138, 136, 134), Color8(166, 164, 162)]],
]
const ACCENT_HUES := [0.0, 0.07, 0.13, 0.3, 0.38, 0.5, 0.76, 0.9]
const ACCENT_SHADES := [[0.8, 0.32], [0.85, 0.5], [0.78, 0.68], [0.68, 0.85], [0.5, 0.95], [0.25, 1.0]]

var objects_path := "res://data/objects.json"
var sprites_dir := "res://assets/sprites/objects/"
var def: Dictionary = {}
var image: Image
var texture: ImageTexture
var brush := Color8(74, 136, 78)
var tool_mode := "pencil" # pencil | eraser | fill
var hover_px := Vector2i(-1, -1)

var canvas: Control
var id_edit: LineEdit
var name_edit: LineEdit
var type_option: OptionButton
var w_spin: SpinBox
var h_spin: SpinBox
var weight_spin: SpinBox
var tier_spin: SpinBox
var skill_spin: SpinBox
var time_spin: SpinBox
var xp_spin: SpinBox
var flora_weight_spin: SpinBox
var grow_edit: LineEdit
var grow_chance_spin: SpinBox
var no_item_check: CheckBox
var yields_box: VBoxContainer
var load_option: OptionButton
var status_label: Label
var tool_label: Label
var brush_swatch: ColorRect

func _ready() -> void:
	def = _default_def()
	_new_image()
	_build_ui()
	_mount_pause_menu()
	_refresh_load_list()
	_sync_to_ui()
	_prefill_flora()

func _default_def() -> Dictionary:
	return {"id": "new_flora", "name": "New Flora", "kind": "scrap", "category": "flora",
		"room_type": "tree", "size": [2, 3], "weight": 4, "tool_tier": 0, "skill": 0,
		"scrap_time": 1.5, "xp": 2, "zones": ["roof"], "flora_weight": 1,
		"yields": [{"item": "wood", "min": 1, "max": 2}]}

func _new_image() -> void:
	image = Image.create(int(def.size[0]) * 16, int(def.size[1]) * 16, false, Image.FORMAT_RGBA8)
	texture = null

# --- UI ---

func _mount_pause_menu() -> void:
	var pm: CanvasLayer = load("res://scripts/ui/pause_menu.gd").new()
	pm.custom_controls = [
		["Paint pixel", "LMB (drag) · Pencil tool"],
		["Erase pixel", "RMB · or the Eraser tool"],
		["Fill", "Fill tool · LMB on a region"],
		["Pick colour", "Swatches · Custom… opens a picker"],
		["Sprite size", "Width / Height spinners (blocks, up to 8x16)"],
		["Growth chain", "Grows-into id + nightly chance"],
		["Save", "SAVE / EXPORT → data/objects.json + PNG"],
		["Menu", "Esc"],
	]
	pm.hint_text = "Unsaved flora is lost on quit — SAVE / EXPORT first"
	pm.quit_text = "QUIT TO TITLE"
	pm.quit_callable = _quit_to_title
	add_child(pm)

func _quit_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.13, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := UITheme.label("FLORA EDITOR — rooftop trees, bushes, grass and shrubs (data/objects.json + sprite PNG)", 9, Color(0.6, 0.82, 0.62))
	title.position = Vector2(8, 4)
	add_child(title)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_top = 18
	root.offset_right = -8
	root.offset_bottom = -8
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", UITheme.steel_panel())
	sp.custom_minimum_size = Vector2(176, 0)
	root.add_child(sp)
	var sscroll := ScrollContainer.new()
	sscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.add_child(sscroll)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sscroll.add_child(sv)
	sv.add_child(UITheme.label("SETTINGS", 8, Color(0.6, 0.82, 0.62)))
	var row1 := HBoxContainer.new()
	id_edit = _edit("id")
	name_edit = _edit("Name")
	row1.add_child(id_edit)
	row1.add_child(name_edit)
	sv.add_child(row1)
	type_option = OptionButton.new()
	type_option.add_theme_font_size_override("font_size", 8)
	for t in FLORA_TYPES:
		type_option.add_item(t)
	sv.add_child(type_option)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 2)
	w_spin = _spin(1, MAX_W, 2, "W")
	h_spin = _spin(1, MAX_H, 3, "H")
	weight_spin = _spin(0, 99, 4, "Wt")
	tier_spin = _spin(0, 3, 0, "Tool")
	skill_spin = _spin(0, 5, 0, "Skill")
	time_spin = _spin(0.5, 20, 1.5, "Time")
	xp_spin = _spin(0, 30, 2, "XP")
	flora_weight_spin = _spin(1, 9, 1, "Spawn")
	for arr in [["Width", w_spin], ["Height", h_spin], ["Weight", weight_spin], ["Tool tier", tier_spin],
			["Skill", skill_spin], ["Scrap s", time_spin], ["XP", xp_spin], ["Spawn wt", flora_weight_spin]]:
		g.add_child(UITheme.label(arr[0], 8))
		g.add_child(arr[1])
	sv.add_child(g)
	w_spin.value_changed.connect(func(_v): _resize_canvas())
	h_spin.value_changed.connect(func(_v): _resize_canvas())
	sv.add_child(UITheme.label("Growth (leave empty = final stage)", 8, Color(0.6, 0.82, 0.62)))
	grow_edit = _edit("grows into id")
	grow_edit.custom_minimum_size = Vector2(120, 0)
	sv.add_child(grow_edit)
	var grow_row := HBoxContainer.new()
	grow_row.add_theme_constant_override("separation", 4)
	grow_row.add_child(UITheme.label("Nightly chance", 8))
	grow_chance_spin = SpinBox.new()
	grow_chance_spin.min_value = 0.05
	grow_chance_spin.max_value = 1.0
	grow_chance_spin.step = 0.05
	grow_chance_spin.value = 0.5
	grow_chance_spin.get_line_edit().add_theme_font_size_override("font_size", 8)
	grow_chance_spin.custom_minimum_size = Vector2(56, 0)
	grow_row.add_child(grow_chance_spin)
	sv.add_child(grow_row)
	no_item_check = CheckBox.new()
	no_item_check.text = "No item form (harvest only)"
	no_item_check.add_theme_font_size_override("font_size", 8)
	sv.add_child(no_item_check)
	sv.add_child(UITheme.label("Yields (item / min / max)", 8, Color(0.6, 0.82, 0.62)))
	yields_box = VBoxContainer.new()
	yields_box.add_theme_constant_override("separation", 1)
	sv.add_child(yields_box)
	sv.add_child(_button("+ add yield", func():
		def.yields.append({"item": "wood", "min": 1, "max": 2})
		_rebuild_yields()))
	var lrow := HBoxContainer.new()
	lrow.add_child(_button("New", func():
		def = _default_def()
		_new_image()
		_sync_to_ui()
		_prefill_flora()))
	load_option = OptionButton.new()
	load_option.add_theme_font_size_override("font_size", 8)
	load_option.item_selected.connect(_load_selected)
	load_option.custom_minimum_size = Vector2(70, 0)
	lrow.add_child(load_option)
	sv.add_child(lrow)
	sv.add_child(_button("SAVE / EXPORT", _save))
	status_label = UITheme.label("", 8, Color(0.75, 0.95, 0.75))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(status_label)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	root.add_child(mid)
	tool_label = UITheme.label("Tool: pencil  (LMB paint · RMB erase)", 8, Color(0.7, 0.85, 0.72))
	tool_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(tool_label)
	# Tall sprites (a mature tree is 16 blocks) scroll inside the column.
	var cscroll := ScrollContainer.new()
	cscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(cscroll)
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(MAX_W * 16 * PX, MAX_H * 16 * PX)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_canvas_input)
	cscroll.add_child(canvas)

	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", UITheme.steel_panel())
	root.add_child(pp)
	var pscroll := ScrollContainer.new()
	pscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pp.add_child(pscroll)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pscroll.add_child(pv)
	pv.add_child(UITheme.label("TOOLS", 8, Color(0.6, 0.82, 0.62)))
	pv.add_child(_button("Pencil", func(): _set_tool("pencil")))
	pv.add_child(_button("Eraser", func(): _set_tool("eraser")))
	pv.add_child(_button("Fill", func(): _set_tool("fill")))
	pv.add_child(_button("Plant prefill", _prefill_flora))
	pv.add_child(_button("Clear", func():
		image.fill(Color(0, 0, 0, 0))
		_dirty()))
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 4)
	brow.add_child(UITheme.label("Brush", 8))
	brush_swatch = ColorRect.new()
	brush_swatch.custom_minimum_size = Vector2(14, 14)
	brush_swatch.color = brush
	brow.add_child(brush_swatch)
	var picker := ColorPickerButton.new()
	picker.text = "Custom…"
	picker.add_theme_font_size_override("font_size", 8)
	picker.custom_minimum_size = Vector2(56, 14)
	picker.color = brush
	picker.color_changed.connect(func(c):
		brush = c
		brush_swatch.color = c)
	brow.add_child(picker)
	pv.add_child(brow)
	pv.add_child(UITheme.label("MATERIALS", 8, Color(0.6, 0.82, 0.62)))
	for ramp in PALETTE:
		pv.add_child(_swatch_row(ramp[1]))
	pv.add_child(UITheme.label("ACCENTS", 8, Color(0.6, 0.82, 0.62)))
	for hue: float in ACCENT_HUES:
		var colors: Array[Color] = []
		for shade in ACCENT_SHADES:
			colors.append(Color.from_hsv(hue, shade[0], shade[1]))
		pv.add_child(_swatch_row(colors))

func _swatch_row(colors: Array) -> HBoxContainer:
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 1)
	for col: Color in colors:
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(13, 12)
		sw.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sw.add_theme_stylebox_override("normal", sb)
		sw.add_theme_stylebox_override("hover", sb)
		sw.add_theme_stylebox_override("pressed", sb)
		sw.pressed.connect(func():
			brush = col
			brush_swatch.color = col)
		srow.add_child(sw)
	return srow

func _edit(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.add_theme_font_size_override("font_size", 8)
	e.custom_minimum_size = Vector2(76, 0)
	return e

func _spin(minv: float, maxv: float, val: float, _tip: String) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = 0.5 if maxv <= 20 and minv >= 0.5 else 1
	s.value = val
	s.get_line_edit().add_theme_font_size_override("font_size", 8)
	s.custom_minimum_size = Vector2(52, 0)
	return s

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 14)
	UITheme.style_button(b)
	b.pressed.connect(cb)
	return b

func _set_tool(mode: String) -> void:
	tool_mode = mode
	tool_label.text = "Tool: " + mode + "  (LMB paint · RMB erase)"

func _say(text: String) -> void:
	status_label.text = text

func _rebuild_yields() -> void:
	for c in yields_box.get_children():
		c.queue_free()
	for y in def.yields:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var item := OptionButton.new()
		item.add_theme_font_size_override("font_size", 8)
		for it in YIELD_ITEMS:
			item.add_item(it)
		item.selected = maxi(YIELD_ITEMS.find(y.item), 0)
		item.item_selected.connect(func(i): y.item = YIELD_ITEMS[i])
		row.add_child(item)
		var mn := _spin(0, 60, int(y.min), "")
		mn.value_changed.connect(func(v): y.min = int(v))
		row.add_child(mn)
		var mx := _spin(0, 60, int(y.max), "")
		mx.value_changed.connect(func(v): y.max = int(v))
		row.add_child(mx)
		var del := _button("x", func():
			def.yields.erase(y)
			_rebuild_yields())
		del.custom_minimum_size = Vector2(16, 14)
		row.add_child(del)
		yields_box.add_child(row)

# --- Canvas ---

func _resize_canvas() -> void:
	var old := image
	def.size = [int(w_spin.value), int(h_spin.value)]
	_new_image()
	image.blit_rect(old, Rect2i(Vector2i.ZERO, old.get_size()), Vector2i.ZERO)
	_dirty()

## Starting shape: a bark stem with an outlined leafy blob on top.
func _prefill_flora() -> void:
	var w := image.get_width()
	var h := image.get_height()
	image.fill(Color(0, 0, 0, 0))
	var cx := w / 2
	for y in range(h - maxi(h / 3, 4), h):
		image.set_pixel(cx, y, Color8(120, 82, 50))
		if cx > 0:
			image.set_pixel(cx - 1, y, Color8(94, 62, 38))
	var ry := maxi(h / 3, 4)
	var rx := maxi(w / 2 - 1, 3)
	var cyc := maxi(h / 3, 4)
	for x in range(w):
		for y in range(h):
			var dx := float(x - cx) / maxf(rx, 1.0)
			var dy := float(y - cyc) / maxf(ry, 1.0)
			var d2 := dx * dx + dy * dy
			if d2 <= 1.0:
				image.set_pixel(x, y, Color8(18, 34, 22) if d2 > 0.78 else Color8(74, 136, 78))
	_dirty()

func _dirty() -> void:
	if texture == null or texture.get_size() != Vector2(image.get_size()):
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	canvas.queue_redraw()

func _px_at(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / PX), floori(pos.y / PX))

func _in_image(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height()

func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_px = _px_at(event.position)
		if _in_image(hover_px):
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_apply(hover_px, false)
			elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
				_apply(hover_px, true)
		canvas.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var p := _px_at(event.position)
		if _in_image(p):
			_apply(p, event.button_index == MOUSE_BUTTON_RIGHT)

func _apply(p: Vector2i, erase: bool) -> void:
	if erase or tool_mode == "eraser":
		image.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
	elif tool_mode == "fill":
		_flood_fill(p, image.get_pixel(p.x, p.y), brush)
	else:
		image.set_pixel(p.x, p.y, brush)
	_dirty()

func _flood_fill(start: Vector2i, from: Color, to: Color) -> void:
	if from.is_equal_approx(to):
		return
	var stack := [start]
	var guard := 0
	while not stack.is_empty() and guard < 32768:
		guard += 1
		var p: Vector2i = stack.pop_back()
		if not _in_image(p) or not image.get_pixel(p.x, p.y).is_equal_approx(from):
			continue
		image.set_pixel(p.x, p.y, to)
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.UP)
		stack.append(p + Vector2i.DOWN)

func _draw_canvas() -> void:
	var w := image.get_width()
	var h := image.get_height()
	for x in range(0, w):
		for y in range(0, h):
			if (x + y) % 2 == 0:
				canvas.draw_rect(Rect2(x * PX, y * PX, PX, PX), Color(0.16, 0.2, 0.18))
	canvas.draw_rect(Rect2(0, 0, w * PX, h * PX), Color(0.13, 0.16, 0.14), false)
	if texture != null:
		canvas.draw_texture_rect(texture, Rect2(0, 0, w * PX, h * PX), false)
	for bx in range(0, w + 1, 16):
		canvas.draw_line(Vector2(bx * PX, 0), Vector2(bx * PX, h * PX), Color(1, 1, 1, 0.18))
	for by in range(0, h + 1, 16):
		canvas.draw_line(Vector2(0, by * PX), Vector2(w * PX, by * PX), Color(1, 1, 1, 0.18))
	if _in_image(hover_px):
		canvas.draw_rect(Rect2(hover_px.x * PX, hover_px.y * PX, PX, PX), Color(1, 1, 0.6, 0.7), false)

# --- Sync + library I/O ---

func _sync_to_ui() -> void:
	id_edit.text = def.id
	name_edit.text = def.name
	type_option.selected = maxi(FLORA_TYPES.find(def.get("room_type", "tree")), 0)
	w_spin.set_value_no_signal(int(def.size[0]))
	h_spin.set_value_no_signal(int(def.size[1]))
	weight_spin.value = float(def.get("weight", 4))
	tier_spin.value = int(def.get("tool_tier", 0))
	skill_spin.value = int(def.get("skill", 0))
	time_spin.value = float(def.get("scrap_time", 1.5))
	xp_spin.value = int(def.get("xp", 2))
	flora_weight_spin.value = maxi(int(def.get("flora_weight", 1)), 1)
	grow_edit.text = String(def.get("grows_into", ""))
	grow_chance_spin.value = float(def.get("grow_chance", 0.5))
	no_item_check.button_pressed = bool(def.get("no_item", false))
	_rebuild_yields()
	_dirty()

func _apply_ui() -> void:
	def.id = id_edit.text.strip_edges()
	def.name = name_edit.text.strip_edges()
	def.kind = "scrap"
	def.category = "flora"
	def.zones = ["roof"]
	def.room_type = FLORA_TYPES[type_option.selected]
	def.size = [int(w_spin.value), int(h_spin.value)]
	def.weight = weight_spin.value
	def.tool_tier = int(tier_spin.value)
	def.skill = int(skill_spin.value)
	def.scrap_time = time_spin.value
	def.xp = int(xp_spin.value)
	def.flora_weight = int(flora_weight_spin.value)
	var grow := grow_edit.text.strip_edges()
	if grow == "":
		def.erase("grows_into")
		def.erase("grow_chance")
	else:
		def["grows_into"] = grow
		def["grow_chance"] = grow_chance_spin.value
	if no_item_check.button_pressed:
		def["no_item"] = true
	else:
		def.erase("no_item")

func _read_library() -> Dictionary:
	var parsed = null
	if FileAccess.file_exists(objects_path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(objects_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = {"_comment": "World objects.", "objects": []}
	return parsed

## Only flora shows in the load list — this editor's lane.
func _refresh_load_list() -> void:
	load_option.clear()
	load_option.add_item("— load —")
	for o in _read_library().objects:
		if o.get("category", "") == "flora":
			load_option.add_item(o.id)

func _load_selected(index: int) -> void:
	if index <= 0:
		return
	var lib := _read_library()
	for o in lib.objects:
		if o.id == load_option.get_item_text(index):
			def = o.duplicate(true)
			def["zones"] = def.get("zones", ["roof"])
			def["yields"] = def.get("yields", [])
			_new_image()
			if def.has("sheet"):
				# Pack-authored flora (roof_gear trees): extract to edit; a
				# save rebinds it to a standalone PNG.
				var sheet := Image.load_from_file(ProjectSettings.globalize_path(def.sheet))
				if sheet != null:
					var r: Array = def.rect
					image = sheet.get_region(Rect2i(r[0], r[1], r[2], r[3]))
					image.convert(Image.FORMAT_RGBA8)
			else:
				var sprite_file: String = sprites_dir + def.id + ".png"
				if FileAccess.file_exists(sprite_file):
					var loaded := Image.load_from_file(ProjectSettings.globalize_path(sprite_file))
					if loaded != null:
						image = loaded
						image.convert(Image.FORMAT_RGBA8)
			_sync_to_ui()
			_say("Loaded " + def.id)
			return

func _save() -> void:
	_apply_ui()
	if def.id == "":
		_say("Give the plant an id first")
		return
	var grow: String = def.get("grows_into", "")
	if grow != "" and grow == def.id:
		_say("A plant cannot grow into itself")
		return
	# The sprite becomes a standalone PNG: drop any stale sheet binding so
	# Data.object_texture reads the exported file.
	def.erase("sheet")
	def.erase("rect")
	var lib := _read_library()
	if grow != "":
		var known := false
		for o in lib.objects:
			if o.id == grow:
				known = true
		if not known:
			_say("Warning: grows-into '%s' is not in the library yet" % grow)
	var replaced := false
	for i in lib.objects.size():
		if lib.objects[i].id == def.id:
			lib.objects[i] = def.duplicate(true)
			replaced = true
	if not replaced:
		lib.objects.append(def.duplicate(true))
	var f := FileAccess.open(objects_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(lib, " ") + "\n")
	f.close()
	image.save_png(ProjectSettings.globalize_path(sprites_dir + def.id + ".png"))
	_refresh_load_list()
	_say("%s %s + sprite — the roof sprinkle picks it up next world (weight %d)" %
		["Updated" if replaced else "Exported", def.id, int(def.flora_weight)])
