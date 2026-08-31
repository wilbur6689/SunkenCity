class_name Player
extends CharacterBody2D
## M0 character controller — explicit state machine (WS-19).
## Server-authoritative by design: input is read into `input_dir`/`wants_*`
## fields first, then states consume them, so a networked client can later
## feed the same fields remotely (CC-06).

enum State { GROUNDED, AIRBORNE, SURFACE_SWIM, UNDERWATER, CLIMBING, CRAWLING }

var state: State = State.AIRBORNE

# --- Input snapshot (separated from state logic for LAN-readiness) ---
var input_dir: Vector2 = Vector2.ZERO
var wants_jump: bool = false
var wants_sprint: bool = false
var wants_crouch: bool = false

# --- Timers ---
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# --- Vitals (first pass; systems move to components in M1+) ---
var health: float = Constants.MAX_HEALTH
var oxygen: float = Constants.BASE_OXYGEN_SECONDS
var fall_start_y: float = 0.0

func _physics_process(delta: float) -> void:
	_read_input()
	_tick_timers(delta)
	match state:
		State.GROUNDED:
			_state_grounded(delta)
		State.AIRBORNE:
			_state_airborne(delta)
		State.SURFACE_SWIM, State.UNDERWATER, State.CLIMBING, State.CRAWLING:
			# M0 stubs — implemented against real water cells in M2,
			# ropes/ladders and crawl later in M0.
			_state_airborne(delta)
	move_and_slide()

func _read_input() -> void:
	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	wants_sprint = Input.is_action_pressed("sprint")
	wants_crouch = Input.is_action_pressed("crouch")
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = Constants.JUMP_BUFFER_TIME

func _tick_timers(delta: float) -> void:
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

func _state_grounded(delta: float) -> void:
	var speed := Constants.SPRINT_SPEED if wants_sprint else Constants.WALK_SPEED
	velocity.x = input_dir.x * speed
	velocity.y += Constants.gravity * delta

	if jump_buffer_timer > 0.0:
		jump_buffer_timer = 0.0
		velocity.y = Constants.jump_velocity
		_enter_airborne()
		return

	if not is_on_floor():
		coyote_timer = Constants.COYOTE_TIME
		_enter_airborne()

func _state_airborne(delta: float) -> void:
	velocity.x = input_dir.x * Constants.WALK_SPEED
	velocity.y = minf(velocity.y + Constants.gravity * delta, Constants.MAX_FALL_SPEED)
	fall_start_y = minf(fall_start_y, global_position.y)

	# Coyote jump
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		velocity.y = Constants.jump_velocity

	if is_on_floor():
		_land()

func _enter_airborne() -> void:
	state = State.AIRBORNE
	fall_start_y = global_position.y

func _land() -> void:
	var fall_blocks := (global_position.y - fall_start_y) / Constants.BLOCK_SIZE
	if fall_blocks > Constants.SAFE_FALL_BLOCKS:
		var over := fall_blocks - Constants.SAFE_FALL_BLOCKS
		apply_damage(over * Constants.FALL_DAMAGE_PER_BLOCK)
	state = State.GROUNDED

func apply_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		_die()

func _die() -> void:
	# M0: reset to spawn. Backpack drop + bed respawn arrive in M4/M1.
	health = Constants.MAX_HEALTH
	oxygen = Constants.BASE_OXYGEN_SECONDS
	velocity = Vector2.ZERO
	global_position = get_tree().get_first_node_in_group("spawn_point").global_position
	state = State.AIRBORNE
	fall_start_y = global_position.y
