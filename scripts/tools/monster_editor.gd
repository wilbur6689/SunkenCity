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

var enemies_path := "res://data/enemies.json"
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
		["Save", "SAVE / EXPORT → data/enemies.json"],
		["Menu", "Esc"],
	]
	pm.hint_text = "Unsaved monster tuning is lost on quit — SAVE / EXPORT first"
	pm.quit_text = "QUIT TO TITLE"
	pm.quit_callable = _quit_to_title
	add_child(pm)

func _quit_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")

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
	load_option.custom_minimum_size = Vector2(110, 0)
	lrow.add_child(load_option)
	lrow.add_child(_button("New", func():
		def = _default_def()
		_sync_to_ui()))
	sv.add_child(lrow)
	var row1 := HBoxContainer.new()
	id_edit = _edit("id")
	name_edit = _edit("Name")
	row1.add_child(id_edit)
	row1.add_child(name_edit)
	sv.add_child(row1)
	mode_option = OptionButton.new()
	mode_option.add_theme_font_size_override("font_size", 8)
	for m in MODES:
		mode_option.add_item(m)
	sv.add_child(mode_option)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 2)
	w_spin = _spin(4, 64, 12)
	h_spin = _spin(4, 64, 22)
	frames_spin = _spin(1, 16, 1)
	variants_spin = _spin(1, 12, 1)
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
		_rebuild_drops()))
	sv.add_child(_button("SAVE / EXPORT", _save))
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
		on.add_theme_font_size_override("font_size", 8)
		head.add_child(on)
		var row := {"on": on}
		for stat in STATS:
			var spin := _spin(0, 500, 10)
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
	variant_option.item_selected.connect(func(_i): _load_preview_texture())
	pv.add_child(variant_option)
	var prow := HBoxContainer.new()
	play_check = CheckBox.new()
	play_check.text = "Play"
	play_check.button_pressed = true
	play_check.add_theme_font_size_override("font_size", 8)
	prow.add_child(play_check)
	hitbox_check = CheckBox.new()
	hitbox_check.text = "Hitbox"
	hitbox_check.button_pressed = true
	hitbox_check.add_theme_font_size_override("font_size", 8)
	hitbox_check.toggled.connect(func(_v): preview.queue_redraw())
	prow.add_child(hitbox_check)
	pv.add_child(prow)
	preview = Control.new()
	preview.custom_minimum_size = Vector2(200, 160)
	preview.draw.connect(_draw_preview)
	pv.add_child(preview)
	pv.add_child(UITheme.label("Sprites come from tools/convert_monsters.py\n(hand-made strips) and gen_placeholder_art.py.", 8, Color(0.6, 0.66, 0.72)))

func _edit(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.add_theme_font_size_override("font_size", 8)
	e.custom_minimum_size = Vector2(80, 0)
	return e

func _spin(minv: float, maxv: float, val: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = 1
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

func _say(text: String) -> void:
	status_label.text = text

func _rebuild_drops() -> void:
	for c in drops_box.get_children():
		c.queue_free()
	for d in def.drops:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var item := _edit("item id")
		item.text = String(d.item)
		item.custom_minimum_size = Vector2(64, 0)
		item.text_changed.connect(func(t): d.item = t.strip_edges())
		row.add_child(item)
		var mn := _spin(0, 30, int(d.min))
		mn.custom_minimum_size = Vector2(40, 0)
		mn.value_changed.connect(func(v): d.min = int(v))
		row.add_child(mn)
		var mx := _spin(0, 30, int(d.max))
		mx.custom_minimum_size = Vector2(40, 0)
		mx.value_changed.connect(func(v): d.max = int(v))
		row.add_child(mx)
		var ch := SpinBox.new()
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
			_rebuild_drops())
		del.custom_minimum_size = Vector2(16, 14)
		row.add_child(del)
		drops_box.add_child(row)

# --- Preview ---

func _process(delta: float) -> void:
	if play_check != null and play_check.button_pressed and int(frames_spin.value) > 1:
		_anim_t += delta * 6.0
		preview.queue_redraw()

func _refresh_variants() -> void:
	variant_option.clear()
	var id := id_edit.text.strip_edges()
	variant_option.add_item(id + ".png")
	for i in range(1, int(variants_spin.value)):
		var suffix := "_" + char(97 + i)
		if FileAccess.file_exists(SPRITE_DIR + id + suffix + ".png"):
			variant_option.add_item(id + suffix + ".png")
	variant_option.selected = 0
	_load_preview_texture()

func _load_preview_texture() -> void:
	_tex = null
	if variant_option.item_count > 0:
		var path := SPRITE_DIR + variant_option.get_item_text(variant_option.selected)
		if FileAccess.file_exists(path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img != null:
				_tex = ImageTexture.create_from_image(img)
	preview.queue_redraw()

func _draw_preview() -> void:
	preview.draw_rect(Rect2(Vector2.ZERO, preview.size), Color(0.16, 0.18, 0.22))
	if _tex == null:
		preview.draw_rect(Rect2(20, 20, 40, 40), Color(0.4, 0.2, 0.2), false)
		return
	var frames := maxi(int(frames_spin.value), 1)
	var fw := _tex.get_width() / frames
	var fh := _tex.get_height()
	var frame := int(_anim_t) % frames if play_check.button_pressed else 0
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
