extends Node
## Game constants singleton — the single tuning surface (WS-30).
## All design units are BLOCKS; pixels appear only via BLOCK_SIZE.

const BLOCK_SIZE: int = 16 # pixels per block; 1 block = 2 ft in-game

# --- Movement (blocks/second, WS-03) ---
const WALK_SPEED: float = 5.0 * BLOCK_SIZE
const SPRINT_SPEED: float = 7.0 * BLOCK_SIZE
const SURFACE_SWIM_SPEED: float = 5.0 * BLOCK_SIZE
const UNDERWATER_SWIM_SPEED: float = 4.0 * BLOCK_SIZE

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

# --- Oxygen & drowning (WS-08, GD-20) ---
const BASE_OXYGEN_SECONDS: float = 30.0
const DROWNING_SECONDS_TO_DEATH: float = 10.0

# --- Health (GL-21) ---
const MAX_HEALTH: float = 100.0
const PASSIVE_REGEN_PER_SECOND: float = 1.0
const PASSIVE_REGEN_COMBAT_DELAY: float = 8.0

# --- Interaction (WS-12) ---
const REACH_BLOCKS: float = 4.0

# --- Derived (computed once at load) ---
var jump_velocity: float
var gravity: float

func _ready() -> void:
	# Solve projectile motion so the apex is exactly JUMP_HEIGHT_BLOCKS.
	var h := JUMP_HEIGHT_BLOCKS * BLOCK_SIZE
	gravity = 2.0 * h / (JUMP_APEX_TIME * JUMP_APEX_TIME)
	jump_velocity = -gravity * JUMP_APEX_TIME
