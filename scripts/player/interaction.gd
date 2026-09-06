class_name Interaction
extends Node2D
## Aim-and-act layer for the player (WS-12 reach). Reads the player's input
## snapshot (aim point, use/secondary/interact) each physics tick and turns
## it into world mutations through World. Owns the ghost preview.
##
## Held item decides the primary action:
##   placeable block/object -> place at the aimed cell (ghost shows validity)
##   knife / bare hand      -> hold-to-scrap the aimed furniture (GL-07)
##   hammer                 -> hit player-placed blocks / pick up placeables (WS-22)
##   consumable             -> use on press
## Secondary: place/remove background walls (WS-21).

var player: Player
## LAN Step 4 (MultiplayerImpl §0/§5): on a client the layer only AIMS -
## target cell, reach, hover, cursor, ghost - and never acts; the host runs
## the actions from the relayed snapshot. Set by Player._ready().
var view_only: bool = false
var target_cell: Vector2i = Vector2i.ZERO
var target_in_reach: bool = false
var scrapping: WorldObject = null
var scrap_progress: float = 0.0
var pending_pump: WorldObject = null # click a pump -> next use click sets its outlet
var hovered: WorldObject = null      # interactable under the mouse (glows)
# LMB-on-object lifecycle: short press interacts on release, holding
# OBJECT_LONG_PRESS picks the object up (user request).
var press_obj: WorldObject = null
var press_time: float = 0.0
var press_consumed: bool = false
var press_lock: bool = false # a press that began on an object suppresses held-item actions
var hit_cooldown: float = 0.0
var attack_cooldown: float = 0.0 # weapon rate limit (melee swings, shots)
var _scrap_sfx_timer: float = 0.0
var message: String = ""
var message_timer: float = 0.0
var rng := RandomNumberGenerator.new()

var _ghost: Sprite2D
var _ghost_rect: ColorRect
var _used_last_tick: bool = false
var _used_secondary_last_tick: bool = false

func _ready() -> void:
	player = get_parent()
	_ghost = Sprite2D.new()
	_ghost.centered = false
	_ghost.modulate = Color(1, 1, 1, 0.5)
	_ghost.visible = false
	_ghost.top_level = true
	_ghost.z_index = 5
	add_child(_ghost)
	_ghost_rect = ColorRect.new()
	_ghost_rect.size = Vector2(Constants.BLOCK_SIZE, Constants.BLOCK_SIZE)
	_ghost_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_rect.visible = false
	_ghost_rect.top_level = true
	_ghost_rect.z_index = 5
	add_child(_ghost_rect)

func tick(delta: float) -> void:
	hit_cooldown = maxf(hit_cooldown - delta, 0.0)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	message_timer = maxf(message_timer - delta, 0.0)
	if message_timer <= 0.0:
		message = ""
	target_cell = World.cell_at(player.aim_position)
	var reach := player.reach_blocks() * Constants.BLOCK_SIZE
	target_in_reach = player.global_position.distance_to(World.cell_center(target_cell)) <= reach
	_update_hover()
	if _visuals():
		_update_cursor()
		_update_ghost()
	if view_only:
		_used_last_tick = player.wants_use
		_used_secondary_last_tick = player.wants_use_secondary
		return

	if player.wants_interact:
		_interact()
	_object_press(delta)
	if player.wants_use and not press_lock:
		_primary()
	if player.wants_use_secondary:
		_secondary(delta)
	else:
		_stop_scrapping()
	_used_last_tick = player.wants_use
	_used_secondary_last_tick = player.wants_use_secondary

## LMB on an interactable: interact on a short click's release; picking it
## up on a long hold. Dragging off the object cancels the press.
var press_climb := Vector2i(-1, -1) # ladder/rope cell under a held LMB (picked up on a long hold)

func _object_press(delta: float) -> void:
	if player.wants_use:
		if not _used_last_tick and pending_pump == null:
			press_obj = hovered if target_in_reach else null
			press_climb = Vector2i(-1, -1)
			# Ladders and ropes lift out on a long hold too (user request
			# 2026-09-04) - unless a rope is held, which extends the line instead.
			if press_obj == null and target_in_reach and World.is_climbable_cell(target_cell) and player.held_item() != "rope":
				press_climb = target_cell
			press_time = 0.0
			press_consumed = false
			press_lock = press_obj != null or press_climb.x >= 0
		if press_climb.x >= 0:
			if target_cell != press_climb:
				press_climb = Vector2i(-1, -1) # dragged off: cancel
			else:
				press_time += delta
				if press_time >= Constants.OBJECT_LONG_PRESS and not press_consumed:
					press_consumed = true
					_pickup_climbable(press_climb)
		if press_obj != null:
			if not is_instance_valid(press_obj) or World.object_at(target_cell) != press_obj:
				press_obj = null # dragged off: cancel (press_lock stays until release)
			else:
				press_time += delta
				if press_time >= Constants.OBJECT_LONG_PRESS and not press_consumed:
					press_consumed = true
					_pickup_object(press_obj)
	else:
		if press_obj != null and is_instance_valid(press_obj) and not press_consumed:
			var msg := press_obj.interact(player)
			if msg != "":
				say(msg)
		press_obj = null
		press_climb = Vector2i(-1, -1)
		press_lock = false

func _pickup_climbable(cell: Vector2i) -> void:
	var id := "ladder" if World.grid.climb_at(cell) == WorldGrid.C.LADDER else "rope"
	if not player.inventory.can_add(id, 1):
		say("Inventory full")
		return
	if World.pickup_climbable(cell) != "":
		player.inventory.add(id, 1)
		say("Picked up " + Data.item(id).get("name", id))

func _pickup_object(obj: WorldObject) -> void:
	if obj.def.get("fixed", false) or Data.item(obj.id).is_empty():
		say("It is wired into the building")
		return
	if obj.storage != null and not obj.storage.is_empty():
		say("Empty the chest first")
		return
	if player.inventory.can_add(obj.id, 1):
		var obj_name: String = obj.def.name
		World.remove_object(obj)
		player.inventory.add(obj.id, 1)
		say("Picked up " + obj_name)
	else:
		say("Inventory full")

func say(text: String) -> void:
	message = text
	message_timer = 2.0
	if not player.is_local() and player._sync != null:
		player._sync.ev_say(text) # host: the owning client shows it

## Visual side effects (hover glow, cursor, ghost, SFX) belong to the machine
## whose screen this body is on: skipped when the host simulates a remote peer.
func _visuals() -> bool:
	return player.is_local()

func _sfx(base: String, pos: Vector2, variants: int = 1, volume_db: float = 0.0) -> void:
	if player.is_local():
		Audio.play_sfx(base, pos, variants, volume_db)

# --- Actions ---

func _interact() -> void:
	if not target_in_reach:
		return
	var obj := World.object_at(target_cell)
	if obj != null:
		var msg := obj.interact(player)
		if msg != "":
			say(msg)
		return
	# Hand-grab fishing (GD-09): swim close to a school and interact.
	for f in get_tree().get_nodes_in_group("fish_schools"):
		if f.catch_fish(player):
			say("Caught a fish")
			return

## Pump outlet targeting (GL-16): E on a pump, then click a cell to aim its hose.
func begin_pump_targeting(pump: WorldObject) -> void:
	pending_pump = pump
	say("Click a cell to set the pump outlet")

func _set_pump_outlet() -> void:
	if not is_instance_valid(pending_pump):
		pending_pump = null
		return
	var max_px := Constants.PUMP_RANGE_BLOCKS * Constants.BLOCK_SIZE
	if pending_pump.center().distance_to(World.cell_center(target_cell)) > max_px:
		say("Outlet out of range (max %d blocks)" % int(Constants.PUMP_RANGE_BLOCKS))
	elif World.is_solid_cell(target_cell):
		say("The outlet must be an open cell")
	else:
		pending_pump.outlet_cell = target_cell
		World.notify_record_state(pending_pump)
		say("Pump outlet set")
	pending_pump = null

## LMB: interact with the held item — place, hammer, consume (scrap is RMB).
func _primary() -> void:
	if pending_pump != null:
		if not _used_last_tick:
			_set_pump_outlet()
		return
	var held := player.held_item()
	var it := Data.item(held)
	match it.get("category", ""):
		"placeable_block":
			if it.get("places_block", "") == "rope":
				# Ropes place ROPE_DROP cell(s) per click (one), extending
				# an existing line from its bottom (user request 2026-09-02).
				if target_in_reach and World.can_place_rope(target_cell):
					var slot = player.inventory.slots[player.selected_slot]
					var want: int = mini(Constants.ROPE_DROP, slot.count if slot != null else 0)
					var n := World.place_rope(target_cell, want)
					if n > 0:
						player.inventory.remove_from_slot(player.selected_slot, n)
						player.skills.add_xp("building", Constants.XP_BUILD_PER_BLOCK * n)
			elif target_in_reach and World.can_place_block(it.places_block, target_cell, player):
				if World.place_block(it.places_block, target_cell):
					player.inventory.remove_from_slot(player.selected_slot, 1)
					player.skills.add_xp("building", Constants.XP_BUILD_PER_BLOCK)
		"placeable_object":
			if target_in_reach and World.can_place_object(it.places_object, target_cell, player) and not _used_last_tick:
				World.place_object(it.places_object, target_cell, true)
				player.inventory.remove_from_slot(player.selected_slot, 1)
				player.skills.add_xp("building", Constants.XP_BUILD_PER_BLOCK * 2.0)
			elif target_in_reach and not _used_last_tick and World.last_place_error != "":
				say(World.last_place_error) # e.g. the stove wants a sealed room
		"consumable", "schematic":
			if not _used_last_tick:
				player.use_item(player.selected_slot)
		"seed":
			_plant_seed()
		"bucket":
			_use_bucket()
		"weapon":
			var w: Dictionary = ItemMods.weapon_of(player.held_stack()) # prefix mods folded in
			if w.get("melee", false):
				_melee(float(w.damage), float(w.speed), float(w.get("knockback", 8.0)),
					float(w.get("water_factor", Constants.MELEE_WATER_FACTOR)))
			elif w.has("projectile"):
				_fire_projectile(w)
			else:
				_fire_gun(w)
		_:
			var tool := Data.tool_of(held)
			if Data.is_tool(held, "hammer"):
				# The hammer doubles as a club when something is in swing range.
				if _enemy_near_aim() != null:
					_melee(float(tool.get("damage", 3)), 1.2, 8.0, Constants.MELEE_WATER_FACTOR)
				else:
					_hammer(tool)
			elif tool.get("type", "") == "knife":
				# Knives fight on LMB (RMB stays scrapping) — quick, and the
				# least slowed underwater (GD-08).
				_melee(float(tool.get("damage", 2)), 1.0 + float(tool.get("speed", 1.0)), 3.0,
					Constants.KNIFE_WATER_FACTOR)

## Plant a tree seed in a planter (user request 2026-09-02): a sapling sprouts
## on the pot and grows nightly - full-size only under open sky (a roof).
func _plant_seed() -> void:
	if _used_last_tick or not target_in_reach:
		return
	var obj := World.object_at(target_cell)
	if obj == null or obj.def.get("kind", "") != "planter":
		say("Plant seeds in a planter pot")
		return
	if World.plant_in_planter(obj, target_cell):
		player.inventory.remove_from_slot(player.selected_slot, 1)
		player.skills.add_xp("building", Constants.XP_BUILD_PER_BLOCK)
		say("Planted a seed - give it open sky to grow")
	else:
		say("This planter already has something growing")

## Wooden bucket (user request 2026-09-02): scoop a full cell of water, or
## pour the carried water into an open cell - carry water by hand.
func _use_bucket() -> void:
	if _used_last_tick or not target_in_reach or World.water_sim == null:
		return
	var held := player.held_item()
	if held == "wood_bucket":
		if World.water_sim.level_at(target_cell) > 0:
			World.water_sim.remove_water(target_cell, WaterSim.MAX_LEVEL)
			_swap_held("wood_bucket_full")
			_sfx("splash", World.cell_center(target_cell), 4, -12.0)
			say("Filled the bucket")
		else:
			say("No water to scoop there")
	elif held == "wood_bucket_full":
		if World.is_solid_cell(target_cell):
			say("Can't pour into a solid block")
		else:
			World.water_sim.add_water(target_cell, WaterSim.MAX_LEVEL)
			_swap_held("wood_bucket")
			_sfx("splash", World.cell_center(target_cell), 4, -10.0)
			say("Poured out the bucket")

func _swap_held(to_id: String) -> void:
	player.inventory.remove_from_slot(player.selected_slot, 1)
	player.inventory.add(to_id, 1)

## RMB: hold-to-scrap furniture (any non-tool or knife); walls with a wall
## item or the hammer.
func _secondary(delta: float) -> void:
	var held := player.held_item()
	var it := Data.item(held)
	var cat: String = it.get("category", "")
	if not target_in_reach:
		_stop_scrapping()
		return
	if cat == "placeable_block" and Data.blocks[it.places_block].layer == "back":
		_stop_scrapping()
		if World.can_place_block(it.places_block, target_cell, player) and World.place_block(it.places_block, target_cell):
			player.inventory.remove_from_slot(player.selected_slot, 1)
	elif Data.is_tool(held, "hammer"):
		_stop_scrapping()
		if hit_cooldown <= 0.0 or not _used_secondary_last_tick:
			var removed := World.remove_block(target_cell, "back")
			if removed != "":
				player.inventory.add(removed, 1)
			elif not World.erase_back_wall(target_cell):
				return
			hit_cooldown = Constants.BLOCK_HIT_INTERVAL
	else:
		_scrap(delta, Data.tool_of(held))

func _hammer(tool: Dictionary) -> void:
	# The cooldown paces repeated hits while holding; a fresh press always lands.
	if not target_in_reach or (hit_cooldown > 0.0 and _used_last_tick):
		return
	hit_cooldown = Constants.BLOCK_HIT_INTERVAL
	player.play_swing()
	var obj := World.object_at(target_cell)
	if obj != null:
		if obj.def.kind == "decal":
			# Dressing (user request 2026-09-01): broken-wall patches and roof
			# junk are not harvestable - a hammer knock simply clears them.
			var dname: String = obj.def.name
			World.remove_object(obj)
			_sfx("wood_break", World.cell_center(target_cell), 4)
			say("Cleared away the " + dname.to_lower())
			return
		if obj.def.kind == "scrap":
			say("Use a knife or your hands to scrap furniture")
			return
		if obj.storage != null and not obj.storage.is_empty():
			say("Empty the chest first")
			return
		if obj.def.get("fixed", false) or Data.item(obj.id).is_empty():
			say("It is wired into the building") # breakers, interior doorways
			return
		if player.inventory.can_add(obj.id, 1):
			World.remove_object(obj)
			player.inventory.add(obj.id, 1)
			say("Picked up " + obj.def.name)
		return
	# Demolitionist (tech tree) lands hammer blows harder.
	var dmg := float(tool.get("damage", 0)) * player.skills.effect("hammer_mult", 1.0)
	var result := World.damage_block(target_cell, dmg, int(tool.get("tier", 0)), player.global_position)
	match result:
		"structure":
			say("Building structure cannot be broken")
		"too_hard":
			say("Needs a better tool")
		"broken":
			_sfx("wood_break", World.cell_center(target_cell), 4)
		"damaged":
			_sfx("wood_hit", World.cell_center(target_cell), 2)
		_:
			pass

# --- Combat (M4, GD-07/08) ---

## The enemy a melee swing would connect with: in range of the player AND
## near the aim point (so you hit the one you're pointing at).
func _enemy_near_aim() -> Enemy:
	var best: Enemy = null
	var best_d := Constants.MELEE_AIM_SLOP_BLOCKS * Constants.BLOCK_SIZE
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(player.global_position) > \
				Constants.MELEE_RANGE_BLOCKS * Constants.BLOCK_SIZE + e.half.length():
			continue
		var d := e.global_position.distance_to(player.aim_position) - e.half.length()
		if d < best_d:
			best_d = d
			best = e
	return best

## One melee swing: `aps` attacks/sec, slowed by `water_factor` in water
## (knives least, GD-08). Swings land whether or not something is there.
func _melee(damage: float, aps: float, knockback: float, water_factor: float) -> void:
	if attack_cooldown > 0.0:
		return
	var rate := aps * (water_factor if player.in_water else 1.0)
	attack_cooldown = 1.0 / maxf(rate, 0.1)
	player.play_swing()
	var enemy := _enemy_near_aim()
	if enemy != null:
		enemy.hurt(damage, player.global_position, knockback)
		_sfx("wood_hit", enemy.global_position, 2, -6.0)

## Firearms (LT-01): hitscan, loud, and dead weight submerged. Bullets stop
## at solids and at the water surface — lead above, spears below.
func _fire_gun(w: Dictionary) -> void:
	if attack_cooldown > 0.0:
		return
	if player.submerged:
		if not _used_last_tick:
			say("It won't fire submerged")
		return
	var ammo: String = w.get("ammo", "")
	if ammo != "" and not player.inventory.has(ammo):
		if not _used_last_tick:
			say("Out of " + Data.item_name(ammo))
		return
	attack_cooldown = 1.0 / maxf(float(w.get("speed", 1.0)), 0.1)
	if ammo != "":
		player.inventory.remove(ammo, 1)
	var aim := (player.aim_position - player.global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2(player.facing, 0)
	var origin := player.global_position + aim * 6.0
	# Shotguns (Weapons.md §3): one trace per pellet across a half-cone, each
	# pellet its own damage — up close it all lands, at range it thins out.
	var pellets := maxi(int(w.get("pellets", 1)), 1)
	var spread := deg_to_rad(float(w.get("spread", Constants.SHOTGUN_SPREAD_DEG))) if pellets > 1 else 0.0
	for p in pellets:
		var dir := aim.rotated(randf_range(-spread, spread)) if pellets > 1 else aim
		var max_px := float(w.get("range_blocks", Constants.GUN_RANGE_BLOCKS)) * Constants.BLOCK_SIZE
		# Wall/water clip first, then the nearest enemy inside that distance.
		var d := 4.0
		while d < max_px:
			var pos := origin + dir * d
			if World.is_solid(pos) or World.is_water(pos):
				max_px = d
				break
			d += 4.0
		var best: Enemy = null
		var best_t := max_px
		for e: Enemy in get_tree().get_nodes_in_group("enemies"):
			var to := e.global_position - origin
			var t := to.dot(dir)
			if t > 0.0 and t < best_t and absf(to.cross(dir)) < e.half.length() + 3.0:
				best_t = t
				best = e
		if best != null:
			best.hurt(float(w.damage), player.global_position, 3.0 + float(w.get("knockback", 0.0)) * 0.25)
		World.spawn_tracer(origin, origin + dir * best_t) # the streak flies to where the shot stopped
	# Three gunshot takes; the host also relays the bang to every client
	# (a client shooter never runs this path itself, so it would hear nothing).
	var take := randi() % 3 + 1
	_sfx("gunshot_%d" % take, origin, 1, 0.0)
	Net.on_effect("sfx", origin, "gunshot_%d" % take)
	player.play_swing()

## Projectile weapons (GD-08, LT-16; generalised 2026-09-05): a spear gun,
## bow, crossbow, nail gun or harpoon gun fires its `projectile` ammo item.
## The ammo def's `projectile` block sets flight speed, how much gravity it
## feels in air and whether it drops back as a pickup. Silent; works above
## and below water (spears are the underwater ranged line).
func _fire_projectile(w: Dictionary) -> void:
	if attack_cooldown > 0.0:
		return
	var bolt_id: String = w.projectile
	if not player.inventory.has(bolt_id):
		if not _used_last_tick:
			say("Out of " + Data.item_name(bolt_id))
		return
	attack_cooldown = 1.0 / maxf(float(w.get("speed", 1.0)), 0.1)
	player.inventory.remove(bolt_id, 1)
	var dir := (player.aim_position - player.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(player.facing, 0)
	var pdef: Dictionary = Data.item(bolt_id).get("projectile", {})
	var speed := float(pdef.get("speed", Constants.PROJECTILE_SPEED_BLOCKS)) * Constants.BLOCK_SIZE
	var bolt := SpearBolt.new()
	bolt.setup(bolt_id, dir * speed, float(w.damage))
	bolt.knockback = 4.0 + float(w.get("knockback", 0.0)) * 0.25
	World.items_root.add_child(bolt)
	bolt.global_position = player.global_position + dir * 8.0
	_sfx("splash", player.global_position, 5, -14.0)

func _scrap(delta: float, tool: Dictionary) -> void:
	var obj := World.object_at(target_cell) if target_in_reach else null
	if obj == null or obj.def.kind != "scrap":
		_stop_scrapping()
		return
	if _weapon_in_hand():
		say("Weapons don't dismantle - use a tool")
		_stop_scrapping()
		return
	var need_tool: String = obj.def.get("requires_tool", "")
	if need_tool != "" and tool.get("type", "") != need_tool:
		say("Needs an %s to cut down" % need_tool if need_tool == "axe" else "Needs a %s" % need_tool)
		_stop_scrapping()
		return
	# Axes are tree tools only (user request 2026-09-02): dismantling anything
	# that doesn't require an axe treats one as bare hands (tier and speed).
	if tool.get("type", "") == "axe" and need_tool != "axe":
		tool = {}
	var tier: int = int(tool.get("tier", Constants.HAND_TOOL_TIER))
	if tier < int(obj.def.get("tool_tier", 0)):
		say("Needs a tool (tier %d)" % obj.def.tool_tier)
		_stop_scrapping()
		return
	if player.skills.level("scrapping") < int(obj.def.get("skill", 0)):
		say("Needs Scrapping %d" % obj.def.skill)
		_stop_scrapping()
		return
	if obj.storage != null and not obj.storage.is_empty():
		say("Empty it before scrapping")
		_stop_scrapping()
		return
	if scrapping != obj:
		_stop_scrapping()
		scrapping = obj
		scrap_progress = 0.0
	_scrap_sfx_timer -= delta
	if _scrap_sfx_timer <= 0.0:
		_scrap_sfx_timer = Constants.SCRAP_SFX_INTERVAL
		_sfx("creak_plastic", obj.center(), 3, -6.0)
	var speed: float = float(tool.get("speed", Constants.HAND_SCRAP_SPEED)) * player.scrap_speed_mult()
	if World.is_water(obj.center()): # working submerged is slower (user request 2026-09-06)
		speed *= 1.0 - Constants.UNDERWATER_SCRAP_SLOW
	scrap_progress += delta * speed / float(obj.def.get("scrap_time", 2.0))
	obj.scrap_progress = scrap_progress
	if scrap_progress >= 1.0:
		var yields := obj.roll_yields(false, rng, player)
		var pos := obj.center()
		World.remove_object(obj)
		# Resources pop OUT of the object and hover for the player to collect
		# (user request 2026-09-02), instead of teleporting into the bag.
		for y in yields:
			_pop_resource(y.item, int(y.count), pos)
		World.spawn_break_puff(pos, yields[0].item if not yields.is_empty() else "")
		player.skills.add_xp("scrapping", float(obj.def.get("xp", 3)))
		say("Scrapped " + obj.def.name)
		_sfx("dismantle_rattle", pos)
		scrapping = null
		scrap_progress = 0.0

## Pop a harvested resource out of the broken object as a few bobbing world
## items (user request 2026-09-02): they scatter up-and-out, then hover for
## the player to walk over and collect - no auto-magnet.
func _pop_resource(item: String, count: int, pos: Vector2) -> void:
	if count <= 0:
		return
	var n := clampi(count, 1, 3) # a few icons burst out, for feel
	var base := count / n
	var extra := count % n
	for i in n:
		var c := base + (1 if i < extra else 0)
		if c <= 0:
			continue
		var vel := Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-9.0, -6.0)) * Constants.BLOCK_SIZE
		var it := World.spawn_item(item, c, pos, vel)
		if it != null:
			# Pop out, hover briefly, then drift gently toward the player
			# (user request 2026-09-02).
			it.magnet = true
			it.gentle = true
			it.pickup_delay = Constants.HARVEST_DROP_DELAY

func _stop_scrapping() -> void:
	if scrapping != null:
		scrapping.scrap_progress = 0.0
	scrapping = null
	scrap_progress = 0.0

## Can the player harvest this object right now (user request 2026-09-02:
## don't highlight furniture that needs a higher-tier tool than the one held)?
## Mirrors the _scrap gate exactly. Only kind=="scrap" is gated - doors,
## chests, stations, beds, pumps, breakers stay actionable regardless.
## A plain weapon (weapon block, no tool block) held in the HOTBAR hand
## cannot dismantle anything (user request 2026-09-06); a worn weapon
## standing in for an empty hand does not count - that is still bare hands.
func _weapon_in_hand() -> bool:
	if player.holding_worn_weapon():
		return false
	var it := Data.item(player.held_item())
	return it.has("weapon") and not it.has("tool")

func can_harvest(obj: WorldObject) -> bool:
	if obj == null or obj.def.get("kind", "") != "scrap":
		return true
	if _weapon_in_hand():
		return false
	var tool: Dictionary = player.held_tool()
	var need_tool: String = obj.def.get("requires_tool", "")
	if need_tool != "" and tool.get("type", "") != need_tool:
		return false
	if tool.get("type", "") == "axe" and need_tool != "axe":
		tool = {} # axes are tree-only when dismantling
	var tier: int = int(tool.get("tier", Constants.HAND_TOOL_TIER))
	if tier < int(obj.def.get("tool_tier", 0)):
		return false
	return player.skills.level("scrapping") >= int(obj.def.get("skill", 0))

## Interactables glow slightly while the mouse is over them and in reach
## (self_modulate, so door transparency and power dimming are untouched).
func _update_hover() -> void:
	var new_hover: WorldObject = null
	if not player.ui_blocking(): # the info card reads at any distance (user request 2026-09-04)
		var obj := World.object_at(target_cell)
		if obj != null and obj.is_interactable():
			new_hover = obj
	if new_hover != hovered:
		if hovered != null and is_instance_valid(hovered) and _visuals():
			hovered.sprite.self_modulate = Color.WHITE
		hovered = new_hover
	# The glow marks "you can act on this NOW": only harvestable objects light
	# up (user request 2026-09-02), refreshed each frame so switching to the
	# right tool lights it. The info card still shows for un-harvestable ones,
	# so the tier badge can explain the gate.
	if hovered != null and is_instance_valid(hovered) and _visuals():
		hovered.sprite.self_modulate = Color(1.45, 1.42, 1.2) if target_in_reach and can_harvest(hovered) else Color.WHITE

## Cursor swap (user request): a magnifying glass over a searchable
## container; the same glass with a green check once it has been emptied.
const CURSOR_SEARCH := "res://assets/ui/cursor_search.png"
const CURSOR_SEARCH_DONE := "res://assets/ui/cursor_search_done.png"
const CURSOR_HOTSPOT := Vector2(10, 10) # lens centre

var _cursor_state: String = ""

func _update_cursor() -> void:
	var want := ""
	if hovered != null and is_instance_valid(hovered) and hovered.storage != null:
		want = "done" if hovered.storage.is_empty() else "search"
	if want == _cursor_state:
		return
	_cursor_state = want
	match want:
		"search":
			Input.set_custom_mouse_cursor(load(CURSOR_SEARCH), Input.CURSOR_ARROW, CURSOR_HOTSPOT)
		"done":
			Input.set_custom_mouse_cursor(load(CURSOR_SEARCH_DONE), Input.CURSOR_ARROW, CURSOR_HOTSPOT)
		_:
			Input.set_custom_mouse_cursor(null)

# --- Ghost preview ---

func _update_ghost() -> void:
	var held := player.held_item()
	var it := Data.item(held)
	var cat: String = it.get("category", "")
	if cat != "placeable_block" and cat != "placeable_object":
		_ghost.visible = false
		_ghost_rect.visible = false
		return
	var ok := false
	var origin := World.cell_center(target_cell) - Vector2.ONE * Constants.BLOCK_SIZE * 0.5
	if cat == "placeable_block":
		ok = target_in_reach and World.can_place_block(it.places_block, target_cell, player)
		_ghost_rect.size = Vector2.ONE * Constants.BLOCK_SIZE
		if it.places_block == "ladder": # a ladder builds 2 cells wide (2026-09-05)
			_ghost_rect.size.x *= 2
		_ghost_rect.position = origin
		_ghost.texture = Data.icon(held)
		_ghost.position = origin
		_ghost.scale = Vector2.ONE if _ghost.texture == null or _ghost.texture.get_width() <= Data.ICON_PX \
				else Vector2.ONE * (float(Data.ICON_PX) / _ghost.texture.get_width())
	else:
		var d: Dictionary = Data.objects[it.places_object]
		ok = target_in_reach and World.can_place_object(it.places_object, target_cell, player)
		var px := Vector2(d.size[0], d.size[1]) * Constants.BLOCK_SIZE
		_ghost_rect.size = px
		_ghost_rect.position = origin - Vector2(0, px.y - Constants.BLOCK_SIZE)
		_ghost.texture = Data.icon(held)
		_ghost.position = _ghost_rect.position
		_ghost.scale = Vector2.ONE
	_ghost_rect.color = Color(0.3, 1.0, 0.4, 0.25) if ok else Color(1.0, 0.3, 0.3, 0.25)
	_ghost.visible = _ghost.texture != null
	_ghost_rect.visible = true
