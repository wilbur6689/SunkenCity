extends Node
## Data registry autoload. Loads the JSON definitions under res://data/ at
## startup and exposes them as dictionaries keyed by id. Items are the union
## of items.json, blocks.json (category placeable_block) and objects.json
## (category placeable_object) so one id names both the thing in the world
## and the thing in your bag. Per LT-11 nothing here is per-item code.

const ITEM_ICON_SHEET := "res://assets/sprites/items.png"
const BLOCK_ATLAS := "res://assets/tiles/placeholder_blocks.png"
const OBJECT_SPRITE_DIR := "res://assets/sprites/objects/"
const STATIONS := ["hand", "workbench", "forge", "med_station", "dive_station", "mod_bench"]

var items: Dictionary = {}    # id -> item def
var blocks: Dictionary = {}   # id -> block def
var objects: Dictionary = {}  # id -> object def
var recipes: Dictionary = {}  # id -> recipe def
var recipe_list: Array = []   # ordered as authored

var _icon_cache: Dictionary = {}

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	for it in _load_json("res://data/items.json").get("items", []):
		it["stack"] = it.get("stack", Constants.MATERIAL_STACK if it.get("category") == "material" else 1)
		items[it.id] = it
	for b in _load_json("res://data/blocks.json").get("blocks", []):
		blocks[b.id] = b
		items[b.id] = {
			"id": b.id, "name": b.name, "category": "placeable_block", "weight": b.get("weight", 1.0),
			"stack": Constants.MATERIAL_STACK, "places_block": b.id, "scrap": b.get("scrap", []),
		}
	for o in _load_json("res://data/objects.json").get("objects", []):
		objects[o.id] = o
		if o.get("no_item", false):
			continue # fixed infrastructure (breakers, wired lights) has no item form
		var full_scrap := []
		for y in o.get("yields", []):
			full_scrap.append({"item": y.item, "count": y.max})
		items[o.id] = {
			"id": o.id, "name": o.name, "category": "placeable_object", "weight": o.get("weight", 10.0),
			"stack": 1 if o.kind != "light" and o.kind != "door" else 20, "places_object": o.id, "scrap": full_scrap,
		}
	for r in _load_json("res://data/recipes.json").get("recipes", []):
		recipes[r.id] = r
		recipe_list.append(r)
	_validate()

func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Data: cannot read %s" % path)
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Data: %s is not a JSON object" % path)
		return {}
	return parsed

func _validate() -> void:
	for r in recipe_list:
		assert(r.station in STATIONS, "recipe %s: unknown station %s" % [r.id, r.station])
		assert(items.has(r.output.item), "recipe %s: unknown output %s" % [r.id, r.output.item])
		for inp in r.inputs:
			assert(items.has(inp.item), "recipe %s: unknown input %s" % [r.id, inp.item])
	for o in objects.values():
		for y in o.get("yields", []):
			assert(items.has(y.item), "object %s: unknown yield %s" % [o.id, y.item])
	for it in items.values():
		for s in it.get("scrap", []):
			assert(items.has(s.item), "item %s: unknown scrap %s" % [it.id, s.item])
	print("Data: %d items, %d blocks, %d objects, %d recipes" % [items.size(), blocks.size(), objects.size(), recipe_list.size()])

# --- Accessors ---

func item(id: String) -> Dictionary:
	return items.get(id, {})

func item_name(id: String) -> String:
	return items.get(id, {}).get("name", id)

func stack_size(id: String) -> int:
	return int(items.get(id, {}).get("stack", 1))

func weight(id: String) -> float:
	return float(items.get(id, {}).get("weight", 0.0))

func tool_of(id: String) -> Dictionary:
	return items.get(id, {}).get("tool", {})

func is_tool(id: String, type: String) -> bool:
	return tool_of(id).get("type", "") == type

## Items that hand-scrap into materials at a station (full yield).
func scrap_yield(id: String) -> Array:
	return items.get(id, {}).get("scrap", [])

func recipes_for_station(station: String, known: Callable) -> Array:
	var out := []
	for r in recipe_list:
		if r.station == station and (r.get("known", false) or known.call(r.id)):
			out.append(r)
	return out

# --- Icons ---

func icon(id: String) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id]
	var tex: Texture2D = null
	var it: Dictionary = items.get(id, {})
	if it.has("icon"):
		tex = _atlas(ITEM_ICON_SHEET, Vector2i(it.icon[0], it.icon[1]))
	elif blocks.has(id):
		tex = _atlas(BLOCK_ATLAS, Vector2i(0, blocks[id].atlas_row))
	elif objects.has(id):
		var path := OBJECT_SPRITE_DIR + id + ".png"
		if ResourceLoader.exists(path):
			tex = load(path)
	_icon_cache[id] = tex
	return tex

func _atlas(sheet: String, cell: Vector2i) -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = load(sheet)
	at.region = Rect2(cell.x * Constants.BLOCK_SIZE, cell.y * Constants.BLOCK_SIZE, Constants.BLOCK_SIZE, Constants.BLOCK_SIZE)
	return at
