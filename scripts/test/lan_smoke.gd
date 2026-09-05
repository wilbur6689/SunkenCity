extends Node
## Headless LAN gate (Multiplayer step 2): host and client `Net` nodes in ONE
## process, each under its own subtree with its own SceneMultiplayer
## (`SceneTree.set_multiplayer(api, path)`), talking over ENet on localhost.
## Checks the handshake: accept, duplicate name, mismatched build, full world,
## client leave, host close, beacon text. Run:
##   godot --path . --headless res://scenes/test/lan_smoke.tscn

const PORT := 47777
const WORLD := "smoke_world"

var failures: PackedStringArray = []
var checks := 0
var _side_n := 0

func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok:   " if cond else "  FAIL: ") + msg)
	if not cond:
		failures.append(msg)

func until(pred: Callable, frames: int) -> bool:
	for i in frames:
		if pred.call():
			return true
		await get_tree().process_frame
	return pred.call()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## A subtree with its own MultiplayerAPI and a plain `Net` node inside it
## (the autoload at /root/Net stays OFFLINE and untouched).
func _make_side(label: String) -> Node:
	_side_n += 1
	var side := Node.new()
	side.name = label
	add_child(side)
	get_tree().set_multiplayer(SceneMultiplayer.new(), side.get_path())
	var n := Node.new()
	n.name = "Net"
	n.set_script(load("res://scripts/net/net.gd"))
	n.require_world_ready = false
	n.beacon_enabled = false
	n.attach_sync_nodes = false
	n.auto_enter_city = false
	side.add_child(n)
	return n

func _ready() -> void:
	await _run()
	print("\nLAN smoke: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)

func _run() -> void:
	print("== A. host opens, a client joins and passes the handshake")
	var host: Node = _make_side("HostSide")
	host.host_character = "hosty"
	check(host.host(PORT, 3, WORLD) == OK, "host() opens the listen server on %d" % PORT)
	check(host.mode == host.Mode.HOST and host.is_server() and not host.is_client(), "host mode: is_server, not client")
	check(host.local_peer() == 1 and host.peers.has(1) and host.peers[1].name == "hosty", "host is peer 1 in its own table")
	check(host.beacon_text().begins_with("SUNKENCITY|%s|%s|1/3|%d" % [host.BUILD_ID, WORLD, PORT]),
		"beacon text: %s" % host.beacon_text())
	var parsed := LanBrowser.parse_beacon(host.beacon_text(), "127.0.0.1")
	check(parsed.get("world", "") == WORLD and parsed.get("port", 0) == PORT and parsed.get("players", 0) == 1 and parsed.get("cap", 0) == 3,
		"LanBrowser parses the beacon back")
	check(LanBrowser.parse_beacon("HELLO|x", "1.2.3.4").is_empty(), "foreign UDP chatter is ignored")

	var accepted: Array = []
	host.peer_accepted.connect(func(id, n): accepted.append([id, n]))
	var left: Array = []
	host.peer_left.connect(func(id): left.append(id))

	var alice: Node = _make_side("ClientA")
	var alice_joined: Array = []
	alice.joined.connect(func(id): alice_joined.append(id))
	var alice_failed: Array = []
	alice.join_failed.connect(func(r): alice_failed.append(r))
	check(alice.join("127.0.0.1", PORT, "alice") == OK, "join() starts a client")
	check(alice.mode == alice.Mode.CLIENT and alice.is_client() and not alice.is_server(), "client mode")
	var ok := await until(func(): return not alice_joined.is_empty(), 300)
	check(ok, "the host accepted alice (joined signal)")
	check(alice_failed.is_empty(), "no join_failed for a valid join")
	check(accepted.size() == 1 and accepted[0][1] == "alice", "host emitted peer_accepted('alice')")
	var alice_id: int = alice_joined[0] if not alice_joined.is_empty() else -1
	check(alice_id > 1 and host.peers.has(alice_id) and host.peers[alice_id].name == "alice", "host peer table has alice under her peer id")
	check(host.peers.get(alice_id, {}).get("state") == host.PeerState.LOADING, "a fresh peer starts LOADING (deltas queue until ready)")
	check(alice.world_name == WORLD, "the client learns the world name from _accepted")
	check(alice.local_peer() == alice_id, "client local_peer() is its ENet id")
	check(host.ready_peers().is_empty(), "ready_peers() excludes loading peers")
	host.peers[alice_id].state = host.PeerState.READY
	check(host.ready_peers() == [alice_id], "...and lists them once READY")

	print("== B. roster + ping reach the client within a second or two")
	ok = await until(func(): return alice.peers.has(1) and alice.peers[1].name == "hosty", 200)
	check(ok, "client roster lists the host by name")
	check(alice.peers.has(alice_id) and alice.peers[alice_id].name == "alice", "and itself")

	print("== C. refusals: duplicate name, other build, full world")
	var dup: Node = _make_side("ClientDup")
	var dup_failed: Array = []
	dup.join_failed.connect(func(r): dup_failed.append(r))
	var dup_joined: Array = []
	dup.joined.connect(func(id): dup_joined.append(id))
	dup.join("127.0.0.1", PORT, "Alice") # case-insensitive duplicate
	ok = await until(func(): return not dup_failed.is_empty(), 300)
	check(ok and dup_joined.is_empty(), "a duplicate character name is refused")
	check(ok and dup_failed[0].contains("already"), "...with a reason that says so: '%s'" % (dup_failed[0] if ok else ""))
	ok = await until(func(): return dup.mode == dup.Mode.OFFLINE, 300)
	check(ok, "the refused client tears down to OFFLINE")

	var old: Node = _make_side("ClientOldBuild")
	old.BUILD_ID = "0.0.0-bogus/w0/c0"
	var old_failed: Array = []
	old.join_failed.connect(func(r): old_failed.append(r))
	old.join("127.0.0.1", PORT, "bob")
	ok = await until(func(): return not old_failed.is_empty(), 300)
	check(ok and old_failed[0].contains("build"), "a mismatched build is refused with the build ids: '%s'" % (old_failed[0] if ok else ""))
	check(not host.peers.values().any(func(e): return e.name == "bob"), "the refused peer never entered the table")

	var bob: Node = _make_side("ClientB")
	var bob_joined: Array = []
	bob.joined.connect(func(id): bob_joined.append(id))
	var bob_dc: Array = []
	bob.disconnected.connect(func(r): bob_dc.append(r))
	bob.join("127.0.0.1", PORT, "bob")
	ok = await until(func(): return not bob_joined.is_empty(), 300)
	check(ok and host.peers.size() == 3, "a second client fills the world to its cap (3/3)")
	var carol: Node = _make_side("ClientC")
	var carol_failed: Array = []
	carol.join_failed.connect(func(r): carol_failed.append(r))
	carol.join("127.0.0.1", PORT, "carol")
	ok = await until(func(): return not carol_failed.is_empty(), 300)
	check(ok and carol_failed[0].contains("full"), "an over-cap joiner is told the world is full: '%s'" % (carol_failed[0] if ok else ""))

	print("== D. leaving and closing")
	alice.leave()
	check(alice.mode == alice.Mode.OFFLINE, "leave() puts the client OFFLINE at once")
	ok = await until(func(): return left.has(alice_id), 600)
	check(ok, "host sees alice leave (peer_left)")
	check(not host.peers.has(alice_id) and host.peers.size() == 2, "and drops her from the table")
	ok = await until(func(): return not bob.peers.has(alice_id), 200)
	check(ok, "the remaining client's roster drops her too")

	host.close_world()
	check(host.mode == host.Mode.OFFLINE and host.peers.is_empty(), "close_world() goes OFFLINE and clears the table")
	ok = await until(func(): return not bob_dc.is_empty(), 600)
	check(ok and bob_dc[0].contains("closed"), "clients get 'host closed the world': '%s'" % (bob_dc[0] if ok else ""))
	check(bob.mode == bob.Mode.OFFLINE, "the client tears down")
	ok = await until(func(): return host.peer == null, 120)
	check(ok, "the host socket closes after the flush")

	print("== E. a fresh host on the same port after close")
	check(host.host(PORT, 2, WORLD) == OK, "the port is free again")
	host.close_world()
	await frames(30)
	check(Net.mode == Net.Mode.OFFLINE and Net.peers.is_empty(), "the autoload Net stayed OFFLINE throughout")
