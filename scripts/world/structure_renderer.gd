class_name StructureRenderer
extends Node2D
## Windows the WorldGrid into TileMapLayers around the camera (CT-28): only
## a rect of cells near the view is ever painted (tiles carry collision, so
## physics exists exactly where the player is — Terraria-style). Creates its
## three layers (back walls, solid blocks, climbables) as children.
##
## Anchors (2026-09-06, user report: a LAN client fell through floors and
## walls far from the host): the painted area is the UNION of one rect per
## anchor — the camera view (+MARGIN) and, on the host, an ENEMY_WINDOW-sized
## rect around EVERY simulated player body (the local one too), so a remote
## player and the enemies streamed in around it always stand on physics. A
## client paints only around its own camera (it simulates nothing).

## Tile art density (2026-09-04, half-size blocks): 24 px tiles drawn at 1/3
## scale onto the 8 px cell grid — 1 texel per monitor pixel at the default
## zoom (3.0) on a 1080p screen. Physics rides the scaled layers (+-12
## polygons -> +-4). Atlas + tres come from tools/gen_tiles_24.py. (History:
## 16 px tiles at 1.0 until 2026-09-02, then 32 px at 0.5 on 16 px cells.)
const TILESET := preload("res://assets/tiles/placeholder_blocks_24.tres")
const TILE_ART_SCALE := float(Constants.BLOCK_SIZE) / 24.0
const MARGIN := 28        # cells beyond the view kept painted
const SHRINK_SLACK := 20  # how far the view must move before erasing

var back_layer: TileMapLayer
var blocks_layer: TileMapLayer
var climb_layer: TileMapLayer
var painted: Dictionary = {} # anchor key -> painted cell rect (the union is what exists)

func _ready() -> void:
	back_layer = TileMapLayer.new()
	back_layer.tile_set = TILESET
	back_layer.collision_enabled = false
	back_layer.modulate = Color(0.42, 0.45, 0.52)
	back_layer.z_index = -3 # under the decal/wall-object planes (room layers)
	add_child(back_layer)
	blocks_layer = TileMapLayer.new()
	blocks_layer.tile_set = TILESET
	add_child(blocks_layer)
	climb_layer = TileMapLayer.new()
	climb_layer.tile_set = TILESET
	climb_layer.collision_enabled = false
	add_child(climb_layer)
	for layer: TileMapLayer in [back_layer, blocks_layer, climb_layer]:
		layer.scale = Vector2(TILE_ART_SCALE, TILE_ART_SCALE)
	add_child(_CrackLayer.new()) # after the tile layers: cracks draw on top; NOT scaled (draws in world px)

## Damage cracks (WS-22, user request): any damaged block — structure or
## player-placed — shows progressively larger cracks at 25/50/75% damage,
## from the 3-stage sheet assets/sprites/cracks.png. Redraws only when
## World.damage_rev moves.
class _CrackLayer extends Node2D:
	const SHEET := preload("res://assets/sprites/cracks.png")
	var _rev: int = -1

	func _physics_process(_delta: float) -> void:
		if World.grid != null and World.damage_rev != _rev:
			_rev = World.damage_rev
			queue_redraw()

	func _draw() -> void:
		if World.grid == null:
			return
		for cell in World.structure_damage:
			var full: float = Constants.STRUCTURE_HP.get(World.grid.structure_at(cell), 60.0)
			_draw_cracks(cell, 1.0 - float(World.structure_damage[cell]) / full)
		for key in World.placed_blocks:
			if key is Vector2i: # blocks layer only (back/climb use string keys)
				var e: Dictionary = World.placed_blocks[key]
				_draw_cracks(key, 1.0 - float(e.hp) / float(Data.blocks[e.id].hp))

	func _draw_cracks(cell: Vector2i, fraction: float) -> void:
		var stage := mini(int(fraction * 4.0), 3) # 25/50/75% -> stages 1/2/3
		if stage < 1:
			return
		var s := Constants.BLOCK_SIZE
		draw_texture_rect_region(SHEET, Rect2(cell.x * s, cell.y * s, s, s),
			Rect2((stage - 1) * 16, 0, 16, 16))

func _physics_process(_delta: float) -> void:
	if World.grid == null:
		return
	var s := Constants.BLOCK_SIZE
	var wants: Dictionary = {}
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		var half := get_viewport_rect().size * 0.5 / cam.zoom.x
		var c0 := Vector2i(floori((cam.get_screen_center_position().x - half.x) / s), floori((cam.get_screen_center_position().y - half.y) / s))
		var c1 := Vector2i(ceili((cam.get_screen_center_position().x + half.x) / s), ceili((cam.get_screen_center_position().y + half.y) / s))
		wants["cam"] = Rect2i(c0 - Vector2i(MARGIN, MARGIN), (c1 - c0) + Vector2i(MARGIN * 2, MARGIN * 2))
	if Net.is_server():
		# Physics wherever the host simulates a body (and the enemies around it).
		var bhalf: Vector2i = Constants.ENEMY_WINDOW / 2
		for p in get_tree().get_nodes_in_group("player"):
			if p is Node2D and is_instance_valid(p):
				wants[p.get("peer_id")] = Rect2i(World.cell_at(p.global_position) - bhalf, Constants.ENEMY_WINDOW)
	if wants.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	for key in wants:
		wants[key] = (wants[key] as Rect2i).intersection(World.grid.bounds)
	for key in painted.keys():
		if not wants.has(key):
			_drop_anchor(key)
	for key in wants:
		_update_anchor(key, wants[key])
	var cells := 0
	for key in painted:
		cells += (painted[key] as Rect2i).size.x * (painted[key] as Rect2i).size.y
	World.perf.struct_cells = cells
	World.perf.struct_ms = (Time.get_ticks_usec() - t0) / 1000.0

## Bring one anchor's painted rect up to `want`: paint fresh, grow by delta
## strips while the merged rect stays sane, else drop the old rect and paint
## the new one. Cells another anchor still covers are never erased.
func _update_anchor(key, want: Rect2i) -> void:
	if not painted.has(key):
		_paint_rect(want)
		painted[key] = want
		return
	var cur: Rect2i = painted[key]
	if cur.encloses(want):
		return
	var new_rect := cur.merge(want)
	if new_rect.size.x * new_rect.size.y > (want.size.x + SHRINK_SLACK * 2) * (want.size.y + SHRINK_SLACK * 2) * 2:
		painted.erase(key)
		_erase_rect_uncovered(cur)
		_paint_rect(want)
		painted[key] = want
	else:
		for y in range(new_rect.position.y, new_rect.end.y):
			for x in range(new_rect.position.x, new_rect.end.x):
				var c := Vector2i(x, y)
				if not cur.has_point(c):
					_paint_cell(c)
		painted[key] = new_rect

func _drop_anchor(key) -> void:
	var cur: Rect2i = painted[key]
	painted.erase(key)
	_erase_rect_uncovered(cur)

## True when some painted anchor rect contains the cell.
func _is_painted(cell: Vector2i) -> bool:
	for key in painted:
		if (painted[key] as Rect2i).has_point(cell):
			return true
	return false

func _erase_rect_uncovered(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if not _is_painted(c):
				_erase_cell(c)

func _erase_cell(cell: Vector2i) -> void:
	blocks_layer.erase_cell(cell)
	back_layer.erase_cell(cell)
	climb_layer.erase_cell(cell)

func _clear_all() -> void:
	back_layer.clear()
	blocks_layer.clear()
	climb_layer.clear()
	painted.clear()

func _paint_rect(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_paint_cell(Vector2i(x, y))

func _paint_cell(cell: Vector2i) -> void:
	var g := World.grid
	var m := g.structure_at(cell)
	if m == WorldGrid.M.AIR:
		blocks_layer.erase_cell(cell)
	else:
		blocks_layer.set_cell(cell, 0, Vector2i(posmod(hash(cell), 5), m - 1))
	var b := g.back_at(cell)
	if b == WorldGrid.M.AIR:
		back_layer.erase_cell(cell)
	else:
		back_layer.set_cell(cell, 0, Vector2i(posmod(hash(cell) + 3, 5), b - 1))
	var cl := g.climb_at(cell)
	if cl == WorldGrid.C.NONE:
		climb_layer.erase_cell(cell)
	else:
		# Ladder halves (user request 2026-09-05): a 2-wide ladder reads as one
		# H per row - atlas col 0 = left rail + rung, col 1 = right rail + rung,
		# col 2 = a lone single-cell ladder. Ropes use col 0.
		var col := 0
		if cl == WorldGrid.C.LADDER:
			if g.climb_at(cell + Vector2i.LEFT) == WorldGrid.C.LADDER:
				col = 1
			elif g.climb_at(cell + Vector2i.RIGHT) != WorldGrid.C.LADDER:
				col = 2
		climb_layer.set_cell(cell, 0, Vector2i(col, 4 + cl)) # ladder row 5, rope row 6

## A grid cell changed: repaint it if it is inside the painted window.
func refresh_cell(cell: Vector2i) -> void:
	if _is_painted(cell):
		_paint_cell(cell)
		for n: Vector2i in [cell + Vector2i.LEFT, cell + Vector2i.RIGHT]: # a ladder half's art depends on its neighbour
			if _is_painted(n) and World.grid.climb_at(n) != WorldGrid.C.NONE:
				_paint_cell(n)
