class_name LightMap
extends RefCounted
## Tile light propagation (WS-17): levels 0..30 (0..15 before the 8 px cells of 2026-09-04),
## computed over a moving WINDOW around the camera (CT-28 — the city grid is
## too big to relight whole). Sun seeds each column from the sky (the
## caller's cached first-solid row per column, so the scan never walks the
## world's empty top), scaled by the day/night strength (CC-11); point
## sources BFS outward losing 1/air, 2/water, 4/solid. Cells outside the
## window count as fully lit — the fog-of-war sight cap governs there.
##
## Perf (2026-09-04, half-size blocks quadrupled the window's cells): the
## BFS reads the grid's byte arrays directly — no Callable per neighbour —
## with closed doors passed as a small cell set.

const MAX_LIGHT := 30 # doubled with the 8 px cell: still 1 per cell, same reach in feet
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

## structure/water: the grid-wide byte layers over `gb` (WorldGrid.structure,
## WaterSim.levels); doors: closed-door cells (Vector2i -> true), solid like
## structure; sky_row(x): the first solid row from the top in column x
## (structure or closed door), or a huge number for an open column;
## waterline: rows at or below it in an open column count as water.
func compute_window(p_window: Rect2i, gb: Rect2i, structure: PackedByteArray, water: PackedByteArray,
		doors: Dictionary, sky_row: Callable, waterline: int, sources: Array, sun: float = 1.0) -> void:
	window = p_window
	var ww := window.size.x
	var wh := window.size.y
	var n := ww * wh
	if light.size() != n:
		light.resize(n)
	light.fill(0)
	if n == 0:
		return
	var gw := gb.size.x
	var gx0 := gb.position.x
	var gy0 := gb.position.y
	var wx0 := window.position.x
	var wy0 := window.position.y
	var qc := PackedInt32Array() # window-local indices
	var ql := PackedInt32Array()
	var sun_level := int(roundf(MAX_LIGHT * sun))
	# Sun: descend each window column from the sky. Above the window the
	# column is open air down to the waterline and open water below it (a
	# roof anywhere above blocks the column entirely).
	for lx in ww:
		var x := wx0 + lx
		var sky: int = sky_row.call(x)
		if sky < wy0:
			continue # blocked above the window
		var level := sun_level - COST_WATER * maxi(0, wy0 - maxi(waterline, gy0))
		if level <= 0:
			continue
		var y_end := mini(sky, window.end.y)
		var gi := (wy0 - gy0) * gw + (x - gx0)
		var li := lx
		for y in range(wy0, y_end):
			if water[gi] > 0:
				level -= COST_WATER
			if level <= 0:
				break
			if level > light[li]:
				light[li] = level
				qc.append(li)
				ql.append(level)
			gi += gw
			li += ww
	for s in sources:
		var c: Vector2i = s.cell
		if window.has_point(c) and int(s.level) > light[_idx(c)]:
			var li := _idx(c)
			light[li] = int(s.level)
			qc.append(li)
			ql.append(int(s.level))
	var door_set := {} # window-local indices of closed-door cells
	for c: Vector2i in doors:
		if window.has_point(c):
			door_set[_idx(c)] = true
	var qi := 0
	var check_doors := not door_set.is_empty()
	while qi < qc.size() and qi < 120000:
		var li := qc[qi]
		var lv := ql[qi]
		qi += 1
		if light[li] != lv:
			continue
		@warning_ignore("integer_division")
		var ly := li / ww
		var lx := li - ly * ww
		for d in 4:
			var nx := lx
			var ny := ly
			match d:
				0: ny -= 1
				1: ny += 1
				2: nx -= 1
				3: nx += 1
			if nx < 0 or ny < 0 or nx >= ww or ny >= wh:
				continue
			var nli := ny * ww + nx
			var gi := (wy0 + ny - gy0) * gw + (wx0 + nx - gx0)
			var cost := COST_AIR
			if structure[gi] != 0 or (check_doors and door_set.has(nli)):
				cost = COST_SOLID
			elif water[gi] > 0:
				cost = COST_WATER
			var nl := lv - cost
			if nl > light[nli]:
				light[nli] = nl
				qc.append(nli)
				ql.append(nl)
