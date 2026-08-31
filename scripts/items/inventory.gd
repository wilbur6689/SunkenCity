class_name Inventory
extends RefCounted
## Slot-based item container (WS-13, LT-23). Slots hold {id, count} or are
## empty (null). Stack limits come from Data.stack_size(). Emits `changed`
## after any mutation so UI can refresh.

signal changed

var slots: Array = []

func _init(size: int) -> void:
	slots.resize(size)
	slots.fill(null)

func size() -> int:
	return slots.size()

func is_empty() -> bool:
	for s in slots:
		if s != null:
			return false
	return true

func count(id: String) -> int:
	var n := 0
	for s in slots:
		if s != null and s.id == id:
			n += s.count
	return n

func has(id: String, n: int = 1) -> bool:
	return count(id) >= n

func has_all(inputs: Array) -> bool:
	for inp in inputs:
		if not has(inp.item, inp.count):
			return false
	return true

## Adds up to `n` of `id`; returns how many did NOT fit.
func add(id: String, n: int = 1) -> int:
	var stack := Data.stack_size(id)
	# top up existing stacks first
	for s in slots:
		if n <= 0:
			break
		if s != null and s.id == id and s.count < stack:
			var take: int = mini(stack - s.count, n)
			s.count += take
			n -= take
	# then empty slots
	for i in slots.size():
		if n <= 0:
			break
		if slots[i] == null:
			var take: int = mini(stack, n)
			slots[i] = {"id": id, "count": take}
			n -= take
	changed.emit()
	return n

func can_add(id: String, n: int = 1) -> bool:
	var stack := Data.stack_size(id)
	var room := 0
	for s in slots:
		if s == null:
			room += stack
		elif s.id == id:
			room += stack - s.count
		if room >= n:
			return true
	return room >= n

## Removes up to `n` of `id`; returns how many were actually removed.
func remove(id: String, n: int = 1) -> int:
	var removed := 0
	for i in range(slots.size() - 1, -1, -1):
		if n <= 0:
			break
		var s = slots[i]
		if s != null and s.id == id:
			var take: int = mini(s.count, n)
			s.count -= take
			n -= take
			removed += take
			if s.count <= 0:
				slots[i] = null
	changed.emit()
	return removed

func remove_all(inputs: Array) -> void:
	for inp in inputs:
		remove(inp.item, inp.count)

func remove_from_slot(index: int, n: int = 1) -> int:
	var s = slots[index]
	if s == null:
		return 0
	var take: int = mini(s.count, n)
	s.count -= take
	if s.count <= 0:
		slots[index] = null
	changed.emit()
	return take

func set_slot(index: int, stack) -> void:
	slots[index] = stack if (stack != null and stack.count > 0) else null
	changed.emit()

func total_weight() -> float:
	var w := 0.0
	for s in slots:
		if s != null:
			w += Data.weight(s.id) * s.count
	return w

## Moves as much of every stack whose id already exists in `target` into it (LT-23 quick-stack).
func quick_stack_into(target: Inventory) -> int:
	var moved := 0
	for i in slots.size():
		var s = slots[i]
		if s == null or target.count(s.id) == 0:
			continue
		var leftover := target.add(s.id, s.count)
		moved += s.count - leftover
		slots[i] = {"id": s.id, "count": leftover} if leftover > 0 else null
	changed.emit()
	return moved

func to_dict() -> Array:
	return slots.duplicate(true)
