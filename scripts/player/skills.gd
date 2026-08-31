class_name Skills
extends RefCounted
## Learn-by-doing skills (CC-18). XP per skill -> integer level; player level
## = total skill levels / 5; each player level banks one point for the
## ability tech tree (data/abilities.json): points buy capabilities, never
## skill levels. The skill set is finalized for MVP: Scrapping (gates
## harvesting by material tier, GL-28), Swimming, Building.

signal leveled(skill: String, level: int)
signal ability_unlocked(id: String)

const START_SET := ["scrapping", "swimming", "building"]

var xp: Dictionary = {}
var spent_points: int = 0
var abilities: Dictionary = {} # ability id -> true (CC-18 tech tree)

func _init() -> void:
	for s in START_SET:
		xp[s] = 0.0

func level(skill: String) -> int:
	return int(floor(xp.get(skill, 0.0) / Constants.SKILL_XP_PER_LEVEL))

func add_xp(skill: String, amount: float) -> void:
	var before := level(skill)
	xp[skill] = xp.get(skill, 0.0) + amount
	var after := level(skill)
	if after > before:
		leveled.emit(skill, after)

func total_levels() -> int:
	var t := 0
	for s in xp.keys():
		t += level(s)
	return t

func player_level() -> int:
	return total_levels() / Constants.SKILL_LEVELS_PER_PLAYER_LEVEL

func available_points() -> int:
	return player_level() - spent_points

# --- Ability tech tree (CC-18) ---

func has_ability(id: String) -> bool:
	return abilities.has(id)

func can_unlock(id: String) -> bool:
	if has_ability(id) or available_points() < 1 or not Data.abilities.has(id):
		return false
	var req: String = Data.abilities[id].get("requires", "")
	return req == "" or has_ability(req)

func unlock(id: String) -> bool:
	if not can_unlock(id):
		return false
	abilities[id] = true
	spent_points += 1
	ability_unlocked.emit(id)
	return true

## Sum of one stat key over owned abilities' effect.stats blocks.
func ability_stat(stat: String) -> float:
	var total := 0.0
	for id in abilities:
		total += float(Data.abilities[id].get("effect", {}).get("stats", {}).get(stat, 0.0))
	return total

## Non-stat effect value (field_yield, o2_drain, reach, ...). Each key is
## defined by at most one ability; returns `fallback` when none is owned.
func effect(key: String, fallback: float) -> float:
	for id in abilities:
		var e: Dictionary = Data.abilities[id].get("effect", {})
		if e.has(key):
			return float(e[key])
	return fallback

func has_effect(key: String, value: String) -> bool:
	for id in abilities:
		if String(Data.abilities[id].get("effect", {}).get(key, "")) == value:
			return true
	return false
