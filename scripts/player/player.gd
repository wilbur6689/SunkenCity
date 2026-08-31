class_name Player
extends CharacterBody2D
## M0 character controller — explicit state machine (WS-19).
## Server-authoritative by design (CC-06): input is read into the
## `input_dir`/`wants_*` snapshot only by the multiplayer authority of this
## node; states consume the snapshot, never Input directly, so a networked
## client can later feed the same fields remotely. World queries go through
## the World authority layer, never the tile layers.

enum State { GROUNDED, AIRBORNE, CRAWLING, CLIMBING, SURFACE_SWIM, UNDERWATER }

var state: State = State.AIRBORNE

# --- Input snapshot (separated from state logic for LAN-readiness) ---
var input_dir: Vector2 = Vector2.ZERO
var wants_jump: bool = false # pressed this frame
var wants_sprint: bool = false
var wants_crouch: bool = false

# --- Timers ---
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# --- Vitals (first pass; systems move to components in M1+) ---
var health: float = Constants.MAX_HEALTH
var oxygen: float = Constants.BASE_OXYGEN_SECONDS
var drowning: bool = false
var fall_start_y: float = 0.0

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

var _stand_shape := RectangleShape2D.new()
var _compact_shape := RectangleShape2D.new()

func _ready() -> void:
	_stand_shape.size = Constants.STAND_HITBOX
	_compact_shape.size = Constants.COMPACT_HITBOX
	_set_compact(false)
	if World.is_ready():
		respawn()

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_read_input()
	_tick_timers(delta)
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
	if input_dir.x != 0.0:
		sprite.flip_h = input_dir.x < 0.0 # sheet faces right
	_update_oxygen(delta)
	_update_camera(delta)

# --- Input & timers ---

func _read_input() -> void:
	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	wants_sprint = Input.is_action_pressed("sprint")
	wants_crouch = Input.is_action_pressed("crouch")
	wants_jump = Input.is_action_just_pressed("jump")

func _tick_timers(delta: float) -> void:
	if wants_jump:
		jump_buffer_timer = Constants.JUMP_BUFFER_TIME
		wants_jump = false
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

func _consume_jump() -> bool:
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = 0.0
		return true
	return false

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
	# Sheet frames are 24x24 with feet on the bottom row: frame 0 standing,
	# frame 1 prone (bottom 12px = the compact hitbox). No repositioning needed.
	sprite.frame = 1 if value else 0

func _can_stand() -> bool:
	var size := Constants.STAND_HITBOX
	var rect := Rect2(global_position + Vector2(-size.x * 0.5, FEET_Y - size.y), size)
	return World.rect_is_clear(rect)

# --- Environment ---

func _sense() -> void:
	in_water = World.is_water(_center_point())
	submerged = World.is_water(_head_point())
	on_climbable = World.is_climbable(_center_point())
	climbable_below = World.is_climbable(_feet_point() + Vector2(0, 2.0))

# --- Shared helpers ---

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
	if not on_climbable:
		if is_on_floor():
			state = State.GROUNDED
		else:
			if input_dir.y < 0.0:
				# Topping out: a half-jump hop so the player can step off the
				# rope/ladder instead of dropping straight back into the hole.
				velocity.y = Constants.jump_velocity * 0.5
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
		velocity.y = Constants.UNDERWATER_SWIM_SPEED
		state = State.UNDERWATER
		return
	_accelerate_x(input_dir.x * Constants.SURFACE_SWIM_SPEED, Constants.SWIM_ACCEL, delta)
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
	var target := input_dir * Constants.UNDERWATER_SWIM_SPEED
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
		oxygen = maxf(oxygen - delta, 0.0)
		drowning = oxygen <= 0.0
		if drowning:
			apply_damage(Constants.drowning_damage_per_second * delta)
	else:
		oxygen = Constants.BASE_OXYGEN_SECONDS # instant refill in air (WS-08)
		drowning = false

func apply_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		_die()

func _die() -> void:
	# M0: reset at world spawn. Backpack drop (M4) + bed spawn (M1) later.
	respawn()

func respawn() -> void:
	health = Constants.MAX_HEALTH
	oxygen = Constants.BASE_OXYGEN_SECONDS
	drowning = false
	velocity = Vector2.ZERO
	_set_compact(false)
	global_position = World.spawn_position - Vector2(0, FEET_Y)
	state = State.AIRBORNE
	fall_start_y = global_position.y
	camera.offset = Vector2.ZERO
	camera.reset_smoothing()

# --- Camera (WS-18) ---

func _update_camera(delta: float) -> void:
	var lead := Vector2(
		velocity.x / Constants.SPRINT_SPEED * Constants.CAMERA_LOOKAHEAD_BLOCKS.x,
		velocity.y / Constants.MAX_FALL_SPEED * Constants.CAMERA_LOOKAHEAD_BLOCKS.y
	) * Constants.BLOCK_SIZE
	var t := 1.0 - exp(-Constants.CAMERA_LOOKAHEAD_SMOOTHING * delta)
	camera.offset = camera.offset.lerp(lead, t)

func state_name() -> String:
	return State.keys()[state]
