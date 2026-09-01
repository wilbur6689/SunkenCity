class_name Player
extends CharacterBody2D
## Character controller — explicit state machine (WS-19).
## Server-authoritative by design (CC-06): input is read into the
## `input_dir`/`wants_*`/`aim_position` snapshot only by the multiplayer
## authority of this node; states and the Interaction child consume the
## snapshot, never Input directly, so a networked client can later feed the
## same fields remotely. World queries go through the World authority layer.

signal message(text: String)
signal container_opened(obj: WorldObject)
signal crafting_opened(station: String)

enum State { GROUNDED, AIRBORNE, CRAWLING, CLIMBING, SURFACE_SWIM, UNDERWATER }

var state: State = State.AIRBORNE

# --- Input snapshot (separated from state logic for LAN-readiness) ---
var input_dir: Vector2 = Vector2.ZERO
var wants_jump: bool = false # pressed this frame
var wants_sprint: bool = false
var wants_crouch: bool = false
var wants_use: bool = false           # held
var wants_use_secondary: bool = false # held
var wants_interact: bool = false      # pressed this frame
var wants_drop: bool = false          # pressed this frame
var aim_position: Vector2 = Vector2.ZERO
var hotbar_select: int = -1           # -1 = no change this frame

# --- Timers ---
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# --- Vitals (first pass; systems move to components in M1+) ---
var health: float = Constants.MAX_HEALTH
var oxygen: float = Constants.BASE_OXYGEN_SECONDS
var drowning: bool = false
var fall_start_y: float = 0.0
var bleed_time: float = 0.0   # bleeding drips health until bandaged (GD-21)
var combat_timer: float = 999.0 # seconds since last damage; gates regen (GL-21)

# --- Items & progression (M1) ---
var inventory := Inventory.new(Constants.INVENTORY_SLOTS)
var skills := Skills.new()
var known_recipes: Dictionary = {} # recipe id -> true (schematics, GL-06)
var selected_slot: int = 0

# --- Body form ---
var compact: bool = false # crawl/swim hitbox (fits 1-block holes, WS-02)

# --- Environment sense (refreshed each physics tick) ---
var in_water: bool = false     # body center in a water cell
var submerged: bool = false    # head point in a water cell (O2 drains)
var on_climbable: bool = false # body center in a ladder/rope cell
var climbable_below: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D
@onready var interaction: Interaction = $Interaction

var _stand_shape := RectangleShape2D.new()
var _compact_shape := RectangleShape2D.new()

func _ready() -> void:
	_stand_shape.size = Constants.STAND_HITBOX
	_compact_shape.size = Constants.COMPACT_HITBOX
	_set_compact(false)
	if World.is_ready():
		respawn()

## Invisible edge walls (CT-22): the finite city ends past the open-water
## margins — nothing rendered, just a hard clamp at the grid's x extents.
func _clamp_to_world_bounds() -> void:
	if not World.is_ready():
		return
	if World.in_annex(World.cell_at(global_position)):
		return # inside an interior pocket: its VOID shell is the wall
	var b: Rect2i = World.city_bounds
	var half_w := 6.0 # half the standing hitbox
	var min_x := b.position.x * Constants.BLOCK_SIZE + half_w
	var max_x := b.end.x * Constants.BLOCK_SIZE - half_w
	if global_position.x < min_x or global_position.x > max_x:
		global_position.x = clampf(global_position.x, min_x, max_x)
		velocity.x = 0.0

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_read_input()
	_tick_timers(delta)
	_apply_hotbar()
	_sense()
	match state:
		State.GROUNDED:
			_state_grounded(delta)
		State.AIRBORNE:
			_state_airborne(delta)
		State.CRAWLING:
			_state_crawling(delta)
		State.CLIMBING:
			_state_climbing(delta)
		State.SURFACE_SWIM:
			_state_surface_swim(delta)
		State.UNDERWATER:
			_state_underwater(delta)
	move_and_slide()
	_clamp_to_world_bounds()
	_update_sprite(delta)
	_update_swing(delta)
	_update_move_sfx(delta)
	_update_oxygen(delta)
	_update_vitals(delta)
	_update_environment(delta)
	_update_camera(delta)
	interaction.tick(delta)
	if wants_drop: # Q toggles bare hands (user request) — dropping moved to the UI
		bare_hands = not bare_hands
		if bare_hands:
			message.emit("Hands free")
		elif held_item() != "":
			message.emit("Holding " + Data.item_name(held_item()))
	if state == State.SURFACE_SWIM or state == State.UNDERWATER:
		skills.add_xp("swimming", Constants.XP_SWIM_PER_SECOND * delta)
	# one-frame flags
	wants_interact = false
	wants_drop = false
	hotbar_select = -1

# --- Input & timers ---

func _read_input() -> void:
	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	wants_sprint = Input.is_action_pressed("sprint")
	wants_crouch = Input.is_action_pressed("crouch")
	wants_jump = Input.is_action_just_pressed("jump")
	wants_use = Input.is_action_pressed("use") and not ui_blocking()
	wants_use_secondary = Input.is_action_pressed("use_secondary") and not ui_blocking()
	wants_interact = Input.is_action_just_pressed("interact")
	wants_drop = Input.is_action_just_pressed("drop")
	aim_position = get_global_mouse_position()
	for i in Constants.HOTBAR_SLOTS:
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			hotbar_select = i
	# View-only (not part of the replicated snapshot): wheel zoom.
	if Input.is_action_just_pressed("zoom_in"):
		zoom_step(1)
	if Input.is_action_just_pressed("zoom_out"):
		zoom_step(-1)

## True while a UI panel wants the mouse (set by the inventory UI); clicks
## on GUI controls (the hotbar) also stay out of the world.
var ui_blocks_mouse: bool = false
func ui_blocking() -> bool:
	return ui_blocks_mouse or get_viewport().gui_get_hovered_control() != null

## Bare mouse wheel cycles the hotbar while no menu is open (user request);
## Ctrl+wheel stays zoom, and menus consume their own wheel events.
func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or ui_blocks_mouse:
		return
	if event is InputEventMouseButton and event.pressed and not event.ctrl_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected_slot = (selected_slot + 1) % Constants.HOTBAR_SLOTS
			bare_hands = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected_slot = (selected_slot - 1 + Constants.HOTBAR_SLOTS) % Constants.HOTBAR_SLOTS
			bare_hands = false

func _tick_timers(delta: float) -> void:
	if wants_jump:
		jump_buffer_timer = Constants.JUMP_BUFFER_TIME
		wants_jump = false
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

func _apply_hotbar() -> void:
	if hotbar_select >= 0:
		selected_slot = hotbar_select
		bare_hands = false # reselecting a slot takes the item in hand again

func _consume_jump() -> bool:
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = 0.0
		return true
	return false

# --- Items ---

## Empty hands (user request): Q clears the hand — no placing, tools, or
## consumables until Q is pressed again or a hotbar slot is reselected.
var bare_hands: bool = false

func held_item() -> String:
	if bare_hands:
		return ""
	var s = inventory.slots[selected_slot]
	return s.id if s != null else ""

## The held stack dict (or null) — modifiers live on the instance (LT-05..07).
func held_stack():
	return null if bare_hands else inventory.slots[selected_slot]

func held_tool() -> Dictionary:
	return ItemMods.tool_of(held_stack())

## Weight → swim slowdown (WS-10/14) plus the cold slow (CC-16).
## Sum of one stat across all equipped gear (M5 gear ladder, GL-09/13),
## the gear's modifiers (LT-05..07), and owned tech-tree abilities (CC-18).
func equip_stat(stat: String) -> float:
	var total := skills.ability_stat(stat)
	for slot_name in equipment:
		var st = equipment[slot_name]
		if st != null:
			total += float(Data.item(st.id).get("stats", {}).get(stat, 0.0)) + ItemMods.stat(st, stat)
	return total

## The equipped suit's stat with its modifiers folded in; cold also counts
## the Cold Blood ability (band gates read these, GL-12).
func suit_stat(stat: String) -> float:
	var st = equipment.get("suit")
	var v := 0.0
	if st != null:
		v = float(Data.item(st.id).get("stats", {}).get(stat, 0.0)) + ItemMods.stat(st, stat)
	if stat == "cold":
		v += skills.effect("cold_bonus", 0.0)
	return v

func max_oxygen() -> float:
	return Constants.BASE_OXYGEN_SECONDS + equip_stat("oxygen")

func reveal_radius() -> int:
	return Constants.MAP_REVEAL_RADIUS + int(equip_stat("reveal"))

func scrap_speed_mult() -> float:
	return Constants.SCRAP_SPEED_MULT * (1.0 + equip_stat("scrap_speed") + ItemMods.stat(held_stack(), "scrap_speed"))

## Reach in blocks (WS-12); the Long Reach ability extends it.
func reach_blocks() -> float:
	return Constants.REACH_BLOCKS + skills.effect("reach", 0.0)

## Chance that a scrap roll doubles (Master Scrapper + "of the Scavenger").
func double_yield_chance() -> float:
	return skills.effect("double_yield", 0.0) + equip_stat("yield_chance") + ItemMods.stat(held_stack(), "yield_chance")

func roll_yield(count: int) -> int:
	return count * 2 if randf() < double_yield_chance() else count

## The weight-only part of the swim slowdown (the HUD's overweight icon
## watches this; the weight belt raises the reference).
func weight_swim_factor() -> float:
	var ref := Constants.WEIGHT_SWIM_REFERENCE + equip_stat("carry")
	return maxf(Constants.WEIGHT_SWIM_MIN_FACTOR, 1.0 - 0.5 * inventory.total_weight() / ref)

func swim_factor() -> float:
	var f := weight_swim_factor()
	f *= 1.0 - suit_stat("swim_penalty") + equip_stat("swim")
	return f * env_slow

var env_slow: float = 1.0
var band: String = "dry"

## Cold/crush depth gates (CC-16, GL-12) — while submerged only, so drained
## forward camps stay safe (GL-17). Suit ratings lift them (M5 gear).
func _update_environment(delta: float) -> void:
	env_slow = 1.0
	band = World.band_at(World.cell_at(_center_point()))
	if not in_water:
		return
	match band:
		"cold":
			if suit_stat("cold") < 1:
				env_slow = Constants.COLD_SLOW_FACTOR
		"dark":
			if suit_stat("cold") < 2:
				env_slow = Constants.COLD_SLOW_FACTOR
				apply_damage(Constants.COLD_DPS * delta)
		"crush":
			if suit_stat("crush") < 1:
				env_slow = Constants.COLD_SLOW_FACTOR
				apply_damage(Constants.CRUSH_DPS * delta)

func use_item(slot: int) -> void:
	var s = inventory.slots[slot]
	if s == null:
		return
	var it := Data.item(s.id)
	var use: Dictionary = it.get("use", {})
	if use.is_empty():
		return
	if use.has("heal"):
		var cures: bool = use.get("cure_bleed", false) and bleed_time > 0.0
		if health >= Constants.MAX_HEALTH and not cures:
			return
		health = minf(health + float(use.heal), Constants.MAX_HEALTH)
	if use.get("cure_bleed", false) and bleed_time > 0.0:
		bleed_time = 0.0
		message.emit("Bleeding stopped")
	if use.has("learn_recipe"):
		known_recipes[use.learn_recipe] = true
		message.emit("Learned recipe: " + Data.item_name(Data.recipes[use.learn_recipe].output.item))
	if use.has("drop_light"):
		World.spawn_item(s.id, 1, global_position, Vector2(facing * 3.0 * Constants.BLOCK_SIZE, -2.0 * Constants.BLOCK_SIZE))
	inventory.remove_from_slot(slot, 1)

func drop_held(n: int) -> void:
	var id := held_item()
	if id == "":
		return
	var taken := inventory.remove_from_slot(selected_slot, n)
	World.spawn_item(id, taken, global_position, Vector2(facing * 4.0 * Constants.BLOCK_SIZE, -2.0 * Constants.BLOCK_SIZE))

# --- Equipment (LT-03: Suit + Head + two Accessories; accessory3/4 are the
# reserved mounts, opened by the Tool Harness / Rigger's Kit abilities) ---
var equipment: Dictionary = {"head": null, "suit": null,
	"accessory1": null, "accessory2": null, "accessory3": null, "accessory4": null}

func slot_unlocked(slot_name: String) -> bool:
	if slot_name == "accessory3" or slot_name == "accessory4":
		return skills.has_effect("unlock_slot", slot_name)
	return true

func can_equip(slot_name: String, id: String) -> bool:
	var want: String = Data.item(id).get("slot", "")
	if want == "" or not slot_unlocked(slot_name):
		return false
	if slot_name.begins_with("accessory"):
		return want == "accessory"
	return want == slot_name

func set_equipment(slot_name: String, stack) -> void:
	equipment[slot_name] = stack
	inventory.changed.emit() # equipment shows in the same UI refresh

func equipped(slot_name: String) -> String:
	var st = equipment.get(slot_name)
	return st.id if st != null else ""

func knows_recipe(id: String) -> bool:
	return known_recipes.has(id)

# --- Modification Bench (LT-09/10) ---
var known_mods: Dictionary = {} # mod id -> best power learned (sacrifice-to-learn)

## Mods on this stack that would teach something new (learnable, and a
## higher power than already known) — what the bench's LEARN offers.
func learnable_mods(stack: Dictionary) -> Array:
	var out := []
	var mods := ItemMods.mods_of(stack)
	for part in ["prefix", "suffix"]:
		if mods.has(part):
			var m: Dictionary = mods[part]
			if bool(ItemMods.def_of(m.id).get("learnable", true)) and int(m.power) > int(known_mods.get(m.id, 0)):
				out.append(String(m.id))
	return out

## Sacrifice-to-learn: consumes the modded item, keeps the best power seen
## per modifier. Returns the human-readable list of what was learned.
func learn_mods(stack: Dictionary) -> Array:
	var learned := []
	var mods := ItemMods.mods_of(stack)
	for part in ["prefix", "suffix"]:
		if not mods.has(part):
			continue
		var m: Dictionary = mods[part]
		if not bool(ItemMods.def_of(m.id).get("learnable", true)):
			continue
		if int(m.power) > int(known_mods.get(m.id, 0)):
			known_mods[m.id] = int(m.power)
			learned.append(ItemMods.describe_mod(m.id, int(m.power)))
	return learned

## Applies learned mods to an UNMODIFIED piece (then it is locked, LT-09).
## Up to one learned prefix + one learned suffix in a single operation (LT-07).
func apply_mods(stack: Dictionary, prefix_id: String, suffix_id: String) -> bool:
	var cls := ItemMods.mod_class(stack.id)
	if stack.has("mods") or cls == "":
		return false
	var mods := {}
	if prefix_id != "" and known_mods.has(prefix_id) and (ItemMods.def_of(prefix_id).get("applies", []) as Array).has(cls):
		mods["prefix"] = {"id": prefix_id, "power": int(known_mods[prefix_id])}
	if suffix_id != "" and known_mods.has(suffix_id) and (ItemMods.def_of(suffix_id).get("applies", []) as Array).has(cls):
		mods["suffix"] = {"id": suffix_id, "power": int(known_mods[suffix_id])}
	if mods.is_empty():
		return false
	stack["mods"] = mods
	inventory.changed.emit()
	return true

func can_craft(recipe: Dictionary) -> bool:
	return inventory.has_all(recipe.inputs) and inventory.can_add(recipe.output.item, int(recipe.output.count))

func craft(recipe: Dictionary) -> bool:
	if not can_craft(recipe):
		return false
	inventory.remove_all(recipe.inputs)
	inventory.add(recipe.output.item, int(recipe.output.count))
	return true

## Item scrapping (GL-07): full yield near any station. With allow_field
## (hold-RMB in the bag) it also works away from stations at the reduced
## field yield — the same rule as scrapping furniture in place.
func scrap_item(id: String, n: int = 1, allow_field: bool = false) -> bool:
	var reach := Constants.REACH_BLOCKS * Constants.BLOCK_SIZE * 1.5
	var full := World.stations_near(global_position, reach).size() > 1
	if not full and not allow_field:
		message.emit("Scrapping for full yield needs a station")
		return false
	var yields := Data.scrap_yield(id)
	if yields.is_empty() or inventory.count(id) < n:
		return false
	var obj_def: Dictionary = Data.objects.get(id, {})
	if skills.level("scrapping") < int(obj_def.get("skill", 0)):
		message.emit("Needs Scrapping %d" % obj_def.skill)
		return false
	inventory.remove(id, n)
	for y in yields:
		var count := roll_yield(int(y.count) * n)
		if not full:
			count = int(ceil(count * skills.effect("field_yield", Constants.FIELD_SCRAP_YIELD)))
		var leftover: int = inventory.add(y.item, count)
		if leftover > 0:
			World.spawn_item(y.item, leftover, global_position)
	skills.add_xp("scrapping", float(obj_def.get("xp", 2)) * n)
	message.emit("Scrapped %s x%d%s" % [Data.item_name(id), n, "" if full else " (field yield)"])
	return true

func open_container(obj: WorldObject) -> void:
	container_opened.emit(obj)

func open_crafting(station: String) -> void:
	crafting_opened.emit(station)

# --- Hitbox geometry (local space; feet are always at local y = 12) ---

const FEET_Y: float = 12.0

func hitbox_top() -> float:
	return collision_shape.position.y - collision_shape.shape.size.y * 0.5

func hitbox_bottom() -> float:
	return FEET_Y

func _head_point() -> Vector2:
	return global_position + Vector2(0, hitbox_top() + 2.0)

func _center_point() -> Vector2:
	return global_position + Vector2(0, (hitbox_top() + FEET_Y) * 0.5)

func _feet_point() -> Vector2:
	return global_position + Vector2(0, FEET_Y - 1.0)

## Both forms share the same bottom edge so switching never moves the feet.
func _set_compact(value: bool) -> void:
	compact = value
	var size := Constants.COMPACT_HITBOX if value else Constants.STAND_HITBOX
	collision_shape.shape = _compact_shape if value else _stand_shape
	collision_shape.position.y = FEET_Y - size.y * 0.5

func _can_stand() -> bool:
	var size := Constants.STAND_HITBOX
	var rect := Rect2(global_position + Vector2(-size.x * 0.5, FEET_Y - size.y), size)
	return World.rect_is_clear(rect)

func _pose_clear(pos: Vector2, compact_form: bool) -> bool:
	var size := Constants.COMPACT_HITBOX if compact_form else Constants.STAND_HITBOX
	return World.rect_is_clear(Rect2(pos + Vector2(-size.x * 0.5, FEET_Y - size.y), size))

## Put a loaded save back into its crawl pose (saving in a vent, restoring
## standing, wedged the head into the ceiling and the body into the floor).
func begin_loaded_crawl() -> void:
	_set_compact(true)
	state = State.CRAWLING

## Post-load safety net: if the restored pose overlaps solids anyway, climb
## up in quarter-block steps (falling back to a crawl pose) until legal;
## a hopeless overlap respawns at the bed instead of wedging in the floor.
func unstick() -> void:
	for i in 13:
		var off := Vector2(0, -4.0 * i)
		if _pose_clear(global_position + off, compact):
			global_position += off
			return
		if not compact and _pose_clear(global_position + off, true):
			global_position += off
			begin_loaded_crawl()
			return
	respawn()

# --- Environment ---

func _sense() -> void:
	in_water = World.is_water(_center_point())
	submerged = World.is_water(_head_point())
	on_climbable = World.is_climbable(_center_point())
	climbable_below = World.is_climbable(_feet_point() + Vector2(0, 2.0))

# --- Shared helpers ---

## y of the ladder-top surface directly under the feet (WS-16: ladder tops
## are stand-able one-way platforms), or NAN when there is none.
func _ladder_top_surface() -> float:
	var feet_y := global_position.y + FEET_Y
	var cell := World.cell_at(Vector2(global_position.x, feet_y + 1.0))
	if World.is_ladder_top_cell(cell):
		var top := World.cell_top_y(cell)
		if feet_y <= top + 2.0:
			return top
	return NAN

func _accelerate_x(target: float, accel: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, target, accel * delta)

func _apply_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + Constants.gravity * delta, Constants.MAX_FALL_SPEED)

## Water takes precedence over every land state (WS-15: entry is always safe).
func _try_enter_water() -> bool:
	if not in_water:
		return false
	_set_compact(true)
	velocity.y = minf(velocity.y, Constants.UNDERWATER_SWIM_SPEED) # splash-brake
	state = State.SURFACE_SWIM if _can_surface() else State.UNDERWATER
	return true

## Surface swimming needs the head out of water and air above the column
## (a flooded room's ceiling is not a surface).
func _can_surface() -> bool:
	return not submerged and World.surface_has_air(_center_point())

func _try_enter_climb() -> bool:
	if input_dir.y < 0.0 and on_climbable:
		_enter_climbing()
		return true
	var below := _feet_point() + Vector2(0, 2.0)
	if input_dir.y > 0.0 and climbable_below and not World.is_solid(below):
		_enter_climbing()
		return true
	return false

func _enter_climbing() -> void:
	if compact and _can_stand():
		_set_compact(false)
	velocity = Vector2.ZERO
	state = State.CLIMBING

func _enter_airborne() -> void:
	state = State.AIRBORNE
	fall_start_y = global_position.y

func _jump() -> void:
	velocity.y = Constants.jump_velocity
	coyote_timer = 0.0
	_enter_airborne()

func _land() -> void:
	var fall_blocks := (global_position.y - fall_start_y) / Constants.BLOCK_SIZE
	if fall_blocks > Constants.SAFE_FALL_BLOCKS:
		var over := fall_blocks - Constants.SAFE_FALL_BLOCKS
		apply_damage(over * Constants.FALL_DAMAGE_PER_BLOCK)
	if compact and (wants_crouch or not _can_stand()):
		state = State.CRAWLING
	else:
		_set_compact(false)
		state = State.GROUNDED

# --- States ---

func _state_grounded(delta: float) -> void:
	if _try_enter_water() or _try_enter_climb():
		return
	if wants_crouch or not _can_stand():
		_set_compact(true)
		state = State.CRAWLING
		return
	var target := input_dir.x * (Constants.SPRINT_SPEED if wants_sprint else Constants.WALK_SPEED)
	var accel := Constants.GROUND_ACCEL if input_dir.x != 0.0 else Constants.GROUND_FRICTION
	_accelerate_x(target, accel, delta)
	_apply_gravity(delta)
	if _consume_jump():
		_jump()
		return
	if not is_on_floor():
		var ladder_top := _ladder_top_surface()
		if not is_nan(ladder_top) and velocity.y >= 0.0:
			# Standing on a ladder top: keep the feet pinned to the surface.
			global_position.y = ladder_top - FEET_Y
			velocity.y = 0.0
			return
		coyote_timer = Constants.COYOTE_TIME
		_enter_airborne()

func _state_airborne(delta: float) -> void:
	if _try_enter_water() or _try_enter_climb():
		return
	var target := input_dir.x * (Constants.SPRINT_SPEED if wants_sprint else Constants.WALK_SPEED)
	_accelerate_x(target, Constants.AIR_ACCEL, delta)
	_apply_gravity(delta)
	fall_start_y = minf(fall_start_y, global_position.y)
	if coyote_timer > 0.0 and _consume_jump():
		_jump()
		return
	# Falling across a ladder-top surface lands on it (one-way platform).
	if velocity.y > 0.0 and input_dir.y <= 0.0:
		var feet_y := global_position.y + FEET_Y
		var next_feet := feet_y + velocity.y * delta
		var cell := World.cell_at(Vector2(global_position.x, next_feet + 0.5))
		if World.is_ladder_top_cell(cell):
			var top := World.cell_top_y(cell)
			if feet_y <= top + 0.5 and next_feet >= top - 0.5:
				global_position.y = top - FEET_Y
				velocity.y = 0.0
				_land()
				return
	if is_on_floor():
		_land()

func _state_crawling(delta: float) -> void:
	if _try_enter_water() or _try_enter_climb():
		return
	var can_stand := _can_stand()
	if can_stand and not wants_crouch:
		_set_compact(false)
		state = State.GROUNDED
		return
	_accelerate_x(input_dir.x * Constants.CRAWL_SPEED, Constants.GROUND_ACCEL, delta)
	_apply_gravity(delta)
	if can_stand and _consume_jump():
		_set_compact(false)
		_jump()
		return
	if not is_on_floor():
		coyote_timer = Constants.COYOTE_TIME
		_enter_airborne()

func _state_climbing(delta: float) -> void:
	if _try_enter_water():
		return
	# Descending onto/through a ladder counts as climbing even while the body
	# center is still above the top rung (stepping down from a ladder top).
	if not on_climbable and not (input_dir.y > 0.0 and climbable_below):
		if is_on_floor():
			state = State.GROUNDED
		else:
			if input_dir.y < 0.0:
				# Topping out: a partial-jump hop so the player can step off the
				# rope/ladder instead of dropping straight back into the hole
				# (0.8 clears the taller body's centre-to-feet gap).
				velocity.y = Constants.jump_velocity * 0.8
			_enter_airborne()
		return
	if _consume_jump():
		_jump()
		velocity.x = input_dir.x * Constants.WALK_SPEED
		return
	velocity.y = input_dir.y * Constants.CLIMB_SPEED
	# Center on the rope/ladder column (walk anim reuse, WS-27).
	var dx := World.climbable_center_x(_center_point()) - global_position.x
	velocity.x = clampf(dx / delta, -Constants.WALK_SPEED, Constants.WALK_SPEED)
	if input_dir.y > 0.0 and is_on_floor():
		state = State.GROUNDED

func _state_surface_swim(delta: float) -> void:
	if not in_water:
		_exit_water_to_air()
		return
	if _consume_jump():
		velocity.y = Constants.water_jump_velocity
		_exit_water_to_air()
		return
	if input_dir.y > 0.0:
		velocity.y = Constants.UNDERWATER_SWIM_SPEED * swim_factor()
		state = State.UNDERWATER
		return
	_accelerate_x(input_dir.x * Constants.SURFACE_SWIM_SPEED * swim_factor(), Constants.SWIM_ACCEL, delta)
	velocity += World.current_at(_center_point()) * delta * 60.0 * delta # currents push (WS-16)
	# Auto-tread (WS-07): spring toward the float line.
	var surface := World.water_surface_y(_center_point())
	var target_y := surface - Constants.SURFACE_FLOAT_HEIGHT_PX - hitbox_top()
	velocity.y = (target_y - global_position.y) * Constants.SURFACE_TREAD_STIFFNESS

func _state_underwater(delta: float) -> void:
	if not in_water:
		_exit_water_to_air()
		return
	if input_dir.y <= 0.0 and _can_surface():
		state = State.SURFACE_SWIM
		return
	# Free 8-way, neutral buoyancy (WS-06/09): no gravity, drag to rest.
	var target := input_dir * Constants.UNDERWATER_SWIM_SPEED * swim_factor()
	target += World.current_at(_center_point()) # currents push, swimmable against (WS-16)
	var rate := Constants.SWIM_ACCEL if input_dir != Vector2.ZERO else Constants.SWIM_DRAG
	velocity = velocity.move_toward(target, rate * delta)

func _exit_water_to_air() -> void:
	if _can_stand():
		_set_compact(false)
	_enter_airborne()

# --- Vitals ---

func _update_oxygen(delta: float) -> void:
	# Drains whenever the head is under — including pinned to a flooded ceiling.
	if submerged:
		# Free Diver (tech tree) slows the drain.
		oxygen = minf(maxf(oxygen - delta * skills.effect("o2_drain", 1.0), 0.0), max_oxygen())
		drowning = oxygen <= 0.0
		if drowning:
			apply_damage(Constants.drowning_damage_per_second * delta)
	else:
		oxygen = max_oxygen() # instant refill in air (WS-08); tanks extend it (GL-13)
		drowning = false

## Bleeding drip + slow out-of-combat regen (GD-21, GL-21). Any damage —
## enemies, cold, drowning — resets the regen delay via apply_damage.
func _update_vitals(delta: float) -> void:
	combat_timer += delta
	if bleed_time > 0.0:
		bleed_time = maxf(bleed_time - delta, 0.0)
		apply_damage(Constants.BLEED_DPS * delta)
	elif combat_timer > Constants.PASSIVE_REGEN_COMBAT_DELAY and not drowning and health > 0.0:
		health = minf(health + Constants.PASSIVE_REGEN_PER_SECOND * delta, Constants.MAX_HEALTH)

## A contact hit from an enemy (M4): damage, a shove, and a bleed chance
## from zombie/Drowned kinds (GD-21).
func hurt_from_enemy(damage: float, from_pos: Vector2, can_bleed: bool) -> void:
	var dir := (global_position - from_pos).normalized()
	velocity += Vector2(dir.x, -0.5).normalized() * Constants.ENEMY_KNOCKBACK
	apply_damage(damage)
	if can_bleed and bleed_time <= 0.0 and randf() < Constants.BLEED_CHANCE and health > 0.0:
		start_bleeding()
	Audio.play_sfx("footstep_soft", global_position, 8, -4.0)

func start_bleeding() -> void:
	bleed_time = Constants.BLEED_DURATION
	message.emit("You are bleeding — bandage it!")

func apply_damage(amount: float) -> void:
	combat_timer = 0.0
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		_die()

## Death loop (CC-07): the whole bag transfers to a backpack that floats up
## from where you fell (or pins under a flooded ceiling); worn gear stays on
## the body. Respawn at the bed (GL-23), swim back down, touch to recover.
func _die() -> void:
	var dropped: Array = []
	for i in inventory.slots.size():
		if inventory.slots[i] != null:
			dropped.append(inventory.slots[i])
			inventory.slots[i] = null
	inventory.changed.emit()
	if not dropped.is_empty():
		World.spawn_backpack(dropped, _center_point())
		message.emit("You died — your backpack is where you fell")
	else:
		message.emit("You died")
	respawn()

func respawn() -> void:
	health = Constants.MAX_HEALTH
	oxygen = max_oxygen()
	drowning = false
	bleed_time = 0.0
	combat_timer = 999.0
	velocity = Vector2.ZERO
	_set_compact(false)
	global_position = World.spawn_position - Vector2(0, FEET_Y)
	state = State.AIRBORNE
	fall_start_y = global_position.y
	camera.offset = Vector2.ZERO
	camera.reset_smoothing()

## Step through an interior doorway (or any authored portal): land with the
## feet at `feet`, no momentum, camera snapped — the far side can be a whole
## city away, so the streaming windows refill before the next frame.
func travel_to(feet: Vector2) -> void:
	velocity = Vector2.ZERO
	_set_compact(false)
	global_position = feet - Vector2(0, FEET_Y)
	state = State.AIRBORNE
	fall_start_y = global_position.y
	camera.offset = Vector2.ZERO
	camera.reset_smoothing()
	World.refresh_objects_around(global_position)
	unstick()

# --- Camera (WS-18) ---

# --- Sprite (assets/sprites/player.png: 32x32, row 0 east / row 1 west, col 0 idle, cols 1-6 walk) ---

const WALK_FRAMES: int = 6
const WALK_FRAME_TIME: float = 0.1 # seconds per frame at walk speed; scales with actual speed

var facing: int = 1 # +1 east, -1 west
var _anim_time: float = 0.0

# Movement sounds: footsteps paced by ground distance, a splash on hitting
# water (volume scales with entry speed).
var _step_dist: float = 0.0
var _was_in_water: bool = false
var _splash_cooldown: float = 0.0

func _update_move_sfx(delta: float) -> void:
	_splash_cooldown = maxf(_splash_cooldown - delta, 0.0)
	var stride := Constants.FOOTSTEP_STRIDE_BLOCKS * Constants.BLOCK_SIZE
	if state == State.GROUNDED and absf(velocity.x) > 0.5 * Constants.BLOCK_SIZE:
		_step_dist += absf(velocity.x) * delta
		if _step_dist >= stride:
			_step_dist = 0.0
			Audio.play_sfx("footstep_wood", _feet_point(), 12, -8.0)
	elif state == State.CRAWLING and velocity.length() > 0.4 * Constants.BLOCK_SIZE:
		_step_dist += velocity.length() * delta
		if _step_dist >= stride:
			_step_dist = 0.0
			Audio.play_sfx("footstep_soft", _feet_point(), 8, -2.0)
	else:
		_step_dist = stride * 0.6 # first step lands quickly when moving resumes
	if in_water and not _was_in_water and _splash_cooldown <= 0.0:
		var speed := velocity.length()
		if speed > 1.5 * Constants.BLOCK_SIZE:
			_splash_cooldown = 0.4
			var vol := clampf(-18.0 + speed / (6.0 * Constants.BLOCK_SIZE) * 18.0, -18.0, 0.0)
			Audio.play_sfx("splash", _feet_point(), 5, vol)
	_was_in_water = in_water

# Tool swing (user request): the held tool arcs in front of the player on
# each hammer hit so breaking your own blocks reads as an action.
var _swing_time: float = 0.0
var _scrap_anim: float = 0.0
var _tool_sprite: Sprite2D = null

func play_swing() -> void:
	if _tool_sprite == null:
		_tool_sprite = Sprite2D.new()
		_tool_sprite.z_index = 1
		add_child(_tool_sprite)
	_tool_sprite.texture = Data.icon(held_item())
	_swing_time = Constants.TOOL_SWING_TIME

func _update_swing(delta: float) -> void:
	# Paper-doll held tool (WS-26): the tool rides in the hand whenever one
	# is held, not only during the swing arc.
	if _tool_sprite == null:
		if held_tool().is_empty() and Data.item(held_item()).get("weapon") == null:
			return
		_tool_sprite = Sprite2D.new()
		_tool_sprite.z_index = 1
		add_child(_tool_sprite)
	if _swing_time <= 0.0:
		var it := Data.item(held_item())
		if it.has("tool") or it.has("weapon"):
			_tool_sprite.texture = Data.icon(held_item())
			_tool_sprite.visible = true
			_tool_sprite.flip_h = facing < 0
			if interaction != null and interaction.scrapping != null:
				# Levering motion while dismantling furniture (user request):
				# the held tool rocks back and forth like a pry bar working
				# a joint loose.
				_scrap_anim += delta * 9.0
				var osc := sin(_scrap_anim)
				_tool_sprite.rotation = (0.55 + osc * 0.45) * facing
				_tool_sprite.position = Vector2(facing * (6.0 + osc), -4.0 + absf(osc) * 1.5)
			else:
				_scrap_anim = 0.0
				_tool_sprite.rotation = 0.35 * facing
				# Held at hand height: the tool's lower corner sits
				# mid-body, not at the feet (user request).
				_tool_sprite.position = Vector2(facing * 5.0, -5.0)
			if state == State.SURFACE_SWIM: # ride the chest-deep body
				_tool_sprite.position.y += Constants.SURFACE_SPRITE_SINK_PX
		else:
			_tool_sprite.visible = false
		return
	_swing_time = maxf(_swing_time - delta, 0.0)
	var t := 1.0 - _swing_time / Constants.TOOL_SWING_TIME
	var dir := 1.0 if aim_position.x >= global_position.x else -1.0
	var ang := lerpf(-1.9, 0.6, t) # overhead wind-up to forward-down
	_tool_sprite.visible = true
	_tool_sprite.rotation = ang * dir
	_tool_sprite.flip_h = dir < 0
	_tool_sprite.position = Vector2(dir * 7.0, 0.0) + Vector2(sin(ang) * dir, -cos(ang)) * 5.0

var _lamp_dot: Sprite2D = null

## Visible gear (WS-26, first pass per WS-25 tint layers): the sprite is
## tinted by the worn suit tier ("tint" in items.json) and a lit pip marks a
## worn head lamp; the held tool renders in hand (see _update_swing).
func _update_gear_visuals() -> void:
	var tint: Array = Data.item(equipped("suit")).get("tint", [])
	sprite.modulate = Color(tint[0], tint[1], tint[2]) if tint.size() == 3 else Color.WHITE
	var head_light := equipment.get("head") != null and float(Data.item(equipped("head")).get("stats", {}).get("light", 0)) > 0.0
	if head_light and _lamp_dot == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.95, 0.6))
		_lamp_dot = Sprite2D.new()
		_lamp_dot.texture = ImageTexture.create_from_image(img)
		_lamp_dot.z_index = 1
		add_child(_lamp_dot)
	if _lamp_dot != null:
		_lamp_dot.visible = head_light
		_lamp_dot.position = Vector2(facing * 3.0, hitbox_top() + 3.0)
		if state == State.SURFACE_SWIM:
			_lamp_dot.position.y += Constants.SURFACE_SPRITE_SINK_PX

func _update_sprite(delta: float) -> void:
	if input_dir.x != 0.0:
		facing = 1 if input_dir.x > 0.0 else -1
	_update_gear_visuals()
	var speed := absf(velocity.x) if not compact else velocity.length()
	var moving := speed > 0.5 * Constants.BLOCK_SIZE
	var frame_col := 0
	if moving:
		_anim_time += delta * clampf(speed / Constants.WALK_SPEED, 0.5, 2.0)
		frame_col = 1 + int(_anim_time / WALK_FRAME_TIME) % WALK_FRAMES
	else:
		_anim_time = 0.0
	sprite.frame_coords = Vector2i(frame_col, 0 if facing > 0 else 1)
	if compact and state != State.SURFACE_SWIM:
		# Crawling / diving: lay the body along the compact hitbox, head
		# toward facing. Treading at the surface stays upright (user request).
		sprite.rotation = facing * PI * 0.5
		sprite.position = Vector2(0, 5)
	else:
		sprite.rotation = 0.0
		# Feet on the scaled frame's bottom row at local y = FEET_Y.
		sprite.position = Vector2(0, FEET_Y - 16.0 * Constants.PLAYER_SPRITE_SCALE)
		if state == State.SURFACE_SWIM:
			# Chest-high waterline while treading (user request).
			sprite.position.y += Constants.SURFACE_SPRITE_SINK_PX

var zoom_index: int = Constants.CAMERA_ZOOM_DEFAULT_INDEX

## Camera stays centred on the player (smooth follow only, no lookahead).
func _update_camera(_delta: float) -> void:
	camera.offset = Vector2.ZERO

func zoom_step(direction: int) -> void:
	zoom_index = clampi(zoom_index + direction, 0, Constants.CAMERA_ZOOM_LEVELS.size() - 1)
	var z: float = Constants.CAMERA_ZOOM_LEVELS[zoom_index]
	camera.zoom = Vector2(z, z)

func state_name() -> String:
	return State.keys()[state]
