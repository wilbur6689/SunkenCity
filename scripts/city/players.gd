class_name Players
extends Node2D
## The per-peer Player container in city.tscn (LAN Step 1, docs/technical/
## MultiplayerImpl.md §4): one Player node per peer, named by its peer id so
## RPC paths match on every machine. Offline the host's own player (peer 1)
## is the only child - exactly the single $Player the scene used to carry.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

func spawn_for(peer_id: int, character_name: String) -> Player:
	var existing := player_of(peer_id)
	if existing != null:
		return existing
	var p: Player = PLAYER_SCENE.instantiate()
	p.name = str(peer_id)
	p.peer_id = peer_id
	p.character_name = character_name
	p.set_multiplayer_authority(peer_id)
	var local := peer_id == Net.local_peer()
	# Players never block each other (Step 4): two bodies on one spawn cell
	# would shove apart and then wall each other in.
	for other in get_children():
		if other is Player and not other.is_queued_for_deletion():
			p.add_collision_exception_with(other)
			other.add_collision_exception_with(p)
	add_child(p)
	p.camera.enabled = local # only the local body drives the viewport
	if local:
		Net.register_local_player(p)
	if Net.peers.has(peer_id):
		Net.peers[peer_id].player = p
	return p

func remove_for(peer_id: int) -> void:
	var p := player_of(peer_id)
	if p == null:
		return
	if Net.peers.has(peer_id):
		Net.peers[peer_id].player = null
	p.remove_from_group("player")
	p.queue_free()

func player_of(peer_id: int) -> Player:
	var n := get_node_or_null(str(peer_id))
	return n as Player if n != null and is_instance_valid(n) and not n.is_queued_for_deletion() else null
