extends Control
## Tier badge (user request 2026-09-02; shared 2026-09-06): a little shield
## with a tool-tier number, colour-coded. The object hover card shows the
## tier an object NEEDS; item tooltips show the tier a tool CAN dismantle,
## so the two read against each other at a glance.
## Preload this script (no class_name: a fresh global class is not in the
## cache until an import pass, which headless gate runs never do).

var tier: int = -1
const COLORS := {
	0: Color(0.52, 0.54, 0.58), # hands - grey
	1: Color(0.40, 0.74, 0.36), # pry/basic - green
	2: Color(0.34, 0.62, 0.93), # iron - blue
	3: Color(0.93, 0.60, 0.24), # steel/torch - orange
}

func _init() -> void:
	custom_minimum_size = Vector2(13, 15)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_tier(t: int) -> void:
	if t == tier:
		return
	tier = t
	queue_redraw()

func _draw() -> void:
	var col: Color = COLORS.get(tier, COLORS[1])
	var w := size.x
	var h := size.y
	var pts := PackedVector2Array([
		Vector2(1, 1), Vector2(w - 1, 1), Vector2(w - 1, h * 0.52),
		Vector2(w * 0.5, h - 1), Vector2(1, h * 0.52)])
	draw_colored_polygon(pts, col)
	var border := PackedVector2Array(pts)
	border.append(pts[0])
	draw_polyline(border, col.darkened(0.45), 1.0, true)
	var fnt := ThemeDB.fallback_font
	var s := str(tier)
	var fs := 9
	var tw: float = fnt.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ink := Color(1, 1, 1) if col.get_luminance() < 0.62 else Color(0.08, 0.09, 0.1)
	draw_string(fnt, Vector2((w - tw) * 0.5, h * 0.66), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
