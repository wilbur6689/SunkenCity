extends Node
## Net/Snapshot (LAN Step 3, docs/technical/MultiplayerImpl.md §3): the join
## snapshot. The host serialises the world with the SAME builder the disk save
## uses (`SaveGame.world_payload`), `var_to_bytes` it and streams it to one
## peer in `Constants.NET_CHUNK_BYTES` reliable chunks, a few per frame so ENet's
## outgoing queue never holds the whole ~4 MB at once. The client reassembles
## and hands the dictionary to `Net.snapshot_ready` - the menu parks it in
## `Net.pending_snapshot` and city.gd boots from it through `_boot_loaded`,
## one code path for "load from disk" and "load from host".
##
## The parent is the Net node (autoload or a plain node in lan_smoke), so the
## signals are reached through `get_parent()`, never /root/Net.

## Chunks handed to ENet per frame per loading peer. 32 KB x 6 = 192 KB / frame
## (~11 MB/s at 60 fps): a 4 MB city lands in ~0.4 s on localhost without the
## reliable window ever backing up into a burst of resends.
const CHUNKS_PER_FRAME := 6

## Host side: peer id -> {bytes: PackedByteArray, total: int, next: int, mark: int}
var _sending: Dictionary = {}
## Client side: the chunks received so far (index -> bytes) and the expected count.
var _rx: Dictionary = {}
var _rx_total: int = 0
var _rx_bytes: int = 0
var _rx_t0: int = 0

func _net() -> Node:
	return get_parent()

# --- Host ---

## Build the payload now (so deltas queued from this moment apply on top of
## it) and start streaming it to `peer_id`.
func send_to(peer_id: int) -> void:
	var net := _net()
	var wn := String(net.world_name)
	if net.has_method("_current_world_name"):
		wn = String(net._current_world_name())
	var seed_value := 1
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		var sv = tree.current_scene.get("seed_value")
		if sv != null:
			seed_value = int(sv)
	var t0 := Time.get_ticks_msec()
	var data := SaveGame.world_payload(wn, seed_value)
	var bytes := var_to_bytes(data)
	var total := int(ceil(float(bytes.size()) / float(Constants.NET_CHUNK_BYTES)))
	total = maxi(total, 1)
	_sending[peer_id] = {"bytes": bytes, "total": total, "next": 0, "mark": 0}
	print("[net] snapshot for peer %d: %d bytes in %d chunks (built in %d ms)" % [peer_id, bytes.size(), total,
		Time.get_ticks_msec() - t0])
	set_process(true)

func _ready() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	if _sending.is_empty():
		set_process(false)
		return
	for peer_id in _sending.keys():
		if not (peer_id in multiplayer.get_peers()):
			print("[net] snapshot to peer %d abandoned (peer gone)" % peer_id)
			_sending.erase(peer_id)
			continue
		var s: Dictionary = _sending[peer_id]
		var bytes: PackedByteArray = s.bytes
		var total: int = s.total
		for _i in CHUNKS_PER_FRAME:
			var index: int = s.next
			if index >= total:
				break
			var start := index * Constants.NET_CHUNK_BYTES
			var stop := mini(start + Constants.NET_CHUNK_BYTES, bytes.size())
			_chunk.rpc_id(peer_id, index, total, bytes.slice(start, stop))
			s.next = index + 1
			var pct := int(floor(float(s.next) * 100.0 / float(total)))
			var quarter := int(pct / 25) * 25
			if quarter > int(s.mark):
				s.mark = quarter
				print("[net] snapshot to peer %d: %d %%" % [peer_id, quarter])
		if s.next >= total:
			_sending.erase(peer_id)

## True while a snapshot is still streaming to `peer_id` (WorldSync may want
## to keep queueing deltas until then; READY arrives from the client anyway).
func is_sending_to(peer_id: int) -> bool:
	return _sending.has(peer_id)

# --- Client ---

@rpc("authority", "call_remote", "reliable")
func _chunk(index: int, total: int, bytes: PackedByteArray) -> void:
	if total <= 0 or index < 0 or index >= total:
		return
	if _rx_total != total: # a new snapshot (or the first chunk): start over
		_rx.clear()
		_rx_total = total
		_rx_bytes = 0
		_rx_t0 = Time.get_ticks_msec()
	if not _rx.has(index):
		_rx[index] = bytes
		_rx_bytes += bytes.size()
	var net := _net()
	net.snapshot_progress.emit(float(_rx.size()) / float(total))
	if _rx.size() < total:
		return
	var all := PackedByteArray()
	for i in total:
		all.append_array(_rx[i])
	_rx.clear()
	_rx_total = 0
	_rx_bytes = 0
	var data = bytes_to_var(all)
	if not (data is Dictionary) or data.is_empty():
		push_error("Net/Snapshot: the world payload did not decode (%d bytes)" % all.size())
		return
	print("[net] snapshot received: %d bytes, %d chunks in %d ms" % [all.size(), total, Time.get_ticks_msec() - _rx_t0])
	net.snapshot_ready.emit(data)
