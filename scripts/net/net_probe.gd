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
## `--net-harvest` (a client, or offline) walks to the nearest hand-harvestable
## object, aims at it through Player.aim_override and holds RMB until the
## record is gone (or HARVEST_TIMEOUT), printing `NETPROBE harvest:` lines.

const DRIVE_SECONDS := 2.0
const HARVEST_TIMEOUT := 25.0
const HARVEST_SEARCH_BLOCKS := 40.0

var seconds: int = 5
var drive: bool = false
var harvest: bool = false
var _hv_rec: Dictionary = {}
var _hv_center: Vector2 = Vector2.ZERO
var _hv_t := -1.0
var _hv_holding := false
var _hv_done := false
var _hv_walk := "" # move action held while walking to the target
var _hv_last_msg := ""
var _hv_max_prog := 0.0
var _last_ms := 0 # highest scrap progress seen (local or streamed)
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
		elif a == "--net-harvest":
			harvest = true

func _process(delta: float) -> void:
	if _quitting:
		return
	_t += delta
	var now_ms := Time.get_ticks_msec()
	if _last_ms > 0 and now_ms - _last_ms > 400:
		# Godot caps the process delta, so this is wall-clock: a frame that
		# took this long stalled ENet too (the 2026-09-06 record-flush stall).
		print("NETPROBE stall: %d ms between frames at ms=%d (last frame process=%.0f ms physics=%.0f ms)" % [now_ms - _last_ms, now_ms,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	_last_ms = now_ms
	if drive and not _drive_done:
		_tick_drive(delta)
	if harvest and not _hv_done:
		_tick_harvest(delta)
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

## --net-harvest: pick the nearest kind=scrap record a bare hand can take
## (no requires_tool, tool_tier 0, skill 0), walk into reach, aim, hold RMB.
func _hv_pick(lp: Node2D) -> void:
	var best_d := HARVEST_SEARCH_BLOCKS * Constants.BLOCK_SIZE
	for rec: Dictionary in World.object_records:
		var def: Dictionary = rec.def
		if def.get("kind", "") != "scrap" or def.has("requires_tool"):
			continue
		if int(def.get("tool_tier", 0)) > 0 or int(def.get("skill", 0)) > 0:
			continue
		var c := _hv_center_of(rec)
		var d := c.distance_to(lp.global_position)
		if d < best_d and absf(c.y - lp.global_position.y) < 6 * Constants.BLOCK_SIZE:
			best_d = d
			_hv_rec = rec
			_hv_center = c

static func _hv_center_of(rec: Dictionary) -> Vector2:
	var bs := float(Constants.BLOCK_SIZE)
	var size: Array = rec.def.get("size", [1, 1])
	return Vector2(rec.cell) * bs + Vector2(float(size[0]) * bs * 0.5, bs * 0.5 - (float(size[1]) - 1.0) * bs * 0.5)

func _tick_harvest(delta: float) -> void:
	var lp := Net.local_player() as Node2D
	if _hv_t < 0.0:
		if not _driveable():
			return
		_hv_t = 0.0
		_hv_pick(lp)
		if _hv_rec.is_empty():
			print("NETPROBE harvest: no hand-harvestable object within %d blocks" % int(HARVEST_SEARCH_BLOCKS))
			_hv_done = true
			return
		print("NETPROBE harvest: target=%s cell=%s uid=%s dist=%.1f blocks" % [_hv_rec.id, _hv_rec.cell, _hv_rec.get("uid"),
			_hv_center.distance_to(lp.global_position) / Constants.BLOCK_SIZE])
	_hv_t += delta
	var msg: String = lp.interaction.message if lp.get("interaction") != null else ""
	if msg != _hv_last_msg and msg != "":
		print("NETPROBE harvest: say '%s' at t=%.1f" % [msg, _hv_t])
	_hv_last_msg = msg
	var reach: float = (lp.reach_blocks() - 1.5) * Constants.BLOCK_SIZE
	var gone: bool = not World.object_cells.has(_hv_rec.cell) or World.object_cells[_hv_rec.cell].get("uid") != _hv_rec.get("uid")
	if gone:
		print("NETPROBE harvest: DONE record gone after %.1f s (held %s, sfx_requests=%d, progress_seen=%.2f)" % [_hv_t, _hv_holding, Audio.sfx_requests, _hv_max_prog])
		_hv_stop()
		return
	if _hv_t >= HARVEST_TIMEOUT:
		print("NETPROBE harvest: TIMEOUT after %.1f s, record still there (held %s, scrapping=%s progress=%.2f)" % [_hv_t, _hv_holding,
			lp.interaction.scrapping != null, lp.interaction.scrap_progress])
		_hv_stop()
		return
	if _hv_center.distance_to(lp.global_position) > reach:
		var want := "move_right" if _hv_center.x > lp.global_position.x else "move_left"
		if _hv_walk != want:
			if _hv_walk != "":
				Input.action_release(_hv_walk)
			_hv_walk = want
			Input.action_press(want)
		if _hv_holding:
			Input.action_release("use_secondary")
			_hv_holding = false
		return
	if _hv_walk != "":
		Input.action_release(_hv_walk)
		_hv_walk = ""
	lp.aim_override = _hv_center
	if not _hv_holding:
		_hv_holding = true
		Input.action_press("use_secondary")
		print("NETPROBE harvest: in reach, RMB held at t=%.1f (aim %s)" % [_hv_t, _hv_center])
	else:
		_hv_max_prog = maxf(_hv_max_prog, maxf(lp.interaction.scrap_progress, lp.puppet_scrap_progress))
		if int(_hv_t * 2.0) != int((_hv_t - delta) * 2.0):
			print("NETPROBE harvest: t=%.1f scrapping=%s/%s progress=%.2f/%.2f sfx=%d" % [_hv_t, lp.interaction.scrapping != null,
				lp.puppet_scrapping, lp.interaction.scrap_progress, lp.puppet_scrap_progress, Audio.sfx_requests])

func _hv_stop() -> void:
	_hv_done = true
	if _hv_walk != "":
		Input.action_release(_hv_walk)
	if _hv_holding:
		Input.action_release("use_secondary")
	var lp := Net.local_player()
	if lp != null:
		lp.aim_override = Vector2.INF

func _finish() -> void:
	_quitting = true
	if drive and not _drive_done:
		Input.action_release("move_right")
	if harvest and not _hv_done:
		_hv_stop()
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
	print("NETPROBE t=%d mode=%s peers=%d players=%d grid=%d water=%d records=%d enemies=%d items=%d lp=%s ms=%d" % [
		_tick, _mode_name(), Net.peers.size(), Net.players().size(), grid_hash, water_hash, records, enemies,
		items, lp_text, Time.get_ticks_msec()])
