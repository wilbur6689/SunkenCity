class_name Backpack
extends Node2D
## The death backpack (CC-07): everything from the bag transfers here when
## the player dies (worn gear stays on the body). Physics mirrors buoyant
## WorldItems — unobstructed packs float up and bob at the surface, packs
## under a flooded ceiling pin against it. Touch it to take everything back;
## whatever doesn't fit stays in the pack.

var slots: Array = [] # inventory stack dicts (mods intact, LT-05..07)
var velocity: Vector2 = Vector2.ZERO
var pickup_delay: float = Constants.BACKPACK_PICKUP_DELAY

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("backpacks")
	var path := "res://assets/sprites/backpack.png"
	if ResourceLoader.exists(path):
		sprite.texture = load(path)

func _physics_process(delta: float) -> void:
	pickup_delay = maxf(pickup_delay - delta, 0.0)
	var in_water := World.is_water(global_position)
	if in_water:
		# Buoyant (M2 physics): rise, pin to ceilings, bob at the surface.
		if World.is_solid(global_position + Vector2(0, -7.0)):
			velocity = Vector2.ZERO
			var cell := World.cell_at(global_position + Vector2(0, -7.0))
			global_position.y = (cell.y + 1) * Constants.BLOCK_SIZE + 6.0
		else:
			velocity.y = move_toward(velocity.y, -Constants.ITEM_BUOYANCY_RISE, 6.0 * Constants.BLOCK_SIZE * delta)
			var surface := World.water_surface_y(global_position)
			if global_position.y + velocity.y * delta < surface + 4.0:
				global_position.y = surface + 4.0
				velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + Constants.gravity * delta, 20.0 * Constants.BLOCK_SIZE)
	velocity.x = move_toward(velocity.x, 0.0, (8.0 if in_water else 3.0) * Constants.BLOCK_SIZE * delta)
	var next := global_position + velocity * delta
	if velocity.y > 0.0 and World.is_solid(next + Vector2(0, 5)):
		next.y = World.cell_top_y(World.cell_at(next + Vector2(0, 5))) - 5.0
		velocity.y = 0.0
	if velocity.x != 0.0 and World.is_solid(next):
		next.x = global_position.x
		velocity.x = 0.0
	global_position = next
	if pickup_delay <= 0.0:
		_try_recover()

## Recover-on-touch: stacks go back whole (mods intact); leftovers stay.
func _try_recover() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if p.global_position.distance_to(global_position) > 1.5 * Constants.BLOCK_SIZE:
			continue
		var kept: Array = []
		for s in slots:
			if s == null:
				continue
			if s.has("mods"):
				if not p.inventory.add_stack(s):
					kept.append(s)
			else:
				var leftover: int = p.inventory.add(s.id, int(s.count))
				if leftover > 0:
					kept.append({"id": s.id, "count": leftover})
		slots = kept
		if kept.is_empty():
			p.message.emit("Backpack recovered")
			queue_free()
		else:
			p.message.emit("Backpack too full to take everything")
			pickup_delay = 2.0
		return
