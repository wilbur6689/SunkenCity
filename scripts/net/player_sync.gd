class_name PlayerSync
extends Node
## Per-player network endpoint (LAN Step 4, docs/technical/MultiplayerImpl.md
## §5): child `Sync` of every Player, added by Player._ready() so the RPC path
## is `.../Players/<peer_id>/Sync` on every machine. Three flows:
##
##   client -> host   `_in(seq, packed)`  the owner's input snapshot, every
##                    physics tick, unreliable-ordered (12 bytes)
##   host -> all      `_st(packed)`       this body's state, every tick,
##                    unreliable (28 bytes); puppets interpolate toward it
##   host -> owner    `_ev_*`             reliable one-shots the owning client
##                    plays locally: messages, gain feed, container/crafting
##                    UI, portal travel, death scene, respawn
##
## Offline (and in the gates, which drive a peer-2 authority player by hand)
## none of this runs: every entry point checks Net.mode first.
##
## Input packet (little-endian):
##   0  int8   input_dir.x * 127      1  int8   input_dir.y * 127
##   2  u8     bits: 1 jump · 2 sprint · 4 crouch · 8 use · 16 use_secondary
##             · 32 interact · 64 bare_hands
##   3  u8     selected_slot
##   4  f32    aim_position.x         8  f32    aim_position.y
## State packet:
##   0  f32 pos.x   4 f32 pos.y   8 f32 vel.x   12 f32 vel.y
##   16 u8  state (bits 0-2) · compact<<3 · facing east<<4 · in_water<<5
##          · submerged<<6 · on_climbable<<7
##   17 u8  drowning 1 · dying 2 · scrapping 4
##   18 f16 health   20 f16 oxygen   22 f16 bleed_time   24 f16 swing_time
##   26 u16 held item index (Data.items key order; 0xFFFF = empty hands)
##   28 u16 suit item index   30 u8 scrap progress * 255 (the owner's HUD bar)
##   31 f16 attack_time   33 f16 attack_total   35 u8 action clip id (Player.ACTION_CLIPS)

const IN_BYTES := 12
const ST_BYTES := 36 # +4 (2026-09-07): weapon attack remaining/total as halves; +1 the action clip id
const NO_ITEM := 0xFFFF
## Beyond this the puppet snaps instead of sliding (respawn, portal, lag spike).
const SNAP_DIST_PX := 6.0 * Constants.BLOCK_SIZE
## Host: a remote body whose input went silent this long stops moving (held
## flags would otherwise walk it into a wall while its client is stalled).
const INPUT_STALE_TICKS := 30

var player: Player
## Set by Net/PlayerSpawn once `_spawn_player` for this body went out (host)
## or arrived (client): until both ends have the node, owner events, the
## state stream and the input stream stay quiet.
var announced: bool = false
## Packets this endpoint received (host: inputs from the owner; client: states) - F3/diagnostics.
var packets_in: int = 0

# --- client -> host input ---
var _seq_out: int = 0
var _seq_in: int = -1
var _in_dir: Vector2 = Vector2.ZERO
var _in_held: int = 0          # sprint/crouch/use/use_secondary bits of the last packet
var _in_aim: Vector2 = Vector2.ZERO
var _in_slot: int = 0
var _in_bare: bool = false
var _jump_pending: bool = false
var _interact_pending: bool = false
var _in_age: int = INPUT_STALE_TICKS # ticks since the last packet

# --- host -> client state (puppet interpolation) ---
var _have_state: bool = false
var _from_pos: Vector2 = Vector2.ZERO
var _to_pos: Vector2 = Vector2.ZERO
var _lerp_t: float = 1.0

static var _item_ids: Array = [] # Data.items keys, same order on every build

func _ready() -> void:
	player = get_parent() as Player
	if Net.mode == Net.Mode.HOST and player != null and not player.is_local():
		# Relay what the simulated body says to the client that owns it.
		player.message.connect(ev_message)

# --- Host: state stream, after the parent simulated this tick ---

func _physics_process(_delta: float) -> void:
	if Net.mode != Net.Mode.HOST or player == null:
		return
	if not announced and not player.is_local(): # the host's own body always streams
		return
	_in_age += 1
	var spawn: Node = Net.player_spawn
	if spawn == null:
		return
	var packed := _pack_state()
	for pid in Net.ready_peers():
		if spawn.stream_ok(pid, player.peer_id):
			_st.rpc_id(pid, packed)

# --- Client (local puppet): send the input snapshot ---

## Called by the local puppet right after _read_input(), before the one-frame
## flags are cleared (Player._puppet_tick).
func send_input() -> void:
	if Net.mode != Net.Mode.CLIENT or player == null or not player.is_local() or not announced:
		return
	if multiplayer.multiplayer_peer == null or not (1 in multiplayer.get_peers()):
		return
	_seq_out += 1
	var b := PackedByteArray()
	b.resize(IN_BYTES)
	b.encode_s8(0, int(round(clampf(player.input_dir.x, -1.0, 1.0) * 127.0)))
	b.encode_s8(1, int(round(clampf(player.input_dir.y, -1.0, 1.0) * 127.0)))
	var bits := 0
	if player.wants_jump: bits |= 1
	if player.wants_sprint: bits |= 2
	if player.wants_crouch: bits |= 4
	if player.wants_use: bits |= 8
	if player.wants_use_secondary: bits |= 16
	if player.wants_interact: bits |= 32
	if player.bare_hands: bits |= 64
	b.encode_u8(2, bits)
	b.encode_u8(3, 255 if player.selected_slot == Constants.WEAPON_HOTBAR else clampi(player.selected_slot, 0, 254))
	b.encode_float(4, player.aim_position.x)
	b.encode_float(8, player.aim_position.y)
	_in.rpc_id(1, _seq_out, b)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _in(seq: int, packed: PackedByteArray) -> void:
	if Net.mode != Net.Mode.HOST or player == null:
		return
	if multiplayer.get_remote_sender_id() != player.peer_id:
		return # only the owner drives this body
	if seq <= _seq_in or packed.size() < IN_BYTES:
		return # stale / malformed
	if _seq_in < 0:
		print("[net] input stream open from peer %d (%s)" % [player.peer_id, player.character_name])
	_seq_in = seq
	packets_in += 1
	_in_dir = Vector2(packed.decode_s8(0) / 127.0, packed.decode_s8(1) / 127.0)
	var bits := packed.decode_u8(2)
	_in_held = bits
	if bits & 1:
		_jump_pending = true
	if bits & 32:
		_interact_pending = true
	_in_bare = bits & 64 != 0
	var raw_slot := packed.decode_u8(3)
	_in_slot = Constants.WEAPON_HOTBAR if raw_slot == 255 else clampi(raw_slot, 0, Constants.INVENTORY_SLOTS - 1)
	_in_aim = Vector2(packed.decode_float(4), packed.decode_float(8))
	_in_age = 0

## Host, each physics tick of a REMOTE player (Player._physics_process, in
## place of _read_input): write the last snapshot into the input fields. Held
## flags persist between packets; one-frame flags fire once.
func apply_input() -> void:
	if Net.mode != Net.Mode.HOST or player == null or player.is_local():
		return
	if _in_age >= INPUT_STALE_TICKS:
		player.input_dir = Vector2.ZERO
		player.wants_sprint = false
		player.wants_crouch = false
		player.wants_use = false
		player.wants_use_secondary = false
	else:
		player.input_dir = _in_dir
		player.wants_sprint = _in_held & 2 != 0
		player.wants_crouch = _in_held & 4 != 0
		player.wants_use = _in_held & 8 != 0
		player.wants_use_secondary = _in_held & 16 != 0
	player.wants_jump = _jump_pending
	player.wants_interact = _interact_pending
	_jump_pending = false
	_interact_pending = false
	player.aim_position = _in_aim
	player.selected_slot = _in_slot
	player.bare_hands = _in_bare
	player.wants_drop = false # Q is folded into bare_hands client-side
	player.hotbar_select = Player.NO_HOTBAR_KEY # the snapshot already carries selected_slot (-1 would now mean the weapon slot)

# --- Host -> all: per-tick state ---

static func _held_index(id: String) -> int:
	if _item_ids.is_empty():
		_item_ids = Data.items.keys()
	if id == "":
		return NO_ITEM
	var i := _item_ids.find(id)
	return i if i >= 0 else NO_ITEM

static func _held_id(index: int) -> String:
	if _item_ids.is_empty():
		_item_ids = Data.items.keys()
	return String(_item_ids[index]) if index >= 0 and index < _item_ids.size() else ""

func _pack_state() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(ST_BYTES)
	b.encode_float(0, player.global_position.x)
	b.encode_float(4, player.global_position.y)
	b.encode_float(8, player.velocity.x)
	b.encode_float(12, player.velocity.y)
	var b0 := int(player.state) & 7
	if player.compact: b0 |= 8
	if player.facing > 0: b0 |= 16
	if player.in_water: b0 |= 32
	if player.submerged: b0 |= 64
	if player.on_climbable: b0 |= 128
	b.encode_u8(16, b0)
	var b1 := 0
	if player.drowning: b1 |= 1
	if player.dying: b1 |= 2
	if player.interaction != null and player.interaction.scrapping != null: b1 |= 4
	if player.equipment.get("head") != null and float(Data.item(player.equipped("head")).get("stats", {}).get("light", 0)) > 0.0:
		b1 |= 8 # worn head lamp: a fog beacon + lamp pip on every client
	b.encode_u8(17, b1)
	b.encode_half(18, player.health)
	b.encode_half(20, player.oxygen)
	b.encode_half(22, player.bleed_time)
	b.encode_half(24, player._swing_time)
	b.encode_u16(26, _held_index(player.held_item()))
	b.encode_u16(28, _held_index(player.equipped("suit")))
	var prog := player.interaction.scrap_progress if player.interaction != null else 0.0
	b.encode_u8(30, int(clampf(prog, 0.0, 1.0) * 255.0))
	b.encode_half(31, player._attack_time) # the weapon swing (2026-09-07): remaining + total
	b.encode_half(33, player._attack_total)
	b.encode_u8(35, player.action_index()) # use/place/interact/pick_up one-shot in flight
	return b

@rpc("authority", "call_remote", "unreliable")
func _st(packed: PackedByteArray) -> void:
	if Net.mode != Net.Mode.CLIENT or player == null or packed.size() < ST_BYTES:
		return
	if packets_in == 0:
		print("[net] state stream open for peer %d (%s)" % [player.peer_id, player.character_name])
	packets_in += 1
	var pos := Vector2(packed.decode_float(0), packed.decode_float(4))
	player.velocity = Vector2(packed.decode_float(8), packed.decode_float(12))
	var b0 := packed.decode_u8(16)
	player.state = (b0 & 7) as Player.State
	var compact := b0 & 8 != 0
	if compact != player.compact:
		player._set_compact(compact)
	player.facing = 1 if b0 & 16 else -1
	player.in_water = b0 & 32 != 0
	player.submerged = b0 & 64 != 0
	player.on_climbable = b0 & 128 != 0
	var b1 := packed.decode_u8(17)
	player.drowning = b1 & 1 != 0
	player.puppet_dying = b1 & 2 != 0
	player.puppet_scrapping = b1 & 4 != 0
	player.puppet_lamp = b1 & 8 != 0
	player.health = packed.decode_half(18)
	player.oxygen = packed.decode_half(20)
	player.bleed_time = packed.decode_half(22)
	var swing := packed.decode_half(24)
	if swing > player._swing_time:
		player._swing_time = swing # a fresh hammer hit; the local decay carries it
	player.puppet_held = _held_id(packed.decode_u16(26))
	player.puppet_suit = _held_id(packed.decode_u16(28))
	player.puppet_scrap_progress = packed.decode_u8(30) / 255.0
	var attack := packed.decode_half(31)
	if attack > player._attack_time: # a fresh weapon swing; the local decay carries it
		player._attack_time = attack
		player._attack_total = maxf(packed.decode_half(33), 0.05)
		player.attack_dir = player.facing
	var aid := packed.decode_u8(35)
	if aid > 0 and aid < Player.ACTION_CLIPS.size() and player._action_clip != Player.ACTION_CLIPS[aid]:
		player.play_action(Player.ACTION_CLIPS[aid])
	# Interpolation: slide from where the puppet is now to the new host
	# position over one tick; a big jump (respawn, portal, lag) snaps.
	if not _have_state or player.global_position.distance_to(pos) > SNAP_DIST_PX:
		_have_state = true
		player.global_position = pos
		_from_pos = pos
		_to_pos = pos
		_lerp_t = 1.0
		player.reset_physics_interpolation()
	else:
		_from_pos = player.global_position
		_to_pos = pos
		_lerp_t = 0.0

## Client, each physics tick of every puppet (Player._puppet_tick): advance
## the slide toward the last host position.
func apply_state(delta: float) -> void:
	if Net.mode != Net.Mode.CLIENT or player == null or not _have_state:
		return
	if _lerp_t < 1.0:
		_lerp_t = minf(_lerp_t + delta * Constants.NET_TICK_HZ, 1.0)
		player.global_position = _from_pos.lerp(_to_pos, _lerp_t)

## Client: the host moved this body somewhere else on purpose (respawn,
## portal) - restart the slide from there.
func reset_interp() -> void:
	_have_state = false

# --- Host -> owner: one-shot events (reliable) ---

func _relaying() -> bool:
	return Net.mode == Net.Mode.HOST and player != null and not player.is_local() and announced \
		and Net.player_spawn != null and Net.player_spawn.peer_spawned(player.peer_id)

func ev_message(text: String) -> void:
	if _relaying():
		_ev_message.rpc_id(player.peer_id, text)

func ev_say(text: String) -> void:
	if _relaying():
		_ev_say.rpc_id(player.peer_id, text)

func ev_gain(id: String, n: int) -> void:
	if _relaying():
		_ev_gain.rpc_id(player.peer_id, id, n)

func ev_container(cell: Vector2i) -> void:
	if _relaying():
		_ev_container.rpc_id(player.peer_id, cell)

func ev_crafting(station: String) -> void:
	if _relaying():
		_ev_crafting.rpc_id(player.peer_id, station)

func ev_travel(feet: Vector2) -> void:
	if _relaying():
		_ev_travel.rpc_id(player.peer_id, feet)

func ev_died() -> void:
	if _relaying():
		_ev_died.rpc_id(player.peer_id)

func ev_hurt() -> void:
	if _relaying():
		_ev_hurt.rpc_id(player.peer_id)

func ev_respawn(feet: Vector2) -> void:
	if _relaying():
		_ev_respawn.rpc_id(player.peer_id, feet)

func _owner_event() -> bool:
	return Net.mode == Net.Mode.CLIENT and player != null and player.is_local()

@rpc("authority", "call_remote", "reliable")
func _ev_message(text: String) -> void:
	if _owner_event():
		player.message.emit(text)

## Interaction.say() texts (the hover/action line), kept apart from the
## message signal so the HUD shows them where it always did.
@rpc("authority", "call_remote", "reliable")
func _ev_say(text: String) -> void:
	if _owner_event() and player.interaction != null:
		player.interaction.say(text)

@rpc("authority", "call_remote", "reliable")
func _ev_gain(id: String, n: int) -> void:
	if _owner_event():
		player.notify_gain(id, n)

@rpc("authority", "call_remote", "reliable")
func _ev_container(cell: Vector2i) -> void:
	if not _owner_event():
		return
	var obj := World.object_at(cell)
	if obj == null:
		World.refresh_objects_around(player.global_position)
		obj = World.object_at(cell)
	if obj != null:
		player.container_opened.emit(obj)

@rpc("authority", "call_remote", "reliable")
func _ev_crafting(station: String) -> void:
	if _owner_event():
		player.crafting_opened.emit(station)

@rpc("authority", "call_remote", "reliable")
func _ev_travel(feet: Vector2) -> void:
	if _owner_event():
		reset_interp()
		player.travel_to(feet)

@rpc("authority", "call_remote", "reliable")
func _ev_died() -> void:
	if _owner_event():
		player.death_marks.append(player.global_position) # map dot (user request 2026-09-06)
		player._begin_death_scene()

@rpc("authority", "call_remote", "reliable")
func _ev_hurt() -> void:
	if _owner_event():
		player.flash_hurt()

@rpc("authority", "call_remote", "reliable")
func _ev_respawn(feet: Vector2) -> void:
	if _owner_event():
		reset_interp()
		player.place_at_feet(feet)
