"""Residential zone — living-room room-pack items.

Fills the gaps in apartment_pack / livingroom01: seating, a rug, a side
table, a stereo, an aquarium (a drowned city's favourite joke), a tall
plant, a bean bag, family photos and curtains. Style per
docs/technical/TileArt.md — material ramps, 1px outlines, light top-left /
dark bottom-right shading, no per-pixel noise.
"""
from common import *  # noqa: F401,F403


def _dark(c, k=45):
    return (max(0, c[0] - k), max(0, c[1] - k), max(0, c[2] - k))


def _light(c, k=35):
    return (min(255, c[0] + k), min(255, c[1] + k), min(255, c[2] + k))


# ---------------------------------------------------------------- furniture


def draw_armchair(d, W, H):
    fb = RAMPS["fabric"]
    o, t, hl = fb
    box(d, 3, 2, 12, 16, fb)                                     # backrest
    d.line([4, 3, 11, 3], fill=hl)
    box(d, 1, 14, 14, 24, fb)                                    # seat
    d.line([3, 15, 12, 15], fill=hl)
    box(d, 0, 12, 3, 26, fb, bevel=False)                        # armrests
    box(d, 12, 12, 15, 26, fb, bevel=False)
    d.point((1, 13), fill=hl)
    d.point((13, 13), fill=hl)
    d.rectangle([1, 27, 3, H - 1], fill=RAMPS["wood"][1][1], outline=RAMPS["wood"][0])  # legs
    d.rectangle([12, 27, 14, H - 1], fill=RAMPS["wood"][1][1], outline=RAMPS["wood"][0])


def draw_rug(d, W, H):
    base, band, dk, lt = (150, 60, 60), (200, 160, 90), (110, 40, 40), (190, 90, 90)
    d.rectangle([0, H - 8, W - 1, H - 1], fill=base, outline=OUT)
    d.rectangle([2, H - 7, W - 3, H - 2], outline=band)          # border band
    d.rectangle([5, H - 6, W - 6, H - 3], outline=lt)            # inner line
    for x in range(8, W - 8, 6):                                 # diamond motif
        d.point((x, H - 5), fill=band)
        d.point((x + 1, H - 4), fill=band)
        d.point((x - 1, H - 4), fill=band)
        d.point((x, H - 3), fill=dk)
    for x in range(1, W - 1, 2):                                 # fringe
        d.point((x, H - 1), fill=band)
    d.line([1, H - 8, W - 2, H - 8], fill=lt)



def draw_side_table(d, W, H):
    wd = RAMPS["wood"]
    box(d, 0, 0, W - 1, 2, wd)                                   # top flush with the block top
    d.rectangle([2, 3, 3, H - 1], fill=wd[1][1], outline=wd[0])  # legs
    d.rectangle([W - 4, 3, W - 3, H - 1], fill=wd[1][1], outline=wd[0])
    d.rectangle([4, 9, W - 5, 10], fill=wd[1][2], outline=wd[0])  # lower shelf
    d.rectangle([5, 7, 8, 8], fill=BROWN_PAPER, outline=OUT)     # a book on the shelf


def draw_stereo(d, W, H):
    nv, mt = RAMPS["navy"], RAMPS["metal"]
    o, t, hl = nv
    for sx in (0, W - 8):                                        # speakers
        box(d, sx, 2, sx + 7, H - 2, nv, bevel=False)
        d.ellipse([sx + 2, 5, sx + 5, 8], fill=t[0], outline=t[3])   # woofer
        d.ellipse([sx + 3, 10, sx + 4, 11], fill=t[0], outline=t[3])  # tweeter
        d.rectangle([sx + 1, H - 1, sx + 6, H - 1], fill=o)
    box(d, 9, 6, W - 10, H - 2, mt, bevel=False)                 # receiver
    d.line([10, 7, W - 11, 7], fill=mt[2])
    d.rectangle([11, 9, 16, 10], fill=(40, 120, 90))             # display
    d.point((11, 9), fill=GREEN)
    d.point((19, 10), fill=mt[1][0])                             # knobs
    d.point((21, 10), fill=mt[1][0])
    d.rectangle([11, 12, W - 12, 12], fill=mt[1][0])             # tray slot
    d.rectangle([10, H - 1, W - 11, H - 1], fill=mt[0])


def draw_aquarium(d, W, H):
    wd, nv = RAMPS["wood"], RAMPS["navy"]
    box(d, 1, H - 5, W - 2, H - 1, wd)                           # stand
    d.rectangle([2, 1, W - 3, H - 6], fill=nv[1][3], outline=OUT)  # glass
    d.rectangle([3, 4, W - 4, H - 7], fill=(60, 120, 150))       # water
    d.line([3, 4, W - 4, 4], fill=(150, 200, 220))               # surface
    d.rectangle([3, H - 8, W - 4, H - 7], fill=(190, 170, 110))  # gravel
    d.rectangle([5, H - 11, 5, H - 9], fill=DARKGREEN)           # plants
    d.rectangle([6, H - 12, 6, H - 9], fill=GREEN)
    d.rectangle([W - 8, H - 10, W - 8, H - 9], fill=DARKGREEN)
    d.rectangle([12, 7, 14, 8], fill=ORANGE)                     # fish
    d.point((11, 7), fill=ORANGE)
    d.point((12, 7), fill=WHITE)
    d.rectangle([20, 10, 22, 11], fill=YELLOW)
    d.point((23, 10), fill=YELLOW)
    d.point((7, 6), fill=(200, 230, 240))                        # bubbles
    d.point((8, 8), fill=(200, 230, 240))
    d.rectangle([2, 0, W - 3, 1], fill=OUT)                      # hood
    d.line([3, 1, W - 4, 1], fill=(60, 68, 80))


def draw_tall_plant(d, W, H):
    pot, pot_hi, pot_dk = (170, 100, 60), (200, 130, 84), (120, 66, 36)
    d.rectangle([4, H - 8, 11, H - 6], fill=pot, outline=OUT)    # rim
    d.line([5, H - 7, 10, H - 7], fill=pot_hi)
    d.polygon([(5, H - 5), (10, H - 5), (9, H - 1), (6, H - 1)], fill=pot, outline=OUT)
    d.line([6, H - 4, 6, H - 2], fill=pot_hi)
    d.rectangle([7, 8, 8, H - 8], fill=(90, 70, 40))             # trunk
    leaves = ((2, 6, 6, 10), (9, 5, 13, 9), (4, 2, 8, 6), (8, 1, 12, 4), (1, 11, 5, 14), (10, 11, 14, 14))
    for x0, y0, x1, y1 in leaves:
        d.rectangle([x0, y0, x1, y1], fill=DARKGREEN, outline=OUT)
        d.point((x0 + 1, y0 + 1), fill=GREEN)
        d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=GREEN)


# ------------------------------------------------------------------ clutter


def draw_bean_bag(d, W, H):
    c, dk, lt = PURPLE, _dark(PURPLE, 50), _light(PURPLE, 30)
    d.ellipse([1, 6, 14, H - 1], fill=c, outline=OUT)            # body
    d.ellipse([3, 3, 12, 9], fill=c, outline=OUT)                # top lobe
    d.rectangle([4, 7, 11, 9], fill=c)                           # merge seam
    d.line([5, 4, 9, 4], fill=lt)
    d.point((4, 5), fill=lt)
    d.line([4, H - 3, 11, H - 3], fill=dk)
    d.line([12, 10, 12, H - 4], fill=dk)


# ----------------------------------------------------------------- wall art


def draw_family_photos(d, W, H):
    wd, mt = RAMPS["wood"], RAMPS["metal"]
    d.rectangle([1, 1, 8, 9], fill=wd[1][2], outline=wd[0])      # wood frame
    d.rectangle([2, 2, 7, 8], fill=(150, 130, 100))
    d.rectangle([3, 4, 4, 5], fill=OUT)                          # two heads
    d.rectangle([5, 3, 6, 4], fill=OUT)
    d.rectangle([3, 6, 6, 8], fill=(90, 80, 70))
    d.rectangle([9, 5, 14, 13], fill=mt[1][3], outline=mt[0])    # metal frame
    d.rectangle([10, 6, 13, 12], fill=(140, 176, 200))
    d.rectangle([11, 8, 12, 9], fill=OUT)
    d.rectangle([10, 10, 13, 12], fill=(100, 130, 90))
    d.rectangle([2, 11, 7, 14], fill=WHITE, outline=OUT)         # small polaroid
    d.rectangle([3, 12, 6, 13], fill=(200, 160, 120))


def draw_curtains(d, W, H):
    fb = RAMPS["fabric"]
    o, t, hl = fb
    rod = RAMPS["metal"]
    d.rectangle([0, 1, W - 1, 2], fill=rod[1][2], outline=rod[0])  # rod
    d.point((0, 1), fill=rod[2])
    d.point((W - 1, 1), fill=rod[2])
    d.polygon([(2, 3), (13, 3), (11, H - 1), (4, H - 1)], fill=t[2], outline=o)  # drape
    for x in (5, 8, 11):                                         # folds
        d.line([x, 4, x - 1, H - 2], fill=t[0])
        d.line([x - 1, 4, x - 2, H - 2], fill=t[3])
    d.rectangle([3, H // 2, 12, H // 2 + 1], fill=YELLOW, outline=OUT)  # tie-back
    d.line([4, H // 2, 11, H // 2], fill=(250, 226, 150))
    d.line([3, 4, 12, 4], fill=hl)


# -------------------------------------------------------------------- items

ITEMS = [
    {
        "id": "res_armchair", "name": "Armchair", "category": "furniture",
        "size": [1, 2], "zones": ["residential"], "room_type": "living",
        "weight": 12, "tool_tier": 0, "skill": 0, "scrap_time": 2.0, "xp": 4,
        "yields": [{"item": "cloth", "min": 2, "max": 4},
                   {"item": "wood", "min": 1, "max": 3}],
        "draw": draw_armchair,
    },
    {
        "id": "res_rug", "name": "Rug", "category": "furniture",
        "size": [3, 1], "zones": ["residential"], "room_type": "living",
        "weight": 5, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "cloth", "min": 3, "max": 6}],
        "draw": draw_rug,
    },
    {
        "id": "res_side_table", "name": "Side Table", "category": "furniture", "surface": True, "surface": True, "surface": True,
        "size": [1, 1], "zones": ["residential"], "room_type": "living",
        "weight": 5, "tool_tier": 0, "skill": 0, "scrap_time": 1.2, "xp": 2,
        "yields": [{"item": "wood", "min": 2, "max": 3},
                   {"item": "stone", "min": 0, "max": 1}],
        "draw": draw_side_table,
    },
    {
        "id": "res_stereo", "name": "Stereo Set", "category": "furniture",
        "size": [2, 1], "zones": ["residential"], "room_type": "living",
        "weight": 9, "tool_tier": 1, "skill": 1, "scrap_time": 2.0, "xp": 5,
        "yields": [{"item": "plastic", "min": 2, "max": 4},
                   {"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_stereo,
    },
    {
        "id": "res_aquarium", "name": "Aquarium", "category": "furniture",
        "size": [2, 1], "zones": ["residential"], "room_type": "living",
        "weight": 14, "tool_tier": 0, "skill": 0, "scrap_time": 2.0, "xp": 4,
        "yields": [{"item": "wood", "min": 2, "max": 3},
                   {"item": "stone", "min": 1, "max": 2},
                   {"item": "plastic", "min": 0, "max": 1}],
        "draw": draw_aquarium,
    },
    {
        "id": "res_tall_plant", "name": "Tall Houseplant", "category": "furniture",
        "size": [1, 2], "zones": ["residential", "business", "commercial"], "room_type": "living",
        "weight": 6, "tool_tier": 0, "skill": 0, "scrap_time": 1.2, "xp": 2,
        "yields": [{"item": "stone", "min": 1, "max": 2},
                   {"item": "wood", "min": 0, "max": 1}],
        "draw": draw_tall_plant,
    },
    {
        "id": "res_bean_bag", "name": "Bean Bag", "category": "clutter",
        "size": [1, 1], "zones": ["residential"], "room_type": "living",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "cloth", "min": 2, "max": 3},
                   {"item": "plastic", "min": 0, "max": 1}],
        "draw": draw_bean_bag,
    },
    {
        "id": "res_family_photos", "name": "Family Photos", "category": "wall_art",
        "size": [1, 1], "zones": ["residential"], "room_type": "living",
        "weight": 1, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "wall_mounted": True,
        "yields": [{"item": "wood", "min": 1, "max": 1},
                   {"item": "scrap_metal", "min": 0, "max": 1}],
        "draw": draw_family_photos,
    },
    {
        "id": "res_curtains", "name": "Curtains", "category": "wall_art",
        "size": [1, 3], "zones": ["residential"], "room_type": "living",
        "weight": 4, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "wall_mounted": True,
        "yields": [{"item": "cloth", "min": 3, "max": 5},
                   {"item": "scrap_metal", "min": 0, "max": 1}],
        "draw": draw_curtains,
    },
]
