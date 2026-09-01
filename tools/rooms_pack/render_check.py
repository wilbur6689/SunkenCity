"""Validate a room-pack item module: schema checks + render every item.

Usage (from the project root):
    python tools/rooms_pack/render_check.py <module_name>

Renders each item at its block size, reports errors, and writes an x4
contact sheet to tools/rooms_pack/_preview_<module>.png for visual review.
"""
import importlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from PIL import Image, ImageDraw  # noqa: E402

VALID_YIELD_ITEMS = {"wood", "scrap_metal", "plastic", "cloth", "stone", "iron"}
VALID_CATEGORIES = {"furniture", "clutter", "wall_art", "wall_detail", "statement", "roof", "tree", "flora"}
# Per-category size caps (w, h); default is ordinary furniture.
SIZE_CAPS = {"roof": (8, 16), "tree": (8, 16), "flora": (8, 16), "wall_detail": (4, 4), "statement": (4, 4)}
REQUIRED = ["id", "name", "category", "size", "zones", "room_type", "weight",
            "tool_tier", "skill", "scrap_time", "xp", "yields", "draw"]


def check(module_name: str) -> int:
    mod = importlib.import_module(module_name)
    items = mod.ITEMS
    errors = []
    renders = []
    seen = set()
    for it in items:
        label = it.get("id", "<no id>")
        for k in REQUIRED:
            if k not in it:
                errors.append(f"{label}: missing field {k}")
        if it.get("id") in seen:
            errors.append(f"{label}: duplicate id")
        seen.add(it.get("id"))
        w, h = it.get("size", [1, 1])
        cap_w, cap_h = SIZE_CAPS.get(it.get("category"), (4, 3))
        if not (1 <= w <= cap_w and 1 <= h <= cap_h):
            errors.append(f"{label}: size {w}x{h} out of range (w 1-{cap_w}, h 1-{cap_h})")
        if it.get("category") not in VALID_CATEGORIES:
            errors.append(f"{label}: bad category {it.get('category')}")
        for y in it.get("yields", []):
            if y.get("item") not in VALID_YIELD_ITEMS:
                errors.append(f"{label}: bad yield item {y.get('item')}")
            cap = 60 if it.get("category") in ("roof", "tree", "flora") else 30
            if not (0 <= y.get("min", -1) <= y.get("max", -1) <= cap):
                errors.append(f"{label}: bad yield range")
        try:
            img = Image.new("RGBA", (w * 16, h * 16), (0, 0, 0, 0))
            it["draw"](ImageDraw.Draw(img), w * 16, h * 16)
            bbox = img.getbbox()
            if bbox is None:
                errors.append(f"{label}: draw produced an empty image")
            else:
                bw, bh = bbox[2] - bbox[0], bbox[3] - bbox[1]
                if bw < w * 16 * 0.5 or bh < h * 16 * 0.4:
                    errors.append(f"{label}: art fills only {bw}x{bh} of {w*16}x{h*16} — shrink size or draw bigger")
                if it.get("surface"):
                    # Surface furniture must present its top plane in row 0 so stacked
                    # clutter rests on it instead of floating (2026-09-01).
                    px = img.load()
                    opaque = sum(1 for x in range(w * 16) if px[x, 0][3] > 0)
                    if opaque < w * 16 * 0.6:
                        errors.append(f"{label}: surface item but row 0 is only {opaque}/{w*16} px opaque — extend the top to the block top")
            renders.append((label, img))
        except Exception as e:  # noqa: BLE001
            errors.append(f"{label}: draw crashed: {e!r}")
    # contact sheet
    if renders:
        pad = 6
        scale = 4
        width = sum(r[1].width * scale + pad for r in renders) + pad
        height = max(r[1].height for r in renders) * scale + 2 * pad
        sheet = Image.new("RGBA", (width, height), (44, 48, 60, 255))
        x = pad
        for _label, img in renders:
            up = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
            sheet.paste(up, (x, pad), up)
            x += up.width + pad
        out = Path(__file__).parent / f"_preview_{module_name}.png"
        sheet.save(out)
        print(f"preview: {out}")
    for e in errors:
        print("ERROR:", e)
    print(f"{module_name}: {len(items)} items, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(check(sys.argv[1]))
