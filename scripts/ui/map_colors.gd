class_name MapColors
extends RefCounted
## Shared cell-color mapping for the minimap and the full-screen map (CC-25):
## structure materials, water depth-graded to the abyss, sky, and interiors.

const MAT := {
	WorldGrid.M.STONE: Color(0.52, 0.52, 0.55),
	WorldGrid.M.WOOD: Color(0.55, 0.4, 0.24),
	WorldGrid.M.METAL: Color(0.45, 0.52, 0.6),
	WorldGrid.M.PLASTIC: Color(0.75, 0.72, 0.66),
}
const UNREVEALED := Color(0.03, 0.03, 0.05)
const SKY := Color(0.22, 0.55, 0.64)
const INTERIOR := Color(0.16, 0.14, 0.13)
const WATER := Color(0.12, 0.3, 0.52)
const DEEP := Color(0.05, 0.12, 0.26)

## Color of one REVEALED cell (callers handle unrevealed themselves).
static func cell_color(cell: Vector2i) -> Color:
	var mat: int = World.grid.structure_at(cell)
	if mat != WorldGrid.M.AIR:
		return MAT.get(mat, INTERIOR)
	if World.water_sim.level_at(cell) > 2:
		var deep_f := clampf(float(cell.y - World.waterline_row) / 250.0, 0.0, 1.0)
		return WATER.lerp(DEEP, deep_f)
	if World.has_back_wall_cell(cell):
		return INTERIOR
	return SKY if cell.y < World.waterline_row else WATER.lerp(INTERIOR, 0.5)
