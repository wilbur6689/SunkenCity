class_name WaterRenderer
extends Node2D
## Draws the water sim within the camera view (CT-28 windowing) and the depth
## colour grade (WS-29) as horizontal bands darkening below the waterline.
##
## Perf rewrite (2026-09-05): the old per-cell draw_rect loop cost ~8 ms a
## frame zoomed out (21k cells). Now the visible slice of the sim's level
## bytes is copied row-by-row into a one-byte-per-cell texture (C++ slices,
## no GDScript per-cell work) and one quad + shader paints fill height, the
## animated surface line and the body tint. The slice is rebuilt only when
## the view moves, water moved this tick, or a slow keep-alive timer fires.

const BODY := Color(0.235, 0.47, 0.78, 0.55)
const SURFACE := Color(0.42, 0.68, 0.9, 0.8)
const DEEP := Color(0.02, 0.06, 0.16)
const REFRESH_SECONDS := 0.5 # keep-alive rebuild (flattening / pours that never wake a cell)

const WATER_SHADER := """
shader_type canvas_item;
uniform sampler2D levels : filter_nearest;
uniform vec2 cells;        // texture size in cells
uniform float max_level;   // WaterSim.MAX_LEVEL
uniform float cell_px;     // world px per cell
uniform float time;
uniform vec4 body : source_color;
uniform vec4 surface : source_color;
void fragment() {
	vec2 c = UV * cells;
	vec2 cell = floor(c);
	vec2 local = c - cell;                 // 0 = top of the cell, 1 = bottom
	float l = texelFetch(levels, ivec2(cell), 0).r * 255.0;
	if (l <= 0.5) { discard; }
	float above = 0.0;
	if (cell.y >= 1.0) { above = texelFetch(levels, ivec2(cell) - ivec2(0, 1), 0).r * 255.0; }
	float top = 1.0 - l / max_level;      // fill line inside the cell
	bool is_surface = above <= 0.5;
	if (is_surface && l < max_level - 0.5) {
		top += round(sin(time * 2.0 + cell.x * 0.9)) / cell_px; // 1 px bob
		top = clamp(top, 0.0, 1.0 - 1.0 / cell_px);
	}
	if (local.y < top) { discard; }
	COLOR = body;
	if (is_surface && local.y < top + 1.0 / cell_px) { COLOR = surface; }
}
"""

var waterline_y: float = 0.0
var _time: float = 0.0
var _mat: ShaderMaterial
var _tex: ImageTexture
var _img: Image
var _region := Rect2i() # cells currently in the texture
var _refresh := 0.0
var _quad: Node2D # child that carries the material (the depth bands stay unshaded)

func setup(p_waterline_y: float) -> void:
	waterline_y = p_waterline_y

func _ready() -> void:
	var shader := Shader.new()
	shader.code = WATER_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("body", BODY)
	_mat.set_shader_parameter("surface", SURFACE)
	_mat.set_shader_parameter("max_level", float(WaterSim.MAX_LEVEL))
	_mat.set_shader_parameter("cell_px", float(Constants.BLOCK_SIZE))
	_quad = _Quad.new()
	_quad.material = _mat
	_quad.owner_renderer = self
	_quad.show_behind_parent = true # the depth grade (parent draw) stays on top of the water, as before
	add_child(_quad)

func _process(delta: float) -> void:
	_time += delta
	_refresh -= delta
	if World.water_sim != null:
		queue_redraw()
		_quad.queue_redraw()

## The visible cell window, one cell of slack each side.
func _view_cells() -> Rect2i:
	var s := Constants.BLOCK_SIZE
	var view := get_viewport_rect()
	var inv := get_canvas_transform().affine_inverse()
	var top_left := inv * view.position
	var bottom_right := inv * view.end
	var w0 := Vector2i(floori(top_left.x / s) - 1, floori(top_left.y / s) - 1)
	var w1 := Vector2i(ceili(bottom_right.x / s) + 1, ceili(bottom_right.y / s) + 1)
	return Rect2i(w0, w1 - w0 + Vector2i.ONE).intersection(World.water_sim.bounds)

## Copy the visible slice of the sim's level bytes into the texture.
func _rebuild(region: Rect2i) -> void:
	var sim: WaterSim = World.water_sim
	var stride := sim.bounds.size.x
	var data := PackedByteArray()
	for y in region.size.y:
		var i0: int = (region.position.y + y - sim.bounds.position.y) * stride + (region.position.x - sim.bounds.position.x)
		data.append_array(sim.levels.slice(i0, i0 + region.size.x))
	_img = Image.create_from_data(region.size.x, region.size.y, false, Image.FORMAT_R8, data)
	if _tex == null or _region.size != region.size:
		_tex = ImageTexture.create_from_image(_img)
		_mat.set_shader_parameter("levels", _tex)
	else:
		_tex.update(_img)
	_mat.set_shader_parameter("cells", Vector2(region.size))
	_region = region

func _draw() -> void:
	var sim: WaterSim = World.water_sim
	if sim == null:
		return
	var t0 := Time.get_ticks_usec()
	var region := _view_cells()
	if region.size.x <= 0 or region.size.y <= 0:
		return
	World.perf.water_cells = region.size.x * region.size.y
	if region != _region or sim.changed_last_tick > 0 or not sim.awake.is_empty() or _refresh <= 0.0 or _tex == null:
		_rebuild(region)
		_refresh = REFRESH_SECONDS
	_mat.set_shader_parameter("time", _time)
	# Depth colour grade over the visible span below the waterline (WS-29)
	var s := Constants.BLOCK_SIZE
	var view := get_viewport_rect()
	var inv := get_canvas_transform().affine_inverse()
	var top_left := inv * view.position
	var bottom_right := inv * view.end
	var b := sim.bounds
	var depth_px := (b.end.y * s) - waterline_y + s * 4
	var bands := 14
	for i in bands:
		var a := 0.55 * pow(float(i) / bands, 1.4)
		var band_y0 := waterline_y + depth_px * i / bands
		var band_y1 := band_y0 + depth_px / bands + 1
		if band_y1 < top_left.y or band_y0 > bottom_right.y:
			continue
		draw_rect(Rect2(top_left.x - s, band_y0, (bottom_right.x - top_left.x) + s * 2, band_y1 - band_y0), Color(DEEP.r, DEEP.g, DEEP.b, a))
	World.perf.water_draw_ms = (Time.get_ticks_usec() - t0) / 1000.0

## The shaded quad: one textured rect over the visible cell window.
class _Quad extends Node2D:
	var owner_renderer: WaterRenderer
	func _draw() -> void:
		if owner_renderer == null or owner_renderer._tex == null:
			return
		var s := Constants.BLOCK_SIZE
		var r: Rect2i = owner_renderer._region
		draw_texture_rect(owner_renderer._tex, Rect2(r.position.x * s, r.position.y * s, r.size.x * s, r.size.y * s), false)
