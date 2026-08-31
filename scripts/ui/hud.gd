extends CanvasLayer
## In-game HUD: health, oxygen (only while it matters), hotbar, scrap
## progress, transient messages, debug state readout. Polls the local
## player each frame; M1 UI keeps it simple.

@onready var health_bar: ProgressBar = %HealthBar
@onready var oxygen_bar: ProgressBar = %OxygenBar
@onready var debug_label: Label = %DebugLabel
@onready var hotbar: HBoxContainer = %Hotbar
@onready var message_label: Label = %MessageLabel
@onready var scrap_bar: ProgressBar = %ScrapBar

var player: Player
var _slots: Array = []
var _message: String = ""
var _message_timer: float = 0.0
var _minimap: TextureRect
var _minimap_img: Image
var _minimap_tex: ImageTexture
var _minimap_timer: float = 0.0

func _ready() -> void:
	for i in Constants.HOTBAR_SLOTS:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(20, 20)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.05, 0.08, 0.75)
		style.border_color = Color(0.5, 0.5, 0.55, 0.8)
		style.set_border_width_all(1)
		panel.add_theme_stylebox_override("panel", style)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(16, 16)
		panel.add_child(icon)
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.add_theme_font_size_override("font_size", 8)
		count.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_child(count)
		hotbar.add_child(panel)
		_slots.append({"panel": panel, "style": style, "icon": icon, "count": count})
	_build_minimap()

## Top-right minimap (CC-25): a window of the fog-of-war world map centred
## on the player, redrawn a few times a second from World.map_reveal.
func _build_minimap() -> void:
	var w: Vector2i = Constants.MINIMAP_WINDOW
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	style.border_color = Color(0.5, 0.5, 0.55, 0.8)
	style.set_border_width_all(1)
	style.set_content_margin_all(2)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-w.x - 10, 6)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap = TextureRect.new()
	_minimap.custom_minimum_size = Vector2(w)
	_minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_minimap)
	get_node("Root").add_child(panel)
	_minimap_img = Image.create(w.x, w.y, false, Image.FORMAT_RGBA8)
	_minimap_tex = ImageTexture.create_from_image(_minimap_img)
	_minimap.texture = _minimap_tex

const _MAT_COLORS := {
	WorldGrid.M.STONE: Color(0.52, 0.52, 0.55),
	WorldGrid.M.WOOD: Color(0.55, 0.4, 0.24),
	WorldGrid.M.METAL: Color(0.45, 0.52, 0.6),
	WorldGrid.M.PLASTIC: Color(0.75, 0.72, 0.66),
}
const _UNREVEALED := Color(0.03, 0.03, 0.05)
const _SKY := Color(0.22, 0.55, 0.64)
const _INTERIOR := Color(0.16, 0.14, 0.13)
const _WATER := Color(0.12, 0.3, 0.52)
const _DEEP := Color(0.05, 0.12, 0.26)

func _redraw_minimap() -> void:
	if not World.is_ready() or World.map_reveal == null:
		return
	var w: Vector2i = Constants.MINIMAP_WINDOW
	var center := World.cell_at(player.global_position)
	var org := center - w / 2
	for py in w.y:
		for px in w.x:
			var cell := org + Vector2i(px, py)
			var col: Color = _UNREVEALED
			if World.map_reveal.is_revealed(cell):
				var mat: int = World.grid.structure_at(cell)
				if mat != WorldGrid.M.AIR:
					col = _MAT_COLORS.get(mat, _INTERIOR)
				elif World.water_sim.level_at(cell) > 2:
					var deep_f := clampf(float(cell.y - World.waterline_row) / 250.0, 0.0, 1.0)
					col = _WATER.lerp(_DEEP, deep_f)
				elif World.has_back_wall_cell(cell):
					col = _INTERIOR
				else:
					col = _SKY if cell.y < World.waterline_row else _WATER.lerp(_INTERIOR, 0.5)
			_minimap_img.set_pixel(px, py, col)
	# The player: a bright 2x2 dot dead centre.
	for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var p := w / 2 + d
		_minimap_img.set_pixel(p.x, p.y, Color.WHITE)
	_minimap_tex.update(_minimap_img)

func show_message(text: String) -> void:
	_message = text
	_message_timer = 2.5

func _process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		if player == null:
			return
		player.message.connect(show_message)
	health_bar.max_value = Constants.MAX_HEALTH
	health_bar.value = player.health
	oxygen_bar.max_value = Constants.BASE_OXYGEN_SECONDS
	oxygen_bar.value = player.oxygen
	oxygen_bar.visible = player.submerged or player.oxygen < Constants.BASE_OXYGEN_SECONDS
	oxygen_bar.modulate = Color(1.0, 0.35, 0.35) if player.drowning else Color.WHITE

	for i in _slots.size():
		var s = player.inventory.slots[i]
		var ui = _slots[i]
		ui.icon.texture = Data.icon(s.id) if s != null else null
		ui.count.text = str(s.count) if (s != null and s.count > 1) else ""
		ui.style.border_color = Color(1.0, 0.85, 0.4) if i == player.selected_slot else Color(0.5, 0.5, 0.55, 0.8)

	_minimap_timer -= delta
	if _minimap_timer <= 0.0:
		_minimap_timer = Constants.MINIMAP_REFRESH_SECONDS
		_redraw_minimap()

	var inter := player.interaction
	scrap_bar.visible = inter.scrapping != null
	scrap_bar.value = inter.scrap_progress * 100.0
	if inter.message != "" and inter.message != _message:
		show_message(inter.message)
	_message_timer = maxf(_message_timer - delta, 0.0)
	message_label.text = _message if _message_timer > 0.0 else ""

	var v := player.velocity / Constants.BLOCK_SIZE
	debug_label.text = "%s%s  hp %d  o2 %.1f  v (%.1f, %.1f) bl/s  wt %.1f  lvl %d (scr %d swim %d bld %d)" % [
		player.state_name(), " [compact]" if player.compact else "",
		roundi(player.health), player.oxygen, v.x, v.y, player.inventory.total_weight(),
		player.skills.player_level(), player.skills.level("scrapping"), player.skills.level("swimming"),
		player.skills.level("building")]
