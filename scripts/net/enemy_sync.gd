extends Node
## Net/EnemySync (LAN Step 6, MultiplayerImpl §6): enemy records and the
## per-tick enemy state stream. Relay-only: the host runs every enemy brain
## and every player's combat; this node only mirrors the outcome.
##
## Host side (Net.mode == HOST):
##   World.add_enemy_record  -> Net.on_enemy_added   -> _add     (reliable)
##   World.remove_enemy      -> Net.on_enemy_removed -> _remove  (reliable)
##   Enemy.hurt / _die / bite -> Net.on_enemy_event  -> _event   (reliable)
##   every physics tick        -> _state  (unreliable_ordered): live enemies
##                                inside the peer's window
##   every NET_ENEMY_RESYNC_TICKS -> _resync (reliable): pos + hp of every record
##                                inside the peer's window (drift guard)
##   SpearBolt on the host      -> _bolt (reliable): a visual-only bolt
## A peer that is still LOADING (snapshot in flight) gets its reliable
## messages queued; on `peer_ready` the host sends a full `_reset` of every
## record (the join snapshot carries no nids, so the client's copies are
## rebuilt with the host's ids) and then flushes the queue. `_add` is
## idempotent by nid, so a queued add after the reset is harmless.
##
## Client side: `_add`/`_reset` create records through World.add_enemy_replica
## (no hooks, no id allocation); nodes are the usual windowed view, spawned
## as puppets (Enemy.puppet) that only interpolate toward the streamed pos.

const RESET_BATCH := 200    # records per _reset RPC
const STATE_STRIDE := 6     # [nid, x, y, hp, facing, moving] per enemy

var _queues: Dictionary = {}   # host: LOADING peer id -> Array of [method, args]
var _by_nid: Dictionary = {}   # client: nid -> record
var _tick := 0

## The Net node this endpoint belongs to (the parent), so a plain-node Net
## (lan_smoke) and the autoload both work.
func _net() -> Node:
	var p := get_parent()
	return p if p != null and "mode" in p else Net

func _ready() -> void:
	var net := _net()
	if net.has_signal("peer_accepted"):
		net.peer_accepted.connect(_on_peer_accepted)
	if net.has_signal("peer_ready"):
		net.peer_ready.connect(_on_peer_ready)
	if net.has_signal("peer_left"):
		net.peer_left.connect(_on_peer_left)
	if net.has_signal("disconnected"):
		net.disconnected.connect(func(_r: String) -> void: _by_nid.clear())

func _is_host() -> bool:
	return _net().mode == Net.Mode.HOST

func _is_client() -> bool:
	return _net().mode == Net.Mode.CLIENT

# --- Host: peer lifecycle ---

func _on_peer_accepted(peer_id: int, _name: String) -> void:
	_queues[peer_id] = []

func _on_peer_ready(peer_id: int) -> void:
	if not _is_host():
		return
	_send_reset(peer_id)
	var q: Array = _queues.get(peer_id, [])
	_queues.erase(peer_id)
	for msg in q:
		callv("rpc_id", [peer_id, msg[0]] + msg[1])

func _on_peer_left(peer_id: int) -> void:
	_queues.erase(peer_id)

## Send a reliable message to every READY peer, queue it for LOADING ones.
func _send(method: String, args: Array) -> void:
	var net := _net()
	for pid in net.peers:
		if pid == 1:
			continue
		if net.peers[pid].get("state", Net.PeerState.READY) == Net.PeerState.READY:
			callv("rpc_id", [pid, method] + args)
		elif _queues.has(pid):
			_queues[pid].append([method, args])

# --- Host: hooks from World / Enemy ---

func _add_args(rec: Dictionary) -> Array:
	var extra := {}
	if rec.has("stock"):
		extra["stock"] = int(rec.stock)
	if rec.get("night", false):
		extra["night"] = true
	return [int(rec.get("nid", 0)), String(rec.type), _rec_pos(rec), float(rec.get("mult", 1.0)),
		float(rec.hp), String(rec.get("band", "dry")), extra]

func _rec_pos(rec: Dictionary) -> Vector2:
	var n = rec.get("node")
	if n != null and is_instance_valid(n):
		return n.global_position
	return rec.pos

func on_enemy_added(rec: Dictionary) -> void:
	if not _is_host():
		return
	_send("_add", _add_args(rec))

func on_enemy_removed(rec: Dictionary) -> void:
	if not _is_host():
		return
	_send("_remove", [int(rec.get("nid", 0))])

func on_enemy_event(rec: Dictionary, event: String) -> void:
	if not _is_host():
		return
	_send("_event", [int(rec.get("nid", 0)), event])

## A speargun bolt left a host-side muzzle: clients get a visual twin.
func on_bolt_fired(item_id: String, pos: Vector2, vel: Vector2) -> void:
	if not _is_host():
		return
	for pid in _net().ready_peers():
		_bolt.rpc_id(pid, item_id, pos, vel)

# --- Host: per-tick stream ---

func _physics_process(_delta: float) -> void:
	if not _is_host() or not World.is_ready():
		return
	_tick += 1
	var full := _tick % Constants.NET_ENEMY_RESYNC_TICKS == 0
	var net := _net()
	for pid in net.ready_peers():
		var p = net.player_of(pid)
		if p == null or not is_instance_valid(p):
			continue
		var win := _window_of(p.global_position)
		var packed := _pack_window(win, full)
		if packed.is_empty():
			continue
		if full:
			_resync.rpc_id(pid, packed)
		else:
			_state.rpc_id(pid, packed)

func _window_of(pos: Vector2) -> Rect2i:
	var half: Vector2i = Constants.ENEMY_WINDOW / 2
	return Rect2i(World.cell_at(pos) - half, Constants.ENEMY_WINDOW)

## Live nodes inside `win` (every record inside it when `all_records`).
func _pack_window(win: Rect2i, all_records: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for rec: Dictionary in World.enemy_records:
		var n = rec.get("node")
		var live: bool = n != null and is_instance_valid(n)
		if not live and not all_records:
			continue
		var pos: Vector2 = n.global_position if live else rec.pos
		if not win.has_point(World.cell_at(pos)):
			continue
		var facing := 1
		var moving := 0.0
		if live:
			facing = int(n.facing)
			moving = 1.0 if n.velocity.length() > 6.0 else 0.0
		out.append(float(int(rec.get("nid", 0))))
		out.append(pos.x)
		out.append(pos.y)
		out.append(float(rec.hp))
		out.append(float(facing))
		out.append(moving)
	return out

func _send_reset(peer_id: int) -> void:
	var batch: Array = []
	var first := true
	for rec: Dictionary in World.enemy_records:
		batch.append(_add_args(rec))
		if batch.size() >= RESET_BATCH:
			_reset.rpc_id(peer_id, batch, first)
			first = false
			batch = []
	if first or not batch.is_empty():
		_reset.rpc_id(peer_id, batch, first)

# --- RPCs (host -> client) ---

## One enemy record. `extra`: {stock, night}. Idempotent by nid.
@rpc("authority", "call_remote", "reliable")
func _add(nid: int, type: String, pos: Vector2, mult: float, hp: float, band: String, extra: Dictionary) -> void:
	if not _is_client():
		return
	_apply_add([nid, type, pos, mult, hp, band, extra])

func _apply_add(a: Array) -> void:
	var d := {"nid": int(a[0]), "type": String(a[1]), "pos": a[2], "mult": float(a[3]),
		"hp": float(a[4]), "band": String(a[5])}
	var extra: Dictionary = a[6]
	if extra.has("stock"):
		d["stock"] = int(extra.stock)
	if extra.get("night", false):
		d["night"] = true
	var rec := World.add_enemy_replica(d)
	if not rec.is_empty():
		_by_nid[rec.nid] = rec

## Every record on the host, in batches; `clear` on the first batch drops the
## client's snapshot copies (their nids were local guesses).
@rpc("authority", "call_remote", "reliable")
func _reset(batch: Array, clear: bool) -> void:
	if not _is_client():
		return
	if clear:
		World.clear_enemy_replicas()
		_by_nid.clear()
	for a in batch:
		_apply_add(a)
	World.refresh_enemy_window()

@rpc("authority", "call_remote", "reliable")
func _remove(nid: int) -> void:
	if not _is_client():
		return
	var rec: Dictionary = _by_nid.get(nid, {})
	if rec.is_empty():
		return
	_by_nid.erase(nid)
	World.remove_enemy(rec) # hooks are no-ops on a client

## "hurt" -> flash + flinch, "died" -> corpse + rattle, "anim:<clip>" -> one-shot.
@rpc("authority", "call_remote", "reliable")
func _event(nid: int, event: String) -> void:
	if not _is_client():
		return
	var rec: Dictionary = _by_nid.get(nid, {})
	if rec.is_empty():
		return
	var n = rec.get("node")
	if n == null or not is_instance_valid(n):
		return
	n.puppet_event(event)

## Per tick: [nid, x, y, hp, facing, moving] x N for enemies in this peer's window.
@rpc("authority", "call_remote", "unreliable_ordered")
func _state(packed: PackedFloat32Array) -> void:
	if not _is_client():
		return
	_apply_state(packed)

## The same layout, reliable, every NET_ENEMY_RESYNC_TICKS: covers frozen records too.
@rpc("authority", "call_remote", "reliable")
func _resync(packed: PackedFloat32Array) -> void:
	if not _is_client():
		return
	_apply_state(packed)
	World.refresh_enemy_window()

func _apply_state(packed: PackedFloat32Array) -> void:
	var i := 0
	while i + STATE_STRIDE <= packed.size():
		var nid := int(packed[i])
		var rec: Dictionary = _by_nid.get(nid, {})
		if not rec.is_empty():
			var pos := Vector2(packed[i + 1], packed[i + 2])
			var hp := packed[i + 3]
			var n = rec.get("node")
			if n != null and is_instance_valid(n):
				n.puppet_state(pos, hp, int(packed[i + 4]), packed[i + 5] > 0.5)
			else:
				rec.pos = pos
				rec.hp = hp
				if World._enemy_in_window(rec):
					World._instantiate_enemy(rec) # streamed into view while we stood still
					var e = rec.get("node")
					if e != null:
						e.puppet_state(pos, hp, int(packed[i + 4]), packed[i + 5] > 0.5)
		i += STATE_STRIDE

## A visual-only twin of a bolt fired on the host (never damages, never drops).
@rpc("authority", "call_remote", "reliable")
func _bolt(item_id: String, pos: Vector2, vel: Vector2) -> void:
	if not _is_client() or World.items_root == null:
		return
	var b := SpearBolt.new()
	b.setup(item_id, vel, 0.0)
	b.visual = true
	World.items_root.add_child(b)
	b.global_position = pos
