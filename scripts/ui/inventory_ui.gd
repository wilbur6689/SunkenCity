extends CanvasLayer
## Character menu (styled after docs/Examples/UI Menus): three screens over
## the underwater menu backdrop, sharing the wood-framed 10x4 bag grid.
##   Inventory — character preview, equipment (Head, Suit, 2 Accessories,
##               2 reserved), stats
##   Crafting  — recipe list (stations in reach), recipe detail, CRAFT
##   Chest     — container grid + quick stack (opens from a chest)
## Drag model: LMB pick/put/swap/merge, RMB split half / place one,
## Shift+LMB move between bag and chest.

const SLOT := 24
const GAP := 2
const ICON := 16
const DESIGN_W := 640.0

const EQUIP_SLOTS := ["head", "suit", "accessory1", "accessory2", "reserved1", "reserved2"]
const EQUIP_GLYPH := {"head": 0, "suit": 1, "accessory1": 2, "accessory2": 2, "reserved1": 3, "reserved2": 3}
const EQUIP_LABEL := {"head": "Head", "suit": "Suit", "accessory1": "Accessory", "accessory2": "Accessory", "reserved1": "Reserved", "reserved2": "Reserved"}

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
var equip_hint: Label
var recipe_list: VBoxContainer
var detail_box: VBoxContainer
var craft_button: Button
var station_label: Label
var chest_grid: GridContainer
var cursor_icon: TextureRect
var cursor_count: Label
var _last_stations: Array = []

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

	# Popup window: steel frame with the underwater rock art as its interior
	var window := Control.new()
	window.position = WIN_POS
	window.size = WIN_SIZE
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(window)
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
	for name in ["inventory", "crafting", "skills", "chest"]:
		var b := Button.new()
		b.text = name.capitalize()
		b.custom_minimum_size = Vector2(48, 16)
		UITheme.style_button(b)
		b.pressed.connect(show_screen.bind(name))
		tabs.add_child(b)
		tab_buttons[name] = b
	tab_buttons["chest"].visible = false

	_build_inventory_screen()
	_build_crafting_screen()
	_build_skills_screen()
	_build_chest_screen()

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
		b.tooltip_text = EQUIP_LABEL[slot_name]
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
		if slot_name.begins_with("reserved"):
			b.disabled = true
			b.tooltip_text = "Reserved (tech tree, M5)"
		else:
			b.gui_input.connect(_on_slot_input.bind("equip:" + slot_name, 0))
		eq.add_child(b)
		_equip_buttons[slot_name] = {"button": b, "icon": icon, "glyph": g}

	# Stats (steel panel)
	var sp := _panel(Vector2(355, 46), Vector2(100, 148), UITheme.steel_panel())
	s.add_child(sp)
	stats_label = UITheme.label("")
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sp.add_child(stats_label)

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
	detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 2)
	dp.add_child(detail_box)

	craft_button = Button.new()
	craft_button.text = "CRAFT"
	craft_button.custom_minimum_size = Vector2(64, 18)
	craft_button.position = Vector2(327 + 128 - 64, 46 + 130 + 4)
	UITheme.style_button(craft_button)
	craft_button.pressed.connect(_craft_selected)
	s.add_child(craft_button)

var player_stats_box: VBoxContainer
var skills_box: VBoxContainer

## Skills & player stats screen (CC-18): player level, banked tech-tree
## points, vitals, and each skill's level with XP progress to the next.
func _build_skills_screen() -> void:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.visible = false
	content.add_child(s)
	screens["skills"] = s

	var pp := _panel(Vector2(185, 46), Vector2(128, 148), UITheme.steel_panel())
	s.add_child(pp)
	player_stats_box = VBoxContainer.new()
	player_stats_box.add_theme_constant_override("separation", 2)
	pp.add_child(player_stats_box)

	var sp := _panel(Vector2(319, 46), Vector2(136, 148), UITheme.steel_panel())
	s.add_child(sp)
	skills_box = VBoxContainer.new()
	skills_box.add_theme_constant_override("separation", 3)
	sp.add_child(skills_box)

func _refresh_skills() -> void:
	for c in player_stats_box.get_children():
		c.queue_free()
	for c in skills_box.get_children():
		c.queue_free()
	var sk := player.skills
	player_stats_box.add_child(UITheme.label("PLAYER", 9, Color(0.56, 0.75, 0.81)))
	player_stats_box.add_child(UITheme.label("Level %d" % sk.player_level(), 9))
	player_stats_box.add_child(UITheme.label("Ability points: %d" % sk.available_points(), 8, Color(0.95, 0.85, 0.5) if sk.available_points() > 0 else Color(0.7, 0.78, 0.85)))
	player_stats_box.add_child(UITheme.label("(tech tree arrives in M5)", 8, Color(0.55, 0.6, 0.68)))
	player_stats_box.add_child(UITheme.label(" ", 8))
	player_stats_box.add_child(UITheme.label("Health  %d / %d" % [roundi(player.health), roundi(Constants.MAX_HEALTH)], 8))
	player_stats_box.add_child(UITheme.label("Oxygen  %.0fs" % Constants.BASE_OXYGEN_SECONDS, 8))
	player_stats_box.add_child(UITheme.label("Weight  %.1f" % player.inventory.total_weight(), 8))
	player_stats_box.add_child(UITheme.label("Swim    x%.2f" % player.swim_factor(), 8))
	var suit := player.equipped("suit")
	player_stats_box.add_child(UITheme.label("Suit    %s" % (Data.item_name(suit) if suit != "" else "none"), 8))

	skills_box.add_child(UITheme.label("SKILLS — level by use", 9, Color(0.56, 0.75, 0.81)))
	for skill_name in sk.xp.keys():
		var lvl := sk.level(skill_name)
		var into: float = sk.xp[skill_name] - lvl * Constants.SKILL_XP_PER_LEVEL
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		row.add_child(UITheme.label("%s  —  %d" % [skill_name.capitalize(), lvl], 8))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(120, 5)
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
		row.add_child(UITheme.label("%.0f / %.0f xp to next" % [into, Constants.SKILL_XP_PER_LEVEL], 8, Color(0.55, 0.6, 0.68)))
		skills_box.add_child(row)

func _build_chest_screen() -> void:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.visible = false
	content.add_child(s)
	screens["chest"] = s

	var cp := _panel(Vector2(185, 46), Vector2(5 * SLOT + 4 * GAP + 8, 4 * SLOT + 3 * GAP + 8), UITheme.steel_panel())
	s.add_child(cp)
	chest_grid = GridContainer.new()
	chest_grid.columns = 5
	chest_grid.add_theme_constant_override("h_separation", GAP)
	chest_grid.add_theme_constant_override("v_separation", GAP)
	cp.add_child(chest_grid)

	var qs := Button.new()
	qs.text = "Quick stack"
	qs.custom_minimum_size = Vector2(80, 18)
	qs.position = Vector2(340, 46)
	UITheme.style_button(qs)
	qs.pressed.connect(_quick_stack)
	s.add_child(qs)
	var hint := UITheme.label("Shift+click moves\nbetween bag and chest", 8, Color(0.7, 0.78, 0.85))
	hint.position = Vector2(340, 70)
	s.add_child(hint)

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
		target.add_child(b)
		out.append({"button": b, "icon": icon, "count": count})
	return out

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
	show_screen("crafting" if station != "" else "inventory")

func close() -> void:
	open = false
	root.visible = false
	container = null
	tab_buttons["chest"].visible = false
	if player != null:
		player.ui_blocks_mouse = false
		if cursor_stack != null: # never lose a held stack on close
			var leftover: int = player.inventory.add(cursor_stack.id, cursor_stack.count)
			if leftover > 0:
				World.spawn_item(cursor_stack.id, leftover, player.global_position)
			cursor_stack = null

func open_container(obj: WorldObject) -> void:
	container = obj
	open_panel()
	tab_buttons["chest"].visible = true
	_chest_slots = _make_slots(chest_grid, obj.storage, "chest")
	show_screen("chest")

func show_screen(name: String) -> void:
	if name == "chest" and container == null:
		name = "inventory"
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
			get_tree().quit() # Esc quits the game (Esc with the menu open just closes it)
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
	if screen == "crafting":
		_refresh_crafting()

# --- Refresh ---

func _refresh_all() -> void:
	if not open or player == null:
		return
	_refresh_grid(_bag_slots, player.inventory, true)
	if container != null and is_instance_valid(container):
		_refresh_grid(_chest_slots, container.storage, false)
	for slot_name in _equip_buttons.keys():
		var st = player.equipment.get(slot_name)
		_equip_buttons[slot_name].icon.texture = Data.icon(st.id) if st != null else null
		_equip_buttons[slot_name].glyph.visible = st == null
		if st != null:
			_equip_buttons[slot_name].button.tooltip_text = Data.item_name(st.id)
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

func _refresh_grid(ui_slots: Array, inv: Inventory, is_bag: bool) -> void:
	for i in ui_slots.size():
		var st = inv.slots[i]
		ui_slots[i].icon.texture = Data.icon(st.id) if st != null else null
		ui_slots[i].count.text = str(st.count) if (st != null and st.count > 1) else ""
		ui_slots[i].button.tooltip_text = Data.item_name(st.id) if st != null else ""
		if is_bag:
			UITheme.style_slot(ui_slots[i].button, i == player.selected_slot)

func _stations() -> Array:
	return World.stations_near(player.global_position, Constants.REACH_BLOCKS * Constants.BLOCK_SIZE * 1.5)

func _refresh_crafting(force: bool = false) -> void:
	var stations := _stations()
	if not force and stations == _last_stations:
		for b in recipe_list.get_children():
			b.disabled = not player.can_craft(b.get_meta("recipe"))
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
		b.disabled = not player.can_craft(r)
		b.pressed.connect(_select_recipe.bind(r))
		recipe_list.add_child(b)
	_refresh_detail()

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
				var half: int = int(ceil(slot.count / 2.0))
				cursor_stack = {"id": slot.id, "count": half}
				slot.count -= half
				inv.set_slot(index, slot)
		elif slot == null:
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
	if not player.can_equip(slot_name, cursor_stack.id):
		player.message.emit("%s cannot go in the %s slot" % [Data.item_name(cursor_stack.id), EQUIP_LABEL[slot_name]])
		return
	var one = {"id": cursor_stack.id, "count": 1}
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
