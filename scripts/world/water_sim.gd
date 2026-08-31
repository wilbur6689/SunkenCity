class_name WaterSim
extends RefCounted
## Cellular tile water (WaterPhysics.md, CC-13/WS-23). Each cell in a bounded
## grid holds a fill level 0..8 (M2 decision: 8 levels — partial cells and
## smooth surfaces while staying integer-conserved). Rules per tick, applied
## bottom-up to awake cells only:
##   1. Down:   flow into free space below.
##   2. Spread: equalize sideways when the difference is >= 2.
##   3. Settle: cells that moved nothing go dormant until a neighbour changes.
## Everything else — floods, drains, pumping, displacement — emerges from
## these rules. Solidity comes from World (solid blocks and closed doors
## seal; background walls never do, WS-20). Out-of-bounds counts as solid.

const MAX_LEVEL := 8
const PX_PER_LEVEL := float(Constants.BLOCK_SIZE) / MAX_LEVEL

var bounds: Rect2i
var levels := PackedByteArray()
var awake: Dictionary = {}      # index -> true
var flow: Dictionary = {}       # index -> Vector2 (units moved out this tick, for currents)
var fresh: Dictionary = {}      # index -> ripple direction (+1/-1); set on sideways receive
var is_solid: Callable          # func(cell: Vector2i) -> bool
var budget_per_tick: int = 3000
var processed_last_tick: int = 0

func _init(p_bounds: Rect2i, p_is_solid: Callable) -> void:
	bounds = p_bounds
	is_solid = p_is_solid
	levels.resize(bounds.size.x * bounds.size.y)
	levels.fill(0)

# --- Indexing ---

func _idx(cell: Vector2i) -> int:
	return (cell.y - bounds.position.y) * bounds.size.x + (cell.x - bounds.position.x)

func _cell(i: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(bounds.position.x + i % bounds.size.x, bounds.position.y + i / bounds.size.x)

func in_bounds(cell: Vector2i) -> bool:
	return bounds.has_point(cell)

func _blocked(cell: Vector2i) -> bool:
	return not in_bounds(cell) or is_solid.call(cell)

# --- Levels ---

func level_at(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return 0
	return levels[_idx(cell)]

## Water surface y (global px) inside this cell: top of the filled part.
func surface_y_in_cell(cell: Vector2i) -> float:
	return (cell.y + 1) * Constants.BLOCK_SIZE - level_at(cell) * PX_PER_LEVEL

func set_level(cell: Vector2i, l: int) -> void:
	if not in_bounds(cell):
		return
	levels[_idx(cell)] = clampi(l, 0, MAX_LEVEL)
	wake_around(cell)

## Adds up to `units`; returns what did not fit.
func add_water(cell: Vector2i, units: int) -> int:
	if _blocked(cell):
		return units
	var i := _idx(cell)
	var space := MAX_LEVEL - levels[i]
	var t := mini(space, units)
	levels[i] += t
	wake_around(cell)
	return units - t

## Removes up to `units`; returns what was actually removed.
func remove_water(cell: Vector2i, units: int) -> int:
	if not in_bounds(cell):
		return 0
	var i := _idx(cell)
	var t := mini(int(levels[i]), units)
	levels[i] -= t
	if t > 0:
		wake_around(cell)
	return t

## Seeds one cell without waking anything (world-gen flooding).
func seed_cell(cell: Vector2i, level: int) -> void:
	if in_bounds(cell) and not is_solid.call(cell):
		levels[_idx(cell)] = level

## Seeds a rect at the given level without waking anything (already settled).
func fill_rect(rect: Rect2i, level: int) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if in_bounds(c) and not is_solid.call(c):
				levels[_idx(c)] = level

func total_units() -> int:
	var t := 0
	for v in levels:
		t += v
	return t

func awake_count() -> int:
	return awake.size()

# --- Waking ---

func wake(cell: Vector2i) -> void:
	if in_bounds(cell):
		awake[_idx(cell)] = true

func wake_around(cell: Vector2i) -> void:
	wake(cell)
	wake(cell + Vector2i.UP)
	wake(cell + Vector2i.DOWN)
	wake(cell + Vector2i.LEFT)
	wake(cell + Vector2i.RIGHT)

## A block/door changed at `cell`: wake the neighbourhood (WS-24 wake-on-change).
func notify_changed(cell: Vector2i) -> void:
	wake_around(cell)

# --- Tick ---

var _settled_recently: Dictionary = {} # index -> true; flatten seeds

func tick() -> void:
	flow.clear()
	if awake.is_empty():
		processed_last_tick = 0
		if not _settled_recently.is_empty():
			_flatten_settled()
		return
	var order := awake.keys()
	order.sort_custom(func(a, b): return a > b) # bottom-up (higher index = lower row)
	var processed := 0
	for i in order:
		if processed >= budget_per_tick:
			break
		processed += 1
		var moved := _step_cell(i)
		if not moved:
			awake.erase(i) # settle; a neighbour change re-wakes it
			if levels[i] > 0:
				_settled_recently[i] = true
	processed_last_tick = processed

## When a body finishes moving, redistribute it to true equilibrium: the
## flow rules freeze slope-1 staircases (diff >= 2 only), so a settled body
## is levelled exactly — full rows bottom-up, the topmost partial row spread
## evenly. Conservation-exact and idempotent, so it cannot re-trigger itself.
func _flatten_settled() -> void:
	var seeds := _settled_recently.keys()
	_settled_recently.clear()
	var visited := {}
	for si in seeds:
		if visited.has(si) or levels[si] == 0:
			continue
		_flatten_body(_cell(si), visited)

func _flatten_body(seed: Vector2i, visited: Dictionary) -> void:
	var queue: Array[Vector2i] = [seed]
	var body: Array[Vector2i] = []
	var total := 0
	var searched := 0
	while not queue.is_empty():
		searched += 1
		if searched > 1200:
			return # body too large to flatten in one pass (ocean-scale: already flat)
		var c: Vector2i = queue.pop_front()
		if not in_bounds(c):
			continue
		var ci := _idx(c)
		if visited.has(ci) or levels[ci] == 0:
			continue
		visited[ci] = true
		body.append(c)
		total += levels[ci]
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			queue.push_back(c + d)
	if body.size() < 2:
		return
	# Group by row, fill bottom-up; the last (partial) row levels out evenly.
	var rows: Dictionary = {}
	for c in body:
		if not rows.has(c.y):
			rows[c.y] = []
		rows[c.y].append(c)
	var ys := rows.keys()
	ys.sort_custom(func(a, b): return a > b) # deepest first
	var changed: Array[Vector2i] = []
	for y in ys:
		var row: Array = rows[y]
		row.sort_custom(func(a, b): return a.x < b.x)
		var n := row.size()
		var take := mini(total, n * MAX_LEVEL)
		total -= take
		@warning_ignore("integer_division")
		var base := take / n
		var extra := take % n
		for k in n:
			var want := base + (1 if k < extra else 0)
			var ci := _idx(row[k])
			if int(levels[ci]) != want:
				levels[ci] = want
				changed.append(row[k])
	for c in changed:
		wake_around(c)

func _step_cell(i: int) -> bool:
	var l := int(levels[i])
	if l == 0:
		return false
	var c := _cell(i)
	var moved := false
	# 1. Down
	var below := c + Vector2i.DOWN
	if not _blocked(below):
		var bi := _idx(below)
		var space := MAX_LEVEL - levels[bi]
		if space > 0:
			var t := mini(l, space)
			levels[i] -= t
			levels[bi] += t
			_record_flow(i, Vector2(0, t))
			wake_around(c)
			wake_around(below)
			l -= t
			moved = true
	if l == 0:
		return moved
	# 2. Spread (only when resting on something)
	if _blocked(below) or level_at(below) == MAX_LEVEL:
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + dir
			if _blocked(n):
				continue
			var ni := _idx(n)
			var diff := l - int(levels[ni])
			if diff >= 2:
				@warning_ignore("integer_division")
				var t := diff / 2
				levels[i] -= t
				levels[ni] += t
				fresh[ni] = dir.x
				_record_flow(i, Vector2(dir.x * t, 0))
				wake_around(c)
				wake_around(n)
				l -= t
				moved = true
	# 3. Ripple: a cell that just received sideways flow may push one unit
	# onward in the SAME direction even at diff 1. Unidirectional, so it
	# cannot oscillate — it levels the slope-1 wedges the diff>=2 rule
	# would otherwise freeze (long rooms flooding through a doorway).
	if fresh.has(i):
		var dirx: int = fresh[i]
		fresh.erase(i)
		if not moved and l > 0:
			var n2: Vector2i = c + Vector2i(dirx, 0)
			if (_blocked(below) or level_at(below) == MAX_LEVEL) and not _blocked(n2):
				var ni2 := _idx(n2)
				if int(levels[ni2]) < l and levels[ni2] < MAX_LEVEL:
					levels[i] -= 1
					levels[ni2] += 1
					fresh[ni2] = dirx
					_record_flow(i, Vector2(dirx, 0))
					wake_around(c)
					wake_around(n2)
					moved = true
	return moved

func _record_flow(i: int, units: Vector2) -> void:
	flow[i] = flow.get(i, Vector2.ZERO) + units

## Net outgoing flow (units this tick) at a cell — currents push bodies (WS-16).
func flow_at(cell: Vector2i) -> Vector2:
	if not in_bounds(cell):
		return Vector2.ZERO
	return flow.get(_idx(cell), Vector2.ZERO)

# --- Displacement (WS-24: displace if possible, destroy if enclosed) ---

## A block is being placed into `cell`: push its water into connected free
## space (raising the body's surface). Water that finds no room within the
## search limit is destroyed — filling a sealed pocket with blocks is a
## legitimate drain tactic.
func displace(cell: Vector2i) -> void:
	if not in_bounds(cell):
		return
	var units := int(levels[_idx(cell)])
	if units == 0:
		return
	levels[_idx(cell)] = 0
	wake_around(cell)
	# leftover units are destroyed (enclosed pocket)
	_insert_spread(cell, units, true)

## Removes up to `units` from water reachable through the connected airspace
## around `start`, taking from the topmost cells first. Searching through air
## (not just the water body) is deliberate, gameplay-first suction (GL-16):
## a pump drains the whole room including the last disconnected puddles.
func remove_water_spread(start: Vector2i, units: int) -> int:
	if not in_bounds(start):
		return 0
	var visited := {}
	var queue: Array[Vector2i] = [start]
	var body: Array[Vector2i] = []
	var searched := 0
	while not queue.is_empty() and searched < 1200:
		searched += 1
		var n: Vector2i = queue.pop_front()
		if _blocked(n) or visited.has(_idx(n)):
			continue
		visited[_idx(n)] = true
		if levels[_idx(n)] > 0:
			body.append(n)
		for d: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			queue.push_back(n + d)
	body.sort_custom(func(a, b): return a.y < b.y) # topmost (surface) first
	var removed := 0
	for c in body:
		if removed >= units:
			break
		removed += remove_water(c, units - removed)
	return removed

## Deposits `units` into free space connected to `start` (through the water
## body and the air just above it); returns what found no room. Also the
## pump-outlet path: inserting into the body sidesteps the diff>=2 spread
## rule's static-pyramid limitation under sustained point sources.
func add_water_spread(start: Vector2i, units: int) -> int:
	return _insert_spread(start, units, false)

func _insert_spread(start: Vector2i, units: int, skip_start: bool) -> int:
	var visited := {}
	if skip_start:
		visited[_idx(start)] = true
	var queue: Array[Vector2i] = []
	if skip_start:
		queue = [start + Vector2i.UP, start + Vector2i.LEFT, start + Vector2i.RIGHT, start + Vector2i.DOWN]
	else:
		queue = [start]
	var searched := 0
	while units > 0 and not queue.is_empty() and searched < 1200:
		searched += 1
		var n: Vector2i = queue.pop_front()
		if _blocked(n) or visited.has(_idx(n)):
			continue
		var ni := _idx(n)
		visited[ni] = true
		if levels[ni] < MAX_LEVEL:
			var t := mini(MAX_LEVEL - int(levels[ni]), units)
			levels[ni] += t
			units -= t
			wake_around(n)
		if levels[ni] > 0:
			# free space lives at the body's surface: search upward first
			for d: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
				queue.push_back(n + d)
	return units
