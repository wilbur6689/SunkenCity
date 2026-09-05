class_name CityGen
extends RefCounted
## Deterministic city generator (M3, CT-01..21): seed -> a full drowned city.
## Pure with respect to the World autoload: builds a WorldGrid plus object/
## door placement lists, so determinism is testable (same seed = same hashes,
## CT-21). Flooding is applied separately once doors exist, because sealing
## is decided by solidity (WS-20).
##
## DISTRICTS (docs/DistrictsOverhaul.md, 2026-09-04): the city is a flat
## slab of TOWER_COUNT double-wide towers at jumpable gaps (CLUSTER_GAP_MIN..
## MAX everywhere - the old spawn-cluster rule became the city's), divided
## HORIZONTALLY into districts: clusters of 5-6 towers sharing one building
## type (business / commercial / civil / industrial / construction), placed
## anywhere outside the reserved 6-tower residential centre with a 1-tower
## residential buffer between any two, and residential filling whatever is
## left (about half the city). A tower's district sets its room pool for
## EVERY floor (mixed-use per floor is gone), its floor height
## (DISTRICT_FLOOR_H: 12 / 14 / 20 cells), its room-width filter
## (DISTRICT_ROOM_W), and whether it may roll a rare triple-wide footprint
## (industrial / commercial only). Every crown sits within SKYLINE_BAND (10)
## cells of CROWN_ROW - neighbouring roofs still step by LIFT_STEP_MIN..MAX -
## and every tower reaches the ground: floors = crown-to-ground / floor
## height, the remainder a solid plinth (crown lift). Nothing is authored at
## the start any more (no medical room, no supply crate): spawn is the roof
## of the centre-most centre tower and the roof-locked opening lives off
## trees and roof gear. Construction towers are an unfinished metal frame
## with wood flooring and partitions, back walls only below the waterline,
## near-certain breaches below it and no sealed rooms.
##
## Every tower is a twin-wing block (three wings when triple-wide): ladder
## stairwells on BOTH sides, an elevator shaft between each pair of wings
## (CT-06), and submerged ladder runs broken into scrappable gaps (craft
## ladders to climb back up); floors fill with room templates from
## data/rooms.json filtered by zone, depth range and district width; a wear
## pass adds breaches scaling with depth (CT-11); each tower keeps a
## randomized 4-8 dry floors' worth of rows at the top (a watertight wood
## barrier seals a sub-waterline air pocket) with the flood below.
##
## Interior pockets (user request 2026-09-01): ~50% of a tower's floors get
## an apartment doorway on the back wall beside the stairwell (random wing). Each leads to a
## room of its own — carved in a VOID annex east of the city (ANNEX_GAP of
## open air keeps it off-screen, then ANNEX_W columns of solid blackness),
## on the SAME rows as its doorway so depth bands, loot tables and pressure
## stay honest. The pocket holds one zone template behind a stone shell,
## with the matching doorway inside; both doorways link by cell. Flooding
## is decided here (`flooded`) and seeded by the city scene after the
## connectivity flood, since pockets touch no ocean.
##
## Half-size blocks (2026-09-04): a cell is 8 px = 1 ft. Every dimension
## below is a named structural constant in cells - slabs and walls are 2
## cells thick, doorways 6 tall, ladders 2 wide. Rooms (data/rooms.json)
## are authored in cells too; furniture is snapped to the 2-cell macro grid
## inside a room so it stays on the old 16 px lattice.

const WORLD_W := 7600   # the city proper (52 towers + ocean margins); the grid is wider (annex)
const WORLD_H := 800
const WATERLINE := 104 # raised ~2 floors 2026-09-02 (was old row 64): the open
                       # water between towers sits ~2 floors below the crowns, so a
                       # fall off a roof is a short swim, not an unrecoverable drop
const GROUND := 720

const SLAB_T := 2            # floor slab thickness
const FLOOR_H := 12          # DEFAULT floor pitch: ceiling slab top row -> standing row (SLAB_T + FLOOR_OPEN)
const FLOOR_OPEN := FLOOR_H - SLAB_T # open cavity rows per default floor
const FLOOR_H_MAX := 20      # tallest district pitch (industrial)
const WALL_T := 2            # interior partitions, stair/shaft walls, pocket shells
const OUTER_WALL_T := 4      # tower outer walls
const DOOR_H := 6            # doorway rows (a 2x6 door object fills one)
const DOOR_W := 2
const LADDER_W := 2          # ladder columns per stairwell
const STAIR_W := 6           # stairwell gap in the slabs
const SHAFT_W := 6           # elevator shaft (mid - 3 .. mid + 2)
const BREACH := 4            # wear-pass side breach, BREACH x BREACH
const CRAWL_GAP := 2         # rows a compact (12 px) body squeezes through
const STAND_GAP := 3         # rows a standing (22 px) body needs
const JUMP_CELLS := 6        # rows a jump clears (= Constants.JUMP_HEIGHT_BLOCKS)
const MIN_ROOM_W := 16       # narrowest room the wing packer will stamp
const POCKET_DOOR_INSET := DOOR_W + 2 # doorway plus a step before the first room

const TOWER_W_MIN := 96      # two wings + central shaft (doubled 2026-08-31, user request)
const TOWER_W_MAX := 152
const TOWER_COUNT := 52      # towers on the full-width world (a narrower slice holds fewer)
const OCEAN_MARGIN := 120    # least open water outside the first/last tower
const CLUSTER_GAP_MIN := 5   # rooftop gaps EVERYWHERE (5-10 ft, user request 2026-09-05; was 2-6):
const CLUSTER_GAP_MAX := 10  # wide enough to see the water below, still a jump
const CROWN_ROW := GROUND - 56 * FLOOR_H # the skyline's reference crown row (48)
const SKYLINE_BAND := 10     # every crown sits CROWN_ROW .. CROWN_ROW + SKYLINE_BAND
const LIFT_STEP_MIN := 4     # neighbouring roofs differ by this many cells
const LIFT_STEP_MAX := 10

# Districts (docs/DistrictsOverhaul.md): the five placed types; residential is what remains.
const DISTRICTS: Array = ["business", "commercial", "civil", "industrial", "construction"]
const CENTER_TOWERS := 6       # reserved residential centre (the spawn cluster)
const DISTRICT_SIZE_MIN := 5   # towers per placed district
const DISTRICT_SIZE_MAX := 6
const DISTRICT_SIZE_FLOOR := 2 # a cramped test slice still places clusters this small
const DISTRICT_FLOOR_H: Dictionary = {
	"residential": 12, "business": 12, "commercial": 14, "civil": 14, "industrial": 20, "construction": 12,
}
const DISTRICT_ROOM_W: Dictionary = { # template width filter [min, max]; 9999 = the whole wing
	"residential": [16, 24], "business": [16, 28], "commercial": [20, 38], "civil": [20, 38],
	"industrial": [28, 9999], "construction": [16, 24],
}
const INDUSTRIAL_OPEN_CHANCE := 0.6 # an industrial wing is one open room
const TRIPLE_WIDE: Dictionary = {"industrial": 0.15, "commercial": 0.15} # per-tower chance of a 3-wing footprint
const CONSTRUCTION_BREACH := 0.95   # submerged construction floors: near-certain breach, never sealed

const LADDER_RUN_MIN := 16   # intact submerged ladder run between gaps
const LADDER_RUN_MAX := 44
const LADDER_GAP_MIN := 4
const LADDER_GAP_MAX := 8
const WEAR_DEPTH_NORM := 400.0 # rows below the waterline over which breach chance ramps
const COLLAPSE_W_MIN := 8    # slab collapse hole width
const COLLAPSE_W_MAX := 14
const SEAL_CHANCE := 0.16
const SURFACE_SAFE_CHANCE := 0.012 # wall-safe chance per room above The Cold (0.04 below; GL-28)

const HALL_W := 36           # central mega-pump hall shell
const HALL_H := 14
const RELAY_W := 28          # relay pylon machine room
const RELAY_H := 12
const STATION_MIN_GAP := 40  # open-water span that can hold the hall
const SPAWN_X_OFF := 6       # spawn column offset into the west wing

const ANNEX_GAP := 160  # open columns between the city's edge and the VOID (> half a max-zoom-out view)
const ANNEX_W := 840    # VOID columns holding the pockets on a narrow slice; see annex_width()
const POCKET_VIEW_MARGIN := 160 # VOID kept between a pocket and either annex edge: nothing but
                                # blackness fills a max-zoom-out view from inside a pocket
const POCKET_MIN_W := 16 # interior width clamp for the stamped template
const POCKET_MAX_W := 44
const POCKET_SPACER := 4 # VOID columns between neighbouring pockets in a lane

## VOID columns for the pocket annex: the base width, or ~35 % of the city
## width when that is more - pockets scale with the tower count (52 towers
## at ~50 % of floors need ~3x the room the old 26 did).
static func annex_width(world_w: int) -> int:
	return 2 * POCKET_VIEW_MARGIN + maxi(ANNEX_W - 2 * POCKET_VIEW_MARGIN, world_w * 35 / 100)

static func generate(seed_value: int, world_w: int = WORLD_W) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var annex_x0 := world_w + ANNEX_GAP
	var annex_w := annex_width(world_w)
	var grid := WorldGrid.new(Rect2i(0, 0, annex_x0 + annex_w, WORLD_H))
	var rooms := _load_rooms()
	# Roof surface pool (user request 2026-09-01): pulled out of the
	# interior mix and stamped on every tower's top slab instead.
	var roof_pool: Array = rooms.get("roof", [])
	rooms.erase("roof")
	var objects: Array = []   # {id, cell[, link, open]} — portals carry their twin's cell
	var doors: Array = []     # cells for wood_door
	var sealed: Array = []    # Rect2i room interiors meant to start dry
	var pockets: Array = []   # {rect: interior Rect2i, exit: Vector2i, entry: Vector2i, flooded: bool}
	var result := {
		"grid": grid, "objects": objects, "doors": doors, "sealed": sealed,
		"waterline_row": WATERLINE, "towers": 0, "spawn_feet": Vector2.ZERO, "seed": seed_value,
		"tower_list": [], "relays": [], "debris": 0,
		"city_w": world_w, "pockets": pockets, "districts": [], "center": [0, -1],
	}
	# Bare concrete ground (CT-07: The Crush's floor, solid below) and the
	# pocket annex (solid VOID top to bottom; pockets are carved out of it),
	# composed from two row templates - a per-cell loop over ~4M cells cost
	# more than the rest of generation.
	var gw := annex_x0 + annex_w
	var sky_row := PackedByteArray()
	sky_row.resize(gw)
	var ground_row := PackedByteArray()
	ground_row.resize(gw)
	for x in gw:
		var m: int = WorldGrid.M.VOID if x >= annex_x0 else WorldGrid.M.AIR
		sky_row[x] = m
		ground_row[x] = WorldGrid.M.STONE if x < world_w else m
	var structure := PackedByteArray()
	for y in WORLD_H:
		structure.append_array(ground_row if y >= GROUND else sky_row)
	grid.structure = structure
	# Pocket packer: every carved shell (walls included) is kept as a rect;
	# a new pocket takes the westmost column where its rows are free (first
	# fit), so towers on different floor lattices and pitches pack tightly.
	var pk := {"x0": annex_x0, "x1": annex_x0 + annex_w, "shells": [], "pockets": pockets}
	# 1. Tower slots: widths and hoppable gaps until TOWER_COUNT or the
	#    width is spent (a test slice simply holds fewer towers).
	var avail := world_w - 2 * OCEAN_MARGIN
	var specs: Array = [] # {w, gap, wings}
	var span := 0
	while specs.size() < TOWER_COUNT:
		var w := rng.randi_range(TOWER_W_MIN, TOWER_W_MAX)
		var gap := rng.randi_range(CLUSTER_GAP_MIN, CLUSTER_GAP_MAX) if not specs.is_empty() else 0
		if span + gap + w > avail:
			break
		specs.append({"w": w, "gap": gap, "wings": 2})
		span += gap + w
	var n := specs.size()
	# 2. Districts: the centre is residential, five clusters land outside it
	#    with a residential buffer between any two, residential fills the rest.
	var plan := _assign_districts(rng, n)
	var districts: Array = plan.districts
	result.districts = districts
	result.center = plan.center
	# 3. Rare triple-wide footprints where the district allows and the width has room.
	for i in n:
		var d: String = districts[i]
		if TRIPLE_WIDE.has(d) and rng.randf() < float(TRIPLE_WIDE[d]):
			var extra: int = int(specs[i].w) / 2
			if span + extra <= avail:
				specs[i].w = int(specs[i].w) + extra
				specs[i].wings = 3
				span += extra
	# 4. Build: the run is centred between the ocean margins; crowns walk
	#    within SKYLINE_BAND so the skyline is flat but never a straight line.
	var x := OCEAN_MARGIN + (avail - span) / 2
	var jitter := -1
	for i in n:
		x += int(specs[i].gap)
		var w: int = int(specs[i].w)
		var d: String = districts[i]
		jitter = _crown_step(rng, jitter)
		var top := CROWN_ROW + jitter
		var fh: int = int(DISTRICT_FLOOR_H.get(d, FLOOR_H))
		var floors := (GROUND - top) / fh
		var lift := (GROUND - top) - floors * fh
		var tower := _build_tower(grid, rng, rooms, x, w, floors, objects, doors, sealed, pk, lift,
			d, int(specs[i].wings))
		tower["index"] = i
		tower["center"] = i >= int(plan.center[0]) and i <= int(plan.center[1])
		_stamp_roofs(grid, rng, roof_pool, tower, objects)
		result.towers += 1
		result.tower_list.append(tower)
		x += w
	# Roof drop-off start: the centre-most tower of the residential centre
	# (nothing authored on or in it - user decision 2026-09-04: no hospital,
	# no supply room; the roof-locked opening lives off trees and roof gear).
	var spawn_tower := {}
	var spawn_best := 1e9
	for i in range(int(plan.center[0]), int(plan.center[1]) + 1):
		var t: Dictionary = result.tower_list[i]
		var dc := absf((int(t.x0) + int(t.x1)) * 0.5 - world_w / 2.0)
		if dc < spawn_best:
			spawn_best = dc
			spawn_tower = t
	if spawn_tower.is_empty() and n > 0:
		spawn_tower = result.tower_list[n / 2]
	if not spawn_tower.is_empty():
		_set_roof_spawn(spawn_tower, result)
	# Mega-pump infrastructure shells (CT-08/26, CC-26): the station on the
	# concrete ground plus relay pylons at the band boundaries - in the open
	# water outside the slab now that inter-tower gaps are hoppable.
	_author_stations(grid, rng, objects, result, world_w)
	# Light floating debris on the open surface for mood (CT-23).
	_scatter_surface_debris(grid, rng, objects, result, world_w)
	return result

## District plan for `n` tower slots (docs/DistrictsOverhaul.md): the middle
## CENTER_TOWERS slots are residential and off-limits; each placed district
## (shuffled order) rolls a size and takes a random run of free slots whose
## outer neighbours are residential (the 1-tower buffer) - every valid start
## is enumerated and one picked, so a placement that exists is always found;
## a district that fits nowhere shrinks, down to DISTRICT_SIZE_FLOOR, before
## it is dropped. Residential is whatever remains. Seed-stable (CT-21).
static func _assign_districts(rng: RandomNumberGenerator, n: int) -> Dictionary:
	var out: Array = []
	var claimed := PackedByteArray()
	claimed.resize(n)
	for i in n:
		out.append("residential")
	var c0 := maxi((n - CENTER_TOWERS) / 2, 0)
	var c1 := mini(c0 + CENTER_TOWERS - 1, n - 1)
	for i in range(c0, c1 + 1):
		claimed[i] = 1
	var order: Array = DISTRICTS.duplicate()
	for i in range(order.size() - 1, 0, -1): # Fisher-Yates on the seed stream
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for d in order:
		var size := rng.randi_range(DISTRICT_SIZE_MIN, DISTRICT_SIZE_MAX)
		while size >= DISTRICT_SIZE_FLOOR:
			var starts: Array = []
			for s in range(0, n - size + 1):
				if _run_free(claimed, out, s, size):
					starts.append(s)
			if starts.is_empty():
				size -= 1
				continue
			var s: int = starts[rng.randi_range(0, starts.size() - 1)]
			for i in range(s, s + size):
				out[i] = d
				claimed[i] = 1
			break
	return {"districts": out, "center": [c0, c1]}

## A run of `size` unclaimed slots from `s` whose neighbours (if any) are
## residential - the centre counts, another placed district does not.
static func _run_free(claimed: PackedByteArray, out: Array, s: int, size: int) -> bool:
	for i in range(s, s + size):
		if claimed[i] != 0:
			return false
	if s > 0 and String(out[s - 1]) != "residential":
		return false
	if s + size < out.size() and String(out[s + size]) != "residential":
		return false
	return true

## Next crown jitter (0..SKYLINE_BAND): the first is free, then each roof
## steps LIFT_STEP_MIN..MAX cells from its neighbour - varied but hoppable.
static func _crown_step(rng: RandomNumberGenerator, prev: int) -> int:
	if prev < 0:
		return rng.randi_range(0, SKYLINE_BAND)
	var cands: Array[int] = []
	for v in SKYLINE_BAND + 1:
		if absi(v - prev) >= LIFT_STEP_MIN and absi(v - prev) <= LIFT_STEP_MAX:
			cands.append(v)
	if cands.is_empty():
		return rng.randi_range(0, SKYLINE_BAND)
	return cands[rng.randi_range(0, cands.size() - 1)]

## The tower whose footprint holds `cell` (x0..x1, top..GROUND), or {}.
static func tower_at(towers: Array, cell: Vector2i) -> Dictionary:
	for t in towers:
		if cell.x >= int(t.x0) and cell.x <= int(t.x1) and cell.y >= int(t.top) and cell.y < GROUND:
			return t
	return {}

## The row a cell's depth band is measured at (DistrictsOverhaul "Bands"):
## inside a tower's floor lattice it is the floor's CEILING row, so a floor
## straddling a band boundary takes the shallower band; elsewhere the cell's own row.
static func band_row(towers: Array, cell: Vector2i) -> int:
	var t := tower_at(towers, cell)
	if t.is_empty():
		return cell.y
	var fh := int(t.get("floor_h", FLOOR_H))
	var top := int(t.top)
	var f := (cell.y - top) / fh
	if f >= int(t.floors):
		return cell.y # the plinth
	return top + f * fh

## Two-jump rule check (WS-04): every column of a floor cavity must stay
## passable — a jump clears JUMP_CELLS rows and a crawl fits a CRAWL_GAP, so
## the only true blockage is an authored obstacle taller than the jump from
## the standing row (too high to mount, no room to crawl over). Returns the
## offending columns.
static func floor_blockages(grid: WorldGrid, tower: Dictionary) -> Array:
	var out: Array = []
	var top: int = tower.top
	var fh: int = int(tower.get("floor_h", FLOOR_H))
	for f in tower.floors:
		var sr: int = top + f * fh + fh - 1
		for zone in tower.zones:
			for vx in range(int(zone[0]), int(zone[1]) + 1):
				var blocked := true
				for vy in range(sr - JUMP_CELLS, sr + 1):
					if grid.structure_at(Vector2i(vx, vy)) == WorldGrid.M.AIR:
						blocked = false
						break
				if blocked:
					out.append(Vector2i(vx, sr))
	return out

static func _load_rooms() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms.json"))
	var by_zone := {}
	for r in parsed.rooms:
		var key: String = r.get("zone", r.get("type", "residential"))
		if not by_zone.has(key):
			by_zone[key] = []
		by_zone[key].append(r)
	return by_zone

## Fill a column range of one row with a material.
static func _fill_row(grid: WorldGrid, x0: int, x1: int, y: int, mat: int) -> void:
	for x in range(x0, x1 + 1):
		grid.set_structure(Vector2i(x, y), mat)

## Column plan for a `wings`-wing tower between x0 and x1 (west side; the
## east mirrors it):
##   outer wall x0..x0+3 | stair gap x0+4..x0+9 (ladder hugs the room-side
##   wall at x0+8..x0+9) | stair wall x0+10..x0+11 | wing | shaft wall |
##   shaft (SHAFT_W) | shaft wall | wing | ... | stair wall | stair gap | outer wall
## Shafts sit at the interior's 1/wings fractions, so a 2-wing tower keeps
## its shaft at the old midpoint.
static func _column_plan(x0: int, x1: int, wings: int) -> Dictionary:
	var stair_w0 := x0 + OUTER_WALL_T                # west stair gap start
	var stair_e0 := x1 - OUTER_WALL_T - STAIR_W + 1  # east stair gap start
	var wall_w := stair_w0 + STAIR_W                 # stair walls (WALL_T wide)
	var wall_e := stair_e0 - WALL_T
	var in0 := wall_w + WALL_T                       # first interior column
	var in1 := wall_e - 1                            # last interior column
	var wi := in1 - in0 + 1
	var shafts: Array = []
	var zones: Array = []
	var zx := in0
	for s in range(1, wings):
		var centre := in0 + (wi * s) / wings
		var sx0 := centre - SHAFT_W / 2
		shafts.append([sx0, sx0 + SHAFT_W - 1])
		zones.append([zx, sx0 - WALL_T - 1])
		zx = sx0 + SHAFT_W + WALL_T
	zones.append([zx, in1])
	return {
		"stair_w0": stair_w0, "stair_e0": stair_e0,
		"lad_w": stair_w0 + STAIR_W - LADDER_W, "lad_e": stair_e0, # ladders hug the room-side wall
		"wall_w": wall_w, "wall_e": wall_e, "shafts": shafts, "zones": zones,
	}

static func _build_tower(grid: WorldGrid, rng: RandomNumberGenerator, rooms: Dictionary,
		x0: int, w: int, floors: int, objects: Array, doors: Array, sealed: Array,
		pk: Dictionary = {}, lift: int = 0, district: String = "residential", wings: int = 2) -> Dictionary:
	# District shape (docs/DistrictsOverhaul.md): the floor pitch and the
	# room pool come from the tower's district; construction towers are an
	# unfinished frame - metal skeleton, wood temporary floors and partitions,
	# back walls only where the flood already is.
	var fh: int = int(DISTRICT_FLOOR_H.get(district, FLOOR_H))
	var fo := fh - SLAB_T
	var construction := district == "construction"
	var frame_mat: int = WorldGrid.M.METAL if construction else WorldGrid.M.STONE
	var slab_mat: int = WorldGrid.M.WOOD if construction else WorldGrid.M.METAL
	var part_mat: int = WorldGrid.M.WOOD if construction else WorldGrid.M.STONE
	var back_mat: int = WorldGrid.M.METAL if construction else WorldGrid.M.STONE
	var x1 := x0 + w - 1
	var top := GROUND - floors * fh - lift
	# Dry top pocket (user request 2026-09-02): each surface tower keeps a
	# randomized 4-8 dry floors' worth of rows at the top, INDEPENDENT of the
	# raised exterior waterline. A watertight wood barrier caps the interior
	# at the dry line; the ocean floods only BELOW it (breaches are skipped
	# above), so the pocket stays dry even where it dips under the waterline.
	# Taller district floors keep the same dry HEIGHT (fewer floors).
	var dry_floors := 0
	var barrier_row := -1
	if top < WATERLINE and floors > 6:
		dry_floors = maxi(rng.randi_range(4, 8) * FLOOR_H / fh, 2)
		barrier_row = top + dry_floors * fh
	var plan := _column_plan(x0, x1, wings)
	var lad_w: int = plan.lad_w
	var lad_e: int = plan.lad_e
	var wall_w: int = plan.wall_w
	var wall_e: int = plan.wall_e
	var shafts: Array = plan.shafts
	var zones: Array = plan.zones
	var mid: int = int(shafts[0][0]) + SHAFT_W / 2 # first shaft's centre (= the old midpoint)
	# Outer walls + interior back walls
	for y in range(top, GROUND):
		for t in OUTER_WALL_T:
			grid.set_structure(Vector2i(x0 + t, y), frame_mat)
			grid.set_structure(Vector2i(x1 - t, y), frame_mat)
	for y in range(top + SLAB_T, GROUND):
		if construction and y <= WATERLINE:
			continue # an open frame above the flood: sky-lit, no back wall
		for bx in range(x0 + OUTER_WALL_T, x1 - OUTER_WALL_T + 1):
			grid.set_back(Vector2i(bx, y), back_mat)
	# Crown lift: a solid plinth under the whole footprint raises the floor
	# lattice `lift` rows - the remainder of crown-to-ground / floor pitch,
	# so every tower bottoms out on the same ground row.
	for y in range(GROUND - lift, GROUND):
		for px in range(x0, x1 + 1):
			grid.set_structure(Vector2i(px, y), frame_mat)
	# Slabs (SLAB_T thick) with gaps at both stairwells and every shaft
	for f in floors:
		var y := top + f * fh
		for sx in range(x0 + OUTER_WALL_T, x1 - OUTER_WALL_T + 1):
			var in_stair: bool = f > 0 and ((sx >= plan.stair_w0 and sx < plan.stair_w0 + STAIR_W) \
				or (sx >= plan.stair_e0 and sx < plan.stair_e0 + STAIR_W))
			var in_shaft := false
			for sh in shafts:
				if sx >= int(sh[0]) and sx <= int(sh[1]):
					in_shaft = true
			if not (in_stair or in_shaft):
				for t in SLAB_T:
					grid.set_structure(Vector2i(sx, y + t), slab_mat)
	# Ladders on both sides (stopping on the plinth when lifted)
	for y in range(top + SLAB_T, GROUND - lift):
		for t in LADDER_W:
			grid.set_climb(Vector2i(lad_w + t, y), WorldGrid.C.LADDER)
			grid.set_climb(Vector2i(lad_e + t, y), WorldGrid.C.LADDER)
	# Room pool: the district's zone only (mixed-use per floor is gone),
	# filtered by depth range and the district's template width range.
	var pool: Array = rooms.get(district, [])
	var wr: Array = DISTRICT_ROOM_W.get(district, [MIN_ROOM_W, 9999])
	var in_width := func(r): return int(r.width) >= int(wr[0]) and int(r.width) <= int(wr[1])
	# Per-floor walls, doorways, rooms in every wing
	for f in floors:
		var ceiling := top + f * fh
		var sr := ceiling + fh - 1 # standing row
		# stair walls + shaft walls (lintel rows; doorway sr-DOOR_H+1..sr stays open)
		for wy in range(ceiling + SLAB_T, sr - DOOR_H + 1):
			for t in WALL_T:
				grid.set_structure(Vector2i(wall_w + t, wy), frame_mat)
				grid.set_structure(Vector2i(wall_e + t, wy), frame_mat)
				for sh in shafts:
					grid.set_structure(Vector2i(int(sh[0]) - WALL_T + t, wy), frame_mat)
					grid.set_structure(Vector2i(int(sh[1]) + 1 + t, wy), frame_mat)
		# ~50% of floors get an apartment doorway in one wing (user request:
		# independent rolls were tried against a 3-4 floor countdown and
		# play better). Floor 0 never does.
		# (An unfinished frame has no apartments above the flood: construction
		# floors without back walls carry no doorway.)
		var pocket_wing := -1
		if not pk.is_empty() and f > 0 and not (construction and sr <= WATERLINE) 				and rng.randf() < Constants.POCKET_CHANCE:
			pocket_wing = rng.randi_range(0, zones.size() - 1)
		var depth := sr - WATERLINE
		var in_depth := func(r): return depth >= int(r.get("depth_min", -9999)) and depth <= int(r.get("depth_max", 9999))
		var candidates: Array = pool.filter(func(r): return in_depth.call(r) and in_width.call(r))
		if candidates.is_empty():
			candidates = pool.filter(in_depth) # width is a preference; depth is a rule
		if candidates.is_empty() and not pool.is_empty():
			# No depth-valid room in this zone: depth ranges win over zone
			# (a depth-gated room must never leak to other bands — GL-28
			# leans on iron-bearing rooms staying below The Cold).
			for zp in rooms.values():
				candidates.append_array((zp as Array).filter(in_depth))
		if candidates.is_empty():
			candidates = pool # an empty pool (no templates yet) leaves the wing bare
		for wing in zones.size():
			var zone_x: int = zones[wing][0]
			var zone_end: int = zones[wing][1]
			# The wing's doorway wall (stair side; a middle wing opens west)
			# and the wall sealed solid behind a sealed room.
			var door_x: int
			var solid_x: int
			if wing == 0:
				door_x = wall_w
				solid_x = int(shafts[0][0]) - WALL_T
			elif wing == zones.size() - 1:
				door_x = wall_e
				solid_x = int(shafts[wing - 1][1]) + 1
			else:
				door_x = int(shafts[wing - 1][1]) + 1
				solid_x = int(shafts[wing][0]) - WALL_T
			var seal_this := sr > WATERLINE and not construction and rng.randf() < SEAL_CHANCE
			if seal_this:
				# Deeper sealed rooms hide behind tougher doors (GL-09): wood
				# in The Shallows, chained metal in The Cold, vaults below.
				var dd := sr - WATERLINE
				var did := "wood_door"
				if dd > Constants.BAND_COLD_DEPTH:
					did = "vault_door"
				elif dd > Constants.BAND_SHALLOWS_DEPTH:
					did = "metal_door"
				doors.append({"cell": Vector2i(door_x, sr), "id": did}) # a DOOR_W x DOOR_H door fills the doorway
				for wy in range(sr - DOOR_H + 1, sr + 1): # the far side walled solid
					for t in WALL_T:
						grid.set_structure(Vector2i(solid_x + t, wy), frame_mat)
				sealed.append(Rect2i(zone_x, ceiling + SLAB_T, zone_end - zone_x + 1, fo))
			# Interior pocket doorway (user request): on the back wall beside
			# the stairwell entrance — the wing's first (west) / last (east)
			# columns; the rooms then start POCKET_DOOR_INSET columns in.
			var rx0 := zone_x
			var rx1 := zone_end
			var east_door := wing == zones.size() - 1 and wing > 0
			var barred_door := Vector2i(-1, -1) # set when this wing's pocket is button-locked
			if wing == pocket_wing:
				var door_cell := Vector2i(zone_end - DOOR_W + 1 if east_door else zone_x, sr)
				# Door material follows depth like the sealed-room ladder
				# (GL-09): wood through The Shallows, chained metal below.
				var did := "room_door"
				var is_open := false
				var barred := false
				if sr - WATERLINE > Constants.BAND_SHALLOWS_DEPTH:
					did = "room_door_metal"
				elif rng.randf() < Constants.POCKET_LOCK_CHANCE:
					did = "room_door_locked"
				elif sr <= WATERLINE and rng.randf() < Constants.POCKET_BUTTON_CHANCE:
					# Dry rooms only: a barred door opened by a hidden button, so
					# the player clears the room to find the switch (user request).
					did = "room_door_barred"
					barred = true
				else:
					is_open = rng.randf() < Constants.POCKET_OPEN_CHANCE
				var flooded := sr > WATERLINE and rng.randf() >= Constants.POCKET_SEAL_CHANCE
				if _carve_pocket(grid, rng, pk, sr, candidates, district, objects, door_cell, did, is_open, flooded, fh):
					if east_door:
						rx1 -= POCKET_DOOR_INSET
					else:
						rx0 += POCKET_DOOR_INSET
					if barred:
						barred_door = door_cell
			var cx := rx0
			if district == "industrial" and not candidates.is_empty() and rng.randf() < INDUSTRIAL_OPEN_CHANCE:
				# One open room across the whole wing (large open floors).
				var t: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
				_stamp_room(grid, rng, t, rx1 - cx, cx, sr, rx1, objects, district, fo)
				cx = rx1
			while rx1 - cx >= MIN_ROOM_W and not candidates.is_empty():
				var t: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
				var tw := int(t.width)
				if cx + tw > rx1:
					tw = rx1 - cx
				_stamp_room(grid, rng, t, tw, cx, sr, rx1, objects, district, fo)
				cx += tw
				# interior partition with a doorway (rooms stitch by sockets)
				if rx1 - cx >= MIN_ROOM_W:
					for wy in range(ceiling + SLAB_T, sr - DOOR_H + 1):
						for t2 in WALL_T:
							grid.set_structure(Vector2i(cx + t2, wy), part_mat)
					cx += WALL_T
			# The barred door's release button (user request 2026-09-02): a
			# small back-wall switch tucked among this room's clutter, so the
			# player scraps/searches the room to find it. Placed after the
			# furniture so it lands on a free, clickable cell.
			if barred_door.x >= 0:
				_place_door_button(grid, rng, objects, rx0, rx1, ceiling, sr, barred_door, fo)
	# Broken ladders (user request): submerged runs have decayed into gaps.
	# The pieces scrap for wood; craft ladders and place them to climb back
	# up. (Dry crown ladders stay intact — the tutorial floors.) A
	# broken_ladder piece is 2x2 (bottom-left anchored), one per two gap rows.
	for lx: int in [lad_w, lad_e]:
		var ly := maxi(top + SLAB_T, WATERLINE + 4)
		while ly < GROUND - fh:
			ly += rng.randi_range(LADDER_RUN_MIN, LADDER_RUN_MAX) # intact run between gaps
			var gap := rng.randi_range(LADDER_GAP_MIN, LADDER_GAP_MAX)
			var gy1 := mini(ly + gap, GROUND - lift - 4)
			for gy in range(ly, gy1):
				for t in LADDER_W:
					grid.set_climb(Vector2i(lx + t, gy), WorldGrid.C.NONE)
				if (gy - ly) % 2 == 1 and rng.randf() < 0.6:
					objects.append({"id": "broken_ladder", "cell": Vector2i(lx, gy)})
			ly += gap
	# Two-jump repair (WS-04): carve a walking doorway through any authored
	# obstacle a jump plus a crawl can't clear — a gen-time guarantee.
	var tower := {"x0": x0, "x1": x1, "top": top, "floors": floors, "mid": mid, "zones": zones,
		"shafts": shafts, "district": district, "floor_h": fh, "wings": wings, "lift": lift}
	for bc: Vector2i in floor_blockages(grid, tower):
		for vy in range(bc.y - DOOR_H + 1, bc.y + 1):
			grid.set_structure(Vector2i(bc.x, vy), WorldGrid.M.AIR)
	# Wear pass (CT-11): breaches scale with depth; occasional slab collapse.
	# Construction sites (user decision 2026-09-04) are breached on nearly
	# every submerged floor - the flood is everywhere below the dry cap.
	for f in floors:
		if dry_floors > 0 and f < dry_floors:
			continue # no breaches in the dry top pocket - keep it sealed
		var sr := top + f * fh + fh - 1
		if sr <= WATERLINE:
			continue
		var depth_f := clampf(float(sr - WATERLINE) / WEAR_DEPTH_NORM, 0.0, 1.0)
		var breach_p := CONSTRUCTION_BREACH if construction else 0.2 + depth_f * 0.5
		if rng.randf() < breach_p:
			var side := x0 if rng.randf() < 0.5 else x1 - BREACH + 1
			for by in range(sr - BREACH + 1, sr + 1):
				for bx in range(side, side + BREACH):
					grid.set_structure(Vector2i(bx, by), WorldGrid.M.AIR)
			# Side openings are vent-gated like the roof (user request
			# 2026-09-01) - but only through The Shallows. A closed vent
			# SEALS water, and venting every breach left whole towers dry
			# inside (user bug report: fell 50 blocks through "underwater"
			# floors in air). Deeper breaches stay open as the flood inlets,
			# so interiors fill to the waterline; the shallow, reachable
			# openings still need a pry tool.
			if sr - WATERLINE <= Constants.BAND_SHALLOWS_DEPTH:
				objects.append({"id": "side_vent", "cell": Vector2i(side, sr)}) # BREACH x BREACH grate
		if f > 0 and rng.randf() < 0.10:
			var cy := top + f * fh
			var hole_x := rng.randi_range(x0 + OUTER_WALL_T + 8, x1 - OUTER_WALL_T - 16)
			var hole_w := rng.randi_range(COLLAPSE_W_MIN, COLLAPSE_W_MAX)
			for t in SLAB_T:
				_fill_row(grid, hole_x, hole_x + hole_w - 1, cy + t, WorldGrid.M.AIR)
	# Seal the dry pocket (after the wear pass, so a collapse can't reopen it):
	# fill every non-solid interior cell at the barrier rows with breakable
	# wood - a boarded-up floor the player chops through (tier 1) to dive the
	# shaft - and cut the ladders there. Watertight, so the flood below stays
	# below.
	if barrier_row > 0:
		for t in SLAB_T:
			for bx in range(x0 + OUTER_WALL_T, x1 - OUTER_WALL_T + 1):
				var bc := Vector2i(bx, barrier_row + t)
				if grid.structure_at(bc) == WorldGrid.M.AIR:
					grid.set_structure(bc, WorldGrid.M.WOOD)
					grid.set_climb(bc, WorldGrid.C.NONE)
	return tower

## Carve one interior pocket for the doorway at `exit_cell` (standing row
## `sr`) of a tower with floor pitch `fh`: a stone shell around a
## (fh - SLAB_T)-row cavity in the annex lane of the same ceiling row,
## back-walled like any interior, one zone template stamped inside, and the
## return doorway at the west end. Both doorways are appended to `objects`
## with `link` = the twin's cell and a shared `open` state. Returns false
## (and carves nothing) when the lane is full.
static func _carve_pocket(grid: WorldGrid, rng: RandomNumberGenerator, pk: Dictionary,
		sr: int, candidates: Array, zone: String, objects: Array, exit_cell: Vector2i,
		door_id: String, is_open: bool, flooded: bool, fh: int = FLOOR_H) -> bool:
	if candidates.is_empty():
		return false
	var t: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	var tw := clampi(int(t.width), POCKET_MIN_W, POCKET_MAX_W)
	var w_in := tw + POCKET_DOOR_INSET # doorway + a step + the template
	var fo := fh - SLAB_T
	var ceiling := sr - (fh - 1)
	# First fit from the west: crown lifts and district floor pitches put
	# towers on different lattices, so shells are packed as rects - the
	# pocket lands at the westmost column where no existing shell (plus its
	# POCKET_SPACER of VOID) crosses its rows.
	var shell_w := 2 * WALL_T + w_in
	var shell_h := sr + SLAB_T + 1 - ceiling
	var wx: int = int(pk.x0) + POCKET_VIEW_MARGIN
	var moved := true
	while moved:
		moved = false
		var mine := Rect2i(wx - POCKET_SPACER, ceiling, shell_w + 2 * POCKET_SPACER, shell_h)
		for other: Rect2i in pk.shells:
			if other.intersects(mine):
				wx = maxi(wx, other.end.x + POCKET_SPACER)
				moved = true
		if wx + shell_w + POCKET_VIEW_MARGIN > int(pk.x1):
			return false # annex full at these rows: this floor simply has no apartment door
	var ex := wx + WALL_T + w_in # first east wall column (wall is WALL_T wide)
	pk.shells.append(Rect2i(wx, ceiling, shell_w, shell_h))
	for y in range(ceiling, sr + SLAB_T + 1):
		for x in range(wx, ex + WALL_T):
			var c := Vector2i(x, y)
			var slab: bool = y < ceiling + SLAB_T or y > sr
			var wall: bool = x < wx + WALL_T or x >= ex
			if slab:
				grid.set_structure(c, WorldGrid.M.METAL)
			elif wall:
				grid.set_structure(c, WorldGrid.M.STONE)
			else:
				grid.set_structure(c, WorldGrid.M.AIR)
			grid.set_back(c, WorldGrid.M.STONE) # fogged like any interior (WS-20)
	var entry_cell := Vector2i(wx + WALL_T, sr)
	_stamp_room(grid, rng, t, tw, wx + WALL_T + POCKET_DOOR_INSET, sr, ex, objects, zone, fo)
	objects.append({"id": door_id, "cell": exit_cell, "link": entry_cell, "open": is_open})
	objects.append({"id": "room_door", "cell": entry_cell, "link": exit_cell, "open": is_open})
	pk.pockets.append({"rect": Rect2i(wx + WALL_T, ceiling + SLAB_T, w_in, fo),
		"exit": exit_cell, "entry": entry_cell, "flooded": flooded})
	return true

## Stamp one room template with per-instance variety (CT-05, user request:
## identical layouts everywhere read as copy-paste): random mirroring,
## ±1 macro-block furniture jitter, pieces occasionally missing (looted
## before the flood), wall art hung at slightly different heights, and a
## sprinkle of zone clutter in the leftover floor space. All rng-driven =
## seed-stable. Random horizontal offsets are drawn in 2-cell steps (M) so
## furniture stays on the old 16 px lattice.
const M := 2 # macro-grid step (cells) for in-room placement

static func _stamp_room(grid: WorldGrid, rng: RandomNumberGenerator, t: Dictionary,
		tw: int, cx: int, sr: int, zone_end: int, objects: Array, zone: String,
		fo: int = FLOOR_OPEN) -> void:
	var mirror := rng.randf() < 0.5
	var taken: Array = [] # [x0, x1) floor intervals used by furniture
	for o in t.objects:
		var def: Dictionary = Data.objects.get(o.id, {})
		if def.is_empty():
			continue
		var w := int(def.size[0])
		var h := int(def.size[1])
		var wall: bool = def.get("wall_mounted", false)
		if rng.randf() < 0.15:
			continue # somebody got here first
		var ox := int(o.x)
		if mirror:
			ox = tw - w - ox
		ox += M * rng.randi_range(-1, 1)
		ox = clampi(ox, 0, tw - w)
		if wall:
			var dy := int(o.get("dy", 3 * M))
			dy = clampi(dy + M * rng.randi_range(0, 1), M, fo - h)
			if cx + ox + w <= zone_end:
				objects.append({"id": o.id, "cell": Vector2i(cx + ox, sr - dy)})
			continue
		var lift := int(o.get("dy", 0))
		if lift > 0: # authored off the floor (shelf/counter top): keep the height as drawn
			lift = clampi(lift, 0, fo - h)
			if cx + ox + w <= zone_end:
				objects.append({"id": o.id, "cell": Vector2i(cx + ox, sr - lift)})
			continue
		for attempt in 3: # slide right until the jittered spot is free
			if not _interval_taken(taken, ox, ox + w) and cx + ox + w <= zone_end:
				taken.append([ox, ox + w])
				objects.append({"id": o.id, "cell": Vector2i(cx + ox, sr)})
				break
			ox = clampi(ox + M, 0, tw - w)
	# Mirrored authored blocks keep counters against the intended wall.
	for b in t.get("blocks", []):
		if int(b.dy) >= fo:
			continue # rooms authored taller than the floor cavity crop
		var bx := int(b.x)
		if mirror:
			bx = tw - 1 - bx
		if bx < 0 or bx >= tw:
			continue # authored past a cropped width (a mirrored bx can go negative
			         # and stomp the column left of the room - a pocket doorway)
		var bc := Vector2i(cx + bx, sr - int(b.dy))
		if bc.x < zone_end:
			grid.set_structure(bc, int(b.mat))
	# A rare wall safe (LT-14, a 2x2 piece) tucked into the room's free space.
	# Safes are the only iron above The Cold; with 52 towers (districts,
	# 2026-09-04) the surface rate is cut so GL-28 still forces the dive.
	var safe_p := 0.04 if sr - WATERLINE > Constants.BAND_SHALLOWS_DEPTH else SURFACE_SAFE_CHANCE
	if rng.randf() < safe_p:
		var sx := M * rng.randi_range(0, maxi(tw / M - 1, 0))
		if not _interval_taken(taken, sx, sx + M) and cx + sx + M <= zone_end:
			taken.append([sx, sx + M])
			objects.append({"id": "safe", "cell": Vector2i(cx + sx, sr)})
	# A little lived-in mess: 0-2 clutter pieces (2x2) from this zone's set.
	var clutter := _zone_clutter(zone)
	if not clutter.is_empty():
		for i in rng.randi_range(0, 2):
			var id: String = clutter[rng.randi_range(0, clutter.size() - 1)]
			var ox2 := M * rng.randi_range(0, maxi(tw / M - 1, 0))
			if not _interval_taken(taken, ox2, ox2 + M) and cx + ox2 + M <= zone_end:
				taken.append([ox2, ox2 + M])
				objects.append({"id": id, "cell": Vector2i(cx + ox2, sr)})
	# Interior details (user request 2026-09-01): 0-2 wall pieces from this
	# zone's set (broken-wall decals, vents, duct/pipe runs) on the back
	# wall, and a rare statement piece (statues) in free floor space.
	var wall_bits := _zone_details(zone, "wall_detail")
	if not wall_bits.is_empty():
		var wall_taken: Array = []
		for i in rng.randi_range(0, 2):
			var wid: String = wall_bits[rng.randi_range(0, wall_bits.size() - 1)]
			var wdef: Dictionary = Data.objects[wid]
			var ww := int(wdef.size[0])
			var wh := int(wdef.size[1])
			var wx := M * rng.randi_range(0, maxi((tw - ww) / M, 0))
			var wdy := M * rng.randi_range(1, maxi(1, (fo - wh) / M))
			if not _interval_taken(wall_taken, wx, wx + ww) and cx + wx + ww <= zone_end:
				wall_taken.append([wx, wx + ww])
				objects.append({"id": wid, "cell": Vector2i(cx + wx, sr - wdy)})
	if rng.randf() < 0.06:
		var pieces := _zone_details(zone, "statement")
		if not pieces.is_empty():
			var pid: String = pieces[rng.randi_range(0, pieces.size() - 1)]
			var pw := int(Data.objects[pid].size[0])
			var px := M * rng.randi_range(0, maxi((tw - pw) / M, 0))
			if not _interval_taken(taken, px, px + pw) and cx + px + pw <= zone_end:
				taken.append([px, px + pw])
				objects.append({"id": pid, "cell": Vector2i(cx + px, sr)})

## Roof surface (user request 2026-09-01; abandonment pass same day): each
## wing gets ONE gear set - 2-3 pieces subsampled from a roof template -
## mixed with trees (dry roofs only) and non-harvest junk, so the skyline
## reads old and abandoned instead of crowded. ~30% of the gear rolls its
## overgrown (vined) twin. Wall-mounted pieces never spawn up here.
static func _stamp_roofs(grid: WorldGrid, rng: RandomNumberGenerator, pool: Array,
		tower: Dictionary, objects: Array) -> void:
	if pool.is_empty():
		return
	var roofr: int = int(tower.top) - 1
	var depth := roofr - WATERLINE
	var in_depth := func(r): return depth >= int(r.get("depth_min", -9999)) and depth <= int(r.get("depth_max", 9999))
	var candidates: Array = pool.filter(in_depth)
	if candidates.is_empty():
		return
	var shafts: Array = tower.get("shafts", [[int(tower.mid) - SHAFT_W / 2, int(tower.mid) + SHAFT_W / 2 - 1]])
	# Early-game roof lock (user request 2026-09-01): on dry crowns the open
	# elevator-shaft mouth is sealed by a fixed, padlocked vent hatch - a
	# solid grate until a pry-tier scrap tool (workbench chain) forces it.
	# The roofs are the whole world until then; submerged towers stay open.
	# The hatch is SHAFT_W x SLAB_T, bottom-left anchored on the lower slab row.
	if roofr < WATERLINE:
		for sh in shafts: # one hatch per shaft mouth (a triple-wide tower has two)
			objects.append({"id": "roof_hatch", "cell": Vector2i(int(sh[0]), int(tower.top) + SLAB_T - 1)})
	var flora := _zone_details("roof", "flora")
	var grasses: Array = flora.filter(func(id): return Data.objects[id].get("room_type", "") == "grass" and int(Data.objects[id].size[0]) == M)
	var woody: Array = flora.filter(func(id): return Data.objects[id].get("room_type", "") != "grass")
	for zone in tower.zones:
		var zx: int = int(zone[0])
		var zend: int = int(zone[1])
		var taken: Array = [] # wing-local [x0, x1) floor intervals
		# 2-3 gear pieces from one themed template, scattered across the wing
		var t: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		var picks: Array = (t.objects as Array).duplicate()
		var want := rng.randi_range(2, 3)
		while picks.size() > want:
			picks.remove_at(rng.randi_range(0, picks.size() - 1))
		for o in picks:
			var def: Dictionary = Data.objects.get(o.id, {})
			if def.is_empty() or def.get("wall_mounted", false):
				continue
			var oid: String = o.id
			if rng.randf() < 0.3 and Data.objects.has(oid + "_vined"):
				oid += "_vined" # a coat of vines (user request: overgrown roofs)
			_roof_drop(rng, objects, taken, zx, zend, roofr, oid)
		# non-harvest junk dressing: hammer-cleared, yields nothing
		for i in rng.randi_range(1, 3):
			_roof_drop(rng, objects, taken, zx, zend, roofr, _ROOF_JUNK[rng.randi_range(0, _ROOF_JUNK.size() - 1)])
		# Flora blankets every dry roof (user request 2026-09-01: only ~10%
		# bare): a healthy stand of trees and bushes first (weighted picks
		# from the Flora Editor pool), then grass-type flora (M wide) fills
		# nearly every remaining macro cell.
		if depth <= -1:
			if not woody.is_empty():
				for i in rng.randi_range(3, 6):
					_roof_drop(rng, objects, taken, zx, zend, roofr, _weighted_flora(rng, woody))
			if not grasses.is_empty():
				for lx in range(0, zend - zx + 2 - M, M):
					if not _interval_taken(taken, lx, lx + M) and rng.randf() < 0.9:
						taken.append([lx, lx + M])
						objects.append({"id": _weighted_flora(rng, grasses), "cell": Vector2i(zx + lx, roofr)})
	# The strips OUTSIDE the wings - stairwell tops, wing gaps, parapet
	# edges - carry the same grass blanket, so the whole roofline reads as
	# a meadow; only the open shaft mouth stays bare (user request).
	if depth <= -1 and not grasses.is_empty():
		for x in range(int(tower.x0) + OUTER_WALL_T, int(tower.x1) - OUTER_WALL_T + 2 - M, M):
			var over_shaft := false
			for sh in shafts:
				if x + M - 1 >= int(sh[0]) and x <= int(sh[1]):
					over_shaft = true
			if over_shaft:
				continue
			var in_wing := false
			for zn in tower.zones:
				if x + M - 1 >= int(zn[0]) and x <= int(zn[1]):
					in_wing = true
			if not in_wing and rng.randf() < 0.9:
				objects.append({"id": _weighted_flora(rng, grasses), "cell": Vector2i(x, roofr)})

const _ROOF_JUNK: Array = ["roof_junk_pile", "roof_fallen_mast", "roof_tarp_crates"]

## One flora id from the pool, weighted by each def's flora_weight (>= 1).
static func _weighted_flora(rng: RandomNumberGenerator, pool: Array) -> String:
	var total := 0
	for id in pool:
		total += maxi(int(Data.objects[id].get("flora_weight", 1)), 1)
	var roll := rng.randi_range(1, maxi(total, 1))
	for id in pool:
		roll -= maxi(int(Data.objects[id].get("flora_weight", 1)), 1)
		if roll <= 0:
			return id
	return pool[0]

## Place one object at a free random macro-grid spot on the wing's roof row
## (give up quietly when the wing is crowded - abandonment tolerates gaps).
static func _roof_drop(rng: RandomNumberGenerator, objects: Array, taken: Array,
		zx: int, zend: int, roofr: int, id: String) -> void:
	var def: Dictionary = Data.objects.get(id, {})
	if def.is_empty():
		return
	var w := int(def.size[0])
	if zend - zx + 1 < w:
		return
	for attempt in 6:
		var lx := M * rng.randi_range(0, (zend - zx + 1 - w) / M)
		if not _interval_taken(taken, lx, lx + w):
			taken.append([lx, lx + w])
			objects.append({"id": id, "cell": Vector2i(zx + lx, roofr)})
			return

static func _interval_taken(taken: Array, x0: int, x1: int) -> bool:
	for iv in taken:
		if x0 < int(iv[1]) and int(iv[0]) < x1:
			return true
	return false

static var _clutter_cache: Dictionary = {}

## 2x2-cell (one old block) scrap items tagged for this zone (pack clutter), sorted for CT-21.
static func _zone_clutter(zone: String) -> Array:
	if _clutter_cache.has(zone):
		return _clutter_cache[zone]
	var out: Array = []
	for id in Data.objects:
		var def: Dictionary = Data.objects[id]
		if def.get("kind", "") == "scrap" and def.get("category", "") == "clutter" \
				and int(def.size[0]) == M and int(def.size[1]) == M \
				and (def.get("zones", []) as Array).has(zone):
			out.append(id)
	out.sort()
	_clutter_cache[zone] = out
	return out

static var _details_cache: Dictionary = {}

## Zone-tagged detail pieces by category ("wall_detail" = vents, pipes and
## broken-wall decals; "statement" = statues), sorted for CT-21.
static func _zone_details(zone: String, category: String) -> Array:
	var key := zone + "/" + category
	if _details_cache.has(key):
		return _details_cache[key]
	var out: Array = []
	for id in Data.objects:
		var def: Dictionary = Data.objects[id]
		if def.get("category", "") == category and (def.get("zones", []) as Array).has(zone):
			out.append(id)
	out.sort()
	_details_cache[key] = out
	return out

## Roof drop-off start (user request 2026-09-02): the run begins on a rooftop,
## DECOUPLED from any medical room. Spawn is the very top of the centre-most
## cluster tower; enemy_gen keeps floor 0 of that tower clear so you never land
## on a walker. The player crafts their own bed to move spawn (GL-23); until
## then respawn returns here.
static func _set_roof_spawn(tower: Dictionary, result: Dictionary) -> void:
	var top: int = tower.top
	var zone_x: int = tower.zones[0][0]
	result.spawn_feet = Vector2((zone_x + SPAWN_X_OFF + 1.0) * Constants.BLOCK_SIZE, float(top) * Constants.BLOCK_SIZE)
	result["spawn_tower"] = tower

## Place a barred-door release button (2x2) on a free back-wall cell in the
## wing room (user request 2026-09-02). Avoids furniture footprints so it stays
## clickable; falls back to a high wall cell. `objects` already holds the
## room's furniture.
static func _place_door_button(grid: WorldGrid, rng: RandomNumberGenerator, objects: Array,
		rx0: int, rx1: int, ceiling: int, sr: int, door_cell: Vector2i, fo: int = FLOOR_OPEN) -> void:
	var occ := {}
	for o in objects:
		var oc: Vector2i = o.cell
		if oc.x >= rx0 - WALL_T and oc.x <= rx1 + WALL_T and oc.y <= sr and oc.y > ceiling:
			var od: Dictionary = Data.objects.get(o.id, {})
			var osz: Array = od.get("size", [1, 1])
			for ddy in int(osz[1]):
				for ddx in int(osz[0]):
					occ[Vector2i(oc.x + ddx, oc.y - ddy)] = true
	for _attempt in 24:
		var bc := Vector2i(rng.randi_range(rx0, rx1), sr - rng.randi_range(1, fo - 2))
		if not occ.has(bc) and grid.structure_at(bc) == WorldGrid.M.AIR \
				and grid.back_at(bc) != WorldGrid.M.AIR:
			objects.append({"id": "door_button", "cell": bc, "door": door_cell})
			return
	# Fallback: high on the back wall, above furniture.
	objects.append({"id": "door_button", "cell": Vector2i(rx0, ceiling + SLAB_T + 1), "door": door_cell})

## Mega-pump shells (CT-08, CC-26): non-functional for now — the endgame
## drain wires them up in a later milestone. The central station is a metal
## hall on the concrete ground at city centre; relays are freestanding metal
## pylons rising from the ground with a machine room at each band boundary.
static func _author_stations(grid: WorldGrid, rng: RandomNumberGenerator,
		objects: Array, result: Dictionary, world_w: int) -> void:
	# Central station: a hall on the ground row, in the inter-tower gap
	# nearest the city centre that can hold it (gaps narrow toward centre).
	var best_x := -1
	var best_score := -1.0e18
	var towers: Array = result.tower_list
	# Candidate spans: every inter-tower gap plus the two ocean margins
	# (with hoppable gaps citywide the margins are the only spans that fit).
	var spans: Array = []
	if not towers.is_empty():
		spans.append([0, int(towers[0].x0) - 1])
		spans.append([int(towers[towers.size() - 1].x1) + 1, world_w - 1])
	for i in range(towers.size() - 1):
		spans.append([int(towers[i].x1) + 1, int(towers[i + 1].x0) - 1])
	for sp in spans:
		var gap_x0: int = int(sp[0])
		var gap_w: int = int(sp[1]) - gap_x0 + 1
		if gap_w < STATION_MIN_GAP:
			continue
		var mid := gap_x0 + gap_w / 2
		var score := -absf(mid - world_w / 2.0)
		if score > best_score:
			best_score = score
			best_x = mid
	if best_x >= 0:
		var hall := Rect2i(best_x - HALL_W / 2, GROUND - HALL_H, HALL_W, HALL_H)
		_station_room(grid, hall, objects, true)
		result["central"] = hall
	# Relay pylons at the shallows/cold, cold/dark, dark/crush boundaries.
	var relay_rows: Array = [
		WATERLINE + Constants.BAND_SHALLOWS_DEPTH,
		WATERLINE + Constants.BAND_COLD_DEPTH,
		WATERLINE + Constants.BAND_DARK_DEPTH,
	]
	var fracs: Array = [0.25, 0.58, 0.8]
	for i in relay_rows.size():
		var row: int = relay_rows[i]
		var px0 := _find_open_span(grid, int(world_w * float(fracs[i])), row, RELAY_W, row - RELAY_H, row + SLAB_T)
		if px0 < 0:
			continue
		var shell := Rect2i(px0, row - RELAY_H + 1, RELAY_W, RELAY_H)
		_station_room(grid, shell, objects, false)
		# Support legs (WALL_T wide) drop until they meet something solid (a
		# roof or the ground) — never through a tower's interior (keeps WS-04 intact).
		for lx: int in [px0 + WALL_T, px0 + RELAY_W - 2 * WALL_T]:
			for y in range(shell.end.y + SLAB_T, GROUND + 1):
				var hit := false
				for t in WALL_T:
					if grid.structure_at(Vector2i(lx + t, y)) != WorldGrid.M.AIR:
						hit = true
				if hit:
					break
				for t in WALL_T:
					grid.set_structure(Vector2i(lx + t, y), WorldGrid.M.METAL)
		result.relays.append(shell)

## A sealed metal machine room: walls (WALL_T), roof and floor (SLAB_T), back
## walls, a side doorway, and the pump/breaker kit. rect covers the shell down
## to the standing row; the floor slab hangs SLAB_T rows below rect.end.y.
static func _station_room(grid: WorldGrid, rect: Rect2i, objects: Array, central: bool) -> void:
	var sr := rect.end.y - 1 # standing row (the floor slab sits below it)
	for y in range(rect.position.y, rect.end.y + SLAB_T):
		for x in range(rect.position.x, rect.end.x):
			var edge: bool = y < rect.position.y + SLAB_T or y > sr \
				or x < rect.position.x + WALL_T or x >= rect.end.x - WALL_T
			grid.set_structure(Vector2i(x, y), WorldGrid.M.METAL if edge else WorldGrid.M.AIR)
			if not edge:
				grid.set_back(Vector2i(x, y), WorldGrid.M.METAL)
	# Side doorway (4 rows, WALL_T wide) so divers can get in; water floods it like any room.
	for y in range(sr - 3, sr + 1):
		for t in WALL_T:
			grid.set_structure(Vector2i(rect.position.x + t, y), WorldGrid.M.AIR)
	var x0 := rect.position.x + 2 * WALL_T
	objects.append({"id": "breaker", "cell": Vector2i(x0, sr - 4)})
	objects.append({"id": "pump", "cell": Vector2i(x0 + 4, sr)})
	objects.append({"id": "ceiling_lamp", "cell": Vector2i(x0 + 8, rect.position.y + SLAB_T + 1)})
	if central:
		objects.append({"id": "pump", "cell": Vector2i(x0 + 12, sr)})
		objects.append({"id": "pump", "cell": Vector2i(x0 + 18, sr)})
		objects.append({"id": "ceiling_lamp", "cell": Vector2i(x0 + 22, rect.position.y + SLAB_T + 1)})
		objects.append({"id": "chest", "cell": Vector2i(x0 + 24, sr)})

## Leftmost x of a `w`-wide span centred near want_x whose rows y0..y1 are
## clear of structure; scans outward, -1 if the city is too dense there.
static func _find_open_span(grid: WorldGrid, want_x: int, _row: int, w: int, y0: int, y1: int) -> int:
	for off in range(0, grid.bounds.end.x, 8):
		for sgn: int in [1, -1]:
			var x0 := want_x + off * sgn - w / 2
			if x0 < 8 or x0 + w > grid.bounds.end.x - 8:
				continue
			var clear := true
			for x in range(x0, x0 + w):
				for y in range(y0, y1 + 1):
					if grid.structure_at(Vector2i(x, y)) != WorldGrid.M.AIR:
						clear = false
						break
				if not clear:
					break
			if clear:
				return x0
	return -1

## Floating wood rafts (SLAB_T thick) scattered on open water between towers (CT-23).
static func _scatter_surface_debris(grid: WorldGrid, rng: RandomNumberGenerator,
		objects: Array, result: Dictionary, world_w: int) -> void:
	var x := 60
	while x < world_w - 60:
		x += rng.randi_range(30, 80) # short strides: open water is only the margins and the gaps now
		var w := rng.randi_range(4, 10)
		var clear := true
		for sx in range(x - 2, x + w + 2):
			for sy in range(WATERLINE - 8, WATERLINE + 6):
				if grid.structure_at(Vector2i(sx, sy)) != WorldGrid.M.AIR:
					clear = false
					break
			if not clear:
				break
		if not clear:
			continue
		for t in SLAB_T:
			_fill_row(grid, x, x + w - 1, WATERLINE + t, WorldGrid.M.WOOD)
		if w >= 8 and rng.randf() < 0.35:
			objects.append({"id": "ret_box", "cell": Vector2i(x + 2, WATERLINE - 1)})
		result.debris += 1

## Connectivity flooding (CT-12/13): everything reachable from the ocean at
## or below the waterline floods to full; sealed pockets keep their air.
## Runs after objects exist so closed doors seal (World solidity = structure
## or a closed door record). A scanline fill over the grid's byte arrays
## (2026-09-04 perf: the cell-by-cell DFS took 5.5 s on the 4x grid).
static func flood(world) -> void:
	var sim: WaterSim = world.water_sim
	var grid: WorldGrid = world.grid
	var b: Rect2i = sim.bounds
	var bw := b.size.x
	var bx0 := b.position.x
	var by0 := b.position.y
	var structure: PackedByteArray = grid.structure
	var doors: Dictionary = world.closed_door_cells()
	var visited := PackedByteArray()
	visited.resize(bw * b.size.y)
	var y_min := WATERLINE - by0 # local rows at/below the waterline only
	var y_max := b.size.y - 1
	var stack := PackedInt32Array()
	for y in range(y_min, mini(GROUND - by0, y_max + 1)):
		stack.append(y * bw)
		stack.append(y * bw + bw - 1)
	var door_idx := {} # grid index -> true for every closed-door cell
	for c: Vector2i in doors:
		if b.has_point(c):
			door_idx[(c.y - by0) * bw + (c.x - bx0)] = true
	var has_doors := not door_idx.is_empty()
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if visited[i] == 1:
			continue
		if structure[i] != 0 or (has_doors and door_idx.has(i)):
			visited[i] = 1
			continue
		@warning_ignore("integer_division")
		var y := i / bw
		var row0 := y * bw
		# walk to the west end of this open run
		var x := i - row0
		while x > 0 and visited[row0 + x - 1] == 0 and structure[row0 + x - 1] == 0 \
				and not (has_doors and door_idx.has(row0 + x - 1)):
			x -= 1
		# fill east, pushing the open cells above and below
		var above_open := false
		var below_open := false
		while x < bw:
			var ci := row0 + x
			if visited[ci] == 1:
				break
			if structure[ci] != 0 or (has_doors and door_idx.has(ci)):
				visited[ci] = 1
				break
			visited[ci] = 1
			sim.levels[ci] = WaterSim.MAX_LEVEL
			if y > y_min:
				var ai := ci - bw
				var a_open: bool = visited[ai] == 0 and structure[ai] == 0
				if a_open and not above_open:
					stack.append(ai)
				above_open = a_open
			if y < y_max:
				var bi := ci + bw
				var b_open: bool = visited[bi] == 0 and structure[bi] == 0
				if b_open and not below_open:
					stack.append(bi)
				below_open = b_open
			x += 1
