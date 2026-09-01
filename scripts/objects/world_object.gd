class_name WorldObject
extends Node2D
## A multi-tile world object (furniture, station, chest, bed, lamp, door,
## portal) defined in data/objects.json. Anchored at its bottom-left cell;
## World registers every covered cell so aiming/placement can look it up.
## Objects are non-solid except closed doors. A portal (interior doorway)
## hangs on the back wall: one click opens it, the next steps through to its
## linked twin (World.portal_target) — the pocket rooms of user request
## 2026-09-01.

var id: String = ""
var def: Dictionary = {}
var cell: Vector2i = Vector2i.ZERO # bottom-left
var size: Vector2i = Vector2i.ONE
var storage: Inventory = null     # chests
var open: bool = false            # doors
var unlocked: bool = false        # locked doors (M5 tool/key gates, GL-09)

const NO_OUTLET := Vector2i(-99999, -99999)
var outlet_cell: Vector2i = NO_OUTLET # pumps (GL-16): where pumped water goes
var powered_on: bool = false      # breakers: switch state; wired lights: powered state

## Wired lights (def.powered) glow only while powered; others always.
func set_powered(v: bool) -> void:
	powered_on = v
	var lit: bool = v or not def.get("powered", false)
	if _light != null:
		_light.enabled = lit
	if def.kind == "light":
		sprite.modulate = Color.WHITE if lit else Color(0.55, 0.55, 0.6)
var scrap_progress: float = 0.0   # 0..1 while being scrapped in place
var placed_by_player: bool = false

var _body: StaticBody2D
var _shape: CollisionShape2D
var _light: PointLight2D

@onready var sprite: Sprite2D = $Sprite2D

func setup(p_id: String, p_cell: Vector2i, p_placed: bool) -> void:
	id = p_id
	def = Data.objects[p_id]
	cell = p_cell
	size = Vector2i(def.size[0], def.size[1])
	placed_by_player = p_placed
	# Storage: chests always; any furniture may opt in via storage_slots
	# (cabinets, lockers… — authored in the Furniture Editor).
	var slots := int(def.get("storage_slots", def.get("slots", 0)))
	if def.kind == "chest" and slots == 0:
		slots = Constants.CHEST_SLOTS
	if slots > 0:
		storage = Inventory.new(slots)

func _ready() -> void:
	add_to_group("world_objects")
	sprite.texture = Data.object_texture(id)
	sprite.centered = false
	# Node origin = bottom-left cell's top-left corner; sprite is size*16 px.
	var px := Vector2(size) * Constants.BLOCK_SIZE
	sprite.position = Vector2(0, -px.y + Constants.BLOCK_SIZE)
	match def.kind:
		"door":
			_body = StaticBody2D.new()
			_shape = CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = px
			_shape.shape = rect
			_shape.position = sprite.position + px * 0.5
			_body.add_child(_shape)
			add_child(_body)
		"portal":
			set_open_look(open)
		"light":
			_light = PointLight2D.new()
			_light.texture = load("res://assets/sprites/light.png")
			var l: Dictionary = def.get("light", {})
			_light.texture_scale = float(l.get("radius_blocks", 6)) * Constants.BLOCK_SIZE / 64.0
			var c: Array = l.get("color", [1, 1, 1])
			_light.color = Color(c[0], c[1], c[2])
			_light.energy = 1.0
			_light.position = sprite.position + Vector2(px.x * 0.5, 4)
			add_child(_light)
			set_powered(false) # wired lights start dark until a breaker feeds them

## Re-apply saved state after place_object (must run once _ready has built
## the door body / storage). Power re-resolves via World.update_power later.
func restore_state(st: Dictionary) -> void:
	unlocked = st.get("unlocked", false)
	if def.kind == "door" and st.get("open", false):
		open = true
		_shape.disabled = true
		sprite.modulate.a = 0.45
	if def.kind == "portal":
		set_open_look(bool(st.get("open", false)))
	if def.kind == "breaker":
		powered_on = st.get("powered", false)
	outlet_cell = st.get("outlet", NO_OUTLET)
	if storage != null and st.has("storage"):
		var slots: Array = (st.storage as Array).duplicate(true)
		slots.resize(storage.slots.size())
		storage.slots = slots
		storage.changed.emit()

## Objects that respond to E (everything except wired-in lights).
func is_interactable() -> bool:
	return def.kind != "light"

func covered_cells() -> Array:
	var cells := []
	for dy in size.y:
		for dx in size.x:
			cells.append(Vector2i(cell.x + dx, cell.y - dy))
	return cells

func is_solid() -> bool:
	return def.kind == "door" and not open

## Feet position for a player standing on the object's floor row.
func bottom_center() -> Vector2:
	return global_position + Vector2(size.x * Constants.BLOCK_SIZE * 0.5, Constants.BLOCK_SIZE)

func center() -> Vector2:
	return global_position + Vector2(size.x * Constants.BLOCK_SIZE * 0.5, -(size.y - 1) * Constants.BLOCK_SIZE * 0.5 + Constants.BLOCK_SIZE * 0.5)

## Portal look: the closed door, or the open frame (def.open_sprite) with
## the dark room beyond. Also the record's truth via World.notify.
func set_open_look(v: bool) -> void:
	open = v
	if sprite == null:
		return
	var tex: Texture2D = null
	if v:
		tex = Data.object_texture(def.get("open_sprite", id + "_open"))
	sprite.texture = tex if tex != null else Data.object_texture(id)
	sprite.modulate.a = 1.0

## Locked doors (GL-09 ladder): a matching key unlocks for good, or a pry
## tool at the lock's tier forces it. "" once unlocked, else the reason.
func _try_unlock(player) -> String:
	if unlocked or int(def.get("lock_tier", 0)) <= 0:
		return ""
	var kid: String = def.get("key", "")
	var tool: Dictionary = player.held_tool()
	if kid != "" and player.inventory.has(kid):
		player.inventory.remove(kid, 1)
	elif tool.get("type", "") == "pry" and int(tool.get("tier", 0)) >= int(def.lock_tier):
		pass
	else:
		var need := "a vault key or a cutting torch" if kid != "" else "bolt cutters or better"
		if kid == "" and int(def.lock_tier) <= 1:
			need = "a pry bar or better"
		return "Locked — needs " + need
	unlocked = true
	Audio.play_sfx("door_latch", center())
	return ""

## E-key interaction. Returns a short HUD message ("" for none).
func interact(player) -> String:
	match def.kind:
		"portal":
			if not open:
				var why := _try_unlock(player)
				if why != "":
					return why
				set_open_look(true)
				World.notify_object_changed(self)
				Audio.play_sfx("door_open", center())
				return "The door swings open"
			var feet := World.portal_target(cell)
			if feet == Vector2.INF:
				return "The doorway is bricked up"
			Audio.play_sfx("door_creak_1", center())
			player.travel_to(feet)
			return "You step through the doorway"
		"door":
			if not open:
				var why := _try_unlock(player)
				if why != "":
					return why
			open = not open
			_shape.disabled = open
			sprite.modulate.a = 0.45 if open else 1.0
			World.notify_object_changed(self) # doors seal water; toggling wakes it
			Audio.play_sfx("door_open" if open else "door_creak_1", center())
			return "Door " + ("opened" if open else "closed")
		"pump":
			player.interaction.begin_pump_targeting(self)
			return ""
		"breaker":
			if World.water_sim != null and World.water_sim.level_at(cell) > 2:
				return "The breaker is flooded"
			powered_on = not powered_on
			World.update_power()
			return "Breaker switched " + ("on" if powered_on else "off")
		"bed":
			World.set_spawn(bottom_center())
			return "Spawn point set"
		"chest":
			player.open_container(self)
			return ""
		"safe":
			# Best-of-band loot behind the city's hardest lock (LT-14).
			if not unlocked:
				var skid: String = def.get("key", "")
				var stool: Dictionary = player.held_tool()
				if skid != "" and player.inventory.has(skid):
					player.inventory.remove(skid, 1)
					unlocked = true
					Audio.play_sfx("door_latch", center())
				elif stool.get("type", "") == "pry" and int(stool.get("tier", 0)) >= int(def.get("lock_tier", 3)):
					unlocked = true
					Audio.play_sfx("door_latch", center())
				else:
					return "Locked safe — a vault key or a cutting torch"
			player.open_container(self)
			return ""
		"station":
			player.open_crafting(def.station)
			return ""
		_:
			if def.get("fixed", false):
				return "It is wired into the building"
			if storage != null: # furniture with an inventory opens like a chest
				player.open_container(self)
				return ""
			# Plain furniture: picking up whole is the LONG press (GL-07 haul);
			# a short click just hints.
			return "Hold LMB to pick up · RMB to scrap"

## Rolls this object's yields. full = station yield; otherwise field yield
## (the Field Strip ability raises the field fraction; Master Scrapper and
## "of the Scavenger" gear can double a roll).
func roll_yields(full: bool, rng: RandomNumberGenerator, player = null) -> Array:
	var out := []
	var field_frac := Constants.FIELD_SCRAP_YIELD
	if player != null:
		field_frac = player.skills.effect("field_yield", field_frac)
	for y in def.get("yields", []):
		var n: int = rng.randi_range(int(y.min), int(y.max))
		if player != null:
			n = player.roll_yield(n)
		if not full:
			n = int(ceil(n * field_frac))
		if n > 0:
			out.append({"item": y.item, "count": n})
	return out
