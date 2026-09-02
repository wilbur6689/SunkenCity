extends Control
## Room Editor (CT-05 authoring workflow): create, edit, and export the room
## templates the city generator builds floors from. Run standalone:
##   godot --path . res://scenes/tools/room_editor.tscn
##
## Left: room settings (id, zone, room type, spawn depth range, size).
## Center: the room canvas — paint blocks, place/move furniture anywhere in the
## room (an object's `dy` = rows its bottom sits above the standing row; 0 = on
## the floor, omitted when 0). The generator honours dy for every object.
## Right: block picker + zone-filtered furniture palette.
## Save writes into data/rooms.json (the curated library, hand-editable).

## Room zones (user decision 2026-09-01): residential · business (small service
## firms — lawyers, accountants, agencies) · commercial (retail / office) ·
## industrial · civil (city admin, police, hospital, post office; was "hospital").
const ZONES := ["residential", "business", "commercial", "industrial", "civil", "roof"]
const ZONE_FURNITURE := {
	"residential": ["bed_frame", "cabinet", "chair", "fridge", "desk"],
	"business": ["desk", "chair", "cabinet", "locker"],
	"commercial": ["desk", "chair", "cabinet", "locker", "fridge"],
	"industrial": ["locker", "pump", "med_cart", "cabinet"],
	"civil": ["med_cart", "bed_frame", "cabinet", "locker", "chair", "desk"],
}
const BLOCK_MATS := {"stone": 1, "wood": 2, "metal": 3, "plastic": 4}
const CELL := 16
const MIN_W := 6
const MAX_W := 20
const MIN_H := 4
const MAX_H := 8
const ATLAS := preload("res://assets/tiles/placeholder_blocks.png")

var rooms_path := "res://data/rooms.json"
var room: Dictionary = {}
var tool_mode := "pointer" # pointer | erase | block:<mat> | object:<id>
var grabbed: Dictionary = {} # object being moved (removed from room while held)
var hover_cell := Vector2i(-99, -99)
var status := ""

var canvas: Control
var id_edit: LineEdit
var type_edit: LineEdit
var zone_option: OptionButton
var depth_min_spin: SpinBox
var depth_max_spin: SpinBox
var width_spin: SpinBox
var height_spin: SpinBox
var load_option: OptionButton
var furniture_box: VBoxContainer
var status_label: Label
var tool_label: Label
var _obj_textures: Dictionary = {}

func _ready() -> void:
	room = _default_room()
	_build_ui()
	_mount_pause_menu()
	_refresh_load_list()
	_refresh_furniture()
	_sync_settings_to_ui()

func _default_room() -> Dictionary:
	return {"id": "new_room", "zone": "residential", "type": "room", "width": 12, "height": 5,
		"depth_min": -9999, "depth_max": 9999, "objects": [], "blocks": []}

# --- UI construction ---

## Esc menu — the in-game pause menu (sound sliders, a CONTROLS page) with
## editor bindings and QUIT TO TITLE in place of Save & Quit.
func _mount_pause_menu() -> void:
	var pm: CanvasLayer = load("res://scripts/ui/pause_menu.gd").new()
	pm.custom_controls = [
		["Paint block", "LMB (drag) with a block tool"],
		["Place furniture", "LMB · bottom row sits on the clicked cell"],
		["Move furniture", "Pointer tool: click to grab, click to drop"],
		["Erase", "RMB · or the Erase tool"],
		["Room size / depth", "Settings panel spinners"],
		["Save", "SAVE / EXPORT → data/rooms.json"],
		["Menu", "Esc"],
	]
	pm.hint_text = "Unsaved rooms are lost on quit — SAVE / EXPORT first"
	pm.quit_text = "QUIT GAME"
	pm.quit_callable = _quit_game
	add_child(pm)

## Editors are standalone tools (user request 2026-09-01): Esc quits the
## app outright instead of returning to the title screen.
func _quit_game() -> void:
	get_tree().quit()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.12, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UITheme.label("ROOM EDITOR — templates for the city generator (data/rooms.json)", 9, Color(0.56, 0.75, 0.81))
	title.position = Vector2(8, 4)
	add_child(title)

	# Three columns in an HBox so the panels can never paint over the canvas
	# (they grow with their contents; fixed x positions did not follow).
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_top = 18
	root.offset_right = -8
	root.offset_bottom = -8
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Left: settings
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", UITheme.steel_panel())
	sp.custom_minimum_size = Vector2(140, 0)
	sp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(sp)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 3)
	sp.add_child(sv)
	sv.add_child(UITheme.label("SETTINGS", 8, Color(0.56, 0.75, 0.81)))
	sv.add_child(UITheme.label("Room id", 8))
	id_edit = LineEdit.new()
	id_edit.tooltip_text = "Unique room template id (lowercase_snake_case)."
	id_edit.add_theme_font_size_override("font_size", 8)
	sv.add_child(id_edit)
	sv.add_child(UITheme.label("Zone", 8))
	zone_option = OptionButton.new()
	zone_option.tooltip_text = "Zone pool the generator draws this room from (roof templates stamp on tower tops)."
	zone_option.add_theme_font_size_override("font_size", 8)
	for z in ZONES:
		zone_option.add_item(z)
	zone_option.item_selected.connect(func(_i): _apply_settings(); _refresh_furniture(); _refresh_load_list())
	sv.add_child(zone_option)
	sv.add_child(UITheme.label("Room type", 8))
	type_edit = LineEdit.new()
	type_edit.add_theme_font_size_override("font_size", 8)
	type_edit.placeholder_text = "bedroom, ward, office…"
	type_edit.tooltip_text = "Free-form descriptive tag; not used for selection (zone + depth are)."
	sv.add_child(type_edit)
	sv.add_child(UITheme.label("Depth range (blocks below", 8))
	sv.add_child(UITheme.label("waterline; -9999 = any)", 8, Color(0.6, 0.66, 0.72)))
	depth_min_spin = _spin(-9999, 9999, 0, "Shallowest spawn depth in blocks below the waterline (-9999 = anywhere, negative = above water).")
	depth_max_spin = _spin(-9999, 9999, 9999, "Deepest spawn depth in blocks below the waterline (9999 = anywhere). Iron-bearing rooms stay >= 40 (GL-28).")
	var dh := HBoxContainer.new()
	dh.add_child(depth_min_spin)
	dh.add_child(depth_max_spin)
	sv.add_child(dh)
	sv.add_child(UITheme.label("Size (width x height)", 8))
	width_spin = _spin(MIN_W, MAX_W, 12, "Interior width in cells - rooms tile side by side across a tower wing.")
	width_spin.value_changed.connect(func(_v): _apply_settings())
	height_spin = _spin(MIN_H, MAX_H, 5, "Interior height in cells (tower floors hold 5).")
	height_spin.value_changed.connect(func(_v): _apply_settings())
	var sh := HBoxContainer.new()
	sh.add_child(width_spin)
	sh.add_child(height_spin)
	sv.add_child(sh)
	sv.add_child(UITheme.label(" ", 6))
	var new_btn := _button("New room", func():
		room = _default_room()
		_sync_settings_to_ui()
		_say("New room"), "Start a fresh template (unsaved changes are lost).")
	sv.add_child(new_btn)
	sv.add_child(UITheme.label("Load existing", 8))
	load_option = OptionButton.new()
	load_option.add_theme_font_size_override("font_size", 8)
	load_option.tooltip_text = "Load an existing room of the selected zone."
	load_option.item_selected.connect(_load_selected)
	sv.add_child(load_option)
	var save_btn := _button("SAVE / EXPORT", _save, "Write this template into data/rooms.json - the generator uses it in the next world.")
	sv.add_child(save_btn)
	status_label = UITheme.label("", 8, Color(0.75, 0.95, 0.75))
	sv.add_child(status_label)

	# Center: tool readout over the canvas
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	root.add_child(mid)
	tool_label = UITheme.label("Tool: pointer  (LMB use tool · RMB erase · pointer grabs furniture)", 8, Color(0.7, 0.78, 0.85))
	tool_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(tool_label)
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2((MAX_W + 4) * CELL, (MAX_H + 4) * CELL)
	canvas.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	canvas.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_canvas_input)
	mid.add_child(canvas)

	# Right: palettes
	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", UITheme.steel_panel())
	pp.custom_minimum_size = Vector2(124, 0)
	root.add_child(pp) # fills the column height; the list inside scrolls
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pp.add_child(scroll)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pv)
	pv.add_child(UITheme.label("BLOCKS", 8, Color(0.56, 0.75, 0.81)))
	var pointer := _button("Pointer / move", func(): _set_tool("pointer"), "Grab and move furniture: click to grab, click again to drop.")
	pv.add_child(pointer)
	for mat_name in BLOCK_MATS:
		var m: int = BLOCK_MATS[mat_name]
		pv.add_child(_button(mat_name.capitalize(), func(): _set_tool("block:%d" % m), "Paint " + mat_name + " blocks (LMB drag). Counters, shelves, obstacles."))
	pv.add_child(_button("Erase", func(): _set_tool("erase"), "Clicks remove blocks and furniture (RMB also erases in any tool)."))
	pv.add_child(UITheme.label(" ", 4))
	pv.add_child(UITheme.label("FURNITURE (zone)", 8, Color(0.56, 0.75, 0.81)))
	furniture_box = VBoxContainer.new()
	furniture_box.add_theme_constant_override("separation", 2)
	pv.add_child(furniture_box)

func _spin(minv: int, maxv: int, val: int, tip: String = "") -> SpinBox:
	var s := SpinBox.new()
	s.tooltip_text = tip
	s.min_value = minv
	s.max_value = maxv
	s.value = val
	# The override must land on the inner LineEdit — SpinBox's own theme
	# overrides do not propagate to it, so it would render at the default 16px.
	s.get_line_edit().add_theme_font_size_override("font_size", 8)
	s.get_line_edit().tooltip_text = tip
	s.custom_minimum_size = Vector2(56, 0)
	return s

func _button(text: String, cb: Callable, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(0, 15)
	UITheme.style_button(b)
	b.pressed.connect(cb)
	return b

func _set_tool(mode: String) -> void:
	tool_mode = mode
	grabbed = {}
	tool_label.text = "Tool: " + mode
	canvas.queue_redraw()

func _say(text: String) -> void:
	status = text
	status_label.text = text

func _refresh_furniture() -> void:
	for c in furniture_box.get_children():
		c.queue_free()
	# Furniture declares its own zones (authored in the Furniture Editor);
	# ZONE_FURNITURE is the fallback for pieces without zone tags.
	var ids := []
	for oid in Data.objects:
		var d: Dictionary = Data.objects[oid]
		if d.get("fixed", false) or d.get("no_item", false) or d.kind == "station" or d.kind == "breaker":
			continue
		var zones: Array = d.get("zones", [])
		if (zones.has(_zone())) or (zones.is_empty() and ZONE_FURNITURE.get(_zone(), []).has(oid)):
			ids.append(oid)
	ids.sort()
	for oid in ids:
		var def: Dictionary = Data.objects[oid]
		furniture_box.add_child(_button("%s (%dx%d)" % [def.name, def.size[0], def.size[1]],
			func(): _set_tool("object:" + oid), "Place: LMB drops it with its bottom row on the clicked cell (any height - the generator honours it)."))

func _zone() -> String:
	return ZONES[zone_option.selected]

# --- Settings sync ---

func _sync_settings_to_ui() -> void:
	id_edit.text = room.id
	type_edit.text = room.get("type", "")
	zone_option.selected = maxi(ZONES.find(room.get("zone", "residential")), 0)
	depth_min_spin.value = room.get("depth_min", -9999)
	depth_max_spin.value = room.get("depth_max", 9999)
	width_spin.value = room.width
	height_spin.value = room.get("height", 5)
	_refresh_furniture()
	_refresh_load_list()
	canvas.queue_redraw()

func _apply_settings() -> void:
	room.id = id_edit.text.strip_edges()
	room.type = type_edit.text.strip_edges()
	room.zone = _zone()
	room.depth_min = int(depth_min_spin.value)
	room.depth_max = int(depth_max_spin.value)
	room.width = int(width_spin.value)
	room.height = int(height_spin.value)
	# Clip content that fell outside after a resize
	room.objects = room.objects.filter(func(o): return _fits_object(o.id, int(o.x), o, int(o.get("dy", 0))))
	room.blocks = room.blocks.filter(func(b): return int(b.x) < room.width and int(b.dy) < room.height)
	canvas.queue_redraw()

# --- Canvas geometry: origin at the room's top-left interior cell ---

func _origin() -> Vector2:
	return Vector2(2 * CELL, 2 * CELL)

func _cell_at(pos: Vector2) -> Vector2i:
	var p := (pos - _origin()) / CELL
	return Vector2i(floori(p.x), floori(p.y))

func _standing_row() -> int:
	return room.height - 1 # dy 0 = standing row (bottom interior row)

## Any object goes anywhere inside the room: its footprint (w×h, bottom at dy
## rows above the standing row) must lie within the interior and overlap no
## other object and no painted block.
func _fits_object(oid: String, x: int, ignore = null, dy: int = 0) -> bool:
	var def: Dictionary = Data.objects.get(oid, {})
	if def.is_empty():
		return false
	var w := int(def.size[0])
	var h := int(def.size[1])
	if x < 0 or x + w > int(room.width):
		return false
	if dy < 0 or dy + h > int(room.height):
		return false
	for o in room.objects:
		if o == ignore:
			continue
		var od: Dictionary = Data.objects[o.id]
		var ody := int(o.get("dy", 0))
		if x < int(o.x) + int(od.size[0]) and int(o.x) < x + w \
				and dy < ody + int(od.size[1]) and ody < dy + h:
			return false
	for b in room.blocks:
		if int(b.x) >= x and int(b.x) < x + w and int(b.dy) >= dy and int(b.dy) < dy + h:
			return false
	return true

## Object entry for the library: dy is stored only when lifted off the floor.
func _object_entry(oid: String, x: int, dy: int) -> Dictionary:
	var entry := {"id": oid, "x": x}
	if dy != 0:
		entry["dy"] = dy
	return entry

func _block_at(x: int, dy: int):
	for b in room.blocks:
		if int(b.x) == x and int(b.dy) == dy:
			return b
	return null

func _object_at_x(x: int):
	for o in room.objects:
		var w := int(Data.objects[o.id].size[0])
		if x >= int(o.x) and x < int(o.x) + w:
			return o
	return null

# --- Canvas input ---

func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_cell = _cell_at(event.position)
		canvas.queue_redraw()
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT and tool_mode.begins_with("block:"):
			_paint(hover_cell)
	elif event is InputEventMouseButton and event.pressed:
		var cell := _cell_at(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			_use_tool(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_erase(cell)
		canvas.queue_redraw()

func _in_room(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < int(room.width) and cell.y >= 0 and cell.y < int(room.height)

func _use_tool(cell: Vector2i) -> void:
	if tool_mode.begins_with("block:"):
		_paint(cell)
	elif tool_mode == "erase":
		_erase(cell)
	elif tool_mode.begins_with("object:"):
		var oid := tool_mode.substr(7)
		var dy := _dy_at(cell)
		if _in_room(cell) and _fits_object(oid, cell.x, null, dy):
			room.objects.append(_object_entry(oid, cell.x, dy))
			_say("Placed " + oid)
	else: # pointer: grab / drop furniture (click-drag-click)
		if not grabbed.is_empty():
			var gdy := _dy_at(cell)
			if _in_room(cell) and _fits_object(grabbed.id, cell.x, null, gdy):
				room.objects.append(_object_entry(grabbed.id, cell.x, gdy))
				grabbed = {}
				_say("Moved")
		elif _in_room(cell):
			var o = _object_at_cell(cell)
			if o != null:
				grabbed = o
				room.objects.erase(o)
				_say("Grabbed %s — click to drop" % grabbed.id)

## dy for a piece dropped at `cell` (its BOTTOM row sits on that cell).
func _dy_at(cell: Vector2i) -> int:
	return _standing_row() - cell.y

## The object (floor or wall) covering this cell, if any.
func _object_at_cell(cell: Vector2i):
	for o in room.objects:
		var od: Dictionary = Data.objects[o.id]
		var w := int(od.size[0])
		var h := int(od.size[1])
		var bottom := _standing_row() - int(o.get("dy", 0))
		if cell.x >= int(o.x) and cell.x < int(o.x) + w and cell.y <= bottom and cell.y > bottom - h:
			return o
	return null

func _paint(cell: Vector2i) -> void:
	if not _in_room(cell):
		return
	var dy := _standing_row() - cell.y
	if _object_at_cell(cell) != null:
		return # occupied by furniture or wall art
	var existing = _block_at(cell.x, dy)
	var mat := int(tool_mode.substr(6))
	if existing != null:
		existing.mat = mat
	else:
		room.blocks.append({"mat": mat, "x": cell.x, "dy": dy})

func _erase(cell: Vector2i) -> void:
	if not _in_room(cell):
		return
	var dy := _standing_row() - cell.y
	var b = _block_at(cell.x, dy)
	if b != null:
		room.blocks.erase(b)
		return
	var o = _object_at_cell(cell)
	if o != null:
		room.objects.erase(o)
		_say("Removed " + o.id)

# --- Canvas drawing ---

func _draw_canvas() -> void:
	var org := _origin()
	var w := int(room.width)
	var h := int(room.height)
	# Context shell: slab below, ceiling above, walls beside (dimmed, not editable)
	var shell := Color(0.55, 0.58, 0.65, 0.55)
	for x in range(-1, w + 1):
		_draw_tile(org + Vector2(x, h) * CELL, WorldGrid.M.METAL, shell)   # floor slab
		_draw_tile(org + Vector2(x, -1) * CELL, WorldGrid.M.METAL, shell)  # ceiling
	for y in range(-1, h + 1):
		_draw_tile(org + Vector2(-1, y) * CELL, WorldGrid.M.STONE, shell)
		_draw_tile(org + Vector2(w, y) * CELL, WorldGrid.M.STONE, shell)
	# Interior background + grid
	canvas.draw_rect(Rect2(org, Vector2(w, h) * CELL), Color(0.16, 0.19, 0.25))
	for x in range(w + 1):
		canvas.draw_line(org + Vector2(x * CELL, 0), org + Vector2(x * CELL, h * CELL), Color(1, 1, 1, 0.07))
	for y in range(h + 1):
		canvas.draw_line(org + Vector2(0, y * CELL), org + Vector2(w * CELL, y * CELL), Color(1, 1, 1, 0.07))
	# Blocks
	for b in room.blocks:
		var cy := _standing_row() - int(b.dy)
		_draw_tile(org + Vector2(int(b.x), cy) * CELL, int(b.mat), Color.WHITE)
	# Furniture (bottom row at dy above the standing row)
	for o in room.objects:
		_draw_object(org, o.id, int(o.x), Color.WHITE, int(o.get("dy", 0)))
	# Ghost previews
	if tool_mode.begins_with("object:") and _in_room(hover_cell):
		var oid := tool_mode.substr(7)
		var gdy := _dy_at(hover_cell)
		var ok := _fits_object(oid, hover_cell.x, null, gdy)
		_draw_object(org, oid, hover_cell.x, Color(0.6, 1.0, 0.6, 0.55) if ok else Color(1.0, 0.5, 0.5, 0.55), gdy)
	elif not grabbed.is_empty() and _in_room(hover_cell):
		var gdy2 := _dy_at(hover_cell)
		var ok2 := _fits_object(grabbed.id, hover_cell.x, null, gdy2)
		_draw_object(org, grabbed.id, hover_cell.x, Color(0.6, 1.0, 0.6, 0.55) if ok2 else Color(1.0, 0.5, 0.5, 0.55), gdy2)
	if _in_room(hover_cell):
		canvas.draw_rect(Rect2(org + Vector2(hover_cell) * CELL, Vector2(CELL, CELL)), Color(1, 1, 0.6, 0.6), false)

func _draw_tile(pos: Vector2, mat: int, mod: Color) -> void:
	var variant := posmod(hash(Vector2i(pos / CELL)), 5)
	canvas.draw_texture_rect_region(ATLAS, Rect2(pos, Vector2(CELL, CELL)),
		Rect2(variant * 16, (mat - 1) * 16, 16, 16), mod)

func _draw_object(org: Vector2, oid: String, x: int, mod: Color, dy: int = 0) -> void:
	var def: Dictionary = Data.objects.get(oid, {})
	if def.is_empty():
		return
	if not _obj_textures.has(oid):
		_obj_textures[oid] = Data.object_texture(oid)
	var tex: Texture2D = _obj_textures[oid]
	if tex == null:
		return
	var h := int(def.size[1])
	var pos := org + Vector2(x, room.height - h - dy) * CELL
	canvas.draw_texture_rect(tex, Rect2(pos, Vector2(def.size[0] * CELL, h * CELL)), false, mod)

# --- Library I/O ---

func _read_library() -> Dictionary:
	var text := FileAccess.get_file_as_string(rooms_path)
	var parsed = JSON.parse_string(text) if text != "" else null
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = {"_comment": "Room template library (CT-04/05).", "rooms": []}
	return parsed

## Only rooms of the selected zone are listed (user request 2026-09-01: the
## full library got too long). Legacy rooms without a zone fall back to type.
func _refresh_load_list() -> void:
	load_option.clear()
	load_option.add_item("— load (%s) —" % _zone())
	for r in _read_library().rooms:
		if _room_zone(r) == _zone():
			load_option.add_item(r.id)

func _room_zone(r: Dictionary) -> String:
	var z: String = r.get("zone", r.get("type", "residential"))
	return "civil" if z == "hospital" else z

func _load_selected(index: int) -> void:
	if index <= 0:
		return
	var lib := _read_library()
	for r in lib.rooms:
		if r.id == load_option.get_item_text(index):
			room = r.duplicate(true)
			room["height"] = room.get("height", 5)
			room["zone"] = _room_zone(room)
			room["depth_min"] = room.get("depth_min", -9999)
			room["depth_max"] = room.get("depth_max", 9999)
			_sync_settings_to_ui()
			_say("Loaded " + room.id)
			return

func _save() -> void:
	_apply_settings()
	if room.id == "":
		_say("Give the room an id first")
		return
	var lib := _read_library()
	var replaced := false
	for i in lib.rooms.size():
		if lib.rooms[i].id == room.id:
			lib.rooms[i] = room.duplicate(true)
			replaced = true
	if not replaced:
		lib.rooms.append(room.duplicate(true))
	var f := FileAccess.open(rooms_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(lib, " ") + "\n")
	f.close()
	_refresh_load_list()
	_say("%s %s (%d rooms in library)" % ["Updated" if replaced else "Exported", room.id, lib.rooms.size()])
