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
## Building seam covers draw smaller than their source art (user request:
## they towered over the play space); bottoms stay planted on the plates.
const BUILDING_SCALE := 0.7

## Sky above the waterline, matched to the mean top-row color of the city
## plates so the plate tops blend into it seamlessly.
const SKY_COLOR := Color(0.226, 0.625, 0.705)
const SKY_HEIGHT := 2000.0
## Deep-stage strips (user request 2026-09-06; tools/gen_stage_backdrops.py):
## one set per band below The Shallows - cold / dark / crush - five 704 px
## variants each, hung from the FIRST row of that stage's gap so the strip's
## fade-in IS the middle ground; each strip overlaps a few rows under the next.
const STAGE_STRIPS: Array = ["cold", "dark", "crush"]
const STAGE_VARIANTS := 5

func setup(waterline_y: float, origin_x: float, city_px: float = 0.0) -> void:
	scroll_scale = Vector2(0.4, 1.0) # slow horizontal parallax, pinned vertically to the waterline
	repeat_size = Vector2(PLATE_W * PLATES.size(), 0)
	# Coverage for the whole city: at 0.4 parallax the plates drift 0.6x the
	# camera's travel, plus a generous max-zoom-out view either side.
	var drift := city_px * 0.6 + 8000.0
	repeat_times = maxi(9, int(ceil(drift / repeat_size.x)) + 2)
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
		b.scale = Vector2(BUILDING_SCALE, BUILDING_SCALE)
		var seam_x := origin_x + (i + 1) * PLATE_W
		b.position = Vector2(seam_x - BUILDING_W * BUILDING_SCALE * 0.5,
			waterline_y + PLATE_H - BUILDING_H * BUILDING_SCALE)
		add_child(b)
	_add_stage_strips(origin_x)

## The cold / dark / crush strips below the Shallows plates (see STAGE_STRIPS).
## Positioned in world px from CityGen's stage gaps, so they line up with the
## garbage plugs whatever the constants say; later stages draw over earlier.
func _add_stage_strips(origin_x: float) -> void:
	var gaps: Array = CityGen.stage_gaps()
	for i in mini(STAGE_STRIPS.size(), gaps.size()):
		var y := float((gaps[i] as Vector2i).x) * Constants.BLOCK_SIZE
		for k in PLATES.size():
			var path := "res://assets/backgrounds/%s%02d.png" % [STAGE_STRIPS[i], k % STAGE_VARIANTS + 1]
			if not ResourceLoader.exists(path):
				continue
			var strip := Sprite2D.new()
			strip.texture = load(path)
			strip.centered = false
			strip.position = Vector2(origin_x + k * PLATE_W, y)
			add_child(strip)
