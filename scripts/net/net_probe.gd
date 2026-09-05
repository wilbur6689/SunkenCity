extends Node
## Dev probe for LAN runs (docs/technical/MultiplayerImpl.md §8). city.gd adds
## this node when `--net-probe=SECS` is on the command line. Once a second it
## prints one line a driver (tools/lan_smoke.py) can compare between the host
## and a client:
##   NETPROBE t=<sec> mode=<host|client|offline> peers=<n> players=<n>
##           grid=<hash> water=<hash> records=<n> enemies=<n> items=<n> lp=<x,y>
## and quits after SECS through the real session-end path (a client saves its
## character and leaves; the host saves and closes the world, so connected
## clients get their final state and a "host closed the world" reason).
## `--net-drive` (a client) holds move_right for 2 s once the host has
## announced the local body (Input.action_press works headless, like
## m0_smoke), so the driver can see the local body move on both ends.

const DRIVE_SECONDS := 2.0

var seconds: int = 5
var drive: bool = false
var _t := 0.0
var _next_print := 0.0
var _tick := 0
var _drive_t := -1.0 # <0: not started; >= 0: seconds held
var _drive_done := false
var _quitting := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--net-probe="):
			seconds = maxi(1, int(a.substr(12)))
		elif a == "--net-drive":
			drive = true

func _process(delta: float) -> void:
	if _quitting:
		return
	_t += delta
	if drive and not _drive_done:
		_tick_drive(delta)
	if _t >= _next_print:
		_next_print += 1.0
		_print_line()
		_tick += 1
		if _tick > seconds:
			_finish()

## The body the host is actually simulating for us (a client's local puppet
## is parked at boot until Net/PlayerSpawn announces it).
func _driveable() -> bool:
	var lp := Net.local_player()
	if lp == null:
		return false
	if Net.is_client():
		var sync := lp.get_node_or_null("Sync")
		return sync != null and sync.get("announced") == true
	return true

func _tick_drive(delta: float) -> void:
	if _drive_t < 0.0:
		if not _driveable():
			return
		_drive_t = 0.0
		Input.action_press("move_right")
		print("NETPROBE drive: move_right pressed at t=%.1f" % _t)
	_drive_t += delta
	if _drive_t >= DRIVE_SECONDS:
		Input.action_release("move_right")
		_drive_done = true
		print("NETPROBE drive: move_right released")

func _finish() -> void:
	_quitting = true
	if drive and not _drive_done:
		Input.action_release("move_right")
	var scene := get_tree().current_scene
	if Net.is_client():
		if scene != null and scene.has_method("_save_local_character"):
			scene._save_local_character()
		Net.leave("")
		print("NETPROBE done (client left)")
	else:
		if scene != null and scene.has_method("save_now"):
			scene.save_now()
		if Net.is_online():
			Net.close_world()
			# Let the closing packets flush before the process dies.
			await get_tree().create_timer(0.5).timeout
		print("NETPROBE done (host closed)")
	get_tree().quit()

func _mode_name() -> String:
	match Net.mode:
		Net.Mode.HOST:
			return "host"
		Net.Mode.CLIENT:
			return "client"
	return "offline"

func _print_line() -> void:
	var grid_hash := 0
	var water_hash := 0
	var records := 0
	var enemies := 0
	var items := 0
	if World.is_ready():
		grid_hash = hash(World.grid.structure) ^ hash(World.grid.back) ^ hash(World.grid.climb)
		water_hash = hash(World.water_sim.levels)
		records = World.object_records.size()
		enemies = World.enemy_records.size()
		if World.items_root != null:
			for it in World.items_root.get_children():
				if it is WorldItem and not it.is_queued_for_deletion():
					items += 1
	var lp := Net.local_player()
	var lp_text := "none"
	if lp != null:
		lp_text = "%.1f,%.1f" % [lp.global_position.x, lp.global_position.y]
	print("NETPROBE t=%d mode=%s peers=%d players=%d grid=%d water=%d records=%d enemies=%d items=%d lp=%s" % [
		_tick, _mode_name(), Net.peers.size(), Net.players().size(), grid_hash, water_hash, records, enemies,
		items, lp_text])
