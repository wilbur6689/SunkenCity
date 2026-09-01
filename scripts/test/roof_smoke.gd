extends Node
## Headless gate for the roof zone (user request 2026-09-01): rooftop gear
## stamped on every tower's top slab, trees only on dry roofs, the roof
## drop-off spawn, interior details (decals/vents/pipes/statues), midnight
## tree growth (record swap), and the harvest data.
## Run: godot --path . --headless res://scenes/test/roof_smoke.tscn

const B := Constants.BLOCK_SIZE

var failures: PackedStringArray = []
var checks := 0

func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok:   " if cond else "  FAIL: ") + msg)
	if not cond:
		failures.append(msg)

func _ready() -> void:
	print("== A. data")
	for id: String in ["tree_sapling", "tree_young", "tree_mature", "roof_hvac", "roof_crane",
			"roof_comm_mast", "decal_broken_wall_a", "int_wall_vent", "int_wall_pipes", "statue_stone"]:
		check(Data.objects.has(id), id + " is defined")
	check(Data.objects.tree_sapling.get("grows_into", "") == "tree_young" \
			and Data.objects.tree_young.get("grows_into", "") == "tree_mature" \
			and not Data.objects.tree_mature.has("grows_into"), "growth chain: sapling -> young -> mature")
	check(not Data.item("tree_sapling").is_empty(), "saplings have an item form (replantable)")
	check(Data.item("tree_young").is_empty() and Data.item("tree_mature").is_empty(),
			"grown trees have no item form (harvest, not haul)")
	var wood_ok := true
	for id: String in ["tree_sapling", "tree_young", "tree_mature"]:
		var got := false
		for y in Data.objects[id].yields:
			if y.item == "wood":
				got = true
		wood_ok = wood_ok and got
	check(wood_ok, "every tree stage yields wood")
	check(int(Data.objects.tree_mature.size[1]) >= 12, "a mature tree stands 2x-3x a room tall (%d blocks)" % int(Data.objects.tree_mature.size[1]))
	check(Data.objects.decal_broken_wall_a.get("kind", "") == "decal" \
			and Data.objects.decal_broken_wall_a.get("no_item", false) \
			and (Data.objects.decal_broken_wall_a.get("yields", []) as Array).is_empty(),
			"broken-wall decals are non-harvest dressing")
	var stone_ok := true
	for id: String in ["statue_bust", "statue_stone", "res_tall_plant", "res_potted_plant"]:
		var got := false
		for y in Data.objects[id].get("yields", []):
			if y.item == "stone":
				got = true
		stone_ok = stone_ok and got
	check(stone_ok, "statues and plants pay out stone")

	# Early-game economy (user request): hand crafting is wood-tier only -
	# scrap tools live behind the workbench, and the workbench is a project.
	for rid: String in ["pry_bar", "scrap_knife", "hammer"]:
		check(Data.recipes[rid].station == "workbench", rid + " is workbench-gated")
	for rid: String in ["wood_axe", "chest", "rope", "ladder", "wood_block", "wood_wall", "workbench"]:
		check(Data.recipes[rid].station == "hand", rid + " is hand-craftable (wood tier)")
	var wb_wood := 0
	for inp in Data.recipes.workbench.inputs:
		if inp.item == "wood":
			wb_wood = int(inp.count)
	check(wb_wood >= 25, "the workbench takes multiple resource runs (%d wood)" % wb_wood)
	check(int(Data.recipes.pry_bar.inputs[0].count) >= 20, "tool costs run 5x (pry bar: %d scrap)" % int(Data.recipes.pry_bar.inputs[0].count))
	check(Data.tool_of("wood_axe").get("type", "") == "axe", "the wooden axe is an axe-type tool")
	check(Data.objects.tree_young.get("requires_tool", "") == "axe" 			and Data.objects.tree_mature.get("requires_tool", "") == "axe" 			and not Data.objects.tree_sapling.has("requires_tool"),
			"grown trees need the axe; saplings hand-pluck (no wood deadlock)")
	check(float(Data.objects.tree_mature.scrap_time) > float(Data.objects.tree_young.scrap_time) 			and float(Data.objects.tree_young.scrap_time) > float(Data.objects.tree_sapling.scrap_time),
			"bigger trees take longer to fell")
	check(Data.blocks.wood_wall.atlas_row == 8, "the wood wall has its own dark plank tile row")
	print("== B. generation")
	var r := CityGen.generate(101, 800)
	var r2 := CityGen.generate(101, 800)
	check(r.grid.content_hash() == r2.grid.content_hash() and hash(str(r.objects)) == hash(str(r2.objects)),
			"roofed city stays seed-deterministic (CT-21)")
	var roof_rows := {} # roof standing row -> [[x0, x1], ...] (equal-height towers share it)
	for t in r.tower_list:
		var row: int = int(t.top) - 1
		if not roof_rows.has(row):
			roof_rows[row] = []
		roof_rows[row].append([int(t.x0), int(t.x1)])
	var roofed := {}
	var stray := 0
	var trees := 0
	var wet_trees := 0
	var details := 0
	var statues := 0
	for o in r.objects:
		var id: String = o.id
		var cell: Vector2i = o.cell
		if id == "roof_hatch":
			continue # sits one row up on the slab; the hatch checks below cover it
		if id.begins_with("roof_") or id.begins_with("tree_"):
			var on_roof := false
			for span: Array in roof_rows.get(cell.y, []):
				if cell.x >= int(span[0]) and cell.x <= int(span[1]):
					on_roof = true
					roofed[cell.y * 100000 + int(span[0])] = true
			if not on_roof:
				stray += 1
		if id.begins_with("tree_"):
			trees += 1
			if cell.y >= CityGen.WATERLINE:
				wet_trees += 1
		if id.begins_with("decal_") or id.begins_with("int_"):
			details += 1
		if id.begins_with("statue_"):
			statues += 1
	check(stray == 0, "roof gear and trees appear only on tower roofs (%d strays)" % stray)
	check(roofed.size() >= r.tower_list.size() * 8 / 10,
			"most towers carry roof gear (%d of %d)" % [roofed.size(), r.tower_list.size()])
	check(trees >= 3, "%d trees rooted across the skyline" % trees)
	check(wet_trees == 0, "trees only on dry roofs above the waterline")
	check(details >= 20, "%d interior wall details (decals/vents/pipes) stamped" % details)
	check(statues >= 1, "%d statues placed" % statues)
	# Abandonment pass: vined twins share the base item's harvest data; junk
	# is pure dressing (kind decal, no yields, no item form).
	check(Data.objects.has("roof_hvac_vined") 			and str(Data.objects.roof_hvac_vined.yields) == str(Data.objects.roof_hvac.yields),
			"vined gear twins exist and keep the base yields")
	for jid: String in ["roof_junk_pile", "roof_fallen_mast", "roof_tarp_crates"]:
		var jd: Dictionary = Data.objects.get(jid, {})
		check(jd.get("kind", "") == "decal" and jd.get("no_item", false) 				and (jd.get("yields", []) as Array).is_empty(), jid + " is non-harvest dressing")
	var vined_placed := 0
	var junk_placed := 0
	var per_tower := {}
	for o in r.objects:
		var oid2: String = o.id
		if oid2.ends_with("_vined"):
			vined_placed += 1
		if oid2.begins_with("roof_junk") or oid2 == "roof_fallen_mast" or oid2 == "roof_tarp_crates":
			junk_placed += 1
		if oid2.begins_with("roof_") or oid2.begins_with("tree_"):
			for span2: Array in roof_rows.get(o.cell.y, []):
				if o.cell.x >= int(span2[0]) and o.cell.x <= int(span2[1]):
					var tk2: int = o.cell.y * 100000 + int(span2[0])
					per_tower[tk2] = int(per_tower.get(tk2, 0)) + 1
	check(vined_placed >= 2, "%d overgrown (vined) pieces rolled (~30%%)" % vined_placed)
	check(junk_placed >= 4, "%d junk dressing pieces scattered" % junk_placed)
	var crowded := 0
	for k in per_tower:
		if int(per_tower[k]) > 20:
			crowded += 1
	check(crowded == 0, "no roof is crowded (max ~2-3 gear + trees + junk per wing)")
	var dry_wings_with_trees := 0
	var dry_towers := 0
	for t2 in r.tower_list:
		if int(t2.top) - 1 < CityGen.WATERLINE:
			dry_towers += 1
	check(dry_towers == 0 or trees >= dry_towers, "trees on every dry roof on average (%d trees, %d dry towers)" % [trees, dry_towers])
	# Side-breach vents (user request): every wear breach carries a grate.
	var vent_def: Dictionary = Data.objects.side_vent
	check(vent_def.kind == "door" and vent_def.get("fixed", false) and int(vent_def.get("lock_tier", 0)) == 1,
			"the wall vent grate is a fixed, padlocked door (pry tier 1)")
	var vents := 0
	var vent_sealed := true
	for o in r.objects:
		if o.id == "side_vent":
			vents += 1
			for dy in 2: # the grate exactly fills its 2x2 breach
				for dx in 2:
					if r.grid.structure_at(Vector2i(o.cell.x + dx, o.cell.y - dy)) != WorldGrid.M.AIR:
						vent_sealed = false
	check(vents >= 20, "%d side breaches wear vent grates" % vents)
	check(vent_sealed, "every grate sits in a fully carved 2x2 breach")
	# Central 20%: towers crowd to <= 5 blocks apart (user request).
	var tight_pairs := 0
	var tight_ok := true
	for i in range(r.tower_list.size() - 1):
		var a: Dictionary = r.tower_list[i]
		var cfa := 1.0 - absf((float(a.x0 + a.x1) * 0.5) - 400.0) / 400.0
		if cfa > 0.8:
			var gap: int = int(r.tower_list[i + 1].x0) - int(a.x1) - 1
			tight_pairs += 1
			if gap > 5:
				tight_ok = false
	check(tight_pairs >= 1 and tight_ok, "central towers sit <= 5 blocks apart (%d tight gaps)" % tight_pairs)
	var hatch_def: Dictionary = Data.objects.roof_hatch
	check(hatch_def.kind == "door" and hatch_def.get("fixed", false) and hatch_def.get("no_item", false) 			and int(hatch_def.get("lock_tier", 0)) == 1, "the roof hatch is a fixed, padlocked door (pry tier 1)")
	var hatch_cells := {}
	for o in r.objects:
		if o.id == "roof_hatch":
			hatch_cells[o.cell] = true
	var dry_missing := 0
	var wet_hatched := 0
	for t in r.tower_list:
		var has := hatch_cells.has(Vector2i(int(t.mid) - 1, int(t.top)))
		if int(t.top) - 1 < CityGen.WATERLINE:
			if not has:
				dry_missing += 1
		elif has:
			wet_hatched += 1
	check(dry_missing == 0 and hatch_cells.size() > 0,
			"every dry crown seals its shaft mouth with a vent hatch (%d hatches)" % hatch_cells.size())
	check(wet_hatched == 0, "submerged towers stay open (no hatch)")
	var hosp: Dictionary = r.hospital
	check(r.spawn_feet.y == float(hosp.top) * B, "spawn is on the very top of the hospital roof")
	check(r.spawn_feet.y / B - 1 < CityGen.WATERLINE, "the drop-off roof is above the waterline")

	print("== C. growth")
	var g := WorldGrid.new(Rect2i(0, 0, 60, 40))
	for x in 60:
		g.set_structure(Vector2i(x, 30), WorldGrid.M.METAL)
	var items_root := Node2D.new()
	var objects_root := Node2D.new()
	add_child(items_root)
	add_child(objects_root)
	World.register(g, Vector2(30 * B, 30 * B), items_root, objects_root, null, 35)
	World.add_object_record("tree_sapling", Vector2i(20, 29), false)
	for i in 60:
		World._grow_trees()
	check(World.object_record_at(Vector2i(20, 29)).get("id", "") == "tree_mature",
			"a sapling grows to maturity over enough midnights")
	check(World.object_record_at(Vector2i(20, 29)) == World.object_record_at(Vector2i(20, 17)),
			"the grown canopy registers its cells")
	World.add_object_record("tree_sapling", Vector2i(40, 29), false)
	g.set_structure(Vector2i(39, 25), WorldGrid.M.STONE) # hem the young stage in
	for i in 60:
		World._grow_trees()
	check(World.object_record_at(Vector2i(40, 29)).get("id", "") == "tree_sapling", "a hemmed-in tree waits")
	World.add_object_record("tree_sapling", Vector2i(10, 29), false)
	World.water_sim.seed_cell(Vector2i(10, 29), WaterSim.MAX_LEVEL)
	for i in 60:
		World._grow_trees()
	check(World.object_record_at(Vector2i(10, 29)).get("id", "") == "tree_sapling", "a drowned tree never grows")
	# Room draw planes (user request 2026-09-01): decals under wall pieces
	# under furniture (the player wins by tree order).
	for y2 in range(24, 30):
		g.set_back(Vector2i(30, y2), WorldGrid.M.STONE)
		g.set_back(Vector2i(31, y2), WorldGrid.M.STONE)
	var deco := World.place_object("decal_broken_wall_a", Vector2i(30, 29), false)
	var vent2 := World.place_object("int_wall_vent", Vector2i(30, 27), false)
	var desk2 := World.place_object("roof_comm_cabinet", Vector2i(33, 29), false)
	check(deco.z_index == -2 and vent2.z_index == -1 and desk2.z_index == 0,
			"draw planes: decal (-2) < wall piece (-1) < furniture (0)")
	check(Data.enemies.walker.get("frames", 0) == 8 and Data.enemies.walker.get("sprite_variants", 0) == 7,
			"walkers carry the 8-frame walk strips (7 variants incl. 2 fat)")
	# A streamed-in tree swaps its node on growth.
	World.refresh_objects_around(Vector2(30 * B, 29 * B))
	var mature_node := World.object_at(Vector2i(20, 29))
	check(mature_node != null and mature_node.id == "tree_mature", "the grown tree streams in as its new stage")

	print("\nRoof smoke: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
