class_name EnemyGen
extends RefCounted
## Seeds the city's enemy population at world gen (GD-02: placed once, no
## ambient respawn; red moons are the only replenishment). Uniform density
## everywhere (GD-27) — the per-band stat tables do the scaling. Roster by
## space (GD-01/10/11/13): walkers + crawlers on dry floors (sealed dry
## rooms included, at their depth's strength), the Drowned in flooded
## interiors of The Dark and The Crush, the Bestiary Grid's district fauna
## on dry floors (T1: a share of each zombie roll becomes one of the tower
## district's own four) and its surface dwellers at the waterline
## (2026-09-06), predator fish (tropical / catfish /
## barracuda, 2026-09-06) in the flooded interiors and open water of The
## Shallows and The Cold, floaters bobbing on the open surface, sharks
## patrolling open water from The Cold down, fish schools in open water
## everywhere below the surface.
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
	# District uniques (Bestiary Grid T1, 2026-09-06): on a dry floor each
	# zombie roll becomes one of the tower district's own creatures with the
	# band's `district_fauna_share` (the chart's "unique replaces a share").
	var fauna: Dictionary = cfg.get("district_fauna", {})
	var fauna_share: Dictionary = cfg.get("district_fauna_share", {})
	for tower in gen.tower_list:
		var fh: int = int(tower.get("floor_h", CityGen.FLOOR_H)) # district floor pitch
		var dry_uniques: Array = (fauna.get("dry", {}) as Dictionary).get(String(tower.get("district", "")), [])
		var dry_share := float(fauna_share.get("dry", 0.0))
		# Pity timer per wing (user request 2026-09-05): each floor a wing
		# seeds nothing raises the next floor's odds, and after `pity` empty
		# floors the next one is guaranteed - never 3+ quiet floors in a row.
		var streaks: Array = []
		streaks.resize(tower.zones.size())
		streaks.fill(0)
		for f in int(tower.floors):
			if f == 0 and not spawn_tower.is_empty() and tower == spawn_tower:
				continue # keep the roof drop-off tower's top floor clear — no ambush on landing
			# World rows (the lattice is build-space; the stage gaps are spliced in).
			var ceiling: int = CityGen.floor_ceiling(tower, f)
			var sr: int = CityGen.floor_standing_row(tower, f)
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
						if not dry_uniques.is_empty() and _band(ceiling - waterline) == "dry" and rng.randf() < dry_share:
							tid = String(dry_uniques[rng.randi_range(0, dry_uniques.size() - 1)])
						_stand(out, rng, grid, tid, zx0, zx1, sr)
				elif _band(ceiling - waterline) in ["dark", "crush"]: # the floor's band = its ceiling row
					var chance := float(cfg.get("wing_drowned_chance", 0.4)) + boost * streak
					if streak >= pity or rng.randf() < chance:
						_stand(out, rng, grid, "drowned", zx0, zx1, sr)
				else:
					# Flooded Shallows/Cold floors (user request 2026-09-06): one
					# predator fish - tropical / catfish / barracuda by the band's
					# weights - so the first dives are no longer quiet.
					var fband := _band(ceiling - waterline)
					var weights: Dictionary = (cfg.get("wing_fish_weights", {}) as Dictionary).get(fband, {})
					var chance := float(cfg.get("wing_fish_chance", 0.0)) + boost * streak
					if not weights.is_empty() and (streak >= pity or rng.randf() < chance):
						var ftid := _weighted_pick(rng, weights)
						# District uniques of the flooded bands (Bestiary Grid T2+): a share of
						# each fish roll is one of the tower district's own.
						var band_uniques: Array = (fauna.get(fband, {}) as Dictionary).get(String(tower.get("district", "")), [])
						if not band_uniques.is_empty() and rng.randf() < float(fauna_share.get(fband, 0.0)):
							ftid = String(band_uniques[rng.randi_range(0, band_uniques.size() - 1)])
						_stand(out, rng, grid, ftid, zx0, zx1, sr)
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
	# Predator fish in open water (2026-09-06): each in the bands it has stats for.
	var pfs: Array = cfg.get("pred_fish_spacing", [60, 140])
	var shallows_end := waterline + Constants.BAND_SHALLOWS_DEPTH - 1
	var cold_end := waterline + Constants.BAND_COLD_DEPTH - 1
	_scatter(out, rng, grid, "tropical_fish", pfs, waterline + 6, shallows_end, waterline, open)
	_scatter(out, rng, grid, "catfish", pfs, waterline + 10, cold_end, waterline, open)
	_scatter(out, rng, grid, "barracuda", pfs, shallows_end + 1, cold_end, waterline, open)
	# Open-water hunters per band (Bestiary Grid T2+ "open water", 2026-09-06).
	var owfs: Array = cfg.get("open_water_fauna_spacing", [70, 150])
	var band_rows := {"shallows": [waterline + 8, shallows_end], "cold": [shallows_end + 1, cold_end],
		"dark": [cold_end + 1, waterline + Constants.BAND_DARK_DEPTH - 1], "crush": [waterline + Constants.BAND_DARK_DEPTH, grid.bounds.end.y - 16]}
	var owf: Dictionary = cfg.get("open_water_fauna", {})
	for band in owf:
		if not band_rows.has(band):
			continue
		for tid in owf[band]:
			_scatter(out, rng, grid, String(tid), owfs, int(band_rows[band][0]), int(band_rows[band][1]), waterline, open)
	# Surface fauna (Bestiary Grid T1 "open water", 2026-09-06): eels and
	# minnows just under the waterline, striders and mudskippers on it.
	var sfs: Array = cfg.get("surface_fauna_spacing", [50, 120])
	for tid in cfg.get("surface_fauna", []):
		var mode := String(Data.enemies.get(tid, {}).get("mode", "ground"))
		if mode == "swim":
			_scatter(out, rng, grid, String(tid), sfs, waterline + 1, waterline + 6, waterline, open)
		else:
			_scatter(out, rng, grid, String(tid), sfs, waterline, waterline, waterline, open)
	return out

## One key from a {id: weight} table.
static func _weighted_pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for w in weights.values():
		total += float(w)
	var roll := rng.randf() * total
	var last := ""
	for k in weights:
		last = String(k)
		roll -= float(weights[k])
		if roll <= 0.0:
			return last
	return last

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
