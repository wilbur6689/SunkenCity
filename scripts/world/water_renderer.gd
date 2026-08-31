class_name WaterRenderer
extends Node2D
## Draws the water sim: per-cell fill rects, a lighter animated surface line,
## and the depth colour grade (WS-29: grade only, no distortion) as horizontal
## bands darkening below the waterline. Sits above the player in tree order so
## water reads as translucent volume.

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
	var b := sim.bounds
	var s := Constants.BLOCK_SIZE
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			var cell := Vector2i(x, y)
			var l := sim.level_at(cell)
			if l == 0:
				continue
			var top := sim.surface_y_in_cell(cell)
			var is_surface := sim.level_at(cell + Vector2i.UP) == 0
			if is_surface:
				# modest animation: the surface line bobs by a pixel
				top += roundf(sin(_time * 2.0 + x * 0.9)) * (1.0 if l < WaterSim.MAX_LEVEL else 0.0)
				top = clampf(top, y * s, (y + 1) * s - 1)
			draw_rect(Rect2(x * s, top, s, (y + 1) * s - top), BODY)
			if is_surface:
				draw_rect(Rect2(x * s, top, s, 1), SURFACE)
	# Depth colour grade: bands from the waterline down (WS-29)
	var world_w := b.size.x * s
	var depth_px := (b.end.y * s) - waterline_y + s * 4
	var bands := 14
	for i in bands:
		var a := 0.55 * pow(float(i) / bands, 1.4)
		var y0 := waterline_y + depth_px * i / bands
		draw_rect(Rect2(b.position.x * s, y0, world_w, depth_px / bands + 1), Color(DEEP.r, DEEP.g, DEEP.b, a))
