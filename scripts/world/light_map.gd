class_name LightMap
extends RefCounted
## Tile light propagation (WS-17): levels 0..15, computed over a moving
## WINDOW around the camera (CT-28 — the city grid is too big to relight
## whole). Sun seeds each column scanning from the world's top so roofs
## occlude correctly, scaled by the day/night strength (CC-11); point
## sources BFS outward losing 1/air, 2/water, 4/solid. Cells outside the
## window count as fully lit — the fog-of-war sight cap governs there.

const MAX_LIGHT := 15
const COST_AIR := 1
const COST_WATER := 2
const COST_SOLID := 4

var window: Rect2i = Rect2i()
var light := PackedByteArray()

func _idx(cell: Vector2i) -> int:
	return (cell.y - window.position.y) * window.size.x + (cell.x - window.position.x)

func light_at(cell: Vector2i) -> int:
	if not window.has_point(cell):
		return MAX_LIGHT
	return light[_idx(cell)]

func compute_window(p_window: Rect2i, world_top: int, is_solid: Callable, water_level: Callable,
		sources: Array, sun: float = 1.0) -> void:
	window = p_window
	var n := window.size.x * window.size.y
	if light.size() != n:
		light.resize(n)
	light.fill(0)
	if n == 0:
		return
	var qc: Array[Vector2i] = []
	var ql: Array[int] = []
	var sun_level := int(roundf(MAX_LIGHT * sun))
	# Sun: descend each window column from the top of the WORLD.
	for x in range(window.position.x, window.end.x):
		var level := sun_level
		for y in range(world_top, window.end.y):
			var c := Vector2i(x, y)
			if is_solid.call(c):
				break
			if water_level.call(c) > 0:
				level -= COST_WATER
			if level <= 0:
				break
			if window.has_point(c) and level > light[_idx(c)]:
				light[_idx(c)] = level
				qc.append(c)
				ql.append(level)
	for s in sources:
		var c: Vector2i = s.cell
		if window.has_point(c) and int(s.level) > light[_idx(c)]:
			light[_idx(c)] = int(s.level)
			qc.append(c)
			ql.append(int(s.level))
	var qi := 0
	while qi < qc.size() and qi < 30000:
		var c := qc[qi]
		var lv := ql[qi]
		qi += 1
		if light[_idx(c)] != lv:
			continue
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var nb: Vector2i = c + d
			if not window.has_point(nb):
				continue
			var cost := COST_AIR
			if is_solid.call(nb):
				cost = COST_SOLID
			elif water_level.call(nb) > 0:
				cost = COST_WATER
			var nl := lv - cost
			if nl > light[_idx(nb)]:
				light[_idx(nb)] = nl
				qc.append(nb)
				ql.append(nl)
