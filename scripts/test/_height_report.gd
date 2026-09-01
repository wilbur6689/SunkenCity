extends Node
## Throwaway analysis (2026-09-01, user request): skyline shape across 10
## seeds — every tower's floor count vs the starting (tallest) tower, split
## into the central 80% of the map vs the edge 20% (outer 10% each side).
## Run: godot --path . --headless res://scenes/test/_height_report.tscn

func _ready() -> void:
	var seeds := [1, 2, 3, 4, 5, 101, 202, 777, 4242, 90210]
	var all_central: Array = []
	var all_edge: Array = []
	var crowns: Array = []
	for s: int in seeds:
		var t0 := Time.get_ticks_msec()
		var r := CityGen.generate(s)
		var crown := 0
		for t in r.tower_list:
			crown = maxi(crown, int(t.floors))
		crowns.append(crown)
		var central: Array = []
		var edge: Array = []
		for t in r.tower_list:
			var mid := (int(t.x0) + int(t.x1)) * 0.5
			var d := absf(mid - CityGen.WORLD_W / 2.0) / (CityGen.WORLD_W / 2.0)
			(edge if d > 0.8 else central).append(int(t.floors))
		central.sort()
		edge.sort()
		all_central.append_array(central)
		all_edge.append_array(edge)
		print("seed %6d: %2d towers, crown %d, central80 %s, edge20 %s  (%d ms)" % [
			s, r.tower_list.size(), crown, _stats(central, crown), _stats(edge, crown),
			Time.get_ticks_msec() - t0])
	print("\n=== ALL SEEDS (floors, %% = of that seed's crown ~%d) ===" % [crowns[0]])
	print("central 80%%: " + _dist(all_central))
	print("edge 20%%:    " + _dist(all_edge))
	get_tree().quit(0)

func _stats(a: Array, crown: int) -> String:
	if a.is_empty():
		return "-"
	var sum := 0
	for v in a:
		sum += int(v)
	return "min %d / med %d / max %d (med %d%% of crown)" % [a[0], a[a.size() / 2], a[a.size() - 1],
		int(a[a.size() / 2]) * 100 / crown]

func _dist(a: Array) -> String:
	a = a.duplicate()
	a.sort()
	var sum := 0
	for v in a:
		sum += int(v)
	var buckets := {}
	for v in a:
		var b := int(v) / 10 * 10
		buckets[b] = int(buckets.get(b, 0)) + 1
	var keys := buckets.keys()
	keys.sort()
	var hist := ""
	for k in keys:
		hist += " %d-%d:%d" % [k, k + 9, buckets[k]]
	return "n=%d mean %.1f med %d [%s ]" % [a.size(), float(sum) / a.size(), a[a.size() / 2], hist]
