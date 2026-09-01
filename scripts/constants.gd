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
const UNDERWATER_SWIM_SPEED: float = 5.0 * BLOCK_SIZE # = walk speed (user request 2026-08-31)

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
const SURFACE_SPRITE_SINK_PX: float = 8.0  # treading draws the body this much lower, so the
                                           # waterline sits chest-high (user request); visual only —
                                           # the hitbox/oxygen head point stays above the surface
const SURFACE_TREAD_STIFFNESS: float = 12.0 # 1/s — auto-tread pull toward the float line

# --- Hitboxes (WS-02: compact form fits 1-block holes; the 1.5x rescale was
# tried and reverted 2026-08-31 — the ~30px sprite at 1x is the kept look) ---
const PLAYER_SPRITE_SCALE: float = 1.0
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

# --- Inventory & weight (WS-13/14, LT-23) ---
const INVENTORY_SLOTS: int = 40
const HOTBAR_SLOTS: int = 10
const MATERIAL_STACK: int = 999
const CHEST_SLOTS: int = 20
const WEIGHT_SWIM_REFERENCE: float = 60.0 # carried weight at which swim speed is halved (soft cap)
const WEIGHT_SWIM_MIN_FACTOR: float = 0.3
const PICKUP_RADIUS_BLOCKS: float = 1.0
const DROP_PICKUP_DELAY: float = 1.0 # seconds before a dropped item can be re-picked

# --- Scrapping (GL-07) ---
const SCRAP_SPEED_MULT: float = 2.0 # global scrap-speed multiplier (2.0 = testing boost, user request)
const FIELD_SCRAP_YIELD: float = 0.5 # fraction of full yield when scrapping in place
const HAND_TOOL_TIER: int = 0
const HAND_SCRAP_SPEED: float = 0.6 # bare-hand scrap speed multiplier

# --- Structure demolition (GL-01 amended, user request 2026-08-31): any
# structure block breaks under the right TOOL TIER — scrap tools (1) chew
# wood/plastic, iron (2) cracks stone, steel (3) cuts metal. Keys are
# WorldGrid.M materials; drops are 1 matching material per block. Structure
# ladders/ropes and back walls keep their own rules.
const STRUCTURE_TIER := {WorldGrid.M.WOOD: 1, WorldGrid.M.PLASTIC: 1, WorldGrid.M.STONE: 2, WorldGrid.M.METAL: 3}
# Demolition is deliberate (user request): at 0.25 s/hit that is ~3 s for a
# wood block (hammer, 10 dmg), ~10 s for stone (iron tools, 4-5 dmg), ~20 s+
# for metal (cutting torch, 3 dmg). Cracks appear at 25/50/75% damage.
const STRUCTURE_HP := {WorldGrid.M.WOOD: 120.0, WorldGrid.M.PLASTIC: 80.0, WorldGrid.M.STONE: 200.0, WorldGrid.M.METAL: 260.0}
const STRUCTURE_DROP := {WorldGrid.M.WOOD: "wood", WorldGrid.M.PLASTIC: "plastic", WorldGrid.M.STONE: "stone", WorldGrid.M.METAL: "scrap_metal"}
# Mined drops must visibly pay out (user request): they pop toward the
# miner (velocity = offset * factor + an upward kick) and then MAGNET home
# to any player within radius once their pickup delay expires.
const MINE_TOSS_FACTOR: float = 1.5
const MINE_TOSS_UP: float = 1.0 * BLOCK_SIZE
const ITEM_MAGNET_RADIUS_BLOCKS: float = 5.0
const ITEM_MAGNET_SPEED: float = 9.0 * BLOCK_SIZE

# --- Building (WS-22) ---
const HAND_BLOCK_DAMAGE: float = 0.0 # bare hands cannot break placed blocks
const BLOCK_HIT_INTERVAL: float = 0.25 # seconds between tool hits while holding use

# --- Water sim (M2, WaterPhysics.md) ---
const WATER_BUDGET_PER_TICK: int = 3000 # awake cells processed per physics tick
const PUMP_UNITS_PER_TICK: int = 2      # 8 units = one cell; 2/tick @60 = 15 cells/sec
const PUMP_RANGE_BLOCKS: float = 24.0   # how far a pump's outlet can be set
const CURRENT_PUSH: float = 14.0        # px/s of push per unit of flow (WS-16; tuned escapable)
const ITEM_BUOYANCY_RISE: float = 3.0 * BLOCK_SIZE # floating items rise at this speed (CC-07)

# --- Lighting & sight (WS-17 + fog of war) ---
const LAMP_LIGHT: int = 13            # placed lights (tile-light seed, 0..15)
const GLOWSTICK_LIGHT: int = 11       # dropped or held glowsticks
const PLAYER_SIGHT_LIGHT: int = 9     # the player's inherent glow (baseline sight)
const SIGHT_FULL_BLOCKS: float = 7.0  # full visibility inside this radius
const SIGHT_FADE_PER_BLOCK: float = 1.5 # visibility lost per block beyond it (0 ≈ 17 blocks)
# Player-placed lights are fog BEACONS (user request): the area around a
# placed lamp / dropped glowstick stays revealed with no line of sight from
# the player (walls still occlude — the beacon raycasts from itself).
const BEACON_FULL_BLOCKS: float = 5.0
const POWER_RADIUS_BLOCKS: float = 24.0 # a breaker powers wired lights within this range
const OBSTACLE_SIGHT_TRANSMISSION: float = 0.45 # sight through a shelf/crate cell (structure = 0)

# --- Object interaction (LMB; hold to pick up) ---
const OBJECT_LONG_PRESS: float = 0.5 # seconds of held LMB that picks an object up
const LIGHT_RECOMPUTE_TICKS: int = 3
const BREAKER_CHECK_TICKS: int = 20   # flood-trip poll (WS-17)

# --- World scale, bands, clock (M3: CT-28, GD-16, CC-11) ---
const LIGHT_WINDOW: Vector2i = Vector2i(120, 72) # cells relit around the camera

# Object streaming: records within this window (cells, centred on the
# player) are instantiated as nodes; the rest of the city stays data.
# Generous on purpose — it must cover the tallest zoom-out and the test
# tower's full height so held references never despawn mid-test.
const OBJECT_WINDOW: Vector2i = Vector2i(200, 160)

const TOOL_SWING_TIME: float = 0.18 # seconds per hammer swing arc
const FOOTSTEP_STRIDE_BLOCKS: float = 1.6 # ground distance between step sounds
const SCRAP_SFX_INTERVAL: float = 0.4     # seconds between scrapping creaks

# Audio
const MUSIC_VOLUME_DB: float = -8.0
const AMBIENT_VOLUME_DB: float = -6.0
# Music cadence (user request 2026-08-31): a track LOOPS for a 3-5 minute
# stretch, then ~2 minutes of silence before the next tune.
const MUSIC_PLAY_MIN: float = 180.0
const MUSIC_PLAY_MAX: float = 300.0
const MUSIC_SILENCE_MIN: float = 110.0  # quiet stretch between tracks (s)
const MUSIC_SILENCE_MAX: float = 130.0
const AMBIENT_ON_MIN: float = 60.0      # ambient beds breathe: on a while,
const AMBIENT_ON_MAX: float = 150.0     # then a long quiet stretch
const AMBIENT_OFF_MIN: float = 45.0
const AMBIENT_OFF_MAX: float = 120.0

# Map + minimap (CC-25)
const MAP_REVEAL_RADIUS: int = 14        # blocks revealed around the player
const MINIMAP_WINDOW: Vector2i = Vector2i(96, 56) # cells shown on the minimap
const MINIMAP_REFRESH_SECONDS: float = 0.25
const DAY_LENGTH_SECONDS: float = 600.0          # full day/night cycle
# --- Interior pockets (user request 2026-09-01; a 3-4 floor countdown was
# tried and reverted the same day - independent rolls clump and drought,
# which plays better): each floor rolls POCKET_CHANCE for an apartment
# doorway (random wing); it leads to a room of its own, carved in the VOID
# annex east of the city at the same rows (so depth/band stay true). Doors
# follow the GL-09 material ladder: wood through The Shallows (sometimes
# standing open, sometimes deadbolted - pry bar), chained metal below
# (bolt cutters or better).
const POCKET_CHANCE: float = 0.30        # a floor gets an interior doorway
const POCKET_OPEN_CHANCE: float = 0.40   # wood door found standing open (else one click opens it)
const POCKET_LOCK_CHANCE: float = 0.20   # wood door deadbolted (room_door_locked)
const POCKET_LOCK_TIER: int = 1          # pry bar or better forces a deadbolt
const POCKET_SEAL_CHANCE: float = 0.40   # submerged pocket kept its air (user: 40% dry)

const BAND_SHALLOWS_DEPTH: int = 40  # rows below the waterline where each band ends
const BAND_COLD_DEPTH: int = 120
const BAND_DARK_DEPTH: int = 220
# Cold/crush gates (CC-16, GL-12) — applied while submerged; drained rooms
# are safe (forward camps, GL-17). Suit stats lift them from M5 onward.
const COLD_SLOW_FACTOR: float = 0.65
const COLD_DPS: float = 2.0    # in The Dark without a cold-rated suit
const CRUSH_DPS: float = 25.0  # in The Crush without a crush-rated suit

# --- Enemies (M4, GD-01..29; stat tables live in data/enemies.json) ---
const ENEMY_WINDOW: Vector2i = Vector2i(140, 100) # records in this window (cells) run as nodes
const AGGRO_NIGHT_MULT: float = 1.5      # surface-band aggro radii grow at night (GD-29)
const ENEMY_TOUCH_COOLDOWN: float = 0.9  # seconds between contact hits on the player
const ENEMY_KNOCKBACK: float = 7.0 * BLOCK_SIZE  # px/s shove a contact hit gives the player
const ENEMY_HOP_BLOCKS: float = 2.2      # zombies mount small steps; no real climbing (GD-04)
# Edge sense (user request 2026-08-31, amends GD-04): ground enemies never
# walk off a ledge — chasers hold the edge, wanderers turn around. (Gap
# jumping was tried and dropped for now, same request.)
const ENEMY_POUND_INTERVAL: float = 1.0  # seconds between pounds on a blocking player block
const ENEMY_POUND_DAMAGE: float = 12.0   # per pound; player-placed blocks/doors only (GD-04)
const ENEMY_WANDER_SPEED: float = 0.35   # idle wander as a fraction of chase speed
const NIGHT_FLOATER_MAX: int = 5         # extra ambient floaters near a player at night (GD-29)
const NIGHT_FLOATER_INTERVAL: float = 12.0 # seconds between night-floater spawn attempts
const FISH_STOCK_MIN: int = 3            # hand-grab catches per school (GD-09/28)
const FISH_STOCK_MAX: int = 6
const FISH_GRAB_BLOCKS: float = 2.5      # swim this close to grab

# --- Combat (M4, GD-07/08, LT-01/16) ---
const MELEE_RANGE_BLOCKS: float = 2.5    # melee connects within this range of the player
const MELEE_AIM_SLOP_BLOCKS: float = 1.8 # and this close to the aim point
const MELEE_WATER_FACTOR: float = 0.5    # default melee speed factor while in water (GD-08)
const KNIFE_WATER_FACTOR: float = 0.85   # knives are the least penalized
const GUN_RANGE_BLOCKS: float = 26.0     # hitscan range; bullets stop at water (LT-01)
const SPEAR_SPEED: float = 22.0 * BLOCK_SIZE # bolt flight speed
const SPEAR_RANGE_BLOCKS: float = 20.0   # bolts drop as pickups past this
const BLEED_DPS: float = 1.5             # bleeding drip (GD-21)
const BLEED_DURATION: float = 18.0       # untreated bleed length; bandage/medkit cure instantly
const BLEED_CHANCE: float = 0.35         # per zombie/Drowned hit

# --- Death loop (CC-07): the backpack keeps everything; gear stays worn ---
const BACKPACK_PICKUP_DELAY: float = 1.5 # seconds before the dropped pack can be recovered

# --- Red moons (CC-14, GL-15, GD-23) ---
const RED_MOON_MIN_DAYS: int = 5
const RED_MOON_MAX_DAYS: int = 10
const RED_MOON_WAVE_INTERVAL: float = 25.0 # seconds between waves through the night
const RED_MOON_BASE_WAVE: int = 3          # walkers per wave per player...
const RED_MOON_WAVE_PER_DAY: float = 0.3   # ...plus this many per day survived (GD-23)
const RED_MOON_STAT_PER_DAY: float = 0.05  # wave hp/damage multiplier growth per day
const RED_MOON_SPAWN_MIN_BLOCKS: int = 16  # waves spawn this ring around each player
const RED_MOON_SPAWN_MAX_BLOCKS: int = 30
const RED_MOON_TINT := Color(1.0, 0.62, 0.58) # full-screen modulate while the moon is up

# --- Skills (CC-18) ---
const SKILL_XP_PER_LEVEL: float = 20.0
const SKILL_LEVELS_PER_PLAYER_LEVEL: int = 5
const XP_SWIM_PER_SECOND: float = 0.5
const XP_BUILD_PER_BLOCK: float = 1.0

# --- Camera (WS-18 amended 2026-08-31: centred on the player, smooth follow, wheel zoom) ---
const CAMERA_ZOOM_LEVELS: Array[float] = [0.5, 0.75, 1.0, 1.5, 2.0, 3.0] # multiplies the window's integer scale
const CAMERA_ZOOM_DEFAULT_INDEX: int = 2

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
