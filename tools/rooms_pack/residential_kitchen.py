"""Residential zone — kitchen room-pack items.

Fills the gaps in the Kitchen template: cooking, eating, dry storage and the
small appliances a flooded apartment kitchen would still hold. Style per
docs/technical/TileArt.md — material ramps, 1px outlines, light top-left /
dark bottom-right shading, no per-pixel noise.
"""
from common import *  # noqa: F401,F403


def _dark(c, k=45):
    return (max(0, c[0] - k), max(0, c[1] - k), max(0, c[2] - k))


# ---------------------------------------------------------------- furniture


def draw_stove(d, W, H):
    mt, ce = RAMPS["metal"], RAMPS["ceramic"]
    o, t, hl = ce
    box(d, 0, 4, W - 1, H - 2, ce, bevel=False)                  # white body
    d.line([1, 5, W - 2, 5], fill=hl)
    d.rectangle([0, 2, W - 1, 4], fill=mt[1][2], outline=mt[0])  # cooktop
    d.line([1, 3, W - 2, 3], fill=mt[2])
    for bx in (5, 13, 21):                                       # burners
        d.rectangle([bx, 2, bx + 4, 2], fill=OUT)
        d.point((bx + 2, 2), fill=mt[1][0])
    d.rectangle([0, 0, W - 1, 1], fill=mt[1][1], outline=mt[0])  # back splash
    for kx in (3, 8, 23, 28):                                    # knobs
        d.point((kx, 7), fill=mt[1][0])
    d.rectangle([3, 10, W - 4, H - 5], fill=(30, 38, 48), outline=mt[1][0])  # oven glass
    d.line([4, 11, W - 5, 11], fill=mt[1][2])                    # glass sheen
    d.rectangle([3, 8, W - 4, 8], fill=mt[1][3])                 # door handle
    d.rectangle([1, H - 2, 2, H - 1], fill=mt[0])                # feet
    d.rectangle([W - 3, H - 2, W - 2, H - 1], fill=mt[0])



def draw_dining_table(d, W, H):
    wd = RAMPS["wood"]
    box(d, 0, 0, W - 1, 3, wd)                                   # tabletop flush with the block top
    d.line([1, 1, W - 2, 1], fill=wd[2])
    d.rectangle([2, 4, 4, H - 1], fill=wd[1][1], outline=wd[0])  # legs
    d.rectangle([W - 5, 4, W - 3, H - 1], fill=wd[1][1], outline=wd[0])
    d.rectangle([5, 4, W - 6, 5], fill=wd[1][0])                 # apron shadow


def draw_bar_stool(d, W, H):
    mt, fb = RAMPS["metal"], RAMPS["fabric"]
    d.rectangle([2, 4, 13, 8], fill=fb[1][2], outline=fb[0])     # padded seat
    d.line([3, 5, 12, 5], fill=fb[2])
    d.line([3, 7, 12, 7], fill=fb[1][0])
    d.rectangle([7, 9, 8, H - 4], fill=mt[1][2], outline=mt[0])  # column
    d.rectangle([4, 16, 11, 17], fill=mt[1][1], outline=mt[0])   # foot ring
    d.rectangle([2, H - 3, 13, H - 2], fill=mt[1][1], outline=mt[0])  # base
    d.line([3, H - 3, 12, H - 3], fill=mt[2])
    d.rectangle([3, H - 1, 12, H - 1], fill=mt[0])


def draw_pantry_shelf(d, W, H):
    wd = RAMPS["wood"]
    o, t, hl = wd
    d.rectangle([0, 0, 1, H - 1], fill=t[2], outline=o)          # uprights
    d.rectangle([W - 2, 0, W - 1, H - 1], fill=t[2], outline=o)
    for sy in (8, 20, 32, H - 2):                                # shelves
        d.rectangle([2, sy, W - 3, sy + 1], fill=t[2], outline=o)
        d.line([3, sy, W - 4, sy], fill=hl)
    # jars, cans, sacks per shelf
    jars = ((3, 3, 7, YELLOW), (8, 2, 7, RED), (13, 4, 7, DARKGREEN), (18, 3, 7, ORANGE), (23, 2, 7, BROWN_PAPER))
    for x, top, bot, c in jars:
        d.rectangle([x, top, x + 3, bot], fill=c, outline=_dark(c, 60))
        d.rectangle([x, top - 1, x + 3, top - 1], fill=RAMPS["metal"][1][2])  # lid
        d.point((x + 1, top + 1), fill=WHITE)
    cans = ((4, 13), (9, 13), (14, 14), (20, 13), (25, 14))
    for x, top in cans:
        d.rectangle([x, top, x + 3, 19], fill=RAMPS["metal"][1][2], outline=RAMPS["metal"][0])
        d.rectangle([x, top + 2, x + 3, top + 3], fill=BLUE if x % 2 else RED)
        d.point((x + 1, top + 1), fill=RAMPS["metal"][2])
    d.rectangle([3, 24, 11, 31], fill=BROWN_PAPER, outline=OUT)   # flour sack
    d.line([4, 25, 10, 25], fill=(220, 196, 150))
    d.rectangle([5, 27, 9, 28], fill=RED)
    d.rectangle([14, 26, 24, 31], fill=(150, 110, 70), outline=OUT)  # crate
    d.line([15, 27, 23, 27], fill=(180, 140, 96))
    d.line([19, 27, 19, 30], fill=OUT)


# ------------------------------------------------------------------ clutter


def draw_trash_can(d, W, H):
    pl = RAMPS["plastic"]
    o, t, hl = pl
    d.polygon([(3, 5), (12, 5), (11, H - 1), (4, H - 1)], fill=t[1], outline=o)  # bin
    d.line([4, 7, 4, H - 3], fill=t[3])
    d.line([10, 7, 10, H - 3], fill=t[0])
    d.rectangle([2, 3, 13, 5], fill=t[2], outline=o)             # lid
    d.line([3, 4, 12, 4], fill=hl)
    d.rectangle([6, 1, 9, 2], fill=t[2], outline=o)              # pedal knob
    d.rectangle([4, H - 1, 6, H - 1], fill=RAMPS["metal"][1][2])  # pedal


def draw_toaster(d, W, H):
    mt = RAMPS["metal"]
    o, t, hl = mt
    box(d, 1, 6, W - 2, H - 2, mt)
    d.line([2, 7, W - 3, 7], fill=hl)
    d.rectangle([4, 6, 6, 6], fill=OUT)                          # slots
    d.rectangle([9, 6, 11, 6], fill=OUT)
    d.rectangle([4, 3, 6, 5], fill=BROWN_PAPER, outline=_dark(BROWN_PAPER, 60))  # toast
    d.rectangle([9, 2, 11, 5], fill=BROWN_PAPER, outline=_dark(BROWN_PAPER, 60))
    d.point((5, 4), fill=(226, 200, 160))
    d.rectangle([W - 3, 9, W - 2, 11], fill=t[0])                # lever
    d.point((3, 12), fill=RED)                                   # dial
    d.rectangle([2, H - 1, 3, H - 1], fill=o)                    # feet
    d.rectangle([W - 4, H - 1, W - 3, H - 1], fill=o)


# ----------------------------------------------------------------- wall art


def draw_range_hood(d, W, H):
    mt = RAMPS["metal"]
    o, t, hl = mt
    d.rectangle([W // 2 - 4, 0, W // 2 + 3, 5], fill=t[1], outline=o)  # duct
    d.line([W // 2 - 3, 1, W // 2 + 2, 1], fill=t[3])
    d.polygon([(0, H - 1), (W - 1, H - 1), (W - 4, 6), (3, 6)], fill=t[2], outline=o)  # hood body
    d.line([4, 7, W - 5, 7], fill=hl)
    for x in range(6, W - 6, 4):                                 # vent slats
        d.line([x, 10, x + 1, 10], fill=t[0])
        d.line([x, 12, x + 1, 12], fill=t[0])
    d.rectangle([3, H - 3, W - 4, H - 2], fill=t[0])             # underside
    d.rectangle([W // 2 - 2, H - 3, W // 2 + 1, H - 2], fill=YELLOW)  # lamp


def draw_spice_rack(d, W, H):
    wd = RAMPS["wood"]
    o, t, hl = wd
    for sy in (7, 14):                                           # two small shelves
        d.rectangle([0, sy, W - 1, sy + 1], fill=t[2], outline=o)
        d.line([1, sy, W - 2, sy], fill=hl)
    jars = ((1, 3, RED), (5, 2, ORANGE), (9, 3, DARKGREEN), (13, 2, YELLOW))
    for x, top, c in jars:
        d.rectangle([x, top, x + 2, 6], fill=c, outline=_dark(c, 60))
        d.rectangle([x, top - 1, x + 2, top - 1], fill=OUT)      # cap
    jars2 = ((2, 10, BROWN_PAPER), (6, 9, PURPLE), (10, 10, TEAL))
    for x, top, c in jars2:
        d.rectangle([x, top, x + 2, 13], fill=c, outline=_dark(c, 60))
        d.rectangle([x, top - 1, x + 2, top - 1], fill=OUT)


# -------------------------------------------------------------------- items

ITEMS = [
    {
        "id": "res_stove", "name": "Stove", "category": "furniture",
        "size": [2, 2], "zones": ["residential"], "room_type": "kitchen",
        "weight": 30, "tool_tier": 1, "skill": 2, "scrap_time": 3.5, "xp": 8,
        "yields": [{"item": "scrap_metal", "min": 6, "max": 10},
                   {"item": "scrap_metal", "min": 0, "max": 1}],
        "draw": draw_stove,
    },
    {
        "id": "res_dining_table", "name": "Dining Table", "category": "furniture", "surface": True, "surface": True, "surface": True,
        "size": [3, 1], "zones": ["residential"], "room_type": "kitchen",
        "weight": 14, "tool_tier": 0, "skill": 0, "scrap_time": 2.5, "xp": 5,
        "yields": [{"item": "wood", "min": 6, "max": 9}],
        "draw": draw_dining_table,
    },
    {
        "id": "res_bar_stool", "name": "Bar Stool", "category": "furniture",
        "size": [1, 2], "zones": ["residential"], "room_type": "kitchen",
        "weight": 6, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "scrap_metal", "min": 2, "max": 3},
                   {"item": "cloth", "min": 0, "max": 1}],
        "draw": draw_bar_stool,
    },
    {
        "id": "res_pantry_shelf", "name": "Pantry Shelf", "category": "furniture",
        "size": [2, 3], "zones": ["residential"], "room_type": "kitchen",
        "weight": 18, "tool_tier": 0, "skill": 0, "scrap_time": 3.0, "xp": 6,
        "storage_slots": 8,
        "yields": [{"item": "wood", "min": 5, "max": 8},
                   {"item": "plastic", "min": 1, "max": 3}],
        "draw": draw_pantry_shelf,
    },
    {
        "id": "res_trash_can", "name": "Trash Can", "category": "clutter",
        "size": [1, 1], "zones": ["residential"], "room_type": "kitchen",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "plastic", "min": 1, "max": 3}],
        "draw": draw_trash_can,
    },
    {
        "id": "res_toaster", "name": "Toaster", "category": "clutter",
        "size": [1, 1], "zones": ["residential"], "room_type": "kitchen",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_toaster,
    },
    {
        "id": "res_range_hood", "name": "Range Hood", "category": "wall_art",
        "size": [2, 1], "zones": ["residential"], "room_type": "kitchen",
        "weight": 8, "tool_tier": 1, "skill": 0, "scrap_time": 2.0, "xp": 4,
        "wall_mounted": True,
        "yields": [{"item": "scrap_metal", "min": 2, "max": 4}],
        "draw": draw_range_hood,
    },
    {
        "id": "res_spice_rack", "name": "Spice Rack", "category": "wall_art",
        "size": [1, 1], "zones": ["residential"], "room_type": "kitchen",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "wall_mounted": True,
        "yields": [{"item": "wood", "min": 1, "max": 2}],
        "draw": draw_spice_rack,
    },
]
