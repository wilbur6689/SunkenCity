class_name ItemMods
extends RefCounted
## Gear modifiers v2 (Modifiers.md / ModifiersImpl.md, 2026-09-05): static
## helpers over data/modifiers.json. A modded stack carries
## {"mods": {"prefix": {"id"}, "suffix": {"id"}}} beside id/count — the tier
## lives in the def (a modifier IS its district family × depth band), so
## instances carry no power. Found gear rolls here (LootGen) from WHERE it
## sits: family = the tower's district, tier = the floor's band. Crafted gear
## is clean and takes library mods at the Modification Bench; library entries
## are stock (consumed by APPLY and COMBINE), never permanent unlocks.

const MAX_TIER := 5
const ROLL_MOD_CHANCE := 0.6    # a found gear piece is modded (D5: every found piece is bench stock)
const JUNK_CHANCE := 0.08       # ...or, on a tool/weapon, carries an unlearnable junk prefix
const TIER_OF_BAND := {"dry": 1, "shallows": 2, "cold": 3, "dark": 4, "crush": 5}

## D2: colour = the highest tier on the piece, bucketed; both slots at T5 = gold.
const RARITY_COLORS := {
	"common": Color(0.72, 0.74, 0.78),     # gray   — no mods
	"uncommon": Color(0.55, 0.9, 0.55),    # green  — T1–T2
	"rare": Color(0.5, 0.72, 1.0),         # blue   — T3–T4
	"epic": Color(0.78, 0.55, 0.95),       # purple — T5
	"legendary": Color(1.0, 0.82, 0.35),   # gold   — both slots at T5
}

## What a mod can roll onto: "tool" (tool block), "weapon" (weapon block),
## "gear" (equip slot). "" = not moddable (materials, schematics, placeables).
static func mod_class(id: String) -> String:
	var it := Data.item(id)
	if it.has("tool"):
		return "tool"
	if it.has("weapon"):
		return "weapon"
	if it.get("slot", "") != "":
		return "gear"
	return ""

static func def_of(mod_id: String) -> Dictionary:
	return Data.modifier_defs.get(mod_id, {})

static func slot_of(mod_id: String) -> String:
	return String(def_of(mod_id).get("slot", ""))

static func tier_of(mod_id: String) -> int:
	return int(def_of(mod_id).get("tier", 0))

## The district family of a base mod ("" for hybrids and junk).
static func family_of(mod_id: String) -> String:
	return String(def_of(mod_id).get("family", ""))

static func is_hybrid(mod_id: String) -> bool:
	return bool(def_of(mod_id).get("hybrid", false))

static func applies_to(mod_id: String, cls: String) -> bool:
	return (def_of(mod_id).get("applies", []) as Array).has(cls)

## The base modifier for a district at a tier, or "" (unknown district).
static func base_id(district: String, tier: int) -> String:
	var fam: Dictionary = Data.modifier_families.get(district, {})
	var tiers: Array = fam.get("tiers", [])
	tier = clampi(tier, 1, MAX_TIER)
	return String(tiers[tier - 1]) if tiers.size() >= tier else ""

## Loot-time roll: a found piece's modifier is decided by where it sits —
## `district` is the tower's district (family), `band` the floor's band
## (tier). Randomness only in WHETHER it rolls. Returns {} (clean) or the
## mods dict for the stack. A family whose slot cannot apply to the item's
## class (a prefix district on a suit) leaves the piece clean.
static func roll(rng: RandomNumberGenerator, id: String, district: String = "", band: String = "dry") -> Dictionary:
	var cls := mod_class(id)
	if cls == "":
		return {}
	var r := rng.randf()
	if r >= ROLL_MOD_CHANCE:
		if cls != "gear" and r >= 1.0 - JUNK_CHANCE:
			var junk: Array = Data.modifiers.get("junk", [])
			if not junk.is_empty():
				var j: Dictionary = junk[rng.randi_range(0, junk.size() - 1)]
				if (j.get("applies", []) as Array).has(cls):
					return {String(j.slot): {"id": String(j.id)}}
		return {}
	var mid := base_id(district, int(TIER_OF_BAND.get(band, 1)))
	if mid == "" or not applies_to(mid, cls):
		return {}
	return {slot_of(mid): {"id": mid}}

static func mods_of(stack) -> Dictionary:
	if stack == null or typeof(stack) != TYPE_DICTIONARY:
		return {}
	return stack.get("mods", {})

## Sum of one mod stat across the stack's prefix + suffix (authored per tier).
static func stat(stack, key: String) -> float:
	var total := 0.0
	var mods := mods_of(stack)
	for part in ["prefix", "suffix"]:
		if mods.has(part):
			var m: Dictionary = mods[part]
			total += float(def_of(m.id).get("stats", {}).get(key, 0.0))
	return total

## The item's tool block with prefix bonuses folded in.
static func tool_of(stack) -> Dictionary:
	if stack == null:
		return {}
	var tool: Dictionary = Data.tool_of(stack.id)
	if tool.is_empty() or mods_of(stack).is_empty():
		return tool
	tool = tool.duplicate()
	tool["damage"] = maxf(1.0, float(tool.get("damage", 0)) + stat(stack, "tool_damage"))
	tool["speed"] = maxf(0.3, float(tool.get("speed", 1.0)) * (1.0 + stat(stack, "tool_speed")))
	tool["knockback"] = float(tool.get("knockback", 0.0)) + stat(stack, "knockback")
	return tool

## The item's weapon block with prefix bonuses folded in (damage, speed, knockback).
static func weapon_of(stack) -> Dictionary:
	if stack == null:
		return {}
	var w: Dictionary = Data.item(stack.id).get("weapon", {})
	if w.is_empty() or mods_of(stack).is_empty():
		return w
	w = w.duplicate()
	w["damage"] = maxf(1.0, float(w.get("damage", 0)) + stat(stack, "tool_damage"))
	w["speed"] = maxf(0.2, float(w.get("speed", 1.0)) * (1.0 + stat(stack, "tool_speed")))
	w["knockback"] = float(w.get("knockback", 8.0)) + stat(stack, "knockback")
	return w

## Weight of one unit, with "of the Cellar" style multipliers applied.
static func unit_weight(stack) -> float:
	var w := Data.weight(stack.id)
	var mult := 1.0 + stat(stack, "weight_mult")
	return w * clampf(mult, 0.1, 2.0)

## Highest tier on the piece (0 when clean; junk counts as 0).
static func top_tier(stack) -> int:
	var t := 0
	for part in mods_of(stack).values():
		t = maxi(t, tier_of(String(part.get("id", ""))))
	return t

static func rarity(stack) -> String:
	var mods := mods_of(stack)
	if mods.is_empty():
		return "common"
	var top := top_tier(stack)
	if top >= MAX_TIER and mods.has("prefix") and mods.has("suffix") \
			and tier_of(mods.prefix.id) >= MAX_TIER and tier_of(mods.suffix.id) >= MAX_TIER:
		return "legendary"
	if top >= MAX_TIER:
		return "epic"
	if top >= 3:
		return "rare"
	return "uncommon"

static func rarity_color(stack) -> Color:
	return RARITY_COLORS[rarity(stack)]

## "Forged Cutting Torch of the Ward" (LT-08 title text).
static func display_name(stack) -> String:
	if stack == null:
		return ""
	var name := Data.item_name(stack.id)
	var mods := mods_of(stack)
	if mods.has("prefix"):
		name = String(def_of(mods.prefix.id).get("name", "")) + " " + name
	if mods.has("suffix"):
		name += " " + String(def_of(mods.suffix.id).get("name", ""))
	return name

## One line per mod for tooltips/bench previews.
static func describe(stack) -> Array:
	var out := []
	var mods := mods_of(stack)
	for part in ["prefix", "suffix"]:
		if mods.has(part):
			out.append(describe_mod(mods[part].id))
	return out

const ROMAN := ["", "I", "II", "III", "IV", "V"]

## "Forged III: +3 damage" — tier as a roman numeral, then the stat lines.
static func describe_mod(mod_id: String) -> String:
	var def := def_of(mod_id)
	var bits := []
	for key in def.get("stats", {}):
		bits.append(_stat_text(key, float(def.stats[key])))
	var tier := int(def.get("tier", 0))
	var head := String(def.get("name", mod_id))
	if tier > 0:
		head += " " + ROMAN[clampi(tier, 0, MAX_TIER)]
	return "%s: %s" % [head, ", ".join(bits)]

static func _stat_text(key: String, v: float) -> String:
	match key:
		"tool_damage": return "%+d damage" % roundi(v)
		"tool_speed": return "%+d%% speed" % roundi(v * 100)
		"knockback": return "%+.1f knockback" % v
		"scrap_speed": return "%+d%% scrap speed" % roundi(v * 100)
		"defense": return "%+d defense" % roundi(v)
		"oxygen": return "%+ds air" % roundi(v)
		"swim": return "%+d%% swim" % roundi(v * 100)
		"weight_mult": return "%+d%% weight" % roundi(v * 100)
		"carry": return "%+d carry" % roundi(v)
		"cold": return "%+d cold rating" % roundi(v)
		"crush": return "%+d crush rating" % roundi(v)
		"light": return "%+d light" % roundi(v)
		"yield_chance": return "%+d%% double yield" % roundi(v * 100)
		"reveal": return "%+d map reveal" % roundi(v)
	return "%s %+.2f" % [key, v]

# --- Combining (Modifiers.md "Combining") ---

## The id two library entries combine into, or "" when no recipe fits:
##   same base id, tier < 5          -> that family's next tier (vertical)
##   two same-tier same-slot bases of different families -> the authored hybrid
##   same hybrid id with `next`      -> next
## Order-free; never crosses slots or tiers; tier 5 is the ceiling.
static func combine_result(a: String, b: String) -> String:
	var da := def_of(a)
	var db := def_of(b)
	if da.is_empty() or db.is_empty() or not bool(da.get("learnable", true)) or not bool(db.get("learnable", true)):
		return ""
	if da.slot != db.slot or int(da.tier) != int(db.tier):
		return ""
	if a == b:
		if da.has("family"):
			return base_id(String(da.family), int(da.tier) + 1) if int(da.tier) < MAX_TIER else ""
		return String(da.get("next", ""))
	if da.has("family") and db.has("family") and da.family != db.family:
		for h in Data.modifier_hybrids:
			var r: Array = h.recipe
			if (String(r[0]) == a and String(r[1]) == b) or (String(r[0]) == b and String(r[1]) == a):
				return String(h.id)
	return ""

# --- Save hygiene (D3) ---

## Drops unknown modifier ids and the legacy `power` key from a stack; the
## one cleaner shared by SaveGame, CharSync and the world-record loader.
## Returns the stack (mutated in place) or null when it names no known item.
static func clean_stack(s):
	if not (s is Dictionary) or not s.has("id") or not Data.items.has(String(s.id)):
		return null
	if s.get("mods") is Dictionary:
		var mods := {}
		for part in ["prefix", "suffix"]:
			var m = (s.mods as Dictionary).get(part)
			if m is Dictionary and Data.modifier_defs.has(String(m.get("id", ""))) and slot_of(String(m.id)) == part:
				mods[part] = {"id": String(m.id)}
		if mods.is_empty():
			s.erase("mods")
		else:
			s["mods"] = mods
			s["count"] = 1
	elif s.has("mods"):
		s.erase("mods")
	return s
