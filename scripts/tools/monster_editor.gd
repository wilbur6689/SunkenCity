extends Control
## Monster Editor: load every enemy type and tune it (user request
## 2026-09-01). Run standalone:
##   godot --path . res://scenes/tools/monster_editor.tscn
##
## Left: the type list (grouped by movement mode) and the identity —
## id, name, mode, hitbox in pixels, behaviour flags, walk-strip frames
## and sprite variants, and the drops table. Center: the AUTHORED per-band
## stat grid (GD-23, no formulas): enable a band row and set hp / damage /
## speed / aggro — an enemy only seeds in bands it has a row for. Right:
## an animated sprite preview (variants cycle, hitbox overlay). Save
## writes data/enemies.json in place (types + band rows together).
## Sprites themselves come from tools/convert_monsters.py (hand-made
## strips) and tools/gen_placeholder_art.py (placeholders).

const SPRITE_DIR := "res://assets/sprites/enemies/"
const MODES := ["ground", "surface", "swim", "fish"]
const BANDS := ["dry", "shallows", "cold", "dark", "crush"]
const FLAGS := ["bleeds", "water_only", "open_water", "passive"]
const STATS := ["hp", "damage", "speed", "aggro"]
const PX := 4 # preview zoom
const FE_PX := 12 # frame pixel-editor zoom
## The same TileArt ramps + accents every other editor offers (user request
## 2026-09-01: the frame palette alone can be two colours on a small sprite).
const FE_PALETTE := [
	["Wood", [Color8(40, 26, 14), Color8(94, 62, 38), Color8(120, 82, 50), Color8(146, 104, 66), Color8(168, 126, 86), Color8(192, 152, 108)]],
	["Metal", [Color8(22, 28, 36), Color8(60, 70, 82), Color8(80, 92, 106), Color8(100, 114, 130), Color8(120, 136, 152), Color8(154, 170, 186)]],
	["Stone", [Color8(30, 28, 26), Color8(66, 64, 62), Color8(90, 88, 86), Color8(114, 112, 110), Color8(138, 136, 134), Color8(166, 164, 162)]],
	["Plastic", [Color8(20, 44, 32), Color8(54, 100, 74), Color8(70, 126, 92), Color8(90, 150, 110), Color8(112, 172, 130), Color8(142, 196, 156)]],
]
const FE_ACCENT_HUES := [0.0, 0.07, 0.13, 0.3, 0.5, 0.62, 0.76, 0.9]
const FE_ACCENT_SHADES := [[0.8, 0.32], [0.85, 0.5], [0.78, 0.68], [0.68, 0.85], [0.5, 0.95], [0.25, 1.0]]

var enemies_path := "res://data/enemies.json"
var sprites_dir := SPRITE_DIR
var def: Dictionary = {}
var band_rows: Dictionary = {} # band -> {on: CheckBox, hp/damage/speed/aggro: SpinBox}

var load_option: OptionButton
var id_edit: LineEdit
var name_edit: LineEdit
var mode_option: OptionButton
var w_spin: SpinBox
var h_spin: SpinBox
var flag_checks: Dictionary = {}
var frames_spin: SpinBox
var variants_spin: SpinBox
var drops_box: VBoxContainer
var status_label: Label
var preview: Control
var variant_option: OptionButton
var play_check: CheckBox
var hitbox_check: CheckBox

var _tex: Texture2D = null
var _anim_t := 0.0
var cur_frame := 0
var frame_label: Label

# frame pixel editor (an overlay window; BACK returns)
var fe_layer: Control = null
var fe_canvas: Control
var fe_img: Image
var fe_full: Image
var fe_tex: ImageTexture
var fe_brush := Color8(120, 40, 40)
var fe_brush2 := Color8(60, 70, 82) # RMB paints this
var fe_pick := false
var fe_erase := false
var fe_hover := Vector2i(-1, -1)
var fe_sel_a := Vector2i(-1, -1)
var fe_sel_b := Vector2i(-1, -1)
var fe_select := false
var fe_clip: Image = null
var fe_clip_tex: ImageTexture = null
var fe_pasting := false
var fe_status: Label
var fe_swatch_box: VBoxContainer
var fe_brush_swatch: ColorRect
var fe_brush2_swatch: ColorRect
var fe_preview: Control
var fe_full_tex: ImageTexture
var fe_anim_t := 0.0

func _ready() -> void:
	def = _default_def()
	_build_ui()
	_mount_pause_menu()
	_refresh_load_list()
	_sync_to_ui()

func _default_def() -> Dictionary:
	return {"id": "new_monster", "name": "New Monster", "mode": "ground",
		"size": [12, 22], "drops": []}

# --- UI ---

func _mount_pause_menu() -> void:
	var pm: CanvasLayer = load("res://scripts/ui/pause_menu.gd").new()
	pm.custom_controls = [
		["Load a monster", "Type list (grouped by mode)"],
		["Band stats", "Enable a band row = the monster seeds there"],
		["Drops", "item id / min / max / chance rows"],
		["Preview", "Variant picker · play toggles the walk cycle"],
		["Frame flow", "< > step frames · SAVE + NEXT · + FRAME copies"],
		["Save", "SAVE / EXPORT → data/enemies.json"],
		["Menu", "Esc"],
	]
	pm.hint_text = "Unsaved monster tuning is lost on quit — SAVE / EXPORT first"
	pm.quit_text = "QUIT GAME"
	pm.quit_callable = _quit_game
	add_child(pm)

## Editors are standalone tools (user request 2026-09-01): Esc quits the
## app outright instead of returning to the title screen.
func _quit_game() -> void:
	get_tree().quit()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.10, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := UITheme.label("MONSTER EDITOR — enemy types, per-band stats and drops (data/enemies.json)", 9, Color(0.85, 0.62, 0.62))
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

	# --- left: identity + drops ---
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", UITheme.steel_panel())
	sp.custom_minimum_size = Vector2(190, 0)
	root.add_child(sp)
	var sscroll := ScrollContainer.new()
	sscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.add_child(sscroll)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sscroll.add_child(sv)
	sv.add_child(UITheme.label("MONSTER", 8, Color(0.85, 0.62, 0.62)))
	var lrow := HBoxContainer.new()
	load_option = OptionButton.new()
	load_option.add_theme_font_size_override("font_size", 8)
	load_option.item_selected.connect(_load_selected)
	load_option.tooltip_text = "Load a monster to edit - grouped by movement mode."
	load_option.custom_minimum_size = Vector2(110, 0)
	lrow.add_child(load_option)
	lrow.add_child(_button("New", func():
		def = _default_def()
		_sync_to_ui(), "Start a fresh monster type (unsaved changes are lost)."))
	sv.add_child(lrow)
	sv.add_child(UITheme.label("Identity - id / display name", 8, Color(0.6, 0.66, 0.72)))
	var row1 := HBoxContainer.new()
	id_edit = _edit("id", "Unique type id (lowercase_snake_case). Names the sprite files: <id>.png, <id>_b.png...")
	name_edit = _edit("Name", "Display name for docs and tools.")
	row1.add_child(id_edit)
	row1.add_child(name_edit)
	sv.add_child(row1)
	sv.add_child(UITheme.label("Movement mode", 8, Color(0.6, 0.66, 0.72)))
	mode_option = OptionButton.new()
	mode_option.tooltip_text = "ground: stands/walks with gravity and edge sense. surface: bobs prone at the waterline. swim: moves freely in water. fish: passive catchable ambience."
	mode_option.add_theme_font_size_override("font_size", 8)
	for m in MODES:
		mode_option.add_item(m)
	sv.add_child(mode_option)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 2)
	w_spin = _spin(4, 64, 12, "Collision box width in PIXELS (not blocks). Wide + short reads prone/swimming.")
	h_spin = _spin(4, 64, 22, "Collision box height in PIXELS. Tall + narrow reads standing.")
	frames_spin = _spin(1, 16, 1, "Frames in the horizontal walk strip (1 = static sprite).")
	variants_spin = _spin(1, 12, 1, "Alternate look files (<id>_b.png, _c.png...) picked per individual.")
	for arr in [["Hitbox W px", w_spin], ["Hitbox H px", h_spin], ["Frames", frames_spin], ["Variants", variants_spin]]:
		g.add_child(UITheme.label(arr[0], 8))
		g.add_child(arr[1])
	sv.add_child(g)
	frames_spin.value_changed.connect(func(_v): preview.queue_redraw())
	var frow := HBoxContainer.new()
	var frow2 := HBoxContainer.new()
	for i in FLAGS.size():
		var cb := CheckBox.new()
		cb.text = FLAGS[i]
		cb.tooltip_text = {
			"bleeds": "Hits can start the player bleeding (bandage/medkit cures).",
			"water_only": "Never leaves the water; flops helplessly when drained onto dry floor.",
			"open_water": "Refuses building interiors (back-walled cells) - an open-water hunter.",
			"passive": "Never attacks and is not a weapon target (fish are caught by hand).",
		}[FLAGS[i]]
		cb.add_theme_font_size_override("font_size", 8)
		flag_checks[FLAGS[i]] = cb
		(frow if i < 2 else frow2).add_child(cb)
	sv.add_child(frow)
	sv.add_child(frow2)
	sv.add_child(UITheme.label("Drops (item / min / max / chance)", 8, Color(0.85, 0.62, 0.62)))
	drops_box = VBoxContainer.new()
	drops_box.add_theme_constant_override("separation", 1)
	sv.add_child(drops_box)
	sv.add_child(_button("+ add drop", func():
		def.drops.append({"item": "cloth", "min": 1, "max": 2, "chance": 0.5})
		_rebuild_drops(), "Add another death drop."))
	sv.add_child(_button("SAVE / EXPORT", _save, "Write data/enemies.json in place: the type, its band rows, and drops together."))
	status_label = UITheme.label("", 8, Color(0.75, 0.95, 0.75))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(170, 0)
	sv.add_child(status_label)

	# --- middle: authored band stats (GD-23) ---
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", UITheme.steel_panel())
	mp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(mp)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 2)
	mp.add_child(mv)
	mv.add_child(UITheme.label("BAND STATS — a monster only seeds where a row is enabled (GD-23)", 8, Color(0.85, 0.62, 0.62)))
	var head := GridContainer.new()
	head.columns = 6
	head.add_theme_constant_override("h_separation", 4)
	for label in ["band", "on", "hp", "damage", "speed b/s", "aggro bl"]:
		head.add_child(UITheme.label(label, 8, Color(0.6, 0.66, 0.72)))
	for band in BANDS:
		head.add_child(UITheme.label(band.to_upper(), 8))
		var on := CheckBox.new()
		on.tooltip_text = "Enabled = this monster SEEDS in the %s band with this row's stats. Disabled bands fall back toward the surface when queried (red moons)." % band
		on.add_theme_font_size_override("font_size", 8)
		head.add_child(on)
		var row := {"on": on}
		for stat in STATS:
			var spin := _spin(0, 500, 10, {
				"hp": "Hit points in this band.",
				"damage": "Damage per bite in this band.",
				"speed": "Move speed in blocks per second.",
				"aggro": "Notice radius in blocks (surface radii grow x1.5 at night).",
			}[stat])
			spin.step = 0.1 if stat == "speed" else 1
			row[stat] = spin
			head.add_child(spin)
		band_rows[band] = row
	mv.add_child(head)
	mv.add_child(UITheme.label("hp / damage per hit / speed in blocks-per-sec / aggro radius in blocks.", 8, Color(0.6, 0.66, 0.72)))
	mv.add_child(UITheme.label("Bands without a row fall back toward the surface when queried (red moons).", 8, Color(0.6, 0.66, 0.72)))

	# --- right: animated preview ---
	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", UITheme.steel_panel())
	pp.custom_minimum_size = Vector2(220, 0)
	root.add_child(pp)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	pp.add_child(pv)
	pv.add_child(UITheme.label("PREVIEW", 8, Color(0.85, 0.62, 0.62)))
	variant_option = OptionButton.new()
	variant_option.add_theme_font_size_override("font_size", 8)
	variant_option.tooltip_text = "Which sprite file to preview (base + variant looks)."
	variant_option.item_selected.connect(func(_i): _load_preview_texture())
	pv.add_child(variant_option)
	var prow := HBoxContainer.new()
	play_check = CheckBox.new()
	play_check.text = "Play"
	play_check.tooltip_text = "Loop the walk cycle; unchecking (or stepping) freezes on one frame."
	play_check.button_pressed = true
	play_check.add_theme_font_size_override("font_size", 8)
	prow.add_child(play_check)
	hitbox_check = CheckBox.new()
	hitbox_check.text = "Hitbox"
	hitbox_check.tooltip_text = "Overlay the collision box on the sprite (red)."
	hitbox_check.button_pressed = true
	hitbox_check.add_theme_font_size_override("font_size", 8)
	hitbox_check.toggled.connect(func(_v): preview.queue_redraw())
	prow.add_child(hitbox_check)
	pv.add_child(prow)
	# frame stepping (user request 2026-09-01): arrows pause playback and
	# walk the strip one frame at a time; Edit opens the pixel window.
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 4)
	var back_b := _button("<", func(): _step_frame(-1), "Step one frame back (pauses playback).")
	back_b.custom_minimum_size = Vector2(22, 14)
	srow.add_child(back_b)
	frame_label = UITheme.label("frame 1/1", 8)
	frame_label.custom_minimum_size = Vector2(58, 0)
	srow.add_child(frame_label)
	var fwd_b := _button(">", func(): _step_frame(1), "Step one frame forward (pauses playback).")
	fwd_b.custom_minimum_size = Vector2(22, 14)
	srow.add_child(fwd_b)
	srow.add_child(_button("Edit frame…", _open_frame_edit, "Open THIS frame in the pixel editor window."))
	pv.add_child(srow)
	preview = Control.new()
	preview.custom_minimum_size = Vector2(200, 160)
	preview.draw.connect(_draw_preview)
	pv.add_child(preview)
	pv.add_child(UITheme.label("Sprites come from tools/convert_monsters.py\n(hand-made strips) and gen_placeholder_art.py.", 8, Color(0.6, 0.66, 0.72)))

func _edit(placeholder: String, tip: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.tooltip_text = tip
	e.add_theme_font_size_override("font_size", 8)
	e.custom_minimum_size = Vector2(80, 0)
	return e

func _spin(minv: float, maxv: float, val: float, tip: String = "") -> SpinBox:
	var s := SpinBox.new()
	s.tooltip_text = tip
	s.min_value = minv
	s.max_value = maxv
	s.step = 1
	s.value = val
	s.get_line_edit().add_theme_font_size_override("font_size", 8)
	s.get_line_edit().tooltip_text = tip
	s.custom_minimum_size = Vector2(52, 0)
	return s

func _button(text: String, cb: Callable, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(0, 14)
	UITheme.style_button(b)
	b.pressed.connect(cb)
	return b

func _say(text: String) -> void:
	status_label.text = text

func _rebuild_drops() -> void:
	for c in drops_box.get_children():
		c.queue_free()
	for d in def.drops:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var item := _edit("item id", "Item id dropped on death - must exist in the item registry or the save is refused.")
		item.text = String(d.item)
		item.custom_minimum_size = Vector2(64, 0)
		item.text_changed.connect(func(t): d.item = t.strip_edges())
		row.add_child(item)
		var mn := _spin(0, 30, int(d.min), "Minimum count dropped.")
		mn.custom_minimum_size = Vector2(40, 0)
		mn.value_changed.connect(func(v): d.min = int(v))
		row.add_child(mn)
		var mx := _spin(0, 30, int(d.max), "Maximum count dropped.")
		mx.custom_minimum_size = Vector2(40, 0)
		mx.value_changed.connect(func(v): d.max = int(v))
		row.add_child(mx)
		var ch := SpinBox.new()
		ch.tooltip_text = "Probability this drop rolls at all (1.0 = always)."
		ch.min_value = 0.05
		ch.max_value = 1.0
		ch.step = 0.05
		ch.value = float(d.get("chance", 1.0))
		ch.get_line_edit().add_theme_font_size_override("font_size", 8)
		ch.custom_minimum_size = Vector2(46, 0)
		ch.value_changed.connect(func(v): d.chance = v)
		row.add_child(ch)
		var del := _button("x", func():
			def.drops.erase(d)
			_rebuild_drops(), "Remove this drop row.")
		del.custom_minimum_size = Vector2(16, 14)
		row.add_child(del)
		drops_box.add_child(row)

# --- Preview ---

func _process(delta: float) -> void:
	if play_check != null and play_check.button_pressed and int(frames_spin.value) > 1:
		_anim_t += delta * 6.0
		cur_frame = int(_anim_t) % maxi(int(frames_spin.value), 1)
		_update_frame_label()
		preview.queue_redraw()
	if fe_layer != null and fe_layer.visible and fe_preview != null and int(frames_spin.value) > 1:
		fe_anim_t += delta * 6.0
		fe_preview.queue_redraw()

## Arrow stepping pauses playback and walks the strip by hand.
func _step_frame(dir: int) -> void:
	play_check.button_pressed = false
	cur_frame = posmod(cur_frame + dir, maxi(int(frames_spin.value), 1))
	_update_frame_label()
	preview.queue_redraw()

func _update_frame_label() -> void:
	if frame_label != null:
		frame_label.text = "frame %d/%d" % [cur_frame + 1, maxi(int(frames_spin.value), 1)]

func _refresh_variants() -> void:
	variant_option.clear()
	var id := id_edit.text.strip_edges()
	variant_option.add_item(id + ".png")
	for i in range(1, int(variants_spin.value)):
		var suffix := "_" + char(97 + i)
		if FileAccess.file_exists(sprites_dir + id + suffix + ".png"):
			variant_option.add_item(id + suffix + ".png")
	variant_option.selected = 0
	_load_preview_texture()

func _load_preview_texture() -> void:
	_tex = null
	if variant_option.item_count > 0:
		var path := sprites_dir + variant_option.get_item_text(variant_option.selected)
		if FileAccess.file_exists(path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img != null:
				_tex = ImageTexture.create_from_image(img)
	cur_frame = 0
	_update_frame_label()
	preview.queue_redraw()

func _draw_preview() -> void:
	preview.draw_rect(Rect2(Vector2.ZERO, preview.size), Color(0.16, 0.18, 0.22))
	if _tex == null:
		preview.draw_rect(Rect2(20, 20, 40, 40), Color(0.4, 0.2, 0.2), false)
		return
	var frames := maxi(int(frames_spin.value), 1)
	var fw := _tex.get_width() / frames
	var fh := _tex.get_height()
	var frame := cur_frame % frames
	var dst := Rect2(preview.size.x * 0.5 - fw * PX * 0.5, preview.size.y * 0.6 - fh * PX * 0.5,
		fw * PX, fh * PX)
	preview.draw_texture_rect_region(_tex, dst, Rect2(frame * fw, 0, fw, fh))
	if hitbox_check.button_pressed:
		var hw := float(w_spin.value) * PX
		var hh := float(h_spin.value) * PX
		preview.draw_rect(Rect2(dst.get_center().x - hw * 0.5, dst.position.y + dst.size.y - hh,
			hw, hh), Color(0.9, 0.4, 0.4, 0.8), false)

# --- Sync + library I/O ---

func _sync_to_ui() -> void:
	id_edit.text = def.id
	name_edit.text = def.get("name", def.id)
	mode_option.selected = maxi(MODES.find(def.get("mode", "ground")), 0)
	w_spin.set_value_no_signal(int(def.size[0]))
	h_spin.set_value_no_signal(int(def.size[1]))
	frames_spin.set_value_no_signal(maxi(int(def.get("frames", 1)), 1))
	variants_spin.set_value_no_signal(maxi(int(def.get("sprite_variants", 1)), 1))
	for f in FLAGS:
		flag_checks[f].button_pressed = bool(def.get(f, false))
	var lib := _read_library()
	for band in BANDS:
		var row: Dictionary = band_rows[band]
		var stats: Dictionary = (lib.bands as Dictionary).get(band, {}).get(def.id, {})
		row.on.button_pressed = not stats.is_empty()
		for stat in STATS:
			(row[stat] as SpinBox).set_value_no_signal(float(stats.get(stat, 0)))
	_rebuild_drops()
	_refresh_variants()

func _apply_ui() -> void:
	def.id = id_edit.text.strip_edges()
	def.name = name_edit.text.strip_edges()
	def.mode = MODES[mode_option.selected]
	def.size = [int(w_spin.value), int(h_spin.value)]
	for f in FLAGS:
		if flag_checks[f].button_pressed:
			def[f] = true
		else:
			def.erase(f)
	if int(frames_spin.value) > 1:
		def["frames"] = int(frames_spin.value)
	else:
		def.erase("frames")
	if int(variants_spin.value) > 1:
		def["sprite_variants"] = int(variants_spin.value)
	else:
		def.erase("sprite_variants")

func _read_library() -> Dictionary:
	var path := enemies_path
	if not FileAccess.file_exists(path):
		path = "res://data/enemies.json" # first save: start from the shipped data
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = {"types": [], "bands": {}, "seeding": {}}
	return parsed

## The list groups by movement mode so "all monsters by type" scans easily.
func _refresh_load_list() -> void:
	load_option.clear()
	load_option.add_item("— load —")
	var lib := _read_library()
	var entries := []
	for t in lib.types:
		entries.append([String(t.get("mode", "ground")), String(t.id)])
	entries.sort()
	for e in entries:
		load_option.add_item("%s · %s" % [e[0], e[1]])

func _load_selected(index: int) -> void:
	if index <= 0:
		return
	var id: String = load_option.get_item_text(index).get_slice(" · ", 1)
	var lib := _read_library()
	for t in lib.types:
		if t.id == id:
			def = (t as Dictionary).duplicate(true)
			def["drops"] = def.get("drops", [])
			_sync_to_ui()
			_say("Loaded " + id)
			return

func _save() -> void:
	_apply_ui()
	if def.id == "":
		_say("Give the monster an id first")
		return
	for d in def.drops:
		if not Data.items.has(String(d.item)):
			_say("Unknown drop item '%s' — the game refuses bad drops at boot" % d.item)
			return
	var lib := _read_library()
	var replaced := false
	for i in lib.types.size():
		if lib.types[i].id == def.id:
			lib.types[i] = def.duplicate(true)
			replaced = true
	if not replaced:
		lib.types.append(def.duplicate(true))
	var seeds := 0
	for band in BANDS:
		var row: Dictionary = band_rows[band]
		if not lib.bands.has(band):
			lib.bands[band] = {}
		if row.on.button_pressed:
			var stats := {}
			for stat in STATS:
				stats[stat] = (row[stat] as SpinBox).value
			lib.bands[band][def.id] = stats
			seeds += 1
		else:
			(lib.bands[band] as Dictionary).erase(def.id)
	var f := FileAccess.open(enemies_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(lib, " ") + "\n")
	f.close()
	_refresh_load_list()
	_say("%s %s — %d band rows (%s)" % ["Updated" if replaced else "Exported", def.id, seeds,
		"seeds in those bands" if seeds > 0 else "WARNING: seeds nowhere"])


# --- Frame pixel editor (user request 2026-09-01): Edit opens the current
# frame of the current variant file in an overlay window - LMB paints, RMB
# erases, Pick samples, swatches come from the frame's own palette. SAVE
# FRAME writes the strip back to disk and marks the type authored_sprites
# (the game then loads it raw; convert_monsters.py keeps its hands off).
# BACK returns to the monster editor.

func _open_frame_edit() -> void:
	if variant_option.item_count == 0:
		return
	var path := sprites_dir + variant_option.get_item_text(variant_option.selected)
	if not FileAccess.file_exists(path):
		_say("No sprite file to edit")
		return
	fe_full = Image.load_from_file(ProjectSettings.globalize_path(path))
	if fe_full == null:
		_say("Could not load " + path)
		return
	fe_full.convert(Image.FORMAT_RGBA8)
	var frames := maxi(int(frames_spin.value), 1)
	var fw := fe_full.get_width() / frames
	fe_img = fe_full.get_region(Rect2i(cur_frame * fw, 0, fw, fe_full.get_height()))
	fe_tex = null
	if fe_layer == null:
		_build_frame_edit()
	_fe_refresh_swatches()
	fe_status.text = "%s - frame %d/%d" % [variant_option.get_item_text(variant_option.selected), cur_frame + 1, frames]
	fe_layer.visible = true
	_fe_dirty()

func _close_frame_edit() -> void:
	fe_layer.visible = false

func _build_frame_edit() -> void:
	fe_layer = Control.new()
	fe_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fe_layer.visible = false
	add_child(fe_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	fe_layer.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_top = 8
	v.offset_right = -12
	v.offset_bottom = -8
	v.add_theme_constant_override("separation", 6)
	fe_layer.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var back := _button("< BACK", _close_frame_edit, "Return to the monster editor (unsaved frame changes are lost).")
	back.custom_minimum_size = Vector2(64, 16)
	top.add_child(back)
	top.add_child(UITheme.label("FRAME EDITOR - LMB primary / RMB secondary / MMB or eraser clears", 9, Color(0.85, 0.62, 0.62)))
	top.add_child(_button("<", func(): _fe_step(-1), "Previous frame - your edits stay banked in the strip (disk untouched until save)."))
	top.add_child(_button(">", func(): _fe_step(1), "Next frame - your edits stay banked in the strip (disk untouched until save)."))
	top.add_child(_button("SAVE FRAME", _save_frame, "Write the whole edited strip to disk and claim it as hand-edited."))
	top.add_child(_button("SAVE + NEXT >", func():
		_save_frame()
		_fe_step(1), "Save the strip, then move straight to the next frame."))
	top.add_child(_button("+ FRAME", _fe_add_frame, "Insert a COPY of this frame right after it - a starting pose for the next animation step."))
	fe_status = UITheme.label("", 8, Color(0.75, 0.95, 0.75))
	top.add_child(fe_status)
	v.add_child(top)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	tools.add_child(UITheme.label("Brush", 8))
	fe_brush_swatch = ColorRect.new()
	fe_brush_swatch.custom_minimum_size = Vector2(14, 14)
	fe_brush_swatch.color = fe_brush
	tools.add_child(fe_brush_swatch)
	var picker := ColorPickerButton.new()
	picker.text = "Custom..."
	picker.add_theme_font_size_override("font_size", 8)
	picker.custom_minimum_size = Vector2(56, 14)
	picker.color = fe_brush
	picker.tooltip_text = "Primary brush - painted with LMB."
	picker.color_changed.connect(func(c):
		fe_brush = c
		fe_brush_swatch.color = c)
	tools.add_child(picker)
	tools.add_child(UITheme.label("R", 8))
	fe_brush2_swatch = ColorRect.new()
	fe_brush2_swatch.custom_minimum_size = Vector2(14, 14)
	fe_brush2_swatch.color = fe_brush2
	tools.add_child(fe_brush2_swatch)
	var picker2 := ColorPickerButton.new()
	picker2.text = "..."
	picker2.add_theme_font_size_override("font_size", 8)
	picker2.custom_minimum_size = Vector2(28, 14)
	picker2.color = fe_brush2
	picker2.tooltip_text = "Secondary brush - painted with RMB."
	picker2.color_changed.connect(func(c):
		fe_brush2 = c
		fe_brush2_swatch.color = c)
	tools.add_child(picker2)
	var erase_b := CheckBox.new()
	erase_b.text = "Eraser"
	erase_b.tooltip_text = "Clicks clear pixels (MMB click also clears in any mode)."
	erase_b.add_theme_font_size_override("font_size", 8)
	erase_b.toggled.connect(func(v2): fe_erase = v2)
	tools.add_child(erase_b)
	var sel_b2 := CheckBox.new()
	sel_b2.text = "Select"
	sel_b2.tooltip_text = "Drag a rectangle; Copy / Cut / Paste move it (LMB stamps the ghost, RMB stops)."
	sel_b2.add_theme_font_size_override("font_size", 8)
	sel_b2.toggled.connect(func(v2): fe_select = v2)
	tools.add_child(sel_b2)
	tools.add_child(_button("Copy", func(): _fe_copy(false), "Copy the selected pixels."))
	tools.add_child(_button("Cut", func(): _fe_copy(true), "Copy the selection and clear it."))
	tools.add_child(_button("Paste", _fe_begin_paste, "Ghost follows the mouse: LMB stamps, RMB stops."))
	var pick_b := CheckBox.new()
	pick_b.text = "Pick colour (LMB samples)"
	pick_b.tooltip_text = "Sample mode: LMB copies a pixel into the primary brush, RMB into the secondary."
	pick_b.add_theme_font_size_override("font_size", 8)
	pick_b.toggled.connect(func(v2): fe_pick = v2)
	tools.add_child(pick_b)
	v.add_child(tools)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 12)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(mid)
	var cscroll := ScrollContainer.new()
	cscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(cscroll)
	fe_canvas = Control.new()
	fe_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	fe_canvas.draw.connect(_fe_draw)
	fe_canvas.gui_input.connect(_fe_input)
	cscroll.add_child(fe_canvas)
	var sw_panel := PanelContainer.new()
	sw_panel.add_theme_stylebox_override("panel", UITheme.steel_panel())
	sw_panel.custom_minimum_size = Vector2(150, 0)
	mid.add_child(sw_panel)
	var sw_scroll := ScrollContainer.new()
	sw_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sw_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sw_panel.add_child(sw_scroll)
	var sw_main := VBoxContainer.new()
	sw_main.add_theme_constant_override("separation", 2)
	sw_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sw_scroll.add_child(sw_main)
	sw_main.add_child(UITheme.label("LIVE PREVIEW", 8, Color(0.85, 0.62, 0.62)))
	fe_preview = Control.new()
	fe_preview.custom_minimum_size = Vector2(140, 96)
	fe_preview.tooltip_text = "The walk cycle playing from your in-progress strip - unsaved edits included."
	fe_preview.draw.connect(_fe_draw_preview)
	sw_main.add_child(fe_preview)
	sw_main.add_child(UITheme.label("MATERIALS", 8, Color(0.85, 0.62, 0.62)))
	for ramp in FE_PALETTE:
		sw_main.add_child(_fe_swatch_row(ramp[1]))
	sw_main.add_child(UITheme.label("ACCENTS", 8, Color(0.85, 0.62, 0.62)))
	for hue: float in FE_ACCENT_HUES:
		var acc: Array[Color] = []
		for shade in FE_ACCENT_SHADES:
			acc.append(Color.from_hsv(hue, shade[0], shade[1]))
		sw_main.add_child(_fe_swatch_row(acc))
	var grays: Array[Color] = []
	for i in 6:
		grays.append(Color.from_hsv(0.0, 0.0, 0.08 + i * 0.18))
	sw_main.add_child(_fe_swatch_row(grays))
	fe_swatch_box = VBoxContainer.new()
	fe_swatch_box.add_theme_constant_override("separation", 2)
	sw_main.add_child(fe_swatch_box)

## One swatch row: LMB sets the primary brush, RMB the secondary.
func _fe_swatch_row(colors: Array) -> HBoxContainer:
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
			fe_brush = c
			fe_brush_swatch.color = c)
		sw.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
				fe_brush2 = c
				fe_brush2_swatch.color = c)
		srow.add_child(sw)
	return srow

## Swatch rows built from the frame's own palette (up to 36 colours).
func _fe_refresh_swatches() -> void:
	for c in fe_swatch_box.get_children():
		c.queue_free()
	fe_swatch_box.add_child(UITheme.label("FRAME PALETTE", 8, Color(0.85, 0.62, 0.62)))
	var seen := {}
	var colors: Array[Color] = []
	for y in fe_img.get_height():
		for x in fe_img.get_width():
			var c := fe_img.get_pixel(x, y)
			if c.a < 0.5 or colors.size() >= 36:
				continue
			var key := c.to_html()
			if not seen.has(key):
				seen[key] = true
				colors.append(c)
	var row: HBoxContainer = null
	for i in colors.size():
		if i % 8 == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 1)
			fe_swatch_box.add_child(row)
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(14, 13)
		sw.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[i]
		sw.add_theme_stylebox_override("normal", sb)
		sw.add_theme_stylebox_override("hover", sb)
		sw.add_theme_stylebox_override("pressed", sb)
		var col := colors[i]
		sw.pressed.connect(func():
			fe_brush = col
			fe_brush_swatch.color = col)
		sw.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
				fe_brush2 = col
				fe_brush2_swatch.color = col)
		row.add_child(sw)

func _fe_dirty() -> void:
	if fe_tex == null or fe_tex.get_size() != Vector2(fe_img.get_size()):
		fe_tex = ImageTexture.create_from_image(fe_img)
	else:
		fe_tex.update(fe_img)
	# bank the frame into the strip immediately: frame stepping and the live
	# preview always see the latest pixels (disk changes only on save)
	var frames := maxi(int(frames_spin.value), 1)
	var fw := fe_full.get_width() / frames
	fe_full.blit_rect(fe_img, Rect2i(Vector2i.ZERO, fe_img.get_size()), Vector2i(cur_frame * fw, 0))
	if fe_full_tex == null or fe_full_tex.get_size() != Vector2(fe_full.get_size()):
		fe_full_tex = ImageTexture.create_from_image(fe_full)
	else:
		fe_full_tex.update(fe_full)
	fe_canvas.custom_minimum_size = Vector2(fe_img.get_size()) * FE_PX
	fe_canvas.queue_redraw()

## Switch the canvas to another frame of the strip (edits already banked).
func _fe_step(dir: int) -> void:
	var frames := maxi(int(frames_spin.value), 1)
	var fw := fe_full.get_width() / frames
	cur_frame = posmod(cur_frame + dir, frames)
	fe_img = fe_full.get_region(Rect2i(cur_frame * fw, 0, fw, fe_full.get_height()))
	fe_tex = null
	_update_frame_label()
	_fe_refresh_swatches()
	fe_status.text = "frame %d/%d" % [cur_frame + 1, frames]
	_fe_dirty()

## Insert a copy of the current frame right after it (user request: a
## starting pose when building a new animation step). The frame count syncs
## into the def on the next strip save.
func _fe_add_frame() -> void:
	var frames := maxi(int(frames_spin.value), 1)
	if frames >= int(frames_spin.max_value):
		fe_status.text = "Frame limit reached (%d)" % frames
		return
	var fw := fe_full.get_width() / frames
	var fh := fe_full.get_height()
	var out := Image.create((frames + 1) * fw, fh, false, Image.FORMAT_RGBA8)
	out.blit_rect(fe_full, Rect2i(0, 0, (cur_frame + 1) * fw, fh), Vector2i.ZERO)
	out.blit_rect(fe_full, Rect2i(cur_frame * fw, 0, fw, fh), Vector2i((cur_frame + 1) * fw, 0))
	if frames > cur_frame + 1:
		out.blit_rect(fe_full, Rect2i((cur_frame + 1) * fw, 0, (frames - cur_frame - 1) * fw, fh),
			Vector2i((cur_frame + 2) * fw, 0))
	fe_full = out
	fe_full_tex = null
	frames_spin.value = frames + 1
	cur_frame += 1
	fe_img = fe_full.get_region(Rect2i(cur_frame * fw, 0, fw, fh))
	fe_tex = null
	_update_frame_label()
	fe_status.text = "frame %d/%d (copied) - SAVE FRAME writes the longer strip" % [cur_frame + 1, frames + 1]
	_fe_dirty()

## The walk cycle playing from the in-progress strip (unsaved edits shown).
func _fe_draw_preview() -> void:
	fe_preview.draw_rect(Rect2(Vector2.ZERO, fe_preview.size), Color(0.14, 0.16, 0.2))
	if fe_full_tex == null:
		return
	var frames := maxi(int(frames_spin.value), 1)
	var fw := fe_full.get_width() / frames
	var fh := fe_full.get_height()
	var fr := int(fe_anim_t) % frames
	var sc := minf(3.0, minf(fe_preview.size.x / fw, fe_preview.size.y / fh))
	var dst := Rect2(fe_preview.size.x * 0.5 - fw * sc * 0.5, fe_preview.size.y * 0.5 - fh * sc * 0.5,
		fw * sc, fh * sc)
	fe_preview.draw_texture_rect_region(fe_full_tex, dst, Rect2(fr * fw, 0, fw, fh))

func _fe_in(pt: Vector2i) -> bool:
	return pt.x >= 0 and pt.y >= 0 and pt.x < fe_img.get_width() and pt.y < fe_img.get_height()

func _fe_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		fe_hover = Vector2i(event.position / FE_PX)
		if fe_pasting:
			fe_canvas.queue_redraw()
			return
		if fe_select:
			if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) and _fe_in(fe_hover):
				fe_sel_b = fe_hover
			fe_canvas.queue_redraw()
			return
		if _fe_in(fe_hover):
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_fe_apply(fe_hover, false)
			elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
				_fe_apply(fe_hover, true)
			elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
				_fe_erase_at(fe_hover)
		fe_canvas.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		# LMB/RMB paint, MMB clears (user request 2026-09-01); wheel
		# scrolls never touch pixels.
		var pt := Vector2i(event.position / FE_PX)
		if fe_pasting:
			if event.button_index == MOUSE_BUTTON_LEFT and _fe_in(pt):
				_fe_stamp(pt)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				fe_pasting = false
				fe_canvas.queue_redraw()
			return
		if fe_select:
			if event.button_index == MOUSE_BUTTON_LEFT and _fe_in(pt):
				fe_sel_a = pt
				fe_sel_b = pt
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				fe_sel_a = Vector2i(-1, -1)
				fe_sel_b = fe_sel_a
			fe_canvas.queue_redraw()
			return
		if not _fe_in(pt):
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_fe_erase_at(pt)
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_fe_apply(pt, event.button_index == MOUSE_BUTTON_RIGHT)

## LMB paints the primary colour, RMB the secondary; Pick samples into the
## matching slot; only the Eraser mode clears (user request 2026-09-01).
func _fe_apply(pt: Vector2i, secondary: bool) -> void:
	if fe_pick:
		var c := fe_img.get_pixel(pt.x, pt.y)
		if c.a > 0.0:
			if secondary:
				fe_brush2 = c
				fe_brush2_swatch.color = c
			else:
				fe_brush = c
				fe_brush_swatch.color = c
		return
	if fe_erase:
		fe_img.set_pixel(pt.x, pt.y, Color(0, 0, 0, 0))
	else:
		fe_img.set_pixel(pt.x, pt.y, fe_brush2 if secondary else fe_brush)
	_fe_dirty()

## Middle-click eraser: clears regardless of the current mode.
func _fe_erase_at(pt: Vector2i) -> void:
	fe_img.set_pixel(pt.x, pt.y, Color(0, 0, 0, 0))
	_fe_dirty()

func _fe_draw() -> void:
	var w := fe_img.get_width()
	var h := fe_img.get_height()
	# hot-pink checker = transparency (user request 2026-09-01)
	fe_canvas.draw_rect(Rect2(0, 0, w * FE_PX, h * FE_PX), Color(1.0, 0.25, 0.8))
	for x in w:
		for y in h:
			if (x + y) % 2 == 0:
				fe_canvas.draw_rect(Rect2(x * FE_PX, y * FE_PX, FE_PX, FE_PX), Color(0.85, 0.15, 0.65))
	if fe_tex != null:
		fe_canvas.draw_texture_rect(fe_tex, Rect2(0, 0, w * FE_PX, h * FE_PX), false)
	fe_canvas.draw_rect(Rect2(0, 0, w * FE_PX, h * FE_PX), Color(1, 1, 1, 0.2), false)
	var _sr := _fe_sel_rect()
	if _sr.size.x > 0:
		fe_canvas.draw_rect(Rect2(Vector2(_sr.position) * FE_PX, Vector2(_sr.size) * FE_PX), Color(1, 1, 0.4, 0.9), false)
	if fe_pasting and fe_clip_tex != null and _fe_in(fe_hover):
		fe_canvas.draw_texture_rect(fe_clip_tex, Rect2(Vector2(fe_hover) * FE_PX, fe_clip_tex.get_size() * FE_PX), false, Color(1, 1, 1, 0.6))
	if _fe_in(fe_hover):
		fe_canvas.draw_rect(Rect2(fe_hover.x * FE_PX, fe_hover.y * FE_PX, FE_PX, FE_PX), Color(1, 1, 0.6, 0.7), false)

## Blit the edited frame back into the strip, save, and claim the type's
## sprites so the game raw-loads them and the converter never stomps them.
func _save_frame() -> void:
	var frames := maxi(int(frames_spin.value), 1)
	var fw := fe_full.get_width() / frames
	fe_full.blit_rect(fe_img, Rect2i(Vector2i.ZERO, fe_img.get_size()), Vector2i(cur_frame * fw, 0))
	var fname := variant_option.get_item_text(variant_option.selected)
	fe_full.save_png(ProjectSettings.globalize_path(sprites_dir + fname))
	_mark_sprites_authored()
	var keep := cur_frame
	_load_preview_texture()
	cur_frame = posmod(keep, frames)
	_update_frame_label()
	fe_status.text = "Saved %s (frame %d)" % [fname, cur_frame + 1]

func _mark_sprites_authored() -> void:
	var lib := _read_library()
	for t in lib.types:
		if t.id == id_edit.text.strip_edges():
			t["authored_sprites"] = true
			if int(frames_spin.value) > 1:
				t["frames"] = int(frames_spin.value)
	var f := FileAccess.open(enemies_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(lib, " ") + "\n")
	f.close()
	def["authored_sprites"] = true

# --- Frame-editor select / copy / cut / paste (user request 2026-09-01) ---

func _fe_sel_rect() -> Rect2i:
	if fe_sel_a.x < 0:
		return Rect2i()
	var tl := Vector2i(mini(fe_sel_a.x, fe_sel_b.x), mini(fe_sel_a.y, fe_sel_b.y))
	var br := Vector2i(maxi(fe_sel_a.x, fe_sel_b.x), maxi(fe_sel_a.y, fe_sel_b.y))
	var r := Rect2i(tl, br - tl + Vector2i.ONE)
	return r.intersection(Rect2i(0, 0, fe_img.get_width(), fe_img.get_height()))

func _fe_copy(cut: bool) -> void:
	var r := _fe_sel_rect()
	if r.size.x <= 0 or r.size.y <= 0:
		fe_status.text = "Drag a selection first (Select)"
		return
	fe_clip = fe_img.get_region(r)
	fe_clip_tex = ImageTexture.create_from_image(fe_clip)
	if cut:
		for y in r.size.y:
			for x in r.size.x:
				fe_img.set_pixel(r.position.x + x, r.position.y + y, Color(0, 0, 0, 0))
		_fe_dirty()
	fe_status.text = "%s %dx%d px - Paste stamps it" % ["Cut" if cut else "Copied", r.size.x, r.size.y]

func _fe_begin_paste() -> void:
	if fe_clip == null:
		fe_status.text = "Nothing copied yet (Select, then Copy or Cut)"
		return
	fe_pasting = true
	fe_status.text = "Paste: LMB stamps at the cursor - RMB stops"

func _fe_stamp(at: Vector2i) -> void:
	for y in fe_clip.get_height():
		for x in fe_clip.get_width():
			var c := fe_clip.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var d := at + Vector2i(x, y)
			if _fe_in(d):
				fe_img.set_pixel(d.x, d.y, c)
	_fe_dirty()
