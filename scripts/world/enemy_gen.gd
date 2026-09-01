class_name EnemyGen
extends RefCounted
## Seeds the city's enemy population at world gen (GD-02: placed once, no
## ambient respawn; red moons are the only replenishment). Uniform density
## everywhere (GD-27) — the per-band stat tables do the scaling. Roster by
## space (GD-01/10/11/13): walkers + crawlers on dry floors (sealed dry
## rooms included, at their depth's strength), the Drowned in flooded
## interiors of The Dark and The Crush, floaters bobbing on the open
## surface, sharks patrolling open water from The Cold down, fish schools
## in open water everywhere below the surface.
## Deterministic: its own RNG stream off the world seed (CT-21).

const FLOOR_H := 6 # CityGen.FLOOR_H

static func seed_city(gen: Dictionary, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "enemies"])
	var out: Array = []
	var grid: WorldGrid = gen.grid
	var waterline: int = gen.waterline_row
	var cfg: Dictionary = Data.enemy_seeding
	var zw: Array = cfg.get("wing_zombie_weights", [0.35, 0.45, 0.2])
	# --- Tower interiors ---
	var hospital: Dictionary = gen.get("hospital", {})
	for tower in gen.tower_list:
		for f in int(tower.floors):
			if f == 0 and not hospital.is_empty() and tower == hospital:
				continue # the authored starting medical room wakes you safely (GL-02)
			var sr: int = int(tower.top) + f * FLOOR_H + FLOOR_H - 1
			for zone in tower.zones:
				var zx0 := int(zone[0])
				var zx1 := int(zone[1])
				if zx1 - zx0 < 4:
					continue
				var mid := Vector2i((zx0 + zx1) / 2, sr - 1)
				var dry := sr < waterline or _in_sealed(gen.sealed, mid)
				if dry:
					var roll := rng.randf()
					var n := 0 if roll < float(zw[0]) else (1 if roll < float(zw[0]) + float(zw[1]) else 2)
					for i in n:
						var tid := "crawler" if rng.randf() < float(cfg.get("wing_crawler_chance", 0.3)) else "walker"
						_stand(out, rng, grid, tid, zx0, zx1, sr)
				elif _band(sr - waterline) in ["dark", "crush"]:
					if rng.randf() < float(cfg.get("wing_drowned_chance", 0.4)):
						_stand(out, rng, grid, "drowned", zx0, zx1, sr)
	# --- Open water ---
	_scatter(out, rng, grid, "floater", cfg.get("floater_spacing", [50, 120]),
		waterline, waterline, waterline)
	_scatter(out, rng, grid, "shark", cfg.get("shark_spacing", [80, 160]),
		waterline + Constants.BAND_COLD_DEPTH + 4, grid.bounds.end.y - 12, waterline)
	_scatter(out, rng, grid, "fish_school", cfg.get("fish_spacing", [40, 90]),
		waterline + 4, grid.bounds.end.y - 8, waterline)
	return out

static func _band(depth: int) -> String:
	if depth < 0:
		return "dry"
	if depth < Constants.BAND_SHALLOWS_DEPTH:
		return "shallows"
	if depth < Constants.BAND_COLD_DEPTH:
		return "cold"
	if depth < Constants.BAND_DARK_DEPTH:
		return "dark"
	return "crush"

static func _in_sealed(sealed: Array, cell: Vector2i) -> bool:
	for r: Rect2i in sealed:
		if r.has_point(cell):
			return true
	return false

## One enemy standing on floor row `sr`, at a clear column inside the wing.
static func _stand(out: Array, rng: RandomNumberGenerator, grid: WorldGrid,
		tid: String, zx0: int, zx1: int, sr: int) -> void:
	var h := float(Data.enemies[tid].size[1])
	for attempt in 4:
		var x := rng.randi_range(zx0, zx1)
		if grid.structure_at(Vector2i(x, sr)) == WorldGrid.M.AIR \
				and grid.structure_at(Vector2i(x, sr - 1)) == WorldGrid.M.AIR:
			out.append({"type": tid, "pos": Vector2((x + 0.5) * Constants.BLOCK_SIZE,
				(sr + 1) * Constants.BLOCK_SIZE - h * 0.5 - 1.0)})
			return

## Open-water spawns marching across the world at a random spacing:
## structure-free, outside buildings (no back wall), below the waterline.
static func _scatter(out: Array, rng: RandomNumberGenerator, grid: WorldGrid,
		tid: String, spacing: Array, y0: int, y1: int, waterline: int) -> void:
	if y0 > y1:
		return
	var h := float(Data.enemies[tid].size[1])
	var x := 30
	while x < grid.bounds.end.x - 30:
		x += rng.randi_range(int(spacing[0]), int(spacing[1]))
		var y := rng.randi_range(y0, y1)
		var ok := y >= waterline # the spawn row itself must be flooded
		for dy in range(-1, 2):
			var c := Vector2i(x, y + dy)
			if not grid.bounds.has_point(c) or grid.structure_at(c) != WorldGrid.M.AIR \
					or grid.back_at(c) != WorldGrid.M.AIR:
				ok = false
				break
		if ok:
			out.append({"type": tid, "pos": Vector2((x + 0.5) * Constants.BLOCK_SIZE,
				(y + 1) * Constants.BLOCK_SIZE - h * 0.5 - 1.0)})
