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

func _ready() -> void:
	var shader := Shader.new()
	shader.code = FOG_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material

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
	var view := get_viewport_rect()
	var inv := get_canvas_transform().affine_inverse()
	var top_left := inv * view.position
	var bottom_right := inv * view.end
	var c0 := Vector2i(floori(top_left.x / s) - 1, floori(top_left.y / s) - 1)
	var c1 := Vector2i(ceili(bottom_right.x / s) + 1, ceili(bottom_right.y / s) + 1)
	var size := Vector2i(c1.x - c0.x + 1, c1.y - c0.y + 1)
	if size != _size:
		_size = size
		_image = Image.create(size.x, size.y, false, Image.FORMAT_RF)
		_texture = null
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
	draw_texture_rect(_texture, Rect2(c0.x * s, c0.y * s, size.x * s, size.y * s), false)
