"""Commercial / retail (storefront floors) room-pack items.

Drowned-city retail flavor: convenience store, boutique, diner counter.
Style per docs/technical/TileArt.md — material ramps, 1px outlines,
light top/left + dark bottom/right shading, no per-pixel noise.
"""
from common import *  # noqa: F401,F403 — palette + box/panel/legs helpers

# Local accent ramps built to the same 5-step law as RAMPS (common.py).
RED_RAMP = ((60, 18, 16), [(120, 36, 30), (150, 48, 40), (178, 62, 50), (200, 84, 68)], (222, 112, 92))
CARD = ((70, 50, 28), [(140, 114, 76), (166, 138, 94), (188, 160, 112), (204, 178, 132)], (220, 196, 152))
WHITE_RAMP = (OUT, [(150, 150, 150), (180, 180, 180), (205, 205, 205), (225, 225, 225)], (240, 240, 240))

GLASS_EDGE = (110, 150, 170)
GLASS_FILL = (176, 206, 220, 44)
GLASS_SHINE = (222, 240, 250, 170)
CHALK = (222, 224, 214)
NEON = (244, 116, 138)
NEON_DIM = (140, 56, 74)


def _lighten(c, k=36):
    return tuple(min(255, v + k) for v in c[:3])


def _darken(c, k=36):
    return tuple(max(0, v - k) for v in c[:3])


def _product(d, x, y, w, h, color):
    """Small shaded product box: fill, outline, 1px light top edge."""
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=color, outline=OUT)
    if w > 2 and h > 2:
        d.line([x + 1, y + 1, x + w - 2, y + 1], fill=_lighten(color))


def _can(d, x, y, label):
    """4x6 tin can: metal rim top, colored label with a darker band."""
    m = RAMPS["metal"]
    d.rectangle([x, y, x + 3, y + 5], fill=label, outline=OUT)
    d.line([x + 1, y + 1, x + 2, y + 1], fill=m[1][3])       # metal rim
    d.line([x + 1, y + 3, x + 2, y + 3], fill=_darken(label))  # label band


# ---- 5x5 neon letters ----------------------------------------------------

def _neon_O(d, x, y, c):
    d.rectangle([x, y, x + 3, y + 4], outline=c)


def _neon_P(d, x, y, c):
    d.line([x, y, x, y + 4], fill=c)
    d.line([x, y, x + 3, y], fill=c)
    d.point((x + 3, y + 1), fill=c)
    d.line([x, y + 2, x + 3, y + 2], fill=c)


def _neon_E(d, x, y, c):
    d.line([x, y, x, y + 4], fill=c)
    d.line([x, y, x + 3, y], fill=c)
    d.line([x, y + 2, x + 2, y + 2], fill=c)
    d.line([x, y + 4, x + 3, y + 4], fill=c)


def _neon_N(d, x, y, c):
    d.line([x, y, x, y + 4], fill=c)
    d.line([x + 3, y, x + 3, y + 4], fill=c)
    d.point((x + 1, y + 1), fill=c)
    d.point((x + 1, y + 2), fill=c)
    d.point((x + 2, y + 2), fill=c)
    d.point((x + 2, y + 3), fill=c)


# ---- furniture -----------------------------------------------------------

def draw_counter(d, W, H):
    wood, metal = RAMPS["wood"], RAMPS["metal"]
    # cabinet body + kickplate
    box(d, 1, 15, W - 2, H - 1, wood)
    d.line([2, H - 3, W - 3, H - 3], fill=wood[1][0])
    for x in (16, 32):                                   # front panel seams
        d.line([x, 17, x, H - 4], fill=wood[1][0])
        d.line([x + 1, 17, x + 1, H - 4], fill=wood[1][3])
    # countertop slab
    box(d, 0, 11, W - 1, 14, wood)
    d.line([1, 12, W - 2, 12], fill=wood[2])
    # cash register (metal, on the right of the top)
    box(d, 30, 1, 44, 11, metal)
    panel(d, 31, 2, 36, 6, (26, 38, 32))                 # screen
    d.line([32, 4, 35, 4], fill=GREEN)                   # readout
    for ky in (8, 10):                                    # key rows
        for kx in (38, 40, 42):
            d.point((kx, ky), fill=metal[2])
    d.line([31, 9, 36, 9], fill=metal[1][0])             # drawer seam
    # small basket of goods on the left of the counter
    _product(d, 4, 6, 6, 5, ORANGE)
    _product(d, 11, 8, 5, 3, BLUE)


def draw_gondola(d, W, H):
    metal = RAMPS["metal"]
    panel(d, 2, 1, W - 3, H - 3, metal[1][0], outline=metal[0])  # back panel
    panel(d, 2, 1, W - 3, 5, ORANGE, top=_lighten(ORANGE))       # header sign
    box(d, 1, H - 4, W - 2, H - 1, metal)                        # base deck
    for sy in (16, 28, 40):                                       # shelves
        d.rectangle([2, sy, W - 3, sy + 1], fill=metal[1][3], outline=metal[0])
    # products per shelf (light top edge each, no noise)
    _product(d, 4, 9, 5, 7, RED)
    _product(d, 10, 11, 5, 5, YELLOW)
    _product(d, 16, 9, 5, 7, BLUE)
    _product(d, 22, 12, 6, 4, GREEN)
    _product(d, 4, 22, 6, 6, TEAL)
    _product(d, 11, 24, 5, 4, PINK)
    _product(d, 17, 22, 5, 6, ORANGE)
    _product(d, 23, 24, 5, 4, RED)
    _product(d, 4, 35, 5, 5, BLUE)
    _product(d, 10, 33, 6, 7, YELLOW)
    _product(d, 17, 35, 5, 5, GREEN)
    _product(d, 23, 33, 5, 7, PURPLE)


def draw_vending(d, W, H):
    metal = RAMPS["metal"]
    box(d, 1, 0, W - 2, H - 1, metal)
    panel(d, 3, 2, W - 4, 6, RED, top=_lighten(RED))              # brand stripe
    d.line([6, 4, 12, 4], fill=WHITE)                              # logo dash
    panel(d, 4, 8, 20, 31, (28, 36, 52))                           # window
    rows = [(RED, YELLOW, BLUE), (GREEN, ORANGE, RED), (BLUE, PINK, YELLOW)]
    for i, row in enumerate(rows):
        ry = 10 + i * 7
        for j, c in enumerate(row):
            d.rectangle([6 + j * 5, ry, 9 + j * 5, ry + 4], fill=c, outline=OUT)
            d.point((7 + j * 5, ry + 1), fill=_lighten(c))
        d.line([5, ry + 5, 19, ry + 5], fill=(52, 64, 84))         # shelf lip
    d.line([18, 9, 15, 12], fill=(150, 190, 210))                  # glass shine
    # selection panel
    panel(d, 23, 8, 28, 22, metal[1][0], top=metal[1][3])
    for by in (10, 13, 16):
        d.rectangle([24, by, 27, by + 1], fill=metal[1][3])        # buttons
    d.rectangle([25, 19, 26, 21], fill=(20, 24, 30))               # coin slot
    d.point((24, 24), fill=GREEN)                                  # power led
    panel(d, 4, 35, 20, 42, metal[1][0], top=metal[1][3])          # dispenser
    d.rectangle([6, 37, 18, 41], fill=(20, 24, 30))
    d.rectangle([2, H - 3, 5, H - 1], fill=metal[1][0], outline=metal[0])
    d.rectangle([W - 6, H - 3, W - 3, H - 1], fill=metal[1][0], outline=metal[0])


def draw_display_case(d, W, H):
    wood = RAMPS["wood"]
    box(d, 1, 20, W - 2, H - 1, wood)                              # wood base
    d.line([2, H - 3, W - 3, H - 3], fill=wood[1][0])
    # glass hood
    d.rectangle([2, 3, W - 3, 20], fill=GLASS_FILL, outline=GLASS_EDGE)
    d.line([3, 4, W - 4, 4], fill=GLASS_SHINE)                     # top shine
    d.line([8, 11, 13, 6], fill=GLASS_SHINE)                       # diagonal
    d.rectangle([3, 13, W - 4, 14], fill=wood[1][2], outline=wood[0])  # shelf
    # prized goods: rings, gem, watch
    d.rectangle([9, 10, 11, 12], outline=YELLOW)                   # ring
    d.point((10, 9), fill=_lighten(YELLOW, 60))
    d.polygon([(21, 12), (24, 8), (27, 12)], fill=PINK, outline=OUT)
    d.point((24, 10), fill=_lighten(PINK, 50))
    d.rectangle([33, 9, 37, 12], fill=WHITE, outline=OUT)          # watch face
    d.point((35, 10), fill=BLUE)
    d.rectangle([14, 16, 20, 19], fill=RED, outline=OUT)           # cushion box
    d.line([15, 17, 19, 17], fill=_lighten(RED))
    d.rectangle([28, 16, 34, 19], fill=NAVY_CUSHION, outline=OUT)
    d.line([29, 17, 33, 17], fill=_lighten(NAVY_CUSHION))


NAVY_CUSHION = (58, 76, 108)


def draw_clothes_rack(d, W, H):
    metal = RAMPS["metal"]
    d.rectangle([2, 2, 3, H - 3], fill=metal[1][2], outline=metal[0])   # posts
    d.rectangle([W - 4, 2, W - 3, H - 3], fill=metal[1][2], outline=metal[0])
    d.rectangle([1, 2, W - 2, 3], fill=metal[1][3], outline=metal[0])   # bar
    d.rectangle([0, H - 3, 6, H - 1], fill=metal[1][1], outline=metal[0])   # feet
    d.rectangle([W - 7, H - 3, W - 1, H - 1], fill=metal[1][1], outline=metal[0])
    for x, c in ((6, RED), (14, BLUE), (22, DARKGREEN)):
        d.point((x + 3, 4), fill=metal[2])                          # hanger hook
        d.polygon([(x + 3, 5), (x, 8), (x + 6, 8)], outline=metal[1][0])  # hanger
        d.rectangle([x, 8, x + 6, 18], fill=c, outline=OUT)         # shirt body
        d.line([x + 1, 9, x + 5, 9], fill=_lighten(c))              # shoulders
        d.line([x + 1, 10, x + 1, 13], fill=_darken(c))             # sleeve L
        d.line([x + 5, 10, x + 5, 13], fill=_darken(c))             # sleeve R
        d.point((x + 3, 10), fill=_darken(c))                       # collar
        d.line([x + 1, 17, x + 5, 17], fill=_darken(c))             # hem


def draw_booth(d, W, H):
    metal, wood = RAMPS["metal"], RAMPS["wood"]
    # bench: tall back + seat cushion + wood base
    box(d, 1, 3, 9, 20, RED_RAMP)
    d.line([5, 5, 5, 18], fill=RED_RAMP[1][0])                     # tuft seam
    box(d, 1, 19, 15, 25, RED_RAMP)
    panel(d, 2, 26, 14, H - 1, wood[1][1], top=wood[1][3])
    # table on a metal pedestal
    box(d, 17, 13, W - 2, 17, WHITE_RAMP)
    d.rectangle([30, 18, 33, H - 3], fill=RAMPS["metal"][1][1], outline=metal[0])
    d.rectangle([26, H - 3, 37, H - 1], fill=metal[1][2], outline=metal[0])
    # ketchup + napkin holder
    d.rectangle([21, 8, 23, 12], fill=RED, outline=OUT)
    d.point((22, 7), fill=RED_RAMP[1][0])
    d.rectangle([38, 9, 43, 12], fill=metal[1][3], outline=metal[0])
    d.line([39, 10, 42, 10], fill=WHITE)


# ---- storage -------------------------------------------------------------

def draw_stock_shelf(d, W, H):
    metal = RAMPS["metal"]
    d.rectangle([1, 0, 2, H - 1], fill=metal[1][1], outline=metal[0])   # uprights
    d.rectangle([W - 3, 0, W - 2, H - 1], fill=metal[1][1], outline=metal[0])
    for sy in (14, 30, H - 3):                                          # shelves
        d.rectangle([1, sy, W - 2, sy + 2], fill=metal[1][2], outline=metal[0])
        d.line([2, sy + 1, W - 3, sy + 1], fill=metal[1][3])
    # cardboard boxes, some navy crates — light top edges, tape stripes
    for x, y, w, h in ((5, 5, 10, 9), (17, 7, 8, 7), (27, 3, 12, 11)):
        box(d, x, y, x + w, y + h, CARD)
        d.line([x + w // 2, y + 1, x + w // 2, y + h - 1], fill=CARD[1][0])
    box(d, 5, 21, 16, 29, CARD)
    d.line([10, 22, 10, 28], fill=CARD[1][0])
    box(d, 19, 23, 28, 29, RAMPS["navy"])
    box(d, 31, 20, 41, 29, CARD)
    d.line([36, 21, 36, 28], fill=CARD[1][0])
    box(d, 6, 37, 14, 44, RAMPS["navy"])
    box(d, 17, 35, 29, 44, CARD)
    d.line([23, 36, 23, 43], fill=CARD[1][0])
    _product(d, 33, 38, 7, 6, TEAL)


def draw_undercounter(d, W, H):
    wood, metal = RAMPS["wood"], RAMPS["metal"]
    box(d, 0, 1, W - 1, H - 1, wood)
    d.line([W // 2, 3, W // 2, H - 3], fill=wood[1][0])            # door seam
    d.line([W // 2 + 1, 3, W // 2 + 1, H - 3], fill=wood[1][3])
    d.rectangle([W // 2 - 4, 7, W // 2 - 3, 9], fill=metal[1][3])  # handles
    d.rectangle([W // 2 + 3, 7, W // 2 + 4, 9], fill=metal[1][3])
    d.line([1, 2, W - 2, 2], fill=wood[2])                          # top edge


# ---- clutter (1x1) -------------------------------------------------------

def draw_basket(d, W, H):
    r = RED_RAMP
    d.line([5, 2, 10, 2], fill=r[1][0])                             # handle
    d.line([4, 3, 4, 6], fill=r[1][0]); d.line([11, 3, 11, 6], fill=r[1][0])
    d.polygon([(2, 7), (13, 7), (12, 14), (3, 14)], fill=r[1][2], outline=r[0])
    d.line([3, 8, 12, 8], fill=r[1][3])                             # rim light
    for x in (5, 8, 10):                                            # lattice
        d.line([x, 9, x, 13], fill=r[1][0])
    d.line([4, 11, 11, 11], fill=r[1][0])


def draw_cans(d, W, H):
    _can(d, 1, 9, RED)                                              # bottom row
    _can(d, 6, 9, GREEN)
    _can(d, 11, 9, YELLOW)
    _can(d, 3, 3, BLUE)                                             # top row
    _can(d, 8, 3, ORANGE)
    d.line([1, 15, 14, 15], fill=OUT)                               # ground shadow


def draw_cardboard_box(d, W, H):
    box(d, 1, 5, 14, 15, CARD)
    d.rectangle([7, 6, 8, 14], fill=CARD[1][0])                     # tape stripe
    d.polygon([(1, 5), (5, 2), (8, 5)], fill=CARD[1][3], outline=CARD[0])   # flap
    d.polygon([(8, 5), (11, 3), (14, 5)], fill=CARD[1][1], outline=CARD[0])
    d.line([3, 8, 6, 8], fill=CARD[1][0])                           # label scrawl


# ---- wall art ------------------------------------------------------------

def draw_open_sign(d, W, H):
    panel(d, 0, 1, W - 1, 14, (24, 28, 42), outline=OUT)
    d.rectangle([2, 3, W - 3, 12], outline=NEON_DIM)                # neon border
    c = NEON
    _neon_O(d, 5, 5, c)
    _neon_P(d, 11, 5, c)
    _neon_E(d, 17, 5, c)
    _neon_N(d, 23, 5, c)
    d.point((6, 6), fill=(255, 190, 200))                           # hot spots
    d.point((24, 6), fill=(255, 190, 200))


def draw_menu_board(d, W, H):
    wood = RAMPS["wood"]
    box(d, 0, 0, W - 1, H - 1, wood)
    panel(d, 3, 3, W - 4, H - 4, (32, 40, 36))                      # chalk board
    d.line([5, 5, 14, 5], fill=YELLOW)                              # header
    for y in (8, 11):                                               # menu lines
        d.line([5, y, 15, y], fill=CHALK)
        d.line([22, y, 26, y], fill=CHALK)                          # prices
    d.line([5, 13, 11, 13], fill=CHALK)


def draw_poster(d, W, H):
    d.rectangle([2, 1, 13, 14], fill=(222, 218, 202), outline=OUT)
    d.line([3, 2, 12, 2], fill=(240, 238, 226))                     # top light
    d.rectangle([3, 4, 12, 7], fill=RED)                            # SALE band
    for x in (4, 6, 8, 10):
        d.line([x, 5, x, 6], fill=WHITE)                            # letters
    d.point((5, 10), fill=RED); d.point((9, 12), fill=RED)          # % mark
    d.line([9, 10, 5, 12], fill=RED)
    d.point((3, 2), fill=OUT); d.point((12, 2), fill=OUT)           # pins
    d.polygon([(13, 12), (13, 14), (11, 14)], fill=(150, 144, 128))  # curl


ITEMS = [
    {
        "id": "ret_counter", "name": "Checkout Counter", "category": "furniture",
        "size": [3, 2], "zones": ["commercial"], "room_type": "retail",
        "weight": 20, "tool_tier": 0, "skill": 0, "scrap_time": 3.0, "xp": 6,
        "yields": [{"item": "wood", "min": 4, "max": 6}, {"item": "scrap_metal", "min": 1, "max": 3},
                   {"item": "plastic", "min": 1, "max": 2}],
        "draw": draw_counter,
    },
    {
        "id": "ret_gondola", "name": "Shelf Gondola", "category": "furniture",
        "size": [2, 3], "zones": ["commercial"], "room_type": "retail",
        "weight": 16, "tool_tier": 0, "skill": 0, "scrap_time": 2.5, "xp": 5,
        "yields": [{"item": "scrap_metal", "min": 3, "max": 5}, {"item": "plastic", "min": 2, "max": 4}],
        "draw": draw_gondola,
    },
    {
        "id": "ret_vending", "name": "Vending Machine", "category": "furniture",
        "size": [2, 3], "zones": ["commercial"], "room_type": "retail",
        "weight": 28, "tool_tier": 1, "skill": 0, "scrap_time": 4.0, "xp": 8,
        "yields": [{"item": "scrap_metal", "min": 5, "max": 7}, {"item": "plastic", "min": 2, "max": 4},
                   {"item": "iron", "min": 1, "max": 2}],
        "draw": draw_vending,
    },
    {
        "id": "ret_display_case", "name": "Display Case", "category": "furniture",
        "size": [3, 2], "zones": ["commercial"], "room_type": "retail",
        "weight": 18, "tool_tier": 0, "skill": 1, "scrap_time": 3.0, "xp": 8,
        "yields": [{"item": "wood", "min": 3, "max": 5}, {"item": "scrap_metal", "min": 2, "max": 3},
                   {"item": "iron", "min": 0, "max": 1}],
        "draw": draw_display_case,
    },
    {
        "id": "ret_clothes_rack", "name": "Clothing Rack", "category": "furniture",
        "size": [2, 2], "zones": ["commercial"], "room_type": "retail",
        "weight": 10, "tool_tier": 0, "skill": 0, "scrap_time": 2.0, "xp": 4,
        "yields": [{"item": "scrap_metal", "min": 2, "max": 3}, {"item": "cloth", "min": 3, "max": 5}],
        "draw": draw_clothes_rack,
    },
    {
        "id": "ret_booth", "name": "Diner Booth", "category": "furniture",
        "size": [3, 2], "zones": ["commercial"], "room_type": "retail",
        "weight": 18, "tool_tier": 0, "skill": 0, "scrap_time": 3.0, "xp": 6,
        "yields": [{"item": "wood", "min": 2, "max": 4}, {"item": "cloth", "min": 3, "max": 5},
                   {"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_booth,
    },
    {
        "id": "ret_stock_shelf", "name": "Stockroom Shelf", "category": "furniture",
        "size": [3, 3], "zones": ["commercial"], "room_type": "retail",
        "weight": 24, "tool_tier": 1, "skill": 0, "scrap_time": 3.5, "xp": 7,
        "yields": [{"item": "scrap_metal", "min": 4, "max": 6}, {"item": "wood", "min": 2, "max": 4},
                   {"item": "plastic", "min": 1, "max": 2}],
        "storage_slots": 10,
        "draw": draw_stock_shelf,
    },
    {
        "id": "ret_undercounter", "name": "Under-Counter Storage", "category": "furniture",
        "size": [2, 1], "zones": ["commercial"], "room_type": "retail",
        "weight": 8, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "wood", "min": 3, "max": 5}, {"item": "scrap_metal", "min": 0, "max": 1}],
        "storage_slots": 6,
        "draw": draw_undercounter,
    },
    {
        "id": "ret_basket", "name": "Shopping Basket", "category": "clutter",
        "size": [1, 1], "zones": ["commercial"], "room_type": "retail",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "plastic", "min": 1, "max": 2}],
        "draw": draw_basket,
    },
    {
        "id": "ret_cans", "name": "Canned Goods Stack", "category": "clutter",
        "size": [1, 1], "zones": ["commercial"], "room_type": "retail",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 3}],
        "draw": draw_cans,
    },
    {
        "id": "ret_box", "name": "Cardboard Box", "category": "clutter",
        "size": [1, 1], "zones": ["commercial"], "room_type": "retail",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "cloth", "min": 1, "max": 2}],
        "draw": draw_cardboard_box,
    },
    {
        "id": "ret_open_sign", "name": "Neon OPEN Sign", "category": "wall_art",
        "size": [2, 1], "zones": ["commercial"], "room_type": "retail",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 4,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 2}, {"item": "plastic", "min": 1, "max": 2}],
        "wall_mounted": True,
        "draw": draw_open_sign,
    },
    {
        "id": "ret_menu_board", "name": "Menu Board", "category": "wall_art",
        "size": [2, 1], "zones": ["commercial"], "room_type": "retail",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "wood", "min": 1, "max": 3}],
        "wall_mounted": True,
        "draw": draw_menu_board,
    },
    {
        "id": "ret_poster", "name": "Sale Poster", "category": "wall_art",
        "size": [1, 1], "zones": ["commercial"], "room_type": "retail",
        "weight": 1, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "cloth", "min": 1, "max": 1}],
        "wall_mounted": True,
        "draw": draw_poster,
    },
]
