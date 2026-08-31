class_name LightRenderer
extends Node2D
## Darkness overlay (fog of war). Visibility is computed per world cell
## (World.visibility_at: interior-only, raycast LOS, light x sight falloff)
## into a small texture — one pixel per cell — then drawn over the view by
## a shader that samples it bilinearly and quantizes to quarter-block steps,
## so fog edges are soft 4px stipples instead of full-block squares.

const SUB_STEPS := 4.0 # sub-cells per block (1/4 block granularity)

const FOG_SHADER := """
shader_type canvas_item;
uniform sampler2D vis_tex : filter_linear;
uniform vec2 cells;
uniform float quant = 4.0;
void fragment() {
	vec2 steps = cells * quant;
	vec2 uv = (floor(UV * steps) + 0.5) / steps;
	float vis = texture(vis_tex, uv).r;
	float a = pow(1.0 - vis, 1.2);
	COLOR = vec4(0.01, 0.01, 0.03, a);
}
"""

var _image: Image
var _texture: ImageTexture
var _material: ShaderMaterial
var _size := Vector2i.ZERO
var _origin := Vector2i.ZERO
# Visibility raycasts are the most expensive thing on screen, so the texture
# is cached: recompute at most 20x/s while the viewer moves, and at 2x/s
# while standing still (day/night and lamps drift slowly). Redrawing the
# cached texture every frame is nearly free.
var _last_viewer := Vector2(1e9, 1e9)
var _cooldown := 0.0
var _idle := 0.0

func _ready() -> void:
	var shader := Shader.new()
	shader.code = FOG_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material

func _process(delta: float) -> void:
	_cooldown -= delta
	_idle += delta
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
	var view := get_viewport_rect()
	var inv := get_canvas_transform().affine_inverse()
	var top_left := inv * view.position
	var bottom_right := inv * view.end
	var c0 := Vector2i(floori(top_left.x / s) - 1, floori(top_left.y / s) - 1)
	var c1 := Vector2i(ceili(bottom_right.x / s) + 1, ceili(bottom_right.y / s) + 1)
	var size := Vector2i(c1.x - c0.x + 1, c1.y - c0.y + 1)
	var recompute := size != _size or c0 != _origin or _texture == null or _idle >= 0.5 \
		or (_cooldown <= 0.0 and viewer.distance_to(_last_viewer) >= Constants.BLOCK_SIZE * 0.25)
	if recompute:
		var t0 := Time.get_ticks_usec()
		if size != _size:
			_size = size
			_image = Image.create(size.x, size.y, false, Image.FORMAT_RF)
			_texture = null
		_origin = c0
		for y in size.y:
			for x in size.x:
				var vis := World.visibility_at(Vector2i(c0.x + x, c0.y + y), viewer)
				_image.set_pixel(x, y, Color(vis / LightMap.MAX_LIGHT, 0, 0))
		if _texture == null:
			_texture = ImageTexture.create_from_image(_image)
		else:
			_texture.update(_image)
		_material.set_shader_parameter("vis_tex", _texture)
		_material.set_shader_parameter("cells", Vector2(size))
		_material.set_shader_parameter("quant", SUB_STEPS)
		_last_viewer = viewer
		_cooldown = 0.05
		_idle = 0.0
		World.perf.fog_ms = (Time.get_ticks_usec() - t0) / 1000.0
	draw_texture_rect(_texture, Rect2(_origin.x * s, _origin.y * s, _size.x * s, _size.y * s), false)
