class_name WorldObject
extends Node2D
## A multi-tile world object (furniture, station, chest, bed, lamp, door)
## defined in data/objects.json. Anchored at its bottom-left cell; World
## registers every covered cell so aiming/placement can look it up. Objects
## are non-solid except closed doors.

var id: String = ""
var def: Dictionary = {}
var cell: Vector2i = Vector2i.ZERO # bottom-left
var size: Vector2i = Vector2i.ONE
var storage: Inventory = null     # chests
var open: bool = false            # doors

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
	if def.kind == "chest":
		storage = Inventory.new(int(def.get("slots", Constants.CHEST_SLOTS)))

func _ready() -> void:
	add_to_group("world_objects")
	var path: String = Data.OBJECT_SPRITE_DIR + id + ".png"
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
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

## E-key interaction. Returns a short HUD message ("" for none).
func interact(player) -> String:
	match def.kind:
		"door":
			open = not open
			_shape.disabled = open
			sprite.modulate.a = 0.45 if open else 1.0
			World.notify_object_changed(self) # doors seal water; toggling wakes it
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
		"station":
			player.open_crafting(def.station)
			return ""
		_:
			if def.get("fixed", false):
				return "It is wired into the building"
			# Found furniture / placeables: pick up whole (haul it home for full yield, GL-07).
			if player.inventory.can_add(id, 1):
				World.remove_object(self)
				player.inventory.add(id, 1)
				return "Picked up " + def.name
			return "Inventory full"

## Rolls this object's yields. full = station yield; otherwise field yield.
func roll_yields(full: bool, rng: RandomNumberGenerator) -> Array:
	var out := []
	for y in def.get("yields", []):
		var n: int = rng.randi_range(int(y.min), int(y.max))
		if not full:
			n = int(ceil(n * Constants.FIELD_SCRAP_YIELD))
		if n > 0:
			out.append({"item": y.item, "count": n})
	return out
