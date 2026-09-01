class_name WorldItem
extends Node2D
## A dropped item stack lying in the world. Falls under gravity, rests on
## solid blocks, sinks slowly in water (buoyancy/pinning is M2), and is
## picked up by a player who walks within PICKUP_RADIUS. Persists in the
## scene until picked up (save/load is M3).

var id: String = ""
var count: int = 1
var velocity: Vector2 = Vector2.ZERO
var pickup_delay: float = 0.0
var magnet: bool = false # mined drops home to a nearby player (pays out visibly)
var light: PointLight2D

@onready var sprite: Sprite2D = $Sprite2D

func setup(p_id: String, p_count: int, p_velocity: Vector2 = Vector2.ZERO) -> void:
	id = p_id
	count = p_count
	velocity = p_velocity
	pickup_delay = Constants.DROP_PICKUP_DELAY

func _ready() -> void:
	add_to_group("world_items")
	sprite.texture = Data.icon(id)
	var it := Data.item(id)
	var drop_light: Dictionary = it.get("use", {}).get("drop_light", {})
	if not drop_light.is_empty():
		light = PointLight2D.new()
		light.texture = load("res://assets/sprites/light.png")
		light.texture_scale = float(drop_light.get("radius_blocks", 4)) * Constants.BLOCK_SIZE / 64.0
		var c: Array = drop_light.get("color", [1, 1, 1])
		light.color = Color(c[0], c[1], c[2])
		light.energy = 0.9
		add_child(light)

func _physics_process(delta: float) -> void:
	pickup_delay = maxf(pickup_delay - delta, 0.0)
	var in_water := World.is_water(global_position)
	var sinks: bool = Data.item(id).get("sinks", false)
	if in_water and not sinks:
		# Buoyant (CC-07): rise until the surface — or pin against a ceiling.
		if World.is_solid(global_position + Vector2(0, -6.0)):
			velocity = Vector2.ZERO # pinned to the ceiling
			var cell := World.cell_at(global_position + Vector2(0, -6.0))
			global_position.y = (cell.y + 1) * Constants.BLOCK_SIZE + 5.0
		else:
			velocity.y = move_toward(velocity.y, -Constants.ITEM_BUOYANCY_RISE, 6.0 * Constants.BLOCK_SIZE * delta)
			var surface := World.water_surface_y(global_position)
			if global_position.y + velocity.y * delta < surface + 3.0:
				global_position.y = surface + 3.0 # bob at the surface
				velocity.y = 0.0
	else:
		var g := Constants.gravity * (0.15 if in_water else 1.0)
		velocity.y = minf(velocity.y + g * delta, (2.0 if in_water else 20.0) * Constants.BLOCK_SIZE)
	velocity.x = move_toward(velocity.x, 0.0, (8.0 if in_water else 3.0) * Constants.BLOCK_SIZE * delta)
	if in_water:
		velocity += World.current_at(global_position) * delta * 4.0 # currents carry items (WS-16)
	# Mined-drop magnet: once grabbable, fly straight to a player in range
	# (solid checks below still stop it at walls).
	if magnet and pickup_delay <= 0.0:
		for p in get_tree().get_nodes_in_group("player"):
			var to: Vector2 = p.global_position - global_position
			if to.length() <= Constants.ITEM_MAGNET_RADIUS_BLOCKS * Constants.BLOCK_SIZE:
				velocity = to.normalized() * Constants.ITEM_MAGNET_SPEED
				break
	var next := global_position + velocity * delta
	# rest on the top of the first solid cell below
	if velocity.y > 0.0 and World.is_solid(next + Vector2(0, 4)):
		var cell := World.cell_at(next + Vector2(0, 4))
		next.y = World.cell_top_y(cell) - 4.0
		velocity.y = 0.0
	if velocity.x != 0.0 and World.is_solid(next):
		next.x = global_position.x
		velocity.x = 0.0
	global_position = next
	if pickup_delay <= 0.0:
		_try_pickup()

func _try_pickup() -> void:
	var radius := Constants.PICKUP_RADIUS_BLOCKS * Constants.BLOCK_SIZE
	for p in get_tree().get_nodes_in_group("player"):
		if p.global_position.distance_to(global_position) <= radius:
			var leftover: int = p.inventory.add(id, count)
			if leftover < count:
				count = leftover
				if count <= 0:
					queue_free()
			return
