class_name Admin
extends RefCounted
## Admin / QA toggles behind the F4 panel (user request 2026-09-06). Session
## state only - nothing here is saved or replicated. Host/offline only: on a
## LAN client the host simulates the body, so the panel just says so.
##
##   noclip    - fly through everything (Player._admin_fly): move keys, jump
##               = up, crouch = down, sprint doubles the speed
##   no_death  - apply_damage / bleeding / drowning are no-ops, vitals stay full
##   reveal    - the whole city map is revealed and World.visibility_at is
##               always full (fog off); the map bits stay revealed after
##               unticking, only the fog comes back
##   give_resources() - RESOURCE_COUNT of every basic crafting resource
##   to_surface()     - teleport onto the topmost block above the player

static var noclip: bool = false
static var no_death: bool = false
static var reveal: bool = false

## The basic crafting inputs (data/recipes.json ingredients that are
## materials, plus rope): enough for every plain recipe, none of the found
## bench parts or modifier donors.
const RESOURCE_IDS: Array = ["wood", "stone", "scrap_metal", "plastic", "cloth", "iron", "steel", "rope"]
const RESOURCE_COUNT: int = 50

static func available() -> bool:
	return not Net.is_client()

static func any_on() -> bool:
	return noclip or no_death or reveal

static func set_noclip(player, on: bool) -> void:
	noclip = on
	if player == null:
		return
	if on:
		player.velocity = Vector2.ZERO
	else: # hand the body back to the state machine wherever it is
		player.velocity = Vector2.ZERO
		player.state = Player.State.AIRBORNE
		player.fall_start_y = player.global_position.y

static func set_no_death(player, on: bool) -> void:
	no_death = on
	if on and player != null:
		player.health = Constants.MAX_HEALTH
		player.oxygen = player.max_oxygen()
		player.bleed_time = 0.0
		player.drowning = false

static func set_reveal(on: bool) -> void:
	reveal = on
	if on and World.is_ready() and World.map_reveal != null:
		World.map_reveal.reveal_all()

## RESOURCE_COUNT of each basic resource into the bag; returns how many
## stacks actually fit (a full bag takes what it can).
static func give_resources(player) -> int:
	if player == null:
		return 0
	var added := 0
	for id: String in RESOURCE_IDS:
		if not Data.items.has(id):
			continue
		if player.inventory.can_add(id, RESOURCE_COUNT):
			player.inventory.add(id, RESOURCE_COUNT)
			added += 1
	return added

## Teleport onto the topmost solid block in the player's column (the roof
## above, or the ground if the column is open sky). False when nothing is
## solid below the sky in that column.
static func to_surface(player) -> bool:
	if player == null or not World.is_ready():
		return false
	var cell := World.cell_at(player.global_position)
	var top := World.sky_row(cell.x)
	if top >= (1 << 30):
		return false
	var feet := Vector2((cell.x + 0.5) * Constants.BLOCK_SIZE, float(top) * Constants.BLOCK_SIZE)
	player.travel_to(feet)
	return true
