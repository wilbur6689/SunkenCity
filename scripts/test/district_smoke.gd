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
			blockages += CityGen.floor_blockages(r.grid, t, true).size()
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
			for y in range(int(con.top), CityGen.ground_row()):
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
		var boundary := CityGen.WATERLINE + Constants.STAGE_FLOOR_DEPTH_SHALLOWS # build lattice
		var f := (boundary - int(probe.top)) / fh
		var ceiling := CityGen.floor_ceiling(probe, f) # world rows: above the gap
		var sr := CityGen.floor_standing_row(probe, f) # ... and below it
		var cell := Vector2i(int(probe.zones[0][0]) + 1, sr)
		check(CityGen.band_row(towers, cell) == ceiling and CityGen.band_row(towers, Vector2i(5, sr)) == sr,
				"seed %d: band row is the floor's ceiling inside a tower, the cell's own row outside" % s)
		# pockets: the annex scales with the tower count, so density holds citywide
		var floors_total := 0
		for t in towers:
			floors_total += int(t.floors)
		var density := float((r.pockets as Array).size()) / floors_total
		check(density > 0.38, "seed %d: %.0f%% of floors carry an apartment doorway (target ~50%%)" % [s, density * 100.0])
		# stage gaps (user request 2026-09-06): three open bands spliced in,
		# bare back wall across every footprint, garbage everywhere else.
		var gaps: Array = CityGen.stage_gaps()
		check(r.grid.bounds.size.y == CityGen.world_h() and gaps.size() == 3 and CityGen.ground_row() == CityGen.GROUND + 3 * CityGen.GAP_ROWS,
				"seed %d: the grid is %d rows (3 gaps of %d spliced in), ground at %d" % [s, r.grid.bounds.size.y, CityGen.GAP_ROWS, CityGen.ground_row()])
		var gap_bad := 0
		var plug_bad := 0
		var wet_above := 0
		for g: Vector2i in gaps:
			for x in range(0, int(r.city_w)):
				var in_tower := false
				for t in towers:
					if x >= int(t.x0) and x <= int(t.x1):
						in_tower = true
						break
				var edge_d := 99999 # distance from the nearest footprint edge (the heap may spill this far)
				for t in towers:
					if x >= int(t.x0) and x <= int(t.x1):
						edge_d = mini(x - int(t.x0), int(t.x1) - x)
				for y in range(g.x, g.y):
					var c := Vector2i(x, y)
					if in_tower:
						var m: int = r.grid.structure_at(c)
						var heap: bool = m == WorldGrid.M.GARBAGE and edge_d < CityGen.plug_reach(y - g.x)
						if (m != WorldGrid.M.AIR and not heap) or r.grid.back_at(c) == WorldGrid.M.AIR or r.grid.climb_at(c) != WorldGrid.C.NONE:
							gap_bad += 1
					elif r.grid.structure_at(c) == WorldGrid.M.AIR: # garbage, or a relay's floor slab
						plug_bad += 1
				if not in_tower and r.grid.structure_at(Vector2i(x, g.x - 1)) == WorldGrid.M.AIR:
					wet_above += 1
		check(gap_bad == 0, "seed %d: every gap row inside a footprint is bare back wall, bar the heap's slope (%d bad cells)" % [s, gap_bad])
		var heap_ok := true
		if towers.size() > 1: # the heap between towers 0 and 1: gap-wide on top, PLUG_SLOPE cells wider per row below
			var hx0 := int(towers[0].x1) + 1
			var hx1 := int(towers[1].x0) - 1
			for k in CityGen.GAP_ROWS:
				var reach := CityGen.plug_reach(k)
				var y: int = (gaps[0] as Vector2i).x + k
				if r.grid.structure_at(Vector2i(hx0 - reach, y)) != WorldGrid.M.GARBAGE or r.grid.structure_at(Vector2i(hx1 + reach, y)) != WorldGrid.M.GARBAGE 						or r.grid.structure_at(Vector2i(hx0 - reach - 1, y)) == WorldGrid.M.GARBAGE:
					heap_ok = false
		check(heap_ok, "seed %d: the plug is a heap - gap-wide at the top, one cell wider each side per %d rows" % [s, CityGen.PLUG_SLOPE])
		check(plug_bad == 0, "seed %d: every open-water column is plugged solid through the whole gap (%d holes)" % [s, plug_bad])
		check(wet_above > 200, "seed %d: open water sits right on top of the plugs (%d columns)" % [s, wet_above])
		var crossing := 0
		var straddles := func(y0: int, y1: int) -> bool:
			for g: Vector2i in gaps:
				if y0 < g.y and g.x <= y1:
					return true
			return false
		for o in r.objects:
			var h := int(Data.objects[o.id].size[1])
			if straddles.call(int(o.cell.y) - h + 1, int(o.cell.y)):
				crossing += 1
		for dd in r.doors:
			var h := int(Data.objects[dd.id].size[1])
			if straddles.call(int(dd.cell.y) - h + 1, int(dd.cell.y)):
				crossing += 1
		for rect: Rect2i in r.sealed:
			if straddles.call(rect.position.y, rect.end.y - 1):
				crossing += 1
		check(crossing == 0, "seed %d: no object, door or sealed room crosses a gap (%d)" % [s, crossing])
		var portal_cells := {}
		for o in r.objects:
			if o.has("link"):
				portal_cells[o.cell] = true
		var orphan_pockets := 0
		for p in r.pockets:
			if not portal_cells.has(p.exit) or not portal_cells.has(p.entry):
				orphan_pockets += 1
		check(orphan_pockets == 0, "seed %d: every surviving pocket keeps both doorways (%d orphans)" % [s, orphan_pockets])
		var relays_on_plugs := 0
		for shell: Rect2i in r.relays:
			for g: Vector2i in gaps:
				if shell.end.y == g.x:
					relays_on_plugs += 1
		check((r.relays as Array).size() == 3 and relays_on_plugs == 3, "seed %d: the three relay pylons stand on the plugs (%d/%d)" % [s, relays_on_plugs, (r.relays as Array).size()])
		check(r.grid.structure_at(Vector2i(int(r.city_w) / 2, CityGen.ground_row())) == WorldGrid.M.STONE
				and r.grid.structure_at(Vector2i(3, CityGen.ground_row() - 1)) == WorldGrid.M.AIR, "seed %d: the ground moved down with the splice" % s)
		# construction rooms are furnished from their own pool only
		var con_ids := {}
		var con_foreign := 0
		for t in towers:
			if t.district != "construction":
				continue
			for o in r.objects:
				var c: Vector2i = o.cell
				if c.x >= int(t.x0) and c.x <= int(t.x1) and c.y >= int(t.top) and c.y < CityGen.ground_row():
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
	check(World.floor_band_at(World.cell_at(player.global_position)) == "roof", "spawn roof is T0 Rooftops (2026-09-06)")
	print("== predator fish seed the flooded Shallows and Cold (2026-09-06)")
	var fish_by_band := {}
	var fish_wrong := 0
	for rec in World.enemy_records:
		if rec.type in ["tropical_fish", "catfish", "barracuda"]:
			var bandr := String(rec.band)
			fish_by_band[rec.type + "/" + bandr] = int(fish_by_band.get(rec.type + "/" + bandr, 0)) + 1
			if bandr != "shallows" and bandr != "cold":
				fish_wrong += 1
	check(fish_by_band.get("tropical_fish/shallows", 0) > 20 and fish_by_band.get("catfish/shallows", 0) > 5 and fish_by_band.get("barracuda/cold", 0) > 20,
			"a full city seeds all three fish in their bands %s" % str(fish_by_band))
	check(fish_wrong == 0, "no predator fish outside The Shallows and The Cold")
	var interior_fish := 0
	for rec in World.enemy_records:
		if rec.type in ["tropical_fish", "catfish", "barracuda"] and World.has_back_wall_cell(World.cell_at(rec.pos)):
			interior_fish += 1
	check(interior_fish > 100, "...including flooded interiors (%d indoors)" % interior_fish)
	print("== T1 district fauna on dry floors + surface dwellers (2026-09-06)")
	var dry_fauna: Dictionary = (Data.enemy_seeding.district_fauna as Dictionary).get("dry", {})
	var uniques := 0
	var misplaced := 0
	var seen_districts := {}
	for rec in World.enemy_records:
		var e: Dictionary = Data.enemies.get(rec.type, {})
		if not e.get("grid_fauna", false) or String(e.get("stage", "")) != "t1" or String(e.district) == "open_water":
			continue
		uniques += 1
		var tw := CityGen.tower_at(World.towers, World.cell_at(rec.pos))
		if tw.is_empty() or not (dry_fauna.get(String(tw.district), []) as Array).has(rec.type) or String(rec.band) != "dry":
			misplaced += 1
		else:
			seen_districts[String(tw.district)] = true
	check(uniques > 150 and misplaced == 0 and seen_districts.size() == 6,
			"dry floors carry their district's own creatures: %d seeded, %d misplaced, %d districts" % [uniques, misplaced, seen_districts.size()])
	var surf := {}
	for rec in World.enemy_records:
		if rec.type in ["drain_eel", "water_strider", "minnow_school", "mudskipper"]:
			surf[rec.type] = int(surf.get(rec.type, 0)) + 1
			if absi(World.cell_at(rec.pos).y - World.waterline_row) > 8:
				misplaced += 1
	check(surf.size() == 4 and misplaced == 0, "the four open-water T1 dwellers live at the waterline %s" % str(surf))
	print("== T2 district fauna in flooded Shallows floors + open-water hunters (2026-09-06)")
	var sh_fauna: Dictionary = (Data.enemy_seeding.district_fauna as Dictionary).get("shallows", {})
	var sh_uniques := 0
	var sh_bad := 0
	var sh_districts := {}
	var ow := {}
	for rec in World.enemy_records:
		var e: Dictionary = Data.enemies.get(rec.type, {})
		if not e.get("grid_fauna", false) or String(e.get("stage", "")) != "t2":
			continue
		if String(e.district) == "open_water":
			ow[rec.type] = int(ow.get(rec.type, 0)) + 1
			if String(rec.band) != "shallows" or World.has_back_wall_cell(World.cell_at(rec.pos)):
				sh_bad += 1
			continue
		sh_uniques += 1
		var tw := CityGen.tower_at(World.towers, World.cell_at(rec.pos))
		if tw.is_empty() or not (sh_fauna.get(String(tw.district), []) as Array).has(rec.type) or String(rec.band) != "shallows":
			sh_bad += 1
		else:
			sh_districts[String(tw.district)] = true
	check(sh_uniques > 60 and sh_districts.size() == 6, "flooded Shallows floors carry their district's own T2 creatures: %d seeded, %d districts" % [sh_uniques, sh_districts.size()])
	check(ow.size() == 4 and sh_bad == 0, "the four T2 open-water hunters swim the Shallows between towers %s (%d misplaced)" % [str(ow), sh_bad])
	print("== T0 rooftops: night spawns (2026-09-06)")
	var roof_cell := World.cell_at(player.global_position)
	var spawn_t: Dictionary = World.towers[0]
	for t in World.towers:
		if roof_cell.x >= int(t.x0) and roof_cell.x <= int(t.x1):
			spawn_t = t
	check(World.band_at(Vector2i(roof_cell.x, int(spawn_t.top) + 5)) == "dry", "just under the crown it is The Dry again")
	check(Data.enemy_stats("prowler", "roof").speed > Data.enemy_stats("walker", "dry").speed, "the Prowler has roof stats and outruns a walker")
	check(Data.enemy_stats("walker", "roof").hp == Data.enemy_stats("walker", "dry").hp, "a type without a roof row uses its Dry stats")
	check(Data.enemies.prowler.get("pounds", true) == false, "the Prowler never pounds player blocks (a house holds)")
	World.time_of_day = 0.0 # midnight
	World._was_night = true
	World._tick_roof_night(0.0)
	var roofers := 0
	var wrong := 0
	var here := World.district_at_x(roof_cell.x)
	var allowed: Array = (Data.enemy_seeding.roof_night_types_by_district as Dictionary).get(here, [])
	check(here != "" and allowed.size() == 4, "the spawn roof is %s: four creatures of its own %s" % [here, str(allowed)])
	for rec in World.enemy_records:
		if rec.get("roof", false):
			roofers += 1
			var c := World.cell_at(rec.pos)
			if not allowed.has(rec.type) or not rec.get("night", false) or World.band_at(c) != "roof" or World.is_solid_cell(c) \
					or absf(rec.pos.x - player.global_position.x) > 60.0 * Constants.BLOCK_SIZE:
				wrong += 1
	check(roofers == int(Data.enemy_seeding.roof_night_max) and wrong == 0, "midnight on an open roof: %d of the district's creatures on roof tops in the ring, all night records (%d wrong)" % [roofers, wrong])
	World._tick_roof_night(0.0)
	var again := 0
	for rec in World.enemy_records:
		if rec.get("roof", false):
			again += 1
	check(again == roofers, "the roof cap holds while they live")
	World.time_of_day = 0.5 # noon
	World._tick_night(0.1)
	var left := 0
	for rec in World.enemy_records:
		if rec.get("roof", false):
			left += 1
	check(left == 0 and not World.is_night(), "dawn clears the roofs")
	World._was_night = false
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
	var f2 := (World.waterline_row + Constants.STAGE_FLOOR_DEPTH_SHALLOWS - int(probe_t.top)) / fh2
	var sr2 := CityGen.floor_standing_row(probe_t, f2)
	var straddle := Vector2i(int(probe_t.x0) + 14, sr2)
	check(World.floor_band_at(straddle) == "shallows" and World.band_at(straddle) == "cold",
			"a floor straddling the Shallows/Cold line: floor band shallows, cell band cold (gates stay per cell)")
	print("== stage gaps in the live world (2026-09-06)")
	var g0: Vector2i = CityGen.stage_gaps()[0]
	check(World.band_at(Vector2i(10, g0.x)) == "shallows" and World.band_at(Vector2i(10, g0.y - 1)) == "shallows"
			and World.band_at(Vector2i(10, g0.y)) == "cold", "the gap belongs to the shallower band; The Cold starts right under it")
	World.time_of_day = 0.5
	var gap_in_tower := Vector2i(int(probe_t.x0) + 20, g0.x + 3)
	check(World.has_back_wall_cell(gap_in_tower) and World.visibility_at(gap_in_tower, Vector2.ZERO) >= float(LightMap.MAX_LIGHT),
			"a gap cell inside a tower keeps its back wall yet is revealed like an exterior")
	var plug := Vector2i(int(probe_t.x0) - 3, g0.x + 5) # the inter-tower gap west of tower 0 (or the margin)
	check(World.grid.structure_at(plug) == WorldGrid.M.GARBAGE and World.is_solid_cell(plug), "the plug is solid garbage")
	check(World.damage_block(plug, 100.0, 1) == "broken" and not World.has_block_cell(plug), "a plain hammer digs through a garbage cell")
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
