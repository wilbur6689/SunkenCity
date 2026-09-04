extends Node
## Throwaway check (2026-09-02): the spawn cluster (central 20%) must be
## full height (56 floors) with gaps of CLUSTER_GAP_MIN..MAX cells and neighbouring
## roof rows LIFT_STEP_MIN..MAX cells apart (the crown-lift walk). 8 px cells.

func _ready() -> void:
	var fails := 0
	for s: int in [1, 2, 3, 101, 777]:
		var r := CityGen.generate(s)
		var cluster: Array = []
		for t in r.tower_list:
			var mid := (int(t.x0) + int(t.x1)) * 0.5
			if 1.0 - absf(mid - CityGen.WORLD_W / 2.0) / (CityGen.WORLD_W / 2.0) > 0.8:
				cluster.append(t)
		var floors_list: Array = []
		var gaps: Array = []
		var roof_diffs: Array = []
		for i in cluster.size():
			floors_list.append(int(cluster[i].floors))
			if i > 0:
				gaps.append(int(cluster[i].x0) - int(cluster[i - 1].x1) - 1)
				roof_diffs.append(absi(int(cluster[i].top) - int(cluster[i - 1].top)))
		print("seed %6d: %d cluster towers, floors %s, gaps %s, roof diffs %s" % [
			s, cluster.size(), floors_list, gaps, roof_diffs])
		for f in floors_list:
			if int(f) != 56:
				fails += 1
				print("  FAIL: cluster tower has %d floors" % f)
		for g in gaps:
			if int(g) < CityGen.CLUSTER_GAP_MIN or int(g) > CityGen.CLUSTER_GAP_MAX:
				fails += 1
				print("  FAIL: cluster gap of %d blocks" % g)
		for d in roof_diffs:
			if int(d) < CityGen.LIFT_STEP_MIN or int(d) > CityGen.LIFT_STEP_MAX:
				fails += 1
				print("  FAIL: neighbouring roofs differ by %d blocks" % d)
		if cluster.size() < 3:
			fails += 1
			print("  FAIL: only %d cluster towers" % cluster.size())
	print("Cluster check: %s" % ("OK" if fails == 0 else "%d FAILURES" % fails))
	get_tree().quit(0 if fails == 0 else 1)
