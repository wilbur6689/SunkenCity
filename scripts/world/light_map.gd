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
## with closed doors passed as a small cell set. The STATIC field (sun, lamps,
## dropped lights) is computed by compute_window — safe to run on a worker
## thread, it touches only its arguments — and kept in `static_light`; the
## DYNAMIC sources (players' own glow) are re-applied on top per move by
## apply_dynamic, a small bounded BFS, so walking never triggers a full relight.

const MAX_LIGHT := 30 # doubled with the 8 px cell: still 1 per cell, same reach in feet
const COST_AIR := 1
const COST_WATER := 2
const COST_SOLID := 4

var window: Rect2i = Rect2i()
var light := PackedByteArray()        # static + dynamic: what the renderers read
var static_light := PackedByteArray() # sun + static sources only
var compute_ms: float = 0.0           # last compute_window cost (set on the computing thread)
# Inputs kept for apply_dynamic (references; PackedByteArrays are copy-on-write).
var _gb: Rect2i
var _structure := PackedByteArray()
var _water := PackedByteArray()
var _door_set: Dictionary = {}        # window-local indices of closed-door cells

func _idx(cell: Vector2i) -> int:
	return (cell.y - window.position.y) * window.size.x + (cell.x - window.position.x)

func light_at(cell: Vector2i) -> int:
	if not window.has_point(cell):
		return MAX_LIGHT
	return light[_idx(cell)]

## Copy another map's freshly computed field into this live one (the World
## keeps one LightMap instance so holders of the reference stay valid).
func adopt(other: LightMap) -> void:
	window = other.window
	static_light = other.static_light
	light = other.light
	compute_ms = other.compute_ms
	_gb = other._gb
	_structure = other._structure
	_water = other._water
	_door_set = other._door_set

## structure/water: the grid-wide byte layers over `gb` (WorldGrid.structure,
## WaterSim.levels); doors: closed-door cells (Vector2i -> true), solid like
## structure; sky_rows[i]: the first solid row from the top in window column i
## (structure or closed door), or a huge number for an open column;
## waterline: rows at or below it in an open column count as water.
## Thread-safe: reads only its arguments.
func compute_window(p_window: Rect2i, gb: Rect2i, structure: PackedByteArray, water: PackedByteArray,
		doors: Dictionary, sky_rows: PackedInt32Array, waterline: int, sources: Array, sun: float = 1.0) -> void:
	var t0 := Time.get_ticks_usec()
	window = p_window
	_gb = gb
	_structure = structure
	_water = water
	var ww := window.size.x
	var wh := window.size.y
	var n := ww * wh
	light = PackedByteArray()
	light.resize(n)
	light.fill(0)
	_door_set = {}
	for c: Vector2i in doors:
		if window.has_point(c):
			_door_set[_idx(c)] = true
	if n == 0:
		static_light = light
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
		var sky: int = sky_rows[lx] if lx < sky_rows.size() else 1 << 30
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
	_bfs(qc, ql)
	static_light = light.duplicate()
	compute_ms = (Time.get_ticks_usec() - t0) / 1000.0

## Re-apply the dynamic sources (players) over the static field. Cheap: the
## BFS only spreads where a source beats the static light, so it stays within
## the source's own radius.
func apply_dynamic(sources: Array) -> void:
	if static_light.is_empty():
		return
	light = static_light.duplicate()
	var qc := PackedInt32Array()
	var ql := PackedInt32Array()
	for s in sources:
		var c: Vector2i = s.cell
		if window.has_point(c) and int(s.level) > light[_idx(c)]:
			var li := _idx(c)
			light[li] = int(s.level)
			qc.append(li)
			ql.append(int(s.level))
	if not qc.is_empty():
		_bfs(qc, ql)

func _bfs(qc: PackedInt32Array, ql: PackedInt32Array) -> void:
	var ww := window.size.x
	var wh := window.size.y
	var gw := _gb.size.x
	var gx0 := _gb.position.x
	var gy0 := _gb.position.y
	var wx0 := window.position.x
	var wy0 := window.position.y
	var check_doors := not _door_set.is_empty()
	var qi := 0
	while qi < qc.size() and qi < 200000:
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
			if _structure[gi] != 0 or (check_doors and _door_set.has(nli)):
				cost = COST_SOLID
			elif _water[gi] > 0:
				cost = COST_WATER
			var nl := lv - cost
			if nl > light[nli]:
				light[nli] = nl
				qc.append(nli)
				ql.append(nl)
