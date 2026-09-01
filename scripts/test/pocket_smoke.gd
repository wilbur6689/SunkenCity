extends Node
## Headless gate test for interior pockets (user request 2026-09-01):
## apartment doorways on wing back walls that lead to a room of their own,
## carved in the VOID annex east of the city on the doorway's own rows.
## Covers generation (shell, spacing, links, determinism), travel both ways
## through the linked doorways, open/closed/deadbolted states, flooding of
## drowned pockets, the map anchor, VOID sight, and the save fields.
## Run: godot --path . --headless res://scenes/test/pocket_smoke.tscn

const B := Constants.BLOCK_SIZE

var city: Node2D
var player: Player
var failures: PackedStringArray = []
var checks := 0

func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok:   " if cond else "  FAIL: ") + msg)
	if not cond:
		failures.append(msg)

func ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func until(pred: Callable, n: int) -> bool:
	for i in n:
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()

## Teleport the player's feet onto standing row `row` at column `cx`.
func place(cx: int, row: int) -> void:
	player.velocity = Vector2.ZERO
	player.global_position = Vector2((cx + 0.5) * B, (row + 1) * B - Player.FEET_Y)
	World.refresh_objects_around(player.global_position)
	await ticks(3)

func portal_objects(r: Dictionary) -> Dictionary: # cell -> gen object entry
	var out := {}
	for o in r.objects:
		if o.has("link"):
			out[o.cell] = o
	return out

func _ready() -> void:
	print("== A. generation (800-wide slice)")
	var r := CityGen.generate(101, 800)
	var r2 := CityGen.generate(101, 800)
	var g: WorldGrid = r.grid
	var annex_x0: int = 800 + CityGen.ANNEX_GAP
	check(int(r.city_w) == 800, "result carries the city width")
	check(g.bounds.size.x == annex_x0 + CityGen.ANNEX_W, "grid widened by the gap + VOID annex (%d cols)" % g.bounds.size.x)
	check(r.pockets.size() >= 15, "slice carved %d pockets" % r.pockets.size())
	check(str(r.pockets) == str(r2.pockets) and g.content_hash() == r2.grid.content_hash(), "pockets are seed-deterministic (CT-21)")
	check(g.structure_at(Vector2i(annex_x0, 5)) == WorldGrid.M.VOID and g.structure_at(Vector2i(annex_x0 + 100, 380)) == WorldGrid.M.VOID,
		"annex is VOID top to bottom outside the pockets")
	check(g.structure_at(Vector2i(800 + 10, 200)) == WorldGrid.M.AIR, "the gap east of the city stays open air")
	var portals := portal_objects(r)
	var shell_ok := true
	var link_ok := true
	var rows_ok := true
	var overlap_ok := true
	var exit_clear_ok := true
	var locked := 0
	var opened := 0
	var flooded := 0
	var rects: Array = []
	for p in r.pockets:
		var rect: Rect2i = p.rect
		var sr: int = rect.end.y - 1
		if rect.position.x < annex_x0 or rect.end.x > g.bounds.end.x:
			shell_ok = false
		if sr != int(p.exit.y) or rect.size.y != CityGen.FLOOR_H - 1:
			rows_ok = false # a pocket sits on exactly its doorway's floor rows
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if g.back_at(Vector2i(x, y)) == WorldGrid.M.AIR:
					shell_ok = false # interiors are back-walled (fog of war applies)
		for y in range(rect.position.y, rect.end.y):
			if g.structure_at(Vector2i(rect.position.x - 1, y)) != WorldGrid.M.STONE \
					or g.structure_at(Vector2i(rect.end.x, y)) != WorldGrid.M.STONE:
				shell_ok = false
		for x in range(rect.position.x - 1, rect.end.x + 1):
			if g.structure_at(Vector2i(x, rect.position.y - 1)) != WorldGrid.M.METAL \
					or g.structure_at(Vector2i(x, rect.end.y)) != WorldGrid.M.METAL:
				shell_ok = false
		if g.structure_at(Vector2i(rect.position.x - 2, sr)) != WorldGrid.M.VOID:
			shell_ok = false # spacer: blackness right behind the west wall
		if rect.position.x - 1 - annex_x0 < CityGen.POCKET_VIEW_MARGIN 				or g.bounds.end.x - (rect.end.x + 1) < CityGen.POCKET_VIEW_MARGIN:
			shell_ok = false # a screen's worth of VOID before the gap / the grid edge
		if g.structure_at(Vector2i(rect.position.x, sr)) != WorldGrid.M.AIR:
			shell_ok = false # the return doorway's column is clear to stand in
		var ex: Dictionary = portals.get(p.exit, {})
		var en: Dictionary = portals.get(p.entry, {})
		if ex.is_empty() or en.is_empty() or ex.link != p.entry or en.link != p.exit \
				or en.id != "room_door" or not (ex.id in ["room_door", "room_door_locked", "room_door_metal"]) \
				or bool(ex.open) != bool(en.open) or int(p.exit.x) >= 800 or p.entry != Vector2i(rect.position.x, sr):
			link_ok = false
		# Door material follows the GL-09 ladder: wood through The Shallows,
		# chained metal below; locked doors are never found open.
		var deep: bool = sr - CityGen.WATERLINE > Constants.BAND_SHALLOWS_DEPTH
		if deep != (ex.get("id", "") == "room_door_metal"):
			link_ok = false
		if ex.get("id", "") != "room_door":
			locked += 1
			if bool(ex.get("open", false)):
				link_ok = false
		if bool(ex.get("open", false)):
			opened += 1
		if bool(p.flooded):
			flooded += 1
		for dy in 3: # the city-side doorway hangs on a back wall in clear air
			var c: Vector2i = p.exit - Vector2i(0, dy)
			if g.structure_at(c) != WorldGrid.M.AIR or g.back_at(c) == WorldGrid.M.AIR:
				exit_clear_ok = false
		for other: Rect2i in rects:
			# Interiors never overlap; same-lane neighbours keep walls + a VOID
			# spacer between them (stacked pockets share slabs, like real floors).
			if other.intersects(rect):
				overlap_ok = false
			elif other.position.y == rect.position.y:
				var gap: int = maxi(other.position.x - rect.end.x, rect.position.x - other.end.x)
				if gap < 2 + CityGen.POCKET_SPACER:
					overlap_ok = false
		rects.append(rect)
	check(shell_ok, "every pocket: stone walls, metal slabs, back walls, VOID spacer, clear doorway column")
	# Density (user request: 30% of floors, at most one doorway per floor).
	var total_floors := 0
	for tower in r.tower_list:
		total_floors += int(tower.floors)
	var density := float(r.pockets.size()) / total_floors
	check(density > 0.18 and density < 0.38, "%.0f%% of floors carry a doorway (target ~30%%)" % (density * 100.0))
	check(rows_ok, "every pocket sits on its doorway's floor rows (depth/band preserved)")
	check(link_ok, "doorway twins link both ways, share their open state, exits stay in the city")
	check(exit_clear_ok, "city-side doorways hang on back walls in clear air")
	check(overlap_ok, "pocket interiors never overlap; lane neighbours keep their VOID spacer")
	check(locked > 0 and opened > 0 and locked + opened < r.pockets.size(),
		"a mix of states: %d locked (deadbolt/chain), %d standing open, %d closed" % [locked, opened, r.pockets.size() - locked - opened])
	var submerged := 0
	var dry_submerged := 0
	for p in r.pockets:
		if int(p.exit.y) > CityGen.WATERLINE:
			submerged += 1
			if not bool(p.flooded):
				dry_submerged += 1
	var dry_f := float(dry_submerged) / maxf(submerged, 1.0)
	check(flooded > 0 and dry_f > 0.25 and dry_f < 0.55, "%.0f%% of submerged pockets kept their air (target 40%%)" % (dry_f * 100.0))
	var dry_above := true
	for p in r.pockets:
		if int(p.exit.y) <= CityGen.WATERLINE and bool(p.flooded):
			dry_above = false
	check(dry_above, "pockets above the waterline are never flooded")
	var no_item := Data.item("room_door").is_empty() and Data.item("room_door_locked").is_empty() \
			and Data.item("room_door_metal").is_empty()
	check(no_item and Data.objects.room_door.get("fixed", false), "doorways are fixed infrastructure with no item form")
	check(not Constants.STRUCTURE_TIER.has(WorldGrid.M.VOID), "VOID is unbreakable (no demolition tier)")

	print("== B. the full city")
	SaveGame.pending_character = "__pocket_smoke__"
	city = load("res://scenes/city/city.tscn").instantiate()
	add_child(city)
	player = city.get_node("Player")
	player.set_multiplayer_authority(2)
	await get_tree().physics_frame
	check(World.city_bounds.size.x == CityGen.WORLD_W and World.grid.bounds.size.x > CityGen.WORLD_W, "World knows the city proper vs the wider grid")
	check(World.pockets.size() == city.gen.pockets.size() and World.pockets.size() > 50, "World registered %d pockets" % World.pockets.size())
	check(not World.in_annex(World.cell_at(player.global_position)), "spawn is in the city")
	# Enemies never seed inside the annex; wave/scatter spawns stay west of it.
	var annex_enemies := 0
	for rec in World.enemy_records:
		if World.in_annex(World.cell_at(rec.pos)):
			annex_enemies += 1
	check(annex_enemies == 0, "no enemies seeded in the annex")
	check(await until(func(): return player.state == Player.State.GROUNDED, 120), "player lands")

	print("== C. through an open/closed doorway and back")
	var gen_pockets: Array = city.gen.pockets
	var plain: Dictionary = {}
	var deadbolt: Dictionary = {}
	var wet: Dictionary = {}
	for p in gen_pockets:
		var rec := World.object_record_at(p.exit)
		if rec.is_empty():
			continue
		if rec.id == "room_door" and not rec.open and plain.is_empty() and not bool(p.flooded):
			plain = p
		elif rec.id == "room_door_locked" and deadbolt.is_empty():
			deadbolt = p
		if bool(p.flooded) and wet.is_empty():
			wet = p
	check(not plain.is_empty() and not wet.is_empty(), "found a closed dry pocket and a drowned one to test")
	print("  (seed %d: dry pocket exit %s -> entry %s; drowned pocket entry %s)" % [city.seed_value, plain.exit, plain.entry, wet.entry])
	var exit_cell: Vector2i = plain.exit
	await place(exit_cell.x, exit_cell.y)
	var door := World.object_at(exit_cell)
	check(door != null and door.def.kind == "portal" and not door.open, "closed apartment door instantiated at the doorway")
	check(not World.is_solid_cell(exit_cell), "the doorway never blocks the corridor")
	var msg := door.interact(player)
	check(door.open and msg.contains("open"), "first click opens it ('%s')" % msg)
	var before := player.global_position
	msg = door.interact(player)
	await ticks(2)
	var cell := World.cell_at(player.global_position)
	check(World.in_annex(cell) and World.pocket_at(cell) == World.pockets[gen_pockets.find(plain)], "second click steps into the pocket ('%s')" % msg)
	check(cell.x == int(plain.entry.x), "arrived standing at the return doorway")
	check(World.map_cell_for(player.global_position) == exit_cell, "map anchor inside a pocket is the doorway it was entered through")
	check(await until(func(): return player.state == Player.State.GROUNDED, 60), "lands on the pocket floor")
	var rect: Rect2i = plain.rect
	var clear := true
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if World.is_water_cell(Vector2i(x, y)):
				clear = false
	check(clear, "a sealed pocket is dry")
	check(World.visibility_at(Vector2i(rect.position.x - 2, rect.end.y - 1), player.global_position) == 0.0, "the VOID beyond the wall is pitch black")
	check(World.visibility_at(Vector2i(rect.position.x + 2, rect.end.y - 1), player.global_position) > 0.0, "the room itself is in sight")
	var furniture := 0
	for c in World.object_cells:
		if rect.has_point(c) and World.object_cells[c].def.kind != "portal":
			furniture += 1
	check(furniture > 0, "the pocket is furnished (%d object cells)" % furniture)
	var back := World.object_at(plain.entry)
	check(back != null and back.def.kind == "portal" and back.open, "the return doorway stands open (you came through it)")
	msg = back.interact(player)
	await ticks(2)
	cell = World.cell_at(player.global_position)
	check(not World.in_annex(cell) and cell.x == exit_cell.x and absi(cell.y - exit_cell.y) <= 1, "back in the corridor where you started ('%s')" % msg)
	check(player.global_position.distance_to(before) < 2.0 * B, "returned to the same spot")
	# The city-side record banked the open state (windowed objects re-read it).
	check(World.object_record_at(exit_cell).open, "record keeps the door open")

	print("== D. locked doors: deadbolted wood, chained metal")
	player.inventory.slots.fill(null)
	player.selected_slot = 0
	player.bare_hands = false
	if deadbolt.is_empty():
		# Wood doors only reach through The Shallows, so a given seed may
		# hold no deadbolted one; the metal path below still proves the lock.
		print("  (this seed rolled no deadbolted wood door - skipping the pry-bar leg)")
		player.inventory.slots[0] = {"id": "pry_bar", "count": 1}
		player.inventory.changed.emit()
	else:
		await place(deadbolt.exit.x, deadbolt.exit.y)
		var locked_door := World.object_at(deadbolt.exit)
		msg = locked_door.interact(player)
		check(locked_door != null and not locked_door.open and msg.begins_with("Locked"), "bare hands: '%s'" % msg)
		player.inventory.slots[0] = {"id": "pry_bar", "count": 1}
		player.inventory.changed.emit()
		msg = locked_door.interact(player)
		check(locked_door.open and locked_door.unlocked, "a pry bar forces it ('%s')" % msg)
		locked_door.interact(player)
		await ticks(2)
		check(World.in_annex(World.cell_at(player.global_position)), "and it leads into its pocket")
	var chained: Dictionary = {}
	for p in gen_pockets:
		if World.object_record_at(p.exit).get("id", "") == "room_door_metal":
			chained = p
			break
	check(not chained.is_empty(), "a chained metal door exists below the Shallows")
	await place(chained.exit.x, chained.exit.y)
	var metal_door := World.object_at(chained.exit)
	msg = metal_door.interact(player) # still holding only the pry bar (tier 1)
	check(not metal_door.open and msg.contains("bolt cutters"), "a pry bar is not enough: '%s'" % msg)
	player.inventory.slots[0] = {"id": "bolt_cutters", "count": 1}
	player.inventory.changed.emit()
	msg = metal_door.interact(player)
	check(metal_door.open and metal_door.unlocked, "bolt cutters cut the chain ('%s')" % msg)

	print("== E. a drowned pocket")
	var wrect: Rect2i = wet.rect
	var wet_cells := 0
	for y in range(wrect.position.y, wrect.end.y):
		for x in range(wrect.position.x, wrect.end.x):
			if World.is_water_cell(Vector2i(x, y)):
				wet_cells += 1
	check(wet_cells >= wrect.size.x * wrect.size.y / 2, "a drowned pocket holds water (%d cells)" % wet_cells)

	print("== F. save fields")
	SaveGame.save_world("__pocket_smoke", city.seed_value)
	var data := SaveGame.read_world("__pocket_smoke")
	var linked := 0
	for st in data.objects:
		if st.has("link"):
			linked += 1
	check(int(data.city_w) == CityGen.WORLD_W and data.pockets.size() == World.pockets.size(), "world save carries city width + pockets")
	check(linked == World.pockets.size() * 2, "every doorway saves its link (%d)" % linked)
	SaveGame.delete_world("__pocket_smoke")

	print("\nPocket smoke: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
