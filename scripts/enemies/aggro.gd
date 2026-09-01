class_name Aggro
extends RefCounted
## The single shared enemy sense (GD-06/12/25/26): proximity only — an
## activation radius, no light/sound/scent modeling. At night, radii in the
## surface bands grow (GD-29); bands below The Shallows never see the sun.

## The nearest player within `radius_blocks` of `pos`, or null. Every enemy
## acquires targets through this one call.
static func acquire(tree: SceneTree, pos: Vector2, radius_blocks: float) -> Node2D:
	var radius := radius_blocks * Constants.BLOCK_SIZE
	var band: String = World.band_at(World.cell_at(pos))
	if World.is_night() and (band == "dry" or band == "shallows"):
		radius *= Constants.AGGRO_NIGHT_MULT
	var best: Node2D = null
	var best_d := radius
	for p in tree.get_nodes_in_group("player"):
		var d: float = (p as Node2D).global_position.distance_to(pos)
		if d <= best_d:
			best_d = d
			best = p
	return best
