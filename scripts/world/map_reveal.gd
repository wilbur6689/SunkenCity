class_name MapReveal
extends RefCounted
## Fog-of-war world map (CC-25): one bit per cell, revealed by proximity as
## the player explores. Tracked per character — the bitset serializes into
## the character save, not the world save.

var bounds: Rect2i
var bits := PackedByteArray()

func _init(p_bounds: Rect2i) -> void:
	bounds = p_bounds
	bits.resize((bounds.size.x * bounds.size.y + 7) / 8)

func _idx(cell: Vector2i) -> int:
	return (cell.y - bounds.position.y) * bounds.size.x + (cell.x - bounds.position.x)

func is_revealed(cell: Vector2i) -> bool:
	if not bounds.has_point(cell):
		return false
	var i := _idx(cell)
	return bits[i >> 3] & (1 << (i & 7)) != 0

func reveal_cell(cell: Vector2i) -> void:
	if not bounds.has_point(cell):
		return
	var i := _idx(cell)
	bits[i >> 3] |= 1 << (i & 7)

## Reveal a disc of cells around the player's position.
func reveal_disc(center: Vector2i, radius: int) -> void:
	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= r2:
				reveal_cell(center + Vector2i(dx, dy))

func revealed_count() -> int:
	var n := 0
	for i in bits.size():
		var b := bits[i]
		while b > 0:
			n += b & 1
			b >>= 1
	return n

func to_bytes() -> PackedByteArray:
	return bits.compress(FileAccess.COMPRESSION_ZSTD)

func from_bytes(data: PackedByteArray) -> void:
	var raw := data.decompress(bits.size(), FileAccess.COMPRESSION_ZSTD)
	if raw.size() == bits.size():
		bits = raw
