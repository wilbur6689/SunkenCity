extends CanvasLayer
## Full-screen map (M, user request): the whole revealed city (CC-25), pan
## by dragging (LMB) and zoom with the wheel (anchored on the mouse). M or
## Esc closes. The world image is built once on first open, then kept fresh
## from MapReveal's newly-revealed cells plus a repaint window around the
## player, so reopening is instant.

const ZOOM_MIN := 0.5
const ZOOM_MAX := 8.0
const REFRESH_SECONDS := 0.5
const REPAINT_WINDOW := Vector2i(120, 70) # map cells around the player kept fresh

var open: bool = false
var esc_consumed_frame: int = -1
var root: Control
var map_rect: TextureRect
var marker: ColorRect
var _clip: Control
var _other_marks: Dictionary = {} # peer_id -> {rect, label} (other players, LAN)
var _pack_marks: Array = []       # ColorRects on death backpacks
var _death_marks: Array = []      # dim dots where the local player died this session
var zoom: float = 2.0
var pan := Vector2.ZERO
var _img: Image
var _tex: ImageTexture
var _built := false
var _dragging := false
var _refresh := 0.0

func _ready() -> void:
	add_to_group("map_view")
	layer = 7 # above the HUD (1), character menu (5), and Esc menu (6)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_gui_input)
	add_child(root)
	UIScale.register(root) # UI size scaling (2026-09-02)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var clip := Control.new()
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clip)
	map_rect = TextureRect.new()
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(map_rect)
	marker = ColorRect.new()
	marker.color = Color(1.0, 0.95, 0.7)
	marker.size = Vector2(5, 5)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(marker)
	_clip = clip
	var hint := UITheme.label("Drag to pan · wheel zooms · M / Esc closes  ·  cyan: players · red: death packs", 8, Color(0.6, 0.68, 0.74))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -14
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("map") and World.is_ready():
		var inv = get_tree().get_first_node_in_group("inventory_ui")
		var pause = get_tree().get_first_node_in_group("pause_menu")
		if open:
			close()
		elif (inv == null or not inv.open) and (pause == null or not pause.open):
			open_map()
	if not open:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		esc_consumed_frame = Engine.get_process_frames()
		close()
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = REFRESH_SECONDS
		_update_pixels()
	_clamp_pan()
	map_rect.position = pan
	map_rect.size = Vector2(_img.get_size()) * zoom
	var player = Net.local_player()
	if player != null:
		var cell := World.map_macro_for(player.global_position) - World.map_bounds.position
		marker.position = pan + Vector2(cell) * zoom - marker.size * 0.5
	marker.visible = int(Time.get_ticks_msec() / 400) % 2 == 0 # blink
	_update_overlays(player)

## Other players (cyan, named) and death backpacks (red) on the map, plus
## dim dots where this character died this session (user request 2026-09-06).
func _update_overlays(local) -> void:
	var seen: Dictionary = {}
	for p in Net.players():
		if p == local or not (p is Node2D):
			continue
		var pid: int = p.get("peer_id")
		seen[pid] = true
		if not _other_marks.has(pid):
			var r := ColorRect.new()
			r.color = Color(0.35, 0.9, 1.0)
			r.size = Vector2(5, 5)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_clip.add_child(r)
			var l := UITheme.label(String(p.get("character_name")), 8, Color(0.6, 0.95, 1.0))
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_clip.add_child(l)
			_other_marks[pid] = {"rect": r, "label": l}
		var m: Dictionary = _other_marks[pid]
		var at := _map_pos(p.global_position)
		(m.rect as ColorRect).position = at - Vector2(2.5, 2.5)
		(m.label as Label).position = at + Vector2(4, -6)
	for pid in _other_marks.keys():
		if not seen.has(pid):
			(_other_marks[pid].rect as ColorRect).queue_free()
			(_other_marks[pid].label as Label).queue_free()
			_other_marks.erase(pid)
	var packs: Array = get_tree().get_nodes_in_group("backpacks")
	_fit_marks(_pack_marks, packs.size(), Color(1.0, 0.3, 0.3), Vector2(5, 5))
	for i in packs.size():
		(_pack_marks[i] as ColorRect).position = _map_pos((packs[i] as Node2D).global_position) - Vector2(2.5, 2.5)
	var deaths: Array = []
	if local != null and local.get("death_marks") != null:
		deaths = local.get("death_marks")
	_fit_marks(_death_marks, deaths.size(), Color(0.75, 0.2, 0.2, 0.8), Vector2(3, 3))
	for i in deaths.size():
		(_death_marks[i] as ColorRect).position = _map_pos(deaths[i]) - Vector2(1.5, 1.5)

func _fit_marks(pool: Array, n: int, color: Color, size: Vector2) -> void:
	while pool.size() < n:
		var r := ColorRect.new()
		r.color = color
		r.size = size
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clip.add_child(r)
		pool.append(r)
	for i in pool.size():
		(pool[i] as ColorRect).visible = i < n

func _map_pos(world_pos: Vector2) -> Vector2:
	var cell := World.map_macro_for(world_pos) - World.map_bounds.position
	return pan + Vector2(cell) * zoom

func open_map() -> void:
	open = true
	root.visible = true
	if not _built:
		_build_full()
	else:
		_update_pixels()
	_refresh = REFRESH_SECONDS
	var player = Net.local_player()
	if player != null:
		player.ui_blocks_mouse = true
		# centre the view on the player (inside a pocket: on its doorway)
		var cell := World.map_macro_for(player.global_position) - World.map_bounds.position
		pan = root.size * 0.5 - Vector2(cell) * zoom

func close() -> void:
	open = false
	_dragging = false
	root.visible = false
	var player = Net.local_player()
	if player != null:
		player.ui_blocks_mouse = false

# --- Input: drag pan + wheel zoom on the mouse point ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, 1.25)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.0 / 1.25)
	elif event is InputEventMouseMotion and _dragging:
		pan += event.relative

func _zoom_at(mouse: Vector2, factor: float) -> void:
	var new_zoom := clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	# keep the map point under the mouse fixed while zooming
	pan = mouse - (mouse - pan) * (new_zoom / zoom)
	zoom = new_zoom

func _clamp_pan() -> void:
	var map_size := Vector2(_img.get_size()) * zoom if _img != null else Vector2.ZERO
	var view := root.size
	pan.x = clampf(pan.x, minf(view.x - map_size.x, view.x * 0.5), maxf(0.0, view.x * 0.5))
	pan.y = clampf(pan.y, minf(view.y - map_size.y, view.y * 0.5), maxf(0.0, view.y * 0.5))

# --- Image upkeep ---

## One-time full build (first open); afterwards only new reveals repaint.
func _build_full() -> void:
	var t0 := Time.get_ticks_msec()
	var b: Rect2i = World.map_bounds # map cells; the pocket annex is never mapped
	_img = Image.create(b.size.x, b.size.y, false, Image.FORMAT_RGB8)
	_img.fill(MapColors.UNREVEALED)
	for y in b.size.y:
		for x in b.size.x:
			var cell := b.position + Vector2i(x, y)
			if World.map_reveal.is_revealed(cell):
				_img.set_pixel(x, y, MapColors.cell_color(cell))
	World.map_reveal.dirty.clear()
	_tex = ImageTexture.create_from_image(_img)
	map_rect.texture = _tex
	_built = true
	print("map view: full build in %d ms" % (Time.get_ticks_msec() - t0))

## Newly revealed cells + a window around the player (terrain there may
## have changed: mining, pumping, building).
func _update_pixels() -> void:
	var b: Rect2i = World.map_bounds
	if World.map_reveal.full_dirty: # admin reveal_all: repaint everything
		World.map_reveal.full_dirty = false
		_build_full()
		return
	for v in World.map_reveal.dirty:
		var cell := Vector2i(v)
		if b.has_point(cell): # reveals inside a pocket stay off the city map
			_img.set_pixel(cell.x - b.position.x, cell.y - b.position.y, MapColors.cell_color(cell))
	World.map_reveal.dirty.clear()
	var player = Net.local_player()
	if player != null:
		var center := World.map_macro_for(player.global_position)
		var org := center - REPAINT_WINDOW / 2
		for dy in REPAINT_WINDOW.y:
			for dx in REPAINT_WINDOW.x:
				var cell := org + Vector2i(dx, dy)
				if b.has_point(cell) and World.map_reveal.is_revealed(cell):
					_img.set_pixel(cell.x - b.position.x, cell.y - b.position.y, MapColors.cell_color(cell))
	_tex.update(_img)
