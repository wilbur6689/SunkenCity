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
	message_timer = maxf(message_timer - delta, 0.0)
	if message_timer <= 0.0:
		message = ""
	target_cell = World.cell_at(player.aim_position)
	var reach := Constants.REACH_BLOCKS * Constants.BLOCK_SIZE
	target_in_reach = player.global_position.distance_to(World.cell_center(target_cell)) <= reach
	_update_hover()
	_update_ghost()

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
func _object_press(delta: float) -> void:
	if player.wants_use:
		if not _used_last_tick and pending_pump == null:
			press_obj = hovered
			press_time = 0.0
			press_consumed = false
			press_lock = press_obj != null
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
		press_lock = false

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

# --- Actions ---

func _interact() -> void:
	if not target_in_reach:
		return
	var obj := World.object_at(target_cell)
	if obj != null:
		var msg := obj.interact(player)
		if msg != "":
			say(msg)

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
			if target_in_reach and World.can_place_block(it.places_block, target_cell, player):
				if World.place_block(it.places_block, target_cell):
					player.inventory.remove_from_slot(player.selected_slot, 1)
					player.skills.add_xp("building", Constants.XP_BUILD_PER_BLOCK)
		"placeable_object":
			if target_in_reach and World.can_place_object(it.places_object, target_cell, player) and not _used_last_tick:
				World.place_object(it.places_object, target_cell, true)
				player.inventory.remove_from_slot(player.selected_slot, 1)
				player.skills.add_xp("building", Constants.XP_BUILD_PER_BLOCK * 2.0)
		"consumable", "schematic":
			if not _used_last_tick:
				player.use_item(player.selected_slot)
		_:
			if Data.is_tool(held, "hammer"):
				_hammer(Data.tool_of(held))

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
	var obj := World.object_at(target_cell)
	if obj != null:
		if obj.def.kind == "scrap":
			say("Use a knife or your hands to scrap furniture")
			return
		if obj.storage != null and not obj.storage.is_empty():
			say("Empty the chest first")
			return
		if player.inventory.can_add(obj.id, 1):
			World.remove_object(obj)
			player.inventory.add(obj.id, 1)
			say("Picked up " + obj.def.name)
		return
	var result := World.damage_block(target_cell, float(tool.get("damage", 0)), int(tool.get("tier", 0)))
	match result:
		"structure":
			say("Building structure cannot be broken")
		"too_hard":
			say("Needs a better tool")
		"broken":
			pass # World dropped the block item
		_:
			pass

func _scrap(delta: float, tool: Dictionary) -> void:
	var obj := World.object_at(target_cell) if target_in_reach else null
	if obj == null or obj.def.kind != "scrap":
		_stop_scrapping()
		return
	var tier: int = int(tool.get("tier", Constants.HAND_TOOL_TIER))
	if tier < int(obj.def.get("tool_tier", 0)):
		say("Needs a tool (tier %d)" % obj.def.tool_tier)
		_stop_scrapping()
		return
	if player.skills.level("scrapping") < int(obj.def.get("skill", 0)):
		say("Needs Scrapping %d" % obj.def.skill)
		_stop_scrapping()
		return
	if scrapping != obj:
		_stop_scrapping()
		scrapping = obj
		scrap_progress = 0.0
	var speed: float = float(tool.get("speed", Constants.HAND_SCRAP_SPEED)) * Constants.SCRAP_SPEED_MULT
	scrap_progress += delta * speed / float(obj.def.get("scrap_time", 2.0))
	obj.scrap_progress = scrap_progress
	if scrap_progress >= 1.0:
		var yields := obj.roll_yields(false, rng)
		var pos := obj.center()
		World.remove_object(obj)
		for y in yields:
			var leftover: int = player.inventory.add(y.item, y.count)
			if leftover > 0:
				World.spawn_item(y.item, leftover, pos)
		player.skills.add_xp("scrapping", float(obj.def.get("xp", 3)))
		say("Scrapped " + obj.def.name)
		scrapping = null
		scrap_progress = 0.0

func _stop_scrapping() -> void:
	if scrapping != null:
		scrapping.scrap_progress = 0.0
	scrapping = null
	scrap_progress = 0.0

## Interactables glow slightly while the mouse is over them and in reach
## (self_modulate, so door transparency and power dimming are untouched).
func _update_hover() -> void:
	var new_hover: WorldObject = null
	if target_in_reach and not player.ui_blocking():
		var obj := World.object_at(target_cell)
		if obj != null and obj.is_interactable():
			new_hover = obj
	if new_hover == hovered:
		return
	if hovered != null and is_instance_valid(hovered):
		hovered.sprite.self_modulate = Color.WHITE
	hovered = new_hover
	if hovered != null:
		hovered.sprite.self_modulate = Color(1.45, 1.42, 1.2)

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
		_ghost_rect.position = origin
		_ghost.texture = Data.icon(held)
		_ghost.position = origin
		_ghost.scale = Vector2.ONE
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
