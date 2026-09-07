extends Node
## Net (autoload): the one place that knows whether this process is offline,
## the LAN host, or a client (docs/technical/Multiplayer.md §2-3). Everything
## else asks `Net.is_server()` / `Net.local_player()` instead of touching
## `multiplayer` directly, so a Steam transport later replaces this file.
##
## Step 2 (2026-09-05): the ENet listen server / client, the LAN beacon, the
## peer table, the build-id handshake and per-peer ping / byte counters live
## here. The child nodes are the RPC endpoints (identical paths on every peer):
##   Net/WorldSync  (scripts/net/world_sync.gd)  cells / water / objects / items / clock
##   Net/EnemySync  (scripts/net/enemy_sync.gd)  enemy records + state stream
##   Net/Snapshot   (scripts/net/snapshot.gd)    join snapshot chunks
##   Net/CharSync   (scripts/net/char_sync.gd)   per-character state + UI action requests
## Each is added in _ready() when its script exists, so the pieces can land
## independently. The script also works as a PLAIN node (not the autoload):
## lan_smoke instantiates two under subtrees with their own SceneMultiplayer,
## so everything here goes through `multiplayer` (this node's API) and the
## handshake never assumes /root/Net.

enum Mode { OFFLINE, HOST, CLIENT }
enum PeerState { CONNECTING, LOADING, READY }
enum JoinState { NONE, CONNECTING, HANDSHAKE, ACCEPTED, REFUSED }

const CITY_SCENE := "res://scenes/city/city.tscn"
const HELLO_TIMEOUT_S := 10.0   # a connected peer that never says hello is dropped
const WORLD_WAIT_S := 10.0      # a hello that arrives before the world is up waits this long
const BEACON_MAGIC := "SUNKENCITY"

## Build id carried by the beacon and the join handshake: mismatched builds
## are refused with a message, never allowed to desync.
var BUILD_ID: String = "%s/w%d/c%d" % [ProjectSettings.get_setting("application/config/version", "dev"),
	SaveGame.WORLD_VERSION, SaveGame.VERSION]

var mode: Mode = Mode.OFFLINE
## peer id -> {name: String, player: Player, state: PeerState, ping_ms: float,
##   char_state: Dictionary (host-held copy for resume), bytes_in/out: int}
## On a client the table mirrors the host's roster (name + ping) for the UI.
var peers: Dictionary = {}
var _local_player: Player = null
var pending_snapshot: Dictionary = {} # a joining client's world payload, consumed by city.gd
## Dev-arg handoff (--join=…): the Multiplayer screen runs this join on open.
var auto_join: Dictionary = {}

signal peer_accepted(peer_id: int, character_name: String) # host: a client passed the handshake
signal peer_left(peer_id: int)                              # host: a client disconnected / left
signal joined(peer_id: int)                                 # client: the host accepted us
signal join_failed(reason: String)                          # client: refused or unreachable
signal disconnected(reason: String)                         # client: connection lost / host closed
signal snapshot_progress(fraction: float)                   # client: world download progress
signal snapshot_ready(data: Dictionary)                     # client: full world payload received
signal status(text: String)                                 # client: join progress in plain words
signal roster_changed                                       # both: peers table changed (names/pings)
signal peer_ready(peer_id: int)                             # host: a client finished loading the world (WorldSync._ready_for_world)
signal notice(text: String)                                 # both: a session event for the HUD (joined / left / died), user request 2026-09-06

var world_sync: Node = null
var enemy_sync: Node = null
var snapshot: Node = null
var char_sync: Node = null
var player_spawn: Node = null

# --- Session state ---
var peer: ENetMultiplayerPeer = null
var port: int = Constants.LAN_PORT
var cap: int = Constants.NET_MAX_PLAYERS
var world_name: String = ""          # the world being hosted / joined (beacon + _accepted)
var host_character: String = ""
var local_character: String = ""     # this process's character name (host or client)
var ping_ms: float = 0.0             # client: our round trip to the host
var bytes_in_per_s: int = 0
var bytes_out_per_s: int = 0
var last_disconnect_reason: String = ""
## Test hooks (lan_smoke): plain-node instances skip the world-readiness
## check, the beacon and the sync children.
var require_world_ready: bool = true
var beacon_enabled: bool = true
var attach_sync_nodes: bool = true
var auto_enter_city: bool = true # client: change to city.tscn when the snapshot lands

var _join_state: JoinState = JoinState.NONE
var _pending_hello: Dictionary = {}   # peer id -> {build, name, char, deadline}
var _hello_deadline: Dictionary = {}  # peer id -> time a hello must arrive by
var _beacon: PacketPeerUDP = null
var _beacon_t := 0.0
var _stats_t := 0.0
var _closing_t := -1.0
var _signals_hooked := false

func _ready() -> void:
	if attach_sync_nodes:
		for pair in [["WorldSync", "res://scripts/net/world_sync.gd", "world_sync"],
				["EnemySync", "res://scripts/net/enemy_sync.gd", "enemy_sync"],
				["Snapshot", "res://scripts/net/snapshot.gd", "snapshot"],
				["CharSync", "res://scripts/net/char_sync.gd", "char_sync"],
				["PlayerSpawn", "res://scripts/net/player_spawn.gd", "player_spawn"]]:
			if ResourceLoader.exists(pair[1]):
				var n: Node = Node.new()
				n.name = pair[0]
				n.set_script(load(pair[1]))
				add_child(n)
				set(pair[2], n)
	snapshot_ready.connect(_on_snapshot_ready)

# --- Role queries ---

func is_server() -> bool:
	return mode != Mode.CLIENT

func is_client() -> bool:
	return mode == Mode.CLIENT

func is_online() -> bool:
	return mode != Mode.OFFLINE

func local_peer() -> int:
	if mode == Mode.OFFLINE or multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()

# --- Players ---

## The player this process controls and draws the UI for. Falls back to the
## first "player" group node so scenes without a Players container (the test
## tower, gates) keep working.
func local_player() -> Player:
	if _local_player != null and is_instance_valid(_local_player):
		return _local_player
	_local_player = null
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player") as Player

func register_local_player(p: Player) -> void:
	_local_player = p

func player_of(peer_id: int) -> Player:
	var e: Dictionary = peers.get(peer_id, {})
	var p = e.get("player")
	if p != null and is_instance_valid(p):
		return p
	if peer_id == local_peer():
		return local_player()
	return null

## Every live player body (host: all peers; client: all replicas).
func players() -> Array:
	var out: Array = []
	var tree := get_tree()
	if tree == null:
		return out
	for p in tree.get_nodes_in_group("player"):
		if p is Player:
			out.append(p)
	return out

func peer_state(peer_id: int) -> PeerState:
	return peers.get(peer_id, {}).get("state", PeerState.READY)

## Peers that finished loading the world (deltas go to these; loading peers
## get theirs queued by WorldSync until they report ready).
func ready_peers() -> Array:
	var out: Array = []
	for id in peers:
		if id != 1 and peers[id].get("state", PeerState.READY) == PeerState.READY:
			out.append(id)
	return out

## The peer's character name ("" when unknown).
func peer_name(peer_id: int) -> String:
	return String(peers.get(peer_id, {}).get("name", ""))

# --- World change hooks (Step 1: no-ops; Step 5/6 route them to the sync nodes) ---
# World calls these after every authoritative mutation. They must stay cheap
# offline: a single mode check.

func on_cell_changed(cell: Vector2i) -> void:
	if mode == Mode.HOST and world_sync != null:
		world_sync.on_cell_changed(cell)

func on_record_added(rec: Dictionary) -> void:
	if mode == Mode.HOST and world_sync != null:
		world_sync.on_record_added(rec)

func on_record_removed(rec: Dictionary) -> void:
	if mode == Mode.HOST and world_sync != null:
		world_sync.on_record_removed(rec)

## Any record field changed: open/powered/unlocked/outlet/grow_day/storage/link/door.
func on_record_changed(rec: Dictionary) -> void:
	if mode == Mode.HOST and world_sync != null:
		world_sync.on_record_changed(rec)

func on_record_replaced(old_rec: Dictionary, new_rec: Dictionary) -> void:
	if mode == Mode.HOST and world_sync != null:
		world_sync.on_record_replaced(old_rec, new_rec)

func on_item_spawned(item: Node) -> void:
	if mode == Mode.HOST and world_sync != null:
		world_sync.on_item_spawned(item)

## taker: the Player that picked it up (null when it despawned otherwise).
func on_item_removed(item: Node, taker: Node) -> void:
	if mode == Mode.HOST and world_sync != null:
		world_sync.on_item_removed(item, taker)

func on_backpack_spawned(pack: Node) -> void:
	if mode == Mode.HOST and world_sync != null:
		world_sync.on_backpack_spawned(pack)

func on_backpack_removed(pack: Node, taker: Node) -> void:
	if mode == Mode.HOST and world_sync != null:
		world_sync.on_backpack_removed(pack, taker)

func on_power_changed() -> void:
	if mode == Mode.HOST and world_sync != null:
		world_sync.on_power_changed()

## Cosmetic one-shots every peer should see: "puff" (break debris, arg = item id),
## "sfx" (arg = sfx name) — position in world px.
## A session event everyone should read (joined / left / died): shown on
## this screen and, while hosting, relayed reliably to every READY client.
func notice_all(text: String) -> void:
	notice.emit(text)
	if mode == Mode.HOST and world_sync != null and world_sync.has_method("send_notice"):
		world_sync.send_notice(text)

func on_effect(kind: String, pos: Vector2, arg: String) -> void:
	if mode == Mode.HOST and world_sync != null:
		world_sync.on_effect(kind, pos, arg)

func on_enemy_added(rec: Dictionary) -> void:
	if mode == Mode.HOST and enemy_sync != null:
		enemy_sync.on_enemy_added(rec)

func on_enemy_removed(rec: Dictionary) -> void:
	if mode == Mode.HOST and enemy_sync != null:
		enemy_sync.on_enemy_removed(rec)

## hp/flash/oneshot changes that the per-tick stream doesn't carry: "hurt", "died", "anim:<name>".
func on_enemy_event(rec: Dictionary, event: String) -> void:
	if mode == Mode.HOST and enemy_sync != null:
		enemy_sync.on_enemy_event(rec, event)

# --- Session control ---

## Open the listen server. `p_world_name` is what the beacon advertises and
## the handshake reports; `host_character` should be set (or passed via
## start_hosting) so the roster shows the host by name.
func host(p_port: int = Constants.LAN_PORT, p_cap: int = Constants.NET_MAX_PLAYERS, p_world_name: String = "") -> Error:
	if mode != Mode.OFFLINE:
		_teardown()
	var p := ENetMultiplayerPeer.new()
	# A couple of spare ENet slots above the cap: an over-cap joiner gets a
	# "world is full" reason from the handshake instead of a silent socket refusal.
	var err := p.create_server(p_port, p_cap + 2)
	if err != OK:
		push_warning("Net.host: create_server on port %d failed (%s)" % [p_port, error_string(err)])
		return err
	peer = p
	port = p_port
	cap = clampi(p_cap, 2, 16)
	world_name = p_world_name
	if host_character == "":
		host_character = local_character if local_character != "" else "host"
	local_character = host_character
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	peers = {1: _peer_entry(host_character, PeerState.READY, {})}
	_hook_signals()
	if beacon_enabled:
		_start_beacon()
	roster_changed.emit()
	return OK

## Connect to a host; the handshake runs on connection (see _hello).
func join(address: String, p_port: int, character_name: String) -> Error:
	if mode != Mode.OFFLINE:
		_teardown()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(address, p_port)
	if err != OK:
		push_warning("Net.join: create_client %s:%d failed (%s)" % [address, p_port, error_string(err)])
		return err
	peer = p
	port = p_port
	local_character = character_name
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	peers.clear()
	last_disconnect_reason = ""
	_join_state = JoinState.CONNECTING
	_hook_signals()
	_status("connecting to %s:%d" % [address, p_port])
	return OK

## Client: disconnect and go offline. Host: same as close_world().
func leave(reason: String = "") -> void:
	if mode == Mode.HOST:
		close_world(reason if reason != "" else "host closed the world")
		return
	last_disconnect_reason = reason
	_teardown()

## Host: hand every client its final character state, tell them why, then
## drop the connections (after a short flush so the message arrives).
func close_world(reason: String = "host closed the world") -> void:
	if mode != Mode.HOST:
		_teardown()
		return
	if char_sync != null and char_sync.has_method("push_final_states"):
		char_sync.push_final_states()
	if peer != null and multiplayer.multiplayer_peer == peer:
		for id in peers:
			if id != 1 and _peer_live(id):
				_host_closing.rpc_id(id, reason)
	_stop_beacon()
	mode = Mode.OFFLINE # the world stops broadcasting at once; sockets close shortly
	peers.clear()
	_pending_hello.clear()
	_hello_deadline.clear()
	_closing_t = 0.25
	roster_changed.emit()

## Menu / dev-arg entry: bank the pickers into SaveGame's handoff, open the
## server and boot the city like DIVE. `world` == "" means a new world from `seed`;
## `display_name` is the typed name for that new world (2026-09-06; "" = world_<seed>).
func start_hosting(world: String, seed_value: int, character: String, p_port: int = Constants.LAN_PORT,
		p_cap: int = Constants.NET_MAX_PLAYERS, display_name: String = "") -> Error:
	SaveGame.pending_world_name = ""
	if world != "":
		SaveGame.pending_world = world
	elif seed_value > 0:
		SaveGame.pending_seed = seed_value
		SaveGame.pending_world_name = display_name
	if character != "":
		SaveGame.pending_character = character
	host_character = character if character != "" else "host"
	# What the beacon says until the city scene is up (it then advertises the
	# scene's world_title): the saved world's display name, or the typed one.
	var wn := SaveGame.world_display_name(world) if world != "" else SaveGame.clean_world_name(display_name)
	if wn == "":
		wn = "world_%d" % (seed_value if seed_value > 0 else 1)
	var err := host(p_port, p_cap, wn)
	if err != OK:
		return err
	get_tree().change_scene_to_file.call_deferred(CITY_SCENE)
	return OK

## Menu / dev-arg entry: parse "ip[:port]" and join as `character`. The city
## boots by itself when the snapshot lands (auto_enter_city).
func start_joining(target: String, character: String) -> Error:
	var address := target.strip_edges()
	var p_port := Constants.LAN_PORT
	var colon := address.rfind(":")
	if colon > 0 and address.substr(colon + 1).is_valid_int():
		p_port = int(address.substr(colon + 1))
		address = address.substr(0, colon)
	if address == "":
		address = "127.0.0.1"
	if character.strip_edges() == "":
		join_failed.emit("pick or name a character first")
		return ERR_INVALID_PARAMETER
	return join(address, p_port, character.strip_edges())

# --- Internals: peer lifecycle ---

func _peer_entry(p_name: String, state: PeerState, char_state: Dictionary) -> Dictionary:
	return {"name": p_name, "player": null, "state": state, "ping_ms": 0.0,
		"char_state": char_state, "bytes_in": 0, "bytes_out": 0}

func _hook_signals() -> void:
	if _signals_hooked:
		return
	_signals_hooked = true
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _teardown() -> void:
	_stop_beacon()
	if peer != null:
		peer.close()
	if multiplayer.multiplayer_peer == peer:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new() # never null: is_multiplayer_authority() needs an id
	peer = null
	mode = Mode.OFFLINE
	peers.clear()
	_pending_hello.clear()
	_hello_deadline.clear()
	_join_state = JoinState.NONE
	_closing_t = -1.0
	ping_ms = 0.0
	roster_changed.emit()

func _on_peer_connected(id: int) -> void:
	print("[net] t=%.2f peer_connected %d (mode %d)" % [_now(), id, mode])
	if mode == Mode.HOST:
		var ep := peer.get_peer(id) if peer != null else null
		if ep != null:
			ep.set_timeout(32, Constants.NET_PEER_TIMEOUT_MS, Constants.NET_PEER_TIMEOUT_MS * 2)
		_hello_deadline[id] = _now() + HELLO_TIMEOUT_S
	elif mode == Mode.CLIENT and id == 1 and peer != null:
		var ep := peer.get_peer(1)
		if ep != null:
			ep.set_timeout(32, Constants.NET_PEER_TIMEOUT_MS, Constants.NET_PEER_TIMEOUT_MS * 2)

func _on_peer_disconnected(id: int) -> void:
	print("[net] t=%.2f peer_disconnected %d (mode %d)" % [_now(), id, mode])
	if mode == Mode.HOST:
		_pending_hello.erase(id)
		_hello_deadline.erase(id)
		if peers.has(id):
			notice_all("%s left the world" % String(peers[id].get("name", "someone")))
			peer_left.emit(id) # listeners read the entry (name, char_state) before it goes
			peers.erase(id)
			_send_roster()
			roster_changed.emit()
	elif mode == Mode.CLIENT:
		if peers.has(id):
			peers.erase(id)
			roster_changed.emit()

func _on_connected_to_server() -> void:
	if mode != Mode.CLIENT:
		return
	_join_state = JoinState.HANDSHAKE
	_status("handshake")
	var char_dict := SaveGame.read_character(local_character)
	_hello.rpc_id(1, BUILD_ID, local_character, char_dict)

func _on_connection_failed() -> void:
	if mode != Mode.CLIENT:
		return
	_status("could not reach the host")
	join_failed.emit("could not reach the host")
	_teardown()

func _on_server_disconnected() -> void:
	if mode != Mode.CLIENT:
		return
	var st := _join_state
	var reason := last_disconnect_reason
	if st == JoinState.REFUSED:
		pass # join_failed already went out with the host's reason
	elif st == JoinState.ACCEPTED:
		if reason == "":
			reason = "connection to the host was lost"
		_status(reason)
		disconnected.emit(reason)
	else:
		_status("the host dropped the connection")
		join_failed.emit("the host dropped the connection")
	_teardown()

func _status(text: String) -> void:
	print("[net] t=%.2f %s" % [_now(), text]) # the log carries the clock; the UI gets the bare text
	status.emit(text)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## True while `id` is a fully connected ENet peer (not mid-disconnect):
## sending to a closing peer logs "max channels: 0" errors.
func _peer_live(id: int) -> bool:
	if peer == null or not (id in multiplayer.get_peers()):
		return false
	var ep := peer.get_peer(id)
	return ep != null and ep.get_state() == ENetPacketPeer.STATE_CONNECTED

## The world name the beacon / _accepted advertise: the city scene's DISPLAY
## name (`world_title`, 2026-09-06), else its file key, else what host() got.
func _current_world_name() -> String:
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		for prop in ["world_title", "world_name"]:
			var wn = tree.current_scene.get(prop)
			if wn is String and wn != "":
				return wn
	return world_name

# --- Handshake RPCs (MultiplayerImpl §3) ---

## Client -> host: who we are. The host validates and answers with
## _accepted or _refused (then drops the connection).
@rpc("any_peer", "call_remote", "reliable")
func _hello(build: String, char_name: String, char_dict: Dictionary) -> void:
	if mode != Mode.HOST:
		return
	var id := multiplayer.get_remote_sender_id()
	_hello_deadline.erase(id)
	if build != BUILD_ID:
		_refuse(id, "different game build (host %s, you %s)" % [BUILD_ID, build])
		return
	if peers.size() >= cap:
		_refuse(id, "the world is full (%d/%d)" % [peers.size(), cap])
		return
	var clean := char_name.strip_edges()
	if clean == "":
		_refuse(id, "no character name")
		return
	for pid in peers:
		if String(peers[pid].name).to_lower() == clean.to_lower():
			_refuse(id, "a character named '%s' is already in this world" % clean)
			return
	for pid in _pending_hello:
		if pid != id and String(_pending_hello[pid].name).to_lower() == clean.to_lower():
			_refuse(id, "a character named '%s' is already joining" % clean)
			return
	if require_world_ready and not World.is_ready():
		_pending_hello[id] = {"build": build, "name": clean, "char": char_dict, "deadline": _now() + WORLD_WAIT_S}
		return
	_accept(id, clean, char_dict)

func _accept(id: int, char_name: String, char_dict: Dictionary) -> void:
	_pending_hello.erase(id)
	peers[id] = _peer_entry(char_name, PeerState.LOADING, char_dict)
	_accepted.rpc_id(id, id, _current_world_name())
	peer_accepted.emit(id, char_name)
	_send_roster()
	roster_changed.emit()
	if snapshot != null and snapshot.has_method("send_to"):
		snapshot.send_to(id)

func _refuse(id: int, reason: String) -> void:
	_pending_hello.erase(id)
	_refused.rpc_id(id, reason)
	if peer != null and id in multiplayer.get_peers():
		# Graceful: ENet's disconnect_later waits for the queued reason packet to
		# go out first (a plain disconnect resets the outgoing queue).
		var ep := peer.get_peer(id)
		if ep != null:
			ep.peer_disconnect_later()
		_hello_deadline[id] = _now() + 3.0 # belt and braces: force it if it lingers

@rpc("authority", "call_remote", "reliable")
func _accepted(peer_id: int, p_world_name: String) -> void:
	if mode != Mode.CLIENT:
		return
	_join_state = JoinState.ACCEPTED
	world_name = p_world_name
	peers[peer_id] = _peer_entry(local_character, PeerState.LOADING, {})
	_status("accepted into '%s' as peer %d - downloading world" % [p_world_name, peer_id])
	joined.emit(peer_id)
	roster_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _refused(reason: String) -> void:
	if mode != Mode.CLIENT:
		return
	_join_state = JoinState.REFUSED
	_status("refused: " + reason)
	join_failed.emit(reason)

@rpc("authority", "call_remote", "reliable")
func _host_closing(reason: String) -> void:
	if mode != Mode.CLIENT:
		return
	last_disconnect_reason = reason

## Host -> all: names + pings of everyone in the world, for the pause menu.
@rpc("authority", "call_remote", "reliable")
func _roster(rows: Array) -> void:
	if mode != Mode.CLIENT:
		return
	var seen := {}
	for row in rows:
		var id: int = row[0]
		seen[id] = true
		if not peers.has(id):
			peers[id] = _peer_entry(String(row[1]), PeerState.READY, {})
		peers[id].name = String(row[1])
		if id != local_peer():
			peers[id].ping_ms = float(row[2])
	for id in peers.keys():
		if not seen.has(id):
			peers.erase(id)
	roster_changed.emit()

func _send_roster() -> void:
	if mode != Mode.HOST or peer == null:
		return
	var rows: Array = []
	for id in peers:
		rows.append([id, String(peers[id].name), float(peers[id].ping_ms)])
	for id in peers:
		if id != 1 and _peer_live(id):
			_roster.rpc_id(id, rows)

@rpc("any_peer", "call_remote", "unreliable")
func _ping(t: int) -> void:
	_pong.rpc_id(multiplayer.get_remote_sender_id(), t)

@rpc("any_peer", "call_remote", "unreliable")
func _pong(t: int) -> void:
	var rtt := float(Time.get_ticks_msec() - t)
	var from := multiplayer.get_remote_sender_id()
	if mode == Mode.HOST and peers.has(from):
		peers[from].ping_ms = rtt
	elif mode == Mode.CLIENT:
		ping_ms = rtt
		var me := local_peer()
		if peers.has(me):
			peers[me].ping_ms = rtt

# --- Per-frame: beacon, pings, stats, deadlines ---

func _process(delta: float) -> void:
	if _closing_t >= 0.0:
		_closing_t -= delta
		if _closing_t < 0.0:
			_closing_t = -1.0
			_teardown()
		return
	if mode == Mode.OFFLINE or peer == null:
		return
	_stats_t += delta
	if _stats_t >= 1.0:
		_stats_t -= 1.0
		_tick_second()
	if mode == Mode.HOST:
		var now := _now()
		for id in _pending_hello.keys():
			var ph: Dictionary = _pending_hello[id]
			if not require_world_ready or World.is_ready():
				_accept(id, ph.name, ph.char)
			elif now > ph.deadline:
				_refuse(id, "the host is still loading its world - try again")
		for id in _hello_deadline.keys():
			if now > _hello_deadline[id]:
				_hello_deadline.erase(id)
				if id in multiplayer.get_peers():
					peer.disconnect_peer(id, true)
		if beacon_enabled:
			_beacon_t += delta
			if _beacon_t >= Constants.NET_BEACON_INTERVAL:
				_beacon_t = 0.0
				_send_beacon()

func _tick_second() -> void:
	# Byte counters: ENet's host totals since the last pop.
	if peer != null and peer.host != null:
		bytes_out_per_s = int(peer.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA))
		bytes_in_per_s = int(peer.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA))
	var t := Time.get_ticks_msec()
	if mode == Mode.HOST:
		for id in peers:
			if id != 1 and _peer_live(id):
				_ping.rpc_id(id, t)
		_send_roster()
	elif mode == Mode.CLIENT and _join_state == JoinState.ACCEPTED and _peer_live(1):
		_ping.rpc_id(1, t)
	roster_changed.emit()

# --- LAN beacon (host side; LanBrowser listens) ---

func _start_beacon() -> void:
	_stop_beacon()
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon_t = Constants.NET_BEACON_INTERVAL # first beacon on the next frame

func _stop_beacon() -> void:
	if _beacon != null:
		_beacon.close()
		_beacon = null

## "SUNKENCITY|<build>|<world>|<players>/<cap>|<port>"
func beacon_text() -> String:
	return "|".join(PackedStringArray([BEACON_MAGIC, BUILD_ID, _current_world_name(),
		"%d/%d" % [peers.size(), cap], str(port)]))

func _send_beacon() -> void:
	if _beacon == null:
		return
	var packet := beacon_text().to_utf8_buffer()
	for dest in ["255.255.255.255", "127.0.0.1"]:
		_beacon.set_dest_address(dest, Constants.LAN_BEACON_PORT)
		_beacon.put_packet(packet)

# --- Client: the snapshot landed -> boot the city from it ---

func _on_snapshot_ready(data: Dictionary) -> void:
	if mode != Mode.CLIENT:
		return
	pending_snapshot = data
	if local_character != "":
		SaveGame.pending_character = local_character
	_status("world received - entering")
	if auto_enter_city:
		get_tree().change_scene_to_file.call_deferred(CITY_SCENE)
