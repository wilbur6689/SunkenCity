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

# LAN identity (docs/technical/MultiplayerImpl.md §4-5): which peer owns this
# body, the character it plays, and that character's spawn in this world.
var peer_id: int = 1
var character_name: String = ""
var spawn_feet: Vector2 = Vector2.INF # GL-23: this character's bed; INF = the world default

func is_local() -> bool:
	return peer_id == Net.local_peer()

## Every player body on a client is a puppet driven by host state (Step 4).
func is_puppet() -> bool:
	return Net.is_client()

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
## Dev drivers (net_probe --net-harvest) aim without a mouse: INF = use the mouse.
var aim_override: Vector2 = Vector2.INF
const NO_HOTBAR_KEY := -99
var hotbar_select: int = NO_HOTBAR_KEY # NO_HOTBAR_KEY = no change this frame; Constants.WEAPON_HOTBAR = the weapon slot

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

## Net endpoint (LAN Step 4): child `Sync` (scripts/net/player_sync.gd),
## added by code so the test tower's $Player carries one too. Untyped: the
## script is loaded at runtime to keep Player <-> PlayerSync acyclic.
const SYNC_SCRIPT := "res://scripts/net/player_sync.gd"
var _sync: Node = null
# Puppet-only replicas of host-side facts the visuals need (remote bodies on
# a client have no inventory or interaction of their own).
var puppet_held: String = ""
var puppet_scrapping: bool = false
var puppet_scrap_progress: float = 0.0 # the host's Interaction.scrap_progress for this body (owner HUD bar)
var puppet_dying: bool = false
var puppet_lamp: bool = false  # LAN: a remote body's worn head lamp (state stream bit)
var puppet_suit: String = ""   # LAN: a remote body's suit id (tint), from the state stream

func _ready() -> void:
	_stand_shape.size = Constants.STAND_HITBOX
	_compact_shape.size = Constants.COMPACT_HITBOX
	_set_compact(false)
	_apply_zoom()
	if _sync == null and ResourceLoader.exists(SYNC_SCRIPT):
		_sync = Node.new()
		_sync.name = "Sync"
		_sync.set_script(load(SYNC_SCRIPT))
		add_child(_sync)
	interaction.view_only = is_puppet() # a client aims and previews; the host acts
	PlayerActions.attach(self) # LAN Step 7: the UI-action funnel child `Actions`
	if World.is_ready():
		respawn()

## Host relays to the owning client (remote bodies only; offline and for the
## host's own body every relay is a no-op).
func _relay() -> Node:
	return _sync if _sync != null and Net.mode == Net.Mode.HOST and not is_local() else null

## Put the feet at `feet` with no momentum (spawn, respawn on a puppet).
func place_at_feet(feet: Vector2) -> void:
	velocity = Vector2.ZERO
	global_position = feet - Vector2(0, FEET_Y)
	state = State.AIRBORNE
	fall_start_y = global_position.y
	camera.offset = Vector2.ZERO
	camera.reset_smoothing()
	reset_physics_interpolation()

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
	if dying: # death scene (user request 2026-09-01): 3 s of stillness -
		_tick_death(delta) # camera closing in, screen fading - then respawn
		if dying: # the body plays its death clip while the scene runs
			_update_sprite(delta)
		return
	if is_puppet(): # client: every body follows host state (LAN Step 4)
		_puppet_tick(delta)
		return
	if is_multiplayer_authority():
		_read_input()
	elif _sync != null:
		_sync.apply_input() # host: a remote peer's relayed snapshot (no-op offline)
	if Admin.noclip and is_local(): # F4 admin flight (2026-09-06): no state machine, no collision
		_admin_fly(delta)
		return
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
	if state == State.GROUNDED:
		_step_up()
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
	hotbar_select = NO_HOTBAR_KEY

## Admin no-clip flight (F4, scripts/dev/admin.gd): the local body drifts
## through everything at ADMIN_FLY_BLOCKS (sprint x2) - move keys, jump = up,
## crouch = down. Camera, sprite, hotbar and the interaction layer keep
## running so the tester can still look around and click things.
func _admin_fly(delta: float) -> void:
	var dir := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	if Input.is_action_pressed("jump"):
		dir.y -= 1.0
	if Input.is_action_pressed("crouch"):
		dir.y += 1.0
	var speed := Constants.ADMIN_FLY_BLOCKS * Constants.BLOCK_SIZE * (2.0 if Input.is_action_pressed("sprint") else 1.0)
	velocity = dir.limit_length(1.0) * speed
	global_position += velocity * delta
	_clamp_to_world_bounds()
	state = State.AIRBORNE
	fall_start_y = global_position.y
	oxygen = max_oxygen()
	drowning = false
	_tick_timers(delta)
	_apply_hotbar()
	_sense()
	_update_sprite(delta)
	_update_swing(delta)
	_update_camera(delta)
	interaction.tick(delta)
	wants_interact = false
	wants_drop = false
	hotbar_select = NO_HOTBAR_KEY

## Client-side body (LAN Step 4, MultiplayerImpl §5): no state machine, no
## move_and_slide, no vitals, no interaction ACTIONS - the host runs all of
## that and streams the result. The local puppet still reads input (and ships
## it), drives the camera/zoom/hotbar and aims in view-only mode; every puppet
## keeps its sprite, held tool and movement sounds from the replicated fields.
func _puppet_tick(delta: float) -> void:
	var local := is_local()
	if local and is_multiplayer_authority():
		_read_input()
		_apply_hotbar()
		if _sync != null:
			_sync.send_input() # before the one-frame flags clear below
	if _sync != null:
		_sync.apply_state(delta)
	_update_sprite(delta)
	_update_swing(delta)
	_update_move_sfx(delta)
	if local:
		_update_camera(delta)
		interaction.tick(delta) # view_only: target/hover/cursor/ghost, no actions
		if wants_drop:
			bare_hands = not bare_hands
			if bare_hands:
				message.emit("Hands free")
			elif held_item() != "":
				message.emit("Holding " + Data.item_name(held_item()))
	wants_interact = false
	wants_drop = false
	hotbar_select = NO_HOTBAR_KEY

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
	aim_position = aim_override if aim_override != Vector2.INF else get_global_mouse_position()
	# Key 1 = the weapon slot (user request 2026-09-06); keys 2..0 = hotbar
	# slots 1..9. The tenth hotbar slot is wheel/click only.
	if Input.is_action_just_pressed("hotbar_1"):
		hotbar_select = Constants.WEAPON_HOTBAR
	for i in range(1, Constants.HOTBAR_SLOTS):
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			hotbar_select = i - 1
	# View-only (not part of the replicated snapshot): wheel zoom.
	if Input.is_action_just_pressed("zoom_in"):
		zoom_step(1)
	if Input.is_action_just_pressed("zoom_out"):
		zoom_step(-1)

## True while a UI panel wants the mouse (set by the inventory UI); clicks
## on GUI controls (the hotbar) also stay out of the world.
var ui_blocks_mouse: bool = false
func ui_blocking() -> bool:
	if not is_local():
		return false # a remote body's clicks were already UI-filtered on its own machine
	return ui_blocks_mouse or get_viewport().gui_get_hovered_control() != null

## Bare mouse wheel cycles the hotbar while no menu is open (user request);
## Ctrl+wheel stays zoom, and menus consume their own wheel events.
func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or ui_blocks_mouse:
		return
	if event is InputEventMouseButton and event.pressed and not event.ctrl_pressed:
		# The wheel cycles weapon slot -> hotbar 1..10 -> weapon slot (11 stops).
		var n := Constants.HOTBAR_SLOTS + 1
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected_slot = posmod(selected_slot + 2, n) - 1
			bare_hands = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected_slot = posmod(selected_slot, n) - 1
			bare_hands = false

func _tick_timers(delta: float) -> void:
	if wants_jump:
		jump_buffer_timer = Constants.JUMP_BUFFER_TIME
		wants_jump = false
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

func _apply_hotbar() -> void:
	if hotbar_select != NO_HOTBAR_KEY:
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
	if puppet_held != "" and is_puppet() and not is_local():
		return puppet_held # a remote body on a client: what the host says it holds
	var s = held_stack()
	return s.id if s != null else ""

## The held stack dict (or null) — modifiers live on the instance (LT-05..07).
## An empty hand (Q, or an empty hotbar slot) holds the WORN weapon instead,
## so the weapon slot is what you fight with by default.
func held_stack():
	if bare_hands or selected_slot == Constants.WEAPON_HOTBAR:
		return equipped_weapon()
	var s = inventory.slots[selected_slot]
	return s if s != null else equipped_weapon()

## True when the hand is really empty (or the weapon slot is selected) and
## the worn weapon is standing in.
func holding_worn_weapon() -> bool:
	return equipped_weapon() != null and (bare_hands or selected_slot == Constants.WEAPON_HOTBAR \
		or inventory.slots[selected_slot] == null)

## The hotbar slot index the bag would read for the hand: the weapon slot
## maps to no bag slot (-1).
func hand_bag_slot() -> int:
	return selected_slot if selected_slot >= 0 else -1

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
		World.spawn_item(s.id, 1, global_position, Vector2(facing * 6.0 * Constants.BLOCK_SIZE, -4.0 * Constants.BLOCK_SIZE))
	inventory.remove_from_slot(slot, 1)
	play_action("use_item")

func drop_held(n: int) -> void:
	var id := held_item()
	if id == "" or holding_worn_weapon() or selected_slot < 0:
		return # the worn weapon comes off in the inventory screen, never by dropping
	var taken := inventory.remove_from_slot(selected_slot, n)
	World.spawn_item(id, taken, global_position, Vector2(facing * 8.0 * Constants.BLOCK_SIZE, -4.0 * Constants.BLOCK_SIZE))

# --- Equipment (LT-03: Suit + Head + two Accessories; accessory3/4 are the
# reserved mounts, opened by the Tool Harness / Rigger's Kit abilities;
# `weapon` (2026-09-05) is the worn weapon — see equipped_weapon()) ---
var equipment: Dictionary = {"head": null, "suit": null, "weapon": null,
	"accessory1": null, "accessory2": null, "accessory3": null, "accessory4": null}

func slot_unlocked(slot_name: String) -> bool:
	if slot_name == "accessory3" or slot_name == "accessory4":
		return skills.has_effect("unlock_slot", slot_name)
	return true

## Whether an item's kind belongs in a slot (no unlock check — shared with
## CharSync.sanitize). The weapon slot takes anything with a weapon block.
static func slot_fits(slot_name: String, id: String) -> bool:
	if slot_name == "weapon":
		return Data.item(id).has("weapon")
	var want: String = Data.item(id).get("slot", "")
	if want == "":
		return false
	if slot_name.begins_with("accessory"):
		return want == "accessory"
	return want == slot_name

func can_equip(slot_name: String, id: String) -> bool:
	return slot_unlocked(slot_name) and slot_fits(slot_name, id)

## The worn weapon (stack dict or null). It is what you fight with whenever
## the hotbar hand is empty — held_item()/held_stack() fall back to it — and,
## being equipment, its modifiers count as worn gear (equip_stat), so a
## Commercial suffix on a spear gun gives air while it is worn.
func equipped_weapon():
	return equipment.get("weapon")

func set_equipment(slot_name: String, stack) -> void:
	equipment[slot_name] = stack
	inventory.changed.emit() # equipment shows in the same UI refresh

func equipped(slot_name: String) -> String:
	var st = equipment.get(slot_name)
	return st.id if st != null else ""

func knows_recipe(id: String) -> bool:
	return known_recipes.has(id)

# --- Modification Bench (Modifiers.md "The Library": stock, not unlocks) ---
var mod_library: Dictionary = {} # mod id -> count in stock (sacrifice adds, apply/combine consume)

func library_count(mod_id: String) -> int:
	return int(mod_library.get(mod_id, 0))

func _library_add(mod_id: String, n: int) -> void:
	var c := library_count(mod_id) + n
	if c <= 0:
		mod_library.erase(mod_id)
	else:
		mod_library[mod_id] = c

## Learnable mods on this stack — duplicates always teach (the library is a
## stock count), only junk is refused. What the bench's LEARN offers.
func learnable_mods(stack: Dictionary) -> Array:
	var out := []
	var mods := ItemMods.mods_of(stack)
	for part in ["prefix", "suffix"]:
		if mods.has(part):
			var m: Dictionary = mods[part]
			if bool(ItemMods.def_of(m.id).get("learnable", false)):
				out.append(String(m.id))
	return out

## Sacrifice: the modded item is destroyed and each learnable mod on it adds
## one to the library. Returns the human-readable list of what was stocked.
func learn_mods(stack: Dictionary) -> Array:
	var learned := []
	for id in learnable_mods(stack):
		_library_add(id, 1)
		learned.append(ItemMods.describe_mod(id))
	return learned

## Applies library mods to an UNMODIFIED piece (then it is locked, LT-09).
## Up to one prefix + one suffix in a single operation (LT-07); each chosen
## id needs stock, the right slot and an `applies` match, and is consumed.
func apply_mods(stack: Dictionary, prefix_id: String, suffix_id: String) -> bool:
	var cls := ItemMods.mod_class(stack.id)
	if stack.has("mods") or cls == "":
		return false
	var mods := {}
	if prefix_id != "" and library_count(prefix_id) > 0 and ItemMods.slot_of(prefix_id) == "prefix" and ItemMods.applies_to(prefix_id, cls):
		mods["prefix"] = {"id": prefix_id}
	if suffix_id != "" and library_count(suffix_id) > 0 and ItemMods.slot_of(suffix_id) == "suffix" and ItemMods.applies_to(suffix_id, cls):
		mods["suffix"] = {"id": suffix_id}
	if mods.is_empty():
		return false
	for part in mods:
		_library_add(String(mods[part].id), -1)
	stack["mods"] = mods
	stack["count"] = 1
	inventory.changed.emit()
	return true

## COMBINE two library entries (same slot, same tier) into the recipe's
## result: two of one id climb the family's ladder, two families at one tier
## make the named hybrid. Consumes the inputs, stocks the result; returns
## the result id or "".
func combine_mods(a_id: String, b_id: String) -> String:
	var need_a := 2 if a_id == b_id else 1
	if library_count(a_id) < need_a or (a_id != b_id and library_count(b_id) < 1):
		return ""
	var result := ItemMods.combine_result(a_id, b_id)
	if result == "":
		return ""
	_library_add(a_id, -1)
	_library_add(b_id, -1)
	_library_add(result, 1)
	inventory.changed.emit()
	return result

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
		notify_gain(y.item, count - leftover)
		if leftover > 0:
			World.spawn_item(y.item, leftover, global_position)
	skills.add_xp("scrapping", float(obj_def.get("xp", 2)) * n)
	message.emit("Scrapped %s x%d%s" % [Data.item_name(id), n, "" if full else " (field yield)"])
	return true

## Tiered scrap benches (user request 2026-09-02): grind every collected
## FURNITURE object of `stage` in the bag down to its materials at once (full
## yield). Stage 5 (Master bench) takes any tier. Never touches tools, gear,
## materials, or functional objects (chests/beds/lamps/stations) you carry.
func bulk_scrap(stage: int) -> String:
	var to_scrap := {} # id -> total count
	var blocked := false
	for slot in inventory.slots:
		if slot == null:
			continue
		var id: String = slot.id
		if Data.item(id).get("category", "") != "placeable_object":
			continue
		var odef: Dictionary = Data.objects.get(id, {})
		if odef.get("kind", "") != "scrap":
			continue
		var istage := Data.item_scrap_stage(id)
		if istage < 1 or (stage < 5 and istage != stage):
			continue
		if skills.level("scrapping") < int(odef.get("skill", 0)):
			blocked = true
			continue
		to_scrap[id] = int(to_scrap.get(id, 0)) + int(slot.count)
	var total := 0
	for id: String in to_scrap:
		var n: int = to_scrap[id]
		for y in Data.scrap_yield(id):
			var count := roll_yield(int(y.count) * n)
			var leftover: int = inventory.add(y.item, count)
			notify_gain(y.item, count - leftover)
			if leftover > 0:
				World.spawn_item(y.item, leftover, global_position)
		inventory.remove(id, n)
		skills.add_xp("scrapping", float(Data.objects.get(id, {}).get("xp", 2)) * n)
		total += n
	if total == 0:
		return "Nothing here to grind down" + (" - needs a higher Scrapping skill" if blocked else "")
	Audio.play_world_sfx("dismantle_rattle", global_position)
	return "Ground down %d object%s to materials" % [total, "" if total == 1 else "s"]

func open_container(obj: WorldObject) -> void:
	var relay := _relay()
	if relay != null:
		relay.ev_container(obj.cell) # the owning client opens its UI on that record
		return
	container_opened.emit(obj)

func open_crafting(station: String) -> void:
	var relay := _relay()
	if relay != null:
		relay.ev_crafting(station)
		return
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
	# 32 quarter-block steps = 8 blocks of rescue: enough to climb out of a
	# slab-and-furniture stack when a restored position lands inside one
	# (user report 2026-09-01: "spawned in the floor and can't move").
	for i in 32:
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
		# Centre on the run first: a rope through a body-narrow hole leaves
		# the hitbox touching the hole's edge, and is_on_floor() would bounce
		# the climb straight back to GROUNDED (rope tops as platforms, 2026-09-06).
		global_position.x = World.climbable_center_x(below)
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

var _launch_pending: bool = false # a real jump: the launch one-shot (knockback also sends the body up)

func _jump() -> void:
	_launch_pending = true
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
	# Standing on a rope/ladder top that sits in a hole no wider than the body
	# (the body also touches the hole's edge, so is_on_floor() is true): down
	# still climbs through it (rope tops as platforms, 2026-09-06).
	if is_on_floor() and input_dir.y > 0.0 and climbable_below and not is_nan(_ladder_top_surface()):
		_enter_climbing()
		return
	if not is_on_floor():
		# Going down a ladder/rope (user request 2026-09-02): pressing down
		# while over a climbable grabs and descends it instead of falling -
		# whether standing on a ladder top or stepping off a ledge onto a rope.
		# (Gated on the down key so a fast shaft-drop into water still falls.)
		if input_dir.y > 0.0 and climbable_below:
			_enter_climbing()
			return
		var ladder_top := _ladder_top_surface()
		if not is_nan(ladder_top) and velocity.y >= 0.0:
			# Standing on a ladder top (not descending): pin to the surface.
			global_position.y = ladder_top - FEET_Y
			velocity.y = 0.0
			return
		if _step_down():
			return
		coyote_timer = Constants.COYOTE_TIME
		_enter_airborne()

# --- Steps (user request 2026-09-07): stairs of blocks are walked, not jumped ---

## After the move: walking into a ledge no taller than STEP_UP_CELLS lifts the
## body onto it. The probe is the standing hitbox raised by h and nudged one
## step forward - it must be clear, with solid ground under its front foot
## (a wall of any height fails the ground test and stays a wall).
func _step_up() -> void:
	if input_dir.x == 0.0 or not is_on_wall():
		return
	var size := Constants.COMPACT_HITBOX if compact else Constants.STAND_HITBOX
	var dir := 1.0 if input_dir.x > 0.0 else -1.0
	for h in range(1, Constants.STEP_UP_CELLS * Constants.BLOCK_SIZE + 1):
		var pos := global_position + Vector2(dir * 2.0, -h)
		if not World.rect_is_clear(Rect2(pos + Vector2(-size.x * 0.5, FEET_Y - size.y), size)):
			continue
		if not World.is_solid(pos + Vector2(dir * (size.x * 0.5 + 1.0), FEET_Y + 0.5)):
			continue
		global_position.y -= h
		velocity.y = 0.0
		return

## Before leaving the floor: a drop no deeper than STEP_UP_CELLS under a
## walking body is stepped down onto, so a staircase reads as ground both ways.
func _step_down() -> bool:
	if input_dir.x == 0.0 or velocity.y < 0.0:
		return false
	var size := Constants.COMPACT_HITBOX if compact else Constants.STAND_HITBOX
	for h in range(1, Constants.STEP_UP_CELLS * Constants.BLOCK_SIZE + 1):
		var pos := global_position + Vector2(0, h)
		if not World.rect_is_clear(Rect2(pos + Vector2(-size.x * 0.5, FEET_Y - size.y), size)):
			return false # something in the way below: not a step
		if World.is_solid(pos + Vector2(0, FEET_Y + 0.5)) or World.is_solid(pos + Vector2(size.x * 0.5 - 1.0, FEET_Y + 0.5)) \
				or World.is_solid(pos + Vector2(-size.x * 0.5 + 1.0, FEET_Y + 0.5)):
			global_position.y += h
			velocity.y = 0.0
			return true
	return false

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
	# Column exit. Hanging at the very top (center above the top rung) still
	# counts as on the ladder/rope so you can grab-and-hang from a ledge and
	# then descend (user request 2026-09-02); you only leave by reaching a
	# floor, topping out (pressing up off the top), or clearing the column.
	if not on_climbable and not climbable_below:
		if is_on_floor():
			state = State.GROUNDED
		else:
			_enter_airborne()
		return
	if not on_climbable and input_dir.y < 0.0:
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
	if input_dir.y > 0.0 and is_on_floor() and is_nan(_ladder_top_surface()):
		state = State.GROUNDED # reached the floor at the bottom (not merely brushing a hole's edge at the top)

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
	# Plunge drag (user report 2026-09-01): entry momentum from a fall
	# bleeds off hard, so a dive stops within a few blocks instead of
	# coasting to the bottom of a flooded shaft.
	if velocity.length() > Constants.UNDERWATER_SWIM_SPEED:
		velocity = velocity.move_toward(velocity.normalized() * Constants.UNDERWATER_SWIM_SPEED,
			Constants.WATER_PLUNGE_DECEL * delta)
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
	if Admin.no_death: # F4 admin: never drowns
		oxygen = max_oxygen()
		drowning = false
		return
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
	# Defence (Civil suffixes, gear stats) shaves a share off every bite.
	var mitigated := damage * maxf(Constants.DEFENSE_FLOOR, 1.0 - equip_stat("defense") * Constants.DEFENSE_PER_POINT)
	apply_damage(mitigated)
	if can_bleed and bleed_time <= 0.0 and randf() < Constants.BLEED_CHANCE and health > 0.0:
		start_bleeding()
	Audio.play_world_sfx("footstep_soft", global_position, 8, -4.0)

func start_bleeding() -> void:
	if Admin.no_death:
		return
	bleed_time = Constants.BLEED_DURATION
	message.emit("You are bleeding — bandage it!")

## Hit feedback (user request 2026-09-06): the screen flash is a timer the
## HUD drains (seconds left); the burst + thud happen where the body is.
var hurt_flash: float = 0.0
var death_marks: Array = [] # world positions where this body died this session (map dots)
var _hurt_fx_at_ms: int = -100000

func _hurt_fx(amount: float) -> void:
	if amount < Constants.HURT_FX_MIN_DAMAGE:
		return # drains tick per frame: no strobing
	var now := Time.get_ticks_msec()
	if now - _hurt_fx_at_ms < int(Constants.HURT_FX_COOLDOWN * 1000.0):
		return
	_hurt_fx_at_ms = now
	play_action("hurt") # the flinch (the action byte relays it to puppets)
	World.spawn_break_puff(_center_point(), "blood") # replicated to clients as a puff effect
	Audio.play_world_sfx("player_hurt", global_position, 3, -2.0) # relayed to clients
	flash_hurt()
	var relay := _relay()
	if relay != null:
		relay.ev_hurt() # the owning client flashes its own screen

## The red screen flash (local screens only; a relayed client calls this itself).
func flash_hurt() -> void:
	if is_local():
		hurt_flash = Constants.HURT_FLASH_SECONDS

func apply_damage(amount: float) -> void:
	if dying:
		return # the body on the ground takes no further hits
	if Admin.no_death: # F4 admin: nothing hurts
		health = Constants.MAX_HEALTH
		return
	combat_timer = 0.0
	health = maxf(health - amount, 0.0)
	_hurt_fx(amount)
	if health <= 0.0:
		_die()

## Death loop (CC-07): the whole bag transfers to a backpack that floats up
## from where you fell (or pins under a flooded ceiling); worn gear stays on
## the body. Respawn at the bed (GL-23), swim back down, touch to recover.
func _die() -> void:
	death_marks.append(_center_point())
	if Net.is_online():
		Net.notice_all("%s died" % character_name)
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
	_begin_death_scene()
	var relay := _relay()
	if relay != null:
		relay.ev_died() # the owning client plays the scene on its own screen

## Death scene (user request 2026-09-01): the UI clears, the camera slowly
## closes in on the body, the screen fades to black over DEATH_SCENE_SECONDS,
## and only then the respawn happens (with a quick fade back in).
var dying := false
var _death_t := 0.0
var _death_zoom_from := Vector2.ONE
var _death_fade: ColorRect = null

func _begin_death_scene() -> void:
	if dying:
		return
	dying = true
	_death_t = 0.0
	velocity = Vector2.ZERO
	_death_zoom_from = camera.zoom
	if not is_local():
		return # host simulating a remote body: no fade on THIS screen (relayed instead)
	if _death_fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 90 # above the HUD, below nothing that matters mid-death
		_death_fade = ColorRect.new()
		_death_fade.color = Color(0, 0, 0, 0)
		_death_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_death_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_death_fade)
		add_child(layer)
	_death_fade.color.a = 0.0

func _tick_death(delta: float) -> void:
	_death_t += delta
	var t := clampf(_death_t / Constants.DEATH_SCENE_SECONDS, 0.0, 1.0)
	var zoom_t := minf(t / 0.85, 1.0) # the zoom lands just before full black
	var z := lerpf(1.0, Constants.DEATH_SCENE_ZOOM, zoom_t * zoom_t * (3.0 - 2.0 * zoom_t))
	camera.zoom = _death_zoom_from * z
	if _death_fade != null:
		_death_fade.color.a = clampf((t - 0.45) / 0.5, 0.0, 1.0)
	if _death_t >= Constants.DEATH_SCENE_SECONDS:
		dying = false
		camera.zoom = _death_zoom_from
		if is_puppet():
			# The host decides where we wake up (_ev_respawn); until it lands
			# the body stays put and the state stream carries it.
			if _sync != null:
				_sync.reset_interp()
		else:
			respawn()
		if _death_fade != null:
			var tw := create_tween() # eyes open at the bed
			tw.tween_property(_death_fade, "color:a", 0.0, 0.5)

func respawn() -> void:
	play_action("wake_bed") # sit up and stand (the world start too)
	health = Constants.MAX_HEALTH
	oxygen = max_oxygen()
	drowning = false
	bleed_time = 0.0
	combat_timer = 999.0
	velocity = Vector2.ZERO
	_set_compact(false)
	var feet: Vector2 = spawn_feet if spawn_feet != Vector2.INF else World.spawn_position
	global_position = feet - Vector2(0, FEET_Y)
	state = State.AIRBORNE
	fall_start_y = global_position.y
	camera.offset = Vector2.ZERO
	camera.reset_smoothing()
	reset_physics_interpolation()
	var relay := _relay()
	if relay != null:
		relay.ev_respawn(feet)

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
	reset_physics_interpolation()
	World.refresh_objects_around(global_position)
	unstick()
	var relay := _relay()
	if relay != null:
		relay.ev_travel(global_position + Vector2(0, FEET_Y)) # after unstick: the settled spot

# --- Camera (WS-18) ---

# --- Sprite (assets/sprites/player.png: 32x32, row 0 east / row 1 west, col 0 idle, cols 1-6 walk) ---

const WALK_FRAMES: int = 6
const WALK_FRAME_TIME: float = 0.1 # seconds per frame at walk speed; scales with actual speed

var facing: int = 1 # +1 east, -1 west

# Movement sounds: footsteps paced by ground distance, a splash on hitting
# water (volume scales with entry speed).
var _step_dist: float = 0.0
var _was_in_water: bool = false
var _splash_cooldown: float = 0.0

func _update_move_sfx(delta: float) -> void:
	_splash_cooldown = maxf(_splash_cooldown - delta, 0.0)
	var stride := Constants.FOOTSTEP_STRIDE_BLOCKS * Constants.BLOCK_SIZE
	if state == State.GROUNDED and absf(velocity.x) > 1.0 * Constants.BLOCK_SIZE:
		_step_dist += absf(velocity.x) * delta
		if _step_dist >= stride:
			_step_dist = 0.0
			Audio.play_sfx("footstep_wood", _feet_point(), 12, -8.0)
	elif state == State.CRAWLING and velocity.length() > 0.8 * Constants.BLOCK_SIZE:
		_step_dist += velocity.length() * delta
		if _step_dist >= stride:
			_step_dist = 0.0
			Audio.play_sfx("footstep_soft", _feet_point(), 8, -2.0)
	else:
		_step_dist = stride * 0.6 # first step lands quickly when moving resumes
	if in_water and not _was_in_water and _splash_cooldown <= 0.0:
		var speed := velocity.length()
		if speed > 3.0 * Constants.BLOCK_SIZE:
			_splash_cooldown = 0.4
			var vol := clampf(-18.0 + speed / (12.0 * Constants.BLOCK_SIZE) * 18.0, -18.0, 0.0)
			Audio.play_sfx("splash", _feet_point(), 5, vol)
	_was_in_water = in_water

# Tool swing (user request): the held tool arcs in front of the player on
# each hammer hit so breaking your own blocks reads as an action.
var _swing_time: float = 0.0
var _scrap_anim: float = 0.0
var _tool_sprite: Sprite2D = null

## 32x32 authored icons ride in the hand at 16 px (2026-09-01).
func _fit_tool_sprite() -> void:
	if _tool_sprite.texture != null and _tool_sprite.texture.get_width() > Data.ICON_PX:
		_tool_sprite.scale = Vector2.ONE * (float(Data.ICON_PX) / _tool_sprite.texture.get_width())
	else:
		_tool_sprite.scale = Vector2.ONE

func play_swing() -> void:
	if _tool_sprite == null:
		_tool_sprite = Sprite2D.new()
		_tool_sprite.z_index = 1
		add_child(_tool_sprite)
	_tool_sprite.texture = Data.icon(held_item())
	_fit_tool_sprite()
	_swing_time = Constants.TOOL_SWING_TIME

func _update_swing(delta: float) -> void:
	_attack_time = maxf(_attack_time - delta, 0.0)
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
			_fit_tool_sprite()
			_tool_sprite.visible = true
			if _attack_time > 0.0:
				# Weapon swing (user request 2026-09-07): wind back, sweep
				# around the head, ease home - see _attack_pose.
				_scrap_anim = 0.0
				_attack_pose(1.0 - _attack_time / _attack_total, float(attack_dir))
			elif puppet_scrapping or (interaction != null and interaction.scrapping != null):
				# Harvest chop (user request 2026-09-01): wind back, arc over
				# the head, pull down onto the resource, repeat.
				_scrap_anim += delta / CHOP_CYCLE_TIME
				_chop_pose(fposmod(_scrap_anim, 1.0), 1.0 if facing >= 0 else -1.0)
			else:
				# Ready stance (user request 2026-09-02): the icon flipped and
				# rotated ~90 deg down, so the tool hangs at the mid-section.
				_scrap_anim = 0.0
				_apply_rest_pose(1.0 if facing >= 0 else -1.0)
		else:
			_tool_sprite.visible = false
		return
	# One-shot swing (a single hammer hit): one chop toward the aim point.
	_swing_time = maxf(_swing_time - delta, 0.0)
	var t := 1.0 - _swing_time / Constants.TOOL_SWING_TIME
	_tool_sprite.visible = true
	_chop_pose(0.45 + 0.55 * t, 1.0 if aim_position.x >= global_position.x else -1.0) # from mid-lift: chop + hold

## The harvest chop (user request 2026-09-01; rebuilt on the grip-held blade
## 2026-09-07, user request "up, swing, chop, repeat" with less backward
## travel): the tool RISES in front of the body to straight over the head
## (phase 0-0.6, ease in-out), CHOPS down fast onto the resource out front
## (0.6-0.85, ease-in), and holds the impact (0.85-1.0) before the next lift.
## Angles are blade angles in facing-right space (see _place_blade); grips are
## local px from the body origin. `dir` = +1 facing right.
const CHOP_CYCLE_TIME := 0.55 # seconds per harvest chop
const CHOP_RAISE := 0.6       # phase fraction spent lifting
const CHOP_STRIKE := 0.85     # .. by here the blade is down; the rest is the impact hold
const CHOP_TOP_ANGLE := -1.75 # ~100 deg: straight up, a hair back
const CHOP_END_ANGLE := 1.05  # ~60 deg below level: driven into the resource out front
const CHOP_TOP_HAND := Vector2(4.0, -9.0)  # grip at the shoulder: the tip peaks about head height (user request 2026-09-07)
const CHOP_END_HAND := Vector2(10.0, -2.0) # grip out front at the hip, arm extended

func _chop_pose(ph: float, dir: float) -> void:
	var geo := _tool_geometry(dir)
	var phi: float
	var hand: Vector2
	if ph < CHOP_RAISE:
		var w := ph / CHOP_RAISE
		w = w * w * (3.0 - 2.0 * w)
		phi = lerpf(CHOP_END_ANGLE, CHOP_TOP_ANGLE, w) # up through the front, never behind
		hand = CHOP_END_HAND.lerp(CHOP_TOP_HAND, w)
	elif ph < CHOP_STRIKE:
		var w := (ph - CHOP_RAISE) / (CHOP_STRIKE - CHOP_RAISE)
		w = w * w
		phi = lerpf(CHOP_TOP_ANGLE, CHOP_END_ANGLE, w)
		hand = CHOP_TOP_HAND.lerp(CHOP_END_HAND, w)
	else:
		phi = CHOP_END_ANGLE
		hand = CHOP_END_HAND
	_place_blade(phi, hand, dir, geo)

## Resting held pose (user request 2026-09-02): the tool icon flipped
## horizontally and rotated 90 deg down toward the mid-section, so it hangs
## in the hand instead of resting on the head.
const TOOL_REST_ROT := PI * 0.5 - 0.14 # ~82 deg: the icon flipped and rotated down toward the mid-section
const TOOL_REST_SHRINK := 0.85

func _apply_rest_pose(dir: float) -> void:
	# ~82 deg, not a flat 90: tilted back counter-clockwise so the handle
	# reads level in the hand (user request 2026-09-02); slightly scaled down.
	var ang := TOOL_REST_ROT * dir
	_tool_sprite.rotation = ang
	_tool_sprite.flip_h = dir > 0
	_tool_sprite.scale *= TOOL_REST_SHRINK
	_tool_sprite.z_index = 1
	_tool_sprite.position = _rest_centre(dir)

## Where the rest pose puts the sprite's centre (local px, facing `dir`).
func _rest_centre(dir: float) -> Vector2:
	var ang := TOOL_REST_ROT * dir
	var head := Vector2(sin(ang), -cos(ang))
	var pos := Vector2(dir * 3.0, 0.0) + head * 3.0 + _hand_delta()
	if Data.item(held_item()).has("weapon"):
		pos.y -= Constants.WEAPON_REST_LIFT_PX # weapons ride higher in the hand (user request 2026-09-07)
	if state == State.SURFACE_SWIM:
		pos.y += Constants.SURFACE_SPRITE_SINK_PX
	return pos

## Hand tracker (user request 2026-09-07): how far the current sheet frame's
## hand sits from the idle frame's (local px, already in the facing row), from
## data/hand_anchors.json (tools/gen_hand_anchors.py scans the sheet for the
## forearm). The resting tool rides it, so the weapon swings with the arm.
func _hand_delta() -> Vector2:
	if sprite == null or sprite.rotation != 0.0:
		return Vector2.ZERO
	if clip != "idle" and clip != "walk": # a composed clip: its per-frame anchor from player_anim.json
		var anchors: Array = _clip_def(clip).get("anchors", [])
		var fi: int = sprite.frame_coords.x
		if fi < 0 or fi >= anchors.size() or anchors[fi] == null:
			return Vector2.ZERO
		var d := Vector2(float(anchors[fi][0]), float(anchors[fi][1])) - CLIP_REST_HAND
		if facing < 0:
			d.x = -d.x
		return d
	var row: Array = Data.hand_anchors.get("east" if sprite.frame_coords.y == 0 else "west", [])
	var f: int = sprite.frame_coords.x
	if f < 0 or f >= row.size() or row.is_empty():
		return Vector2.ZERO
	return Vector2(float(row[f][0]) - float(row[0][0]), float(row[f][1]) - float(row[0][1]))

# --- Weapon swing (user request 2026-09-07) ---
# Three phases traced from the user's mark-up of the resting sword: (1) the
# blade rotates counter-clockwise up over the head to lie flat behind the
# player at the hip (medium-fast), (2) it sweeps clockwise all the way around
# the head and down to the ground in front as one quick chop (fast), (3) it
# eases home to the ready stance (slow-medium). The whole thing lasts one
# attack interval, so the next swing can start the instant it ends; the sweep
# is the hit window (Interaction._tick_arc). Angles are screen radians in
# facing-right space (0 = forward, -PI/2 = up), mirrored for `attack_dir` -1;
# the weapon is held by the icon's grip (Data.icon_axis) so every blade,
# whatever the artist drew, traces the same arc.
var _attack_time: float = 0.0   # seconds left in the swing (synced to puppets)
var _attack_total: float = 0.0  # its full length = the attack interval
var attack_dir: int = 1         # the side swung at, locked at the start
var _attack_phi: float = 0.0    # current blade angle (facing-right space)
var _attack_hand: Vector2 = Vector2.ZERO # current grip position, local px (mirrored)

const ATTACK_WIND := 0.28           # phase fractions: wind-back ..
const ATTACK_SWEEP := 0.24          # .. the sweep (the rest is the return)
const ATTACK_SWEEP_START := -PI     # flat behind the player
const ATTACK_SWEEP_END := 0.95      # down to the ground in front (~55 deg below level; user request 2026-09-07 - ground monsters were out of the arc)
# Grip points are local px from the body origin, which sits ~6 px BELOW the
# sprite's middle (the hip is about y=0, the shoulder about y=-10).
# The sweep's grip path runs ~1.5x farther out than the arm's rest reach (user
# request 2026-09-07: extend the reach) - the arm at full stretch.
const ATTACK_WIND_HAND := Vector2(-6.0, 1.0)   # grip back at the hip, arm extended behind
const ATTACK_RAISE_HAND := Vector2(1.0, -44.0) # bezier control: the grip passes just over the head
const ATTACK_FRONT_HAND := Vector2(12.0, 0.0)  # grip out front at hip height, the blade driven at the floor

func play_attack(total: float) -> void:
	if _tool_sprite == null:
		_tool_sprite = Sprite2D.new()
		_tool_sprite.z_index = 1
		add_child(_tool_sprite)
	_tool_sprite.texture = Data.icon(held_item())
	_fit_tool_sprite()
	_attack_total = maxf(total, 0.05)
	_attack_time = _attack_total
	_swing_time = 0.0
	if is_puppet() and not is_local():
		attack_dir = facing
	else:
		attack_dir = 1 if aim_position.x >= global_position.x else -1
	_attack_pose(0.0, float(attack_dir))

## Blade geometry for the held icon: the flipped texture axis (the paper doll
## draws facing-right tools flipped), the draw scale, the grip offset and the
## rest pose expressed as a blade angle + grip position.
func _tool_geometry(dir: float) -> Dictionary:
	var ax := Data.icon_axis(held_item())
	var base := 1.0
	if _tool_sprite.texture != null and _tool_sprite.texture.get_width() > Data.ICON_PX:
		base = float(Data.ICON_PX) / _tool_sprite.texture.get_width()
	var s := base * TOOL_REST_SHRINK
	var alpha_f := -PI - float(ax.angle) # flip_h mirrors the drawn axis about the vertical
	var hilt: Vector2 = ax.hilt
	if dir > 0:
		hilt.x = -hilt.x # flip_h mirrors the texture in place
	# The rest pose's grip: its centre plus the rotated grip offset, un-mirrored.
	var rest_ang := TOOL_REST_ROT * dir
	var rest_centre := _rest_centre(dir)
	var rest_hand := rest_centre + hilt.rotated(rest_ang) * s
	rest_hand.x *= dir
	if state == State.SURFACE_SWIM:
		rest_hand.y -= Constants.SURFACE_SPRITE_SINK_PX
	return {"alpha_f": alpha_f, "s": s, "hilt": hilt, "length": float(ax.length) * s,
		"phi_rest": alpha_f + TOOL_REST_ROT, "rest_hand": rest_hand}

## Put the grip on `hand` (local px, facing-right space) with the blade along `phi`.
func _place_blade(phi: float, hand: Vector2, dir: float, geo: Dictionary) -> void:
	var rot := (phi - float(geo.alpha_f)) * dir
	_tool_sprite.rotation = rot
	_tool_sprite.flip_h = dir > 0
	_tool_sprite.scale = Vector2.ONE * float(geo.s)
	var pos := Vector2(hand.x * dir, hand.y)
	if state == State.SURFACE_SWIM:
		pos.y += Constants.SURFACE_SPRITE_SINK_PX
	_attack_hand = pos
	_attack_phi = phi
	_tool_sprite.position = pos - (geo.hilt as Vector2).rotated(rot) * float(geo.s)
	# Pointing back = behind the body (the user's "rotate behind the player").
	_tool_sprite.z_index = -1 if cos(phi) < -0.5 else 1

func _attack_pose(t: float, dir: float) -> void:
	var geo := _tool_geometry(dir)
	var phi_rest: float = geo.phi_rest
	var rest_hand: Vector2 = geo.rest_hand
	var phi: float
	var hand: Vector2
	if t < ATTACK_WIND:
		var w := t / ATTACK_WIND
		w = w * w * (3.0 - 2.0 * w)
		phi = lerpf(phi_rest, ATTACK_SWEEP_START, w) # counter-clockwise: up over the head, down behind
		hand = rest_hand.lerp(ATTACK_WIND_HAND, w)
	elif t < ATTACK_WIND + ATTACK_SWEEP:
		var w := (t - ATTACK_WIND) / ATTACK_SWEEP
		phi = lerpf(ATTACK_SWEEP_START, ATTACK_SWEEP_END, w) # clockwise, constant speed: the chop
		var a := ATTACK_WIND_HAND.lerp(ATTACK_RAISE_HAND, w)
		var b := ATTACK_RAISE_HAND.lerp(ATTACK_FRONT_HAND, w)
		hand = a.lerp(b, w)
	else:
		var w := (t - ATTACK_WIND - ATTACK_SWEEP) / (1.0 - ATTACK_WIND - ATTACK_SWEEP)
		w = w * w * (3.0 - 2.0 * w)
		phi = lerpf(ATTACK_SWEEP_END, phi_rest, w)
		hand = ATTACK_FRONT_HAND.lerp(rest_hand, w)
	_place_blade(phi, hand, dir, geo)

## The sweep's blade angle this tick (facing-right space), NAN outside the
## sweep phase; ATTACK_SWEEP_END through the return so the last slice lands.
func attack_sweep_angle() -> float:
	if _attack_time <= 0.0 or _attack_total <= 0.0:
		return NAN
	var t := 1.0 - _attack_time / _attack_total
	if t < ATTACK_WIND:
		return NAN
	if t < ATTACK_WIND + ATTACK_SWEEP:
		return lerpf(ATTACK_SWEEP_START, ATTACK_SWEEP_END, (t - ATTACK_WIND) / ATTACK_SWEEP)
	return ATTACK_SWEEP_END

func attack_hand_global() -> Vector2:
	return global_position + _attack_hand

## Grip-to-tip length of the drawn blade in world px.
func attack_blade_px() -> float:
	if _tool_sprite == null:
		return float(Data.ICON_PX) * TOOL_REST_SHRINK
	return float(_tool_geometry(float(attack_dir)).length)

var _lamp_dot: Sprite2D = null

## Visible gear (WS-26, first pass per WS-25 tint layers): the sprite is
## tinted by the worn suit tier ("tint" in items.json) and a lit pip marks a
## worn head lamp; the held tool renders in hand (see _update_swing).
func _update_gear_visuals() -> void:
	var remote := is_puppet() and not is_local() # a remote body on a client has no equipment replica
	var tint: Array = Data.item(puppet_suit if remote else equipped("suit")).get("tint", [])
	sprite.modulate = Color(tint[0], tint[1], tint[2]) if tint.size() == 3 else Color.WHITE
	var head_light := puppet_lamp if remote else (equipment.get("head") != null and float(Data.item(equipped("head")).get("stats", {}).get("light", 0)) > 0.0)
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

# --- Clips (2026-09-07, character-animation skill) ---
# The composed locomotion sheet assets/sprites/player_clips.png (48x32 cells,
# one row per clip, drawn facing RIGHT; data/player_anim.json describes rows,
# frame counts, fps, holds and the per-frame hand anchor) plays for every
# state the hand-drawn sheet has no frames for. `idle` (the rest frame) and
# `walk` stay on player.png with its hand-drawn west row; every other clip
# mirrors with flip_h. Picked by name from state + velocity + flags, so LAN
# puppets (state and velocity are replicated) derive the same clip.
const CLIP_SHEET: Texture2D = preload("res://assets/sprites/player_clips.png")
const LEGACY_SHEET: Texture2D = preload("res://assets/sprites/player.png")
const CLIP_REST_HAND := Vector2(23.0, 22.0) # the rest frame's hand inside the 48x32 cell (rest frame centred)
var clip: String = "idle"
var _clip_time: float = 0.0
var _oneshot: String = ""        # jump_launch / land in flight
# Action clips (2026-09-07): use_item / place / interact / pick_up are one-shots
# started by the action itself (play_action; the host relays the id to puppets);
# harvest_chop / weapon_swing are PHASE-DRIVEN from the tool's own animation, so
# body and tool never drift apart; aim_shoot holds its aim frame while a ranged
# weapon is held and plays its recoil frames on a shot.
const ACTION_CLIPS := ["", "use_item", "place", "interact", "pick_up", "hurt", "wake_bed"] # index = the sync byte
var _action_clip: String = ""
var _action_left: float = 0.0
var _oneshot_left: float = 0.0
var _prev_state: State = State.AIRBORNE

func _clip_def(clip_name: String) -> Dictionary:
	return Data.player_anim.get("clips", {}).get(clip_name, {})

## Seconds a clip runs once (holds included).
func _clip_length(def: Dictionary) -> float:
	var fps := maxf(float(def.get("fps", 8)), 0.1)
	var hold: Dictionary = def.get("hold", {})
	var total := 0.0
	for i in int(def.get("frames", 1)):
		total += float(hold.get(str(i), 1.0)) / fps
	return total

## Frame index `t` seconds into a clip (holds stretch frames; loops wrap).
func _clip_frame(def: Dictionary, t: float) -> int:
	var fps := maxf(float(def.get("fps", 8)), 0.1)
	var n := int(def.get("frames", 1))
	var hold: Dictionary = def.get("hold", {})
	var total := _clip_length(def)
	if def.get("loop", false) and total > 0.0:
		t = fmod(t, total)
	var acc := 0.0
	for i in n:
		acc += float(hold.get(str(i), 1.0)) / fps
		if t < acc:
			return i
	return n - 1

## Which clip the body shows now, from state + velocity (priority: the
## one-shot in flight, then movement, then idle - death/hurt clips come later).
func _pick_clip(moving: bool, speed: float) -> String:
	# Reactions (2026-09-07): the death scene and drowning outrank every state.
	if dying or puppet_dying:
		return "death_water" if in_water else "death_land"
	if state == State.UNDERWATER and drowning:
		return "drowning"
	match state:
		State.GROUNDED:
			if not moving:
				return "idle"
			return "sprint" if speed > Constants.WALK_SPEED * 1.15 else "walk"
		State.AIRBORNE:
			return "rise" if velocity.y < 0.0 else "fall"
		State.CRAWLING:
			return "crawl" if moving else "prone_idle"
		State.CLIMBING:
			if moving:
				return "climb"
			# Stopped with nothing to grab above the head: hanging from the top of the run.
			return "climb_idle" if World.is_climbable(_center_point() + Vector2(0, -8.0)) else "climb_hang"
		State.SURFACE_SWIM:
			return "prone_swim" if moving else "tread_water"
		State.UNDERWATER:
			return "prone_swim" if moving else "underwater_float"
	return "idle"

## Start an action one-shot (upper-body actions; the body plays it over the
## grounded stance). No-op when the clip is missing from the sheet.
func play_action(clip_name: String) -> void:
	var def := _clip_def(clip_name)
	if def.is_empty():
		return
	_action_clip = clip_name
	_action_left = _clip_length(def)
	if clip != clip_name:
		clip = clip_name
		_clip_time = 0.0

func action_index() -> int:
	return ACTION_CLIPS.find(_action_clip) if _action_left > 0.0 else 0

func _ranged_in_hand() -> bool:
	var w: Dictionary = Data.item(held_item()).get("weapon", {})
	return not w.is_empty() and not w.get("melee", false)

func _tool_in_hand() -> bool:
	var it := Data.item(held_item())
	return it.has("tool") or it.has("weapon")

func _chopping() -> bool:
	return puppet_scrapping or (interaction != null and interaction.scrapping != null) \
			or (_swing_time > 0.0 and not _ranged_in_hand())

## The harvest chop's phase (0-1), shared with _chop_pose's cycle so the body
## frame matches the tool: the scrap loop, or the one-shot hammer hit's tail.
func _chop_phase() -> float:
	if puppet_scrapping or (interaction != null and interaction.scrapping != null):
		return fposmod(_scrap_anim, 1.0)
	return 0.45 + 0.55 * (1.0 - _swing_time / Constants.TOOL_SWING_TIME)

## "cold" / "crush" while standing in that band without the suit for it
## (the status loops; a remote puppet has no suit replica: its suit id decides).
func _exposed_band() -> String:
	var band: String = World.band_at(World.cell_at(_center_point()))
	if band != "cold" and band != "crush":
		return ""
	var protection := suit_stat(band)
	if is_puppet() and not is_local():
		protection = float(Data.item(puppet_suit).get("stats", {}).get(band, 0.0))
	if protection >= 1.0 or _clip_def(band + ("_shiver" if band == "cold" else "_strain")).is_empty():
		return ""
	return band

func _start_oneshot(clip_name: String) -> void:
	var def := _clip_def(clip_name)
	if def.is_empty():
		return
	_oneshot = clip_name
	_oneshot_left = _clip_length(def)
	clip = clip_name
	_clip_time = 0.0

func _set_sheet(tex: Texture2D, hframes: int, vframes: int) -> void:
	if sprite.texture != tex:
		sprite.texture = tex
		sprite.hframes = hframes
		sprite.vframes = vframes

func _show_clip_frame() -> void:
	var def := _clip_def(clip)
	if clip == "idle" or clip == "walk" or def.is_empty():
		_set_sheet(LEGACY_SHEET, 7, 2)
		var col := 0
		if clip == "walk":
			col = 1 + int(_clip_time / WALK_FRAME_TIME) % WALK_FRAMES
		sprite.frame_coords = Vector2i(col, 0 if facing > 0 else 1)
		sprite.flip_h = false
		return
	var cell: Array = Data.player_anim.get("cell", [48, 32])
	_set_sheet(CLIP_SHEET, int(CLIP_SHEET.get_width() / int(cell[0])), int(CLIP_SHEET.get_height() / int(cell[1])))
	sprite.frame_coords = Vector2i(_clip_frame(def, _clip_time), int(def.get("row", 0)))
	sprite.flip_h = facing < 0

func _update_sprite(delta: float) -> void:
	if input_dir.x != 0.0:
		facing = 1 if input_dir.x > 0.0 else -1
	_update_gear_visuals()
	var speed := absf(velocity.x) if (state == State.GROUNDED or state == State.SURFACE_SWIM) else velocity.length()
	var moving := speed > 1.0 * Constants.BLOCK_SIZE
	# One-shots ride the transitions: a jump's launch (anticipation is instant
	# in the sim, so the crouch+push plays over the first airborne frames) and
	# the landing squash after a fall of more than two blocks.
	if state != _prev_state:
		if state == State.AIRBORNE and _launch_pending:
			_start_oneshot("jump_launch")
		elif state == State.GROUNDED and _prev_state == State.AIRBORNE \
				and global_position.y - fall_start_y > 2.0 * Constants.BLOCK_SIZE:
			_start_oneshot("land")
		_prev_state = state
	if state != State.AIRBORNE:
		_launch_pending = false
	var want := _pick_clip(moving, speed)
	if _oneshot != "":
		_oneshot_left -= delta
		var fits := (_oneshot == "land" and state == State.GROUNDED) \
				or (_oneshot == "jump_launch" and state == State.AIRBORNE)
		if _oneshot_left <= 0.0 or not fits:
			_oneshot = ""
		else:
			want = _oneshot
	if _action_left > 0.0:
		_action_left -= delta
		if _action_left <= 0.0 or (_action_clip == "wake_bed" and moving):
			_action_clip = "" # moving off the bed ends the wake-up early
	if _action_clip == "hurt" and not dying and not puppet_dying:
		want = "hurt" # a hit interrupts everything but death, on the ground or knocked into the air
	# Actions ride the grounded stance (priority: attack > chop > action > aim > carry).
	if state == State.GROUNDED and _oneshot == "" and not dying and not puppet_dying:
		if _action_clip == "hurt":
			pass # already chosen above
		elif _attack_time > 0.0 and not _clip_def("weapon_swing").is_empty():
			want = "weapon_swing"
		elif _chopping() and not _clip_def("harvest_chop").is_empty():
			want = "harvest_chop"
		elif _action_clip != "":
			want = _action_clip
		elif not moving and _ranged_in_hand() and not _clip_def("aim_shoot").is_empty():
			want = "aim_shoot"
		elif not moving and _exposed_band() != "":
			want = "cold_shiver" if _exposed_band() == "cold" else "crush_strain"
		elif not moving and _tool_in_hand() and not _clip_def("tool_carry").is_empty():
			want = "tool_carry"
	if want != clip:
		var same_stride := (want == "walk" and clip == "sprint") or (want == "sprint" and clip == "walk")
		if not same_stride: # walk <-> sprint keep their phase; anything else restarts
			_clip_time = 0.0
		clip = want
	var rate := 1.0
	match clip:
		"walk":
			rate = clampf(speed / Constants.WALK_SPEED, 0.5, 2.0)
		"sprint":
			rate = clampf(speed / Constants.SPRINT_SPEED, 0.5, 1.5)
		"climb":
			rate = clampf(speed / Constants.CLIMB_SPEED, 0.5, 1.5)
		"crawl":
			rate = clampf(speed / Constants.CRAWL_SPEED, 0.5, 1.5)
	match clip: # phase-driven clips take their time from the tool animation
		"weapon_swing":
			_clip_time = (1.0 - _attack_time / maxf(_attack_total, 0.05)) * _clip_length(_clip_def(clip))
		"harvest_chop":
			_clip_time = clampf(_chop_phase(), 0.0, 0.999) * _clip_length(_clip_def(clip))
		"aim_shoot":
			var def := _clip_def(clip)
			var f0 := float(def.get("hold", {}).get("0", 1.0)) / maxf(float(def.get("fps", 8)), 0.1)
			if _swing_time > 0.0: # a shot: the recoil frames after the held aim frame
				_clip_time = f0 + (1.0 - _swing_time / Constants.TOOL_SWING_TIME) * (_clip_length(def) - f0) * 0.999
			else:
				_clip_time = 0.0
		_:
			_clip_time += delta * rate
	_show_clip_frame()
	sprite.rotation = 0.0
	# Feet on the cell's bottom row at local y = FEET_Y (prone clips are drawn
	# lying on that row, so the old 90-degree body rotation is gone).
	sprite.position = Vector2(0, FEET_Y - 16.0 * Constants.PLAYER_SPRITE_SCALE)
	if state == State.SURFACE_SWIM:
		# Chest-high waterline while treading (user request).
		sprite.position.y += Constants.SURFACE_SPRITE_SINK_PX

var zoom_index: int = Constants.CAMERA_ZOOM_DEFAULT_INDEX

## Camera stays centred on the player (smooth follow only, no lookahead).
func _update_camera(_delta: float) -> void:
	camera.offset = Vector2.ZERO
	if not dying: # the death scene drives the zoom itself
		_apply_zoom() # re-apply each frame so a UI-size change takes effect live

## Camera zoom, divided by the UI scale so that enlarging the UI (via the
## engine's content_scale_factor, which scales the whole canvas) leaves the
## world the same apparent size (user request 2026-09-02).
func _apply_zoom() -> void:
	var z: float = Constants.CAMERA_ZOOM_LEVELS[zoom_index] / maxf(UIScale.content_scale(), 0.01)
	camera.zoom = Vector2(z, z)

func zoom_step(direction: int) -> void:
	zoom_index = clampi(zoom_index + direction, 0, Constants.CAMERA_ZOOM_LEVELS.size() - 1)
	_apply_zoom()

func state_name() -> String:
	return State.keys()[state]

## Left-side gain feed (user request 2026-09-01): materials gained from
## harvesting queue here; the HUD drains the list and shows icon + count.
var gain_feed: Array = []

func notify_gain(id: String, count: int) -> void:
	if count <= 0 or Data.item(id).get("category", "") != "material":
		return
	var relay := _relay()
	if relay != null:
		relay.ev_gain(id, count) # only the owner's HUD drains a feed
		return
	gain_feed.append({"id": id, "count": count})
