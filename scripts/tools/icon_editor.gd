extends Control
## Icon Editor: repaint the 32x32 icons of materials, tools, weapons,
## armor and every other icon-bearing item (user request 2026-09-01).
## Run standalone:
##   godot --path . res://scenes/tools/icon_editor.tscn
##
## Left: the material list and SAVE. Center: a 16x16 pixel canvas (16x zoom,
## hot-pink checker = transparency; LMB primary colour, RMB secondary, MMB
## clears). Right: TileArt ramps + accents. Save writes
## assets/sprites/icons/<id>.png and flags the item `authored_icon` in
## data/items.json - the game then loads that PNG raw (import-cache-proof)
## everywhere icons appear: bags, hotbar, hover cards, the gain feed.
## gen_placeholder_art's sheet never overrides an authored icon.

const ICON := 32 # icon side (user request 2026-09-01: match the sheet's detail)
const PX := 8 # canvas zoom (32x32 icon -> 256 px)
const SHEET := "res://assets/sprites/items.png"

const PALETTE := [
	["Wood", [Color8(40, 26, 14), Color8(94, 62, 38), Color8(120, 82, 50), Color8(146, 104, 66), Color8(168, 126, 86), Color8(192, 152, 108)]],
	["Metal", [Color8(22, 28, 36), Color8(60, 70, 82), Color8(80, 92, 106), Color8(100, 114, 130), Color8(120, 136, 152), Color8(154, 170, 186)]],
	["Stone", [Color8(30, 28, 26), Color8(66, 64, 62), Color8(90, 88, 86), Color8(114, 112, 110), Color8(138, 136, 134), Color8(166, 164, 162)]],
	["Plastic", [Color8(20, 44, 32), Color8(54, 100, 74), Color8(70, 126, 92), Color8(90, 150, 110), Color8(112, 172, 130), Color8(142, 196, 156)]],
]
const ACCENT_HUES := [0.0, 0.07, 0.13, 0.3, 0.5, 0.62, 0.76, 0.9]
const ACCENT_SHADES := [[0.8, 0.32], [0.85, 0.5], [0.78, 0.68], [0.68, 0.85], [0.5, 0.95], [0.25, 1.0]]

var items_path := "res://data/items.json"
var icons_dir := "res://assets/sprites/icons/"
var current_id := ""
var image: Image
var texture: ImageTexture
var brush := Color8(120, 82, 50)
var brush2 := Color8(40, 26, 14)
var tool_mode := "pencil" # pencil | eraser | fill
var hover_px := Vector2i(-1, -1)
var sel_a := Vector2i(-1, -1) # selection anchor / end (Select tool drag)
var sel_b := Vector2i(-1, -1)
var clipboard: Image = null
var _clip_tex: ImageTexture = null
var pasting := false

var canvas: Control
var load_option: OptionButton
var status_label: Label
var tool_label: Label
var brush_swatch: ColorRect
var brush2_swatch: ColorRect

func _ready() -> void:
	image = Image.create(ICON, ICON, false, Image.FORMAT_RGBA8)
	_build_ui()
	_mount_pause_menu()
	_refresh_load_list()

func _mount_pause_menu() -> void:
	var pm: CanvasLayer = load("res://scripts/ui/pause_menu.gd").new()
	pm.custom_controls = [
		["Paint pixel", "LMB primary · RMB secondary"],
		["Erase pixel", "MMB click · or the Eraser tool"],
		["Pick colour", "Swatches · Custom… opens a picker"],
		["Save", "SAVE / EXPORT → icons/<id>.png + items.json"],
		["Select / move", "Select drag · Copy / Cut / Paste (LMB stamps, RMB stops)"],
		["Menu", "Esc"],
	]
	pm.hint_text = "Unsaved icon edits are lost on quit — SAVE / EXPORT first"
	pm.quit_text = "QUIT GAME"
	pm.quit_callable = _quit_game
	add_child(pm)

## Editors are standalone tools: Esc quits the app outright.
func _quit_game() -> void:
	get_tree().quit()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := UITheme.label("ICON EDITOR — material icons for bags, hover cards and the gain feed (assets/sprites/icons/)", 9, Color(0.85, 0.78, 0.5))
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
	sp.custom_minimum_size = Vector2(160, 0)
	root.add_child(sp)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 3)
	sp.add_child(sv)
	sv.add_child(UITheme.label("ITEM (by category)", 8, Color(0.85, 0.78, 0.5)))
	load_option = OptionButton.new()
	load_option.tooltip_text = "Pick any icon-bearing item - materials, tools, weapons, armor, ammo, consumables."
	load_option.add_theme_font_size_override("font_size", 8)
	load_option.item_selected.connect(_load_selected)
	sv.add_child(load_option)
	sv.add_child(_button("Reload current", func(): _load_id(current_id),
		"Discard canvas changes and reload the saved icon."))
	sv.add_child(_button("SAVE / EXPORT", _save,
		"Write icons/<id>.png + flag authored_icon in data/items.json. Every icon spot in the game uses it immediately."))
	status_label = UITheme.label("", 8, Color(0.75, 0.95, 0.75))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(150, 0)
	sv.add_child(status_label)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	root.add_child(mid)
	tool_label = UITheme.label("Tool: pencil  (LMB primary · RMB secondary · MMB clears)", 8, Color(0.85, 0.82, 0.7))
	tool_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(tool_label)
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(ICON * PX, ICON * PX)
	canvas.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	canvas.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_canvas_input)
	mid.add_child(canvas)

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
	pv.add_child(UITheme.label("TOOLS", 8, Color(0.85, 0.78, 0.5)))
	pv.add_child(_button("Pencil", func(): _set_tool("pencil"), "Paint pixels: LMB primary colour, RMB secondary."))
	pv.add_child(_button("Eraser", func(): _set_tool("eraser"), "Clicks clear pixels (MMB click also clears in any tool)."))
	pv.add_child(_button("Fill", func(): _set_tool("fill"), "Flood-fill the clicked colour region."))
	pv.add_child(_button("Select", func(): _set_tool("select"), "Drag a rectangle over the pixels to move or duplicate."))
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 2)
	crow.add_child(_button("Copy", func(): _copy_selection(false), "Copy the selected pixels."))
	crow.add_child(_button("Cut", func(): _copy_selection(true), "Copy the selection and clear it (move = Cut + Paste)."))
	crow.add_child(_button("Paste", _begin_paste, "A ghost follows the mouse: LMB stamps, RMB stops."))
	pv.add_child(crow)
	pv.add_child(_button("Clear", func():
		image.fill(Color(0, 0, 0, 0))
		_dirty(), "Wipe the whole icon transparent."))
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 4)
	brow.add_child(UITheme.label("L", 8))
	brush_swatch = ColorRect.new()
	brush_swatch.custom_minimum_size = Vector2(14, 14)
	brush_swatch.color = brush
	brow.add_child(brush_swatch)
	var picker := ColorPickerButton.new()
	picker.text = "Custom..."
	picker.tooltip_text = "Primary brush - painted with LMB."
	picker.add_theme_font_size_override("font_size", 8)
	picker.custom_minimum_size = Vector2(56, 14)
	picker.color = brush
	picker.color_changed.connect(func(c):
		brush = c
		brush_swatch.color = c)
	brow.add_child(picker)
	brow.add_child(UITheme.label("R", 8))
	brush2_swatch = ColorRect.new()
	brush2_swatch.custom_minimum_size = Vector2(14, 14)
	brush2_swatch.color = brush2
	brow.add_child(brush2_swatch)
	var picker2 := ColorPickerButton.new()
	picker2.text = "..."
	picker2.tooltip_text = "Secondary brush - painted with RMB."
	picker2.add_theme_font_size_override("font_size", 8)
	picker2.custom_minimum_size = Vector2(28, 14)
	picker2.color = brush2
	picker2.color_changed.connect(func(c):
		brush2 = c
		brush2_swatch.color = c)
	brow.add_child(picker2)
	pv.add_child(brow)
	pv.add_child(UITheme.label("MATERIALS", 8, Color(0.85, 0.78, 0.5)))
	for ramp in PALETTE:
		pv.add_child(_swatch_row(ramp[1]))
	pv.add_child(UITheme.label("ACCENTS", 8, Color(0.85, 0.78, 0.5)))
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
		var c := col
		sw.pressed.connect(func():
			brush = c
			brush_swatch.color = c)
		sw.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
				brush2 = c
				brush2_swatch.color = c)
		srow.add_child(sw)
	return srow

func _button(text: String, cb: Callable, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(0, 14)
	UITheme.style_button(b)
	b.pressed.connect(cb)
	return b

func _set_tool(mode: String) -> void:
	tool_mode = mode
	pasting = false
	tool_label.text = "Tool: " + mode + "  (LMB primary · RMB secondary · MMB clears)"

func _say(text: String) -> void:
	status_label.text = text

# --- Canvas ---

func _dirty() -> void:
	if texture == null:
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	canvas.queue_redraw()

func _in_image(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < ICON and p.y < ICON

func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_px = Vector2i(event.position / PX)
		if pasting:
			canvas.queue_redraw()
			return
		if tool_mode == "select":
			if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) and _in_image(hover_px):
				sel_b = hover_px
			canvas.queue_redraw()
			return
		if _in_image(hover_px):
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_apply(hover_px, false)
			elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
				_apply(hover_px, true)
			elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
				_erase_at(hover_px)
		canvas.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var p := Vector2i(event.position / PX)
		if not _in_image(p):
			return
		if pasting:
			if event.button_index == MOUSE_BUTTON_LEFT and _in_image(p):
				_stamp_clipboard(p)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				pasting = false
				canvas.queue_redraw()
			return
		if tool_mode == "select":
			if event.button_index == MOUSE_BUTTON_LEFT and _in_image(p):
				sel_a = p
				sel_b = p
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				sel_a = Vector2i(-1, -1)
				sel_b = sel_a
			canvas.queue_redraw()
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_erase_at(p)
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_apply(p, event.button_index == MOUSE_BUTTON_RIGHT)

## LMB paints the primary colour, RMB the secondary; only the eraser tool
## (or an MMB click) clears.
func _apply(p: Vector2i, secondary: bool) -> void:
	if tool_mode == "eraser":
		image.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
	elif tool_mode == "fill":
		_flood_fill(p, image.get_pixel(p.x, p.y), brush2 if secondary else brush)
	else:
		image.set_pixel(p.x, p.y, brush2 if secondary else brush)
	_dirty()

func _erase_at(p: Vector2i) -> void:
	image.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
	_dirty()

func _flood_fill(start: Vector2i, from: Color, to: Color) -> void:
	if from.is_equal_approx(to):
		return
	var stack := [start]
	var guard := 0
	while not stack.is_empty() and guard < 1024:
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
	# hot-pink checker = transparency (matches the other pixel editors)
	canvas.draw_rect(Rect2(0, 0, ICON * PX, ICON * PX), Color(1.0, 0.25, 0.8))
	for x in ICON:
		for y in ICON:
			if (x + y) % 2 == 0:
				canvas.draw_rect(Rect2(x * PX, y * PX, PX, PX), Color(0.85, 0.15, 0.65))
	if texture != null:
		canvas.draw_texture_rect(texture, Rect2(0, 0, ICON * PX, ICON * PX), false)
	canvas.draw_rect(Rect2(0, 0, ICON * PX, ICON * PX), Color(0.5, 0.08, 0.38), false)
	var _sr := _sel_rect()
	if _sr.size.x > 0:
		canvas.draw_rect(Rect2(Vector2(_sr.position) * PX, Vector2(_sr.size) * PX), Color(1, 1, 0.4, 0.9), false)
	if pasting and _clip_tex != null and _in_image(hover_px):
		canvas.draw_texture_rect(_clip_tex, Rect2(Vector2(hover_px) * PX, _clip_tex.get_size() * PX), false, Color(1, 1, 1, 0.6))
	if _in_image(hover_px):
		canvas.draw_rect(Rect2(hover_px.x * PX, hover_px.y * PX, PX, PX), Color(1, 1, 0.6, 0.7), false)

# --- Library I/O ---

func _read_library() -> Dictionary:
	var path := items_path
	if not FileAccess.file_exists(path):
		path = "res://data/items.json" # first save starts from the shipped data
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = {"items": []}
	return parsed

## Every item that owns an icon - materials, tools, weapons, armor, ammo,
## consumables - grouped by category (user request 2026-09-01).
func _refresh_load_list() -> void:
	load_option.clear()
	load_option.add_item("— item —")
	var entries := []
	for it in _read_library().items:
		if it.has("icon") or it.get("authored_icon", false):
			entries.append([String(it.get("category", "?")), String(it.id)])
	entries.sort()
	for e in entries:
		load_option.add_item("%s · %s" % [e[0], e[1]])

func _load_selected(index: int) -> void:
	if index <= 0:
		return
	_load_id(load_option.get_item_text(index).get_slice(" · ", 1))

## The saved standalone icon when one exists, else the sheet region.
func _load_id(id: String) -> void:
	if id == "":
		return
	current_id = id
	image.fill(Color(0, 0, 0, 0))
	var standalone := icons_dir + id + ".png"
	if FileAccess.file_exists(standalone):
		var img := Image.load_from_file(ProjectSettings.globalize_path(standalone))
		if img != null:
			img.convert(Image.FORMAT_RGBA8)
			if img.get_width() != ICON:
				img.resize(ICON, ICON, Image.INTERPOLATE_NEAREST)
			image = img
	else:
		for it in _read_library().items:
			if it.id == id and it.has("icon"):
				var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
				if sheet != null:
					image = sheet.get_region(Rect2i(int(it.icon[0]) * 16, int(it.icon[1]) * 16, 16, 16))
					image.convert(Image.FORMAT_RGBA8)
					image.resize(ICON, ICON, Image.INTERPOLATE_NEAREST)
	texture = null
	_dirty()
	_say("Loaded " + id)

func _save() -> void:
	if current_id == "":
		_say("Pick a material first")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(icons_dir))
	image.save_png(ProjectSettings.globalize_path(icons_dir + current_id + ".png"))
	var lib := _read_library()
	for it in lib.items:
		if it.id == current_id:
			it["authored_icon"] = true # the game raw-loads it; sheet regens never override
	var f := FileAccess.open(items_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(lib, " ") + "\n")
	f.close()
	_say("Saved icons/%s.png — bags, hover cards and the gain feed use it now" % current_id)

# --- Select / Copy / Cut / Paste (user request 2026-09-01): drag a marquee
# with the Select tool, Cut + Paste to move sections; the paste ghost
# follows the mouse - LMB stamps (opaque pixels only), RMB stops.

func _sel_rect() -> Rect2i:
	if sel_a.x < 0:
		return Rect2i()
	var tl := Vector2i(mini(sel_a.x, sel_b.x), mini(sel_a.y, sel_b.y))
	var br := Vector2i(maxi(sel_a.x, sel_b.x), maxi(sel_a.y, sel_b.y))
	var r := Rect2i(tl, br - tl + Vector2i.ONE)
	return r.intersection(Rect2i(0, 0, image.get_width(), image.get_height()))

func _copy_selection(cut: bool) -> void:
	var r := _sel_rect()
	if r.size.x <= 0 or r.size.y <= 0:
		_say("Drag a selection first (Select tool)")
		return
	clipboard = image.get_region(r)
	_clip_tex = ImageTexture.create_from_image(clipboard)
	if cut:
		for y in r.size.y:
			for x in r.size.x:
				image.set_pixel(r.position.x + x, r.position.y + y, Color(0, 0, 0, 0))
		_dirty()
	_say("%s %dx%d px - Paste stamps it" % ["Cut" if cut else "Copied", r.size.x, r.size.y])

func _begin_paste() -> void:
	if clipboard == null:
		_say("Nothing copied yet (Select, then Copy or Cut)")
		return
	pasting = true
	_say("Paste: LMB stamps at the cursor - RMB stops")

func _stamp_clipboard(at: Vector2i) -> void:
	for y in clipboard.get_height():
		for x in clipboard.get_width():
			var c := clipboard.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var d := at + Vector2i(x, y)
			if _in_image(d):
				image.set_pixel(d.x, d.y, c)
	_dirty()
