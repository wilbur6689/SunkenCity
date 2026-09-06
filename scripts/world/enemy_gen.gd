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
## Cells are 8 px (2026-09-04): row/column margins below are in cells.

static func seed_city(gen: Dictionary, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "enemies"])
	var out: Array = []
	var grid: WorldGrid = gen.grid
	var waterline: int = gen.waterline_row
	var cfg: Dictionary = Data.enemy_seeding
	var zw: Array = cfg.get("wing_zombie_weights", [0.35, 0.45, 0.2])
	# --- Tower interiors ---
	var spawn_tower: Dictionary = gen.get("spawn_tower", {})
	var pity: int = int(cfg.get("wing_pity_floors", 2))
	var boost: float = float(cfg.get("wing_pity_boost", 0.5))
	for tower in gen.tower_list:
		var fh: int = int(tower.get("floor_h", CityGen.FLOOR_H)) # district floor pitch
		# Pity timer per wing (user request 2026-09-05): each floor a wing
		# seeds nothing raises the next floor's odds, and after `pity` empty
		# floors the next one is guaranteed - never 3+ quiet floors in a row.
		var streaks: Array = []
		streaks.resize(tower.zones.size())
		streaks.fill(0)
		for f in int(tower.floors):
			if f == 0 and not spawn_tower.is_empty() and tower == spawn_tower:
				continue # keep the roof drop-off tower's top floor clear — no ambush on landing
			var ceiling: int = int(tower.top) + f * fh
			var sr: int = ceiling + fh - 1
			for zi in tower.zones.size():
				var zone = tower.zones[zi]
				var zx0 := int(zone[0])
				var zx1 := int(zone[1])
				if zx1 - zx0 < 8:
					continue
				var streak: int = int(streaks[zi])
				var before := out.size()
				var mid := Vector2i((zx0 + zx1) / 2, sr - 1)
				var dry := sr < waterline or _in_sealed(gen.sealed, mid)
				if dry:
					# weights[i] = chance of exactly i zombies in this wing (any length).
					var roll := rng.randf()
					var n := zw.size() - 1
					var acc := 0.0
					for i in zw.size():
						acc += float(zw[i])
						if roll < acc:
							n = i
							break
					if n == 0 and streak > 0 and (streak >= pity or rng.randf() < boost * streak):
						n = 1
					for i in n:
						var tid := "crawler" if rng.randf() < float(cfg.get("wing_crawler_chance", 0.3)) else "walker"
						_stand(out, rng, grid, tid, zx0, zx1, sr)
				elif _band(ceiling - waterline) in ["dark", "crush"]: # the floor's band = its ceiling row
					var chance := float(cfg.get("wing_drowned_chance", 0.4)) + boost * streak
					if streak >= pity or rng.randf() < chance:
						_stand(out, rng, grid, "drowned", zx0, zx1, sr)
				# Flooded Shallows/Cold floors seed nothing (walkers are dry-only,
				# the Drowned start in The Dark) - they still count as quiet floors.
				streaks[zi] = 0 if out.size() > before else streak + 1
	# --- Open water ---
	# Only the city proper: the gap + VOID annex east of it (interior pockets)
	# is dry air and blackness, not ocean.
	var city_end: int = int(gen.get("city_w", grid.bounds.end.x))
	# The districts city (2026-09-04) packs towers at 5-10 cell gaps, so a
	# random column almost always lands inside a tower: spacings are walked
	# along OPEN-WATER columns only (the gaps + the ocean margins).
	var open := _open_columns(gen.tower_list, city_end)
	_scatter(out, rng, grid, "floater", cfg.get("floater_spacing", [50, 120]),
		waterline, waterline, waterline, open)
	_scatter(out, rng, grid, "shark", cfg.get("shark_spacing", [80, 160]),
		waterline + Constants.BAND_COLD_DEPTH + 8, grid.bounds.end.y - 24, waterline, open)
	_scatter(out, rng, grid, "fish_school", cfg.get("fish_spacing", [40, 90]),
		waterline + 8, grid.bounds.end.y - 16, waterline, open)
	return out

## Columns outside every tower footprint, ascending, 60 cells in from either
## edge of the city proper (the annex east of it is dry air).
static func _open_columns(towers: Array, city_end: int) -> PackedInt32Array:
	var spans: Array = []
	for t in towers:
		spans.append(Vector2i(int(t.x0), int(t.x1)))
	spans.sort_custom(func(a, b): return a.x < b.x)
	var out := PackedInt32Array()
	var x := 60
	var end := city_end - 60
	for s: Vector2i in spans:
		while x < s.x and x < end:
			out.append(x)
			x += 1
		x = maxi(x, s.y + 1)
	while x < end:
		out.append(x)
		x += 1
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
		var clear := true
		for dy in CityGen.STAND_GAP: # a standing body needs STAND_GAP rows
			if grid.structure_at(Vector2i(x, sr - dy)) != WorldGrid.M.AIR:
				clear = false
				break
		if clear:
			out.append({"type": tid, "pos": Vector2((x + 0.5) * Constants.BLOCK_SIZE,
				(sr + 1) * Constants.BLOCK_SIZE - h * 0.5 - 1.0)})
			return

## Open-water spawns marching along the open-water columns at a random
## spacing (measured in open columns, so a narrow gap between two towers
## counts for exactly its width): structure-free, outside buildings (no back
## wall), below the waterline. A blocked pick retries a few rows before the
## stride moves on.
static func _scatter(out: Array, rng: RandomNumberGenerator, grid: WorldGrid,
		tid: String, spacing: Array, y0: int, y1: int, waterline: int, open: PackedInt32Array) -> void:
	if y0 > y1 or open.is_empty():
		return
	var h := float(Data.enemies[tid].size[1])
	var i := 0
	while true:
		i += rng.randi_range(int(spacing[0]), int(spacing[1]))
		if i >= open.size():
			break
		var x := open[i]
		for attempt in 4:
			var y := rng.randi_range(y0, y1)
			var ok := y >= waterline # the spawn row itself must be flooded
			for dy in range(-3, 3): # 6 clear rows around the spawn row
				var c := Vector2i(x, y + dy)
				if not grid.bounds.has_point(c) or grid.structure_at(c) != WorldGrid.M.AIR \
						or grid.back_at(c) != WorldGrid.M.AIR:
					ok = false
					break
			if ok:
				out.append({"type": tid, "pos": Vector2((x + 0.5) * Constants.BLOCK_SIZE,
					(y + 1) * Constants.BLOCK_SIZE - h * 0.5 - 1.0)})
				break
