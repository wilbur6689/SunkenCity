extends Node
## Net/CharSync (LAN Step 7, docs/technical/MultiplayerImpl.md §7 and
## Multiplayer.md §7/§9): per-character state replication and the session-end
## bookkeeping. The HOST owns every character's game state (inventory,
## equipment, skills, known recipes/mods, vitals, spawn bed); this node
##
##   host   -> owner  `_char_state(dict)`  on any change (coalesced to once per
##                    tick, nudged by PlayerActions / Inventory.changed / skill
##                    signals) and every NET_CHAR_RESYNC_TICKS as a safety resync
##   host   -> owner  `_final_state(dict)` before a disconnect (close world, host
##                    save): the client writes its own character file from it
##   host             keeps `Net.peers[id].char_state` current and, when a peer
##                    leaves, stashes it in `resume_states[name]` so the same
##                    character rejoining resumes where it was (preferred over
##                    the file it uploads)
##   client           applies `_char_state` to its local puppet WITHOUT moving it
##                    (the body follows PlayerSync's stream), merges any LEGACY
##                    per-character map from its file into the shared world map
##                    at boot (the map is host-owned since 2026-09-06: it rides
##                    the snapshot and WorldSync `_map` deltas), and reacts to
##                    `Net.disconnected` by handing the scene the reason.
##
## The parent is the Net node (autoload, or a plain node in lan_smoke), so
## everything goes through `get_parent()` and `multiplayer`, never /root/Net.

## Character name -> state dict of a peer that left (host). Erased on rejoin.
var resume_states: Dictionary = {}

var _dirty: Dictionary = {}          # host: peer id -> true (ship this tick)
var _resync_ticks := 0
var _tracked: Dictionary = {}        # player instance id -> true (signals hooked)
var _pending_state: Dictionary = {}  # client: a _char_state that arrived before the local body existed
var _client_map_done := false        # client: map reveal applied from the character file

func _net() -> Node:
	return get_parent()

func _ready() -> void:
	var net := _net()
	if net.has_signal("peer_left"):
		net.peer_left.connect(_on_peer_left)
	if net.has_signal("disconnected"):
		net.disconnected.connect(_on_disconnected)

func _is_host() -> bool:
	return _net().get("mode") == Net.Mode.HOST

func _is_client() -> bool:
	return _net().get("mode") == Net.Mode.CLIENT

func _world_key() -> String:
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		var wn = tree.current_scene.get("world_name")
		if wn is String and wn != "":
			return wn
	return String(_net().get("world_name"))

# --- Change tracking (host) ---

## Hook a body's change signals (PlayerActions calls this from _ready; the
## host also calls it from apply_on_spawn). Safe to call twice.
func track(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	var key := player.get_instance_id()
	if _tracked.has(key):
		return
	_tracked[key] = true
	player.inventory.changed.connect(mark_dirty.bind(player))
	player.skills.leveled.connect(func(_s: String, _l: int): mark_dirty(player))
	player.skills.ability_unlocked.connect(func(_id: String): mark_dirty(player))
	player.tree_exiting.connect(func(): _tracked.erase(key))

## The owner's replica ships on the next physics tick.
func mark_dirty(player: Node) -> void:
	if not _is_host() or player == null or not is_instance_valid(player):
		return
	var pid: int = player.peer_id
	if pid != 1:
		_dirty[pid] = true

func _physics_process(_delta: float) -> void:
	if _is_host():
		_resync_ticks += 1
		var all := _resync_ticks >= Constants.NET_CHAR_RESYNC_TICKS
		if all:
			_resync_ticks = 0
		var net := _net()
		for pid in net.peers.keys():
			if pid == 1:
				continue
			if all or _dirty.has(pid):
				if net.peer_state(pid) == Net.PeerState.READY:
					push_state(pid)
		_dirty.clear()
	elif _is_client():
		_client_tick()
	else:
		_client_map_done = false
		_pending_state = {}
		_dirty.clear()

# --- State dicts ---

## The replicated character dict: the SaveGame character fields minus the
## per-world maps/positions/spawns, plus the live position and this world's
## spawn bed (so a resume and the client's own file both land right).
func state_of(player: Node) -> Dictionary:
	var st := SaveGame.character_state(player)
	st["pos"] = player.global_position
	st["spawn_feet"] = player.spawn_feet
	return st

## Drop anything the data files do not know: unknown item ids in the bag or
## on the body, unknown recipes / mods / abilities, and clamp the numbers.
func sanitize(st: Dictionary) -> Dictionary:
	var out := {}
	var inv: Array = []
	for s in st.get("inventory", []):
		inv.append(_clean_stack(s))
	inv.resize(Constants.INVENTORY_SLOTS)
	out["inventory"] = inv
	var eq := {}
	for slot_name in ["head", "suit", "weapon", "accessory1", "accessory2", "accessory3", "accessory4"]:
		var s = _clean_stack((st.get("equipment", {}) as Dictionary).get(slot_name))
		if s != null:
			if not Player.slot_fits(slot_name, String(s.id)):
				s = null
			else:
				s.count = 1
		eq[slot_name] = s
	out["equipment"] = eq
	var sk: Dictionary = st.get("skills", {})
	var xp := {}
	for name in Skills.START_SET:
		xp[name] = maxf(float((sk.get("xp", {}) as Dictionary).get(name, 0.0)), 0.0)
	var abilities := {}
	for id in sk.get("abilities", {}):
		if Data.abilities.has(id):
			abilities[id] = true
	var spent: int = clampi(int(sk.get("spent", 0)), 0, abilities.size())
	out["skills"] = {"xp": xp, "spent": spent, "abilities": abilities}
	var recipes := {}
	for id in st.get("known_recipes", {}):
		if Data.recipes.has(id):
			recipes[id] = true
	out["known_recipes"] = recipes
	out["mod_library"] = SaveGame.clean_library(st.get("mod_library", {}))
	out["health"] = clampf(float(st.get("health", Constants.MAX_HEALTH)), 0.0, Constants.MAX_HEALTH)
	out["oxygen"] = maxf(float(st.get("oxygen", Constants.BASE_OXYGEN_SECONDS)), 0.0)
	out["selected_slot"] = clampi(int(st.get("selected_slot", 0)), 0, Constants.HOTBAR_SLOTS - 1)
	out["bare_hands"] = bool(st.get("bare_hands", false))
	out["compact"] = bool(st.get("compact", false))
	if st.get("pos") is Vector2:
		out["pos"] = st.pos
	if st.get("spawn_feet") is Vector2:
		out["spawn_feet"] = st.spawn_feet
	return out

func _clean_stack(s):
	if not (s is Dictionary) or not s.has("id") or not Data.items.has(String(s.id)):
		return null
	var id := String(s.id)
	var out := {"id": id, "count": clampi(int(s.get("count", 1)), 1, Data.stack_size(id))}
	if s.get("mods") is Dictionary and not (s.mods as Dictionary).is_empty():
		out["mods"] = (s.mods as Dictionary).duplicate(true)
	return ItemMods.clean_stack(out) # the shared cleaner: known ids, right slot, no `power`, count 1

## Apply a state dict to a body. `move` also places it (host spawn / resume);
## a client applies WITHOUT moving (the state stream drives the body) and
## keeps its own hotbar selection (the input snapshot is authoritative).
func apply_state(player: Node, st: Dictionary, move: bool) -> void:
	if st.is_empty():
		return
	var inv: Array = (st.inventory as Array).duplicate(true)
	inv.resize(Constants.INVENTORY_SLOTS)
	player.inventory.slots = inv
	for slot_name in player.equipment.keys():
		player.equipment[slot_name] = (st.equipment as Dictionary).get(slot_name)
	player.skills.xp = (st.skills.xp as Dictionary).duplicate()
	player.skills.spent_points = int(st.skills.spent)
	player.skills.abilities = (st.skills.get("abilities", {}) as Dictionary).duplicate()
	player.known_recipes = (st.get("known_recipes", {}) as Dictionary).duplicate()
	player.mod_library = (st.get("mod_library", {}) as Dictionary).duplicate()
	player.health = float(st.health)
	player.oxygen = float(st.oxygen)
	if st.has("spawn_feet"):
		player.spawn_feet = st.spawn_feet
	if move:
		player.selected_slot = int(st.get("selected_slot", 0))
		player.bare_hands = bool(st.get("bare_hands", false))
		if st.has("pos"):
			player.global_position = st.pos
			player.velocity = Vector2.ZERO
			if bool(st.get("compact", false)):
				player.begin_loaded_crawl()
			player.unstick()
			player.reset_physics_interpolation()
	player.inventory.changed.emit()

# --- Host: spawn, push, session end ---

## Host: dress and place a joining peer's body. A state stashed from an
## earlier visit this session wins over the file the client uploaded; either
## way every id is validated against Data and the character's saved position
## / bed for THIS world is honoured (SaveGame.apply_character semantics minus
## the map reveal, which stays on the client).
func apply_on_spawn(player: Node, peer_id: int) -> void:
	var net := _net()
	var entry: Dictionary = net.peers.get(peer_id, {})
	var name := String(entry.get("name", player.character_name))
	var uploaded: Dictionary = entry.get("char_state", {})
	var st: Dictionary = {}
	if resume_states.has(name):
		st = resume_states[name]
		resume_states.erase(name)
	elif not uploaded.is_empty():
		st = uploaded.duplicate(true)
		var wk := _world_key()
		st.erase("pos")
		st.erase("spawn_feet")
		if (uploaded.get("spawns", {}) as Dictionary).has(wk):
			st["spawn_feet"] = uploaded.spawns[wk]
		if (uploaded.get("positions", {}) as Dictionary).has(wk):
			st["pos"] = uploaded.positions[wk]
	if not st.is_empty():
		var clean := sanitize(st)
		apply_state(player, clean, true)
		if net.peers.has(peer_id):
			net.peers[peer_id].char_state = clean
	track(player)
	_dirty[peer_id] = true # the client's replica fills as soon as it is READY

func push_state(peer_id: int) -> void:
	var net := _net()
	var player = net.player_of(peer_id)
	if player == null or not is_instance_valid(player):
		return
	var st := state_of(player)
	if net.peers.has(peer_id):
		net.peers[peer_id].char_state = st
	if _peer_live(peer_id):
		_char_state.rpc_id(peer_id, st)

## Host: bank every connected character into the peer table and hand each
## client its final state to write locally. Called by Net.close_world() and
## the host's save_now.
func push_final_states() -> void:
	if not _is_host():
		return
	var net := _net()
	for pid in net.peers.keys():
		if pid == 1:
			continue
		var player = net.player_of(pid)
		if player == null or not is_instance_valid(player):
			continue
		var st := state_of(player)
		net.peers[pid].char_state = st
		if _peer_live(pid) and net.peer_state(pid) == Net.PeerState.READY:
			_final_state.rpc_id(pid, st)
	_dirty.clear()

## Alias with the save-time meaning (city.save_now on the host).
func save_all_characters() -> void:
	push_final_states()

func _on_peer_left(peer_id: int) -> void:
	if not _is_host():
		return
	var net := _net()
	var entry: Dictionary = net.peers.get(peer_id, {})
	var name := String(entry.get("name", ""))
	if name == "":
		return
	var player = entry.get("player")
	var st: Dictionary = {}
	if player != null and is_instance_valid(player) and not player.is_queued_for_deletion():
		st = state_of(player)
	else:
		st = entry.get("char_state", {})
	if not st.is_empty():
		resume_states[name] = st
	_dirty.erase(peer_id)

func _peer_live(id: int) -> bool:
	var net := _net()
	if net.has_method("_peer_live"):
		return net._peer_live(id)
	return id in multiplayer.get_peers()

# --- Client ---

func _client_tick() -> void:
	var player = _net().local_player()
	if player == null or not World.is_ready():
		return
	if not _pending_state.is_empty():
		apply_state(player, _pending_state, false)
		_pending_state = {}
	if not _client_map_done and World.map_reveal != null:
		_client_map_done = true
		var data := SaveGame.read_character(String(player.character_name))
		var wk := _world_key()
		if not data.is_empty() and (data.get("maps", {}) as Dictionary).has(wk):
			World.map_reveal.merge_bytes(data.maps[wk]) # legacy per-character map joins the shared one

## Client: the character file from the replica (F5 / leave / host push).
func save_local_character() -> void:
	var player = _net().local_player()
	if player == null or not World.is_ready():
		return
	SaveGame.save_character(String(player.character_name), player, _world_key())

func _on_disconnected(reason: String) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	if tree.current_scene.has_method("on_net_disconnected"):
		tree.current_scene.on_net_disconnected(reason)

@rpc("authority", "call_remote", "reliable")
func _char_state(st: Dictionary) -> void:
	if not _is_client():
		return
	var player = _net().local_player()
	if player == null or not is_instance_valid(player):
		_pending_state = st
		return
	apply_state(player, st, false)

@rpc("authority", "call_remote", "reliable")
func _final_state(st: Dictionary) -> void:
	if not _is_client():
		return
	var player = _net().local_player()
	if player == null or not is_instance_valid(player):
		return
	apply_state(player, st, false)
	save_local_character()
	player.message.emit("Character saved")
