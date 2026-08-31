class_name WaterRenderer
extends Node2D
## Draws the water sim within the camera view (CT-28 windowing): per-cell
## fill rects, a lighter animated surface line, and the depth colour grade
## (WS-29) as horizontal bands darkening below the waterline.

const BODY := Color(0.235, 0.47, 0.78, 0.55)
const SURFACE := Color(0.42, 0.68, 0.9, 0.8)
const DEEP := Color(0.02, 0.06, 0.16)

var waterline_y: float = 0.0
var _time: float = 0.0

func setup(p_waterline_y: float) -> void:
	waterline_y = p_waterline_y

func _process(delta: float) -> void:
	_time += delta
	if World.water_sim != null:
		queue_redraw()

func _draw() -> void:
	var sim: WaterSim = World.water_sim
	if sim == null:
		return
	var s := Constants.BLOCK_SIZE
	var view := get_viewport_rect()
	var inv := get_canvas_transform().affine_inverse()
	var top_left := inv * view.position
	var bottom_right := inv * view.end
	var w0 := Vector2i(floori(top_left.x / s) - 1, floori(top_left.y / s) - 1)
	var w1 := Vector2i(ceili(bottom_right.x / s) + 1, ceili(bottom_right.y / s) + 1)
	var b := sim.bounds
	var y0: int = maxi(w0.y, b.position.y)
	var y1: int = mini(w1.y, b.end.y - 1)
	var x0: int = maxi(w0.x, b.position.x)
	var x1: int = mini(w1.x, b.end.x - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var cell := Vector2i(x, y)
			var l := sim.level_at(cell)
			if l == 0:
				continue
			var top := sim.surface_y_in_cell(cell)
			var is_surface := sim.level_at(cell + Vector2i.UP) == 0
			if is_surface:
				top += roundf(sin(_time * 2.0 + x * 0.9)) * (1.0 if l < WaterSim.MAX_LEVEL else 0.0)
				top = clampf(top, y * s, (y + 1) * s - 1)
			draw_rect(Rect2(x * s, top, s, (y + 1) * s - top), BODY)
			if is_surface:
				draw_rect(Rect2(x * s, top, s, 1), SURFACE)
	# Depth colour grade over the visible span below the waterline (WS-29)
	var depth_px := (b.end.y * s) - waterline_y + s * 4
	var bands := 14
	for i in bands:
		var a := 0.55 * pow(float(i) / bands, 1.4)
		var band_y0 := waterline_y + depth_px * i / bands
		var band_y1 := band_y0 + depth_px / bands + 1
		if band_y1 < top_left.y or band_y0 > bottom_right.y:
			continue
		draw_rect(Rect2(top_left.x - s, band_y0, (bottom_right.x - top_left.x) + s * 2, band_y1 - band_y0), Color(DEEP.r, DEEP.g, DEEP.b, a))
