class_name LootGen
extends RefCounted
## Container loot (LT-12/13): every generated storage object rolls from a
## table keyed by its zone and its depth band, once, at world gen. Contents
## live in the object records, so the world save carries looted/unlooted
## state for free (LT-27). Safes roll the best-of-band "safe" tables.

## `towers` (World.towers summaries) resolves each container to its FLOOR's
## band - a floor straddling a boundary rolls the shallower table
## (DistrictsOverhaul "Bands", 2026-09-04).
## `pockets` (World.pockets) resolves annex containers to the tower their
## doorway (`exit`) sits in, so a pocket's loot carries that district.
static func fill_containers(records: Array, waterline: int, seed_value: int, towers: Array = [], pockets: Array = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 977 + 11
	var tables: Dictionary = Data.loot.get("tables", {})
	if tables.is_empty():
		return
	var tally := {}
	for rec: Dictionary in records:
		if rec.placed or rec.storage == null:
			continue
		# The tower's district is the loot table key AND the modifier family
		# (Modifiers.md "The Grid"); a container's own zone tag only covers
		# objects standing outside every tower (debris rafts, station shells).
		var district := district_of(towers, pockets, rec.cell)
		var zkey := district if district != "" else "generic"
		if rec.def.get("kind", "") == "safe":
			zkey = "safe"
		elif district == "":
			var zones: Array = rec.def.get("zones", [])
			if not zones.is_empty():
				zkey = String(zones[0])
		var band := _band(CityGen.band_row(towers, rec.cell) - waterline)
		var zone_tables: Dictionary = tables.get(zkey, {})
		var table: Array = zone_tables.get(band, [])
		if table.is_empty(): # zone has no table this deep: generic covers it
			table = (tables.generic as Dictionary).get(band, [])
		if table.is_empty():
			continue
		var picks := rng.randi_range(3, 5) if zkey == "safe" else rng.randi_range(2, 4)
		for i in picks:
			var e := _pick(rng, table)
			var id := String(e.item)
			# Found gear rolls its location's modifier (family = district,
			# tier = band); a modded piece is a unique instance, its own stack.
			var mods := ItemMods.roll(rng, id, district, band)
			if mods.is_empty():
				rec.storage.add(id, rng.randi_range(int(e.min), int(e.max)))
			else:
				rec.storage.add_stack({"id": id, "count": 1, "mods": mods})
				var k := "%s/%s" % [district if district != "" else "-", band]
				tally[k] = int(tally.get(k, 0)) + 1
	if OS.is_stdout_verbose() or "--f3" in OS.get_cmdline_user_args():
		print("LootGen: modded pieces per district/band ", tally)

## The district a container's cell belongs to: its tower's, or — inside the
## VOID annex — the tower holding the pocket's doorway. "" outside every tower.
static func district_of(towers: Array, pockets: Array, cell: Vector2i) -> String:
	var t := CityGen.tower_at(towers, cell)
	if t.is_empty():
		for p: Dictionary in pockets:
			if (p.rect as Rect2i).has_point(cell):
				t = CityGen.tower_at(towers, p.exit)
				break
	return String(t.get("district", ""))

static func _pick(rng: RandomNumberGenerator, table: Array) -> Dictionary:
	var total := 0
	for e in table:
		total += int(e.get("w", 1))
	var roll := rng.randi_range(1, total)
	for e in table:
		roll -= int(e.get("w", 1))
		if roll <= 0:
			return e
	return table[0]

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
