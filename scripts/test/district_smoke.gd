extends Node
## Headless gate for the district city (docs/DistrictsOverhaul.md, 2026-09-04):
## 52 towers at hoppable gaps, a residential centre, five buffered district
## clusters, one building type per tower, per-district floor pitch, a flat
## skyline, every tower down to the ground, construction's frame palette,
## floor-level band resolution, and the generation budget.
## Run: godot --path . --headless res://scenes/test/district_smoke.tscn

var failures: PackedStringArray = []
var checks := 0

func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok:   " if cond else "  FAIL: ") + msg)
	if not cond:
		failures.append(msg)

func _ready() -> void:
	print("== A. full city, three seeds")
	for s: int in [1, 2, 777]:
		var t0 := Time.get_ticks_msec()
		var r := CityGen.generate(s)
		var ms := Time.get_ticks_msec() - t0
		var towers: Array = r.tower_list
		var d: Array = r.districts
		print("seed %d: %d towers in %d ms, districts %s" % [s, towers.size(), ms, _runs(d)])
		check(towers.size() == CityGen.TOWER_COUNT, "seed %d: %d towers" % [s, towers.size()])
		check(ms <= 5000, "seed %d: generation %d ms within the 5 s budget" % [s, ms])
		# centre: CENTER_TOWERS contiguous residential slots around the middle
		var c0: int = int(r.center[0])
		var c1: int = int(r.center[1])
		var centre_ok := c1 - c0 + 1 == CityGen.CENTER_TOWERS and absi((c0 + c1) / 2 - towers.size() / 2) <= 1
		for i in range(c0, c1 + 1):
			centre_ok = centre_ok and String(d[i]) == "residential" and bool(towers[i].center)
		check(centre_ok, "seed %d: the centre is %d residential towers (slots %d-%d)" % [s, CityGen.CENTER_TOWERS, c0, c1])
		# clusters: each placed district is one contiguous run of 5-6, never adjacent to another
		var runs := {}
		var contiguous := true
		var buffered := true
		var i := 0
		while i < d.size():
			var j := i
			while j + 1 < d.size() and d[j + 1] == d[i]:
				j += 1
			if d[i] != "residential":
				if runs.has(d[i]):
					contiguous = false
				runs[d[i]] = j - i + 1
				if j + 1 < d.size() and d[j + 1] != "residential":
					buffered = false
			i = j + 1
		check(runs.size() == CityGen.DISTRICTS.size(), "seed %d: all %d districts placed (%s)" % [s, CityGen.DISTRICTS.size(), runs])
		check(contiguous, "seed %d: every district is one contiguous cluster" % s)
		var sizes_ok := true
		for k in runs:
			if int(runs[k]) < CityGen.DISTRICT_SIZE_MIN or int(runs[k]) > CityGen.DISTRICT_SIZE_MAX:
				sizes_ok = false
		check(sizes_ok, "seed %d: clusters are %d-%d towers" % [s, CityGen.DISTRICT_SIZE_MIN, CityGen.DISTRICT_SIZE_MAX])
		check(buffered, "seed %d: a residential tower buffers every pair of districts" % s)
		var res := 0
		for k in d:
			if k == "residential":
				res += 1
		check(res >= towers.size() * 3 / 10 and res <= towers.size() * 6 / 10, "seed %d: residential is roughly half the city (%d of %d)" % [s, res, towers.size()])
		# skyline + shafts to the ground + district shape
		var top_min := 99999
		var top_max := -1
		var ground_ok := true
		var pitch_ok := true
		var wings_ok := true
		var gaps_ok := true
		var steps_ok := true
		var hatches := {}
		for o in r.objects:
			if o.id == "roof_hatch":
				hatches[o.cell] = true
		var hatch_ok := true
		var blockages := 0
		for k in towers.size():
			var t: Dictionary = towers[k]
			top_min = mini(top_min, int(t.top))
			top_max = maxi(top_max, int(t.top))
			if int(t.top) + int(t.floors) * int(t.floor_h) + int(t.lift) != CityGen.GROUND:
				ground_ok = false
			if int(t.floor_h) != int(CityGen.DISTRICT_FLOOR_H[t.district]) or t.district != d[k]:
				pitch_ok = false
			if int(t.wings) == 3 and not CityGen.TRIPLE_WIDE.has(t.district):
				wings_ok = false
			if int(t.wings) != (t.shafts as Array).size() + 1 or int(t.wings) != (t.zones as Array).size():
				wings_ok = false
			for sh in t.shafts:
				if not hatches.has(Vector2i(int(sh[0]), int(t.top) + CityGen.SLAB_T - 1)):
					hatch_ok = false
			if k > 0:
				var gap: int = int(t.x0) - int(towers[k - 1].x1) - 1
				if gap < CityGen.CLUSTER_GAP_MIN or gap > CityGen.CLUSTER_GAP_MAX:
					gaps_ok = false
				var step: int = absi(int(t.top) - int(towers[k - 1].top))
				if step < CityGen.LIFT_STEP_MIN or step > CityGen.LIFT_STEP_MAX:
					steps_ok = false
			blockages += CityGen.floor_blockages(r.grid, t).size()
		check(top_max - top_min <= CityGen.SKYLINE_BAND, "seed %d: crowns span %d cells (<= %d)" % [s, top_max - top_min, CityGen.SKYLINE_BAND])
		check(top_max < CityGen.WATERLINE, "seed %d: every crown is above the waterline (The Dry is one layer)" % s)
		check(ground_ok, "seed %d: every tower reaches the ground (floors x pitch + plinth)" % s)
		check(pitch_ok, "seed %d: floor pitch and zone follow the tower's district" % s)
		check(wings_ok, "seed %d: triple-wide only where allowed; wings = shafts + 1 = zones" % s)
		check(hatch_ok, "seed %d: every shaft mouth on a dry crown wears a hatch" % s)
		check(gaps_ok, "seed %d: every gap is hoppable (%d-%d cells)" % [s, CityGen.CLUSTER_GAP_MIN, CityGen.CLUSTER_GAP_MAX])
		check(steps_ok, "seed %d: neighbouring roofs step %d-%d cells" % [s, CityGen.LIFT_STEP_MIN, CityGen.LIFT_STEP_MAX])
		check(blockages == 0, "seed %d: two-jump rule holds on every floor" % s)
		# construction: metal + wood only, no sealed rooms
		var con: Dictionary = {}
		var ind: Dictionary = {}
		for t in towers:
			if t.district == "construction" and con.is_empty():
				con = t
			if t.district == "industrial" and ind.is_empty():
				ind = t
		if not con.is_empty():
			var stone := 0
			for y in range(int(con.top), CityGen.GROUND):
				for x in range(int(con.x0), int(con.x1) + 1):
					if r.grid.structure_at(Vector2i(x, y)) == WorldGrid.M.STONE:
						stone += 1
			check(stone == 0, "seed %d: the construction tower is wood and metal only (%d stone cells)" % [s, stone])
			var sealed_in := 0
			for rect: Rect2i in r.sealed:
				if rect.position.x >= int(con.x0) and rect.end.x <= int(con.x1):
					sealed_in += 1
			check(sealed_in == 0, "seed %d: no sealed rooms in the construction tower" % s)
			var dry_back: int = r.grid.back_at(Vector2i(int(con.zones[0][0]) + 2, int(con.top) + CityGen.SLAB_T + 3))
			var wet_back: int = r.grid.back_at(Vector2i(int(con.zones[0][0]) + 2, CityGen.WATERLINE + 40))
			check(dry_back == WorldGrid.M.AIR and wet_back != WorldGrid.M.AIR, "seed %d: construction back walls only below the waterline" % s)
		if not ind.is_empty():
			check(int(ind.floor_h) == 20 and int(ind.floors) <= 34, "seed %d: industrial floors are 20 cells (%d floors)" % [s, int(ind.floors)])
		# floor-level band: a floor straddling the shallows/cold line takes shallows
		var probe: Dictionary = towers[0]
		var fh := int(probe.floor_h)
		var boundary := CityGen.WATERLINE + Constants.BAND_SHALLOWS_DEPTH
		var f := (boundary - int(probe.top)) / fh
		var ceiling := int(probe.top) + f * fh
		var sr := ceiling + fh - 1
		var cell := Vector2i(int(probe.zones[0][0]) + 1, sr)
		check(CityGen.band_row(towers, cell) == ceiling and CityGen.band_row(towers, Vector2i(5, sr)) == sr,
				"seed %d: band row is the floor's ceiling inside a tower, the cell's own row outside" % s)
		# pockets: the annex scales with the tower count, so density holds citywide
		var floors_total := 0
		for t in towers:
			floors_total += int(t.floors)
		var density := float((r.pockets as Array).size()) / floors_total
		check(density > 0.38, "seed %d: %.0f%% of floors carry an apartment doorway (target ~50%%)" % [s, density * 100.0])
		# construction rooms are furnished from their own pool only
		var con_ids := {}
		var con_foreign := 0
		for t in towers:
			if t.district != "construction":
				continue
			for o in r.objects:
				var c: Vector2i = o.cell
				if c.x >= int(t.x0) and c.x <= int(t.x1) and c.y >= int(t.top) and c.y < CityGen.GROUND:
					var oid: String = o.id
					if oid.begins_with("con_"):
						con_ids[oid] = true
					elif oid.begins_with("res_") or oid.begins_with("com_") or oid.begins_with("hos_") or oid.begins_with("bus_"):
						con_foreign += 1
		check(con_ids.size() >= 5 and con_foreign == 0, "seed %d: construction towers carry site gear (%d kinds), no other zone's furniture (%d)" % [s, con_ids.size(), con_foreign])
	print("== B. determinism + a narrow slice")
	var a := CityGen.generate(101, 1600)
	var b := CityGen.generate(101, 1600)
	check(a.grid.content_hash() == b.grid.content_hash() and str(a.districts) == str(b.districts), "same seed = same grid and district plan")
	check(a.tower_list.size() >= 6 and (a.districts as Array).count("residential") >= 3, "1600-wide slice: %d towers, districts %s" % [a.tower_list.size(), _runs(a.districts)])
	print("== C. runtime budget (DistrictsOverhaul: gen <= 5 s, RAM <= 64 MB, save <= 10 MB, water asleep)")
	SaveGame.pending_character = "__district_smoke__"
	var city = load("res://scenes/city/city.tscn").instantiate()
	add_child(city)
	var player = city.player
	player.set_multiplayer_authority(2)
	await get_tree().physics_frame
	var g: WorldGrid = World.grid
	var cells: int = g.bounds.size.x * g.bounds.size.y
	var mb := float(cells * 4) / 1048576.0 # 3 byte layers + water levels
	check(mb <= 64.0, "world grid + water: %.1f MB for %d x %d cells" % [mb, g.bounds.size.x, g.bounds.size.y])
	check(World.towers.size() == CityGen.TOWER_COUNT, "World.towers carries %d tower summaries" % World.towers.size())
	for i in 90:
		await get_tree().physics_frame
	var awake: int = World.water_sim.awake.size()
	check(awake < 2000, "water sim settles after load (%d awake cells)" % awake)
	SaveGame.save_world("__district_smoke__", city.seed_value)
	var sf := FileAccess.open(SaveGame.WORLD_DIR + "__district_smoke__" + SaveGame.WORLD_EXT, FileAccess.READ)
	var bytes: int = sf.get_length() if sf != null else -1
	if sf != null:
		sf.close()
	check(bytes > 0 and bytes <= 10 * 1048576, "world save is %.2f MB" % (float(bytes) / 1048576.0))
	var saved: Dictionary = SaveGame.read_world("__district_smoke__")
	var parts := ""
	for k in saved:
		var kb: int = var_to_bytes(saved[k]).size() / 1024
		if kb >= 64:
			parts += "%s %d KB · " % [k, kb]
	print("  save composition: " + parts)
	SaveGame.delete_world("__district_smoke__")
	check(World.floor_band_at(World.cell_at(player.global_position)) == "dry", "spawn roof is in The Dry")
	# The hoppable gaps between towers are open to the ocean: every gap column
	# holds water from the waterline down (user report 2026-09-05: dry gaps).
	var dry_gaps := 0
	var gap_probe := ""
	for i in range(1, World.towers.size()):
		var gx: int = int(World.towers[i - 1].x1) + 1
		var gw: int = int(World.towers[i].x0) - gx
		var cells_wet := 0
		for gy in [World.waterline_row + 4, World.waterline_row + 60, World.waterline_row + 300]:
			if World.is_water_cell(Vector2i(gx, gy)):
				cells_wet += 1
		if cells_wet < 3:
			dry_gaps += 1
			if gap_probe == "":
				gap_probe = "gap %d (x %d, %d wide) wet rows %d/3" % [i, gx, gw, cells_wet]
	check(dry_gaps == 0, "every inter-tower gap is flooded to the waterline (%d dry; %s)" % [dry_gaps, gap_probe])
	var probe_t: Dictionary = World.towers[0]
	var fh2 := int(probe_t.floor_h)
	var f2 := (World.waterline_row + Constants.BAND_SHALLOWS_DEPTH - int(probe_t.top)) / fh2
	var sr2 := int(probe_t.top) + f2 * fh2 + fh2 - 1
	var straddle := Vector2i(int(probe_t.x0) + 14, sr2)
	check(World.floor_band_at(straddle) == "shallows" and World.band_at(straddle) == "cold",
			"a floor straddling the Shallows/Cold line: floor band shallows, cell band cold (gates stay per cell)")
	print("\n%d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)

func _runs(d: Array) -> String:
	var out := ""
	var i := 0
	while i < d.size():
		var j := i
		while j + 1 < d.size() and d[j + 1] == d[i]:
			j += 1
		out += "%sx%d " % [String(d[i]).substr(0, 3), j - i + 1]
		i = j + 1
	return out.strip_edges()
