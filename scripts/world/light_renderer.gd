class_name LightRenderer
extends Node2D
## Darkness overlay: draws per-cell shade over everything in view using
## World.visibility_at — the min of tile light (WS-17) and the player's
## sight falloff (fog of war: lit floors beyond sight range still fade to
## black). Cells outside the world grid count as open sky, so only the
## sight cap applies there. Sits last in the scene tree, under the HUD.

func _process(_delta: float) -> void:
	if World.light_map != null:
		queue_redraw()

func _draw() -> void:
	if World.light_map == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var viewer: Vector2 = player.global_position
	var s := Constants.BLOCK_SIZE
	# Visible world rect from the canvas transform, padded a cell.
	var view := get_viewport_rect()
	var inv := get_canvas_transform().affine_inverse()
	var top_left := inv * view.position
	var bottom_right := inv * view.end
	var c0 := Vector2i(floori(top_left.x / s) - 1, floori(top_left.y / s) - 1)
	var c1 := Vector2i(ceili(bottom_right.x / s) + 1, ceili(bottom_right.y / s) + 1)
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			var cell := Vector2i(x, y)
			var vis := World.visibility_at(cell, viewer)
			if vis >= float(LightMap.MAX_LIGHT) - 0.01:
				continue
			var a := pow(1.0 - vis / LightMap.MAX_LIGHT, 1.2)
			draw_rect(Rect2(x * s, y * s, s, s), Color(0.01, 0.01, 0.03, a))
