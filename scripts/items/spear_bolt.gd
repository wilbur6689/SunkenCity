class_name SpearBolt
extends Node2D
## A projectile in flight (GD-08, LT-16; generalised for bows, crossbows,
## nail/rivet guns and harpoon guns 2026-09-05): flies straight with a share
## of gravity in air (none underwater), hits the first enemy or wall, then —
## when its ammo is `retrievable` — drops as a pickup right there, so spent
## ammo is only lost if you can't get to it. Nails and rivets simply vanish.
##
## The ammo item's optional `projectile` block: {speed (blocks/s), gravity
## (share of world gravity in air), retrievable (bool)}.
##
## LAN (Step 6): the real bolt only ever flies on the host (combat runs
## there from the relayed input). Clients get a `visual` twin via
## EnemySync._bolt that flies the same path, never damages and never drops.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var knockback: float = 4.0
var item_id: String = "speargun_bolt"
var travelled: float = 0.0
var visual: bool = false   # client twin: no hit, no drop
var gravity_share: float = Constants.PROJECTILE_GRAVITY
var retrievable: bool = true
var _announced := false

func setup(p_item: String, p_velocity: Vector2, p_damage: float) -> void:
	item_id = p_item
	velocity = p_velocity
	damage = p_damage
	var pdef: Dictionary = Data.item(item_id).get("projectile", {})
	gravity_share = float(pdef.get("gravity", Constants.PROJECTILE_GRAVITY))
	retrievable = bool(pdef.get("retrievable", true))

func _ready() -> void:
	if Net.is_client():
		visual = true
	var s := Sprite2D.new()
	s.texture = Data.icon(item_id)
	if s.texture != null and s.texture.get_width() > Data.ICON_PX:
		s.scale = Vector2.ONE * (float(Data.ICON_PX) / s.texture.get_width())
	add_child(s)
	rotation = velocity.angle()

func _physics_process(delta: float) -> void:
	if not _announced:
		# The muzzle position is set after add_child, so the twin is announced
		# on the first tick rather than in _ready.
		_announced = true
		if not visual and Net.mode == Net.Mode.HOST and Net.enemy_sync != null \
				and Net.enemy_sync.has_method("on_bolt_fired"):
			Net.enemy_sync.on_bolt_fired(item_id, global_position, velocity)
	if not World.is_water(global_position):
		velocity.y += Constants.gravity * gravity_share * delta # dry arc; true underwater
	rotation = velocity.angle()
	var step := velocity * delta
	travelled += step.length()
	var next := global_position + step
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		var to := e.global_position - global_position
		if to.length() < e.half.length() + 5.0:
			if not visual:
				e.hurt(damage, global_position - velocity.normalized() * 8.0, knockback)
			_drop()
			return
	if World.is_solid(next) or travelled > Constants.SPEAR_RANGE_BLOCKS * Constants.BLOCK_SIZE:
		_drop()
		return
	global_position = next

func _drop() -> void:
	if not visual and retrievable:
		World.spawn_item(item_id, 1, global_position) # the host's item spawn replicates on its own
	queue_free()
