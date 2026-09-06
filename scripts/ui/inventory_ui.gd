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
## LAN Step 7: the lifted "cursor" (and the Modification Bench slot) is a
## client-side REFERENCE to a slot - the item never leaves its inventory
## while lifted - and every mutation is a named slot-index action on the
## player's `Actions` child (PlayerActions), which applies it offline / on
## the host and requests it from the host on a client. Nothing in here
## writes `player.inventory` / `equipment` / `skills` / chest storage directly.

const SLOT := 24
const GAP := 2
const ICON := 16
const DESIGN_W := 640.0

const EQUIP_SLOTS := ["head", "suit", "weapon", "accessory1", "accessory2", "accessory3", "accessory4"]
const EQUIP_GLYPH := {"head": 0, "suit": 1, "weapon": 4, "accessory1": 2, "accessory2": 2, "accessory3": 3, "accessory4": 3}
const EQUIP_LABEL := {"head": "Head", "suit": "Suit", "weapon": "Weapon", "accessory1": "Accessory", "accessory2": "Accessory", "accessory3": "Accessory", "accessory4": "Accessory"}

var player: Player
var open: bool = false
var screen: String = "inventory"
## The lifted stack: {} or {which: "inv"|"chest"|"equip", index, cell (chest),
## slot_name (equip), count (how much of the slot is lifted), id}.
var cursor: Dictionary = {}
var container: WorldObject = null
var _watched_storage: Inventory = null # the open chest's inventory (refresh on replicated changes)
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
var station_tabs: Dictionary = {} # station id -> tab Button
var station_name_label: Label
var selected_station: String = "hand"
var chest_grid: GridContainer
var cursor_icon: TextureRect
var cursor_count: Label
var _last_stations: Array = []
var hover_plate: PanelContainer
var hover_name: Label
var hover_mods: Label
var hover_tier_row: HBoxContainer
var hover_tier_badge: Control
var hover_tier_text: Label
const TIER_BADGE := preload("res://scripts/ui/tier_badge.gd")
var _hover: Dictionary = {} # {which, index} for the slot under the mouse

## Popup window rect in design pixels; the screens keep absolute layout
## coordinates and live in a `content` control offset by -window origin.
## Widened for the 4-tab strip + the storage side panel (user request).
const WIN_POS := Vector2(152, 2)
const WIN_SIZE := Vector2(336, 326)

var content: Control

## Set when Esc closes this menu, so the pause menu (which polls after us)
## does not open on the same keypress.
var esc_consumed_frame: int = -1

func _ready() -> void:
	add_to_group("inventory_ui")
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE # the game stays visible around the popup
	root.visible = false
	add_child(root)
	UIScale.register(root) # UI size scaling (2026-09-02)

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
	# Tool tier (user request 2026-09-06): the same shield the object card
	# shows for the tier an object NEEDS, here for the tier a tool CAN dismantle.
	hover_tier_row = HBoxContainer.new()
	hover_tier_row.add_theme_constant_override("separation", 3)
	hover_tier_badge = TIER_BADGE.new()
	hover_tier_row.add_child(hover_tier_badge)
	hover_tier_text = UITheme.label("", 8, Color(0.75, 0.8, 0.82))
	hover_tier_row.add_child(hover_tier_text)
	hv.add_child(hover_tier_row)
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
		gat.region = Rect2(EQUIP_GLYPH[slot_name] * Data.ICON_PX, 0, Data.ICON_PX, Data.ICON_PX)
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
	# screen with the unit's own inventory beside it). Sits below the tab
	# strip so all four tabs stay visible; quick stack rides the header row
	# so a full 20-slot unit still fits above the bag grid.
	storage_panel = _panel(Vector2(365, 44), Vector2(112, 158), UITheme.steel_panel())
	storage_panel.visible = false
	s.add_child(storage_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	storage_panel.add_child(sv)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 2)
	var st_label := UITheme.label("STORAGE", 8, Color(0.56, 0.75, 0.81))
	st_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(st_label)
	var qs := Button.new()
	qs.text = "Stack"
	qs.tooltip_text = ""
	qs.custom_minimum_size = Vector2(34, 12)
	UITheme.style_button(qs)
	qs.pressed.connect(_quick_stack)
	sh.add_child(qs)
	sv.add_child(sh)
	chest_grid = GridContainer.new()
	chest_grid.columns = 4
	chest_grid.add_theme_constant_override("h_separation", GAP)
	chest_grid.add_theme_constant_override("v_separation", GAP)
	sv.add_child(chest_grid)

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
	# One tab per station (user request): every catalog is browsable
	# anywhere; the tab lights up when that station is in reach, and CRAFT
	# is gated on standing at it. The Mod Bench has its own Modify screen.
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 2)
	lv.add_child(tab_row)
	for st: String in ["hand", "workbench", "forge", "med_station", "dive_station"]:
		var tb := Button.new()
		tb.custom_minimum_size = Vector2(22, 20)
		tb.focus_mode = Control.FOCUS_NONE
		UITheme.style_steel_slot(tb)
		var ic := TextureRect.new()
		ic.texture = Data.icon("hammer") if st == "hand" else Data.icon(st)
		# expand mode FIRST: station sprites are bigger than a slot icon, and
		# a TextureRect clamps size to the texture until it may shrink.
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(3, 2)
		ic.size = Vector2(ICON, ICON)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tb.add_child(ic)
		tb.pressed.connect(func():
			selected_station = st
			_refresh_crafting(true))
		tab_row.add_child(tb)
		station_tabs[st] = tb
	station_name_label = UITheme.label("By hand", 8, Color(0.7, 0.78, 0.85))
	lv.add_child(station_name_label)
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
	if _act("unlock_ability", [selected_ability]):
		_refresh_all()

var bench: Dictionary = {} # bag-slot reference resting on the Modification Bench ({} = empty)
var bench_button: Button
var bench_icon: TextureRect
var learned_box: VBoxContainer
var bench_info: VBoxContainer
var bench_action: Button
var library_grid: GridContainer
var library_pick: Label
## Library picks (up to two ids; the same id twice for a vertical combine).
## APPLY reads the first prefix / first suffix among them; COMBINE needs two.
var sel: Array = []
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
	lv.add_theme_constant_override("separation", 1)
	lp.add_child(lv)
	lv.add_child(UITheme.label("MOD LIBRARY", 8, Color(0.56, 0.75, 0.81)))
	# The 6 × 5 grid (family rows × tier columns) — the "map of where you
	# have been"; cells carry the stock count and dim at zero.
	library_grid = GridContainer.new()
	library_grid.columns = 6
	library_grid.add_theme_constant_override("h_separation", 1)
	library_grid.add_theme_constant_override("v_separation", 1)
	lv.add_child(library_grid)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 22)
	lv.add_child(scroll)
	learned_box = VBoxContainer.new()
	learned_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	learned_box.add_theme_constant_override("separation", 0)
	scroll.add_child(learned_box)
	library_pick = UITheme.label("", 8, Color(0.82, 0.84, 0.78))
	library_pick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	library_pick.custom_minimum_size = Vector2(0, 12)
	lv.add_child(library_pick)

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

## The bench holds a reference to a bag slot (the piece stays in the bag
## until LEARN destroys it); the cursor and the bench swap references.
func _bench_slot_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var cur = _cursor_stack()
	var on_bench = _bench_stack()
	if cur == null:
		if on_bench != null:
			cursor = bench
			bench = {}
	elif cursor.which == "inv":
		var was := bench
		bench = _make_ref("inv", int(cursor.index), int(_ref_stack(cursor).count))
		cursor = was
	else:
		player.message.emit("Only items from your bag go on the bench")
	_refresh_all()

const LIB_CELL := Vector2(17, 10)

func _library_cell(mod_id: String, text: String, tint: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = LIB_CELL
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 8)
	var count := player.library_count(mod_id)
	var picks := sel.count(mod_id)
	UITheme.style_row(b, picks > 0)
	# Rows must stack 7 high in the panel: no stylebox padding, a smaller face.
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBox = b.get_theme_stylebox(st).duplicate()
		sb.set_content_margin_all(0)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_size_override("font_size", 7)
	b.disabled = count <= 0
	b.add_theme_color_override("font_color", tint if count > 0 else tint.darkened(0.55))
	b.add_theme_color_override("font_disabled_color", tint.darkened(0.6))
	if picks > 0:
		b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.tooltip_text = ItemMods.describe_mod(mod_id) + ("\nin stock: %d" % count) if count > 0 else ItemMods.describe_mod(mod_id)
	b.pressed.connect(_toggle_library.bind(mod_id))
	return b

func _refresh_modify() -> void:
	_bench_near = _stations().has("mod_bench")
	for c in library_grid.get_children():
		c.queue_free()
	for c in learned_box.get_children():
		c.queue_free()
	for c in bench_info.get_children():
		c.queue_free()
	# Drop picks whose stock ran out (an APPLY / COMBINE just consumed them).
	var kept := []
	for id in sel:
		if kept.count(id) < player.library_count(id):
			kept.append(id)
	sel = kept
	_sync_picks()
	# Header row: blank corner + tier numerals.
	library_grid.add_child(UITheme.label("", 8))
	for t in 5:
		var h := UITheme.label(ItemMods.ROMAN[t + 1], 8, Color(0.56, 0.75, 0.81))
		h.custom_minimum_size = LIB_CELL
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		library_grid.add_child(h)
	# Family rows in file order (prefix families first, then suffix families).
	for fam in Data.modifier_families:
		var f: Dictionary = Data.modifier_families[fam]
		var c: Array = f.color
		var tint := Color(c[0], c[1], c[2])
		var lab := UITheme.label(String(f.label), 8, tint)
		lab.custom_minimum_size = Vector2(22, LIB_CELL.y)
		lab.tooltip_text = "%s (%s)\n%s" % [fam.capitalize(), f.slot, f.desc]
		library_grid.add_child(lab)
		for mid in f.tiers:
			var n := player.library_count(String(mid))
			library_grid.add_child(_library_cell(String(mid), str(n) if n > 0 else "-", tint))
	# Hybrids in stock, as rows.
	var any_hybrid := false
	for h in Data.modifier_hybrids:
		var n := player.library_count(String(h.id))
		if n <= 0:
			continue
		any_hybrid = true
		var b := _library_cell(String(h.id), " %s  x%d" % [h.name, n], Color(0.9, 0.85, 0.7))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		learned_box.add_child(b)
	if not any_hybrid:
		var hint := "Sacrifice modded gear on the bench to stock it." if player.mod_library.is_empty() \
			else "Combine two same-tier mods of different districts for a hybrid."
		learned_box.add_child(UITheme.label(hint, 8, Color(0.55, 0.6, 0.68)))
	# What is picked, and what two picks would make.
	var pick_names := []
	for id in sel:
		pick_names.append(String(ItemMods.def_of(id).get("name", id)))
	var combo := ItemMods.combine_result(String(sel[0]), String(sel[1])) if sel.size() == 2 else ""
	if sel.is_empty():
		library_pick.text = ""
	elif combo != "":
		library_pick.text = " + ".join(pick_names) + " -> " + String(ItemMods.def_of(combo).get("name", combo))
	else:
		library_pick.text = " + ".join(pick_names) + (" (no recipe)" if sel.size() == 2 else "")
	# Bench state → info + the one action button
	var bench_stack = _bench_stack()
	bench_icon.texture = Data.icon(bench_stack.id) if bench_stack != null else null
	bench_action.visible = false
	if not _bench_near:
		bench_info.add_child(UITheme.label("No Modification Bench\nin reach.", 8, Color(0.95, 0.6, 0.55)))
		return
	if bench_stack == null:
		bench_info.add_child(UITheme.label("Bench empty: pick two\nlibrary mods of one tier\nto COMBINE, or place an\nitem (click with it on\nthe cursor).", 8, Color(0.7, 0.78, 0.85)))
		bench_action.visible = true
		bench_action.text = "COMBINE"
		bench_action.disabled = combo == ""
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
		bench_info.add_child(UITheme.label("Unmodified — pick library\nmods to apply (consumed).\nOnce modded it is locked\nfor good.", 8, Color(0.7, 0.78, 0.85)))
		bench_action.visible = true
		bench_action.text = "APPLY"
		bench_action.disabled = sel_prefix == "" and sel_suffix == ""
	else:
		bench_info.add_child(UITheme.label("This cannot take modifiers.", 8, Color(0.7, 0.78, 0.85)))

## The tier row under a tooltip title: a tool's dismantle tier (axes fell
## trees only), or a plain weapon's "no dismantling" note.
func _set_hover_tier(st) -> void:
	hover_tier_row.visible = false
	if st == null:
		return
	var it := Data.item(String(st.id))
	var tool: Dictionary = it.get("tool", {})
	if not tool.is_empty():
		var tier := int(tool.get("tier", 0))
		hover_tier_badge.set_tier(tier)
		hover_tier_badge.visible = true
		if String(tool.get("type", "")) == "axe":
			hover_tier_text.text = "Fells trees (tier %d)" % tier
		else:
			hover_tier_text.text = "Dismantles tier %d and below" % tier
		hover_tier_row.visible = true
	elif it.has("weapon"):
		hover_tier_badge.visible = false
		hover_tier_text.text = "Weapon: no dismantling"
		hover_tier_row.visible = true

## sel -> the first prefix / first suffix picked (what APPLY uses).
func _sync_picks() -> void:
	sel_prefix = ""
	sel_suffix = ""
	for id in sel:
		if ItemMods.slot_of(id) == "prefix" and sel_prefix == "":
			sel_prefix = id
		elif ItemMods.slot_of(id) == "suffix" and sel_suffix == "":
			sel_suffix = id

## A click cycles a cell: none -> picked -> picked twice (stock >= 2, for the
## vertical combine) -> none. At most two picks; the oldest gives way.
func _toggle_library(mod_id: String) -> void:
	var picks := sel.count(mod_id)
	if picks == 0:
		sel.append(mod_id)
	elif picks == 1 and player.library_count(mod_id) >= 2 and sel.size() < 2:
		sel.append(mod_id)
	else:
		while sel.has(mod_id):
			sel.erase(mod_id)
	while sel.size() > 2:
		sel.pop_front()
	_sync_picks()
	_refresh_all()

func _bench_act() -> void:
	var bench_stack = _bench_stack()
	if not _bench_near:
		return
	if bench_stack == null:
		if sel.size() == 2 and _act("combine_mods", [String(sel[0]), String(sel[1])]):
			sel.clear()
			Audio.play_sfx("dismantle_rattle", player.global_position, 1, -6.0)
	elif bench_stack.has("mods"):
		if player.learnable_mods(bench_stack).is_empty():
			return
		if _act("learn_mods", [int(bench.index)]): # sacrificed (LT-09)
			bench = {}
			Audio.play_sfx("dismantle_rattle", player.global_position, 1, -4.0)
	else:
		if _act("apply_mods", [int(bench.index), sel_prefix, sel_suffix]):
			sel.clear()
	_sync_picks()
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
		return container.storage.slots[_hover.index] if _hover.index < container.storage.slots.size() else null
	if w == "bench":
		return _bench_stack()
	if w.begins_with("equip:"):
		return player.equipment.get(w.substr(6))
	return null

# --- Slot references (the lifted cursor / the bench) and the action funnel ---

func _actions() -> PlayerActions:
	return player.get_node_or_null("Actions") as PlayerActions if player != null else null

## Every mutation goes through here: PlayerActions applies it (host/offline)
## or requests it from the host (client). Returns whether it applied / went out.
func _act(action: String, args: Array = []) -> bool:
	var a := _actions()
	return a != null and a.act(action, args)

func _cell_for(which: String) -> Vector2i:
	return container.cell if (which == "chest" and container != null and is_instance_valid(container)) else Vector2i.ZERO

func _make_ref(which: String, index: int, count: int) -> Dictionary:
	var s = _inv_for(which).slots[index]
	if s == null:
		return {}
	return {"which": which, "index": index, "cell": _cell_for(which), "count": maxi(count, 1), "id": String(s.id)}

func _same_ref(ref: Dictionary, which: String, index: int) -> bool:
	return not ref.is_empty() and ref.which == which and int(ref.index) == index \
			and (which != "chest" or ref.cell == _cell_for(which))

## The live stack a reference points at (null when gone / another chest).
func _ref_stack(ref: Dictionary):
	if ref.is_empty() or player == null:
		return null
	match String(ref.which):
		"inv":
			return player.inventory.slots[ref.index] if int(ref.index) < player.inventory.slots.size() else null
		"chest":
			if container == null or not is_instance_valid(container) or container.cell != ref.cell:
				return null
			return container.storage.slots[ref.index] if int(ref.index) < container.storage.slots.size() else null
		"equip":
			return player.equipment.get(ref.slot_name)
	return null

## What the cursor shows: the referenced slot, limited to the lifted count.
## A reference whose slot emptied or changed item (the host consumed it, a
## replica arrived) clears itself.
func _cursor_stack():
	var s = _ref_stack(cursor)
	if s == null or String(s.id) != String(cursor.id):
		cursor = {}
		return null
	if int(cursor.count) >= int(s.count):
		cursor.count = int(s.count)
		return s
	var part = s.duplicate(true)
	part.count = int(cursor.count)
	return part

func _bench_stack():
	var s = _ref_stack(bench)
	if s == null or String(s.id) != String(bench.id):
		bench = {}
		return null
	return s

## True while the cursor or the bench holds this slot (drawn dimmed).
func _lifted(which: String, index: int) -> bool:
	return _same_ref(cursor, which, index) or _same_ref(bench, which, index)

func _update_hover_plate() -> void:
	if _hover.is_empty() or not cursor.is_empty(): # hidden while dragging
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
	_set_hover_tier(st)
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
		if station != "" and station_tabs.has(station):
			selected_station = station # a clicked station opens on its own tab
			selected_recipe = {}
		show_screen("crafting" if station != "" else "inventory")

func close() -> void:
	open = false
	_clear_slot_scrap()
	root.visible = false
	container = null
	if storage_panel != null:
		storage_panel.visible = false
		stats_panel.visible = true
	_watch_container(null)
	if player != null:
		player.ui_blocks_mouse = false
	# Lifted stacks are references - the items never left their slots.
	cursor = {}
	bench = {}

## Refresh when the open chest's inventory changes under us (a replicated
## record on a client, another player's hands on the host).
func _watch_container(obj: WorldObject) -> void:
	if _watched_storage != null and _watched_storage.changed.is_connected(_refresh_all):
		_watched_storage.changed.disconnect(_refresh_all)
	_watched_storage = obj.storage if (obj != null and is_instance_valid(obj)) else null
	if _watched_storage != null:
		_watched_storage.changed.connect(_refresh_all)

func open_container(obj: WorldObject) -> void:
	# Build the chest's slot buttons BEFORE any refresh runs: units differ
	# in slot count, and a refresh against the previous container's buttons
	# indexes out of bounds (crash seen opening a smaller unit).
	container = obj
	_watch_container(obj)
	_chest_slots = _make_slots(chest_grid, obj.storage, "chest")
	stats_panel.visible = false
	storage_panel.visible = true
	open_panel()
	show_screen("inventory")

func show_screen(name: String) -> void:
	screen = name
	for k in screens.keys():
		screens[k].visible = (k == name)
	plaque_title.text = name.to_upper()
	_refresh_all()

func _process(_delta: float) -> void:
	if player == null:
		player = Net.local_player()
		if player == null:
			return
		player.container_opened.connect(open_container)
		player.crafting_opened.connect(open_panel)
		player.inventory.changed.connect(_refresh_all)
	var pause = get_tree().get_first_node_in_group("pause_menu")
	var mv = get_tree().get_first_node_in_group("map_view")
	if Input.is_action_just_pressed("inventory") and (pause == null or not pause.open) and (mv == null or not mv.open):
		toggle()
	if not open:
		# Esc with no menu open is the pause menu's business (sound, quit).
		return
	if Input.is_action_just_pressed("ui_cancel"):
		esc_consumed_frame = Engine.get_process_frames()
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
		var lifted: bool = not cursor.is_empty() and cursor.which == "equip" and cursor.slot_name == slot_name
		eb.icon.modulate = Color(1, 1, 1, 0.35) if lifted else Color.WHITE
		var locked: bool = not player.slot_unlocked(slot_name)
		eb.button.modulate = Color(0.55, 0.57, 0.62) if locked else Color.WHITE
	var s := player.skills
	stats_label.text = "Level %d\nPoints %d\n\nScrapping %d\nSwimming %d\nBuilding %d\n\nWeight %.1f\nSwim x%.2f" % [
		s.player_level(), s.available_points(), s.level("scrapping"), s.level("swimming"), s.level("building"),
		player.inventory.total_weight(), player.swim_factor()]
	var cur = _cursor_stack()
	cursor_icon.texture = Data.icon(cur.id) if cur != null else null
	cursor_count.text = str(cur.count) if (cur != null and cur.count > 1) else ""
	if screen == "crafting":
		_refresh_crafting(true)
	elif screen == "skills":
		_refresh_skills()
	elif screen == "modify":
		_refresh_modify()

func _refresh_grid(ui_slots: Array, inv: Inventory, is_bag: bool) -> void:
	var which := "inv" if is_bag else "chest"
	for i in mini(ui_slots.size(), inv.slots.size()):
		var st = inv.slots[i]
		ui_slots[i].icon.texture = Data.icon(st.id) if st != null else null
		ui_slots[i].icon.modulate = Color(1, 1, 1, 0.35) if _lifted(which, i) else Color.WHITE
		ui_slots[i].count.text = str(st.count) if (st != null and st.count > 1) else ""
		if is_bag:
			UITheme.style_slot(ui_slots[i].button, i == player.selected_slot)

func _stations() -> Array:
	return World.stations_near(player.global_position, Constants.REACH_BLOCKS * Constants.BLOCK_SIZE * 1.5)

func _station_in_reach(st: String) -> bool:
	return st == "hand" or _stations().has(st)

## A recipe crafts only with ingredients AND its station in reach; the
## catalog itself is browsable from anywhere (plan-ahead, user request).
func _row_craftable(r: Dictionary) -> bool:
	return player.can_craft(r) and _station_in_reach(r.station)

func _refresh_crafting(force: bool = false) -> void:
	var stations := _stations()
	if not force and stations == _last_stations:
		for b in recipe_list.get_children():
			_dim_recipe_row(b, _row_craftable(b.get_meta("recipe")))
		craft_button.disabled = selected_recipe.is_empty() or not _row_craftable(selected_recipe)
		return
	_last_stations = stations.duplicate()
	for c in recipe_list.get_children():
		c.queue_free()
	for st: String in station_tabs:
		var near := st == "hand" or stations.has(st)
		var tb: Button = station_tabs[st]
		if st == selected_station:
			tb.modulate = Color(1.25, 1.15, 0.8) if near else Color(0.85, 0.8, 0.62)
		else:
			tb.modulate = Color.WHITE if near else Color(0.45, 0.48, 0.53)
	var st_name: String = "By hand" if selected_station == "hand" \
			else (Data.objects[selected_station].name if Data.objects.has(selected_station) else selected_station)
	var near_sel := _station_in_reach(selected_station)
	station_name_label.text = st_name if near_sel else st_name + " — not in reach"
	station_name_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.85) if near_sel else Color(0.95, 0.6, 0.55))
	var available := Data.recipes_for_station(selected_station, player.knows_recipe)
	if selected_recipe.is_empty() or not available.has(selected_recipe):
		selected_recipe = available[0] if not available.is_empty() else {}
	for r in available:
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "  " + Data.item_name(r.output.item) + ("" if int(r.output.count) == 1 else " x%d" % int(r.output.count))
		b.icon = Data.icon(r.output.item)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 16)
		b.custom_minimum_size = Vector2(0, 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_row(b, r == selected_recipe)
		b.set_meta("recipe", r)
		# Uncraftable recipes stay CLICKABLE (user request) — dimmed so the
		# player can inspect what they will need; only CRAFT is gated.
		_dim_recipe_row(b, _row_craftable(r))
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
	detail_box.add_child(UITheme.label("%s · tier %d" % [st_name, int(r.get("tier", 0))], 8, Color(0.7, 0.78, 0.85)))
	if not _station_in_reach(r.station):
		detail_box.add_child(UITheme.label("Craft at a %s" % st_name, 8, Color(0.95, 0.6, 0.55)))
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
	craft_button.disabled = not _row_craftable(r)

# --- Actions ---

func _craft_selected() -> void:
	if not selected_recipe.is_empty() and _row_craftable(selected_recipe) \
			and _act("craft", [String(selected_recipe.id)]):
		_refresh_crafting(true)

func _quick_stack() -> void:
	if container != null and is_instance_valid(container):
		_act("quick_stack", [container.cell])
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
	if which == "chest" and (container == null or not is_instance_valid(container)):
		return
	var inv := _inv_for(which)
	var slot = inv.slots[index]
	var cur = _cursor_stack()
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.shift_pressed:
			if slot != null and _other_for(which) != null:
				_act("container_move", [_cell_for("chest"), which == "chest", index, -1, 0])
		elif cur == null:
			if slot != null:
				cursor = _make_ref(which, index, int(slot.count))
		elif _same_ref(cursor, which, index):
			cursor = {} # set back down where it came from
		elif cursor.which == "equip":
			if which == "inv":
				_act("unequip", [String(cursor.slot_name), index])
			cursor = {}
		else:
			_put(which, index, int(cursor.count))
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if cur == null:
			if slot != null:
				# Scrappable bag items: RMB press starts a hold-to-scrap
				# (same rule as scrapping furniture in the world); a quick
				# tap still takes half the stack.
				if which == "inv" and not Data.scrap_yield(slot.id).is_empty():
					_begin_slot_scrap(index, slot.id)
					return
				_rmb_take_half(which, index)
		elif cursor.which != "equip" and not _same_ref(cursor, which, index) \
				and (slot == null or (slot.id == cur.id and not slot.has("mods") and not cur.has("mods"))):
			_put(which, index, 1) # place one
	_refresh_all()

## Put `n` of the lifted stack onto (which, index) as ONE slot-to-slot action,
## then let the cursor follow what its source slot holds now: the swapped-out
## item after a swap, the remainder after a split, nothing once it emptied.
func _put(which: String, index: int, n: int) -> void:
	# Work from a copy: the action's `changed` refresh re-validates `cursor`
	# and clears it the moment its source slot empties.
	var ref := cursor.duplicate()
	var src := _inv_for(String(ref.which))
	var si := int(ref.index)
	var before = src.slots[si]
	if before == null:
		cursor = {}
		return
	var before_count := int(before.count)
	var whole: bool = n >= before_count
	var count := 0 if whole else n
	if ref.which == which:
		if which == "inv":
			if whole:
				_act("move_slot", [si, index])
			else:
				_act("split_slot", [si, index, n])
		else:
			_act("storage_move", [ref.cell, si, index, count])
	else:
		var cell: Vector2i = ref.cell if ref.which == "chest" else _cell_for(which)
		_act("container_move", [cell, ref.which == "chest", si, index, count])
	var after = src.slots[si]
	if after == null:
		cursor = {}
	elif String(after.id) != String(ref.id): # swapped: the cursor now holds the other item
		cursor = _make_ref(String(ref.which), si, int(after.count))
	else:
		var left := int(ref.count) - (before_count - int(after.count))
		cursor = _make_ref(String(ref.which), si, left) if left > 0 else {}

# --- Hold-RMB scrapping from the bag (user request) ---

var scrap_hold: Dictionary = {} # {index, id, time, duration} while RMB held
var scrap_hold_bar: ProgressBar = null

## Lift half the stack (a modded instance or a single moves whole) - a
## reference only; nothing moves until it is put down.
func _rmb_take_half(which: String, index: int) -> void:
	var slot = _inv_for(which).slots[index]
	if slot == null:
		return
	var half: int = 1 if (slot.has("mods") or int(slot.count) == 1) else int(ceil(slot.count / 2.0))
	cursor = _make_ref(which, index, half)
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
			_rmb_take_half("inv", scrap_hold.index)
		_clear_slot_scrap()
		return
	scrap_hold.time += delta
	scrap_hold.sfx = scrap_hold.get("sfx", 0.0) - delta
	if scrap_hold.sfx <= 0.0:
		scrap_hold.sfx = Constants.SCRAP_SFX_INTERVAL
		Audio.play_sfx("creak_plastic", player.global_position, 3, -8.0)
	scrap_hold_bar.value = scrap_hold.time / scrap_hold.duration * 100.0
	if scrap_hold.time >= scrap_hold.duration:
		if _act("scrap_slot", [int(scrap_hold.index), 1]):
			Audio.play_sfx("dismantle_rattle", player.global_position, 1, -4.0)
			_refresh_all()
			scrap_hold.time = 0.0 # keep holding to keep scrapping the stack
			scrap_hold_bar.value = 0.0
		else:
			_clear_slot_scrap()

## Equipment slots hold one item; LMB with a bag stack lifted wears one of it
## (`equip` action: the piece it replaces lands in that bag slot when it
## emptied, so the cursor ends up holding it - same feel as before); LMB on a
## worn piece lifts it as a reference, put down on a bag slot (`unequip`).
func _equip_click(event: InputEventMouseButton, slot_name: String) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var current = player.equipment.get(slot_name)
	var cur = _cursor_stack()
	if cur == null:
		if current != null:
			cursor = {"which": "equip", "slot_name": slot_name, "index": 0, "count": 1, "id": String(current.id)}
		return
	if cursor.which == "equip":
		if cursor.slot_name == slot_name:
			cursor = {} # set it back
		return
	if cursor.which != "inv":
		player.message.emit("Put it in your bag first")
		return
	if not player.slot_unlocked(slot_name):
		player.message.emit("That mount is locked — an ability on the tech tree opens it")
		return
	if not player.can_equip(slot_name, cur.id):
		player.message.emit("%s cannot go in the %s slot" % [Data.item_name(cur.id), EQUIP_LABEL[slot_name]])
		return
	var i := int(cursor.index)
	_act("equip", [slot_name, i])
	var after = player.inventory.slots[i]
	cursor = _make_ref("inv", i, int(after.count)) if after != null else {}
