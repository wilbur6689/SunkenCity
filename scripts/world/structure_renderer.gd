class_name StructureRenderer
extends Node2D
## Windows the WorldGrid into TileMapLayers around the camera (CT-28): only
## a rect of cells near the view is ever painted (tiles carry collision, so
## physics exists exactly where the player is — Terraria-style). Creates its
## three layers (back walls, solid blocks, climbables) as children.

const TILESET := preload("res://assets/tiles/placeholder_blocks.tres")
const MARGIN := 14        # cells beyond the view kept painted
const SHRINK_SLACK := 10  # how far the view must move before erasing

var back_layer: TileMapLayer
var blocks_layer: TileMapLayer
var climb_layer: TileMapLayer
var painted := Rect2i() # currently painted cell rect (zero = nothing)

func _ready() -> void:
	back_layer = TileMapLayer.new()
	back_layer.tile_set = TILESET
	back_layer.collision_enabled = false
	back_layer.modulate = Color(0.42, 0.45, 0.52)
	add_child(back_layer)
	blocks_layer = TileMapLayer.new()
	blocks_layer.tile_set = TILESET
	add_child(blocks_layer)
	climb_layer = TileMapLayer.new()
	climb_layer.tile_set = TILESET
	climb_layer.collision_enabled = false
	add_child(climb_layer)
	add_child(_CrackLayer.new()) # after the tile layers: cracks draw on top

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
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var s := Constants.BLOCK_SIZE
	var half := get_viewport_rect().size * 0.5 / cam.zoom.x
	var c0 := Vector2i(floori((cam.get_screen_center_position().x - half.x) / s), floori((cam.get_screen_center_position().y - half.y) / s))
	var c1 := Vector2i(ceili((cam.get_screen_center_position().x + half.x) / s), ceili((cam.get_screen_center_position().y + half.y) / s))
	var want := Rect2i(c0 - Vector2i(MARGIN, MARGIN), (c1 - c0) + Vector2i(MARGIN * 2, MARGIN * 2))
	want = want.intersection(World.grid.bounds)
	if painted.encloses(want) and painted.grow(-SHRINK_SLACK).intersection(want) != want:
		pass # keep
	if painted == Rect2i():
		_paint_rect(want)
		painted = want
		return
	if painted.encloses(want):
		return
	var new_rect := painted.merge(want)
	# Repaint fully if the merged area drifted too large; else paint the delta strips.
	if new_rect.size.x * new_rect.size.y > (want.size.x + SHRINK_SLACK * 2) * (want.size.y + SHRINK_SLACK * 2) * 2:
		_clear_all()
		_paint_rect(want)
		painted = want
	else:
		for y in range(new_rect.position.y, new_rect.end.y):
			for x in range(new_rect.position.x, new_rect.end.x):
				var c := Vector2i(x, y)
				if not painted.has_point(c):
					_paint_cell(c)
		painted = new_rect

func _clear_all() -> void:
	back_layer.clear()
	blocks_layer.clear()
	climb_layer.clear()

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
		climb_layer.set_cell(cell, 0, Vector2i(0, 4 + cl)) # ladder row 5, rope row 6

## A grid cell changed: repaint it if it is inside the painted window.
func refresh_cell(cell: Vector2i) -> void:
	if painted != Rect2i() and painted.has_point(cell):
		_paint_cell(cell)
