"""One-shot data migration for the half-size block (2026-09-04): 16 px blocks
became 8 px cells and every old block is a 2x2 group, while sprites and pixel
sizes stay as they were. Doubles every CELL-denominated value in the data
files and leaves pixel values alone:

  data/objects.json          size [w,h] x2, radius_blocks x2 (rect / sprites untouched)
  data/rooms.json            width/height x2, objects x/dy x2, blocks -> 2x2 groups,
  tools/room_variants/*.json finite depth_min/max x2
  data/enemies.json          bands speed/aggro x2, seeding *_spacing x2 (size = px, untouched)
  data/items.json            weapon knockback x2 (blocks of shove)

Idempotent: a "cell_px": 8 marker is written into each file's top level and
the script refuses to run twice on the same file.

Run from the repo root:  python tools/migrate_half_blocks.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MARK = "cell_px"
CELL = 8


def load(p):
    return json.loads(p.read_text(encoding="utf-8"))


def save(p, data, indent=1):
    p.write_text(json.dumps(data, indent=indent, ensure_ascii=False) + "\n", encoding="utf-8")


def guard(p, data):
    if data.get(MARK) == CELL:
        print("skip (already migrated):", p)
        return False
    data[MARK] = CELL
    return True


def objects():
    p = ROOT / "data" / "objects.json"
    data = load(p)
    if not guard(p, data):
        return
    n = 0
    for o in data["objects"]:
        o["size"] = [int(o["size"][0]) * 2, int(o["size"][1]) * 2]
        if "radius_blocks" in o:
            o["radius_blocks"] = o["radius_blocks"] * 2
        n += 1
    data["_comment"] = data.get("_comment", "").replace("size = [w, h] blocks", "size = [w, h] cells (8 px; sprite px = size * 8)")
    save(p, data)
    print("objects.json: %d entries doubled" % n)


def upscale_room(r):
    r["width"] = int(r["width"]) * 2
    r["height"] = int(r["height"]) * 2
    for k in ("depth_min", "depth_max"):
        v = int(r.get(k, 0))
        if abs(v) < 9000:
            r[k] = v * 2
    for o in r.get("objects", []):
        o["x"] = int(o["x"]) * 2
        if "dy" in o:
            o["dy"] = int(o["dy"]) * 2
    blocks = []
    for b in r.get("blocks", []):
        x, dy = int(b["x"]) * 2, int(b["dy"]) * 2
        for ox in (0, 1):
            for oy in (0, 1):
                nb = dict(b)
                nb["x"] = x + ox
                nb["dy"] = dy + oy
                blocks.append(nb)
    r["blocks"] = blocks


def rooms():
    files = [ROOT / "data" / "rooms.json"] + sorted((ROOT / "tools" / "room_variants").glob("*.json"))
    for p in files:
        data = load(p)
        if not guard(p, data):
            continue
        key = "rooms" if "rooms" in data else None
        rl = data[key] if key else data
        if isinstance(rl, dict):
            rl = list(rl.values())
        n = 0
        for r in rl:
            if isinstance(r, dict) and "width" in r:
                upscale_room(r)
                n += 1
        if "_comment" in data:
            data["_comment"] = data["_comment"].replace("interior cells", "interior cells (8 px each; tower floors hold 10)")
        save(p, data)
        print("%s: %d rooms upscaled" % (p.name, n))


def enemies():
    p = ROOT / "data" / "enemies.json"
    data = load(p)
    if not guard(p, data):
        return
    for tid, bands in data["bands"].items():
        for band, st in bands.items():
            if not isinstance(st, dict):
                continue
            for k in ("speed", "aggro"):
                if k in st:
                    st[k] = st[k] * 2
    for k, v in data["seeding"].items():
        if k.endswith("_spacing"):
            data["seeding"][k] = [v[0] * 2, v[1] * 2]
    save(p, data)
    print("enemies.json: speeds, aggro radii and spacings doubled (size stays in px)")


def items():
    p = ROOT / "data" / "items.json"
    data = load(p)
    if not guard(p, data):
        return
    n = 0
    for it in data["items"]:
        w = it.get("weapon")
        if isinstance(w, dict) and "knockback" in w:
            w["knockback"] = w["knockback"] * 2
            n += 1
    save(p, data, 2)
    print("items.json: %d knockback values doubled" % n)


if __name__ == "__main__":
    objects()
    rooms()
    enemies()
    items()
