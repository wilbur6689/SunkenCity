extends CanvasLayer
## Inventory / crafting / chest panel (M1). Built in code: a 40-slot grid
## (row 0 = hotbar), a crafting list filtered by the stations in reach
## (GL-04/05), a station scrap button (GL-07 full yield), and a chest grid
## with quick-stack (LT-23). Drag with a cursor-held stack: LMB pick/put/
## swap/merge, RMB split half / place one, Shift+LMB move between containers.

const SLOT := 20
const FONT := 8

var player: Player
var open: bool = false
var cursor_stack = null # {id, count} or null
var container: WorldObject = null
var forced_station: String = ""

var root: Control
var panel: PanelContainer
var inv_grid: GridContainer
var chest_box: VBoxContainer
var chest_grid: GridContainer
var craft_box: VBoxContainer
var craft_list: VBoxContainer
var station_label: Label
var scrap_button: Button
var weight_label: Label
var skills_label: Label
var cursor_icon: TextureRect
var cursor_count: Label

var _inv_slots: Array = []
var _chest_slots: Array = []

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(0, 34)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.92)
	style.border_color = Color(0.4, 0.42, 0.5)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# --- inventory column
	var inv_box := VBoxContainer.new()
	hbox.add_child(inv_box)
	inv_box.add_child(_label("Inventory"))
	inv_grid = GridContainer.new()
	inv_grid.columns = Constants.HOTBAR_SLOTS
	inv_grid.add_theme_constant_override("h_separation", 2)
	inv_grid.add_theme_constant_override("v_separation", 2)
	inv_box.add_child(inv_grid)
	weight_label = _label("")
	inv_box.add_child(weight_label)
	skills_label = _label("")
	inv_box.add_child(skills_label)

	# --- chest column
	chest_box = VBoxContainer.new()
	chest_box.visible = false
	hbox.add_child(chest_box)
	chest_box.add_child(_label("Chest"))
	chest_grid = GridContainer.new()
	chest_grid.columns = 5
	chest_grid.add_theme_constant_override("h_separation", 2)
	chest_grid.add_theme_constant_override("v_separation", 2)
	chest_box.add_child(chest_grid)
	var qs := Button.new()
	qs.text = "Quick stack"
	qs.add_theme_font_size_override("font_size", FONT)
	qs.pressed.connect(_quick_stack)
	chest_box.add_child(qs)

	# --- crafting column
	craft_box = VBoxContainer.new()
	hbox.add_child(craft_box)
	station_label = _label("Crafting")
	craft_box.add_child(station_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(150, 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	craft_box.add_child(scroll)
	craft_list = VBoxContainer.new()
	craft_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(craft_list)
	scrap_button = Button.new()
	scrap_button.text = "Scrap held item (full yield)"
	scrap_button.add_theme_font_size_override("font_size", FONT)
	scrap_button.pressed.connect(_scrap_held)
	craft_box.add_child(scrap_button)

	# --- cursor stack
	cursor_icon = TextureRect.new()
	cursor_icon.size = Vector2(16, 16)
	cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_icon.z_index = 10
	root.add_child(cursor_icon)
	cursor_count = Label.new()
	cursor_count.add_theme_font_size_override("font_size", FONT)
	cursor_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_count.z_index = 10
	root.add_child(cursor_count)

	root.visible = false

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT)
	return l

func _make_slots(grid: GridContainer, inv: Inventory, which: String) -> Array:
	for c in grid.get_children():
		c.queue_free()
	var out := []
	for i in inv.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT, SLOT)
		b.focus_mode = Control.FOCUS_NONE
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		var count := Label.new()
		count.set_anchors_preset(Control.PRESET_FULL_RECT)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.add_theme_font_size_override("font_size", FONT)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(count)
		b.gui_input.connect(_on_slot_input.bind(which, i))
		grid.add_child(b)
		out.append({"button": b, "icon": icon, "count": count})
	return out

# --- Open / close ---

func toggle() -> void:
	if open:
		close()
	else:
		open_panel()

func open_panel(station: String = "") -> void:
	if player == null:
		return
	open = true
	forced_station = station
	root.visible = true
	player.ui_blocks_mouse = true
	if _inv_slots.is_empty():
		_inv_slots = _make_slots(inv_grid, player.inventory, "inv")
	_refresh_all()

func close() -> void:
	open = false
	root.visible = false
	container = null
	chest_box.visible = false
	forced_station = ""
	if player != null:
		player.ui_blocks_mouse = false
		# never lose a held stack on close
		if cursor_stack != null:
			var leftover: int = player.inventory.add(cursor_stack.id, cursor_stack.count)
			if leftover > 0:
				World.spawn_item(cursor_stack.id, leftover, player.global_position)
			cursor_stack = null

func open_container(obj: WorldObject) -> void:
	container = obj
	open_panel()
	chest_box.visible = true
	_chest_slots = _make_slots(chest_grid, obj.storage, "chest")
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
	_refresh_crafting()

# --- Refresh ---

func _refresh_all() -> void:
	if not open or player == null:
		return
	_refresh_grid(_inv_slots, player.inventory)
	if container != null and is_instance_valid(container):
		_refresh_grid(_chest_slots, container.storage)
	weight_label.text = "Weight: %.1f" % player.inventory.total_weight()
	var s := player.skills
	skills_label.text = "Lvl %d (pts %d)  Scrapping %d  Swimming %d  Building %d" % [
		s.player_level(), s.available_points(), s.level("scrapping"), s.level("swimming"), s.level("building")]
	cursor_icon.texture = Data.icon(cursor_stack.id) if cursor_stack != null else null
	cursor_count.text = str(cursor_stack.count) if (cursor_stack != null and cursor_stack.count > 1) else ""
	_refresh_crafting(true)

func _refresh_grid(ui_slots: Array, inv: Inventory) -> void:
	for i in ui_slots.size():
		var s = inv.slots[i]
		ui_slots[i].icon.texture = Data.icon(s.id) if s != null else null
		ui_slots[i].count.text = str(s.count) if (s != null and s.count > 1) else ""
		ui_slots[i].button.tooltip_text = Data.item_name(s.id) if s != null else ""

var _last_stations: Array = []
func _refresh_crafting(force: bool = false) -> void:
	var stations := World.stations_near(player.global_position, Constants.REACH_BLOCKS * Constants.BLOCK_SIZE * 1.5)
	if forced_station != "" and not stations.has(forced_station):
		stations.append(forced_station)
	if not force and stations == _last_stations:
		# still update enabled state cheaply
		for b in craft_list.get_children():
			b.disabled = not player.can_craft(b.get_meta("recipe"))
		return
	_last_stations = stations.duplicate()
	for c in craft_list.get_children():
		c.queue_free()
	var names := []
	for st in stations:
		if st != "hand":
			names.append(Data.objects[st].name if Data.objects.has(st) else st)
	station_label.text = "Crafting — " + ("by hand" if names.is_empty() else ", ".join(names))
	scrap_button.visible = stations.size() > 1
	for st in stations:
		for r in Data.recipes_for_station(st, player.knows_recipe):
			var b := Button.new()
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", FONT)
			b.text = "%s x%d" % [Data.item_name(r.output.item), r.output.count]
			var parts := []
			for inp in r.inputs:
				parts.append("%d %s" % [inp.count, Data.item_name(inp.item)])
			b.tooltip_text = "[%s] %s" % [r.station, ", ".join(parts)]
			b.disabled = not player.can_craft(r)
			b.focus_mode = Control.FOCUS_NONE
			b.set_meta("recipe", r)
			b.pressed.connect(_craft.bind(r))
			craft_list.add_child(b)

# --- Actions ---

func _craft(r: Dictionary) -> void:
	if player.craft(r):
		player.message.emit("Crafted " + Data.item_name(r.output.item))

func _scrap_held() -> void:
	if cursor_stack == null:
		player.message.emit("Hold an item on the cursor to scrap it")
		return
	if Data.scrap_yield(cursor_stack.id).is_empty():
		player.message.emit("Nothing to scrap")
		return
	# Return the stack to the bag, then scrap through the player API (skill + station checks).
	var id: String = cursor_stack.id
	var n: int = cursor_stack.count
	cursor_stack = null
	var leftover: int = player.inventory.add(id, n)
	if leftover > 0:
		World.spawn_item(id, leftover, player.global_position)
	player.scrap_item(id, n - leftover)
	_refresh_all()

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
