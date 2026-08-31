extends Control
## Room Editor (CT-05 authoring workflow): create, edit, and export the room
## templates the city generator builds floors from. Run standalone:
##   godot --path . res://scenes/tools/room_editor.tscn
##
## Left: room settings (id, zone, room type, spawn depth range, size).
## Center: the room canvas — paint blocks, place/move furniture.
## Right: block picker + zone-filtered furniture palette.
## Save writes into data/rooms.json (the curated library, hand-editable).

const ZONES := ["residential", "commercial", "industrial", "hospital"]
const ZONE_FURNITURE := {
	"residential": ["bed_frame", "cabinet", "chair", "fridge", "desk"],
	"commercial": ["desk", "chair", "cabinet", "locker", "fridge"],
	"industrial": ["locker", "pump", "med_cart", "cabinet"],
	"hospital": ["med_cart", "bed_frame", "cabinet", "locker", "chair", "desk"],
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
	_refresh_load_list()
	_refresh_furniture()
	_sync_settings_to_ui()

func _default_room() -> Dictionary:
	return {"id": "new_room", "zone": "residential", "type": "room", "width": 12, "height": 5,
		"depth_min": -9999, "depth_max": 9999, "objects": [], "blocks": []}

# --- UI construction ---

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.12, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UITheme.label("ROOM EDITOR — templates for the city generator (data/rooms.json)", 9, Color(0.56, 0.75, 0.81))
	title.position = Vector2(8, 4)
	add_child(title)

	# Left: settings
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", UITheme.steel_panel())
	sp.position = Vector2(8, 18)
	sp.custom_minimum_size = Vector2(140, 330)
	add_child(sp)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 3)
	sp.add_child(sv)
	sv.add_child(UITheme.label("SETTINGS", 8, Color(0.56, 0.75, 0.81)))
	sv.add_child(UITheme.label("Room id", 8))
	id_edit = LineEdit.new()
	id_edit.add_theme_font_size_override("font_size", 8)
	sv.add_child(id_edit)
	sv.add_child(UITheme.label("Zone", 8))
	zone_option = OptionButton.new()
	zone_option.add_theme_font_size_override("font_size", 8)
	for z in ZONES:
		zone_option.add_item(z)
	zone_option.item_selected.connect(func(_i): _apply_settings(); _refresh_furniture())
	sv.add_child(zone_option)
	sv.add_child(UITheme.label("Room type", 8))
	type_edit = LineEdit.new()
	type_edit.add_theme_font_size_override("font_size", 8)
	type_edit.placeholder_text = "bedroom, ward, office…"
	sv.add_child(type_edit)
	sv.add_child(UITheme.label("Depth range (blocks below", 8))
	sv.add_child(UITheme.label("waterline; -9999 = any)", 8, Color(0.6, 0.66, 0.72)))
	depth_min_spin = _spin(-9999, 9999, 0)
	depth_max_spin = _spin(-9999, 9999, 9999)
	var dh := HBoxContainer.new()
	dh.add_child(depth_min_spin)
	dh.add_child(depth_max_spin)
	sv.add_child(dh)
	sv.add_child(UITheme.label("Size (width x height)", 8))
	width_spin = _spin(MIN_W, MAX_W, 12)
	width_spin.value_changed.connect(func(_v): _apply_settings())
	height_spin = _spin(MIN_H, MAX_H, 5)
	height_spin.value_changed.connect(func(_v): _apply_settings())
	var sh := HBoxContainer.new()
	sh.add_child(width_spin)
	sh.add_child(height_spin)
	sv.add_child(sh)
	sv.add_child(UITheme.label(" ", 6))
	var new_btn := _button("New room", func():
		room = _default_room()
		_sync_settings_to_ui()
		_say("New room"))
	sv.add_child(new_btn)
	sv.add_child(UITheme.label("Load existing", 8))
	load_option = OptionButton.new()
	load_option.add_theme_font_size_override("font_size", 8)
	load_option.item_selected.connect(_load_selected)
	sv.add_child(load_option)
	var save_btn := _button("SAVE / EXPORT", _save)
	sv.add_child(save_btn)
	status_label = UITheme.label("", 8, Color(0.75, 0.95, 0.75))
	sv.add_child(status_label)

	# Center: canvas
	canvas = Control.new()
	canvas.position = Vector2(158, 40)
	canvas.custom_minimum_size = Vector2((MAX_W + 4) * CELL, (MAX_H + 4) * CELL)
	canvas.size = canvas.custom_minimum_size
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_canvas_input)
	add_child(canvas)
	tool_label = UITheme.label("Tool: pointer  (LMB use tool · RMB erase · pointer grabs furniture)", 8, Color(0.7, 0.78, 0.85))
	tool_label.position = Vector2(158, 22)
	add_child(tool_label)

	# Right: palettes
	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", UITheme.steel_panel())
	pp.position = Vector2(508, 18)
	pp.custom_minimum_size = Vector2(124, 330)
	add_child(pp)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	pp.add_child(pv)
	pv.add_child(UITheme.label("BLOCKS", 8, Color(0.56, 0.75, 0.81)))
	var pointer := _button("Pointer / move", func(): _set_tool("pointer"))
	pv.add_child(pointer)
	for mat_name in BLOCK_MATS:
		var m: int = BLOCK_MATS[mat_name]
		pv.add_child(_button(mat_name.capitalize(), func(): _set_tool("block:%d" % m)))
	pv.add_child(_button("Erase", func(): _set_tool("erase")))
	pv.add_child(UITheme.label(" ", 4))
	pv.add_child(UITheme.label("FURNITURE (zone)", 8, Color(0.56, 0.75, 0.81)))
	furniture_box = VBoxContainer.new()
	furniture_box.add_theme_constant_override("separation", 2)
	pv.add_child(furniture_box)

func _spin(minv: int, maxv: int, val: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.value = val
	s.add_theme_font_size_override("font_size", 8)
	s.custom_minimum_size = Vector2(56, 0)
	return s

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
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
	for oid in ZONE_FURNITURE.get(_zone(), []):
		var def: Dictionary = Data.objects.get(oid, {})
		if def.is_empty():
			continue
		furniture_box.add_child(_button("%s (%dx%d)" % [def.name, def.size[0], def.size[1]],
			func(): _set_tool("object:" + oid)))

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
	room.objects = room.objects.filter(func(o): return _fits_object(o.id, int(o.x), o))
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

func _fits_object(oid: String, x: int, ignore = null) -> bool:
	var def: Dictionary = Data.objects.get(oid, {})
	if def.is_empty():
		return false
	var w := int(def.size[0])
	var h := int(def.size[1])
	if x < 0 or x + w > int(room.width) or h > int(room.height):
		return false
	for o in room.objects:
		if o == ignore:
			continue
		var ow := int(Data.objects[o.id].size[0])
		if x < int(o.x) + ow and int(o.x) < x + w:
			return false
	for b in room.blocks:
		if int(b.dy) < h and int(b.x) >= x and int(b.x) < x + w:
			return false
	return true

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
		if _in_room(cell) and _fits_object(oid, cell.x):
			room.objects.append({"id": oid, "x": cell.x})
			_say("Placed " + oid)
	else: # pointer: grab / drop furniture (click-drag-click)
		if not grabbed.is_empty():
			if _in_room(cell) and _fits_object(grabbed.id, cell.x):
				room.objects.append({"id": grabbed.id, "x": cell.x})
				grabbed = {}
				_say("Moved")
		elif _in_room(cell):
			var o = _object_at_x(cell.x)
			if o != null and cell.y >= int(room.height) - int(Data.objects[o.id].size[1]):
				grabbed = o
				room.objects.erase(o)
				_say("Grabbed %s — click to drop" % grabbed.id)

func _paint(cell: Vector2i) -> void:
	if not _in_room(cell):
		return
	var dy := _standing_row() - cell.y
	if _object_at_x(cell.x) != null and dy < int(Data.objects[_object_at_x(cell.x).id].size[1]):
		return # occupied by furniture
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
	var o = _object_at_x(cell.x)
	if o != null and cell.y >= int(room.height) - int(Data.objects[o.id].size[1]):
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
	# Furniture (bottom-aligned to the standing row)
	for o in room.objects:
		_draw_object(org, o.id, int(o.x), Color.WHITE)
	# Ghost previews
	if tool_mode.begins_with("object:") and _in_room(hover_cell):
		var oid := tool_mode.substr(7)
		var ok := _fits_object(oid, hover_cell.x)
		_draw_object(org, oid, hover_cell.x, Color(0.6, 1.0, 0.6, 0.55) if ok else Color(1.0, 0.5, 0.5, 0.55))
	elif not grabbed.is_empty() and _in_room(hover_cell):
		var ok2 := _fits_object(grabbed.id, hover_cell.x)
		_draw_object(org, grabbed.id, hover_cell.x, Color(0.6, 1.0, 0.6, 0.55) if ok2 else Color(1.0, 0.5, 0.5, 0.55))
	if _in_room(hover_cell):
		canvas.draw_rect(Rect2(org + Vector2(hover_cell) * CELL, Vector2(CELL, CELL)), Color(1, 1, 0.6, 0.6), false)

func _draw_tile(pos: Vector2, mat: int, mod: Color) -> void:
	var variant := posmod(hash(Vector2i(pos / CELL)), 5)
	canvas.draw_texture_rect_region(ATLAS, Rect2(pos, Vector2(CELL, CELL)),
		Rect2(variant * 16, (mat - 1) * 16, 16, 16), mod)

func _draw_object(org: Vector2, oid: String, x: int, mod: Color) -> void:
	var def: Dictionary = Data.objects.get(oid, {})
	if def.is_empty():
		return
	if not _obj_textures.has(oid):
		_obj_textures[oid] = load(Data.OBJECT_SPRITE_DIR + oid + ".png")
	var tex: Texture2D = _obj_textures[oid]
	if tex == null:
		return
	var h := int(def.size[1])
	var pos := org + Vector2(x, room.height - h) * CELL
	canvas.draw_texture_rect(tex, Rect2(pos, Vector2(def.size[0] * CELL, h * CELL)), false, mod)

# --- Library I/O ---

func _read_library() -> Dictionary:
	var text := FileAccess.get_file_as_string(rooms_path)
	var parsed = JSON.parse_string(text) if text != "" else null
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = {"_comment": "Room template library (CT-04/05).", "rooms": []}
	return parsed

func _refresh_load_list() -> void:
	load_option.clear()
	load_option.add_item("— load —")
	for r in _read_library().rooms:
		load_option.add_item(r.id)

func _load_selected(index: int) -> void:
	if index <= 0:
		return
	var lib := _read_library()
	for r in lib.rooms:
		if r.id == load_option.get_item_text(index):
			room = r.duplicate(true)
			room["height"] = room.get("height", 5)
			room["zone"] = room.get("zone", room.get("type", "residential"))
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
