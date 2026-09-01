class_name Enemy
extends CharacterBody2D
## One data-driven enemy body (M4). Behaviour comes from data/enemies.json:
## `mode` picks the movement brain (ground walkers/crawlers, surface
## floaters, swimming Drowned/sharks, passive fish), per-band stats come
## resolved on the backing World record. AI is deliberately physical (GD-04):
## walk toward the target, fall off ledges, squeeze what the hitbox fits,
## hop small steps, and pound player-placed blocks/doors when blocked —
## no pathfinding, no climbing. All targeting goes through Aggro (GD-06).
## Nodes are a windowed view of World.enemy_records, like objects: position
## and hp bank onto the record every tick, so streaming out loses nothing.

const SPRITE_DIR := "res://assets/sprites/enemies/"

var rec: Dictionary   # backing record {type, pos, hp, band, stats, ...}
var def: Dictionary   # type def from Data.enemies
var stats: Dictionary # {hp, damage, speed, aggro} — already band/wave-scaled
var target: Node2D = null
var attack_cd := 0.0
var pound_cd := 0.0
var wander_x := 0.0            # ground/surface idle direction
var swim_dir := Vector2.RIGHT  # swim/fish idle direction
var wander_timer := 0.0
var facing := 1
var _flash := 0.0
var half: Vector2

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D

func setup(p_rec: Dictionary) -> void:
	rec = p_rec
	def = Data.enemies[rec.type]
	stats = rec.stats
	global_position = rec.pos

func _ready() -> void:
	# Fish are catchable ambience, not weapon targets (GD-09: hands only).
	add_to_group("fish_schools" if def.get("mode", "") == "fish" else "enemies")
	var body := RectangleShape2D.new()
	half = Vector2(def.size[0], def.size[1]) * 0.5
	body.size = Vector2(def.size[0], def.size[1])
	shape.shape = body
	var path := SPRITE_DIR + String(rec.type) + ".png"
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	# Enemies never body-block players (contact damage is a check, not a
	# collision); they still collide with the world tiles.
	for p in get_tree().get_nodes_in_group("player"):
		add_collision_exception_with(p)

func _physics_process(delta: float) -> void:
	attack_cd = maxf(attack_cd - delta, 0.0)
	pound_cd = maxf(pound_cd - delta, 0.0)
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		sprite.modulate = Color(1, 0.4, 0.4) if _flash > 0.0 else Color.WHITE
	match def.get("mode", "ground"):
		"ground":
			_move_ground(delta)
		"surface":
			_move_surface(delta)
		"swim":
			_move_swim(delta)
		"fish":
			_move_fish(delta)
	if not def.get("passive", false):
		_try_touch()
	if absf(velocity.x) > 1.0:
		facing = 1 if velocity.x > 0.0 else -1
	sprite.flip_h = facing < 0
	# Bank live position so streaming out / saving mid-chase loses nothing
	# (hp banks in hurt()).
	rec.pos = global_position

# --- Targeting (single shared sense, GD-06) ---

func _update_target() -> void:
	if target != null:
		if not is_instance_valid(target) \
				or target.global_position.distance_to(global_position) > float(stats.aggro) * 2.5 * Constants.BLOCK_SIZE:
			target = null # leashed: far enough away, interest fades
		else:
			return
	target = Aggro.acquire(get_tree(), global_position, float(stats.aggro))

## Idle wander: drift a while, stand a while (direction re-rolled on a timer).
func _tick_wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		wander_x = [-1.0, 0.0, 0.0, 1.0][randi() % 4]
		swim_dir = Vector2.from_angle(randf() * TAU)

# --- Ground (walker, crawler; GD-04) ---

func _move_ground(delta: float) -> void:
	_update_target()
	_tick_wander(delta)
	var in_water := World.is_water(global_position)
	var speed: float = float(stats.speed) * Constants.BLOCK_SIZE * (0.4 if in_water else 1.0)
	var dir := 0.0
	if target != null:
		var dx := target.global_position.x - global_position.x
		if absf(dx) > 4.0:
			dir = signf(dx)
	else:
		dir = wander_x
		speed *= Constants.ENEMY_WANDER_SPEED
	velocity.x = move_toward(velocity.x, dir * speed, 30.0 * Constants.BLOCK_SIZE * delta)
	velocity.y = minf(velocity.y + Constants.gravity * (0.3 if in_water else 1.0) * delta,
		Constants.MAX_FALL_SPEED)
	move_and_slide()
	if dir != 0.0 and is_on_wall():
		_handle_block(dir)

## Blocked mid-walk: pound the obstacle if a player placed it (blocks and
## closed doors only — building structure is safe from zombies), otherwise
## hop a small step. Neither working, the walk just stalls until the wander
## rolls a new direction.
func _handle_block(dir: float) -> void:
	var fx := global_position.x + dir * (half.x + 3.0)
	for row in ceili(half.y * 2.0 / Constants.BLOCK_SIZE) + 1:
		var cell := World.cell_at(Vector2(fx, global_position.y + half.y - 2.0 - row * Constants.BLOCK_SIZE))
		if World.pound_target(cell):
			if pound_cd <= 0.0:
				pound_cd = Constants.ENEMY_POUND_INTERVAL
				World.pound(cell, Constants.ENEMY_POUND_DAMAGE)
				Audio.play_sfx("wood_hit", World.cell_center(cell), 2, -4.0)
			return
	if is_on_floor():
		velocity.y = -sqrt(2.0 * Constants.gravity * Constants.ENEMY_HOP_BLOCKS * Constants.BLOCK_SIZE)

# --- Surface drifter (floater; GD-05/29) ---

func _move_surface(delta: float) -> void:
	_update_target()
	_tick_wander(delta)
	var speed: float = float(stats.speed) * Constants.BLOCK_SIZE
	if World.is_water(global_position + Vector2(0, half.y)):
		# Bob at the surface like flotsam, body half sunk.
		var surface := World.water_surface_y(global_position)
		velocity.y = (surface + 2.0 - global_position.y) * 6.0
		var dir := 0.0
		if target != null:
			dir = signf(target.global_position.x - global_position.x)
		else:
			dir = wander_x
			speed *= Constants.ENEMY_WANDER_SPEED
		velocity.x = move_toward(velocity.x, dir * speed, 8.0 * Constants.BLOCK_SIZE * delta)
	else: # stranded dry: a bloated body barely shuffles
		velocity.x = move_toward(velocity.x, wander_x * speed * 0.2, 8.0 * Constants.BLOCK_SIZE * delta)
		velocity.y = minf(velocity.y + Constants.gravity * delta, Constants.MAX_FALL_SPEED)
	move_and_slide()

# --- Swimmers (the Drowned, sharks; GD-11..14) ---

func _move_swim(delta: float) -> void:
	if not World.is_water(global_position):
		# Drained on them: flop, harmless-ish, until water returns.
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * Constants.BLOCK_SIZE * delta)
		velocity.y = minf(velocity.y + Constants.gravity * delta, Constants.MAX_FALL_SPEED)
		move_and_slide()
		return
	_update_target()
	_tick_wander(delta)
	var speed: float = float(stats.speed) * Constants.BLOCK_SIZE
	var desired := Vector2.ZERO
	if target != null:
		desired = (target.global_position - global_position).normalized() * speed
	elif def.get("open_water", false):
		# Shark patrol: level cruising, flipping at walls and building edges.
		swim_dir = Vector2(signf(swim_dir.x) if swim_dir.x != 0.0 else 1.0, 0.0)
		if not _swimmable(global_position + swim_dir * (half.x + Constants.BLOCK_SIZE * 2.0)):
			swim_dir.x = -swim_dir.x
		desired = swim_dir * speed * 0.45
	else:
		desired = swim_dir * speed * Constants.ENEMY_WANDER_SPEED
	velocity = velocity.move_toward(desired, 20.0 * Constants.BLOCK_SIZE * delta)
	# Never leave the water (per axis, so they glide along the surface).
	var next := global_position + velocity * delta
	if not _swimmable(Vector2(next.x, global_position.y)):
		velocity.x = 0.0
	if not _swimmable(Vector2(global_position.x, next.y)):
		velocity.y = 0.0
	move_and_slide()

## Water this swimmer may occupy: sharks refuse interiors (back-wall cells) —
## open-water hunters only (GD-11); the Drowned go anywhere flooded.
func _swimmable(pos: Vector2) -> bool:
	if not World.is_water(pos):
		return false
	return not (def.get("open_water", false) and World.has_back_wall_cell(World.cell_at(pos)))

# --- Fish school (GD-09/28): ambience and food, caught by hand ---

func _move_fish(delta: float) -> void:
	_tick_wander(delta)
	var speed: float = float(stats.speed) * Constants.BLOCK_SIZE * 0.5
	velocity = velocity.move_toward(swim_dir * speed, 6.0 * Constants.BLOCK_SIZE * delta)
	var next := global_position + velocity * delta
	if not World.is_water(next):
		swim_dir = -swim_dir
		velocity = Vector2.ZERO
	move_and_slide()

## Hand-grab (GD-09): swim close + interact takes one fish from the school.
func catch_fish(player) -> bool:
	if player.global_position.distance_to(global_position) > Constants.FISH_GRAB_BLOCKS * Constants.BLOCK_SIZE:
		return false
	player.inventory.add("fish_meat", 1)
	rec.stock = int(rec.get("stock", 1)) - 1
	Audio.play_sfx("splash", global_position, 5, -12.0)
	if rec.stock <= 0:
		World.remove_enemy(rec)
	return true

# --- Contact damage ---

func _try_touch() -> void:
	if attack_cd > 0.0:
		return
	for p in get_tree().get_nodes_in_group("player"):
		var d: Vector2 = (p.global_position - global_position).abs()
		if d.x < half.x + 7.0 and d.y < half.y + 12.0:
			attack_cd = Constants.ENEMY_TOUCH_COOLDOWN
			p.hurt_from_enemy(float(stats.damage), global_position, def.get("bleeds", false))
			return

# --- Damage in ---

func hurt(damage: float, from_pos: Vector2, knockback: float = 0.0) -> void:
	rec.hp = float(rec.hp) - damage
	_flash = 0.12
	sprite.modulate = Color(1, 0.4, 0.4)
	if knockback > 0.0:
		var dir := (global_position - from_pos).normalized()
		velocity += Vector2(dir.x, minf(dir.y, 0.0) - 0.4).normalized() * knockback * Constants.BLOCK_SIZE
	# Pain overrides the radius: whoever is closest gets the attention.
	if target == null and not def.get("passive", false):
		target = Aggro.acquire(get_tree(), global_position, float(stats.aggro) * 3.0)
	if rec.hp <= 0.0:
		_die()

func _die() -> void:
	# Light drops only (GD-24): cloth/scrap bits, meat from fish.
	for drop in def.get("drops", []):
		if randf() <= float(drop.get("chance", 1.0)):
			var n := randi_range(int(drop.min), int(drop.max))
			if n > 0:
				World.spawn_item(drop.item, n, global_position,
					Vector2(randf_range(-1.5, 1.5), -2.0) * Constants.BLOCK_SIZE)
	Audio.play_sfx("dismantle_rattle", global_position, 1, -10.0)
	World.remove_enemy(rec)
