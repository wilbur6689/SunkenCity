class_name LightMap
extends RefCounted
## Tile light propagation (WS-17): levels 0..15 on the world grid.
## Sun seeds every sky cell column-wise (attenuating twice as fast through
## water); point sources (lamps, glowsticks, the player's sight glow) seed a
## BFS that loses 1 per air cell, 2 per water cell, and 4 per solid cell —
## so light leaks barely a block into walls but spills through openings.

const MAX_LIGHT := 15
const COST_AIR := 1
const COST_WATER := 2
const COST_SOLID := 4

var bounds: Rect2i
var light := PackedByteArray()

func _init(p_bounds: Rect2i) -> void:
	bounds = p_bounds
	light.resize(bounds.size.x * bounds.size.y)
	light.fill(0)

func _idx(cell: Vector2i) -> int:
	return (cell.y - bounds.position.y) * bounds.size.x + (cell.x - bounds.position.x)

func in_bounds(cell: Vector2i) -> bool:
	return bounds.has_point(cell)

func light_at(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return MAX_LIGHT # outside the world grid is open sky
	return light[_idx(cell)]

## Full recompute. `sources` is an Array of {cell: Vector2i, level: int}.
func compute(is_solid: Callable, water_level: Callable, sources: Array) -> void:
	light.fill(0)
	var qc: Array[Vector2i] = []
	var ql: Array[int] = []
	# Sun: descend each column from the top of the grid until a solid cell.
	for x in range(bounds.position.x, bounds.end.x):
		var level := MAX_LIGHT
		for y in range(bounds.position.y, bounds.end.y):
			var c := Vector2i(x, y)
			if is_solid.call(c):
				break
			if water_level.call(c) > 0:
				level -= COST_WATER # faster falloff through water
			if level <= 0:
				break
			if level > light[_idx(c)]:
				light[_idx(c)] = level
				qc.append(c)
				ql.append(level)
	# Point sources
	for s in sources:
		var c: Vector2i = s.cell
		if in_bounds(c) and int(s.level) > light[_idx(c)]:
			light[_idx(c)] = int(s.level)
			qc.append(c)
			ql.append(int(s.level))
	# BFS with max-update (light only ever decreases along a path)
	var qi := 0
	while qi < qc.size() and qi < 20000:
		var c := qc[qi]
		var lv := ql[qi]
		qi += 1
		if light[_idx(c)] != lv:
			continue # stale entry
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if not in_bounds(n):
				continue
			var cost := COST_AIR
			if is_solid.call(n):
				cost = COST_SOLID
			elif water_level.call(n) > 0:
				cost = COST_WATER
			var nl := lv - cost
			if nl > light[_idx(n)]:
				light[_idx(n)] = nl
				qc.append(n)
				ql.append(nl)
