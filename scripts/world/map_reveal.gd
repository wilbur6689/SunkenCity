class_name MapReveal
extends RefCounted
## Fog-of-war world map (CC-25, amended 2026-09-06: SHARED): one bit per MAP
## cell (a Constants.MAP_CELL square of world cells), revealed by proximity
## as ANY player explores. The bitset serializes into the WORLD save (the
## host's copy is the truth); joining clients get it in the world snapshot
## and then newly revealed cells as WorldSync `_map` deltas. Older character
## files still carry a per-character map: it is merged in once on load.
## All coordinates here are map cells (World.map_macro_for).

var bounds: Rect2i
var bits := PackedByteArray()
var revealed := 0 # running count (the bitset is too big to walk per frame)
var dirty: PackedVector2Array = [] # newly revealed cells since last drain (map view)
var net_dirty: PackedVector2Array = [] # newly revealed cells not yet sent to clients (host only)
var track_net: bool = false # the host sets this while a LAN session is up

func _init(world_bounds: Rect2i) -> void:
	bounds = MapReveal.macro_bounds(world_bounds)
	bits.resize((bounds.size.x * bounds.size.y + 7) / 8)

## World-cell rect -> the map-cell rect that covers it.
static func macro_bounds(b: Rect2i) -> Rect2i:
	var m: int = Constants.MAP_CELL
	return Rect2i(b.position / m, (b.size + Vector2i(m - 1, m - 1)) / m)

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
	var mask := 1 << (i & 7)
	if bits[i >> 3] & mask == 0:
		bits[i >> 3] |= mask
		revealed += 1
		if dirty.size() < 200000: # safety cap; the map view drains this
			dirty.append(Vector2(cell))
		if track_net and net_dirty.size() < 200000:
			net_dirty.append(Vector2(cell))

## Reveal a disc of cells around the player's position.
func reveal_disc(center: Vector2i, radius: int) -> void:
	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= r2:
				reveal_cell(center + Vector2i(dx, dy))

func revealed_count() -> int:
	return revealed

## Apply a batch of revealed map cells (a WorldSync delta on a client).
func reveal_cells(cells: PackedVector2Array) -> void:
	for c in cells:
		reveal_cell(Vector2i(c))

## OR another map into this one (a legacy per-character map joining the
## shared world map). Cells it adds go to `dirty` so the map view repaints.
func merge_bytes(data: PackedByteArray) -> void:
	var raw := data.decompress(bits.size(), FileAccess.COMPRESSION_ZSTD)
	if raw.size() != bits.size():
		return
	for i in bits.size():
		var add: int = raw[i] & ~bits[i]
		if add == 0:
			continue
		bits[i] |= add
		for bit in 8:
			if add & (1 << bit):
				revealed += 1
				var idx := i * 8 + bit
				if dirty.size() < 200000:
					dirty.append(Vector2(bounds.position.x + idx % bounds.size.x, bounds.position.y + idx / bounds.size.x))

func to_bytes() -> PackedByteArray:
	return bits.compress(FileAccess.COMPRESSION_ZSTD)

func from_bytes(data: PackedByteArray) -> void:
	var raw := data.decompress(bits.size(), FileAccess.COMPRESSION_ZSTD)
	if raw.size() != bits.size():
		return
	bits = raw
	revealed = 0 # recount once; cheap enough at load time
	for i in bits.size():
		var b := bits[i]
		while b > 0:
			revealed += b & 1
			b >>= 1
