"""Residential zone — apartment (living quarters) room-pack items.

Drowned-city apartment set: living room / bedroom / kitchen flavor.
Style per docs/technical/TileArt.md — material ramps, 1px outlines,
light top/left + dark bottom/right shading, no per-pixel noise.
"""
from common import *  # noqa: F401,F403


def _dark(c, k=45):
    return (max(0, c[0] - k), max(0, c[1] - k), max(0, c[2] - k))


# ---------------------------------------------------------------- furniture


def draw_sofa(d, W, H):
    f = RAMPS["fabric"]
    o, t, hl = f
    box(d, 4, 1, W - 5, 9, f)                      # backrest
    box(d, 4, 8, W - 5, H - 3, f)                  # seat base
    d.line([W // 2, 9, W // 2, H - 4], fill=t[0])  # cushion seam
    d.line([6, 9, W // 2 - 2, 9], fill=hl)         # cushion top light
    d.line([W // 2 + 2, 9, W - 7, 9], fill=hl)
    box(d, 0, 4, 5, H - 2, f)                      # armrests
    box(d, W - 6, 4, W - 1, H - 2, f)
    d.point((2, 5), fill=hl)
    d.point((W - 4, 5), fill=hl)
    d.rectangle([1, H - 2, 2, H - 1], fill=o)      # stub legs
    d.rectangle([W - 3, H - 2, W - 2, H - 1], fill=o)


def draw_bookshelf(d, W, H):
    wd = RAMPS["wood"]
    o, t, hl = wd
    box(d, 0, 0, W - 1, H - 1, wd, bevel=False)
    d.line([1, 1, W - 2, 1], fill=hl)              # top edge light
    d.line([1, 2, 1, H - 2], fill=t[3])
    d.rectangle([3, 3, W - 4, H - 3], fill=t[0])   # dark interior back
    for sy in (12, 22):                            # shelf boards
        d.line([3, sy, W - 4, sy], fill=t[2])
        d.line([3, sy + 1, W - 4, sy + 1], fill=t[1])
    # books: (x, height, color) per shelf, drawn as 2px spines w/ dark edge
    shelves = [(11, ((4, 7, RED), (6, 6, BLUE), (8, 8, DARKGREEN), (10, 7, ORANGE),
                     (12, 6, TEAL), (14, 8, BROWN_PAPER), (16, 7, PURPLE), (18, 6, RED))),
               (21, ((4, 8, TEAL), (6, 7, BROWN_PAPER), (8, 6, RED), (10, 8, PURPLE),
                     (13, 7, DARKGREEN), (15, 6, ORANGE), (17, 7, BLUE))),
               (H - 3, ((4, 7, ORANGE), (6, 8, PURPLE), (8, 6, TEAL), (11, 7, RED),
                        (13, 8, BLUE), (15, 6, BROWN_PAPER)))]
    for bot, books in shelves:
        for x, bh, c in books:
            d.rectangle([x, bot - bh, x + 1, bot - 1], fill=c)
            d.line([x, bot - bh, x, bot - 1], fill=_dark(c))


def draw_tv_stand(d, W, H):
    wd, mt, nv = RAMPS["wood"], RAMPS["metal"], RAMPS["navy"]
    box(d, 0, H - 10, W - 1, H - 2, wd)            # stand cabinet
    d.line([W // 2, H - 9, W // 2, H - 3], fill=wd[0])
    d.point((W // 2 - 3, H - 6), fill=mt[1][3])    # door knobs
    d.point((W // 2 + 2, H - 6), fill=mt[1][3])
    d.rectangle([1, H - 2, 2, H - 1], fill=wd[0])  # feet
    d.rectangle([W - 3, H - 2, W - 2, H - 1], fill=wd[0])
    d.rectangle([W // 2 - 4, H - 12, W // 2 + 3, H - 11], fill=mt[1][1], outline=mt[0])  # tv foot
    box(d, 2, 2, W - 3, H - 13, nv, bevel=False)   # tv bezel
    d.rectangle([4, 4, W - 5, H - 15], fill=nv[1][0])  # dead screen
    d.line([5, 8, 9, 4], fill=nv[1][3])            # short glass glare streak
    d.line([6, 9, 10, 5], fill=nv[1][2])
    d.point((W - 5, H - 14), fill=RED)             # standby led


def draw_kitchen_counter(d, W, H):
    wd, mt, ce = RAMPS["wood"], RAMPS["metal"], RAMPS["ceramic"]
    box(d, 0, 5, W - 1, H - 1, wd)                 # cabinet body
    for x in (3, 19, 35):                          # door panels
        d.rectangle([x, 8, x + 10, H - 3], outline=wd[1][0])
        d.point((x + 9, 11), fill=mt[1][3])        # knob
    d.rectangle([0, 3, W - 1, 5], fill=ce[1][2], outline=ce[0])  # countertop
    d.line([1, 4, W - 2, 4], fill=ce[2])
    d.rectangle([23, 2, 37, 6], fill=mt[1][1], outline=mt[0])    # sink basin
    d.rectangle([25, 3, 35, 5], fill=mt[1][0])     # basin well
    d.line([25, 3, 35, 3], fill=mt[1][2])
    d.rectangle([29, 0, 30, 2], fill=mt[2])        # faucet riser
    d.rectangle([31, 0, 33, 0], fill=mt[2])        # spout
    d.point((33, 1), fill=mt[1][3])
    d.point((28, 0), fill=mt[0])                   # tap shadow side


def draw_wardrobe(d, W, H):
    wd, mt = RAMPS["wood"], RAMPS["metal"]
    o, t, hl = wd
    d.rectangle([0, 0, W - 1, 2], fill=t[3], outline=o)          # crown
    box(d, 1, 2, W - 2, H - 3, wd, bevel=False)
    d.line([2, 3, W - 3, 3], fill=hl)
    d.line([2, 4, 2, H - 4], fill=t[3])
    d.line([W - 3, 4, W - 3, H - 4], fill=t[1])
    d.line([W // 2, 4, W // 2, H - 5], fill=o)                   # door split
    for x0 in (4, W // 2 + 3):                                   # door panels
        d.rectangle([x0, 7, x0 + 9, H - 9], outline=t[1])
    d.rectangle([W // 2 - 3, 20, W // 2 - 3, 25], fill=mt[1][3])  # handles
    d.rectangle([W // 2 + 2, 20, W // 2 + 2, 25], fill=mt[1][3])
    d.rectangle([2, H - 3, 4, H - 1], fill=t[1])                 # feet
    d.rectangle([W - 5, H - 3, W - 3, H - 1], fill=t[1])
    d.rectangle([2, H - 3, 4, H - 3], fill=o)
    d.rectangle([W - 5, H - 3, W - 3, H - 3], fill=o)


def draw_coffee_table(d, W, H):
    wd, ce = RAMPS["wood"], RAMPS["ceramic"]
    box(d, 0, 7, W - 1, 10, wd)                    # tabletop
    d.rectangle([2, 11, 4, H - 1], fill=wd[1][1], outline=wd[0])  # legs
    d.rectangle([W - 5, 11, W - 3, H - 1], fill=wd[1][1], outline=wd[0])
    d.rectangle([4, 4, 11, 6], fill=BROWN_PAPER, outline=OUT)     # magazine
    d.line([5, 5, 10, 5], fill=_dark(BROWN_PAPER, 30))
    d.rectangle([W - 10, 3, W - 6, 6], fill=ce[1][3], outline=OUT)  # mug
    d.point((W - 9, 4), fill=ce[2])
    d.line([W - 5, 4, W - 5, 5], fill=OUT)         # mug handle


# ------------------------------------------------------------------ storage


def draw_dresser(d, W, H):
    wd, mt = RAMPS["wood"], RAMPS["metal"]
    o, t, hl = wd
    box(d, 0, 2, W - 1, H - 3, wd, bevel=False)
    d.line([1, 3, W - 2, 3], fill=hl)
    d.rectangle([0, 0, W - 1, 2], fill=t[3], outline=o)          # top slab
    for i, dy in enumerate((6, 14, 22)):                          # 3 drawers
        d.rectangle([3, dy, W - 4, dy + 6], fill=t[2], outline=t[0])
        d.line([4, dy + 1, W - 5, dy + 1], fill=t[3])
        d.rectangle([W // 2 - 3, dy + 3, W // 2 + 2, dy + 3], fill=mt[1][3])  # handle
        d.rectangle([W // 2 - 3, dy + 4, W // 2 + 2, dy + 4], fill=mt[1][0])
    d.rectangle([1, H - 3, 3, H - 1], fill=t[1])                 # feet
    d.rectangle([W - 4, H - 3, W - 2, H - 1], fill=t[1])


def draw_kitchen_cabinet(d, W, H):
    ce, wd, mt = RAMPS["ceramic"], RAMPS["wood"], RAMPS["metal"]
    box(d, 0, 3, W - 1, H - 1, ce)                 # white cabinet body
    d.rectangle([0, 0, W - 1, 3], fill=wd[1][2], outline=wd[0])  # wood top
    d.line([1, 1, W - 2, 1], fill=wd[2])
    d.line([W // 2, 5, W // 2, H - 3], fill=ce[0])               # door split
    d.rectangle([3, 6, W // 2 - 3, H - 4], outline=ce[1][1])     # door panels
    d.rectangle([W // 2 + 3, 6, W - 4, H - 4], outline=ce[1][1])
    d.point((W // 2 - 3, H // 2 + 1), fill=mt[1][0])             # knobs
    d.point((W // 2 + 2, H // 2 + 1), fill=mt[1][0])


# ------------------------------------------------------------------ clutter


def draw_potted_plant(d, W, H):
    pot_hi, pot, pot_dk = (232, 150, 84), ORANGE, (164, 92, 38)
    d.rectangle([4, 9, 11, 11], fill=pot, outline=OUT)           # rim
    d.line([5, 10, 10, 10], fill=pot_hi)
    d.rectangle([5, 12, 10, H - 1], fill=pot, outline=OUT)       # pot body
    d.line([6, 13, 6, H - 2], fill=pot_hi)
    d.line([9, 13, 9, H - 2], fill=pot_dk)
    d.rectangle([7, 5, 8, 9], fill=DARKGREEN)                    # stem
    for lx, ly in ((4, 3), (8, 1), (11, 4)):                     # leaf clumps
        d.rectangle([lx - 1, ly, lx + 2, ly + 3], fill=DARKGREEN, outline=OUT)
        d.point((lx, ly + 1), fill=GREEN)
        d.point((lx + 1, ly), fill=GREEN)


def draw_book_stack(d, W, H):
    books = ((2, 12, H - 4, RED), (3, 13, H - 7, BLUE),
             (1, 11, H - 10, DARKGREEN), (4, 12, H - 13, BROWN_PAPER))
    for x0, x1, top, c in books:                                 # each book 3px tall
        d.rectangle([x0, top, x1, top + 2], fill=c, outline=_dark(c, 60))
        d.line([x0 + 1, top + 1, x1 - 1, top + 1], fill=c)
        d.point((x1 - 1, top + 1), fill=WHITE)                   # page edge
    d.line([2, H - 1, 13, H - 1], fill=OUT)                      # ground shadow


def draw_microwave(d, W, H):
    mt = RAMPS["metal"]
    box(d, 0, 5, W - 1, H - 2, mt)
    d.rectangle([2, 7, 9, H - 4], fill=(30, 38, 48), outline=mt[1][3])  # door glass
    d.line([3, 8, 8, 8], fill=mt[1][1])                          # glass sheen
    d.point((3, 9), fill=mt[1][0])
    d.line([11, 7, 11, H - 4], fill=mt[1][0])                    # panel divide
    d.point((13, 8), fill=GREEN)                                 # display led
    d.rectangle([12, 10, 14, 10], fill=mt[1][0])                 # buttons
    d.rectangle([12, 12, 14, 12], fill=mt[1][0])
    d.rectangle([1, H - 2, 2, H - 1], fill=mt[0])                # feet
    d.rectangle([W - 3, H - 2, W - 2, H - 1], fill=mt[0])


def draw_dish_stack(d, W, H):
    ce = RAMPS["ceramic"]
    o, t, hl = ce
    for i, top in enumerate((H - 3, H - 5, H - 7, H - 9)):       # plate pile
        x0 = 2 + (i % 2)
        d.rectangle([x0, top, x0 + 11, top + 1], fill=t[1] if i % 2 else t[2], outline=o)
        d.line([x0 + 2, top, x0 + 9, top], fill=hl)              # rim light
        d.point((x0 + 1, top + 1), fill=t[0])                    # curved ends
        d.point((x0 + 10, top + 1), fill=t[0])
    d.rectangle([4, H - 14, 11, H - 10], fill=t[2], outline=o)   # bowl on top
    d.line([4, H - 14, 11, H - 14], fill=BLUE)                   # glazed rim
    d.line([5, H - 11, 10, H - 11], fill=t[0])                   # bowl foot shade
    d.point((5, H - 13), fill=hl)
    d.point((6, H - 13), fill=hl)


# ----------------------------------------------------------------- wall art


def draw_wall_painting(d, W, H):
    wd, nv = RAMPS["wood"], RAMPS["navy"]
    box(d, 0, 0, W - 1, H - 1, wd, bevel=False)                  # frame
    d.line([1, 1, W - 2, 1], fill=wd[2])
    d.line([1, 2, 1, H - 2], fill=wd[1][3])
    d.line([1, H - 2, W - 2, H - 2], fill=wd[1][0])
    d.rectangle([3, 3, W - 4, H - 4], fill=(140, 176, 200))      # sky
    d.rectangle([3, 9, W - 4, H - 4], fill=nv[1][2])             # sea
    d.line([3, 9, W - 4, 9], fill=nv[2])                         # horizon glint
    d.rectangle([6, 4, 8, 6], fill=YELLOW)                       # sun
    d.point((7, 5), fill=(250, 226, 150))
    d.rectangle([18, 8, 23, 9], fill=(94, 62, 38))               # boat hull
    d.point((18, 8), fill=(120, 82, 50))
    d.rectangle([20, 4, 20, 7], fill=OUT)                        # mast
    d.rectangle([21, 5, 22, 7], fill=WHITE)                      # sail
    d.point((22, 5), fill=(190, 190, 186))


def draw_wall_clock(d, W, H):
    ce, mt = RAMPS["ceramic"], RAMPS["metal"]
    d.ellipse([1, 1, 14, 14], fill=ce[1][2], outline=mt[1][0])   # rim
    d.ellipse([3, 3, 12, 12], fill=ce[1][3], outline=ce[1][1])   # face
    d.point((4, 4), fill=ce[2])                                  # face sheen
    for tx, ty in ((7, 4), (11, 7), (7, 11), (4, 7)):            # 12/3/6/9 ticks
        d.point((tx, ty), fill=OUT)
        d.point((tx + 1, ty), fill=OUT)
    d.line([7, 7, 7, 5], fill=OUT)                               # minute hand
    d.line([7, 7, 10, 9], fill=OUT)                              # hour hand
    d.point((7, 7), fill=RED)                                    # hub


# -------------------------------------------------------------------- items

ITEMS = [
    {
        "id": "res_sofa", "name": "Sofa", "category": "furniture",
        "size": [3, 1], "zones": ["residential"], "room_type": "apartment",
        "weight": 18, "tool_tier": 0, "skill": 0, "scrap_time": 3.0, "xp": 6,
        "yields": [{"item": "cloth", "min": 3, "max": 5},
                   {"item": "wood", "min": 2, "max": 4}],
        "draw": draw_sofa,
    },
    {
        "id": "res_bookshelf", "name": "Bookshelf", "category": "furniture",
        "size": [2, 2], "zones": ["residential"], "room_type": "apartment",
        "weight": 14, "tool_tier": 0, "skill": 0, "scrap_time": 2.5, "xp": 5,
        "yields": [{"item": "wood", "min": 4, "max": 6},
                   {"item": "cloth", "min": 1, "max": 3}],
        "draw": draw_bookshelf,
    },
    {
        "id": "res_tv_stand", "name": "TV Stand", "category": "furniture",
        "size": [2, 2], "zones": ["residential"], "room_type": "apartment",
        "weight": 15, "tool_tier": 1, "skill": 1, "scrap_time": 3.0, "xp": 8,
        "yields": [{"item": "scrap_metal", "min": 2, "max": 4},
                   {"item": "plastic", "min": 2, "max": 4},
                   {"item": "wood", "min": 2, "max": 3}],
        "draw": draw_tv_stand,
    },
    {
        "id": "res_kitchen_counter", "name": "Kitchen Counter", "category": "furniture",
        "size": [3, 1], "zones": ["residential"], "room_type": "apartment",
        "weight": 16, "tool_tier": 1, "skill": 0, "scrap_time": 3.0, "xp": 6,
        "yields": [{"item": "wood", "min": 3, "max": 5},
                   {"item": "scrap_metal", "min": 1, "max": 3},
                   {"item": "stone", "min": 1, "max": 2}],
        "draw": draw_kitchen_counter,
    },
    {
        "id": "res_wardrobe", "name": "Wardrobe", "category": "furniture",
        "size": [2, 3], "zones": ["residential"], "room_type": "apartment",
        "weight": 22, "tool_tier": 0, "skill": 0, "scrap_time": 3.5, "xp": 7,
        "yields": [{"item": "wood", "min": 5, "max": 8},
                   {"item": "cloth", "min": 1, "max": 3}],
        "draw": draw_wardrobe,
    },
    {
        "id": "res_coffee_table", "name": "Coffee Table", "category": "furniture",
        "size": [2, 1], "zones": ["residential"], "room_type": "apartment",
        "weight": 8, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "wood", "min": 4, "max": 6}],
        "draw": draw_coffee_table,
    },
    {
        "id": "res_dresser", "name": "Dresser", "category": "furniture",
        "size": [2, 2], "zones": ["residential"], "room_type": "apartment",
        "weight": 16, "tool_tier": 0, "skill": 0, "scrap_time": 2.5, "xp": 6,
        "storage_slots": 8,
        "yields": [{"item": "wood", "min": 4, "max": 6},
                   {"item": "cloth", "min": 2, "max": 3}],
        "draw": draw_dresser,
    },
    {
        "id": "res_kitchen_cabinet", "name": "Kitchen Cabinet", "category": "furniture",
        "size": [2, 1], "zones": ["residential"], "room_type": "apartment",
        "weight": 10, "tool_tier": 0, "skill": 0, "scrap_time": 2.0, "xp": 4,
        "storage_slots": 6,
        "yields": [{"item": "wood", "min": 3, "max": 5},
                   {"item": "plastic", "min": 1, "max": 2}],
        "draw": draw_kitchen_cabinet,
    },
    {
        "id": "res_potted_plant", "name": "Potted Plant", "category": "clutter",
        "size": [1, 1], "zones": ["residential"], "room_type": "apartment",
        "weight": 4, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "stone", "min": 1, "max": 2}],
        "draw": draw_potted_plant,
    },
    {
        "id": "res_book_stack", "name": "Stack of Books", "category": "clutter",
        "size": [1, 1], "zones": ["residential"], "room_type": "apartment",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "cloth", "min": 1, "max": 2}],
        "draw": draw_book_stack,
    },
    {
        "id": "res_microwave", "name": "Microwave", "category": "clutter",
        "size": [1, 1], "zones": ["residential"], "room_type": "apartment",
        "weight": 6, "tool_tier": 1, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 2},
                   {"item": "plastic", "min": 0, "max": 1}],
        "draw": draw_microwave,
    },
    {
        "id": "res_dish_stack", "name": "Stack of Dishes", "category": "clutter",
        "size": [1, 1], "zones": ["residential"], "room_type": "apartment",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "stone", "min": 1, "max": 2}],
        "draw": draw_dish_stack,
    },
    {
        "id": "res_wall_painting", "name": "Framed Painting", "category": "wall_art",
        "size": [2, 1], "zones": ["residential"], "room_type": "apartment",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "wall_mounted": True,
        "yields": [{"item": "wood", "min": 1, "max": 2},
                   {"item": "cloth", "min": 0, "max": 1}],
        "draw": draw_wall_painting,
    },
    {
        "id": "res_wall_clock", "name": "Wall Clock", "category": "wall_art",
        "size": [1, 1], "zones": ["residential"], "room_type": "apartment",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "wall_mounted": True,
        "yields": [{"item": "plastic", "min": 1, "max": 2}],
        "draw": draw_wall_clock,
    },
]
