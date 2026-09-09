extends Node
## Data registry autoload. Loads the JSON definitions under res://data/ at
## startup and exposes them as dictionaries keyed by id. Items are the union
## of items.json, blocks.json (category placeable_block) and objects.json
## (category placeable_object) so one id names both the thing in the world
## and the thing in your bag. Per LT-11 nothing here is per-item code.

const ITEM_ICON_SHEET := "res://assets/sprites/items.png"
const BLOCK_ATLAS := "res://assets/tiles/placeholder_blocks.png" # the 16 px sheet: block ICONS only (world tiles come from StructureRenderer.TILESET)
const ICON_PX := 16 # icon sheets (items.png, the block atlas) are 16 px cells - independent of BLOCK_SIZE since 2026-09-04
const OBJECT_SPRITE_DIR := "res://assets/sprites/objects/"
const ICON_DIR := "res://assets/sprites/icons/" # Icon-Editor overrides (authored_icon)
const STATIONS := ["hand", "workbench", "forge", "med_station", "dive_station", "mod_bench",
	"machine_shop", "steel_works", "pressure_works", "weapon_bench", "pump_works"] # stage benches (docs/CraftingStages.md, 2026-09-06)

var items: Dictionary = {}    # id -> item def
var blocks: Dictionary = {}   # id -> block def
var objects: Dictionary = {}  # id -> object def
var recipes: Dictionary = {}  # id -> recipe def
var recipe_list: Array = []
var loot: Dictionary = {}   # ordered as authored
var modifiers: Dictionary = {}      # raw modifiers.json v2: {families, hybrids, junk} (Modifiers.md)
var modifier_defs: Dictionary = {}  # mod id -> {id, name, slot, tier, family|hybrid, applies, stats, learnable}
var modifier_families: Dictionary = {} # family key -> {slot, applies, label, color, tiers: [ids]} (bench grid order)
var modifier_hybrids: Array = []       # hybrid defs in file order
const MOD_STAT_KEYS := ["tool_damage", "tool_speed", "knockback", "scrap_speed", "defense", "oxygen",
	"swim", "weight_mult", "carry", "cold", "crush", "light", "yield_chance", "reveal"]
const BAND_ORDER := ["dry", "shallows", "cold", "dark", "crush"]
var abilities: Dictionary = {}      # ability id -> def (CC-18 tech tree)
var ability_list: Array = []
var enemies: Dictionary = {}        # enemy type id -> def (M4, GD-01)
var player_anim: Dictionary = {}    # player_anim.json: {cell, clips: {name: {row, frames, fps, loop, hold, anchors}}} - the composed locomotion sheet (2026-09-07)
var hand_anchors: Dictionary = {}   # hand_anchors.json: {east/west: [[x, y] per sheet frame]} - the held weapon's rest pose follows the walk cycle's hand (2026-09-07)
var enemy_bands: Dictionary = {}    # band -> {type id -> {hp, damage, speed, aggro}} (GD-23)
var enemy_seeding: Dictionary = {}  # density tuning (GD-27)

var _icon_cache: Dictionary = {}
var _icon_axis_cache: Dictionary = {} # item id -> icon_axis() result

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	hand_anchors = _load_json("res://data/hand_anchors.json")
	player_anim = _load_json("res://data/player_anim.json")
	for row in ["east", "west"]:
		assert(hand_anchors.get(row, []).size() == 7, "hand_anchors.json: %s needs 7 frames (run tools/gen_hand_anchors.py)" % row)
	for it in _load_json("res://data/items.json").get("items", []):
		it["stack"] = it.get("stack", Constants.MATERIAL_STACK if it.get("category") == "material" else 1)
		items[it.id] = it
	for b in _load_json("res://data/blocks.json").get("blocks", []):
		blocks[b.id] = b
		items[b.id] = {
			"id": b.id, "name": b.name, "category": "placeable_block", "weight": b.get("weight", 1.0),
			"stack": Constants.MATERIAL_STACK, "places_block": b.id, "scrap": b.get("scrap", []),
			"desc": b.get("desc", ""),
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
			"desc": o.get("desc", ""),
		}
	for r in _load_json("res://data/recipes.json").get("recipes", []):
		recipes[r.id] = r
		recipe_list.append(r)
	loot = _load_json("res://data/loot.json")
	modifiers = _load_json("res://data/modifiers.json")
	_load_modifiers()
	for a in _load_json("res://data/abilities.json").get("abilities", []):
		abilities[a.id] = a
		ability_list.append(a)
	var edata := _load_json("res://data/enemies.json")
	for e in edata.get("types", []):
		enemies[e.id] = e
	enemy_bands = edata.get("bands", {})
	enemy_seeding = edata.get("seeding", {})
	_validate()

## modifiers.json v2 -> flat defs. A base tier's stats are tier x the family's
## stats_per_tier unless the tier carries its own `stats`; hybrids and junk
## are authored flat. Bad entries are reported and skipped, never fatal.
func _load_modifiers() -> void:
	modifier_defs.clear()
	modifier_families.clear()
	modifier_hybrids.clear()
	var fams: Dictionary = modifiers.get("families", {})
	for fam in fams:
		var f: Dictionary = fams[fam]
		var slot := String(f.get("slot", ""))
		var tiers: Array = f.get("tiers", [])
		if not slot in ["prefix", "suffix"] or tiers.size() != 5:
			push_error("modifiers: family %s needs slot prefix/suffix and 5 tiers" % fam)
			continue
		var per: Dictionary = f.get("stats_per_tier", {})
		var ids := []
		for i in tiers.size():
			var t: Dictionary = tiers[i]
			var stats := {}
			if t.has("stats"):
				stats = (t.stats as Dictionary).duplicate()
			else:
				for k in per:
					stats[k] = float(per[k]) * float(i + 1)
			var id := String(t.id)
			if modifier_defs.has(id):
				push_error("modifiers: duplicate id %s" % id)
				continue
			modifier_defs[id] = {"id": id, "name": String(t.name), "slot": slot, "tier": i + 1, "family": fam,
				"applies": f.get("applies", []), "stats": stats, "learnable": true}
			ids.append(id)
		modifier_families[fam] = {"slot": slot, "applies": f.get("applies", []), "label": f.get("label", fam.substr(0, 3).to_upper()),
			"color": f.get("color", [0.8, 0.8, 0.8]), "desc": f.get("desc", ""), "tiers": ids}
	for h in modifiers.get("hybrids", []):
		var id := String(h.id)
		if modifier_defs.has(id):
			push_error("modifiers: duplicate id %s" % id)
			continue
		modifier_defs[id] = {"id": id, "name": String(h.name), "slot": String(h.slot), "tier": int(h.tier), "hybrid": true,
			"applies": h.get("applies", []), "stats": (h.get("stats", {}) as Dictionary).duplicate(), "learnable": true,
			"recipe": h.get("recipe", []), "next": h.get("next", "")}
		modifier_hybrids.append(modifier_defs[id])
	for j in modifiers.get("junk", []):
		var id := String(j.id)
		if modifier_defs.has(id):
			push_error("modifiers: duplicate id %s" % id)
			continue
		modifier_defs[id] = {"id": id, "name": String(j.name), "slot": String(j.slot), "tier": 0, "junk": true,
			"applies": j.get("applies", []), "stats": (j.get("stats", {}) as Dictionary).duplicate(), "learnable": false}
	# Validation: recipes exist / same tier / same slot / different families, next exists, stat keys known.
	for h in modifier_hybrids:
		var rec: Array = h.recipe
		var ok := rec.size() == 2 and modifier_defs.has(String(rec[0])) and modifier_defs.has(String(rec[1]))
		if ok:
			var a: Dictionary = modifier_defs[String(rec[0])]
			var b: Dictionary = modifier_defs[String(rec[1])]
			ok = int(a.tier) == int(h.tier) and int(b.tier) == int(h.tier) and a.slot == h.slot and b.slot == h.slot \
				and a.get("family", "a") != b.get("family", "b")
		if not ok:
			push_error("modifiers: hybrid %s has a bad recipe %s" % [h.id, str(rec)])
		if String(h.next) != "" and not modifier_defs.has(String(h.next)):
			push_error("modifiers: hybrid %s: unknown next %s" % [h.id, h.next])
	for id in modifier_defs:
		for k in modifier_defs[id].stats:
			if not k in MOD_STAT_KEYS:
				push_error("modifiers: %s uses unknown stat %s" % [id, k])
	if fams.size() != 6:
		push_error("modifiers: expected 6 families, found %d" % fams.size())

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
	for it in items.values():
		var w: Dictionary = it.get("weapon", {})
		if w.has("ammo"):
			assert(items.has(w.ammo), "weapon %s: unknown ammo %s" % [it.id, w.ammo])
		if w.has("projectile"):
			assert(items.has(w.projectile), "weapon %s: unknown projectile %s" % [it.id, w.projectile])
	for zone in loot.get("tables", {}):
		for band in loot.tables[zone]:
			for e in loot.tables[zone][band]:
				assert(items.has(e.item), "loot %s/%s: unknown item %s" % [zone, band, e.item])
	for a in ability_list:
		var req: String = a.get("requires", "")
		assert(req == "" or abilities.has(req), "ability %s: unknown requirement %s" % [a.id, req])
	for e in enemies.values():
		for drop in e.get("drops", []):
			assert(items.has(drop.item), "enemy %s: unknown drop %s" % [e.id, drop.item])
	for band in enemy_bands:
		for tid in enemy_bands[band]:
			assert(enemies.has(tid), "enemy band %s: unknown type %s" % [band, tid])
	print("Data: %d items, %d blocks, %d objects, %d recipes" % [items.size(), blocks.size(), objects.size(), recipe_list.size()])

# --- Accessors ---

func item(id: String) -> Dictionary:
	return items.get(id, {})

func item_desc(id: String) -> String:
	return items.get(id, {}).get("desc", "")

## Band ids -> the names players know (source lines, hover plates).
const BAND_LABEL := {"roof": "Rooftops", "dry": "The Dry", "shallows": "The Shallows",
	"cold": "The Cold", "dark": "The Dark", "crush": "The Crush"}
const SOURCE_BANDS := ["roof", "dry", "shallows", "cold", "dark", "crush"] # BAND_ORDER + the roof
var _source_cache: Dictionary = {}

## "Where to find it" for a recipe ingredient (user request 2026-09-06): the
## crafting station that makes it, a found part's district + band, which
## furniture scraps into it (by zone), which enemies drop it and which loot
## tables carry it. Short lines, wrapped for the hover plate. Cached.
func source_lines(item_id: String) -> Array:
	if _source_cache.has(item_id):
		return _source_cache[item_id]
	var out: Array = []
	for r in recipe_list:
		if String(r.output.item) == item_id:
			var st: String = "by hand" if r.station == "hand" else String(objects.get(r.station, {}).get("name", String(r.station)))
			out.append("Craft: %s (tier %d)" % [st, int(r.get("tier", 1))])
	var odef: Dictionary = objects.get(item_id, {})
	if odef.get("part", false):
		var zones: Array = odef.get("zones", [])
		var zone_caps: Array = []
		for z in zones:
			zone_caps.append(String(z).capitalize())
		var where: String = " / ".join(zone_caps) if not zone_caps.is_empty() else "any"
		out.append("Found: %s district towers" % where)
		out.append("Floors: %s (a few per world)" % BAND_LABEL.get(odef.get("band", ""), "any band"))
		var bench: String = String(objects.get(odef.get("needed_for", ""), {}).get("name", String(odef.get("needed_for", ""))))
		if bench != "":
			out.append("Carry it home: it builds the %s" % bench)
	if item_id in Constants.GARBAGE_DROPS:
		out.append("Dig: garbage heaps between towers (hammer)")
	# Scrap sources by zone (trees are their own line).
	var by_zone: Dictionary = {} # zone -> [names]
	var trees := false
	for oid in objects:
		var d: Dictionary = objects[oid]
		if d.get("kind", "") != "scrap" or d.get("part", false):
			continue
		var gives := false
		for y in d.get("yields", []):
			if String(y.item) == item_id and float(y.get("max", 0)) > 0.0:
				gives = true
				break
		if not gives:
			continue
		if d.get("category", "") == "flora" and d.get("requires_tool", "") == "axe":
			trees = true # grown trees of every district
			continue
		for z in d.get("zones", ["any"]):
			if not by_zone.has(z):
				by_zone[z] = []
			(by_zone[z] as Array).append(String(d.get("name", oid)))
	if trees:
		out.append("Harvest: rooftop trees (axe)")
	var zone_names: Array = by_zone.keys()
	zone_names.sort()
	for z in zone_names:
		var names: Array = by_zone[z]
		var sample: Array = names.slice(0, 3)
		var more: String = " +%d more" % (names.size() - sample.size()) if names.size() > sample.size() else ""
		out.append("Scrap (%s): %s%s" % [String(z).capitalize(), ", ".join(sample), more])
	# Enemy drops.
	var droppers: Array = []
	var drop_bands: Dictionary = {}
	for tid in enemies:
		for dr in enemies[tid].get("drops", []):
			if String(dr.item) == item_id:
				droppers.append(String(enemies[tid].get("name", tid)))
				for b in SOURCE_BANDS:
					if (enemy_bands.get(b, {}) as Dictionary).has(tid):
						drop_bands[b] = true
				break
	if not droppers.is_empty():
		var sample: Array = droppers.slice(0, 3)
		var more: String = " +%d more" % (droppers.size() - sample.size()) if droppers.size() > sample.size() else ""
		var bands: Array = []
		for b in SOURCE_BANDS:
			if drop_bands.has(b):
				bands.append(BAND_LABEL[b])
		out.append("Drops: %s%s" % [", ".join(sample), more])
		if not bands.is_empty():
			out.append("  in %s" % ", ".join(bands))
	# Loot tables (district x band).
	var loot_d: Dictionary = {}
	var loot_b: Dictionary = {}
	var tables: Dictionary = loot.get("tables", loot)
	for dist in tables:
		if not (tables[dist] is Dictionary):
			continue
		for b in tables[dist]:
			for e in tables[dist][b]:
				if e is Dictionary and String(e.get("item", "")) == item_id:
					loot_d[dist] = true
					loot_b[b] = true
	if not loot_d.is_empty():
		var ds: Array = []
		for k in loot_d:
			ds.append(String(k).capitalize())
		var bs: Array = []
		for b in SOURCE_BANDS:
			if loot_b.has(b):
				bs.append(BAND_LABEL[b])
		out.append("Loot: containers in %s" % ", ".join(ds))
		if not bs.is_empty():
			out.append("  on %s floors" % ", ".join(bs))
	if out.is_empty():
		out.append("No known source yet")
	var wrapped: Array = []
	for line in out:
		wrapped.append_array(_wrap(String(line), 46))
	_source_cache[item_id] = wrapped
	return wrapped

static func _wrap(text: String, width: int) -> Array:
	var lines: Array = []
	var cur := ""
	for word in text.split(" "):
		if cur != "" and cur.length() + 1 + word.length() > width:
			lines.append(cur)
			cur = "    " + word
		else:
			cur = word if cur == "" else cur + " " + word
	if cur != "":
		lines.append(cur)
	return lines

func item_name(id: String) -> String:
	return items.get(id, {}).get("name", id)

func stack_size(id: String) -> int:
	return int(items.get(id, {}).get("stack", 1))

func weight(id: String) -> float:
	return float(items.get(id, {}).get("weight", 0.0))

## Per-band authored stats for an enemy type (GD-23). Bands an enemy has no
## row for fall back toward the surface, so a red-moon walker spawned on a
## dry rooftop and a straggler wandering deep both resolve to something.
func enemy_stats(type_id: String, band: String) -> Dictionary:
	# T0 "roof" (2026-09-06) is its own row; a type without one (a red-moon
	# walker landing on a roof) uses its Dry stats.
	if band == "roof" and not (enemy_bands.get("roof", {}) as Dictionary).has(type_id):
		band = "dry"
	var order := ["roof", "dry", "shallows", "cold", "dark", "crush"]
	var i := order.find(band)
	if i < 0:
		i = 1
	while i >= 0:
		var row: Dictionary = enemy_bands.get(order[i], {})
		if row.has(type_id):
			return row[type_id]
		i -= 1
	for b in order: # deeper-only types (the Drowned) queried above their range
		if enemy_bands.get(b, {}).has(type_id):
			return enemy_bands[b][type_id]
	return {}

func tool_of(id: String) -> Dictionary:
	return items.get(id, {}).get("tool", {})

func is_tool(id: String, type: String) -> bool:
	return tool_of(id).get("type", "") == type

## Items that hand-scrap into materials at a station (full yield).
func scrap_yield(id: String) -> Array:
	return items.get(id, {}).get("scrap", [])

## Which stage's scrap bench handles an item (user request 2026-09-02): the
## HIGHEST material tier it yields. 1 wood/plastic/cloth · 2 scrap_metal/stone ·
## 3 iron · 4 steel. 0 = not scrappable furniture. The Master bench (stage 5)
## takes any stage >= 1.
const MATERIAL_STAGE := {
	"cloth": 1, "plastic": 1, "wood": 1, "stone": 2, "scrap_metal": 2, "iron": 3, "steel": 4,
}
func item_scrap_stage(id: String) -> int:
	var yields: Array = scrap_yield(id)
	if yields.is_empty():
		return 0
	var stage := 0
	for y in yields:
		stage = maxi(stage, int(MATERIAL_STAGE.get(y.item, 1)))
	return stage

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
	# A file in the icons dir IS the icon (blocks included - rope has no
	# items.json entry to carry the authored_icon flag, 2026-09-01).
	var path := ICON_DIR + id + ".png"
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		# Icon-Editor-authored icons load RAW from disk (the import cache is
		# stale after an in-game save; same rule as authored sprites) - in
		# an EXPORTED build only the imported texture exists.
		tex = load_texture_fresh(path)
	if tex != null:
		pass
	elif it.has("icon"):
		tex = _atlas(ITEM_ICON_SHEET, Vector2i(it.icon[0], it.icon[1]))
	elif blocks.has(id):
		tex = _atlas(BLOCK_ATLAS, Vector2i(0, blocks[id].atlas_row))
	elif objects.has(id):
		tex = object_texture(id)
	_icon_cache[id] = tex
	return tex

## Held-tool geometry (weapon swing, 2026-09-07): the icon's long axis from
## its grip (the end nearest the icon's bottom - every tool and blade is
## drawn hilt-down) to its tip, in texture px from the texture centre. The
## paper-doll hand holds a weapon by this grip and points the blade along an
## authored angle, so a vertical 32 px sword and a diagonal 16 px machete
## swing the same way. `angle` is the unflipped texture axis (screen radians,
## up = -PI/2), `length` the grip-to-tip distance in texture px.
func icon_axis(id: String) -> Dictionary:
	if _icon_axis_cache.has(id):
		return _icon_axis_cache[id]
	var res := {"angle": -PI * 0.5, "hilt": Vector2(0.0, 8.0), "tip": Vector2(0.0, -8.0), "length": 16.0}
	var tex := icon(id)
	var img: Image = null
	if tex is AtlasTexture:
		var full: Image = (tex as AtlasTexture).atlas.get_image()
		if full != null:
			img = full.get_region(Rect2i((tex as AtlasTexture).region))
	elif tex != null:
		img = tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		var pts: PackedVector2Array = []
		for y in h:
			for x in w:
				if img.get_pixel(x, y).a > 0.5:
					pts.append(Vector2(x + 0.5, y + 0.5))
		if pts.size() >= 2:
			var mean := Vector2.ZERO
			for p in pts:
				mean += p
			mean /= pts.size()
			var cxx := 0.0
			var cyy := 0.0
			var cxy := 0.0
			for p in pts:
				var d := p - mean
				cxx += d.x * d.x
				cyy += d.y * d.y
				cxy += d.x * d.y
			var theta := 0.5 * atan2(2.0 * cxy, cxx - cyy) # principal axis
			var axis := Vector2(cos(theta), sin(theta))
			if axis.y > 0.0 or (absf(axis.y) < 0.01 and axis.x < 0.0):
				axis = -axis # point it up: the grip is the bottom end
			var lo := INF
			var hi := -INF
			for p in pts:
				var t := (p - mean).dot(axis)
				lo = minf(lo, t)
				hi = maxf(hi, t)
			var centre := Vector2(w, h) * 0.5
			res.angle = axis.angle()
			res.hilt = mean - centre + axis * lo
			res.tip = mean - centre + axis * hi
			res.length = hi - lo
	_icon_axis_cache[id] = res
	return res

## An object's sprite: a region of its pack's sprite sheet when it has one,
## otherwise its standalone PNG.
func object_texture(id: String) -> Texture2D:
	var tex := object_strip_texture(id)
	var n := strip_frames(id)
	if tex != null and n > 1: # a sway strip: icons / editors / cards want the rest frame
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 0, tex.get_width() / n, tex.get_height())
		return at
	return tex

## How many sway frames an object's sprite holds: its PNG width over the
## def's size in px (frames are laid out horizontally; a plain sprite is 1).
## Flora strips come from tools/build_flora.py (docs/Flora/flora.md 5).
func strip_frames(id: String) -> int:
	var def: Dictionary = objects.get(id, {})
	if def.is_empty() or def.has("sheet") or not def.has("size"):
		return 1
	if _strip_frames_cache.has(id):
		return _strip_frames_cache[id]
	var n := 1
	var tex := object_strip_texture(id)
	var fw := int(def.size[0]) * Constants.BLOCK_SIZE
	if tex != null and fw > 0 and tex.get_width() > fw and tex.get_width() % fw == 0:
		n = tex.get_width() / fw
	_strip_frames_cache[id] = n
	return n

var _strip_frames_cache: Dictionary = {}

## The whole sprite PNG (every frame) - WorldObject sets hframes from it.
func object_strip_texture(id: String) -> Texture2D:
	var def: Dictionary = objects.get(id, {})
	if def.has("sheet"):
		var at := AtlasTexture.new()
		at.atlas = load(def.sheet)
		var r: Array = def.rect
		at.region = Rect2(r[0], r[1], r[2], r[3])
		return at
	var path := OBJECT_SPRITE_DIR + id + ".png"
	# Editor-authored sprites (Flora/Furniture Editor saves) load RAW from
	# disk, never through the import cache: a plain game run does not
	# re-import a changed PNG, so the cache serves stale art after an
	# in-game save (user report 2026-09-01 - "old tree variations").
	if def.get("authored", false):
		return load_texture_fresh(path)
	return load_texture_fresh(path, false)

## A texture that may have been rewritten on disk by an in-game editor
## (icons, authored sprites, enemy strips). A dev run (editor binary: `godot
## --path .` or the editor itself) reads the PNG RAW when `prefer_raw`, since
## the import cache is stale after an in-game save; an EXPORTED build has no
## loose PNGs - only the imported texture - so it always goes through
## load() (user report 2026-09-06: every material icon was a placeholder
## blob on the exported client build). Null when neither exists.
static func load_texture_fresh(path: String, prefer_raw: bool = true) -> Texture2D:
	var on_disk := FileAccess.file_exists(path)
	if prefer_raw and on_disk and OS.has_feature("editor"):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		return load(path)
	if on_disk: # a file with no .import yet (saved by an editor this run)
		var raw := Image.load_from_file(ProjectSettings.globalize_path(path))
		if raw != null:
			return ImageTexture.create_from_image(raw)
	return null

func _atlas(sheet: String, cell: Vector2i) -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = load(sheet)
	at.region = Rect2(cell.x * ICON_PX, cell.y * ICON_PX, ICON_PX, ICON_PX)
	return at
