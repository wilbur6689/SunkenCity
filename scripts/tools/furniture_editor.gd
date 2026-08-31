extends Control
## Furniture Editor: author the world objects the rooms are furnished with.
## Run standalone:  godot --path . res://scenes/tools/furniture_editor.tscn
##
## Left: settings (id, name, kind, zone applicability, size in blocks,
## weight, tool tier, skill gate, scrap time, XP) and the yields table.
## Center: a pixel canvas for the sprite (6x zoom) — pencil / eraser /
## fill / box prefill. Right: the TileArt material palette.
## Save writes data/objects.json AND assets/sprites/objects/<id>.png.

const ZONES := ["residential", "commercial", "industrial", "hospital"]
const KINDS := ["scrap", "chest", "bed", "light", "door", "pump", "breaker", "station"]
const YIELD_ITEMS := ["wood", "scrap_metal", "plastic", "cloth", "stone", "iron"]
const PX := 5 # canvas zoom
const MAX_BLOCKS := 4

## TileArt material ramps (outline, tones..., highlight).
const PALETTE := [
	["Wood", [Color8(40, 26, 14), Color8(94, 62, 38), Color8(120, 82, 50), Color8(146, 104, 66), Color8(168, 126, 86), Color8(192, 152, 108)]],
	["Metal", [Color8(22, 28, 36), Color8(60, 70, 82), Color8(80, 92, 106), Color8(100, 114, 130), Color8(120, 136, 152), Color8(154, 170, 186)]],
	["Stone", [Color8(30, 28, 26), Color8(66, 64, 62), Color8(90, 88, 86), Color8(114, 112, 110), Color8(138, 136, 134), Color8(166, 164, 162)]],
	["Plastic", [Color8(20, 44, 32), Color8(54, 100, 74), Color8(70, 126, 92), Color8(90, 150, 110), Color8(112, 172, 130), Color8(142, 196, 156)]],
]
## Accent grid: 8 hues x 6 shades (dark -> light), plus a gray row.
const ACCENT_HUES := [0.0, 0.07, 0.13, 0.3, 0.5, 0.62, 0.76, 0.9]
const ACCENT_SHADES := [[0.8, 0.32], [0.85, 0.5], [0.78, 0.68], [0.68, 0.85], [0.5, 0.95], [0.25, 1.0]] # (sat, val)

var objects_path := "res://data/objects.json"
var sprites_dir := "res://assets/sprites/objects/"
var def: Dictionary = {}
var image: Image
var texture: ImageTexture
var brush := Color8(120, 82, 50)
var tool_mode := "pencil" # pencil | eraser | fill
var hover_px := Vector2i(-1, -1)

var canvas: Control
var id_edit: LineEdit
var name_edit: LineEdit
var kind_option: OptionButton
var zone_checks: Dictionary = {}
var w_spin: SpinBox
var h_spin: SpinBox
var weight_spin: SpinBox
var tier_spin: SpinBox
var skill_spin: SpinBox
var time_spin: SpinBox
var xp_spin: SpinBox
var yields_box: VBoxContainer
var storage_check: CheckBox
var storage_slots_spin: SpinBox
var load_option: OptionButton
var status_label: Label
var tool_label: Label
var brush_swatch: ColorRect

func _ready() -> void:
	def = _default_def()
	_new_image()
	_build_ui()
	_refresh_load_list()
	_sync_to_ui()
	_prefill_box()

func _default_def() -> Dictionary:
	return {"id": "new_furniture", "name": "New Furniture", "kind": "scrap", "size": [2, 2],
		"weight": 10, "tool_tier": 0, "skill": 0, "scrap_time": 2.5, "xp": 4,
		"zones": ["residential"], "yields": [{"item": "wood", "min": 3, "max": 5}]}

func _new_image() -> void:
	image = Image.create(int(def.size[0]) * 16, int(def.size[1]) * 16, false, Image.FORMAT_RGBA8)
	texture = null

# --- UI ---

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.12, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := UITheme.label("FURNITURE EDITOR — objects for rooms and the game (data/objects.json + sprite PNG)", 9, Color(0.56, 0.75, 0.81))
	title.position = Vector2(8, 4)
	add_child(title)

	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", UITheme.steel_panel())
	sp.position = Vector2(8, 18)
	sp.custom_minimum_size = Vector2(168, 336)
	add_child(sp)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	sp.add_child(sv)
	sv.add_child(UITheme.label("SETTINGS", 8, Color(0.56, 0.75, 0.81)))
	var row1 := HBoxContainer.new()
	id_edit = _edit("id")
	name_edit = _edit("Name")
	row1.add_child(id_edit)
	row1.add_child(name_edit)
	sv.add_child(row1)
	kind_option = OptionButton.new()
	kind_option.add_theme_font_size_override("font_size", 8)
	for k in KINDS:
		kind_option.add_item(k)
	sv.add_child(kind_option)
	sv.add_child(UITheme.label("Zones (room palettes)", 8))
	var zrow := HBoxContainer.new()
	var zrow2 := HBoxContainer.new()
	for i in ZONES.size():
		var cb := CheckBox.new()
		cb.text = ZONES[i].substr(0, 5)
		cb.add_theme_font_size_override("font_size", 8)
		zone_checks[ZONES[i]] = cb
		(zrow if i < 2 else zrow2).add_child(cb)
	sv.add_child(zrow)
	sv.add_child(zrow2)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 2)
	w_spin = _spin(1, MAX_BLOCKS, 2, "W")
	h_spin = _spin(1, MAX_BLOCKS, 2, "H")
	weight_spin = _spin(1, 99, 10, "Wt")
	tier_spin = _spin(0, 3, 0, "Tool")
	skill_spin = _spin(0, 5, 0, "Skill")
	time_spin = _spin(1, 20, 3, "Time")
	xp_spin = _spin(1, 30, 4, "XP")
	for arr in [["Width", w_spin], ["Height", h_spin], ["Weight", weight_spin], ["Tool tier", tier_spin], ["Skill", skill_spin], ["Scrap s", time_spin], ["XP", xp_spin]]:
		g.add_child(UITheme.label(arr[0], 8))
		g.add_child(arr[1])
	sv.add_child(g)
	w_spin.value_changed.connect(func(_v): _resize_canvas())
	h_spin.value_changed.connect(func(_v): _resize_canvas())
	var strow := HBoxContainer.new()
	strow.add_theme_constant_override("separation", 4)
	storage_check = CheckBox.new()
	storage_check.text = "Has inventory"
	storage_check.add_theme_font_size_override("font_size", 8)
	strow.add_child(storage_check)
	storage_slots_spin = _spin(4, 20, 12, "Slots")
	strow.add_child(storage_slots_spin)
	strow.add_child(UITheme.label("slots", 8, Color(0.6, 0.66, 0.72)))
	sv.add_child(strow)
	sv.add_child(UITheme.label("Yields (item / min / max)", 8, Color(0.56, 0.75, 0.81)))
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
		_prefill_box()))
	load_option = OptionButton.new()
	load_option.add_theme_font_size_override("font_size", 8)
	load_option.item_selected.connect(_load_selected)
	load_option.custom_minimum_size = Vector2(70, 0)
	lrow.add_child(load_option)
	sv.add_child(lrow)
	sv.add_child(_button("SAVE / EXPORT", _save))
	status_label = UITheme.label("", 8, Color(0.75, 0.95, 0.75))
	sv.add_child(status_label)

	tool_label = UITheme.label("Tool: pencil  (LMB paint · RMB erase)", 8, Color(0.7, 0.78, 0.85))
	tool_label.position = Vector2(190, 22)
	add_child(tool_label)
	canvas = Control.new()
	canvas.position = Vector2(190, 40)
	canvas.custom_minimum_size = Vector2(MAX_BLOCKS * 16 * PX, MAX_BLOCKS * 16 * PX)
	canvas.size = canvas.custom_minimum_size
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_canvas_input)
	add_child(canvas)

	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", UITheme.steel_panel())
	pp.position = Vector2(522, 18)
	pp.custom_minimum_size = Vector2(0, 336)
	add_child(pp)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	pp.add_child(pv)
	pv.add_child(UITheme.label("TOOLS", 8, Color(0.56, 0.75, 0.81)))
	pv.add_child(_button("Pencil", func(): _set_tool("pencil")))
	pv.add_child(_button("Eraser", func(): _set_tool("eraser")))
	pv.add_child(_button("Fill", func(): _set_tool("fill")))
	pv.add_child(_button("Box prefill", _prefill_box))
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
	pv.add_child(UITheme.label("MATERIALS", 8, Color(0.56, 0.75, 0.81)))
	for ramp in PALETTE:
		pv.add_child(_swatch_row(ramp[1]))
	pv.add_child(UITheme.label("ACCENTS", 8, Color(0.56, 0.75, 0.81)))
	for hue: float in ACCENT_HUES:
		var colors: Array[Color] = []
		for shade in ACCENT_SHADES:
			colors.append(Color.from_hsv(hue, shade[0], shade[1]))
		pv.add_child(_swatch_row(colors))
	var grays: Array[Color] = []
	for i in 6:
		grays.append(Color.from_hsv(0.0, 0.0, 0.08 + i * 0.18))
	pv.add_child(_swatch_row(grays))

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
	s.step = 0.5 if maxv <= 20 and minv >= 1 else 1
	s.value = val
	s.add_theme_font_size_override("font_size", 8)
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
		var mn := _spin(0, 30, int(y.min), "")
		mn.value_changed.connect(func(v): y.min = int(v))
		row.add_child(mn)
		var mx := _spin(0, 30, int(y.max), "")
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

func _prefill_box() -> void:
	# A shaded box hull as a starting shape (same style the art tool uses).
	var w := image.get_width()
	var h := image.get_height()
	image.fill(Color(0, 0, 0, 0))
	for x in range(1, w - 1):
		for y in range(1, h - 1):
			image.set_pixel(x, y, Color8(120, 82, 50))
	for x in range(w):
		image.set_pixel(x, 0, Color8(40, 26, 14))
		image.set_pixel(x, h - 1, Color8(40, 26, 14))
	for y in range(h):
		image.set_pixel(0, y, Color8(40, 26, 14))
		image.set_pixel(w - 1, y, Color8(40, 26, 14))
	for x in range(1, w - 1):
		image.set_pixel(x, 1, Color8(146, 104, 66))
	for y in range(1, h - 1):
		image.set_pixel(1, y, Color8(146, 104, 66))
	_dirty()

func _dirty() -> void:
	if texture == null:
		texture = ImageTexture.create_from_image(image)
	else:
		if texture.get_size() != Vector2(image.get_size()):
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
	while not stack.is_empty() and guard < 8192:
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
	# checkerboard = transparency
	for x in range(0, w):
		for y in range(0, h):
			if (x + y) % 2 == 0:
				canvas.draw_rect(Rect2(x * PX, y * PX, PX, PX), Color(0.18, 0.2, 0.26))
	canvas.draw_rect(Rect2(0, 0, w * PX, h * PX), Color(0.14, 0.16, 0.2), false)
	if texture != null:
		canvas.draw_texture_rect(texture, Rect2(0, 0, w * PX, h * PX), false)
	# block grid (16px cells) + hover
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
	kind_option.selected = maxi(KINDS.find(def.get("kind", "scrap")), 0)
	for z in ZONES:
		zone_checks[z].button_pressed = def.get("zones", []).has(z)
	w_spin.set_value_no_signal(int(def.size[0]))
	h_spin.set_value_no_signal(int(def.size[1]))
	weight_spin.value = float(def.get("weight", 10))
	tier_spin.value = int(def.get("tool_tier", 0))
	skill_spin.value = int(def.get("skill", 0))
	time_spin.value = float(def.get("scrap_time", 2.5))
	xp_spin.value = int(def.get("xp", 4))
	var slots := int(def.get("storage_slots", def.get("slots", 0)))
	storage_check.button_pressed = def.get("kind", "") == "chest" or slots > 0
	storage_slots_spin.value = clampi(slots if slots > 0 else 12, 4, 20)
	_rebuild_yields()
	_dirty()

func _apply_ui() -> void:
	def.id = id_edit.text.strip_edges()
	def.name = name_edit.text.strip_edges()
	def.kind = KINDS[kind_option.selected]
	def.size = [int(w_spin.value), int(h_spin.value)]
	def.weight = weight_spin.value
	def.tool_tier = int(tier_spin.value)
	def.skill = int(skill_spin.value)
	def.scrap_time = time_spin.value
	def.xp = int(xp_spin.value)
	var zones := []
	for z in ZONES:
		if zone_checks[z].button_pressed:
			zones.append(z)
	def.zones = zones
	# Storage flag: chests always have it; anything else opts in (cabinets…).
	if storage_check.button_pressed:
		def["storage_slots"] = int(storage_slots_spin.value)
	else:
		def.erase("storage_slots")
	if def.kind == "light":
		def["light"] = def.get("light", {"radius_blocks": 6, "color": [1.0, 0.8, 0.55]})
	elif def.kind == "station":
		def["station"] = def.get("station", "workbench") # preserve on round-trips

func _read_library() -> Dictionary:
	var parsed = null
	if FileAccess.file_exists(objects_path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(objects_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = {"_comment": "World objects.", "objects": []}
	return parsed

func _refresh_load_list() -> void:
	load_option.clear()
	load_option.add_item("— load —")
	for o in _read_library().objects:
		load_option.add_item(o.id)

func _load_selected(index: int) -> void:
	if index <= 0:
		return
	var lib := _read_library()
	for o in lib.objects:
		if o.id == load_option.get_item_text(index):
			def = o.duplicate(true)
			def["zones"] = def.get("zones", [])
			def["yields"] = def.get("yields", [])
			_new_image()
			if def.has("sheet"):
				# Sheet-packed item (room packs): extract its region to edit.
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
		_say("Give the furniture an id first")
		return
	var lib := _read_library()
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
	_say("%s %s + sprite (%d objects)" % ["Updated" if replaced else "Exported", def.id, lib.objects.size()])
