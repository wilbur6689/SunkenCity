extends Node
## Perf probe (2026-09-05, user request): samples frame costs for a fixed
## number of seconds, then prints one PERF report block and quits. Needs a
## window (renderers must actually run) - not --headless.
##
##   godot --path . -- --seed=1 --perf=8 [--zoom=IDX] [--objwin=WxH] [--enemywin=WxH] [--walk]
##
## --zoom     index into Constants.CAMERA_ZOOM_LEVELS (0 = widest)
## --objwin   object streaming window in cells (default Constants.OBJECT_WINDOW)
## --enemywin enemy streaming window in cells
## --walk     hold right for the whole run so windows churn (jumps at walls)
## Report: avg/min fps, avg / p95 / max frame ms, and the mean of every
## World.perf timer, plus live counts at the end.

var seconds := 8.0
var walk := false
var _t := 0.0
var _warm := 1.0
var _frames: PackedFloat32Array = PackedFloat32Array()
var _sums := {}
var _n := 0
var player: Player

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--perf="):
			seconds = maxf(a.substr(7).to_float(), 1.0)
		elif a == "--walk":
			walk = true
	set_process(true)

func _process(delta: float) -> void:
	if player == null:
		player = Net.local_player() as Player
		if player == null:
			return
	if _warm > 0.0:
		_warm -= delta # first second: streaming settles
		return
	if walk: # drive through the input map (works like m0_smoke / net_probe)
		Input.action_press("move_right")
		if int(_t * 2.0) % 2 == 0:
			Input.action_press("jump")
		else:
			Input.action_release("jump")
	_t += delta
	_frames.append(delta * 1000.0)
	for k in World.perf:
		if typeof(World.perf[k]) == TYPE_FLOAT:
			_sums[k] = float(_sums.get(k, 0.0)) + float(World.perf[k])
	_sums["draw_calls"] = float(_sums.get("draw_calls", 0.0)) + Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_sums["physics_ms"] = float(_sums.get("physics_ms", 0.0)) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_sums["process_ms"] = float(_sums.get("process_ms", 0.0)) + Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_n += 1
	if _t >= seconds:
		_report()

func _report() -> void:
	var sorted := _frames.duplicate()
	sorted.sort()
	var total := 0.0
	for f in sorted:
		total += f
	var avg := total / maxf(sorted.size(), 1)
	var p95: float = sorted[int(sorted.size() * 0.95)] if sorted.size() > 0 else 0.0
	var worst: float = sorted[sorted.size() - 1] if sorted.size() > 0 else 0.0
	var cam := get_viewport().get_camera_2d()
	var zoom: float = cam.zoom.x if cam != null else 0.0
	var view_px: Vector2 = get_viewport().get_visible_rect().size / maxf(zoom, 0.01)
	var lines := PackedStringArray()
	lines.append("PERF zoom=%.2f view=%dx%d cells objwin=%dx%d enemywin=%dx%d walk=%s frames=%d" % [
		zoom, ceili(view_px.x / Constants.BLOCK_SIZE), ceili(view_px.y / Constants.BLOCK_SIZE),
		World.object_window.x, World.object_window.y, World.enemy_window.x, World.enemy_window.y, str(walk), _n])
	lines.append("PERF fps avg %.1f · frame ms avg %.2f · p95 %.2f · worst %.2f · process %.2f · physics %.2f · draw calls %d" % [
		1000.0 / maxf(avg, 0.001), avg, p95, worst,
		float(_sums.get("process_ms", 0.0)) / _n, float(_sums.get("physics_ms", 0.0)) / _n, int(float(_sums.get("draw_calls", 0.0)) / _n)])
	lines.append("PERF ms avg: water sim %.2f · water draw %.2f · fog %.2f · light %.2f · tiles %.2f · obj scan %.2f · enemy scan %.2f" % [
		float(_sums.get("water_ms", 0.0)) / _n, float(_sums.get("water_draw_ms", 0.0)) / _n, float(_sums.get("fog_ms", 0.0)) / _n,
		float(_sums.get("light_ms", 0.0)) / _n, float(_sums.get("struct_ms", 0.0)) / _n,
		float(_sums.get("obj_scan_ms", 0.0)) / _n, float(_sums.get("enemy_scan_ms", 0.0)) / _n])
	var items := 0
	var asleep := 0
	for it in World.items_root.get_children():
		if it is WorldItem:
			items += 1
			if it.asleep:
				asleep += 1
	lines.append("PERF live: objects %d/%d · enemies %d/%d (%d nodes) · items %d (%d asleep) · water cells %d · fog cells %d · painted %d · nodes %d · bodies %d" % [
		World.perf.objects_live, World.perf.objects_total, World.perf.enemies_live, World.perf.enemies_total,
		get_tree().get_nodes_in_group("enemies").size(), items, asleep, World.perf.water_cells, World.perf.fog_cells,
		World.perf.struct_cells, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)])
	for l in lines:
		print(l)
	get_tree().quit()
