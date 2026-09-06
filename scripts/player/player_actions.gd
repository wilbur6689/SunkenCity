class_name PlayerActions
extends Node
## Child `Actions` of every Player (LAN Step 7, docs/technical/MultiplayerImpl.md
## §7): the ONE funnel for every character-state mutation that originates in
## client-side UI - the inventory / crafting / chest / skills / modify screens,
## hotbar gestures. Each action is expressed in slot indices (and a chest's
## cell) so the host can replay it against its own copy of the world:
##
##   offline / host  -> applied at once through the existing Player/Inventory code
##   client          -> `rpc_id(1, "_act", name, args)` to the host; pure
##                      inventory moves are ALSO applied locally as optimistic
##                      feedback (the host's replica, streamed back by
##                      Net/CharSync, overwrites); actions with world side
##                      effects (drop, scrap, use, bulk scrap) wait for the host.
##
## The host validates that the sender owns this body. After every applied
## action the CharSync is nudged so the owner's replica ships this tick.
##
## Design note: the UI's drag cursor is a CLIENT-SIDE reference to a slot
## (the item never leaves its inventory while "lifted"), so only the final
## slot-to-slot moves travel - there is no host-side cursor to keep in step.

## Actions that run locally on a client as optimistic feedback (no world side effects).
const OPTIMISTIC := {"move_slot": true, "split_slot": true, "container_move": true, "storage_move": true, "quick_stack": true,
	"equip": true, "unequip": true, "craft": true, "learn_mods": true, "apply_mods": true, "combine_mods": true,
	"unlock_ability": true, "select_slot": true}
## Actions the client never applies locally (they spawn items / play world effects).
const HOST_ONLY := {"drop_slot": true, "scrap_slot": true, "use_slot": true, "bulk_scrap_at": true}

var player: Player

## One-liner for Player._ready(): adds the Actions child once.
static func attach(p: Node) -> void:
	if p.get_node_or_null("Actions") == null:
		var a := PlayerActions.new()
		a.name = "Actions"
		p.add_child(a)

func _ready() -> void:
	player = get_parent() as Player
	if Net.char_sync != null and Net.char_sync.has_method("track"):
		Net.char_sync.track(player)

## Entry point for the UI. Returns whether the action applied (server) or
## was sent (client).
func act(action: String, args: Array = []) -> bool:
	if Net.is_client():
		if not player.is_local():
			return false
		if action != "select_slot": # the input snapshot already relays the hotbar (§5)
			_act.rpc_id(1, action, args)
		if OPTIMISTIC.has(action):
			return _apply(action, args)
		return true # sent; the host's replica carries the result back
	return _apply(action, args)

@rpc("any_peer", "call_remote", "reliable")
func _act(action: String, args: Array) -> void:
	if Net.mode != Net.Mode.HOST:
		return
	if multiplayer.get_remote_sender_id() != player.peer_id:
		return
	if not (OPTIMISTIC.has(action) or HOST_ONLY.has(action)):
		return
	if player.dying:
		return
	_apply(action, args)

func _apply(action: String, args: Array) -> bool:
	var ok := false
	match action:
		"move_slot":
			ok = move_slot(int(args[0]), int(args[1]))
		"split_slot":
			ok = split_slot(int(args[0]), int(args[1]), int(args[2]))
		"container_move":
			ok = container_move(args[0], bool(args[1]), int(args[2]), int(args[3]), int(args[4]) if args.size() > 4 else 0)
		"storage_move":
			ok = storage_move(args[0], int(args[1]), int(args[2]), int(args[3]) if args.size() > 3 else 0)
		"quick_stack":
			ok = quick_stack(args[0])
		"drop_slot":
			ok = drop_slot(int(args[0]), int(args[1]))
		"scrap_slot":
			ok = scrap_slot(int(args[0]), int(args[1]))
		"equip":
			ok = equip(String(args[0]), int(args[1]))
		"unequip":
			ok = unequip(String(args[0]), int(args[1]))
		"use_slot":
			ok = use_slot(int(args[0]))
		"craft":
			ok = craft(String(args[0]))
		"learn_mods":
			ok = learn_mods(int(args[0]))
		"apply_mods":
			ok = apply_mods(int(args[0]), String(args[1]), String(args[2]))
		"combine_mods":
			ok = combine_mods(String(args[0]), String(args[1]))
		"unlock_ability":
			ok = unlock_ability(String(args[0]))
		"select_slot":
			ok = select_slot(int(args[0]), bool(args[1]) if args.size() > 1 else false)
		"bulk_scrap_at":
			ok = bulk_scrap_at(args[0])
	if ok:
		_changed()
	return ok

## The owner's replica ships this tick (host); no-op offline / on a client.
func _changed() -> void:
	if Net.mode == Net.Mode.HOST and Net.char_sync != null and Net.char_sync.has_method("mark_dirty"):
		Net.char_sync.mark_dirty(player)

## HUD messages come from the simulating side only: the host relays them to
## the owner (PlayerSync `_ev_message`), so a client applying optimistically
## stays quiet and never shows one twice.
func _say(text: String) -> void:
	if Net.is_server():
		player.message.emit(text)

## Overflow that does not fit the bag: dropped at the feet on the server only.
func _overflow(id: String, count: int) -> void:
	if count > 0 and Net.is_server():
		World.spawn_item(id, count, player.global_position)

# --- Resolution helpers ---

func _reach() -> float:
	return Constants.REACH_BLOCKS * Constants.BLOCK_SIZE * 1.5

func _in_reach(cell: Vector2i) -> bool:
	return World.is_ready() and World.cell_center(cell).distance_to(player.global_position) <= _reach() * 2.0

## The storage Inventory of the container record at `cell` (the record's
## inventory is canonical; an instantiated node shares the same object).
func _storage_at(cell: Vector2i) -> Inventory:
	if not World.is_ready():
		return null
	var rec: Dictionary = World.object_record_at(cell)
	if rec.is_empty() or rec.get("storage") == null:
		return null
	if not _in_reach(cell):
		return null
	return rec.storage

func _notify_storage(cell: Vector2i) -> void:
	var rec: Dictionary = World.object_record_at(cell)
	if not rec.is_empty():
		World.notify_record_changed(rec)

func _valid(inv: Inventory, i: int) -> bool:
	return inv != null and i >= 0 and i < inv.slots.size()

## Core move: `count` (<= 0 = whole stack) from src[i] to dst[j]. Empty
## target takes it; the same plain id merges up to the stack size; anything
## else swaps when the whole stack moves (a partial into a different item is
## refused). Returns how many moved (a swap counts as the whole stack).
func _move(src: Inventory, i: int, dst: Inventory, j: int, count: int) -> int:
	if not _valid(src, i) or not _valid(dst, j):
		return 0
	if src == dst and i == j:
		return 0
	var s = src.slots[i]
	if s == null:
		return 0
	var whole: bool = count <= 0 or count >= int(s.count) or s.has("mods")
	if whole:
		count = int(s.count)
	var d = dst.slots[j]
	var moved := 0
	if d == null:
		if whole:
			dst.slots[j] = s
			src.slots[i] = null
		else:
			dst.slots[j] = {"id": s.id, "count": count}
			s.count -= count
		moved = count
	elif d.id == s.id and not d.has("mods") and not s.has("mods"):
		var room: int = Data.stack_size(s.id) - int(d.count)
		var take: int = mini(room, count)
		if take <= 0:
			return 0
		d.count += take
		s.count -= take
		if s.count <= 0:
			src.slots[i] = null
		moved = take
	elif whole:
		dst.slots[j] = s
		src.slots[i] = d
		moved = count
	else:
		return 0
	src.changed.emit()
	if dst != src:
		dst.changed.emit()
	return moved

# --- Bag ---

func move_slot(i: int, j: int) -> bool:
	return _move(player.inventory, i, player.inventory, j, 0) > 0

func split_slot(i: int, j: int, n: int) -> bool:
	return _move(player.inventory, i, player.inventory, j, maxi(n, 1)) > 0

## Bag <-> container at `cell`. `from_container` = source is the chest.
## j = -1 means "anywhere in the other inventory" (shift-click quick move).
func container_move(cell: Vector2i, from_container: bool, i: int, j: int, n: int = 0) -> bool:
	var storage := _storage_at(cell)
	if storage == null:
		return false
	var src: Inventory = storage if from_container else player.inventory
	var dst: Inventory = player.inventory if from_container else storage
	var moved := 0
	if j < 0:
		if not _valid(src, i) or src.slots[i] == null:
			return false
		var s = src.slots[i]
		if s.has("mods"):
			if dst.add_stack(s):
				src.set_slot(i, null)
				moved = 1
		else:
			var leftover: int = dst.add(s.id, int(s.count))
			moved = int(s.count) - leftover
			src.set_slot(i, {"id": s.id, "count": leftover} if leftover > 0 else null)
	else:
		moved = _move(src, i, dst, j, n)
	if moved > 0:
		_notify_storage(cell)
	return moved > 0

## A move inside one container's own grid.
func storage_move(cell: Vector2i, i: int, j: int, n: int = 0) -> bool:
	var storage := _storage_at(cell)
	if storage == null:
		return false
	var moved := _move(storage, i, storage, j, n)
	if moved > 0:
		_notify_storage(cell)
	return moved > 0

func quick_stack(cell: Vector2i) -> bool:
	var storage := _storage_at(cell)
	if storage == null:
		return false
	var moved: int = player.inventory.quick_stack_into(storage)
	_notify_storage(cell)
	_say("Quick-stacked %d items" % moved)
	return true

func drop_slot(i: int, n: int) -> bool:
	if not _valid(player.inventory, i) or player.inventory.slots[i] == null:
		return false
	var s = player.inventory.slots[i]
	var id: String = s.id
	var taken: int = player.inventory.remove_from_slot(i, maxi(n, 1))
	if taken <= 0:
		return false
	World.spawn_item(id, taken, player.global_position,
		Vector2(player.facing * 8.0 * Constants.BLOCK_SIZE, -4.0 * Constants.BLOCK_SIZE))
	return true

## Hold-RMB scrapping from the bag: field yield away from stations.
func scrap_slot(i: int, n: int) -> bool:
	if not _valid(player.inventory, i) or player.inventory.slots[i] == null:
		return false
	return player.scrap_item(String(player.inventory.slots[i].id), maxi(n, 1), true)

func use_slot(i: int) -> bool:
	if not _valid(player.inventory, i) or player.inventory.slots[i] == null:
		return false
	player.use_item(i)
	return true

# --- Equipment ---

## Wear one from bag[i]. The piece it replaces goes back into bag[i] when
## that slot emptied, else anywhere in the bag (overflow drops at the feet).
func equip(slot_name: String, i: int) -> bool:
	if not player.equipment.has(slot_name) or not _valid(player.inventory, i):
		return false
	var s = player.inventory.slots[i]
	if s == null:
		return false
	if not player.slot_unlocked(slot_name):
		_say("That mount is locked — an ability on the tech tree opens it")
		return false
	if not player.can_equip(slot_name, String(s.id)):
		_say("%s cannot go in the %s slot" % [Data.item_name(s.id), slot_name.trim_suffix("1").trim_suffix("2").trim_suffix("3").trim_suffix("4").capitalize()])
		return false
	var current = player.equipment.get(slot_name)
	var one = s.duplicate(true) # keep per-instance mods (LT-05..07)
	one.count = 1
	s.count -= 1
	if s.count <= 0:
		player.inventory.slots[i] = current # the old piece takes the vacated slot (may be null)
	elif current != null:
		if current.has("mods"):
			if not player.inventory.add_stack(current):
				_overflow(String(current.id), 1)
		else:
			_overflow(String(current.id), player.inventory.add(String(current.id), int(current.count)))
	player.set_equipment(slot_name, one) # emits inventory.changed
	return true

## Take the worn piece off into bag[j] (-1 = first free slot). A wearable of
## the same slot already in bag[j] swaps onto the body.
func unequip(slot_name: String, j: int) -> bool:
	if not player.equipment.has(slot_name):
		return false
	var current = player.equipment.get(slot_name)
	if current == null:
		return false
	if j < 0:
		if not player.inventory.add_stack(current):
			_say("Bag full")
			return false
		player.set_equipment(slot_name, null)
		return true
	if not _valid(player.inventory, j):
		return false
	var d = player.inventory.slots[j]
	if d == null:
		player.inventory.slots[j] = current
		player.set_equipment(slot_name, null)
		return true
	if int(d.count) == 1 and player.can_equip(slot_name, String(d.id)):
		player.inventory.slots[j] = current
		player.set_equipment(slot_name, d)
		return true
	return false

# --- Crafting / progression ---

func craft(recipe_id: String) -> bool:
	var r: Dictionary = Data.recipes.get(recipe_id, {})
	if r.is_empty():
		return false
	if not (bool(r.get("known", false)) or player.knows_recipe(recipe_id)):
		return false
	var station := String(r.station)
	if station != "hand" and not World.stations_near(player.global_position, _reach()).has(station):
		_say("Craft at a %s" % (Data.objects[station].name if Data.objects.has(station) else station))
		return false
	if not player.craft(r):
		return false
	_say("Crafted " + Data.item_name(r.output.item))
	return true

## Modification Bench LEARN: sacrifice bag[i] (a modded instance) for its mods.
func learn_mods(i: int) -> bool:
	if not _valid(player.inventory, i) or player.inventory.slots[i] == null:
		return false
	if not World.stations_near(player.global_position, _reach()).has("mod_bench"):
		return false
	var s = player.inventory.slots[i]
	if not s.has("mods") or player.learnable_mods(s).is_empty():
		return false
	var learned: Array = player.learn_mods(s)
	player.inventory.set_slot(i, null)
	_say("Learned: " + ", ".join(learned) if not learned.is_empty() else "Nothing new to learn")
	return true

## Modification Bench APPLY: learned prefix/suffix onto the clean piece in bag[i].
func apply_mods(i: int, prefix_id: String, suffix_id: String) -> bool:
	if not _valid(player.inventory, i) or player.inventory.slots[i] == null:
		return false
	if not World.stations_near(player.global_position, _reach()).has("mod_bench"):
		return false
	var s = player.inventory.slots[i]
	if not player.apply_mods(s, prefix_id, suffix_id):
		return false
	_say("Modified: " + ItemMods.display_name(s))
	return true

## Modification Bench COMBINE: two library entries into their recipe's result.
func combine_mods(a_id: String, b_id: String) -> bool:
	if not World.stations_near(player.global_position, _reach()).has("mod_bench"):
		return false
	var result := player.combine_mods(a_id, b_id)
	if result == "":
		return false
	_say("Combined: " + String(ItemMods.def_of(result).get("name", result)))
	return true

func unlock_ability(id: String) -> bool:
	if not player.skills.unlock(id):
		return false
	_say("Learned " + String(Data.abilities[id].name))
	player.inventory.changed.emit() # gear slots / stats redraw
	return true

## Hotbar selection: local on every peer (a client's snapshot carries it to the host).
func select_slot(i: int, bare: bool = false) -> bool:
	if i < Constants.WEAPON_HOTBAR or i >= Constants.HOTBAR_SLOTS:
		return false
	player.selected_slot = i
	player.bare_hands = bare
	return true

## A tiered scrap bench at `cell` grinds the bag's furniture of its stage.
func bulk_scrap_at(cell: Vector2i) -> bool:
	if not _in_reach(cell):
		return false
	var rec: Dictionary = World.object_record_at(cell)
	if rec.is_empty() or String(rec.def.get("kind", "")) != "scrapper":
		return false
	_say(player.bulk_scrap(int(rec.def.get("scrap_stage", 1))))
	return true
