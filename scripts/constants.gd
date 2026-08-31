extends Node
## Game constants singleton — the single tuning surface (WS-30).
## All design units are BLOCKS; pixels appear only via BLOCK_SIZE.

const BLOCK_SIZE: int = 16 # pixels per block; 1 block = 2 ft in-game

# --- Movement (blocks/second, WS-03) ---
const WALK_SPEED: float = 5.0 * BLOCK_SIZE
const SPRINT_SPEED: float = 7.0 * BLOCK_SIZE
const CRAWL_SPEED: float = 2.5 * BLOCK_SIZE
const CLIMB_SPEED: float = 4.0 * BLOCK_SIZE
const SURFACE_SWIM_SPEED: float = 5.0 * BLOCK_SIZE
const UNDERWATER_SWIM_SPEED: float = 4.0 * BLOCK_SIZE

# --- Acceleration / friction (blocks/second²) ---
const GROUND_ACCEL: float = 45.0 * BLOCK_SIZE   # ~0.11 s to walk speed
const GROUND_FRICTION: float = 60.0 * BLOCK_SIZE # ~0.08 s to stop
const AIR_ACCEL: float = 25.0 * BLOCK_SIZE
const SWIM_ACCEL: float = 20.0 * BLOCK_SIZE
const SWIM_DRAG: float = 12.0 * BLOCK_SIZE       # underwater coast-to-stop

# --- Jumping (WS-04: 3-block jump; two-jump rule between floors) ---
const JUMP_HEIGHT_BLOCKS: float = 3.0
const JUMP_APEX_TIME: float = 0.34 # seconds to reach apex; tune for feel
const WATER_EXIT_JUMP_BLOCKS: float = 2.0 # water-jump onto ledges (WS-07)
const COYOTE_TIME: float = 0.10
const JUMP_BUFFER_TIME: float = 0.12

# --- Falling (WS-15) ---
const SAFE_FALL_BLOCKS: float = 8.0 # no damage at or under this drop
const FALL_DAMAGE_PER_BLOCK: float = 10.0 # per block beyond safe height
const MAX_FALL_SPEED: float = 30.0 * BLOCK_SIZE

# --- Water (WS-07/09) ---
const SURFACE_FLOAT_HEIGHT_PX: float = 4.0 # compact hitbox top sits this far above the waterline
const SURFACE_TREAD_STIFFNESS: float = 12.0 # 1/s — auto-tread pull toward the float line

# --- Hitboxes (WS-02: 12 wide; compact form fits 1-block holes) ---
const STAND_HITBOX: Vector2 = Vector2(12, 22)
const COMPACT_HITBOX: Vector2 = Vector2(12, 12) # crawling and swimming

# --- Oxygen & drowning (WS-08, GD-20) ---
const BASE_OXYGEN_SECONDS: float = 30.0
const DROWNING_SECONDS_TO_DEATH: float = 10.0

# --- Health (GL-21) ---
const MAX_HEALTH: float = 100.0
const PASSIVE_REGEN_PER_SECOND: float = 1.0
const PASSIVE_REGEN_COMBAT_DELAY: float = 8.0

# --- Interaction (WS-12) ---
const REACH_BLOCKS: float = 4.0

# --- Camera (WS-18: fixed zoom, smooth follow, speed-scaled lookahead) ---
const CAMERA_LOOKAHEAD_BLOCKS: Vector2 = Vector2(4.0, 2.0) # lead at full sprint / terminal fall
const CAMERA_LOOKAHEAD_SMOOTHING: float = 3.0 # 1/s

# --- Derived (computed once at load) ---
var jump_velocity: float
var water_jump_velocity: float
var gravity: float
var drowning_damage_per_second: float

func _ready() -> void:
	# Solve projectile motion so the apex is exactly JUMP_HEIGHT_BLOCKS.
	var h := JUMP_HEIGHT_BLOCKS * BLOCK_SIZE
	gravity = 2.0 * h / (JUMP_APEX_TIME * JUMP_APEX_TIME)
	jump_velocity = -gravity * JUMP_APEX_TIME
	water_jump_velocity = -sqrt(2.0 * gravity * WATER_EXIT_JUMP_BLOCKS * BLOCK_SIZE)
	drowning_damage_per_second = MAX_HEALTH / DROWNING_SECONDS_TO_DEATH
