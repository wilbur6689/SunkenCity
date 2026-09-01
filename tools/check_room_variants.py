"""Validate a room-variant file before it is merged into data/rooms.json.

Usage (from the project root):
    python tools/check_room_variants.py tools/room_variants/<file>.json

File shape: {"rooms": [ <room>, ... ]} where each room follows data/rooms.json:
  id, zone, type, width, height, depth_min, depth_max, objects, blocks
  objects: [{"id": <object id>, "x": <col>, "dy": <rows above the standing row, omit when 0>}]
  blocks:  [{"mat": 1-4, "x": <col>, "dy": <row>}]

Rules (the Room Editor's placement rules, scripts/tools/room_editor.gd):
  - every object id must exist in data/objects.json and be placeable in a room
    (not fixed / no_item / station / breaker);
  - an object at (x, dy) with size (w, h) occupies [x, x+w) x [dy, dy+h); it must
    lie inside the interior (width x height) and overlap no other object or block;
  - wall_mounted objects must have dy >= 1;
  - an elevated non-wall object (clutter on a desk, books on a fridge) must have
    an object or block directly under every cell of its bottom row; "surface"
    objects (desks, tables, counters) have their top flush with the block top;
  - floor footprint (dy == 0 objects) may not exceed 90 % of the width, so the
    player can still move through;
  - ids must be unique within the file and not collide with data/rooms.json.
Exit code 0 = clean.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OBJ = {o["id"]: o for o in json.loads((ROOT / "data" / "objects.json").read_text(encoding="utf-8"))["objects"]}
EXISTING = {r["id"] for r in json.loads((ROOT / "data" / "rooms.json").read_text(encoding="utf-8"))["rooms"]}
ZONES = {"residential", "business", "commercial", "industrial", "civil"}
MAX_FLOOR_FILL = 0.9


def size(oid):
    s = OBJ[oid]["size"]
    return int(s[0]), int(s[1])


def check_room(r, errors, seen_ids):
    rid = r.get("id", "<no id>")
    for k in ("id", "zone", "type", "width", "height", "objects"):
        if k not in r:
            errors.append(f"{rid}: missing field {k}")
    if r.get("zone") not in ZONES:
        errors.append(f"{rid}: zone {r.get('zone')!r} not in {sorted(ZONES)}")
    if rid in seen_ids:
        errors.append(f"{rid}: duplicate id in file")
    if rid in EXISTING:
        errors.append(f"{rid}: id already exists in data/rooms.json")
    seen_ids.add(rid)
    W, H = int(r.get("width", 0)), int(r.get("height", 5))
    if not (8 <= W <= 14) or H != 5:
        errors.append(f"{rid}: size {W}x{H} — width must be 8..14 and height 5")
    cells = {}
    for b in r.get("blocks", []):
        c = (int(b["x"]), int(b["dy"]))
        if not (0 <= c[0] < W and 0 <= c[1] < H):
            errors.append(f"{rid}: block {c} outside the interior")
        cells[c] = "block"
    floor_used = 0
    for o in r.get("objects", []):
        oid = o.get("id")
        if oid not in OBJ:
            errors.append(f"{rid}: unknown object id {oid!r}")
            continue
        d = OBJ[oid]
        if d.get("fixed") or d.get("no_item") or d.get("kind") in ("station", "breaker"):
            errors.append(f"{rid}: {oid} is not placeable in a room template")
        w, h = size(oid)
        x, dy = int(o.get("x", 0)), int(o.get("dy", 0))
        if x < 0 or x + w > W or dy < 0 or dy + h > H:
            errors.append(f"{rid}: {oid} at x={x} dy={dy} ({w}x{h}) leaves the {W}x{H} interior")
            continue
        for cx in range(x, x + w):
            for cy in range(dy, dy + h):
                if (cx, cy) in cells:
                    errors.append(f"{rid}: {oid} at x={x} dy={dy} overlaps {cells[(cx, cy)]} at ({cx},{cy})")
                    break
                cells[(cx, cy)] = oid
        if d.get("wall_mounted"):
            if dy < 1:
                errors.append(f"{rid}: wall art {oid} must hang (dy >= 1)")
        elif dy == 0:
            floor_used += w
        else:
            # elevated non-wall object: something must hold up every cell of its bottom row
            supported = all((cx, dy - 1) in cells for cx in range(x, x + w))
            if not supported:
                errors.append(f"{rid}: {oid} at x={x} dy={dy} floats — every cell under an elevated piece must be an object top or a block")
    if W and floor_used / W > MAX_FLOOR_FILL:
        errors.append(f"{rid}: floor {floor_used}/{W} cells used (> {int(MAX_FLOOR_FILL*100)} %) — leave room to walk")


def main(path):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    rooms = data.get("rooms", [])
    errors, seen = [], set()
    for r in rooms:
        check_room(r, errors, seen)
    for e in errors:
        print("ERROR:", e)
    print(f"{path}: {len(rooms)} rooms, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
