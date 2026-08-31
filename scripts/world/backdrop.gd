class_name BandBackdrop
extends Parallax2D
## Parallax backdrop for the top underwater band (The Shallows): a repeating
## strip of city plates (assets/backgrounds/city0N.png, 704x384) with tall
## building overlays (building0N.png, 384x688) centred on every seam so the
## joins never show. Plates hang from the waterline; the buildings rise
## above it as tower tops breaking the surface. Deeper bands get their own
## strips later (GD-16).

const PLATES := ["city01", "city02", "city03", "city04", "city05"]
const BUILDINGS := ["building01", "building02", "building03", "building04", "building02"] # one per seam
const PLATE_W := 704
const PLATE_H := 384
const BUILDING_W := 384
const BUILDING_H := 688

## Sky above the waterline, matched to the mean top-row color of the city
## plates so the plate tops blend into it seamlessly.
const SKY_COLOR := Color(0.226, 0.625, 0.705)
const SKY_HEIGHT := 2000.0

func setup(waterline_y: float, origin_x: float) -> void:
	scroll_scale = Vector2(0.4, 1.0) # slow horizontal parallax, pinned vertically to the waterline
	repeat_size = Vector2(PLATE_W * PLATES.size(), 0)
	repeat_times = 9 # enough coverage for the full city width at 0.4 parallax
	var sky := ColorRect.new()
	sky.color = SKY_COLOR
	sky.position = Vector2(origin_x, waterline_y - SKY_HEIGHT)
	sky.size = Vector2(PLATE_W * PLATES.size(), SKY_HEIGHT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	for i in PLATES.size():
		var plate := Sprite2D.new()
		plate.texture = load("res://assets/backgrounds/%s.png" % PLATES[i])
		plate.centered = false
		plate.position = Vector2(origin_x + i * PLATE_W, waterline_y)
		add_child(plate)
	for i in BUILDINGS.size():
		var b := Sprite2D.new()
		b.texture = load("res://assets/backgrounds/%s.png" % BUILDINGS[i])
		b.centered = false
		var seam_x := origin_x + (i + 1) * PLATE_W
		b.position = Vector2(seam_x - BUILDING_W * 0.5, waterline_y + PLATE_H - BUILDING_H)
		add_child(b)
