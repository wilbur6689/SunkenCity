extends Node
## Net/WorldSync (LAN Step 5, docs/technical/MultiplayerImpl.md §6): the
## host's world deltas. World's mutation hooks (Net.on_*) land here on the
## host and go out as RPCs to every READY peer; clients apply them through
## World's `*_replica` functions, which write the replica and repaint but
## never re-broadcast, wake the water sim or run game logic.
##
## Streams (one packet per stream per physics tick at most):
##   _cells(packed)              reliable   [cell, structure, back, climb, placed{layer:entry}|null, damage|null] x N
##   _water(pairs)               unreliable_ordered  PackedInt32Array [index, level] x N, clipped to the peer's window
##   _water_rect(rect, bytes)    reliable   a full window resync every NET_WATER_RESYNC_TICKS
##   _rec_add(dict) / _rec_remove(cell, id) / _rec_change(cell, fields) / _rec_replace(old_cell, old_id, dict)
##   _item_spawn(net_id, id, count, pos, vel) / _item_remove(net_id, taker_peer)
##   _item_pos(packed)           unreliable_ordered  [net_id, pos, vel] x N every NET_ITEM_RESYNC_TICKS
##   _items_reset()              reliable   (READY handshake: drop everything, the roster follows)
##   _pack_spawn(net_id, slots, pos) / _pack_remove(net_id, taker_peer)
##   _clock(time_of_day, day_count, next_red_moon_day, red_moon_active)   every NET_CLOCK_SYNC_TICKS + on change
##   _power(lights, breakers)    reliable   [[cell, on], ...] each
##   _effect(kind, pos, arg)     unreliable cosmetic one-shots (break puff, sfx)
##
## Loading peers: from `peer_accepted` (the snapshot payload is built right
## then) until `_ready_for_world`, every reliable delta is also queued per
## peer and flushed on READY, so nothing between the payload and the first
## live delta is lost. The parent is the Net node (autoload, or a plain node
## in lan_smoke), reached through get_parent().

## Cells around a peer's player that receive water deltas / item positions:
## ~2.5 screens at the default zoom (the screen is 160x90 cells at zoom 1.5).
const WATER_WINDOW := Vector2i(200, 120)
## More changed pairs than this in one tick for one peer -> the window goes
## out whole (reliable) instead: cheaper than a 100 KB unreliable packet.
const WATER_DELTA_CAP := 3000

var _queues: Dictionary = {}        # loading peer id -> Array of [method, args]
var _dirty_cells: Dictionary = {}   # cell -> true, this tick
var _dirty_recs: Dictionary = {}    # cell -> record, this tick (coalesced)
var _power_dirty := false
var _water_resync_t: Dictionary = {} # peer id -> ticks until its next full window resync
var _clock_t := 0
var _clock_last: Array = []
var _item_t := 0
## F3 / probes: packets and bytes-ish counters for the last second.
var stats: Dictionary = {"cells": 0, "water_pairs": 0, "packets": 0}
## Last full second of `stats` (F3 line), rolled over by _process.
var stats_last: Dictionary = {"cells": 0, "water_pairs": 0, "packets": 0}
var _stats_t := 0.0

func _process(delta: float) -> void:
	_stats_t += delta
	if _stats_t >= 1.0:
		_stats_t -= 1.0
		stats_last = stats.duplicate()
		for k in stats:
			stats[k] = 0

func _net() -> Node:
	return get_parent()

func _is_host() -> bool:
	var net := _net()
	return net.is_online() and net.is_server()

func _ready() -> void:
	# After every Player / World physics step: the tick's writes are complete.
	process_physics_priority = 1000
	var net := _net()
	net.peer_accepted.connect(_on_peer_accepted)
	net.peer_left.connect(_on_peer_left)
	if OS.get_cmdline_user_args().has("--net-mutate"):
		net.peer_ready.connect(_on_peer_ready_mutate)

# --- Dev aid: --net-mutate (host) exercises every stream beside a joining
# peer's player 2 s after it is READY; lan_smoke's hashes must still match.

func _on_peer_ready_mutate(peer_id: int) -> void:
	await get_tree().create_timer(2.0).timeout
	if _is_host() and World.is_ready():
		_dev_mutate(peer_id)

func _dev_mutate(peer_id: int) -> void:
	var p = _net().player_of(peer_id)
	if p == null or not is_instance_valid(p):
		p = _net().local_player()
	if p == null:
		return
	var base: Vector2i = World.cell_at((p as Node2D).global_position)
	var floor_y := base.y
	while floor_y < base.y + 16 and not World.is_solid_cell(Vector2i(base.x, floor_y)):
		floor_y += 1
	# A walled basin (so the poured water settles and the hashes can agree),
	# one spare block that gets mined (cell delta + item drop), a planter
	# (record add), a chest edit (record change) and a loose item.
	# Basin site: three free columns over solid ground within 20 cells.
	var site := Vector2i(-99999, 0)
	for dx in range(0, 21) + range(-20, 0):
		var ok := true
		for ddx in [-1, 0, 1]:
			var x: int = base.x + int(dx) + int(ddx)
			if not World.is_solid_cell(Vector2i(x, floor_y)):
				ok = false
			for dy in [1, 2]:
				var c := Vector2i(x, floor_y - dy)
				if World.is_solid_cell(c) or World.object_cells.has(c) or World.is_climbable_cell(c) \
						or World.water_sim.level_at(c) > 0:
					ok = false
		if ok:
			site = Vector2i(base.x + dx, floor_y)
			break
	var placed := 0
	var water := 0
	if site.x != -99999:
		for dx in [-1, 1]:
			for dy in [1, 2]:
				var c := Vector2i(site.x + dx, site.y - dy)
				if World.can_place_block("wood_block", c) and World.place_block("wood_block", c):
					placed += 1
		water = 6 - World.water_sim.add_water(Vector2i(site.x, site.y - 1), 6)
	var mined := "unplaced"
	for dx in range(3, 16) + range(-16, -3):
		var spare := Vector2i(base.x + dx, floor_y - 1)
		if World.can_place_block("wood_block", spare) and World.place_block("wood_block", spare):
			placed += 1
			mined = World.damage_block(spare, 999.0, 3, (p as Node2D).global_position)
			break
	var obj = null
	for dx in range(6, 16) + range(-16, -6):
		var c := Vector2i(base.x + dx, floor_y - 1)
		if World.can_place_object("planter", c):
			obj = World.place_object("planter", c, true)
			break
	var chest := 0
	for rec: Dictionary in World.object_records:
		if rec.storage != null and (rec.cell - base).length() < 60.0:
			rec.storage.add("wood", 2)
			chest += 1
			break
	var it = World.spawn_item("stone", 2, World.cell_center(Vector2i(base.x - 12, floor_y - 2)))
	print("NETMUTATE base=%s floor=%d placed=%d mined=%s water=%d object=%s chest=%d item=%s" % [base, floor_y, placed,
		mined, water, obj != null, chest, it != null])

func _on_peer_accepted(peer_id: int, _character_name: String) -> void:
	_queues[peer_id] = []

func _on_peer_left(peer_id: int) -> void:
	_queues.erase(peer_id)
	_water_resync_t.erase(peer_id)

func _peer_live(id: int) -> bool:
	return multiplayer.multiplayer_peer != null and (id in multiplayer.get_peers())

## Reliable delta to every READY peer, queued for every LOADING one.
func _send(method: StringName, args: Array) -> void:
	var net := _net()
	for id in net.ready_peers():
		if _peer_live(id):
			callv("rpc_id", [id, method] + args)
			stats.packets += 1
	for id in _queues:
		_queues[id].append([method, args])

## Reliable to READY peers only (values that are re-sent on READY anyway).
func _send_ready(method: StringName, args: Array) -> void:
	for id in _net().ready_peers():
		if _peer_live(id):
			callv("rpc_id", [id, method] + args)
			stats.packets += 1

func _send_to(id: int, method: StringName, args: Array) -> void:
	if _peer_live(id):
		callv("rpc_id", [id, method] + args)
		stats.packets += 1

# --- READY handshake (MultiplayerImpl §3 step 5) ---

## Client -> host: "my world is booted from the snapshot". The host marks the
## peer READY, replays the queued deltas, hands over the live item roster,
## clock and power, then tells the rest of the game (Net.peer_ready).
@rpc("any_peer", "call_remote", "reliable")
func _ready_for_world() -> void:
	if not _is_host():
		return
	var net := _net()
	var id := multiplayer.get_remote_sender_id()
	if not net.peers.has(id):
		return
	net.peers[id].state = net.PeerState.READY
	var queued: Array = _queues.get(id, [])
	_queues.erase(id)
	for entry in queued:
		if not _peer_live(id):
			return
		callv("rpc_id", [id, entry[0]] + entry[1])
	stats.packets += queued.size()
	# Items carry host-assigned net ids the snapshot doesn't: reset and re-list.
	_send_to(id, "_items_reset", [])
	if World.items_root != null:
		for it in World.items_root.get_children():
			if it.is_queued_for_deletion():
				continue
			if it is WorldItem:
				_send_to(id, "_item_spawn", [it.net_id, it.id, it.count, it.global_position, it.velocity])
			elif it is Backpack:
				_send_to(id, "_pack_spawn", [it.net_id, it.slots.duplicate(true), it.global_position])
	var pw := _power_payload()
	_send_to(id, "_power", [pw[0], pw[1]])
	_send_to(id, "_clock", _clock_payload())
	_water_resync_t[id] = 1 # first full window as soon as its player exists
	print("[net] peer %d ready (%d queued deltas replayed)" % [id, queued.size()])
	net.peer_ready.emit(id)

# --- Host hooks (World -> Net -> here) ---

func on_cell_changed(cell: Vector2i) -> void:
	_dirty_cells[cell] = true

func on_record_added(rec: Dictionary) -> void:
	_send("_rec_add", [_compact(rec)])

func on_record_removed(rec: Dictionary) -> void:
	_dirty_recs.erase(rec.cell)
	_send("_rec_remove", [rec.cell, String(rec.id)])

func on_record_changed(rec: Dictionary) -> void:
	_dirty_recs[rec.cell] = rec

func on_record_replaced(old_rec: Dictionary, new_rec: Dictionary) -> void:
	_dirty_recs.erase(old_rec.cell)
	_send("_rec_replace", [old_rec.cell, String(old_rec.id), _compact(new_rec)])

func on_item_spawned(item: Node) -> void:
	_send("_item_spawn", [item.net_id, item.id, item.count, item.global_position, item.velocity])

func on_item_removed(item: Node, taker: Node) -> void:
	_send("_item_remove", [item.net_id, _peer_of(taker)])

func on_backpack_spawned(pack: Node) -> void:
	_send("_pack_spawn", [pack.net_id, pack.slots.duplicate(true), pack.global_position])

func on_backpack_removed(pack: Node, taker: Node) -> void:
	_send("_pack_remove", [pack.net_id, _peer_of(taker)])

func on_power_changed() -> void:
	_power_dirty = true

func on_effect(kind: String, pos: Vector2, arg: String) -> void:
	for id in _net().ready_peers():
		_send_to(id, "_effect", [kind, pos, arg])

func _peer_of(p: Node) -> int:
	if p == null or not is_instance_valid(p):
		return 0
	var pid = p.get("peer_id")
	return int(pid) if pid != null else 0

## The compact record: the fields the world save carries (SaveGame.world_payload).
func _compact(rec: Dictionary) -> Dictionary:
	var d := {"id": String(rec.id), "cell": rec.cell, "placed": bool(rec.placed), "open": bool(rec.open),
		"powered": bool(rec.powered), "unlocked": bool(rec.get("unlocked", false)), "outlet": rec.outlet}
	for k in ["link", "door", "grow_day"]:
		if rec.has(k):
			d[k] = rec[k]
	if rec.storage != null:
		d["storage"] = rec.storage.slots.duplicate(true)
	return d

# --- Per tick (host) ---

func _physics_process(_delta: float) -> void:
	if not _is_host() or not World.is_ready():
		_dirty_cells.clear()
		_dirty_recs.clear()
		_power_dirty = false
		return
	_flush_cells()
	_flush_records()
	_flush_power()
	_tick_water()
	_tick_items()
	_tick_clock()
	_tick_map()

func _flush_cells() -> void:
	if _dirty_cells.is_empty():
		return
	var packed: Array = []
	var g: WorldGrid = World.grid
	for cell: Vector2i in _dirty_cells:
		packed.append(cell)
		packed.append(g.structure_at(cell))
		packed.append(g.back_at(cell))
		packed.append(g.climb_at(cell))
		var placed := {}
		for layer in ["blocks", "back", "climb"]:
			var key = World._key(cell, layer)
			if World.placed_blocks.has(key):
				placed[layer] = (World.placed_blocks[key] as Dictionary).duplicate()
		packed.append(placed if not placed.is_empty() else null)
		packed.append(World.structure_damage.get(cell, null))
	stats.cells += _dirty_cells.size()
	_dirty_cells.clear()
	_send("_cells", [packed])

func _flush_records() -> void:
	if _dirty_recs.is_empty():
		return
	for cell in _dirty_recs:
		var rec: Dictionary = _dirty_recs[cell]
		if World.object_records.has(rec): # removed later in the tick: the remove already went out
			_send("_rec_change", [cell, _compact(rec)])
	_dirty_recs.clear()

func _power_payload() -> Array:
	var lights: Array = []
	var breakers: Array = []
	if World.objects_root != null:
		for obj in World.objects_root.get_children():
			if not (obj is WorldObject) or obj.is_queued_for_deletion():
				continue
			if obj.def.kind == "breaker":
				breakers.append([obj.cell, obj.powered_on])
			elif obj.def.kind == "light" and bool(obj.def.get("powered", false)):
				lights.append([obj.cell, obj.powered_on])
				# Bank it: streamed-out replicas read rec.powered for beacons.
				var rec: Dictionary = World.object_cells.get(obj.cell, {})
				if not rec.is_empty() and rec.node == obj:
					rec.powered = obj.powered_on
	return [lights, breakers]

func _flush_power() -> void:
	if not _power_dirty:
		return
	_power_dirty = false
	var pw := _power_payload()
	_send("_power", [pw[0], pw[1]])

## The peer's streaming window (cells) around its player, or an empty rect
## before the player exists.
func _peer_window(id: int, size: Vector2i) -> Rect2i:
	var p = _net().player_of(id)
	if p == null or not is_instance_valid(p) or not (p is Node2D):
		return Rect2i()
	var center: Vector2i = World.cell_at((p as Node2D).global_position)
	return Rect2i(center - size / 2, size).intersection(World.grid.bounds)

func _tick_water() -> void:
	var ws: WaterSim = World.water_sim
	if ws == null:
		return
	ws.track = true
	var ready: Array = _net().ready_peers()
	if ready.is_empty():
		ws.changed.clear()
		return
	for id in ready:
		var rect := _peer_window(id, WATER_WINDOW)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		_water_resync_t[id] = int(_water_resync_t.get(id, (id * 17) % Constants.NET_WATER_RESYNC_TICKS + 1)) - 1
		if _water_resync_t[id] <= 0:
			_send_water_rect(id, rect)
			continue
		if ws.changed.is_empty():
			continue
		var pairs := PackedInt32Array()
		var over := false
		for i in ws.changed:
			if rect.has_point(ws._cell(i)):
				pairs.append(i)
				pairs.append(ws.levels[i])
				if pairs.size() > WATER_DELTA_CAP * 2:
					over = true
					break
		if over:
			_send_water_rect(id, rect)
		elif pairs.size() > 0:
			stats.water_pairs += pairs.size() / 2
			_send_to(id, "_water", [pairs])
	ws.changed.clear()

func _send_water_rect(id: int, rect: Rect2i) -> void:
	var ws: WaterSim = World.water_sim
	var bytes := PackedByteArray()
	for y in range(rect.position.y, rect.end.y):
		var i0 := ws._idx(Vector2i(rect.position.x, y))
		bytes.append_array(ws.levels.slice(i0, i0 + rect.size.x))
	_water_resync_t[id] = Constants.NET_WATER_RESYNC_TICKS
	_send_to(id, "_water_rect", [rect, bytes])

func _tick_items() -> void:
	_item_t += 1
	if _item_t < Constants.NET_ITEM_RESYNC_TICKS:
		return
	_item_t = 0
	if World.items_root == null:
		return
	var ready: Array = _net().ready_peers()
	if ready.is_empty():
		return
	var nodes: Array = []
	for it in World.items_root.get_children():
		if (it is WorldItem or it is Backpack) and not it.is_queued_for_deletion():
			nodes.append(it)
	if nodes.is_empty():
		return
	for id in ready:
		var rect := _peer_window(id, WATER_WINDOW)
		if rect.size.x <= 0:
			continue
		var packed: Array = []
		for it in nodes:
			if rect.has_point(World.cell_at(it.global_position)):
				packed.append(it.net_id)
				packed.append(it.global_position)
				packed.append(it.velocity)
		if not packed.is_empty():
			_send_to(id, "_item_pos", [packed])

## Shared map (2026-09-06): the host's MapReveal banks every cell any body
## revealed in `net_dirty`; it drains to ready peers every NET_MAP_SYNC_TICKS.
var _map_t := 0
func _tick_map() -> void:
	_map_t += 1
	if _map_t < Constants.NET_MAP_SYNC_TICKS or World.map_reveal == null:
		return
	_map_t = 0
	var cells: PackedVector2Array = World.map_reveal.net_dirty
	if cells.is_empty():
		return
	World.map_reveal.net_dirty = PackedVector2Array()
	_send_ready("_map", [cells])

@rpc("authority", "call_remote", "reliable")
func _map(cells: PackedVector2Array) -> void:
	if _is_client() and World.is_ready() and World.map_reveal != null:
		World.map_reveal.reveal_cells(cells)

func _clock_payload() -> Array:
	return [World.time_of_day, World.day_count, World.next_red_moon_day, World.red_moon_active]

func _tick_clock() -> void:
	_clock_t += 1
	var cur := _clock_payload()
	var changed: bool = _clock_last.size() != 4 or cur[1] != _clock_last[1] or cur[2] != _clock_last[2] \
		or cur[3] != _clock_last[3]
	if _clock_t >= Constants.NET_CLOCK_SYNC_TICKS or changed:
		_clock_t = 0
		_clock_last = cur
		_send_ready("_clock", cur)

# --- Client side: apply replicas ---

func _is_client() -> bool:
	return _net().is_client()

@rpc("authority", "call_remote", "reliable")
func _cells(packed: Array) -> void:
	if not _is_client() or not World.is_ready():
		return
	var i := 0
	while i + 5 < packed.size():
		World.apply_cell_replica(packed[i], int(packed[i + 1]), int(packed[i + 2]), int(packed[i + 3]),
			packed[i + 4], packed[i + 5])
		i += 6

@rpc("authority", "call_remote", "unreliable_ordered")
func _water(pairs: PackedInt32Array) -> void:
	if _is_client() and World.is_ready():
		World.apply_water_replica(pairs)

@rpc("authority", "call_remote", "reliable")
func _water_rect(rect: Rect2i, bytes: PackedByteArray) -> void:
	if _is_client() and World.is_ready():
		World.apply_water_rect_replica(rect, bytes)

@rpc("authority", "call_remote", "reliable")
func _rec_add(d: Dictionary) -> void:
	if _is_client() and World.is_ready():
		World.add_record_replica(d)

@rpc("authority", "call_remote", "reliable")
func _rec_remove(cell: Vector2i, id: String) -> void:
	if _is_client() and World.is_ready():
		World.remove_record_replica(cell, id)

@rpc("authority", "call_remote", "reliable")
func _rec_change(cell: Vector2i, fields: Dictionary) -> void:
	if _is_client() and World.is_ready():
		World.change_record_replica(cell, fields)

@rpc("authority", "call_remote", "reliable")
func _rec_replace(old_cell: Vector2i, old_id: String, d: Dictionary) -> void:
	if _is_client() and World.is_ready():
		World.remove_record_replica(old_cell, old_id)
		World.add_record_replica(d)

@rpc("authority", "call_remote", "reliable")
func _items_reset() -> void:
	if _is_client() and World.is_ready():
		World.reset_items_replica()

@rpc("authority", "call_remote", "reliable")
func _item_spawn(net_id: int, id: String, count: int, pos: Vector2, vel: Vector2) -> void:
	if _is_client() and World.is_ready():
		World.spawn_item_replica(net_id, id, count, pos, vel)

@rpc("authority", "call_remote", "reliable")
func _item_remove(net_id: int, _taker_peer: int) -> void:
	if _is_client() and World.is_ready():
		World.remove_item_replica(net_id)

@rpc("authority", "call_remote", "unreliable_ordered")
func _item_pos(packed: Array) -> void:
	if _is_client() and World.is_ready():
		World.apply_item_positions(packed)

@rpc("authority", "call_remote", "reliable")
func _pack_spawn(net_id: int, slots: Array, pos: Vector2) -> void:
	if _is_client() and World.is_ready():
		World.spawn_backpack_replica(net_id, slots, pos)

@rpc("authority", "call_remote", "reliable")
func _pack_remove(net_id: int, _taker_peer: int) -> void:
	if _is_client() and World.is_ready():
		World.remove_item_replica(net_id)

@rpc("authority", "call_remote", "reliable")
func _clock(time_of_day: float, day_count: int, next_red_moon_day: int, red_moon_active: bool) -> void:
	if _is_client() and World.is_ready():
		World.apply_clock_replica(time_of_day, day_count, next_red_moon_day, red_moon_active)

@rpc("authority", "call_remote", "reliable")
func _power(lights: Array, breakers: Array) -> void:
	if _is_client() and World.is_ready():
		World.apply_power_replica(lights, breakers)

@rpc("authority", "call_remote", "unreliable")
func _effect(kind: String, pos: Vector2, arg: String) -> void:
	if not _is_client() or not World.is_ready():
		return
	match kind:
		"puff":
			World.spawn_break_puff(pos, arg, true)
		"sfx":
			Audio.play_sfx(arg, pos)
		"tracer":
			var parts := arg.split(",")
			if parts.size() == 2:
				World.spawn_tracer(pos, Vector2(float(parts[0]), float(parts[1])), true)
