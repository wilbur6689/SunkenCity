"""Integrate room-pack item modules into the game.

For every pack module in tools/rooms_pack (worker-agent deliverables), this:
  1. renders each item's pixel art,
  2. packs the set into one sprite sheet: assets/sprites/sets/<module>.png,
  3. merges the item definitions into data/objects.json with sheet + rect
     references (replacing same-id entries, so re-runs are safe).

Usage: python tools/build_room_packs.py
"""
import importlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PACK_DIR = ROOT / "tools" / "rooms_pack"
SHEET_DIR = ROOT / "assets" / "sprites" / "sets"
sys.path.insert(0, str(PACK_DIR))
from PIL import Image, ImageDraw  # noqa: E402

SKIP = {"common", "render_check"}


def render_item(item):
    w, h = item["size"]
    img = Image.new("RGBA", (w * 16, h * 16), (0, 0, 0, 0))
    item["draw"](ImageDraw.Draw(img), w * 16, h * 16)
    return img


def pack_sheet(renders):
    """Shelf-pack (id, img) pairs; returns (sheet_image, {id: [x, y, w, h]})."""
    renders = sorted(renders, key=lambda r: (-r[1].height, -r[1].width))
    max_w = 256
    rects = {}
    x = y = shelf_h = 0
    for iid, img in renders:
        if x + img.width > max_w:
            x = 0
            y += shelf_h
            shelf_h = 0
        rects[iid] = [x, y, img.width, img.height]
        shelf_h = max(shelf_h, img.height)
        x += img.width
    height = y + shelf_h
    sheet = Image.new("RGBA", (max_w, max(height, 16)), (0, 0, 0, 0))
    for iid, img in renders:
        rx, ry, _, _ = rects[iid]
        sheet.paste(img, (rx, ry), img)
    return sheet, rects


def entry_for(item, module_name, rect):
    e = {
        "id": item["id"], "name": item["name"], "kind": "scrap",
        "size": item["size"], "weight": item["weight"],
        "tool_tier": item["tool_tier"], "skill": item["skill"],
        "scrap_time": item["scrap_time"], "xp": item["xp"],
        "yields": item["yields"], "zones": item["zones"],
        "room_type": item["room_type"], "category": item["category"],
        "sheet": "res://assets/sprites/sets/%s.png" % module_name,
        "rect": rect,
    }
    if item.get("storage_slots"):
        e["storage_slots"] = int(item["storage_slots"])
    if item.get("wall_mounted"):
        e["wall_mounted"] = True
    if item.get("surface"):
        e["surface"] = True  # top plane in row 0: things placed at dy = height rest on it
    return e


def main():
    SHEET_DIR.mkdir(parents=True, exist_ok=True)
    objects_path = ROOT / "data" / "objects.json"
    lib = json.loads(objects_path.read_text(encoding="utf-8"))
    by_id = {o["id"]: i for i, o in enumerate(lib["objects"])}
    total = 0
    for mod_file in sorted(PACK_DIR.glob("*.py")):
        name = mod_file.stem
        if name in SKIP or name.startswith("_"):
            continue
        mod = importlib.import_module(name)
        renders = [(it["id"], render_item(it)) for it in mod.ITEMS]
        sheet, rects = pack_sheet(renders)
        sheet.save(SHEET_DIR / f"{name}.png")
        for it in mod.ITEMS:
            entry = entry_for(it, name, rects[it["id"]])
            if it["id"] in by_id:
                lib["objects"][by_id[it["id"]]] = entry
            else:
                by_id[it["id"]] = len(lib["objects"])
                lib["objects"].append(entry)
        print(f"{name}: {len(mod.ITEMS)} items -> sets/{name}.png ({sheet.width}x{sheet.height})")
        total += len(mod.ITEMS)
    objects_path.write_text(json.dumps(lib, indent=1) + "\n", encoding="utf-8")
    print(f"objects.json now holds {len(lib['objects'])} objects ({total} from packs)")


if __name__ == "__main__":
    main()
