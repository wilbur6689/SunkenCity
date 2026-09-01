"""Residential zone — bedroom room-pack items.

Fills the gaps in the bedroom templates (residential_a/b/c/d, bedroom01):
bedside storage, a lamp, laundry, a radiator, a crib, luggage, a mirror and
a photo shelf. Style per docs/technical/TileArt.md — material ramps, 1px
outlines, light top-left / dark bottom-right shading, no per-pixel noise.
"""
from common import *  # noqa: F401,F403


def _dark(c, k=45):
    return (max(0, c[0] - k), max(0, c[1] - k), max(0, c[2] - k))


def _light(c, k=35):
    return (min(255, c[0] + k), min(255, c[1] + k), min(255, c[2] + k))


# ---------------------------------------------------------------- furniture



def draw_nightstand(d, W, H):
    wd, mt = RAMPS["wood"], RAMPS["metal"]
    o, t, hl = wd
    d.rectangle([0, 0, W - 1, 2], fill=t[3], outline=o)          # top slab flush with the block top
    d.line([1, 1, W - 2, 1], fill=hl)
    box(d, 1, 2, W - 2, H - 3, wd, bevel=False)
    d.line([2, 3, W - 3, 3], fill=t[3])
    d.rectangle([3, 5, W - 4, 8], fill=t[2], outline=t[0])       # drawer
    d.line([4, 6, W - 5, 6], fill=t[3])
    d.rectangle([W // 2 - 1, 7, W // 2, 7], fill=mt[1][3])       # handle
    d.rectangle([3, 9, W - 4, H - 4], outline=t[1])              # door panel
    d.rectangle([1, H - 3, 2, H - 1], fill=t[1])                 # feet
    d.rectangle([W - 3, H - 3, W - 2, H - 1], fill=t[1])


def draw_radiator(d, W, H):
    ce, mt = RAMPS["ceramic"], RAMPS["metal"]
    o, t, hl = ce
    d.rectangle([2, 3, W - 3, H - 4], fill=t[1], outline=o)      # body
    for x in range(4, W - 4, 3):                                 # fins
        d.line([x, 4, x, H - 5], fill=t[3])
        d.line([x + 1, 4, x + 1, H - 5], fill=t[0])
    d.line([3, 3, W - 4, 3], fill=hl)                            # top rail
    d.rectangle([0, H - 4, W - 1, H - 3], fill=mt[1][1], outline=mt[0])  # pipe
    d.rectangle([3, H - 2, 4, H - 1], fill=mt[1][0])             # feet
    d.rectangle([W - 5, H - 2, W - 4, H - 1], fill=mt[1][0])
    d.rectangle([W - 3, 5, W - 2, 7], fill=mt[1][3], outline=mt[0])  # valve knob


def draw_crib(d, W, H):
    wd, ce = RAMPS["wood"], RAMPS["ceramic"]
    o, t, hl = wd
    d.rectangle([0, 6, 2, H - 1], fill=t[2], outline=o)          # end posts
    d.rectangle([W - 3, 6, W - 1, H - 1], fill=t[2], outline=o)
    d.point((1, 6), fill=hl)
    d.point((W - 2, 6), fill=hl)
    d.rectangle([2, 9, W - 3, 10], fill=t[3], outline=o)         # top rail
    d.rectangle([2, H - 8, W - 3, H - 7], fill=t[1], outline=o)  # bottom rail
    for x in range(5, W - 4, 3):                                 # slats
        d.line([x, 11, x, H - 9], fill=t[2])
        d.line([x + 1, 11, x + 1, H - 9], fill=t[0])
    d.rectangle([3, H - 6, W - 4, H - 3], fill=ce[1][2], outline=ce[0])  # mattress
    d.line([4, H - 5, W - 5, H - 5], fill=ce[2])
    d.rectangle([5, H - 6, 9, H - 4], fill=PINK)                 # blanket corner
    d.rectangle([4, H - 2, 5, H - 1], fill=o)                    # castors
    d.rectangle([W - 6, H - 2, W - 5, H - 1], fill=o)


# ------------------------------------------------------------------ clutter


def draw_table_lamp(d, W, H):
    mt = RAMPS["metal"]
    shade, shade_dk, shade_hi = (222, 196, 140), (178, 148, 96), (240, 222, 178)
    d.polygon([(3, 8), (12, 8), (14, 2), (1, 2)], fill=shade, outline=OUT)  # shade
    d.line([2, 3, 13, 3], fill=shade_hi)
    d.line([4, 7, 11, 7], fill=shade_dk)
    d.rectangle([7, 9, 8, 12], fill=mt[1][2], outline=mt[0])     # stem
    d.rectangle([4, 13, 11, H - 1], fill=mt[1][1], outline=mt[0])  # base
    d.line([5, 14, 10, 14], fill=mt[1][3])
    d.point((7, 4), fill=YELLOW)                                 # bulb glow through shade


def draw_laundry_basket(d, W, H):
    pl = RAMPS["plastic"]
    o, t, hl = pl
    d.polygon([(2, 6), (13, 6), (12, H - 1), (3, H - 1)], fill=t[2], outline=o)  # basket
    for y in range(8, H - 2, 2):                                 # weave rows
        d.line([4, y, 11, y], fill=t[0])
    d.line([3, 7, 12, 7], fill=hl)
    d.rectangle([3, 3, 7, 6], fill=RED, outline=_dark(RED))      # clothes peeking
    d.rectangle([7, 2, 11, 6], fill=BLUE, outline=_dark(BLUE))
    d.rectangle([5, 4, 9, 5], fill=WHITE)
    d.point((4, 4), fill=_light(RED))


def draw_suitcase(d, W, H):
    lea = ((40, 22, 14), [(110, 62, 34), (138, 82, 44), (162, 102, 58), (184, 124, 76)], (206, 150, 100))
    mt = RAMPS["metal"]
    d.rectangle([6, 3, 9, 5], fill=lea[1][0], outline=lea[0])    # handle
    d.rectangle([7, 4, 8, 4], fill=(0, 0, 0, 0))
    box(d, 1, 5, W - 2, H - 2, lea)
    d.rectangle([4, 6, 4, H - 3], fill=lea[1][0])                # straps
    d.rectangle([11, 6, 11, H - 3], fill=lea[1][0])
    d.rectangle([3, 9, 5, 9], fill=mt[1][3])                     # buckles
    d.rectangle([10, 9, 12, 9], fill=mt[1][3])
    d.rectangle([2, H - 1, 3, H - 1], fill=OUT)                  # feet
    d.rectangle([12, H - 1, 13, H - 1], fill=OUT)


# ----------------------------------------------------------------- wall art


def draw_wall_mirror(d, W, H):
    wd, nv = RAMPS["wood"], RAMPS["navy"]
    box(d, 1, 0, W - 2, H - 1, wd, bevel=False)                  # frame
    d.line([2, 1, W - 3, 1], fill=wd[2])
    d.rectangle([3, 3, W - 4, H - 4], fill=nv[1][3])             # glass
    d.line([W - 5, 4, W - 5, H - 5], fill=nv[1][2])              # side shade
    d.line([4, 5, 4, 12], fill=WHITE)                            # glare
    d.line([5, 4, 5, 9], fill=(200, 216, 232))
    d.line([6, 14, 6, 18], fill=(200, 216, 232))


def draw_photo_shelf(d, W, H):
    wd = RAMPS["wood"]
    o, t, hl = wd
    d.rectangle([0, H - 4, W - 1, H - 2], fill=t[2], outline=o)  # shelf board
    d.line([1, H - 3, W - 2, H - 3], fill=hl)
    d.rectangle([2, H - 1, 3, H - 1], fill=t[0])                 # brackets
    d.rectangle([W - 4, H - 1, W - 3, H - 1], fill=t[0])
    frames = ((3, 4, 11, (140, 176, 200)), (13, 2, 20, (120, 150, 90)), (22, 5, 28, (200, 160, 120)))
    for x0, y0, x1, pic in frames:                               # framed photos
        d.rectangle([x0, y0, x1, H - 5], fill=t[1], outline=o)
        d.rectangle([x0 + 1, y0 + 1, x1 - 1, H - 6], fill=pic)
        d.point((x0 + 1, y0 + 1), fill=_light(pic))
    d.rectangle([13 + 3, 6, 13 + 4, 8], fill=OUT)                # tiny silhouette in the middle photo
    d.point((13 + 3, 5), fill=OUT)


# -------------------------------------------------------------------- items

ITEMS = [
    {
        "id": "res_nightstand", "name": "Nightstand", "category": "furniture", "surface": True, "surface": True, "surface": True,
        "size": [1, 1], "zones": ["residential"], "room_type": "bedroom",
        "weight": 6, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "storage_slots": 4,
        "yields": [{"item": "wood", "min": 2, "max": 4}],
        "draw": draw_nightstand,
    },
    {
        "id": "res_radiator", "name": "Radiator", "category": "furniture",
        "size": [2, 1], "zones": ["residential"], "room_type": "bedroom",
        "weight": 16, "tool_tier": 1, "skill": 2, "scrap_time": 2.5, "xp": 5,
        "yields": [{"item": "scrap_metal", "min": 3, "max": 5},
                   {"item": "scrap_metal", "min": 0, "max": 1}],
        "draw": draw_radiator,
    },
    {
        "id": "res_crib", "name": "Crib", "category": "furniture",
        "size": [2, 2], "zones": ["residential"], "room_type": "bedroom",
        "weight": 12, "tool_tier": 0, "skill": 0, "scrap_time": 2.5, "xp": 5,
        "yields": [{"item": "wood", "min": 4, "max": 6},
                   {"item": "cloth", "min": 1, "max": 2}],
        "draw": draw_crib,
    },
    {
        "id": "res_table_lamp", "name": "Table Lamp", "category": "clutter",
        "size": [1, 1], "zones": ["residential"], "room_type": "bedroom",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 1},
                   {"item": "cloth", "min": 0, "max": 1}],
        "draw": draw_table_lamp,
    },
    {
        "id": "res_laundry_basket", "name": "Laundry Basket", "category": "clutter",
        "size": [1, 1], "zones": ["residential"], "room_type": "bedroom",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "plastic", "min": 1, "max": 2},
                   {"item": "cloth", "min": 1, "max": 3}],
        "draw": draw_laundry_basket,
    },
    {
        "id": "res_suitcase", "name": "Suitcase", "category": "clutter",
        "size": [1, 1], "zones": ["residential"], "room_type": "bedroom",
        "weight": 4, "tool_tier": 0, "skill": 0, "scrap_time": 1.2, "xp": 2,
        "yields": [{"item": "cloth", "min": 1, "max": 3},
                   {"item": "plastic", "min": 0, "max": 1}],
        "draw": draw_suitcase,
    },
    {
        "id": "res_wall_mirror", "name": "Wall Mirror", "category": "wall_art",
        "size": [1, 2], "zones": ["residential"], "room_type": "bedroom",
        "weight": 4, "tool_tier": 0, "skill": 0, "scrap_time": 1.2, "xp": 2,
        "wall_mounted": True,
        "yields": [{"item": "wood", "min": 1, "max": 2}],
        "draw": draw_wall_mirror,
    },
    {
        "id": "res_photo_shelf", "name": "Photo Shelf", "category": "wall_art",
        "size": [2, 1], "zones": ["residential"], "room_type": "bedroom",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "wall_mounted": True,
        "yields": [{"item": "wood", "min": 1, "max": 3}],
        "draw": draw_photo_shelf,
    },
]
