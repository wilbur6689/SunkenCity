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
var gentle: bool = false # harvest drops drift in softly instead of snapping (2026-09-02)
var _bob_t: float = randf() * TAU # phase-offset so a pile of drops doesn't bob in unison
var light: PointLight2D
var net_id: int = 0 # host-assigned (World.spawn_item); clients address items by it

@onready var sprite: Sprite2D = $Sprite2D

func setup(p_id: String, p_count: int, p_velocity: Vector2 = Vector2.ZERO) -> void:
	id = p_id
	count = p_count
	velocity = p_velocity
	pickup_delay = Constants.DROP_PICKUP_DELAY

func _ready() -> void:
	add_to_group("world_items")
	sprite.texture = Data.icon(id)
	if sprite.texture != null and sprite.texture.get_width() > Constants.BLOCK_SIZE:
		# Dropped resources draw at ONE BLOCK (8 px since 2026-09-04, user request:
		# harvest drops shrank with the block), whatever size the icon is authored at.
		sprite.scale = Vector2.ONE * (float(Constants.BLOCK_SIZE) / sprite.texture.get_width())
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

## Perf (2026-09-05): a dropped item far from every player sleeps (no
## physics, no magnet) and one hidden behind the fog of war is not drawn.
## Both re-check a few times a second, not per frame.
var _cull_timer: float = 0.0
var asleep: bool = false

func _cull_check() -> void:
	var near := false
	var viewer: Node2D = null
	var best := INF
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node2D:
			var d := (p as Node2D).global_position.distance_squared_to(global_position)
			if d < best:
				best = d
				viewer = p
	var sleep_px := Constants.ITEM_SLEEP_BLOCKS * Constants.BLOCK_SIZE
	near = best < sleep_px * sleep_px
	asleep = not near
	# Fog: an item the local viewer cannot see draws nothing (the overlay
	# would black it out anyway; this saves the sprite + light draw).
	var local := Net.local_player() as Node2D
	var hidden := false
	if local != null and World.light_map != null and near:
		hidden = World.visibility_at(World.cell_at(global_position), local.global_position) <= 0.0
	elif local != null and not near:
		hidden = true
	visible = not hidden

func _physics_process(delta: float) -> void:
	_cull_timer -= delta
	if _cull_timer <= 0.0:
		_cull_timer = Constants.ITEM_CULL_SECONDS
		_cull_check()
	if asleep:
		pickup_delay = maxf(pickup_delay - delta, 0.0)
		return
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
			# plunging in from a fall brakes hard (user report 2026-09-01)
			var rise_accel := Constants.WATER_PLUNGE_DECEL if velocity.y > 0.0 else 12.0 * Constants.BLOCK_SIZE
			velocity.y = move_toward(velocity.y, -Constants.ITEM_BUOYANCY_RISE, rise_accel * delta)
			var surface := World.water_surface_y(global_position)
			if global_position.y + velocity.y * delta < surface + 3.0:
				global_position.y = surface + 3.0 # bob at the surface
				velocity.y = 0.0
	else:
		var g := Constants.gravity * (0.15 if in_water else 1.0)
		velocity.y = minf(velocity.y + g * delta, (4.0 if in_water else 40.0) * Constants.BLOCK_SIZE)
	velocity.x = move_toward(velocity.x, 0.0, (16.0 if in_water else 6.0) * Constants.BLOCK_SIZE * delta)
	if in_water:
		velocity += World.current_at(global_position) * delta * 4.0 # currents carry items (WS-16)
	# Mined-drop magnet: once grabbable, fly straight to a player in range
	# (solid checks below still stop it at walls).
	if magnet and pickup_delay <= 0.0:
		for p in get_tree().get_nodes_in_group("player"):
			var to: Vector2 = p.global_position - global_position
			if to.length() <= Constants.ITEM_MAGNET_RADIUS_BLOCKS * Constants.BLOCK_SIZE:
				if gentle:
					# Ease toward the player - a soft drift that ramps up (user request).
					var target := to.normalized() * Constants.ITEM_MAGNET_GENTLE_SPEED
					velocity = velocity.move_toward(target, Constants.ITEM_MAGNET_GENTLE_ACCEL * delta)
				else:
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
	# Gentle hover so a dropped resource reads as "come collect me" (user
	# request 2026-09-02) - a visual sprite offset only, so pickup range is
	# unaffected. Only while resting, so it doesn't fight a pop or a fall.
	if absf(velocity.x) < 2.0 and absf(velocity.y) < 2.0:
		_bob_t += delta
		sprite.position.y = -2.0 + sin(_bob_t * 4.0) * 1.5
	else:
		_bob_t = 0.0
		sprite.position.y = 0.0
	if pickup_delay <= 0.0:
		_try_pickup()

## Drop out of the net-id map when freed (pickup, scene change, replica remove).
func _exit_tree() -> void:
	var w := get_node_or_null("/root/World")
	if w != null and net_id != 0 and w.item_by_net_id.get(net_id) == self:
		w.item_by_net_id.erase(net_id)

func _try_pickup() -> void:
	if Net.is_client():
		return # the host picks up for every player and replicates the removal
	var radius := Constants.PICKUP_RADIUS_BLOCKS * Constants.BLOCK_SIZE
	for p in get_tree().get_nodes_in_group("player"):
		if p.global_position.distance_to(global_position) <= radius:
			var leftover: int = p.inventory.add(id, count)
			p.notify_gain(id, count - leftover)
			if leftover < count:
				count = leftover
				if count <= 0:
					Net.on_item_removed(self, p)
					queue_free()
			return
