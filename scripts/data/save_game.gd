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
const VERSION := 1

## Handoff into the city scene's next boot (set by the title screen or the
## quick-load key before a scene change/reload).
static var pending_world: String = ""
static var pending_character: String = ""
static var pending_seed: int = -1

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
	var g: WorldGrid = World.grid
	var objs: Array = []
	for rec: Dictionary in World.object_records:
		if rec.node != null and is_instance_valid(rec.node):
			World.sync_record(rec, rec.node) # bank live node state first
		var st := {"id": rec.id, "cell": rec.cell, "placed": rec.placed,
			"open": rec.open, "powered": rec.powered, "unlocked": rec.get("unlocked", false),
			"outlet": rec.outlet}
		if rec.has("link"): # interior doorway twin
			st["link"] = rec.link
		if rec.storage != null:
			st["storage"] = rec.storage.slots.duplicate(true)
		objs.append(st)
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
		"version": VERSION, "name": world_name, "seed": seed_value,
		"waterline_row": World.waterline_row, "time_of_day": World.time_of_day,
		"bounds": g.bounds, "spawn": World.spawn_position,
		"structure": g.structure.compress(FileAccess.COMPRESSION_ZSTD),
		"back": g.back.compress(FileAccess.COMPRESSION_ZSTD),
		"climb": g.climb.compress(FileAccess.COMPRESSION_ZSTD),
		"water": World.water_sim.levels.compress(FileAccess.COMPRESSION_ZSTD),
		"placed_blocks": World.placed_blocks.duplicate(true),
		"structure_damage": World.structure_damage.duplicate(),
		"objects": objs, "items": items, "backpacks": packs, "enemies": enemies,
		"day_count": World.day_count, "next_red_moon_day": World.next_red_moon_day,
		"red_moon_active": World.red_moon_active,
		"city_w": World.city_bounds.size.x, "pockets": World.pockets.duplicate(true),
	}
	DirAccess.make_dir_recursive_absolute(WORLD_DIR)
	var f := FileAccess.open(WORLD_DIR + world_name + WORLD_EXT, FileAccess.WRITE)
	f.store_var(data)
	f.close()

static func read_world(world_name: String) -> Dictionary:
	var f := FileAccess.open(WORLD_DIR + world_name + WORLD_EXT, FileAccess.READ)
	if f == null:
		return {}
	var data = f.get_var()
	f.close()
	return data if data is Dictionary else {}

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

static func save_character(char_name: String, player, world_key: String) -> void:
	var data := read_character(char_name)
	if data.is_empty():
		data = {"version": VERSION, "name": char_name, "maps": {}, "positions": {}}
	data["inventory"] = player.inventory.slots.duplicate(true)
	data["equipment"] = player.equipment.duplicate(true)
	data["skills"] = {"xp": player.skills.xp.duplicate(), "spent": player.skills.spent_points,
		"abilities": player.skills.abilities.duplicate()}
	data["known_recipes"] = player.known_recipes.duplicate()
	data["known_mods"] = player.known_mods.duplicate()
	data["health"] = player.health
	data["oxygen"] = player.oxygen
	data["selected_slot"] = player.selected_slot
	data["compact"] = player.compact
	data.maps[world_key] = World.map_reveal.to_bytes()
	data.positions[world_key] = player.global_position
	DirAccess.make_dir_recursive_absolute(CHAR_DIR)
	var f := FileAccess.open(CHAR_DIR + char_name + CHAR_EXT, FileAccess.WRITE)
	f.store_var(data)
	f.close()

static func read_character(char_name: String) -> Dictionary:
	var f := FileAccess.open(CHAR_DIR + char_name + CHAR_EXT, FileAccess.READ)
	if f == null:
		return {}
	var data = f.get_var()
	f.close()
	return data if data is Dictionary else {}

## Apply a character-save dict to a live player (inventory, skills, vitals,
## and — when this world was visited before — map reveal and position).
static func apply_character(data: Dictionary, player, world_key: String) -> void:
	if data.is_empty():
		return
	player.inventory.slots = (data.inventory as Array).duplicate(true)
	player.inventory.slots.resize(Constants.INVENTORY_SLOTS)
	player.inventory.changed.emit()
	for slot_name in player.equipment.keys():
		player.set_equipment(slot_name, data.equipment.get(slot_name))
	player.skills.xp = (data.skills.xp as Dictionary).duplicate()
	player.skills.spent_points = int(data.skills.spent)
	player.skills.abilities = (data.skills.get("abilities", {}) as Dictionary).duplicate()
	player.known_recipes = (data.get("known_recipes", {}) as Dictionary).duplicate()
	player.known_mods = (data.get("known_mods", {}) as Dictionary).duplicate()
	player.health = float(data.health)
	player.oxygen = float(data.oxygen)
	player.selected_slot = int(data.selected_slot)
	if data.maps.has(world_key):
		World.map_reveal.from_bytes(data.maps[world_key])
	if data.positions.has(world_key):
		player.global_position = data.positions[world_key]
		player.velocity = Vector2.ZERO
		if bool(data.get("compact", false)):
			player.begin_loaded_crawl()
		player.unstick()
