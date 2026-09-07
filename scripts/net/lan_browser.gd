class_name LanBrowser
extends Node
## Listens for host beacons on Constants.LAN_BEACON_PORT and keeps the live
## list the Join screen shows (docs/technical/Multiplayer.md §2). A host
## broadcasts "SUNKENCITY|<build>|<world>|<players>/<cap>|<port>" once a
## second (Net._send_beacon); entries silent for NET_BEACON_TIMEOUT drop off.
##
## Port busy (2026-09-06): another instance on this PC (a headless test client
## still shutting down, a second menu) may hold the beacon port. Godot 4.8's
## PacketPeerUDP.bind(port, address, recv_buf_size) / UDPServer.listen exposes
## no SO_REUSEADDR / reuse-port option (verified against the class reference
## and PacketPeerUDP::bind, which never sets it), so two listeners can't share
## the port; instead the browser keeps retrying the bind every RETRY_S while
## it exists and reports through `listening_changed`. Manual ip:port joins
## never depend on this (Net.start_joining is a separate ENet socket).

signal changed # a host appeared, updated, or timed out
signal listening_changed(listening: bool) # a (re)bind succeeded — emitted with true; start() returns the first failure

const RETRY_S := 2.0

var _udp: PacketPeerUDP = null
var _hosts: Dictionary = {} # "address:port" -> row dict
var _sweep_t := 0.0
var _retry_t := 0.0
var last_error: String = ""
var retries := 0 # bind attempts that failed since start() (status/tests)

## Bind now; on failure the browser stays alive and retries from _process.
## Returns the first attempt's result (OK / the bind error).
func start() -> Error:
	stop()
	retries = 0
	set_process(true)
	return _try_bind()

func stop() -> void:
	if _udp != null:
		_udp.close()
		_udp = null
	set_process(false)

func is_listening() -> bool:
	return _udp != null

func _try_bind() -> Error:
	var udp := PacketPeerUDP.new()
	var err := udp.bind(Constants.LAN_BEACON_PORT, "0.0.0.0")
	if err != OK:
		last_error = "could not listen on UDP %d (%s)" % [Constants.LAN_BEACON_PORT, error_string(err)]
		if retries == 0:
			push_warning("LanBrowser: " + last_error + " - retrying every %.0f s" % RETRY_S)
		retries += 1
		_retry_t = RETRY_S
		udp.close()
		return err
	_udp = udp
	last_error = ""
	_retry_t = 0.0
	listening_changed.emit(true)
	return OK

## Live hosts, newest beacon first: {address, port, world, players, cap, build, last_seen}.
func hosts() -> Array:
	var out: Array = _hosts.values()
	out.sort_custom(func(a, b): return a.last_seen > b.last_seen)
	return out

func _process(delta: float) -> void:
	if _udp == null:
		_retry_t -= delta
		if _retry_t <= 0.0:
			_try_bind()
		return
	var touched := false
	while _udp.get_available_packet_count() > 0:
		var packet := _udp.get_packet()
		var from := _udp.get_packet_ip()
		var row := parse_beacon(packet.get_string_from_utf8(), from)
		if row.is_empty():
			continue
		var key := "%s:%d" % [row.address, row.port]
		# A host on this machine is heard twice (LAN broadcast + loopback):
		# keep the LAN address, which other machines can also use.
		if _is_loopback(row.address) and _has_twin(row, false):
			continue
		if not _is_loopback(row.address):
			for k in _hosts.keys():
				if _is_loopback(_hosts[k].address) and _same_host(_hosts[k], row):
					_hosts.erase(k)
		if not _hosts.has(key):
			print("[lan] host seen: '%s' %d/%d at %s (build %s)" % [row.world, row.players, row.cap, key, row.build])
		_hosts[key] = row
		touched = true
	_sweep_t += delta
	if _sweep_t >= 1.0:
		_sweep_t = 0.0
		var now := Time.get_ticks_msec() / 1000.0
		for key in _hosts.keys():
			if now - float(_hosts[key].last_seen) > Constants.NET_BEACON_TIMEOUT:
				_hosts.erase(key)
				touched = true
	if touched:
		changed.emit()

static func _is_loopback(address: String) -> bool:
	return address.begins_with("127.") or address == "::1"

static func _same_host(a: Dictionary, b: Dictionary) -> bool:
	return a.world == b.world and a.port == b.port and a.build == b.build

func _has_twin(row: Dictionary, loopback: bool) -> bool:
	for k in _hosts:
		if _is_loopback(_hosts[k].address) == loopback and _same_host(_hosts[k], row):
			return true
	return false

## One beacon string -> a row dict ({} when it isn't ours).
static func parse_beacon(text: String, address: String) -> Dictionary:
	var parts := text.split("|")
	if parts.size() < 5 or parts[0] != Net.BEACON_MAGIC:
		return {}
	var counts := parts[3].split("/")
	return {
		"address": address, "port": int(parts[4]), "world": parts[2],
		"players": int(counts[0]) if counts.size() > 0 else 0,
		"cap": int(counts[1]) if counts.size() > 1 else 0,
		"build": parts[1], "last_seen": Time.get_ticks_msec() / 1000.0,
	}
