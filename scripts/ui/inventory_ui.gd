extends CanvasLayer
## Character menu (styled after docs/Examples/UI Menus): four screens over
## the underwater menu backdrop, sharing the wood-framed 10x4 bag grid.
##   Inventory — character preview, equipment (Head, Suit, 2 Accessories,
##               2 tech-tree-locked accessory mounts), stats; a chest opens
##               its storage grid beside it (+ quick stack)
##   Crafting  — recipe list (stations in reach), recipe detail, CRAFT
##   Skills    — player level/points, skill XP bars, the ability tech tree
##   Modify    — Modification Bench (LT-09/10): learn from sacrificed gear,
##               apply learned mods to clean gear
## Drag model: LMB pick/put/swap/merge, RMB split half / place one,
## Shift+LMB move between bag and chest.

const SLOT := 24
const GAP := 2
const ICON := 16
const DESIGN_W := 640.0

const EQUIP_SLOTS := ["head", "suit", "accessory1", "accessory2", "accessory3", "accessory4"]
const EQUIP_GLYPH := {"head": 0, "suit": 1, "accessory1": 2, "accessory2": 2, "accessory3": 3, "accessory4": 3}
const EQUIP_LABEL := {"head": "Head", "suit": "Suit", "accessory1": "Accessory", "accessory2": "Accessory", "accessory3": "Accessory", "accessory4": "Accessory"}

var player: Player
var open: bool = false
var screen: String = "inventory"
var cursor_stack = null # {id, count} or null
var container: WorldObject = null
var selected_recipe: Dictionary = {}

var root: Control
var plaque_title: Label
var tab_buttons: Dictionary = {}
var screens: Dictionary = {}
var grid: GridContainer
var _bag_slots: Array = []
var _chest_slots: Array = []
var _equip_buttons: Dictionary = {}
var preview: TextureRect
var char_name: Label
var stats_label: Label
var stats_panel: PanelContainer
var storage_panel: PanelContainer
var equip_hint: Label
var recipe_list: VBoxContainer
var detail_box: VBoxContainer
var craft_button: Button
var station_label: Label
var chest_grid: GridContainer
var cursor_icon: TextureRect
var cursor_count: Label
var _last_stations: Array = []
var hover_plate: PanelContainer
var hover_name: Label
var hover_mods: Label
var _hover: Dictionary = {} # {which, index} for the slot under the mouse

## Popup window rect in design pixels; the screens keep absolute layout
## coordinates and live in a `content` control offset by -window origin.
const WIN_POS := Vector2(177, 2)
const WIN_SIZE := Vector2(286, 326)

var content: Control

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE # the game stays visible around the popup
	root.visible = false
	add_child(root)

	# A fixed 640x360 design frame, centred: on wide screens (expand stretch)
	# the viewport is wider than the design space, so absolute positions
	# would drift left without it.
	var design_frame := Control.new()
	design_frame.set_anchors_preset(Control.PRESET_CENTER)
	design_frame.offset_left = -DESIGN_W * 0.5
	design_frame.offset_top = -180
	design_frame.offset_right = DESIGN_W * 0.5
	design_frame.offset_bottom = 180
	design_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(design_frame)

	# Popup window: steel frame with the underwater rock art as its interior
	var window := Control.new()
	window.position = WIN_POS
	window.size = WIN_SIZE
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	design_frame.add_child(window)
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/backgrounds/menu_backdrop.png")
	backdrop.size = WIN_SIZE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.5, 0.55, 0.6)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(backdrop)
	var frame_panel := PanelContainer.new()
	frame_panel.add_theme_stylebox_override("panel", UITheme.steel_panel())
	frame_panel.size = WIN_SIZE
	frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(frame_panel)
	content = Control.new()
	content.position = -WIN_POS
	content.size = Vector2(DESIGN_W, 360)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(content)

	# Title plaque
	var plaque := TextureRect.new()
	plaque.texture = load("res://assets/ui/plaque.png")
	plaque.position = Vector2((DESIGN_W - 160) * 0.5, 6)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(plaque)
	plaque_title = UITheme.label("INVENTORY", 9, Color(0.97, 0.97, 0.97))
	plaque_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	plaque_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plaque_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plaque.add_child(plaque_title)

	# Tabs
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(185, 26)
	tabs.add_theme_constant_override("separation", 3)
	content.add_child(tabs)
	for name in ["inventory", "crafting", "skills", "modify"]:
		var b := Button.new()
		b.text = name.capitalize()
		b.custom_minimum_size = Vector2(48, 16)
		UITheme.style_button(b)
		b.pressed.connect(show_screen.bind(name))
		tabs.add_child(b)
		tab_buttons[name] = b

	_build_inventory_screen()
	_build_crafting_screen()
	_build_skills_screen()
	_build_modify_screen()

	# Hovered-item info plate (LT-08 rarity title text): a small panel that
	# follows the cursor over any slot — name in gray/green/blue/purple by
	# modifier state, plus one line per mod. Replaces the engine tooltips,
	# which render huge at window scale.
	hover_plate = PanelContainer.new()
	hover_plate.add_theme_stylebox_override("panel", UITheme.flat_panel(Color(0.03, 0.06, 0.09, 0.97)))
	hover_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_plate.z_index = 20
	hover_plate.visible = false
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 1)
	hover_plate.add_child(hv)
	hover_name = UITheme.label("", 8)
	hv.add_child(hover_name)
	hover_mods = UITheme.label("", 8, Color(0.75, 0.79, 0.83))
	hv.add_child(hover_mods)
	root.add_child(hover_plate)

	# Shared bag grid (wood frame) at the bottom
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.wood_frame())
	content.add_child(frame)
	grid = GridContainer.new()
	grid.columns = Constants.HOTBAR_SLOTS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	frame.add_child(grid)
	var grid_w := Constants.HOTBAR_SLOTS * SLOT + (Constants.HOTBAR_SLOTS - 1) * GAP + 12
	frame.position = Vector2((DESIGN_W - grid_w) * 0.5, 204)

	# Cursor stack
	cursor_icon = TextureRect.new()
	cursor_icon.size = Vector2(ICON, ICON)
	cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_icon.z_index = 10
	root.add_child(cursor_icon)
	cursor_count = UITheme.label("")
	cursor_count.z_index = 10
	root.add_child(cursor_count)

# --- Screen builders ---

func _panel(pos: Vector2, size: Vector2, style: StyleBox) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style)
	p.position = pos
	p.custom_minimum_size = size
	p.size = size
	return p

func _build_inventory_screen() -> void:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(s)
	screens["inventory"] = s

	# Character preview panel (steel)
	var cp := _panel(Vector2(185, 46), Vector2(104, 148), UITheme.steel_panel())
	s.add_child(cp)
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cp.add_child(cv)
	# Picture of the player (front-view portrait; becomes the paper-doll render with WS-25)
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(96, 116)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.texture = load("res://assets/ui/character_portrait.png")
	cv.add_child(preview)
	char_name = UITheme.label("Diver", 9)
	char_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(char_name)

	# Equipment 2x3 (steel slots with glyphs)
	var eq := GridContainer.new()
	eq.columns = 2
	eq.position = Vector2(297, 46)
	eq.add_theme_constant_override("h_separation", GAP)
	eq.add_theme_constant_override("v_separation", GAP)
	s.add_child(eq)
	var glyphs: Texture2D = load("res://assets/ui/equip_glyphs.png")
	for slot_name in EQUIP_SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT, SLOT)
		UITheme.style_steel_slot(b)
		var g := TextureRect.new()
		var gat := AtlasTexture.new()
		gat.atlas = glyphs
		gat.region = Rect2(EQUIP_GLYPH[slot_name] * 16, 0, 16, 16)
		g.texture = gat
		g.position = Vector2(4, 4)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(g)
		var icon := TextureRect.new()
		icon.position = Vector2(4, 4)
		icon.size = Vector2(ICON, ICON)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		# accessory3/4 start locked; the Tool Harness / Rigger's Kit
		# abilities open them (checked live in _refresh_all).
		b.gui_input.connect(_on_slot_input.bind("equip:" + slot_name, 0))
		b.mouse_entered.connect(_set_hover.bind("equip:" + slot_name, 0))
		b.mouse_exited.connect(_set_hover.bind("", -1))
		eq.add_child(b)
		_equip_buttons[slot_name] = {"button": b, "icon": icon, "glyph": g}

	# Stats (steel panel; hidden while a storage unit is open)
	stats_panel = _panel(Vector2(355, 46), Vector2(100, 148), UITheme.steel_panel())
	s.add_child(stats_panel)
	stats_label = UITheme.label("")
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_panel.add_child(stats_label)

	# Storage side panel (user request: opening storage shows the inventory
	# screen with the unit's own inventory beside it)
	storage_panel = _panel(Vector2(349, 34), Vector2(108, 168), UITheme.steel_panel())
	storage_panel.visible = false
	s.add_child(storage_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	storage_panel.add_child(sv)
	sv.add_child(UITheme.label("STORAGE", 8, Color(0.56, 0.75, 0.81)))
	chest_grid = GridContainer.new()
	chest_grid.columns = 4
	chest_grid.add_theme_constant_override("h_separation", GAP)
	chest_grid.add_theme_constant_override("v_separation", GAP)
	sv.add_child(chest_grid)
	var qs := Button.new()
	qs.text = "Quick stack"
	qs.custom_minimum_size = Vector2(0, 14)
	UITheme.style_button(qs)
	qs.pressed.connect(_quick_stack)
	sv.add_child(qs)

func _build_crafting_screen() -> void:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.visible = false
	content.add_child(s)
	screens["crafting"] = s

	var lp := _panel(Vector2(185, 46), Vector2(136, 130), UITheme.steel_panel())
	s.add_child(lp)
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	station_label = UITheme.label("By hand", 8, Color(0.7, 0.78, 0.85))
	lv.add_child(station_label)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(scroll)
	recipe_list = VBoxContainer.new()
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_list.add_theme_constant_override("separation", 0)
	scroll.add_child(recipe_list)

	var dp := _panel(Vector2(327, 46), Vector2(128, 130), UITheme.steel_panel())
	s.add_child(dp)
	# The detail pane scrolls: long ingredient lists + the description
	# don't fit 130px (user request).
	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dp.add_child(dscroll)
	detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 2)
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(detail_box)

	craft_button = Button.new()
	craft_button.text = "CRAFT"
	craft_button.custom_minimum_size = Vector2(64, 18)
	craft_button.position = Vector2(327 + 128 - 64, 46 + 130 + 4)
	UITheme.style_button(craft_button)
	craft_button.pressed.connect(_craft_selected)
	s.add_child(craft_button)

var player_stats_box: VBoxContainer
var tree_box: VBoxContainer
var selected_ability: String = ""

## Skills & player stats screen (CC-18): player level, banked points, each
## skill's XP progress, and the ability tech tree (data/abilities.json) —
## three branches, points buy capabilities, never skill levels.
func _build_skills_screen() -> void:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.visible = false
	content.add_child(s)
	screens["skills"] = s

	var pp := _panel(Vector2(185, 46), Vector2(130, 148), UITheme.steel_panel())
	s.add_child(pp)
	player_stats_box = VBoxContainer.new()
	player_stats_box.add_theme_constant_override("separation", 1)
	pp.add_child(player_stats_box)

	var tp := _panel(Vector2(321, 46), Vector2(134, 148), UITheme.steel_panel())
	s.add_child(tp)
	tree_box = VBoxContainer.new()
	tree_box.add_theme_constant_override("separation", 2)
	tp.add_child(tree_box)

func _refresh_skills() -> void:
	for c in player_stats_box.get_children():
		c.queue_free()
	for c in tree_box.get_children():
		c.queue_free()
	var sk := player.skills
	player_stats_box.add_child(UITheme.label("PLAYER", 9, Color(0.56, 0.75, 0.81)))
	player_stats_box.add_child(UITheme.label("Level %d" % sk.player_level(), 9))
	player_stats_box.add_child(UITheme.label("Ability points: %d" % sk.available_points(), 8, Color(0.95, 0.85, 0.5) if sk.available_points() > 0 else Color(0.7, 0.78, 0.85)))
	player_stats_box.add_child(UITheme.label("Weight %.1f · Swim x%.2f" % [player.inventory.total_weight(), player.swim_factor()], 8))
	var suit := player.equipped("suit")
	player_stats_box.add_child(UITheme.label("Suit  %s" % (Data.item_name(suit) if suit != "" else "none"), 8))
	player_stats_box.add_child(UITheme.label("SKILLS — level by use", 9, Color(0.56, 0.75, 0.81)))
	for skill_name in sk.xp.keys():
		var lvl := sk.level(skill_name)
		var into: float = sk.xp[skill_name] - lvl * Constants.SKILL_XP_PER_LEVEL
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		row.add_child(UITheme.label("%s — %d  (%.0f/%.0f xp)" % [skill_name.capitalize(), lvl, into, Constants.SKILL_XP_PER_LEVEL], 8))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(110, 4)
		bar.max_value = Constants.SKILL_XP_PER_LEVEL
		bar.value = into
		bar.show_percentage = false
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.06, 0.13, 0.19)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.56, 0.75, 0.81)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		player_stats_box.add_child(row)
	_refresh_tree()

## Ability tech tree (CC-18): three branch columns, tier 1 at the top;
## owned = green, affordable = white, locked = dim. Click to select, the
## UNLOCK button below spends a banked point.
func _refresh_tree() -> void:
	var sk := player.skills
	tree_box.add_child(UITheme.label("TECH TREE", 9, Color(0.56, 0.75, 0.81)))
	var branches := {}
	for a in Data.ability_list:
		if not branches.has(a.branch):
			branches[a.branch] = []
		branches[a.branch].append(a)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	tree_box.add_child(header)
	var grid := GridContainer.new()
	grid.columns = branches.size()
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	tree_box.add_child(grid)
	var max_tier := 0
	for b in branches:
		var col := UITheme.label(String(b).capitalize(), 8, Color(0.7, 0.78, 0.85))
		col.custom_minimum_size = Vector2(40, 0)
		header.add_child(col)
		for a in branches[b]:
			max_tier = maxi(max_tier, int(a.tier))
	for tier in range(1, max_tier + 1):
		for b in branches:
			for a in branches[b]:
				if int(a.tier) == tier:
					grid.add_child(_ability_button(a))
	var a_sel: Dictionary = Data.abilities.get(selected_ability, {})
	if not a_sel.is_empty():
		var nm := UITheme.label(String(a_sel.name), 8, Color(0.95, 0.85, 0.5))
		tree_box.add_child(nm)
		var dl := UITheme.label(String(a_sel.get("desc", "")), 8, Color(0.82, 0.84, 0.78))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(120, 0)
		tree_box.add_child(dl)
		var ub := Button.new()
		ub.custom_minimum_size = Vector2(60, 14)
		UITheme.style_button(ub)
		if sk.has_ability(selected_ability):
			ub.text = "OWNED"
			ub.disabled = true
		else:
			ub.text = "UNLOCK (1 pt)"
			ub.disabled = not sk.can_unlock(selected_ability)
			ub.pressed.connect(_unlock_selected)
		tree_box.add_child(ub)
	else:
		tree_box.add_child(UITheme.label("Each player level banks one\npoint. Points buy abilities,\nnot skill levels.", 8, Color(0.55, 0.6, 0.68)))

func _ability_button(a: Dictionary) -> Button:
	var sk := player.skills
	var b := Button.new()
	b.custom_minimum_size = Vector2(22, 16)
	b.text = "I".repeat(int(a.tier))
	UITheme.style_row(b, selected_ability == String(a.id))
	if sk.has_ability(a.id):
		b.modulate = Color(0.6, 1.0, 0.6)
	elif sk.can_unlock(a.id):
		b.modulate = Color.WHITE
	else:
		b.modulate = Color(0.5, 0.53, 0.58)
	b.pressed.connect(func():
		selected_ability = String(a.id)
		_refresh_all())
	return b

func _unlock_selected() -> void:
	if player.skills.unlock(selected_ability):
		player.message.emit("Learned " + String(Data.abilities[selected_ability].name))
		_refresh_all()

var bench_stack = null # item resting on the Modification Bench
var bench_button: Button
var bench_icon: TextureRect
var learned_box: VBoxContainer
var bench_info: VBoxContainer
var bench_action: Button
var sel_prefix: String = ""
var sel_suffix: String = ""
var _bench_near: bool = false

## Modification Bench screen (LT-09/10): put a MODDED item on the bench to
## LEARN its modifiers (destroys it); put clean crafted gear on to APPLY
## learned mods — up to one prefix + one suffix, then the piece is locked.
func _build_modify_screen() -> void:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.visible = false
	content.add_child(s)
	screens["modify"] = s

	var lp := _panel(Vector2(185, 46), Vector2(130, 148), UITheme.steel_panel())
	s.add_child(lp)
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	lv.add_child(UITheme.label("LEARNED MODS", 8, Color(0.56, 0.75, 0.81)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(scroll)
	learned_box = VBoxContainer.new()
	learned_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	learned_box.add_theme_constant_override("separation", 0)
	scroll.add_child(learned_box)

	var rp := _panel(Vector2(321, 46), Vector2(134, 148), UITheme.steel_panel())
	s.add_child(rp)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 3)
	rp.add_child(rv)
	rv.add_child(UITheme.label("MOD BENCH", 8, Color(0.56, 0.75, 0.81)))
	bench_button = Button.new()
	bench_button.custom_minimum_size = Vector2(SLOT, SLOT)
	bench_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.style_steel_slot(bench_button)
	bench_icon = TextureRect.new()
	bench_icon.position = Vector2(4, 4)
	bench_icon.size = Vector2(ICON, ICON)
	bench_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bench_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bench_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bench_button.add_child(bench_icon)
	bench_button.gui_input.connect(_bench_slot_input)
	bench_button.mouse_entered.connect(_set_hover.bind("bench", 0))
	bench_button.mouse_exited.connect(_set_hover.bind("", -1))
	rv.add_child(bench_button)
	bench_info = VBoxContainer.new()
	bench_info.add_theme_constant_override("separation", 2)
	bench_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(bench_info)
	bench_action = Button.new()
	bench_action.custom_minimum_size = Vector2(0, 14)
	UITheme.style_button(bench_action)
	bench_action.pressed.connect(_bench_act)
	rv.add_child(bench_action)

func _bench_slot_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var was = bench_stack
	bench_stack = cursor_stack
	cursor_stack = was
	_refresh_all()

func _refresh_modify() -> void:
	_bench_near = _stations().has("mod_bench")
	for c in learned_box.get_children():
		c.queue_free()
	for c in bench_info.get_children():
		c.queue_free()
	# Learned mods, selectable for applying (prefix and suffix pick separately)
	for part in ["prefixes", "suffixes"]:
		for m in Data.modifiers.get(part, []):
			if not player.known_mods.has(m.id):
				continue
			var power: int = int(player.known_mods[m.id])
			var b := Button.new()
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text = " " + ItemMods.describe_mod(m.id, power)
			b.custom_minimum_size = Vector2(0, 14)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 8)
			var selected: bool = (sel_prefix == m.id or sel_suffix == m.id)
			UITheme.style_row(b, selected)
			b.pressed.connect(_toggle_learned.bind(String(m.id), part == "prefixes"))
			learned_box.add_child(b)
	if learned_box.get_child_count() == 0:
		learned_box.add_child(UITheme.label("Nothing learned yet.\nSacrifice modded gear on\nthe bench to learn its mods.", 8, Color(0.55, 0.6, 0.68)))
	# Bench state → info + the one action button
	bench_icon.texture = Data.icon(bench_stack.id) if bench_stack != null else null
	bench_action.visible = false
	if not _bench_near:
		bench_info.add_child(UITheme.label("No Modification Bench\nin reach.", 8, Color(0.95, 0.6, 0.55)))
		return
	if bench_stack == null:
		bench_info.add_child(UITheme.label("Place an item on the\nbench (click with it on\nthe cursor).", 8, Color(0.7, 0.78, 0.85)))
		return
	var nm := UITheme.label(ItemMods.display_name(bench_stack), 8, ItemMods.rarity_color(bench_stack))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bench_info.add_child(nm)
	if bench_stack.has("mods"):
		for line in ItemMods.describe(bench_stack):
			bench_info.add_child(UITheme.label(String(line), 8, Color(0.82, 0.84, 0.78)))
		bench_info.add_child(UITheme.label("Learning destroys the item.", 8, Color(0.95, 0.6, 0.55)))
		bench_action.visible = true
		bench_action.text = "LEARN"
		bench_action.disabled = player.learnable_mods(bench_stack).is_empty()
	elif ItemMods.mod_class(bench_stack.id) != "":
		bench_info.add_child(UITheme.label("Unmodified — pick learned\nmods to apply. Once modded\nit is locked for good.", 8, Color(0.7, 0.78, 0.85)))
		bench_action.visible = true
		bench_action.text = "APPLY"
		bench_action.disabled = sel_prefix == "" and sel_suffix == ""
	else:
		bench_info.add_child(UITheme.label("This cannot take modifiers.", 8, Color(0.7, 0.78, 0.85)))

func _toggle_learned(mod_id: String, is_prefix: bool) -> void:
	if is_prefix:
		sel_prefix = "" if sel_prefix == mod_id else mod_id
	else:
		sel_suffix = "" if sel_suffix == mod_id else mod_id
	_refresh_all()

func _bench_act() -> void:
	if bench_stack == null or not _bench_near:
		return
	if bench_stack.has("mods"):
		if player.learnable_mods(bench_stack).is_empty():
			return
		var learned: Array = player.learn_mods(bench_stack)
		bench_stack = null # sacrificed (LT-09)
		Audio.play_sfx("dismantle_rattle", player.global_position, 1, -4.0)
		player.message.emit("Learned: " + ", ".join(learned) if not learned.is_empty() else "Nothing new to learn")
	else:
		if player.apply_mods(bench_stack, sel_prefix, sel_suffix):
			player.message.emit("Modified: " + ItemMods.display_name(bench_stack))
			sel_prefix = ""
			sel_suffix = ""
	_refresh_all()

func _make_slots(target: GridContainer, inv: Inventory, which: String) -> Array:
	for c in target.get_children():
		c.queue_free()
	var out := []
	for i in inv.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT, SLOT)
		b.focus_mode = Control.FOCUS_NONE
		UITheme.style_slot(b)
		var icon := TextureRect.new()
		icon.position = Vector2(4, 4)
		icon.size = Vector2(ICON, ICON)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		var count := UITheme.label("")
		count.set_anchors_preset(Control.PRESET_FULL_RECT)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		b.add_child(count)
		b.gui_input.connect(_on_slot_input.bind(which, i))
		b.mouse_entered.connect(_set_hover.bind(which, i))
		b.mouse_exited.connect(_set_hover.bind("", -1))
		target.add_child(b)
		out.append({"button": b, "icon": icon, "count": count})
	return out

func _set_hover(which: String, index: int) -> void:
	_hover = {} if which == "" else {"which": which, "index": index}

func _hover_stack():
	if _hover.is_empty() or player == null:
		return null
	var w: String = _hover.which
	if w == "inv":
		return player.inventory.slots[_hover.index]
	if w == "chest" and container != null and is_instance_valid(container):
		return container.storage.slots[_hover.index]
	if w == "bench":
		return bench_stack
	if w.begins_with("equip:"):
		return player.equipment.get(w.substr(6))
	return null

func _update_hover_plate() -> void:
	if _hover.is_empty() or cursor_stack != null: # hidden while dragging
		hover_plate.visible = false
		return
	var st = _hover_stack()
	var title := ""
	var color := Color(0.75, 0.79, 0.83)
	var lines: Array = []
	if st != null:
		title = ItemMods.display_name(st)
		color = ItemMods.rarity_color(st)
		lines = ItemMods.describe(st)
	elif String(_hover.which).begins_with("equip:"):
		# Empty equipment slot: name it (or explain the lock).
		var slot_name := String(_hover.which).substr(6)
		title = EQUIP_LABEL[slot_name] if player.slot_unlocked(slot_name) \
				else "Reserved — the tech tree unlocks it"
	if title == "":
		hover_plate.visible = false
		return
	hover_name.text = title
	hover_name.add_theme_color_override("font_color", color)
	hover_mods.text = "\n".join(lines)
	hover_mods.visible = not lines.is_empty()
	hover_plate.visible = true
	hover_plate.reset_size()
	var m := root.get_local_mouse_position() + Vector2(8, 10)
	var vis := root.get_viewport_rect().size
	hover_plate.position = Vector2(minf(m.x, vis.x - hover_plate.size.x - 2), minf(m.y, vis.y - hover_plate.size.y - 2))

# --- Open / close / screens ---

func toggle() -> void:
	if open:
		close()
	else:
		open_panel()

func open_panel(station: String = "") -> void:
	if player == null:
		return
	open = true
	root.visible = true
	player.ui_blocks_mouse = true
	if _bag_slots.is_empty():
		_bag_slots = _make_slots(grid, player.inventory, "inv")
	# Clicking the Modification Bench itself lands on its screen (LT-09/10).
	if station == "mod_bench":
		show_screen("modify")
	else:
		show_screen("crafting" if station != "" else "inventory")

func close() -> void:
	open = false
	_clear_slot_scrap()
	root.visible = false
	container = null
	if storage_panel != null:
		storage_panel.visible = false
		stats_panel.visible = true
	if player != null:
		player.ui_blocks_mouse = false
		for held in [cursor_stack, bench_stack]: # never lose a stack on close
			if held == null:
				continue
			if held.has("mods"): # keep the instance's mods intact
				if not player.inventory.add_stack(held):
					World.spawn_item(held.id, held.count, player.global_position)
			else:
				var leftover: int = player.inventory.add(held.id, held.count)
				if leftover > 0:
					World.spawn_item(held.id, leftover, player.global_position)
		cursor_stack = null
		bench_stack = null

func open_container(obj: WorldObject) -> void:
	container = obj
	open_panel()
	_chest_slots = _make_slots(chest_grid, obj.storage, "chest")
	stats_panel.visible = false
	storage_panel.visible = true
	show_screen("inventory")

func show_screen(name: String) -> void:
	screen = name
	for k in screens.keys():
		screens[k].visible = (k == name)
	plaque_title.text = name.to_upper()
	_refresh_all()

func _process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		if player == null:
			return
		player.container_opened.connect(open_container)
		player.crafting_opened.connect(open_panel)
		player.inventory.changed.connect(_refresh_all)
	if Input.is_action_just_pressed("inventory"):
		toggle()
	if not open:
		if Input.is_action_just_pressed("ui_cancel"):
			# Esc with the menu open just closes it. Without a menu: in the
			# city, save and return to the title (quit from there); in bare
			# test scenes there is no title flow, so quit outright.
			var scene := get_tree().current_scene
			if scene != null and scene.has_method("save_and_exit_to_title"):
				scene.save_and_exit_to_title()
			else:
				get_tree().quit()
		return
	if Input.is_action_just_pressed("ui_cancel"):
		close()
		return
	if container != null:
		var reach := Constants.REACH_BLOCKS * Constants.BLOCK_SIZE * 1.5
		if not is_instance_valid(container) or container.center().distance_to(player.global_position) > reach:
			close()
			return
	var m := root.get_local_mouse_position()
	cursor_icon.position = m + Vector2(4, 4)
	cursor_count.position = m + Vector2(12, 8)
	_tick_slot_scrap(get_process_delta_time())
	_update_hover_plate()
	if screen == "crafting":
		_refresh_crafting()
	elif screen == "modify" and _stations().has("mod_bench") != _bench_near:
		_refresh_modify() # bench walked into / out of reach

# --- Refresh ---

func _refresh_all() -> void:
	if not open or player == null:
		return
	_refresh_grid(_bag_slots, player.inventory, true)
	if container != null and is_instance_valid(container):
		_refresh_grid(_chest_slots, container.storage, false)
	for slot_name in _equip_buttons.keys():
		var st = player.equipment.get(slot_name)
		var eb: Dictionary = _equip_buttons[slot_name]
		eb.icon.texture = Data.icon(st.id) if st != null else null
		eb.glyph.visible = st == null
		var locked: bool = not player.slot_unlocked(slot_name)
		eb.button.modulate = Color(0.55, 0.57, 0.62) if locked else Color.WHITE
	var s := player.skills
	stats_label.text = "Level %d\nPoints %d\n\nScrapping %d\nSwimming %d\nBuilding %d\n\nWeight %.1f\nSwim x%.2f" % [
		s.player_level(), s.available_points(), s.level("scrapping"), s.level("swimming"), s.level("building"),
		player.inventory.total_weight(), player.swim_factor()]
	cursor_icon.texture = Data.icon(cursor_stack.id) if cursor_stack != null else null
	cursor_count.text = str(cursor_stack.count) if (cursor_stack != null and cursor_stack.count > 1) else ""
	if screen == "crafting":
		_refresh_crafting(true)
	elif screen == "skills":
		_refresh_skills()
	elif screen == "modify":
		_refresh_modify()

func _refresh_grid(ui_slots: Array, inv: Inventory, is_bag: bool) -> void:
	for i in ui_slots.size():
		var st = inv.slots[i]
		ui_slots[i].icon.texture = Data.icon(st.id) if st != null else null
		ui_slots[i].count.text = str(st.count) if (st != null and st.count > 1) else ""
		if is_bag:
			UITheme.style_slot(ui_slots[i].button, i == player.selected_slot)

func _stations() -> Array:
	return World.stations_near(player.global_position, Constants.REACH_BLOCKS * Constants.BLOCK_SIZE * 1.5)

func _refresh_crafting(force: bool = false) -> void:
	var stations := _stations()
	if not force and stations == _last_stations:
		for b in recipe_list.get_children():
			_dim_recipe_row(b, player.can_craft(b.get_meta("recipe")))
		craft_button.disabled = selected_recipe.is_empty() or not player.can_craft(selected_recipe)
		return
	_last_stations = stations.duplicate()
	for c in recipe_list.get_children():
		c.queue_free()
	var names := []
	for st in stations:
		if st != "hand":
			names.append(Data.objects[st].name if Data.objects.has(st) else st)
	station_label.text = "By hand" if names.is_empty() else ", ".join(names)
	var available := []
	for st in stations:
		for r in Data.recipes_for_station(st, player.knows_recipe):
			available.append(r)
	if selected_recipe.is_empty() or not available.has(selected_recipe):
		selected_recipe = available[0] if not available.is_empty() else {}
	for r in available:
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "  " + Data.item_name(r.output.item) + ("" if int(r.output.count) == 1 else " x%d" % int(r.output.count))
		b.icon = Data.icon(r.output.item)
		b.expand_icon = false
		b.custom_minimum_size = Vector2(0, 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_row(b, r == selected_recipe)
		b.set_meta("recipe", r)
		# Uncraftable recipes stay CLICKABLE (user request) — dimmed so the
		# player can inspect what they will need; only CRAFT is gated.
		_dim_recipe_row(b, player.can_craft(r))
		b.pressed.connect(_select_recipe.bind(r))
		recipe_list.add_child(b)
	_refresh_detail()

func _dim_recipe_row(b: Button, craftable: bool) -> void:
	b.disabled = false
	b.modulate = Color.WHITE if craftable else Color(0.55, 0.57, 0.62)

func _select_recipe(r: Dictionary) -> void:
	selected_recipe = r
	for b in recipe_list.get_children():
		UITheme.style_row(b, b.get_meta("recipe") == r)
	_refresh_detail()

func _refresh_detail() -> void:
	for c in detail_box.get_children():
		c.queue_free()
	if selected_recipe.is_empty():
		detail_box.add_child(UITheme.label("No recipes here", 8, Color(0.7, 0.78, 0.85)))
		craft_button.disabled = true
		return
	var r := selected_recipe
	# Big picture of what will be crafted
	var pic := TextureRect.new()
	pic.texture = Data.icon(r.output.item)
	pic.custom_minimum_size = Vector2(48, 48)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_box.add_child(pic)
	var title := UITheme.label("%s x%d" % [Data.item_name(r.output.item), int(r.output.count)], 9)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_box.add_child(title)
	var st_name: String = "By hand" if r.station == "hand" else (Data.objects[r.station].name if Data.objects.has(r.station) else r.station)
	detail_box.add_child(UITheme.label("%s · tier %d" % [st_name, int(r.tier)], 8, Color(0.7, 0.78, 0.85)))
	detail_box.add_child(UITheme.label("Needs:", 8, Color(0.7, 0.78, 0.85)))
	for inp in r.inputs:
		var have: int = player.inventory.count(inp.item)
		var ok := have >= int(inp.count)
		var row := HBoxContainer.new()
		var ii := TextureRect.new()
		ii.texture = Data.icon(inp.item)
		ii.custom_minimum_size = Vector2(ICON, ICON)
		ii.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ii)
		row.add_child(UITheme.label("%s  %d/%d" % [Data.item_name(inp.item), have, int(inp.count)], 8,
			Color(0.75, 0.95, 0.75) if ok else Color(0.95, 0.6, 0.55)))
		detail_box.add_child(row)
	# Description last (user request): the requirements are what matters.
	var desc := Data.item_desc(r.output.item)
	if desc != "":
		var dl := UITheme.label(desc, 8, Color(0.82, 0.84, 0.78))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_box.add_child(dl)
	craft_button.disabled = not player.can_craft(r)

# --- Actions ---

func _craft_selected() -> void:
	if not selected_recipe.is_empty() and player.craft(selected_recipe):
		player.message.emit("Crafted " + Data.item_name(selected_recipe.output.item))
		_refresh_crafting(true)

func _quick_stack() -> void:
	if container != null and is_instance_valid(container):
		var moved: int = player.inventory.quick_stack_into(container.storage)
		player.message.emit("Quick-stacked %d items" % moved)
		_refresh_all()

func _inv_for(which: String) -> Inventory:
	return player.inventory if which == "inv" else container.storage

func _other_for(which: String) -> Inventory:
	if which == "inv":
		return container.storage if (container != null and is_instance_valid(container)) else null
	return player.inventory

func _on_slot_input(event: InputEvent, which: String, index: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if which.begins_with("equip:"):
		_equip_click(event, which.substr(6))
		_refresh_all()
		return
	var inv := _inv_for(which)
	var slot = inv.slots[index]
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.shift_pressed:
			var other := _other_for(which)
			if other != null and slot != null:
				var leftover := other.add(slot.id, slot.count)
				inv.set_slot(index, {"id": slot.id, "count": leftover} if leftover > 0 else null)
		elif cursor_stack == null:
			cursor_stack = slot
			inv.set_slot(index, null)
		elif slot == null:
			inv.set_slot(index, cursor_stack)
			cursor_stack = null
		elif slot.id == cursor_stack.id:
			var room: int = Data.stack_size(slot.id) - slot.count
			var take: int = mini(room, cursor_stack.count)
			slot.count += take
			cursor_stack.count -= take
			if cursor_stack.count <= 0:
				cursor_stack = null
			inv.set_slot(index, slot)
		else:
			inv.set_slot(index, cursor_stack)
			cursor_stack = slot
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if cursor_stack == null:
			if slot != null:
				# Scrappable bag items: RMB press starts a hold-to-scrap
				# (same rule as scrapping furniture in the world); a quick
				# tap still takes half the stack.
				if which == "inv" and not Data.scrap_yield(slot.id).is_empty():
					_begin_slot_scrap(index, slot.id)
					return
				_rmb_take_half(inv, index)
		elif slot == null:
			if cursor_stack.has("mods"): # a modded instance places whole
				inv.set_slot(index, cursor_stack)
				cursor_stack = null
			else:
				inv.set_slot(index, {"id": cursor_stack.id, "count": 1})
				cursor_stack.count -= 1
				if cursor_stack.count <= 0:
					cursor_stack = null
		elif slot.id == cursor_stack.id and slot.count < Data.stack_size(slot.id):
			slot.count += 1
			cursor_stack.count -= 1
			if cursor_stack.count <= 0:
				cursor_stack = null
			inv.set_slot(index, slot)
	_refresh_all()

# --- Hold-RMB scrapping from the bag (user request) ---

var scrap_hold: Dictionary = {} # {index, id, time, duration} while RMB held
var scrap_hold_bar: ProgressBar = null

func _rmb_take_half(inv: Inventory, index: int) -> void:
	var slot = inv.slots[index]
	if slot == null:
		return
	if slot.has("mods") or slot.count == 1: # modded instances move whole
		cursor_stack = slot
		inv.set_slot(index, null)
		_refresh_all()
		return
	var half: int = int(ceil(slot.count / 2.0))
	cursor_stack = {"id": slot.id, "count": half}
	slot.count -= half
	inv.set_slot(index, slot if slot.count > 0 else null)
	_refresh_all()

func _begin_slot_scrap(index: int, id: String) -> void:
	var src: Dictionary = Data.objects.get(id, Data.item(id))
	scrap_hold = {"index": index, "id": id, "time": 0.0,
		"duration": float(src.get("scrap_time", 1.5)) / player.scrap_speed_mult()}
	if scrap_hold_bar == null:
		scrap_hold_bar = ProgressBar.new()
		scrap_hold_bar.show_percentage = false
		scrap_hold_bar.custom_minimum_size = Vector2(0, 3)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.05, 0.05, 0.08, 0.9)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.95, 0.8, 0.35)
		scrap_hold_bar.add_theme_stylebox_override("background", bg)
		scrap_hold_bar.add_theme_stylebox_override("fill", fill)
		scrap_hold_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var btn: Button = _bag_slots[index].button
	if scrap_hold_bar.get_parent() != null:
		scrap_hold_bar.get_parent().remove_child(scrap_hold_bar)
	btn.add_child(scrap_hold_bar)
	scrap_hold_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	scrap_hold_bar.offset_top = -3
	scrap_hold_bar.value = 0.0
	scrap_hold_bar.visible = true

func _clear_slot_scrap() -> void:
	scrap_hold = {}
	if scrap_hold_bar != null:
		scrap_hold_bar.visible = false

func _tick_slot_scrap(delta: float) -> void:
	if scrap_hold.is_empty():
		return
	var inv := player.inventory
	var slot = inv.slots[scrap_hold.index]
	if slot == null or slot.id != scrap_hold.id:
		_clear_slot_scrap()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if scrap_hold.time < 0.25: # a quick tap keeps the split-stack action
			_rmb_take_half(inv, scrap_hold.index)
		_clear_slot_scrap()
		return
	scrap_hold.time += delta
	scrap_hold.sfx = scrap_hold.get("sfx", 0.0) - delta
	if scrap_hold.sfx <= 0.0:
		scrap_hold.sfx = Constants.SCRAP_SFX_INTERVAL
		Audio.play_sfx("creak_plastic", player.global_position, 3, -8.0)
	scrap_hold_bar.value = scrap_hold.time / scrap_hold.duration * 100.0
	if scrap_hold.time >= scrap_hold.duration:
		if player.scrap_item(scrap_hold.id, 1, true):
			Audio.play_sfx("dismantle_rattle", player.global_position, 1, -4.0)
			_refresh_all()
			scrap_hold.time = 0.0 # keep holding to keep scrapping the stack
			scrap_hold_bar.value = 0.0
		else:
			_clear_slot_scrap()

## Equipment slots hold one item; LMB swaps with the cursor when the item fits the slot.
func _equip_click(event: InputEventMouseButton, slot_name: String) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var current = player.equipment.get(slot_name)
	if cursor_stack == null:
		if current != null:
			cursor_stack = current
			player.set_equipment(slot_name, null)
		return
	if not player.slot_unlocked(slot_name):
		player.message.emit("That mount is locked — an ability on the tech tree opens it")
		return
	if not player.can_equip(slot_name, cursor_stack.id):
		player.message.emit("%s cannot go in the %s slot" % [Data.item_name(cursor_stack.id), EQUIP_LABEL[slot_name]])
		return
	var one = cursor_stack.duplicate(true) # keep per-instance mods (LT-05..07)
	one.count = 1
	cursor_stack.count -= 1
	var rest = cursor_stack if cursor_stack.count > 0 else null
	player.set_equipment(slot_name, one)
	if current != null:
		if rest == null:
			rest = current
		else:
			var leftover: int = player.inventory.add(current.id, current.count)
			if leftover > 0:
				World.spawn_item(current.id, leftover, player.global_position)
	cursor_stack = rest
