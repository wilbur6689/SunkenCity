extends Node
## Net/PlayerSpawn (LAN Step 4, docs/technical/MultiplayerImpl.md §3.5/§4):
## the host spawns a body for every client that finished loading the world
## and tells every client which bodies exist. Created by Net._ready() as a
## child of Net, so the RPC path is /root/Net/PlayerSpawn on every machine.
##
## Host:   Net.peer_ready(id)  -> Players.spawn_for(id) + character state +
##         spawn point, then `_spawn_player` to every ready peer (and, to the
##         new peer, one per body that already exists - the host's included).
##         Net.peer_left(id)   -> Players.remove_for(id) + `_despawn_player`.
## Client: `_spawn_player` builds the puppet (its own = the local puppet,
##         registered as the local player); `_despawn_player` removes it.
##
## The host's own body is spawned by city.gd at boot; a client's own body is
## created ONLY here, once the host has it READY (city.gd skips its spawn
## line when Net.is_client()).

## Peer id -> true once its spawn burst went out. Reliable owner events may
## follow at once (ENet keeps their order behind the burst). The UNRELIABLE
## state stream of a body goes to a peer only after that peer ACKED the
## body's `_spawn_player` (`_acked[peer][body]`): reliable RPCs can sit
## behind a large reliable payload (WorldSync's ready flush) for hundreds of
## ms while unreliable ones overtake them and hit a node path the client
## hasn't built yet.
var _spawned_at: Dictionary = {}
var _acked: Dictionary = {} # peer id -> {body peer id: true}

func _net():
	return get_parent()

func _ready() -> void:
	var net = _net()
	net.peer_ready.connect(_on_peer_ready)
	net.peer_left.connect(_on_peer_left)

func _players() -> Players:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("Players") as Players

func _world_name() -> String:
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		var wn = tree.current_scene.get("world_name")
		if wn is String and wn != "":
			return wn
	return String(_net().world_name)

## Host: has this peer been sent its spawn burst (its own body exists there)?
func peer_spawned(peer_id: int) -> bool:
	return _spawned_at.has(peer_id)

## Host: may body `body_peer`'s unreliable state stream go to `peer_id` yet?
func stream_ok(peer_id: int, body_peer: int) -> bool:
	return _acked.get(peer_id, {}).has(body_peer)

# --- Host ---

func _on_peer_ready(peer_id: int) -> void:
	var net = _net()
	if net.mode != Net.Mode.HOST:
		return
	var players := _players()
	if players == null:
		push_warning("PlayerSpawn: peer %d ready but the scene has no Players container" % peer_id)
		return
	var entry: Dictionary = net.peers.get(peer_id, {})
	var char_name := String(entry.get("name", "peer%d" % peer_id))
	var p := players.spawn_for(peer_id, char_name)
	# Vitals + the world spawn first, then the character's own state on top
	# (its bed in this world, and its last position here if it visited before)
	# - the same order city.gd uses for the host's body.
	p.respawn()
	var cs: Node = net.char_sync
	if cs != null and cs.has_method("apply_on_spawn"):
		cs.apply_on_spawn(p, peer_id)
	else:
		var char_state: Dictionary = entry.get("char_state", {})
		if not char_state.is_empty():
			# The map reveal is per client (theirs travels with their character);
			# applying it here would overwrite the host's own map.
			var d := char_state.duplicate()
			d["maps"] = {}
			SaveGame.apply_character(d, p, _world_name())
	World.refresh_objects_around(p.global_position)
	if net.peers.has(peer_id):
		net.peers[peer_id].player = p
	var feet := p.global_position + Vector2(0, Player.FEET_Y)
	# Everyone already in: the new body. The new peer: every body, its own included.
	for pid in net.ready_peers():
		if pid != peer_id:
			_spawn_player.rpc_id(pid, peer_id, char_name, feet)
	for other in players.get_children():
		if other is Player and not other.is_queued_for_deletion():
			_spawn_player.rpc_id(peer_id, other.peer_id, other.character_name,
				other.global_position + Vector2(0, Player.FEET_Y))
	_spawned_at[peer_id] = true
	# From now on this body streams state and relays owner events.
	var sync := p.get_node_or_null("Sync")
	if sync != null:
		sync.announced = true

func _on_peer_left(peer_id: int) -> void:
	var net = _net()
	if net.mode != Net.Mode.HOST:
		return
	_spawned_at.erase(peer_id)
	_acked.erase(peer_id)
	for pid in _acked:
		_acked[pid].erase(peer_id)
	var players := _players()
	if players != null:
		players.remove_for(peer_id)
	for pid in net.ready_peers():
		if pid != peer_id and _spawned_at.has(pid):
			_despawn_player.rpc_id(pid, peer_id)

## Client -> host: "I built the node for body `body_peer`" - its state stream may start.
@rpc("any_peer", "call_remote", "reliable")
func _spawn_ack(body_peer: int) -> void:
	if _net().mode != Net.Mode.HOST:
		return
	var from := multiplayer.get_remote_sender_id()
	if not _acked.has(from):
		_acked[from] = {}
	_acked[from][body_peer] = true

# --- Client ---

@rpc("authority", "call_remote", "reliable")
func _spawn_player(peer_id: int, char_name: String, feet: Vector2) -> void:
	var net = _net()
	if net.mode != Net.Mode.CLIENT:
		return
	var players := _players()
	if players == null:
		push_warning("PlayerSpawn: _spawn_player(%d) before the city scene is up" % peer_id)
		return
	var p := players.spawn_for(peer_id, char_name) # our own: the puppet city.gd parked at boot
	p.place_at_feet(feet)
	var sync := p.get_node_or_null("Sync")
	if sync != null:
		sync.reset_interp()
		sync.announced = true # the host has this node now: the input stream may start
	_spawn_ack.rpc_id(1, peer_id) # and the host may stream this body's state to us
	if peer_id == net.local_peer():
		# The scene's `player` field (F5 messages, red-moon line, close-request
		# save) points at our own puppet - city.gd never spawned one on a client.
		var scene := get_tree().current_scene
		if scene != null and scene.get("player") == null:
			scene.set("player", p)
		World.refresh_objects_around(p.global_position)

@rpc("authority", "call_remote", "reliable")
func _despawn_player(peer_id: int) -> void:
	var net = _net()
	if net.mode != Net.Mode.CLIENT:
		return
	var players := _players()
	if players != null:
		players.remove_for(peer_id)
