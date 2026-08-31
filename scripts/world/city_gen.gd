class_name CityGen
extends RefCounted
## Deterministic city generator (M3, CT-01..21): seed -> a full drowned city.
## Pure with respect to the World autoload: builds a WorldGrid plus object/
## door placement lists, so determinism is testable (same seed = same hashes,
## CT-21). Flooding is applied separately once doors exist, because sealing
## is decided by solidity (WS-20).
##
## Layout: bell-curve skyline (CT-01) — tallest towers centre, short sparse
## ones at the edges; every tower is a double-wide twin-wing block: ladder
## stairwells on BOTH sides, an elevator shaft down the centre (CT-06), and
## submerged ladder runs broken into scrappable gaps (craft ladders to climb
## back up); floors fill with room templates from
## data/rooms.json, mixed-use per floor (CT-02); a wear pass adds breaches
## scaling with depth (CT-11); some submerged floors are sealed dry behind
## doors; the tallest tower's top floor is the authored starting medical
## room (GL-02, CT-20).

const WORLD_W := 2400
const WORLD_H := 400
const WATERLINE := 64
const GROUND := 360
const FLOOR_H := 6
const SEAL_CHANCE := 0.16

static func generate(seed_value: int, world_w: int = WORLD_W) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var grid := WorldGrid.new(Rect2i(0, 0, world_w, WORLD_H))
	var rooms := _load_rooms()
	var objects: Array = []   # {id, cell}
	var doors: Array = []     # cells for wood_door
	var sealed: Array = []    # Rect2i room interiors meant to start dry
	var result := {
		"grid": grid, "objects": objects, "doors": doors, "sealed": sealed,
		"waterline_row": WATERLINE, "towers": 0, "spawn_feet": Vector2.ZERO, "seed": seed_value,
		"tower_list": [], "relays": [], "debris": 0,
	}
	# Bare concrete ground (CT-07): The Crush's floor; solid below.
	for y in range(GROUND, WORLD_H):
		for x in world_w:
			grid.set_structure(Vector2i(x, y), WorldGrid.M.STONE)
	# Towers along a bell curve.
	var tallest := {"floors": 0}
	var forced_crown := false # with wide towers there are few centre samples,
	var x := 60               # so one full-height crown is guaranteed
	while x < world_w - 100:
		var center_f := 1.0 - absf(x - world_w / 2.0) / (world_w / 2.0)
		# Tallest towers must BREAK the surface (waterline 64, ground 360):
		# 56 floors tops out around row 24 — six dry floors on the crown.
		var floors := clampi(int(roundf(lerpf(4.0, 56.0, pow(center_f, 1.7)) * rng.randf_range(0.78, 1.12))), 4, 56)
		if center_f > 0.85 and not forced_crown:
			floors = 56
			forced_crown = true
		var w := rng.randi_range(48, 76) # doubled (user request): two wings + central shaft
		var tower := _build_tower(grid, rng, rooms, x, w, floors, objects, doors, sealed)
		result.towers += 1
		result.tower_list.append(tower)
		if floors > tallest.floors:
			tallest = tower
		x += w + int(lerpf(34.0, 8.0, center_f)) + rng.randi_range(0, 14)
	# Authored start (CT-20): the tallest tower's top floor is the hospital
	# medical room — clear it and furnish deliberately, with a real bed.
	_author_medical_room(grid, tallest, objects, result)
	# Mega-pump infrastructure shells (CT-08/26, CC-26): the central station
	# on the concrete ground plus relay pylons at the band boundaries.
	_author_stations(grid, rng, objects, result, world_w)
	# Light floating debris on the open surface for mood (CT-23).
	_scatter_surface_debris(grid, rng, objects, result, world_w)
	return result

## Two-jump rule check (WS-04): every column of a floor cavity must stay
## passable — jump height is 3 blocks and a crawl fits a 1-block gap, so the
## only true blockage is an authored obstacle >= 4 tall from the standing row
## (too high to mount, no room to crawl over). Returns the offending columns.
static func floor_blockages(grid: WorldGrid, tower: Dictionary) -> Array:
	var out: Array = []
	var top: int = tower.top
	for f in tower.floors:
		var sr: int = top + f * FLOOR_H + FLOOR_H - 1
		for zone in tower.zones:
			for vx in range(int(zone[0]), int(zone[1]) + 1):
				var blocked := true
				for vy in range(sr - 3, sr + 1):
					if grid.structure_at(Vector2i(vx, vy)) == WorldGrid.M.AIR:
						blocked = false
						break
				if blocked:
					out.append(Vector2i(vx, sr))
	return out

static func _load_rooms() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms.json"))
	var by_zone := {}
	for r in parsed.rooms:
		var key: String = r.get("zone", r.get("type", "residential"))
		if not by_zone.has(key):
			by_zone[key] = []
		by_zone[key].append(r)
	return by_zone

static func _build_tower(grid: WorldGrid, rng: RandomNumberGenerator, rooms: Dictionary,
		x0: int, w: int, floors: int, objects: Array, doors: Array, sealed: Array) -> Dictionary:
	# Twin-wing layout (user request, 2026-08-31): double-wide towers with a
	# ladder stairwell on EACH side and an elevator shaft down the centre.
	#   walls | west stair (ladder) | wall | west wing | wall | shaft |
	#   wall | east wing | wall | east stair (ladder) | walls
	var x1 := x0 + w - 1
	var top := GROUND - floors * FLOOR_H
	var mid := x0 + w / 2
	var lad_w := x0 + 3          # ladder columns
	var lad_e := x1 - 3
	var wall_w := x0 + 5         # stair walls
	var wall_e := x1 - 5
	var zones := [[x0 + 6, mid - 3], [mid + 3, x1 - 6]]
	# Outer walls + interior back walls
	for y in range(top, GROUND):
		grid.set_structure(Vector2i(x0, y), WorldGrid.M.STONE)
		grid.set_structure(Vector2i(x0 + 1, y), WorldGrid.M.STONE)
		grid.set_structure(Vector2i(x1, y), WorldGrid.M.STONE)
		grid.set_structure(Vector2i(x1 - 1, y), WorldGrid.M.STONE)
	for y in range(top + 1, GROUND):
		for bx in range(x0 + 2, x1 - 1):
			grid.set_back(Vector2i(bx, y), WorldGrid.M.STONE)
	# Slabs with gaps at both stairwells and the central shaft
	for f in floors:
		var y := top + f * FLOOR_H
		for sx in range(x0 + 2, x1 - 1):
			var in_stair: bool = f > 0 and ((sx >= x0 + 2 and sx <= x0 + 4) or (sx >= x1 - 4 and sx <= x1 - 2))
			var in_shaft: bool = sx >= mid - 1 and sx <= mid + 1
			if not (in_stair or in_shaft):
				grid.set_structure(Vector2i(sx, y), WorldGrid.M.METAL)
	# Ladders on both sides
	for y in range(top + 1, GROUND):
		grid.set_climb(Vector2i(lad_w, y), WorldGrid.C.LADDER)
		grid.set_climb(Vector2i(lad_e, y), WorldGrid.C.LADDER)
	# Per-floor walls, doorways, rooms in both wings
	var mix := rooms.keys()
	mix.sort() # deterministic order (CT-21)
	var tower_bias: String = mix[rng.randi_range(0, mix.size() - 1)]
	for f in floors:
		var ceiling := top + f * FLOOR_H
		var sr := ceiling + FLOOR_H - 1 # standing row
		# stair walls + shaft walls (lintel rows; doorway sr-2..sr stays open)
		for wy in range(ceiling + 1, sr - 2):
			grid.set_structure(Vector2i(wall_w, wy), WorldGrid.M.STONE)
			grid.set_structure(Vector2i(wall_e, wy), WorldGrid.M.STONE)
			grid.set_structure(Vector2i(mid - 2, wy), WorldGrid.M.STONE)
			grid.set_structure(Vector2i(mid + 2, wy), WorldGrid.M.STONE)
		for wing in 2:
			var zone_x: int = zones[wing][0]
			var zone_end: int = zones[wing][1]
			var seal_this := sr > WATERLINE and rng.randf() < SEAL_CHANCE
			if seal_this:
				# Deeper sealed rooms hide behind tougher doors (GL-09): wood
				# in The Shallows, chained metal in The Cold, vaults below.
				var dd := sr - WATERLINE
				var did := "wood_door"
				if dd > Constants.BAND_COLD_DEPTH:
					did = "vault_door"
				elif dd > Constants.BAND_SHALLOWS_DEPTH:
					did = "metal_door"
				var door_x: int = wall_w if wing == 0 else wall_e
				var shaft_x: int = mid - 2 if wing == 0 else mid + 2
				doors.append({"cell": Vector2i(door_x, sr), "id": did})
				for wy in range(sr - 2, sr + 1): # shaft side walled solid
					grid.set_structure(Vector2i(shaft_x, wy), WorldGrid.M.STONE)
				sealed.append(Rect2i(zone_x, ceiling + 1, zone_end - zone_x + 1, FLOOR_H - 1))
			# rooms (mixed use per floor, CT-02), filtered by depth range
			var rtype: String = tower_bias if rng.randf() < 0.5 else mix[rng.randi_range(0, mix.size() - 1)]
			var pool: Array = rooms.get(rtype, [])
			var depth := sr - WATERLINE
			var candidates := pool.filter(func(r): return depth >= int(r.get("depth_min", -9999)) and depth <= int(r.get("depth_max", 9999)))
			if candidates.is_empty():
				candidates = pool
			var cx := zone_x
			while zone_end - cx >= 8 and not candidates.is_empty():
				var t: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
				var tw := int(t.width)
				if cx + tw > zone_end:
					tw = zone_end - cx
				_stamp_room(grid, rng, t, tw, cx, sr, zone_end, objects, rtype)
				cx += tw
				# interior partition with a doorway (rooms stitch by sockets)
				if zone_end - cx >= 8:
					for wy in range(ceiling + 1, sr - 2):
						grid.set_structure(Vector2i(cx, wy), WorldGrid.M.STONE)
					cx += 1
	# Broken ladders (user request): submerged runs have decayed into gaps.
	# The pieces scrap for wood; craft ladders and place them to climb back
	# up. (Dry crown ladders stay intact — the tutorial floors.)
	for lx: int in [lad_w, lad_e]:
		var ly := maxi(top + 1, WATERLINE + 2)
		while ly < GROUND - 6:
			ly += rng.randi_range(8, 22) # intact run between gaps
			var gap := rng.randi_range(2, 4)
			for gy in range(ly, mini(ly + gap, GROUND - 2)):
				grid.set_climb(Vector2i(lx, gy), WorldGrid.C.NONE)
				if rng.randf() < 0.6:
					objects.append({"id": "broken_ladder", "cell": Vector2i(lx, gy)})
			ly += gap
	# Two-jump repair (WS-04): carve a walking doorway through any authored
	# obstacle a 3-block jump plus a crawl can't clear — a gen-time guarantee.
	var tower := {"x0": x0, "x1": x1, "top": top, "floors": floors, "mid": mid, "zones": zones}
	for bc: Vector2i in floor_blockages(grid, tower):
		for vy in range(bc.y - 2, bc.y + 1):
			grid.set_structure(Vector2i(bc.x, vy), WorldGrid.M.AIR)
	# Wear pass (CT-11): breaches scale with depth; occasional slab collapse.
	for f in floors:
		var sr := top + f * FLOOR_H + FLOOR_H - 1
		if sr <= WATERLINE:
			continue
		var depth_f := clampf(float(sr - WATERLINE) / 200.0, 0.0, 1.0)
		if rng.randf() < 0.2 + depth_f * 0.5:
			var side := x0 if rng.randf() < 0.5 else x1 - 1
			for by in range(sr - rng.randi_range(1, 2), sr + 1):
				grid.set_structure(Vector2i(side, by), WorldGrid.M.AIR)
				grid.set_structure(Vector2i(side + 1, by), WorldGrid.M.AIR)
		if f > 0 and rng.randf() < 0.10:
			var cy := top + f * FLOOR_H
			var hole_x := rng.randi_range(x0 + 6, x1 - 10)
			for hx in range(hole_x, hole_x + rng.randi_range(4, 7)):
				grid.set_structure(Vector2i(hx, cy), WorldGrid.M.AIR)
	return tower

## Stamp one room template with per-instance variety (CT-05, user request:
## identical layouts everywhere read as copy-paste): random mirroring,
## ±1 furniture jitter, pieces occasionally missing (looted before the
## flood), wall art hung at slightly different heights, and a sprinkle of
## zone clutter in the leftover floor space. All rng-driven = seed-stable.
static func _stamp_room(grid: WorldGrid, rng: RandomNumberGenerator, t: Dictionary,
		tw: int, cx: int, sr: int, zone_end: int, objects: Array, zone: String) -> void:
	var mirror := rng.randf() < 0.5
	var taken: Array = [] # [x0, x1) floor intervals used by furniture
	for o in t.objects:
		var def: Dictionary = Data.objects.get(o.id, {})
		if def.is_empty():
			continue
		var w := int(def.size[0])
		var h := int(def.size[1])
		var wall: bool = def.get("wall_mounted", false)
		if rng.randf() < 0.15:
			continue # somebody got here first
		var ox := int(o.x)
		if mirror:
			ox = tw - w - ox
		ox += rng.randi_range(-1, 1)
		ox = clampi(ox, 0, tw - w)
		if wall:
			var dy := int(o.get("dy", 3))
			dy = clampi(dy + rng.randi_range(0, 1), 1, FLOOR_H - 1 - h)
			if cx + ox + w <= zone_end:
				objects.append({"id": o.id, "cell": Vector2i(cx + ox, sr - dy)})
			continue
		for attempt in 3: # slide right until the jittered spot is free
			if not _interval_taken(taken, ox, ox + w) and cx + ox + w <= zone_end:
				taken.append([ox, ox + w])
				objects.append({"id": o.id, "cell": Vector2i(cx + ox, sr)})
				break
			ox = clampi(ox + 1, 0, tw - w)
	# Mirrored authored blocks keep counters against the intended wall.
	for b in t.get("blocks", []):
		if int(b.dy) >= FLOOR_H - 1:
			continue # rooms authored taller than the floor cavity crop
		var bx := int(b.x)
		if mirror:
			bx = tw - 1 - bx
		var bc := Vector2i(cx + bx, sr - int(b.dy))
		if bc.x < zone_end:
			grid.set_structure(bc, int(b.mat))
	# A rare wall safe (LT-14) tucked into the room's free space.
	if rng.randf() < 0.04:
		var sx := rng.randi_range(0, tw - 1)
		if not _interval_taken(taken, sx, sx + 1) and cx + sx + 1 <= zone_end:
			taken.append([sx, sx + 1])
			objects.append({"id": "safe", "cell": Vector2i(cx + sx, sr)})
	# A little lived-in mess: 0-2 clutter pieces from this zone's set.
	var clutter := _zone_clutter(zone)
	if not clutter.is_empty():
		for i in rng.randi_range(0, 2):
			var id: String = clutter[rng.randi_range(0, clutter.size() - 1)]
			var ox2 := rng.randi_range(0, tw - 1)
			if not _interval_taken(taken, ox2, ox2 + 1) and cx + ox2 + 1 <= zone_end:
				taken.append([ox2, ox2 + 1])
				objects.append({"id": id, "cell": Vector2i(cx + ox2, sr)})

static func _interval_taken(taken: Array, x0: int, x1: int) -> bool:
	for iv in taken:
		if x0 < int(iv[1]) and int(iv[0]) < x1:
			return true
	return false

static var _clutter_cache: Dictionary = {}

## 1x1 scrap items tagged for this zone (pack clutter), sorted for CT-21.
static func _zone_clutter(zone: String) -> Array:
	if _clutter_cache.has(zone):
		return _clutter_cache[zone]
	var out: Array = []
	for id in Data.objects:
		var def: Dictionary = Data.objects[id]
		if def.get("kind", "") == "scrap" and def.get("category", "") == "clutter" \
				and int(def.size[0]) == 1 and int(def.size[1]) == 1 \
				and (def.get("zones", []) as Array).has(zone):
			out.append(id)
	out.sort()
	_clutter_cache[zone] = out
	return out

static func _author_medical_room(grid: WorldGrid, tower: Dictionary, objects: Array, result: Dictionary) -> void:
	var top: int = tower.top
	var sr: int = top + FLOOR_H - 1
	var zone_x: int = tower.zones[0][0]
	var zone_end: int = tower.zones[0][1]
	# Clear whatever the generator put on this floor (objects — wall art
	# included, which anchors above the standing row — and partitions).
	for i in range(objects.size() - 1, -1, -1):
		var c: Vector2i = objects[i].cell
		if c.y <= sr and c.y > sr - FLOOR_H and c.x >= zone_x - 1 and c.x <= zone_end:
			objects.remove_at(i)
	for wy in range(top + 1, sr + 1):
		for wx in range(zone_x, zone_end + 1):
			# ANY leftover template structure goes (wood shelves included —
			# only stone was cleared before, leaving planks over the bed).
			if grid.structure_at(Vector2i(wx, wy)) != WorldGrid.M.AIR:
				grid.set_structure(Vector2i(wx, wy), WorldGrid.M.AIR)
	# The authored kit: a real bed (spawn), medical gear, storage (GL-02).
	objects.append({"id": "bed", "cell": Vector2i(zone_x + 1, sr)})
	objects.append({"id": "med_cart", "cell": Vector2i(zone_x + 5, sr)})
	objects.append({"id": "cabinet", "cell": Vector2i(zone_x + 8, sr)})
	objects.append({"id": "locker", "cell": Vector2i(zone_x + 11, sr)})
	objects.append({"id": "chair", "cell": Vector2i(zone_x + 13, sr)})
	result.spawn_feet = Vector2((zone_x + 3 + 0.5) * Constants.BLOCK_SIZE, (sr + 1) * Constants.BLOCK_SIZE)
	result["hospital"] = tower

## Mega-pump shells (CT-08, CC-26): non-functional for now — the endgame
## drain wires them up in a later milestone. The central station is a metal
## hall on the concrete ground at city centre; relays are freestanding metal
## pylons rising from the ground with a machine room at each band boundary.
static func _author_stations(grid: WorldGrid, rng: RandomNumberGenerator,
		objects: Array, result: Dictionary, world_w: int) -> void:
	# Central station: a hall on the ground row, in the inter-tower gap
	# nearest the city centre that can hold it (gaps narrow toward centre).
	var best_x := -1
	var best_score := -1.0e18
	var towers: Array = result.tower_list
	for i in range(towers.size() - 1):
		var gap_x0: int = int(towers[i].x1) + 1
		var gap_w: int = int(towers[i + 1].x0) - gap_x0
		if gap_w < 20:
			continue
		var mid := gap_x0 + gap_w / 2
		var score := -absf(mid - world_w / 2.0)
		if score > best_score:
			best_score = score
			best_x = mid
	if best_x >= 0:
		var hall := Rect2i(best_x - 9, GROUND - 7, 18, 7)
		_station_room(grid, hall, objects, true)
		result["central"] = hall
	# Relay pylons at the shallows/cold, cold/dark, dark/crush boundaries.
	var relay_rows: Array = [
		WATERLINE + Constants.BAND_SHALLOWS_DEPTH,
		WATERLINE + Constants.BAND_COLD_DEPTH,
		WATERLINE + Constants.BAND_DARK_DEPTH,
	]
	var fracs: Array = [0.25, 0.58, 0.8]
	for i in relay_rows.size():
		var row: int = relay_rows[i]
		var px0 := _find_open_span(grid, int(world_w * float(fracs[i])), row, 14, row - 6, row + 1)
		if px0 < 0:
			continue
		var shell := Rect2i(px0, row - 5, 14, 6)
		_station_room(grid, shell, objects, false)
		# Support legs drop until they meet something solid (a roof or the
		# ground) — never through a tower's interior (keeps WS-04 intact).
		for lx: int in [px0 + 1, px0 + 12]:
			for y in range(row + 2, GROUND + 1):
				if grid.structure_at(Vector2i(lx, y)) != WorldGrid.M.AIR:
					break
				grid.set_structure(Vector2i(lx, y), WorldGrid.M.METAL)
		result.relays.append(shell)

## A sealed metal machine room: walls, roof, back walls, ladder entry through
## the roof hatch, and the pump/breaker kit. rect covers the outer shell.
static func _station_room(grid: WorldGrid, rect: Rect2i, objects: Array, central: bool) -> void:
	var sr := rect.end.y - 1 # standing row (bottom shell row is the floor)
	for y in range(rect.position.y, rect.end.y + 1):
		for x in range(rect.position.x, rect.end.x):
			var edge: bool = y == rect.position.y or y > sr or x == rect.position.x or x == rect.end.x - 1
			grid.set_structure(Vector2i(x, y), WorldGrid.M.METAL if edge else WorldGrid.M.AIR)
			if not edge:
				grid.set_back(Vector2i(x, y), WorldGrid.M.METAL)
	# Side doorway (2-tall) so divers can get in; water floods it like any room.
	grid.set_structure(Vector2i(rect.position.x, sr), WorldGrid.M.AIR)
	grid.set_structure(Vector2i(rect.position.x, sr - 1), WorldGrid.M.AIR)
	var x0 := rect.position.x + 2
	objects.append({"id": "breaker", "cell": Vector2i(x0, sr - 2)})
	objects.append({"id": "pump", "cell": Vector2i(x0 + 2, sr)})
	objects.append({"id": "ceiling_lamp", "cell": Vector2i(x0 + 4, rect.position.y + 1)})
	if central:
		objects.append({"id": "pump", "cell": Vector2i(x0 + 6, sr)})
		objects.append({"id": "pump", "cell": Vector2i(x0 + 9, sr)})
		objects.append({"id": "ceiling_lamp", "cell": Vector2i(x0 + 11, rect.position.y + 1)})
		objects.append({"id": "chest", "cell": Vector2i(x0 + 12, sr)})

## Leftmost x of a `w`-wide span centred near want_x whose rows y0..y1 are
## clear of structure; scans outward, -1 if the city is too dense there.
static func _find_open_span(grid: WorldGrid, want_x: int, _row: int, w: int, y0: int, y1: int) -> int:
	for off in range(0, 400, 4):
		for sgn: int in [1, -1]:
			var x0 := want_x + off * sgn - w / 2
			if x0 < 4 or x0 + w > grid.bounds.end.x - 4:
				continue
			var clear := true
			for x in range(x0, x0 + w):
				for y in range(y0, y1 + 1):
					if grid.structure_at(Vector2i(x, y)) != WorldGrid.M.AIR:
						clear = false
						break
				if not clear:
					break
			if clear:
				return x0
	return -1

## Floating wood rafts scattered on open water between towers (CT-23).
static func _scatter_surface_debris(grid: WorldGrid, rng: RandomNumberGenerator,
		objects: Array, result: Dictionary, world_w: int) -> void:
	var x := 30
	while x < world_w - 30:
		x += rng.randi_range(40, 110)
		var w := rng.randi_range(2, 5)
		var clear := true
		for sx in range(x - 1, x + w + 1):
			for sy in range(WATERLINE - 4, WATERLINE + 3):
				if grid.structure_at(Vector2i(sx, sy)) != WorldGrid.M.AIR:
					clear = false
					break
			if not clear:
				break
		if not clear:
			continue
		for sx in range(x, x + w):
			grid.set_structure(Vector2i(sx, WATERLINE), WorldGrid.M.WOOD)
		if w >= 4 and rng.randf() < 0.35:
			objects.append({"id": "ret_box", "cell": Vector2i(x + 1, WATERLINE - 1)})
		result.debris += 1

## Connectivity flooding (CT-12/13): everything reachable from the ocean at
## or below the waterline floods to full; sealed pockets keep their air.
## Runs after objects exist so closed doors seal (queries World solidity).
static func flood(world) -> void:
	var sim: WaterSim = world.water_sim
	var b: Rect2i = sim.bounds
	var visited := PackedByteArray()
	visited.resize(b.size.x * b.size.y)
	var stack: Array[Vector2i] = []
	for y in range(WATERLINE, GROUND):
		stack.append(Vector2i(b.position.x, y))
		stack.append(Vector2i(b.end.x - 1, y))
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if c.y < WATERLINE or not b.has_point(c):
			continue
		var vi := (c.y - b.position.y) * b.size.x + (c.x - b.position.x)
		if visited[vi] == 1:
			continue
		visited[vi] = 1
		if world.is_solid_cell(c):
			continue
		sim.seed_cell(c, WaterSim.MAX_LEVEL)
		stack.append(c + Vector2i.LEFT)
		stack.append(c + Vector2i.RIGHT)
		stack.append(c + Vector2i.UP)
		stack.append(c + Vector2i.DOWN)
