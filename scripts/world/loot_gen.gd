class_name LootGen
extends RefCounted
## Container loot (LT-12/13): every generated storage object rolls from a
## table keyed by its zone and its depth band, once, at world gen. Contents
## live in the object records, so the world save carries looted/unlooted
## state for free (LT-27). Safes roll the best-of-band "safe" tables.

static func fill_containers(records: Array, waterline: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 977 + 11
	var tables: Dictionary = Data.loot.get("tables", {})
	if tables.is_empty():
		return
	for rec: Dictionary in records:
		if rec.placed or rec.storage == null:
			continue
		var zkey := "generic"
		if rec.def.get("kind", "") == "safe":
			zkey = "safe"
		else:
			var zones: Array = rec.def.get("zones", [])
			if not zones.is_empty():
				zkey = String(zones[0])
		var band := _band(rec.cell.y - waterline)
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
			# Found gear may roll prefixes/suffixes (LT-05..08, LT-10);
			# a modded piece is a unique instance, stored as its own stack.
			var mods := ItemMods.roll(rng, id)
			if mods.is_empty():
				rec.storage.add(id, rng.randi_range(int(e.min), int(e.max)))
			else:
				rec.storage.add_stack({"id": id, "count": 1, "mods": mods})

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
