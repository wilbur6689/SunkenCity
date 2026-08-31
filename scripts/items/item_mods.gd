class_name ItemMods
extends RefCounted
## Gear modifiers (LT-05..10): static helpers over data/modifiers.json.
## A modded stack carries {"mods": {"prefix": {"id", "power"}, "suffix": {...}}}
## beside id/count; power is 1..MAX_POWER. Rarity (LT-08) is derived from the
## mod state, never rolled. Found gear rolls here (LootGen); crafted gear is
## clean and takes learned mods at the Modification Bench (inventory UI).

const MAX_POWER := 3
const ROLL_MOD_CHANCE := 0.35   # a found gear piece gets at least one mod
const ROLL_BOTH_CHANCE := 0.30  # ...and, if modded, both a prefix and a suffix

const RARITY_COLORS := {
	"common": Color(0.72, 0.74, 0.78),   # gray  — no mods
	"uncommon": Color(0.55, 0.9, 0.55),  # green — one mod
	"rare": Color(0.5, 0.72, 1.0),       # blue  — both
	"epic": Color(0.78, 0.55, 0.95),     # purple — both at top strength
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

static func _pool(list: Array, cls: String) -> Array:
	var out := []
	for m in list:
		if (m.get("applies", []) as Array).has(cls):
			out.append(m)
	return out

## Loot-time roll (LT-10): found gear may come modded. Returns {} (clean) or
## a mods dict for the stack.
static func roll(rng: RandomNumberGenerator, id: String) -> Dictionary:
	var cls := mod_class(id)
	if cls == "" or rng.randf() >= ROLL_MOD_CHANCE:
		return {}
	var prefixes := _pool(Data.modifiers.get("prefixes", []), cls)
	var suffixes := _pool(Data.modifiers.get("suffixes", []), cls)
	var both := rng.randf() < ROLL_BOTH_CHANCE and not prefixes.is_empty() and not suffixes.is_empty()
	var mods := {}
	var want_prefix := both or suffixes.is_empty() or (not prefixes.is_empty() and rng.randf() < 0.5)
	if want_prefix and not prefixes.is_empty():
		var p: Dictionary = prefixes[rng.randi_range(0, prefixes.size() - 1)]
		mods["prefix"] = {"id": p.id, "power": rng.randi_range(1, MAX_POWER)}
	if (both or not mods.has("prefix")) and not suffixes.is_empty():
		var sfx: Dictionary = suffixes[rng.randi_range(0, suffixes.size() - 1)]
		mods["suffix"] = {"id": sfx.id, "power": rng.randi_range(1, MAX_POWER)}
	return mods

static func def_of(mod_id: String) -> Dictionary:
	return Data.modifier_defs.get(mod_id, {})

static func mods_of(stack) -> Dictionary:
	if stack == null or typeof(stack) != TYPE_DICTIONARY:
		return {}
	return stack.get("mods", {})

## Sum of one mod stat across the stack's prefix + suffix, scaled by power.
static func stat(stack, key: String) -> float:
	var total := 0.0
	var mods := mods_of(stack)
	for part in ["prefix", "suffix"]:
		if mods.has(part):
			var m: Dictionary = mods[part]
			total += float(def_of(m.id).get("stats", {}).get(key, 0.0)) * int(m.power)
	return total

## The item's tool block with prefix bonuses folded in (Sharp, Swift...).
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

## Weight of one unit, with "of the Shore" style multipliers applied.
static func unit_weight(stack) -> float:
	var w := Data.weight(stack.id)
	var mult := 1.0 + stat(stack, "weight_mult")
	return w * clampf(mult, 0.1, 2.0)

static func rarity(stack) -> String:
	var mods := mods_of(stack)
	if mods.is_empty():
		return "common"
	if not (mods.has("prefix") and mods.has("suffix")):
		return "uncommon"
	if int(mods.prefix.power) >= MAX_POWER and int(mods.suffix.power) >= MAX_POWER:
		return "epic"
	return "rare"

static func rarity_color(stack) -> Color:
	return RARITY_COLORS[rarity(stack)]

## "Sharp Iron Knife of the Deep" (LT-08 title text).
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

## One line per mod for tooltips/bench previews, e.g. "Sharp III: +3 damage".
static func describe(stack) -> Array:
	var out := []
	var mods := mods_of(stack)
	for part in ["prefix", "suffix"]:
		if mods.has(part):
			out.append(describe_mod(mods[part].id, int(mods[part].power)))
	return out

static func describe_mod(mod_id: String, power: int) -> String:
	var def := def_of(mod_id)
	var bits := []
	for key in def.get("stats", {}):
		var v := float(def.stats[key]) * power
		bits.append(_stat_text(key, v))
	return "%s %s: %s" % [def.get("name", mod_id), "I".repeat(power), ", ".join(bits)]

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
		"cold": return "%+d cold rating" % roundi(v)
		"crush": return "%+d crush rating" % roundi(v)
		"light": return "%+d light" % roundi(v)
		"yield_chance": return "%+d%% double yield" % roundi(v * 100)
		"reveal": return "%+d map reveal" % roundi(v)
	return "%s %+.2f" % [key, v]
