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
