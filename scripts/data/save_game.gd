class_name SaveGame
extends RefCounted
## Persistence (CC-09) — the Terraria model: **world saves and character
## saves are separate files** under user://saves/, so any character can join
## any world. Binary via store_var (Vector2i / PackedByteArray serialize
## natively); the big layers (grid, water, map reveal) zstd-compress.
## The map reveal is per character *per world* (CC-25), keyed by world name.

const WORLD_DIR := "user://saves/worlds/"
const CHAR_DIR := "user://saves/chars/"
const WORLD_EXT := ".world"
const CHAR_EXT := ".char"
const VERSION := 2 # 2 = 8 px cells (2026-09-04); v1 worlds/characters are refused, not migrated
## World files carry their own version: 3 = compact object records (districts city, 2026-09-04:
## ~50k records as an id table + PackedInt32Array instead of one Dictionary each - 20 MB -> ~1 MB).
const WORLD_VERSION := 4 # 4: stage gaps spliced into the grid (2026-09-06); 3: compact object records
const OBJ_PLACED := 1
const OBJ_OPEN := 2
const OBJ_POWERED := 4
const OBJ_UNLOCKED := 8

## Handoff into the city scene's next boot (set by the title screen or the
## quick-load key before a scene change/reload).
static var pending_world: String = ""
static var pending_character: String = ""
static var pending_seed: int = -1
## A line for the title screen's hint after an involuntary trip back to it
## (LAN: "Disconnected: ..."); shown once, then cleared.
static var pending_notice: String = ""

# --- Listing ---

static func _names_in(dir: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(f.trim_suffix(ext))
	out.sort()
	return out

static func world_names() -> Array:
	return _names_in(WORLD_DIR, WORLD_EXT)

static func character_names() -> Array:
	return _names_in(CHAR_DIR, CHAR_EXT)

static func delete_world(world_name: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(WORLD_DIR + world_name + WORLD_EXT))

static func delete_character(char_name: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CHAR_DIR + char_name + CHAR_EXT))

# --- World ---

static func save_world(world_name: String, seed_value: int) -> void:
	var data := world_payload(world_name, seed_value)
	DirAccess.make_dir_recursive_absolute(WORLD_DIR)
	var f := FileAccess.open(WORLD_DIR + world_name + WORLD_EXT, FileAccess.WRITE)
	f.store_var(data)
	f.close()

## The world-save dictionary: one builder for the disk file and the LAN join
## snapshot (MultiplayerImpl §3 - `Net/Snapshot` var_to_bytes this and streams
## it in chunks, and the client boots from it through city._boot_loaded like a
## disk load).
static func world_payload(world_name: String, seed_value: int) -> Dictionary:
	var g: WorldGrid = World.grid
	# Object records, compact: an id table, four ints per record (id index,
	# x, y, flag bits) and a sparse dict of the rare fields (doorway links,
	# button targets, growth clocks, pump outlets, non-empty storage).
	var id_table: Array = []
	var id_index := {}
	var cells := PackedInt32Array()
	var extra := {}
	var i := 0
	for rec: Dictionary in World.object_records:
		if rec.node != null and is_instance_valid(rec.node):
			World.sync_record(rec, rec.node) # bank live node state first
		if not id_index.has(rec.id):
			id_index[rec.id] = id_table.size()
			id_table.append(rec.id)
		var flags := 0
		if rec.placed:
			flags |= OBJ_PLACED
		if rec.open:
			flags |= OBJ_OPEN
		if rec.powered:
			flags |= OBJ_POWERED
		if rec.get("unlocked", false):
			flags |= OBJ_UNLOCKED
		cells.append(int(id_index[rec.id]))
		cells.append(rec.cell.x)
		cells.append(rec.cell.y)
		cells.append(flags)
		var ex := {}
		if rec.has("link"): # interior doorway twin
			ex["link"] = rec.link
		if rec.has("door"): # release button -> barred door cell
			ex["door"] = rec.door
		if rec.has("grow_day"): # tree growth clock
			ex["grow_day"] = rec.grow_day
		if rec.outlet != WorldObject.NO_OUTLET:
			ex["outlet"] = rec.outlet
		if rec.storage != null:
			var any := false
			for s in rec.storage.slots:
				if s != null:
					any = true
					break
			if any:
				ex["storage"] = rec.storage.slots.duplicate(true)
		if not ex.is_empty():
			extra[i] = ex
		i += 1
	var items: Array = []
	var packs: Array = []
	for it in World.items_root.get_children():
		if it is WorldItem and not it.is_queued_for_deletion():
			items.append({"id": it.id, "count": it.count, "pos": it.global_position})
		elif it is Backpack and not it.is_queued_for_deletion():
			packs.append({"pos": it.global_position, "slots": it.slots.duplicate(true)})
	# Enemies (M4): live positions/hp are already banked on the records.
	# Night floaters are skipped — they disperse at dawn anyway (GD-29).
	var enemies: Array = []
	for rec: Dictionary in World.enemy_records:
		if rec.get("night", false):
			continue
		var st := {"type": rec.type, "pos": rec.pos, "hp": rec.hp, "mult": rec.get("mult", 1.0)}
		if rec.has("stock"):
			st["stock"] = rec.stock
		enemies.append(st)
	var data := {
		"version": WORLD_VERSION, "name": world_name, "seed": seed_value,
		"waterline_row": World.waterline_row, "time_of_day": World.time_of_day,
		"bounds": g.bounds, "spawn": World.spawn_position,
		"structure": g.structure.compress(FileAccess.COMPRESSION_ZSTD),
		"back": g.back.compress(FileAccess.COMPRESSION_ZSTD),
		"climb": g.climb.compress(FileAccess.COMPRESSION_ZSTD),
		"water": World.water_sim.levels.compress(FileAccess.COMPRESSION_ZSTD),
		"placed_blocks": World.placed_blocks.duplicate(true),
		"structure_damage": World.structure_damage.duplicate(),
		"object_ids": id_table, "object_cells": cells, "object_extra": extra,
		"items": items, "backpacks": packs, "enemies": enemies,
		"day_count": World.day_count, "next_red_moon_day": World.next_red_moon_day,
		"red_moon_active": World.red_moon_active,
		"city_w": World.city_bounds.size.x, "pockets": World.pockets.duplicate(true),
		"towers": World.towers.duplicate(true),
		"map": World.map_reveal.to_bytes(), # shared fog-of-war map (2026-09-06)
	}
	return data

static func read_world(world_name: String) -> Dictionary:
	var f := FileAccess.open(WORLD_DIR + world_name + WORLD_EXT, FileAccess.READ)
	if f == null:
		return {}
	var data = f.get_var()
	f.close()
	return data if data is Dictionary and int(data.get("version", 0)) == WORLD_VERSION else {}

## True when a save file exists but was written by an older, incompatible build
## (the title picker greys those out instead of loading half a world).
static func world_is_stale(world_name: String) -> bool:
	return FileAccess.file_exists(WORLD_DIR + world_name + WORLD_EXT) and read_world(world_name).is_empty()

static func character_is_stale(char_name: String) -> bool:
	return FileAccess.file_exists(CHAR_DIR + char_name + CHAR_EXT) and read_character(char_name).is_empty()

## Every saved world / character the current build refuses (older formats).
static func stale_saves() -> Dictionary:
	var out := {"worlds": [], "chars": []}
	for w in world_names():
		if world_is_stale(w):
			out.worlds.append(w)
	for c in character_names():
		if character_is_stale(c):
			out.chars.append(c)
	return out

## Delete every old-format save file (title screen "Clear old saves", 2026-09-05).
static func delete_stale_saves() -> int:
	var st := stale_saves()
	for w in st.worlds:
		delete_world(w)
	for c in st.chars:
		delete_character(c)
	return st.worlds.size() + st.chars.size()

## Rebuild a WorldGrid from a world-save dict.
static func build_grid(data: Dictionary) -> WorldGrid:
	var b: Rect2i = data.bounds
	var g := WorldGrid.new(b)
	var n: int = b.size.x * b.size.y
	g.structure = (data.structure as PackedByteArray).decompress(n, FileAccess.COMPRESSION_ZSTD)
	g.back = (data.back as PackedByteArray).decompress(n, FileAccess.COMPRESSION_ZSTD)
	g.climb = (data.climb as PackedByteArray).decompress(n, FileAccess.COMPRESSION_ZSTD)
	return g

# --- Character ---

## The per-character fields that are world-independent: what the file carries
## besides maps/positions/spawns, and what the LAN host replicates to the
## owning client (Net/CharSync, MultiplayerImpl §7).
static func character_state(player) -> Dictionary:
	return {
		"inventory": player.inventory.slots.duplicate(true),
		"equipment": player.equipment.duplicate(true),
		"skills": {"xp": player.skills.xp.duplicate(), "spent": player.skills.spent_points,
			"abilities": player.skills.abilities.duplicate()},
		"known_recipes": player.known_recipes.duplicate(),
		"mod_library": player.mod_library.duplicate(),
		"health": player.health,
		"oxygen": player.oxygen,
		"selected_slot": player.selected_slot,
		"bare_hands": player.bare_hands,
		"compact": player.compact,
	}

static func save_character(char_name: String, player, world_key: String) -> void:
	var data := read_character(char_name)
	if data.is_empty():
		data = {"version": VERSION, "name": char_name, "maps": {}, "positions": {}, "spawns": {}}
	data.merge(character_state(player), true)
	# The map is shared and lives in the world save since 2026-09-06; a
	# character file keeps no copy any more (an old one is merged on load).
	if data.has("maps") and (data.maps as Dictionary).has(world_key):
		(data.maps as Dictionary).erase(world_key)
	data.positions[world_key] = player.global_position
	if not data.has("spawns"):
		data["spawns"] = {}
	if player.spawn_feet != Vector2.INF: # this character's bed in this world (GL-23)
		data.spawns[world_key] = player.spawn_feet
	else:
		data.spawns.erase(world_key)
	DirAccess.make_dir_recursive_absolute(CHAR_DIR)
	var f := FileAccess.open(CHAR_DIR + char_name + CHAR_EXT, FileAccess.WRITE)
	f.store_var(data)
	f.close()

## A library dict with only known modifier ids and positive int counts.
static func clean_library(raw) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for id in raw:
			if Data.modifier_defs.has(String(id)) and int(raw[id]) > 0:
				out[String(id)] = int(raw[id])
	return out

static func read_character(char_name: String) -> Dictionary:
	var f := FileAccess.open(CHAR_DIR + char_name + CHAR_EXT, FileAccess.READ)
	if f == null:
		return {}
	var data = f.get_var()
	f.close()
	return data if data is Dictionary and int(data.get("version", 0)) == VERSION else {}

## Apply a character-save dict to a live player (inventory, skills, vitals,
## and — when this world was visited before — map reveal and position).
static func apply_character(data: Dictionary, player, world_key: String) -> void:
	if data.is_empty():
		return
	# D3: unknown modifier ids (the pre-2026-09-05 sharp/of_the_deep set, or
	# `power` instances) are stripped, not refused — the piece loads clean.
	var inv: Array = (data.inventory as Array).duplicate(true)
	for i in inv.size():
		inv[i] = ItemMods.clean_stack(inv[i])
	player.inventory.slots = inv
	player.inventory.slots.resize(Constants.INVENTORY_SLOTS)
	player.inventory.changed.emit()
	for slot_name in player.equipment.keys():
		player.set_equipment(slot_name, ItemMods.clean_stack((data.equipment as Dictionary).get(slot_name)))
	player.skills.xp = (data.skills.xp as Dictionary).duplicate()
	player.skills.spent_points = int(data.skills.spent)
	player.skills.abilities = (data.skills.get("abilities", {}) as Dictionary).duplicate()
	player.known_recipes = (data.get("known_recipes", {}) as Dictionary).duplicate()
	player.mod_library = clean_library(data.get("mod_library", {})) # legacy `known_mods` is ignored
	player.health = float(data.health)
	player.oxygen = float(data.oxygen)
	player.selected_slot = int(data.selected_slot)
	player.bare_hands = bool(data.get("bare_hands", false))
	if (data.get("maps", {}) as Dictionary).has(world_key): # legacy per-character map: fold it into the shared one
		World.map_reveal.merge_bytes(data.maps[world_key])
	if data.get("spawns", {}).has(world_key):
		player.spawn_feet = data.spawns[world_key]
	if data.positions.has(world_key):
		player.global_position = data.positions[world_key]
		player.velocity = Vector2.ZERO
		if bool(data.get("compact", false)):
			player.begin_loaded_crawl()
		player.unstick()
		player.reset_physics_interpolation()
