class_name CityGen
extends RefCounted
## Deterministic city generator (M3, CT-01..21): seed -> a full drowned city.
## Pure with respect to the World autoload: builds a WorldGrid plus object/
## door placement lists, so determinism is testable (same seed = same hashes,
## CT-21). Flooding is applied separately once doors exist, because sealing
## is decided by solidity (WS-20).
##
## Layout: bell-curve skyline (CT-01) — tallest towers centre, short sparse
## ones at the edges; every tower gets a west stairwell with a ladder and an
## east elevator shaft (CT-06); floors fill with room templates from
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
	}
	# Bare concrete ground (CT-07): The Crush's floor; solid below.
	for y in range(GROUND, WORLD_H):
		for x in world_w:
			grid.set_structure(Vector2i(x, y), WorldGrid.M.STONE)
	# Towers along a bell curve.
	var tallest := {"floors": 0}
	var x := 60
	while x < world_w - 100:
		var center_f := 1.0 - absf(x - world_w / 2.0) / (world_w / 2.0)
		# Tallest towers must BREAK the surface (waterline 64, ground 360):
		# 56 floors tops out around row 24 — six dry floors on the crown.
		var floors := clampi(int(roundf(lerpf(4.0, 56.0, pow(center_f, 1.7)) * rng.randf_range(0.78, 1.12))), 4, 56)
		var w := rng.randi_range(24, 38)
		var tower := _build_tower(grid, rng, rooms, x, w, floors, objects, doors, sealed)
		result.towers += 1
		if floors > tallest.floors:
			tallest = tower
		x += w + int(lerpf(34.0, 8.0, center_f)) + rng.randi_range(0, 14)
	# Authored start (CT-20): the tallest tower's top floor is the hospital
	# medical room — clear it and furnish deliberately, with a real bed.
	_author_medical_room(grid, tallest, objects, result)
	return result

static func _load_rooms() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms.json"))
	var by_type := {}
	for r in parsed.rooms:
		if not by_type.has(r.type):
			by_type[r.type] = []
		by_type[r.type].append(r)
	return by_type

static func _build_tower(grid: WorldGrid, rng: RandomNumberGenerator, rooms: Dictionary,
		x0: int, w: int, floors: int, objects: Array, doors: Array, sealed: Array) -> Dictionary:
	var x1 := x0 + w - 1
	var top := GROUND - floors * FLOOR_H
	var stair_x0 := x0 + 2
	var stair_wall := x0 + 5
	var shaft_wall := x1 - 4
	# Outer walls + interior back walls
	for y in range(top, GROUND):
		grid.set_structure(Vector2i(x0, y), WorldGrid.M.STONE)
		grid.set_structure(Vector2i(x0 + 1, y), WorldGrid.M.STONE)
		grid.set_structure(Vector2i(x1, y), WorldGrid.M.STONE)
		grid.set_structure(Vector2i(x1 - 1, y), WorldGrid.M.STONE)
	for y in range(top + 1, GROUND):
		for bx in range(x0 + 2, x1 - 1):
			grid.set_back(Vector2i(bx, y), WorldGrid.M.STONE)
	# Slabs with stairwell + shaft gaps
	for f in floors:
		var y := top + f * FLOOR_H
		for sx in range(x0 + 2, x1 - 1):
			var in_stair := sx >= stair_x0 and sx <= stair_x0 + 2 and f > 0
			var in_shaft := sx >= x1 - 3 and sx <= x1 - 2
			if not (in_stair or in_shaft):
				grid.set_structure(Vector2i(sx, y), WorldGrid.M.METAL)
	# Stairwell ladder
	for y in range(top + 1, GROUND):
		grid.set_climb(Vector2i(stair_x0 + 1, y), WorldGrid.C.LADDER)
	# Per-floor walls, doorways, rooms
	var mix := ["residential", "office", "hospital"]
	var tower_bias: String = mix[rng.randi_range(0, 2)]
	for f in floors:
		var ceiling := top + f * FLOOR_H
		var sr := ceiling + FLOOR_H - 1 # standing row
		# stairwell wall (lintel rows; doorway sr-2..sr stays open)
		for wy in range(ceiling + 1, sr - 2):
			grid.set_structure(Vector2i(stair_wall, wy), WorldGrid.M.STONE)
		for wy in range(ceiling + 1, sr - 2):
			grid.set_structure(Vector2i(shaft_wall, wy), WorldGrid.M.STONE)
		var zone_x := stair_wall + 1
		var zone_end := shaft_wall - 1
		var seal_this := sr > WATERLINE and rng.randf() < SEAL_CHANCE
		if seal_this:
			doors.append(Vector2i(stair_wall, sr))
			for wy in range(sr - 2, sr + 1): # shaft side walled solid
				grid.set_structure(Vector2i(shaft_wall, wy), WorldGrid.M.STONE)
			sealed.append(Rect2i(zone_x, ceiling + 1, zone_end - zone_x + 1, FLOOR_H - 1))
		# rooms (mixed use per floor, CT-02)
		var rtype: String = tower_bias if rng.randf() < 0.5 else mix[rng.randi_range(0, 2)]
		var pool: Array = rooms.get(rtype, [])
		var cx := zone_x
		while zone_end - cx >= 8 and not pool.is_empty():
			var t: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
			var tw := int(t.width)
			if cx + tw > zone_end:
				tw = zone_end - cx
			for o in t.objects:
				if cx + int(o.x) + 3 <= zone_end:
					objects.append({"id": o.id, "cell": Vector2i(cx + int(o.x), sr)})
			for b in t.get("blocks", []):
				var bc := Vector2i(cx + int(b.x), sr - int(b.dy))
				if bc.x < zone_end:
					grid.set_structure(bc, int(b.mat))
			cx += tw
			# interior partition with a doorway (rooms stitch by sockets)
			if zone_end - cx >= 8:
				for wy in range(ceiling + 1, sr - 2):
					grid.set_structure(Vector2i(cx, wy), WorldGrid.M.STONE)
				cx += 1
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
	return {"x0": x0, "x1": x1, "top": top, "floors": floors, "stair_wall": stair_wall, "shaft_wall": shaft_wall}

static func _author_medical_room(grid: WorldGrid, tower: Dictionary, objects: Array, result: Dictionary) -> void:
	var top: int = tower.top
	var sr: int = top + FLOOR_H - 1
	var zone_x: int = tower.stair_wall + 1
	var zone_end: int = tower.shaft_wall - 1
	# Clear whatever the generator put on this floor (objects and partitions).
	for i in range(objects.size() - 1, -1, -1):
		var c: Vector2i = objects[i].cell
		if c.y == sr and c.x >= zone_x - 1 and c.x <= zone_end:
			objects.remove_at(i)
	for wy in range(top + 1, sr + 1):
		for wx in range(zone_x, zone_end + 1):
			if grid.structure_at(Vector2i(wx, wy)) == WorldGrid.M.STONE:
				grid.set_structure(Vector2i(wx, wy), WorldGrid.M.AIR)
	# The authored kit: a real bed (spawn), medical gear, storage (GL-02).
	objects.append({"id": "bed", "cell": Vector2i(zone_x + 1, sr)})
	objects.append({"id": "med_cart", "cell": Vector2i(zone_x + 5, sr)})
	objects.append({"id": "cabinet", "cell": Vector2i(zone_x + 8, sr)})
	objects.append({"id": "locker", "cell": Vector2i(zone_x + 11, sr)})
	objects.append({"id": "chair", "cell": Vector2i(zone_x + 13, sr)})
	result.spawn_feet = Vector2((zone_x + 3 + 0.5) * Constants.BLOCK_SIZE, (sr + 1) * Constants.BLOCK_SIZE)
	result["hospital"] = tower

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
