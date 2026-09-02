"""Slice docs/Examples/Objects/resources.jpg (the user's icon sheet,
2026-09-01) into 16x16 item icons.

White-keys the JPEG, splits the two groups on the central gap, detects row
and column bands from the alpha projections, validates the counts against
the user's authored list, then writes mapped icons to
assets/sprites/icons/<item id>.png (flagging authored_icon in
data/items.json so the game raw-loads them) and everything unmapped to
assets/sprites/icons/extra/<slug>.png for future items.

Run from the repo root:  python tools/convert_icons.py
"""
import json
import os
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs" / "Examples" / "Objects" / "resources.jpg"
OUT = ROOT / "assets" / "sprites" / "icons"
EXTRA = OUT / "extra"

# (group, row, col) -> item id, or a /slug for icons/extra. Rows/cols are
# 0-indexed against the user's corrected list (2026-09-01).
MAP = {
    # left group
    (0, 0, 0): "wood", (0, 0, 1): "scrap_metal", (0, 0, 2): "stone",
    (0, 0, 3): "/paper", (0, 0, 4): "/fabric_roll", (0, 0, 5): "cloth", (0, 0, 6): "/tarp",
    (0, 1, 0): "bandage", (0, 1, 1): "medkit", (0, 1, 2): "food_can",
    (0, 1, 3): "/green_stick", (0, 1, 4): "glowstick", (0, 1, 5): "pistol_rounds", (0, 1, 6): "rifle_rounds",
    (0, 2, 0): "/water_bottle", (0, 2, 1): "/jerry_can", (0, 2, 2): "rope",
    (0, 2, 3): "/nails", (0, 2, 4): "/screws", (0, 2, 5): "/wire_coil", (0, 2, 6): "/red_component",
    (0, 3, 0): "/leather", (0, 3, 1): "/broken_glass", (0, 3, 2): "/plywood",
    (0, 3, 3): "/concrete_block", (0, 3, 4): "/large_component", (0, 3, 5): "/battery_pack", (0, 3, 6): "/hard_drive",
    (0, 4, 0): "/nuts_bolts", (0, 4, 1): "/rubber", (0, 4, 2): "/gear",
    (0, 4, 3): "/circuit_board_component", (0, 4, 4): "/circuit_component", (0, 4, 5): "/steel_pipe",
    (0, 4, 6): "/small_electronic",
    (0, 5, 0): "/bolt", (0, 5, 1): "/small_hammer", (0, 5, 2): "/small_wire_coil",
    (0, 5, 3): "/vent_component", (0, 5, 4): "/cassette_tape", (0, 5, 5): "/fuse",
    (0, 6, 0): "hammer", (0, 6, 1): "pry_bar", (0, 6, 2): "/wire_strippers",
    (0, 6, 3): "/small_resistor_a", (0, 6, 4): "/small_resistor_b", (0, 6, 5): "/small_microchip",
    # right group
    (1, 0, 0): "iron", (1, 0, 1): "/aluminum_ingot", (1, 0, 2): "steel",
    (1, 0, 3): "/green_pcb", (1, 0, 4): "/blue_pcb", (1, 0, 5): "/complex_ic",
    (1, 0, 6): "/coil_of_wire", (1, 0, 7): "/microchip_2",
    (1, 1, 0): "/metal_plates", (1, 1, 1): "/reinforced_steel_ingot", (1, 1, 2): "/alien_ingot",
    (1, 1, 3): "/small_wire_coil_2", (1, 1, 4): "/gear_a", (1, 1, 5): "/gear_b",
    (1, 1, 6): "/gear_c", (1, 1, 7): "/iron_armor",
    (1, 2, 0): "/copper", (1, 2, 1): "/ocean_ingot", (1, 2, 2): "/laser_pointer",
    (1, 2, 3): "/rubber_2", (1, 2, 4): "/heavy_tire", (1, 2, 5): "/spilled_gears",
    (1, 2, 6): "/iron_coupler", (1, 2, 7): "/leather_armor",
    (1, 3, 0): "@schematic", (1, 3, 1): "/circuit_board_piece", (1, 3, 2): "/microprocessor",
    (1, 3, 3): "/backpack", (1, 3, 4): "/leather_belt", (1, 3, 5): "weight_belt",
    (1, 3, 6): "fins", (1, 3, 7): "/diving_fin_single",
    (1, 4, 0): "/large_battery", (1, 4, 1): "/green_battery", (1, 4, 2): "/orange_battery",
    (1, 4, 3): "/alien_artifact", (1, 4, 4): "/polish_compound", (1, 4, 5): "/blue_tank",
    (1, 4, 6): "/green_vial", (1, 4, 7): "/orange_vial",
    (1, 5, 0): "/empty_battery", (1, 5, 1): "/alien_energy", (1, 5, 2): "/flame_ball",
    (1, 5, 3): "/blue_glass_ball", (1, 5, 4): "tool_belt", (1, 5, 5): "/ocean_crystal",
    (1, 5, 6): "/iv_bag", (1, 5, 7): "/glass_flask",
    (1, 6, 0): "/medical_cuff", (1, 6, 1): "/syringe", (1, 6, 2): "/power_drill",
    (1, 6, 3): "/utility_suit", (1, 6, 4): "rebreather",
    (1, 7, 0): "tank_scrap", (1, 7, 1): "tank_iron", (1, 7, 2): "wetsuit",
    (1, 7, 3): "hard_suit", (1, 7, 4): "/full_black_wetsuit",
    (1, 7, 5): "scrap_knife", (1, 7, 6): "iron_knife", (1, 7, 7): "pistol",
    (1, 8, 0): "rifle", (1, 8, 1): "/harpoon_rifle", (1, 8, 2): "speargun",
    (1, 8, 3): "/dive_mask", (1, 8, 4): "/raft_large", (1, 8, 5): "/raft_small",
    (1, 8, 6): "/motorboat", (1, 8, 7): "/mini_submarine",
}
EXPECT = {0: [7, 7, 7, 7, 7, 6, 6], 1: [8, 8, 8, 8, 8, 8, 5, 8, 8]}


def key_white(img, tol=40):
    """Remove the white paper background from the OUTSIDE in, then trim the
    near-white JPEG halo one ring deep. Flooding from the border means an
    icon's own interior whites (a bandage body, a steel blade) survive while
    the surrounding paper - and the fringe it bleeds - goes fully clear."""
    img = img.convert("RGBA")
    w, h = img.width, img.height
    px = img.load()

    def whiteish(x, y, t):
        r, g, b, _a = px[x, y]
        return r > 255 - t and g > 255 - t and b > 255 - t

    # flood the paper from every border pixel
    stack = []
    for x in range(w):
        stack.append((x, 0)); stack.append((x, h - 1))
    for y in range(h):
        stack.append((0, y)); stack.append((w - 1, y))
    seen = set()
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or x < 0 or y < 0 or x >= w or y >= h:
            continue
        seen.add((x, y))
        if not whiteish(x, y, tol):
            continue
        px[x, y] = (0, 0, 0, 0)
        stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    # halo trim: a near-white pixel touching transparency is JPEG fringe
    for _ in range(2):
        clear = []
        for y in range(h):
            for x in range(w):
                if px[x, y][3] == 0 or not whiteish(x, y, 60):
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
                        clear.append((x, y)); break
        for x, y in clear:
            px[x, y] = (0, 0, 0, 0)
    return img


def bands(mask_sums, min_gap):
    """Contiguous non-empty index ranges, merging gaps under min_gap."""
    out = []
    start = None
    gap = 0
    for i, v in enumerate(mask_sums):
        if v > 0:
            if start is None:
                start = i
            gap = 0
        elif start is not None:
            gap += 1
            if gap >= min_gap:
                out.append((start, i - gap))
                start = None
    if start is not None:
        out.append((start, len(mask_sums) - 1))
    return out


def alpha_sums(img, axis):
    a = img.getchannel("A")
    w, h = img.size
    px = a.load()
    if axis == "y":
        return [sum(1 for x in range(w) if px[x, y] > 8) for y in range(h)]
    return [sum(1 for y in range(h) if px[x, y] > 8) for x in range(w)]


# FORCE=1 regenerates every icon; otherwise existing icons are never
# overwritten (protects hand edits from the Icon Editor - user report
# 2026-09-01: convert re-runs kept clobbering edited icons).
FORCE = os.environ.get("ICONS_FORCE") == "1"


def _save_icon(img, path):
    if path.exists() and not FORCE:
        return False
    img.save(path)
    return True


WEAPONS_SRC = ROOT / "docs" / "Examples" / "Objects" / "Weapons.jpg"
WMAP = {  # (row, col) -> item id or /extra slug (labels from the sheet)
    (0, 0): "/machete", (0, 1): "scrap_sword", (0, 2): "iron_sword",
    (1, 0): "/steel_longsword", (1, 1): "/diving_knife_combat", (1, 2): "/bone_scimitar",
    (2, 0): "smg",
}


def convert_weapons(lib, by_id):
    """Weapons.jpg (labelled): icon rows are the TALL y-bands; the baked
    text labels key to short bands and are skipped."""
    img = key_white(Image.open(WEAPONS_SRC))
    rows = [b for b in bands(alpha_sums(img, "y"), min_gap=6) if b[1] - b[0] > 150]
    n = 0
    for ri, (ry0, ry1) in enumerate(rows):
        row = img.crop((0, ry0, img.width, ry1 + 1))
        for ci, (cx0, cx1) in enumerate(bands(alpha_sums(row, "x"), min_gap=12)):
            target = WMAP.get((ri, ci))
            if target is None:
                continue
            cell = row.crop((cx0, 0, cx1 + 1, row.height))
            icon = cell.crop(cell.getbbox())
            side = max(icon.width, icon.height)
            sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            sq.paste(icon, ((side - icon.width) // 2, (side - icon.height) // 2), icon)
            small = sq.resize((32, 32), Image.NEAREST)
            if target.startswith("/"):
                _save_icon(small, EXTRA / (target[1:] + ".png"))
            else:
                if _save_icon(small, OUT / (target + ".png")):
                    n += 1
                if target in by_id:
                    by_id[target]["authored_icon"] = True
    print("weapons sheet: %d icons written (swords + SMG)" % n)


def main():
    img = key_white(Image.open(SRC))
    # split the two groups on the central gap
    cols = alpha_sums(img, "x")
    groups = bands(cols, min_gap=20)
    # the lone microchip floats between the groups (row 5 of the list)
    if len(groups) == 3:
        sx0, sx1 = groups[1]
        stray = img.crop((sx0, 0, sx1 + 1, img.height))
        box = stray.getbbox()
        icon = stray.crop(box)
        side = max(icon.width, icon.height)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.paste(icon, ((side - icon.width) // 2, (side - icon.height) // 2), icon)
        (ROOT / "assets" / "sprites" / "icons" / "extra").mkdir(parents=True, exist_ok=True)
        _save_icon(sq.resize((32, 32), Image.NEAREST), ROOT / "assets" / "sprites" / "icons" / "extra" / "microchip.png")
        groups = [groups[0], groups[2]]
        print("stray microchip parked in icons/extra")
    assert len(groups) == 2, "expected two icon groups, found %d" % len(groups)
    OUT.mkdir(parents=True, exist_ok=True)
    EXTRA.mkdir(parents=True, exist_ok=True)
    lib = json.loads((ROOT / "data" / "items.json").read_text(encoding="utf-8"))
    by_id = {it["id"]: it for it in lib["items"]}
    mapped, parked, missing = 0, 0, []
    for gi, (gx0, gx1) in enumerate(groups):
        g = img.crop((gx0, 0, gx1 + 1, img.height))
        rows = bands(alpha_sums(g, "y"), min_gap=3) # bottom gear rows sit only 4-5 px apart
        assert len(rows) == len(EXPECT[gi]), "group %d: %d rows, expected %d" % (gi, len(rows), len(EXPECT[gi]))
        for ri, (ry0, ry1) in enumerate(rows):
            row = g.crop((0, ry0, g.width, ry1 + 1))
            cells = bands(alpha_sums(row, "x"), min_gap=5) # boat row gaps run down to 7 px
            assert len(cells) == EXPECT[gi][ri], "group %d row %d: %d cells, expected %d" % (gi, ri, len(cells), EXPECT[gi][ri])
            for ci, (cx0, cx1) in enumerate(cells):
                cell = row.crop((cx0, 0, cx1 + 1, row.height))
                box = cell.getbbox()
                icon = cell.crop(box)
                side = max(icon.width, icon.height)
                sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
                sq.paste(icon, ((side - icon.width) // 2, (side - icon.height) // 2), icon)
                small = sq.resize((32, 32), Image.NEAREST)
                target = MAP.get((gi, ri, ci))
                if target is None:
                    parked += 1
                    _save_icon(small, EXTRA / ("g%d_r%d_c%d.png" % (gi, ri, ci)))
                elif target == "@schematic":
                    for it in lib["items"]:
                        if it["id"].startswith("schematic"):
                            _save_icon(small, OUT / (it["id"] + ".png"))
                            it["authored_icon"] = True
                            mapped += 1
                elif target.startswith("/"):
                    parked += 1
                    _save_icon(small, EXTRA / (target[1:] + ".png"))
                elif target in by_id:
                    _save_icon(small, OUT / (target + ".png"))
                    by_id[target]["authored_icon"] = True
                    mapped += 1
                else:
                    # not in items.json (block-backed items like rope):
                    # the icons dir itself is authoritative for Data.icon
                    _save_icon(small, OUT / (target + ".png"))
                    mapped += 1
                    missing.append(target + " (saved; block-backed)")
    convert_weapons(lib, by_id)
    (ROOT / "data" / "items.json").write_text(json.dumps(lib, indent=1, ensure_ascii=True) + "\n", encoding="utf-8")
    print("mapped %d item icons, parked %d in icons/extra" % (mapped, parked))
    if missing:
        print("UNKNOWN item ids (not mapped):", missing)


if __name__ == "__main__":
    main()
