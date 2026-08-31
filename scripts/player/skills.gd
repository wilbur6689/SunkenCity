class_name Skills
extends RefCounted
## Learn-by-doing skills (CC-18). XP per skill -> integer level; player level
## = total skill levels / 5; each player level banks one ability-tree point
## (tree contents are an M5 design item, so points only accumulate for now).

signal leveled(skill: String, level: int)

const START_SET := ["scrapping", "swimming", "building"]

var xp: Dictionary = {}
var spent_points: int = 0

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
