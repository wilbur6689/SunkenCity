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
## LAN Step 6: on a client every enemy node is a puppet — no brain, no
## touch, no pound, no damage; it only eases toward the host's streamed
## position (`net_pos`) and animates. Hurt/death visuals arrive as events.
var puppet := false
var net_pos: Vector2 = Vector2.ZERO
var net_moving := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D

func setup(p_rec: Dictionary) -> void:
	rec = p_rec
	def = Data.enemies[rec.type]
	stats = rec.stats
	global_position = rec.pos
	puppet = Net.is_client()
	net_pos = rec.pos

func _ready() -> void:
	# Fish are catchable ambience, not weapon targets (GD-09: hands only).
	add_to_group("fish_schools" if def.get("mode", "") == "fish" else "enemies")
	var body := RectangleShape2D.new()
	half = Vector2(def.size[0], def.size[1]) * 0.5
	body.size = Vector2(def.size[0], def.size[1])
	shape.shape = body
	# Hand-made sheets (user request 2026-09-01): types with `frames` load a
	# horizontal walk strip; `sprite_variants` picks a look per individual
	# (deterministic from the record's seed position, so it survives
	# streaming). Variant files are <type>_b.png, _c.png...
	var variant := ""
	var vcount := int(def.get("sprite_variants", 1))
	if vcount > 1:
		var pick := absi(int(rec.pos.x) + int(rec.pos.y)) % vcount
		if pick > 0:
			variant = "_" + char(97 + pick) # _b, _c...
	var path := SPRITE_DIR + String(rec.type) + variant + ".png"
	if not FileAccess.file_exists(path):
		path = SPRITE_DIR + String(rec.type) + ".png"
	var tex := _load_strip(path)
	if tex != null:
		walk_tex = tex
		_set_strip(tex) # also stands the art on the hitbox bottom (foot alignment)
		# Optional clips beside the walk strip (urban pack, 2026-09-01):
		# <strip>_idle / _attack / _hurt / _dead play when present.
		var base := path.trim_suffix(".png")
		for anim in ["idle", "attack", "hurt", "dead"]:
			var at := _load_strip(base + "_" + anim + ".png")
			if at != null:
				anim_tex[anim] = at
	if def.has("stealth"): # hard to see against the night sky (T0 glasswing bat)
		sprite.modulate = Color(1, 1, 1, 1.0 - float(def.stealth))
	# Enemies never body-block players (contact damage is a check, not a
	# collision); they still collide with the world tiles.
	for p in get_tree().get_nodes_in_group("player"):
		add_collision_exception_with(p)

func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_tick(delta)
		return
	attack_cd = maxf(attack_cd - delta, 0.0)
	shot_cd = maxf(shot_cd - delta, 0.0)
	pound_cd = maxf(pound_cd - delta, 0.0)
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		sprite.modulate = Color(1, 0.4, 0.4) if _flash > 0.0 else Color(1, 1, 1, 1.0 - float(def.get("stealth", 0.0)))
	match def.get("mode", "ground"):
		"ground":
			_move_ground(delta)
		"surface":
			_move_surface(delta)
		"swim":
			_move_swim(delta)
		"fly":
			_move_fly(delta)
		"fish":
			_move_fish(delta)
	if not def.get("passive", false):
		_try_touch()
		if def.get("ranged", false):
			_try_shoot()
	if absf(velocity.x) > 1.0:
		facing = 1 if velocity.x > 0.0 else -1
	sprite.flip_h = facing < 0
	_tick_anim(delta)
	# Bank live position so streaming out / saving mid-chase loses nothing
	# (hp banks in hurt()).
	rec.pos = global_position

# --- Puppet (client replica, LAN Step 6) ---

## Ease toward the streamed position (snap when far — a teleport or a
## window re-entry), fake a velocity so the walk/idle clips still read,
## bank the position on the record like the host does.
func _puppet_tick(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		sprite.modulate = Color(1, 0.4, 0.4) if _flash > 0.0 else Color(1, 1, 1, 1.0 - float(def.get("stealth", 0.0)))
	var prev := global_position
	if prev.distance_to(net_pos) > Constants.NET_ENEMY_SNAP_BLOCKS * Constants.BLOCK_SIZE:
		global_position = net_pos
	else:
		global_position = prev.lerp(net_pos, 1.0 - exp(-Constants.NET_ENEMY_EASE * delta))
	velocity = (global_position - prev) / maxf(delta, 0.0001) if net_moving else Vector2.ZERO
	if net_moving and velocity.length() < 8.0:
		velocity = Vector2(facing * 8.0, 0.0) # streamed "moving" but eased to rest: keep the walk cycle
	sprite.flip_h = facing < 0
	_tick_anim(delta)
	rec.pos = global_position

## One streamed sample from EnemySync: target pos, hp (the health bar), facing, walk flag.
func puppet_state(pos: Vector2, hp: float, p_facing: int, moving: bool) -> void:
	net_pos = pos
	net_moving = moving
	if p_facing != 0:
		facing = p_facing
	if not is_equal_approx(float(rec.hp), hp):
		rec.hp = hp
		queue_redraw()

## A reliable one-shot from the host: "hurt" / "died" / "anim:<clip>".
func puppet_event(event: String) -> void:
	match event:
		"hurt":
			_flash = 0.12
			queue_redraw()
			if sprite != null:
				sprite.modulate = Color(1, 0.4, 0.4)
				if _oneshot != "attack":
					_play_oneshot("hurt", 0.3)
		"died":
			Audio.play_sfx("dismantle_rattle", global_position, 1, -10.0)
			_spawn_corpse()
		_:
			if event.begins_with("anim:"):
				_play_oneshot(event.substr(5), 0.5)

## Animation clips (2026-09-01): the walk strip drives movement, an idle
## clip sways while standing, attack/hurt clips one-shot over the action,
## and a dead clip lingers as a corpse. Frame counts derive from square
## cells (width / height); legacy non-square strips fall back to
## def.frames.
var _anim_t := 0.0
var walk_tex: Texture2D = null
var anim_tex: Dictionary = {}
var _oneshot := ""
var _oneshot_t := 0.0
var _oneshot_dur := 0.3

func _frames_of(tex: Texture2D) -> int:
	var h := tex.get_height()
	if h > 0 and tex.get_width() % h == 0:
		return maxi(tex.get_width() / h, 1)
	return maxi(int(def.get("frames", 1)), 1)

## Foot alignment (user report 2026-09-06 "monsters clipped into the floor"):
## a strip's cell is usually taller than the hitbox - the square-cell fauna
## draw a 6 px rat near the bottom of a 16 px cell, a 4 px snake at the foot
## of a 24 px one, and the hand-made 26 px walker strips carry a 22 px box -
## so a Sprite2D centred on the hitbox painted the visible feet 2-9 px below
## the hitbox bottom, i.e. inside the floor slab. Standing bodies (ground /
## surface modes) now shift the sprite so the art's lowest opaque row rests
## on the hitbox bottom (the Monster Editor's overlay contract); swimmers
## and fliers stay centred, their hitbox IS the body. Measured once per
## strip file and cached by path; per node, per texture for the clip swaps.
static var _art_bottom_cache: Dictionary = {} # path -> lowest opaque row's bottom edge, px below the cell centre
var _tex_foot: Dictionary = {}                 # Texture2D -> sprite.offset.y for that strip

func _stands() -> bool:
	return def.get("mode", "ground") in ["ground", "surface"]

static func _art_bottom_of(path: String, tex: Texture2D) -> float:
	if _art_bottom_cache.has(path):
		return float(_art_bottom_cache[path])
	var below := tex.get_height() * 0.5 # fallback: the cell bottom
	var img := tex.get_image()
	if img != null:
		var used := img.get_used_rect()
		if used.size.y > 0:
			below = float(used.end.y) - tex.get_height() * 0.5
	_art_bottom_cache[path] = below
	return below

## A strip texture, honouring the authored-sprites raw-load rule; remembers
## the foot offset that stands its art on the hitbox bottom.
func _load_strip(path: String) -> Texture2D:
	var tex := Data.load_texture_fresh(path, def.get("authored_sprites", false))
	if tex != null:
		_tex_foot[tex] = (half.y - _art_bottom_of(path, tex)) if _stands() else 0.0
	return tex

func _set_strip(tex: Texture2D) -> void:
	if sprite.texture != tex:
		sprite.texture = tex
		sprite.hframes = _frames_of(tex)
		sprite.frame = 0
		sprite.offset.y = float(_tex_foot.get(tex, 0.0))

func _play_oneshot(anim: String, dur: float) -> void:
	if not anim_tex.has(anim):
		return
	_set_strip(anim_tex[anim])
	_oneshot = anim
	_oneshot_t = 0.0
	_oneshot_dur = dur

func _tick_anim(delta: float) -> void:
	if walk_tex == null:
		return
	if _oneshot != "":
		_oneshot_t += delta
		var tex: Texture2D = anim_tex[_oneshot]
		var n := _frames_of(tex)
		var idx := int(_oneshot_t / _oneshot_dur * n)
		if idx < n:
			sprite.frame = idx
			return
		_oneshot = ""
		_set_strip(walk_tex)
	var moving := velocity.length() > 6.0
	if moving:
		_set_strip(walk_tex)
		if sprite.hframes > 1:
			_anim_t += delta * clampf(velocity.length() / Constants.BLOCK_SIZE, 3.0, 10.0)
			sprite.frame = int(_anim_t) % sprite.hframes
	elif anim_tex.has("idle"):
		_set_strip(anim_tex["idle"])
		_anim_t += delta * 5.0
		sprite.frame = int(_anim_t) % maxi(sprite.hframes, 1)
	else:
		sprite.frame = 0

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
	if def.get("ambush", false) and target == null: # lies still until something comes close (T0 leech / mantis / snake)
		wander_x = 0.0
		swim_dir = Vector2.ZERO

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
	# Edge sense (amends GD-04, user request 2026-08-31): never walk off a
	# ledge — a chaser holds the edge, a wanderer turns around. (Gap jumping
	# was tried and dropped for now, same request.)
	if dir != 0.0 and is_on_floor() and _edge_ahead(dir):
		if target == null:
			wander_x = -wander_x
		dir = 0.0
	velocity.x = move_toward(velocity.x, dir * speed, 60.0 * Constants.BLOCK_SIZE * delta)
	velocity.y = minf(velocity.y + Constants.gravity * (0.3 if in_water else 1.0) * delta,
		Constants.MAX_FALL_SPEED)
	if in_water and velocity.y > Constants.WATER_SINK_LIMIT:
		# plunge drag (user report 2026-09-01): a zombie knocked off a roof
		# brakes within a few blocks of the surface too
		velocity.y = move_toward(velocity.y, Constants.WATER_SINK_LIMIT, Constants.WATER_PLUNGE_DECEL * delta)
	move_and_slide()
	if dir != 0.0 and is_on_wall():
		_handle_block(dir)

## True when the floor ends just ahead: nothing solid within a step-down
## (2 cells) below the cell in front of the leading foot.
func _edge_ahead(dir: float) -> bool:
	var front := global_position.x + dir * (half.x + 3.0)
	var feet_y := global_position.y + half.y
	for drop in 4:
		if World.is_solid_cell(World.cell_at(Vector2(front, feet_y + 2.0 + drop * Constants.BLOCK_SIZE))):
			return false
	return true

## Blocked mid-walk: pound the obstacle if a player placed it (blocks and
## closed doors only — building structure is safe from zombies), otherwise
## hop a small step. Neither working, the walk just stalls until the wander
## rolls a new direction.
func _handle_block(dir: float) -> void:
	var fx := global_position.x + dir * (half.x + 3.0)
	for row in ceili(half.y * 2.0 / Constants.BLOCK_SIZE) + 1:
		var cell := World.cell_at(Vector2(fx, global_position.y + half.y - 2.0 - row * Constants.BLOCK_SIZE))
		if World.pound_target(cell) and def.get("pounds", true): # T0 prowlers never breach a house
			if pound_cd <= 0.0:
				pound_cd = Constants.ENEMY_POUND_INTERVAL
				World.pound(cell, Constants.ENEMY_POUND_DAMAGE)
				Audio.play_world_sfx("wood_hit", World.cell_center(cell), 2, -4.0)
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
		velocity.x = move_toward(velocity.x, dir * speed, 16.0 * Constants.BLOCK_SIZE * delta)
	else: # stranded dry: a bloated body barely shuffles
		velocity.x = move_toward(velocity.x, wander_x * speed * 0.2, 16.0 * Constants.BLOCK_SIZE * delta)
		velocity.y = minf(velocity.y + Constants.gravity * delta, Constants.MAX_FALL_SPEED)
	move_and_slide()

# --- Swimmers (the Drowned, sharks; GD-11..14) ---

func _move_swim(delta: float) -> void:
	if not World.is_water(global_position):
		# Drained on them: flop, harmless-ish, until water returns.
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * Constants.BLOCK_SIZE * delta)
		velocity.y = minf(velocity.y + Constants.gravity * delta, Constants.MAX_FALL_SPEED)
		move_and_slide()
		return
	_update_target()
	_tick_wander(delta)
	var speed: float = float(stats.speed) * Constants.BLOCK_SIZE
	if velocity.length() > speed: # plunge drag: entry momentum bleeds off fast
		velocity = velocity.move_toward(velocity.normalized() * speed, Constants.WATER_PLUNGE_DECEL * delta)
	var desired := Vector2.ZERO
	if def.get("stationary", false):
		pass # barnacle colonies and urchins stay where they grew
	elif target != null:
		desired = (target.global_position - global_position).normalized() * speed
	elif def.get("open_water", false):
		# Shark patrol: level cruising, flipping at walls and building edges.
		swim_dir = Vector2(signf(swim_dir.x) if swim_dir.x != 0.0 else 1.0, 0.0)
		if not _swimmable(global_position + swim_dir * (half.x + Constants.BLOCK_SIZE * 4.0)):
			swim_dir.x = -swim_dir.x
		desired = swim_dir * speed * 0.45
	else:
		desired = swim_dir * speed * Constants.ENEMY_WANDER_SPEED
	velocity = velocity.move_toward(desired, 40.0 * Constants.BLOCK_SIZE * delta)
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

# --- Fliers (T0 rooftop bats, crows, pigeons; 2026-09-06) ---

## Air is their water: they glide toward a target (aiming a little above its
## centre), bob about on the wander direction otherwise, and turn away from
## solids and the water surface. No gravity, no ground contact.
func _move_fly(delta: float) -> void:
	_update_target()
	_tick_wander(delta)
	var speed: float = float(stats.speed) * Constants.BLOCK_SIZE
	var desired := Vector2.ZERO
	if target != null:
		desired = (target.global_position + Vector2(0, -6.0) - global_position).normalized() * speed
	else:
		var bob := Vector2(0, sin(Time.get_ticks_msec() * 0.004 + global_position.x) * 0.3)
		desired = (swim_dir + bob) * speed * Constants.ENEMY_WANDER_SPEED
	velocity = velocity.move_toward(desired, 30.0 * Constants.BLOCK_SIZE * delta)
	var next := global_position + velocity * delta
	if not _flyable(Vector2(next.x, global_position.y)):
		velocity.x = 0.0
		swim_dir.x = -swim_dir.x
	if not _flyable(Vector2(global_position.x, next.y)):
		velocity.y = 0.0
		swim_dir.y = -swim_dir.y
	move_and_slide()

func _flyable(pos: Vector2) -> bool:
	return not World.is_solid(pos) and not World.is_water(pos)

# --- Fish school (GD-09/28): ambience and food, caught by hand ---

func _move_fish(delta: float) -> void:
	_tick_wander(delta)
	var speed: float = float(stats.speed) * Constants.BLOCK_SIZE * 0.5
	velocity = velocity.move_toward(swim_dir * speed, 12.0 * Constants.BLOCK_SIZE * delta)
	var next := global_position + velocity * delta
	if not World.is_water(next):
		swim_dir = -swim_dir
		velocity = Vector2.ZERO
	move_and_slide()

## Hand-grab (GD-09): swim close + interact takes one fish from the school.
func catch_fish(player) -> bool:
	if puppet: # the host's copy takes the fish; the replica only mirrors
		return false
	if player.global_position.distance_to(global_position) > Constants.FISH_GRAB_BLOCKS * Constants.BLOCK_SIZE:
		return false
	player.inventory.add("fish_meat", 1)
	rec.stock = int(rec.get("stock", 1)) - 1
	Audio.play_world_sfx("splash", global_position, 5, -12.0)
	if rec.stock <= 0:
		World.remove_enemy(rec)
	return true

# --- Ranged attack (Bestiary Grid T2: barnacle / urchin spines, squid ink,
# jellyfish sting, lionfish spines; 2026-09-06) ---

## A spit at any player within `range_blocks` with a clear line of sight:
## instant hit (a tracer draws the shot), ENEMY_SHOT_COOLDOWN between shots,
## damage = the type's stat. Stationary shooters never move, so this is their
## whole game; swimmers shoot while closing in.
func _try_shoot() -> void:
	if shot_cd > 0.0:
		return
	var reach := float(def.get("range_blocks", 3.0)) * Constants.BLOCK_SIZE
	for p in get_tree().get_nodes_in_group("player"):
		var to: Vector2 = p.global_position - global_position
		if to.length() > reach or to.length() < Constants.BLOCK_SIZE * 1.5:
			continue
		if World.sight_transmission(global_position, World.cell_at(p.global_position)) <= 0.05:
			continue # a wall or door between them
		shot_cd = Constants.ENEMY_SHOT_COOLDOWN
		attack_cd = maxf(attack_cd, 0.3)
		_play_oneshot("attack", 0.35)
		World.spawn_tracer(global_position, p.global_position)
		p.hurt_from_enemy(float(stats.damage), global_position, def.get("bleeds", false))
		Audio.play_world_sfx("splash", global_position, 4, -10.0)
		if def.has("lifesteal"):
			rec.hp = minf(float(rec.hp) + float(stats.damage) * float(def.lifesteal), float(stats.hp))
		return

var shot_cd := 0.0

# --- Contact damage ---

## Contact bite + a forward swipe (user request 2026-09-01): overlap-only
## contact read as "same square" - the bite now also lands up to
## ENEMY_ATTACK_REACH_BLOCKS in front of the facing direction, but never
## through a solid cell (a closed door still shields).
func _try_touch() -> void:
	if attack_cd > 0.0:
		return
	var reach := Constants.ENEMY_ATTACK_REACH_BLOCKS * Constants.BLOCK_SIZE
	for p in get_tree().get_nodes_in_group("player"):
		var to: Vector2 = p.global_position - global_position
		var d := to.abs()
		if d.y >= half.y + 12.0:
			continue
		var touching: bool = d.x < half.x + 7.0
		var in_front: bool = signf(to.x) == float(facing) and d.x < half.x + reach 				and not World.is_solid(global_position + Vector2(facing * (half.x + Constants.BLOCK_SIZE * 1.0), 0.0))
		if touching or in_front:
			attack_cd = Constants.ENEMY_TOUCH_COOLDOWN
			_play_oneshot("attack", 0.5) # the bite reads on the body (2026-09-01)
			Net.on_enemy_event(rec, "anim:attack") # puppets play the bite too
			p.hurt_from_enemy(float(stats.damage), global_position, def.get("bleeds", false))
			if def.has("lifesteal"): # the boiler lamprey drinks what it bites
				rec.hp = minf(float(rec.hp) + float(stats.damage) * float(def.lifesteal), float(stats.hp))
			return

# --- Health bar (shows only once hurt) ---

const BAR_H := 2.0

## A sliver of a bar above the head while below full health — damage you've
## dealt stays readable across a fight (and across streaming, via rec.hp).
func _draw() -> void:
	var frac := clampf(float(rec.hp) / float(stats.hp), 0.0, 1.0)
	if frac >= 1.0:
		return
	var w := maxf(half.x * 2.0, 14.0)
	var top := Vector2(-w * 0.5, -half.y - 6.0)
	draw_rect(Rect2(top + Vector2(-1, -1), Vector2(w + 2, BAR_H + 2)), Color(0.05, 0.04, 0.04, 0.85))
	draw_rect(Rect2(top, Vector2(w * frac, BAR_H)),
		Color(0.85, 0.25, 0.2).lerp(Color(0.35, 0.8, 0.3), frac))

# --- Damage in ---

func hurt(damage: float, from_pos: Vector2, knockback: float = 0.0) -> void:
	if puppet: # damage is the host's call; the flash arrives as a "hurt" event
		return
	damage *= 1.0 - float(def.get("armor", 0.0)) # hard shells (T0 roach / statue pigeon)
	rec.hp = float(rec.hp) - damage
	# Hit feedback (user request 2026-09-06): green ichor flies off and a wet
	# crunch plays; both replicate to clients as effects.
	World.spawn_break_puff(global_position, "ichor")
	Audio.play_world_sfx("enemy_hit", global_position, 3, -4.0) # relayed to clients
	knockback *= 1.0 - float(def.get("knockback_resist", 0.0)) # concrete tortoise stands its ground
	# Gets meaner once hurt (dumpster raccoon), or below a health fraction (butcher dog: enrage_at 0.5).
	if def.has("enrage") and not rec.get("enraged", false) \
			and float(rec.hp) <= float(stats.hp) * float(def.get("enrage_at", 1.0)):
		rec["enraged"] = true
		stats = stats.duplicate()
		stats.damage = float(stats.damage) * (1.0 + float(def.enrage))
		stats.speed = float(stats.speed) * (1.0 + float(def.enrage) * 0.5)
	Net.on_enemy_event(rec, "hurt")
	queue_redraw()
	_flash = 0.12
	if sprite != null: # hurt can land the same frame the node spawns
		sprite.modulate = Color(1, 0.4, 0.4)
		if _oneshot != "attack": # a flinch, unless mid-bite
			_play_oneshot("hurt", 0.3)
	if knockback > 0.0:
		var dir := (global_position - from_pos).normalized()
		velocity += Vector2(dir.x, minf(dir.y, 0.0) - 0.4).normalized() * knockback * Constants.BLOCK_SIZE
	# Pain overrides the radius: whoever is closest gets the attention.
	if target == null and not def.get("passive", false) and is_inside_tree():
		target = Aggro.acquire(get_tree(), global_position, float(stats.aggro) * 3.0)
	if rec.hp <= 0.0:
		_die()

func _die() -> void:
	if puppet: # the host removes the record; the corpse comes with the "died" event
		return
	# Light drops only (GD-24): cloth/scrap bits, meat from fish.
	for drop in def.get("drops", []):
		if randf() <= float(drop.get("chance", 1.0)):
			var n := randi_range(int(drop.min), int(drop.max))
			if n > 0:
				World.spawn_item(drop.item, n, global_position,
					Vector2(randf_range(-3.0, 3.0), -4.0) * Constants.BLOCK_SIZE)
	Audio.play_sfx("dismantle_rattle", global_position, 1, -10.0)
	Net.on_enemy_event(rec, "died")
	_spawn_corpse()
	World.remove_enemy(rec)

## A lingering corpse playing the dead clip, then fading out (2026-09-01).
func _spawn_corpse() -> void:
	if not anim_tex.has("dead") or not is_inside_tree():
		return
	var c := Sprite2D.new()
	c.texture = anim_tex["dead"]
	c.hframes = _frames_of(anim_tex["dead"])
	c.flip_h = sprite.flip_h
	c.offset.y = float(_tex_foot.get(anim_tex["dead"], 0.0)) # the corpse lies on the floor, not in it
	get_parent().add_child(c)
	c.global_position = global_position
	var n := c.hframes
	var tw := c.create_tween()
	tw.tween_method(func(f): c.frame = clampi(int(f), 0, n - 1), 0.0, float(n), 0.7)
	tw.tween_interval(1.8)
	tw.tween_property(c, "modulate:a", 0.0, 0.8)
	tw.tween_callback(c.queue_free)
