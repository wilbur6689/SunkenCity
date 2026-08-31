extends CanvasLayer
## Minimal M0 HUD: health, oxygen (only while it matters), debug state readout.
## Polls the local player each frame; a signal-driven HUD comes with M1 UI.

@onready var health_bar: ProgressBar = %HealthBar
@onready var oxygen_bar: ProgressBar = %OxygenBar
@onready var debug_label: Label = %DebugLabel

var player: Player

func _process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		if player == null:
			return
	health_bar.max_value = Constants.MAX_HEALTH
	health_bar.value = player.health
	oxygen_bar.max_value = Constants.BASE_OXYGEN_SECONDS
	oxygen_bar.value = player.oxygen
	oxygen_bar.visible = player.submerged or player.oxygen < Constants.BASE_OXYGEN_SECONDS
	oxygen_bar.modulate = Color(1.0, 0.35, 0.35) if player.drowning else Color.WHITE
	var v := player.velocity / Constants.BLOCK_SIZE
	debug_label.text = "%s%s  hp %d  o2 %.1f  v (%.1f, %.1f) bl/s" % [
		player.state_name(), " [compact]" if player.compact else "",
		roundi(player.health), player.oxygen, v.x, v.y]
