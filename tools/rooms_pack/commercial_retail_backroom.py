"""Commercial / retail back-room + shop-floor extras room-pack items.

Complements commercial_retail.py (counter, gondola, vending, ...): the things
a drowned convenience store or boutique still has lying around — carts,
freezers, mannequins, the cash machine, aisle signage.
Style per docs/technical/TileArt.md — material ramps, 1px outlines,
light top/left + dark bottom/right shading, no per-pixel noise.
"""
from common import *  # noqa: F401,F403 — palette + box/panel/legs helpers

# Local accent ramps built to the same 5-step law as RAMPS (common.py).
RED_RAMP = ((60, 18, 16), [(120, 36, 30), (150, 48, 40), (178, 62, 50), (200, 84, 68)], (222, 112, 92))
CARD = ((70, 50, 28), [(140, 114, 76), (166, 138, 94), (188, 160, 112), (204, 178, 132)], (220, 196, 152))
WHITE_RAMP = (OUT, [(150, 150, 150), (180, 180, 180), (205, 205, 205), (225, 225, 225)], (240, 240, 240))
BEIGE = ((60, 50, 40), [(150, 138, 110), (176, 164, 134), (200, 188, 158), (214, 204, 178)], (230, 222, 200))
SKIN = ((70, 58, 52), [(176, 160, 148), (196, 182, 170), (214, 202, 192), (228, 218, 210)], (240, 232, 226))
SIGN_BLUE = ((18, 30, 60), [(40, 70, 130), (52, 90, 160), (66, 110, 186), (86, 130, 204)], (120, 164, 224))

SCREEN = (26, 38, 32)
SCREEN_TEXT = (110, 210, 120)
TYRE = (34, 34, 38)
WRAP_EDGE = (150, 190, 210)
WRAP_SHINE = (222, 240, 250)
LED_RED = (240, 70, 60)


def _lighten(c, k=36):
    return tuple(min(255, v + k) for v in c[:3])


def _darken(c, k=36):
    return tuple(max(0, v - k) for v in c[:3])


def _product(d, x, y, w, h, color):
    """Small shaded product box: fill, outline, 1px light top edge."""
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=color, outline=OUT)
    if w > 2 and h > 2:
        d.line([x + 1, y + 1, x + w - 2, y + 1], fill=_lighten(color))


def _cover(d, x, y, w, h, color):
    """Magazine cover: coloured card, light top edge, white title, darker photo."""
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=color, outline=OUT)
    d.line([x + 1, y + 1, x + w - 2, y + 1], fill=_lighten(color))
    d.line([x + 1, y + 2, x + w - 2, y + 2], fill=WHITE)                 # title
    d.rectangle([x + 1, y + 4, x + w - 2, y + h - 2], fill=_darken(color))  # photo


def _wheel(d, x, y):
    """4x4 caster: dark tyre, metal hub, one highlight pixel."""
    m = RAMPS["metal"]
    d.rectangle([x, y, x + 3, y + 3], fill=TYRE, outline=OUT)
    d.point((x + 1, y + 1), fill=m[1][3])
    d.point((x + 2, y + 2), fill=m[1][1])


# ---- furniture -----------------------------------------------------------

def draw_shopping_cart(d, W, H):
    m = RAMPS["metal"]
    # wire basket: trapezoid, dark fill with a lighter wire lattice on top
    d.polygon([(3, 9), (26, 9), (24, 21), (5, 21)], fill=m[1][0], outline=m[0])
    for x in (7, 10, 13, 16, 19, 22):                                # vertical wires
        d.line([x, 10, x, 20], fill=m[1][2])
    for y in (13, 17):                                               # horizontal wires
        d.line([6, y, 23, y], fill=m[1][2])
    d.line([4, 10, 25, 10], fill=m[2])                               # rim highlight
    d.line([5, 20, 24, 20], fill=m[1][1])                            # basket floor
    # goods poking above the rim
    _product(d, 8, 5, 6, 5, YELLOW)
    _product(d, 15, 6, 5, 4, BLUE)
    # handle post + red grip
    d.rectangle([26, 5, 27, 9], fill=m[1][2], outline=m[0])
    box(d, 23, 3, 31, 5, RED_RAMP, bevel=False)
    d.line([24, 4, 30, 4], fill=RED_RAMP[1][3])
    # undercarriage: two struts, a lower tray bar, casters
    d.rectangle([7, 21, 8, 27], fill=m[1][1], outline=m[0])
    d.rectangle([21, 21, 22, 27], fill=m[1][1], outline=m[0])
    d.rectangle([6, 24, 23, 25], fill=m[1][2], outline=m[0])
    _wheel(d, 4, H - 4)
    _wheel(d, 22, H - 4)


def draw_chest_freezer(d, W, H):
    w = WHITE_RAMP
    box(d, 0, 2, W - 1, H - 1, w)
    # lid: light top face, dark seam, lighter lip below it
    d.rectangle([1, 3, W - 2, 6], fill=w[1][3])
    d.line([1, 3, W - 2, 3], fill=w[2])
    d.line([1, 7, W - 2, 7], fill=w[1][0])                           # lid seam
    d.line([1, 8, W - 2, 8], fill=w[2])
    d.rectangle([12, 5, 19, 6], fill=(60, 64, 70), outline=OUT)      # lid handle
    # logo strip (blue) with a white dash
    panel(d, 3, 10, 12, 12, BLUE, top=_lighten(BLUE))
    d.line([5, 11, 9, 11], fill=WHITE)
    # vent grille bottom right
    for y in (11, 13):
        d.line([22, y, 28, y], fill=w[1][0])
    d.line([1, H - 2, W - 2, H - 2], fill=w[1][0])                   # base shadow


def draw_mannequin(d, W, H):
    s, m = SKIN, RAMPS["metal"]
    # head + neck
    d.rectangle([6, 1, 10, 5], fill=s[1][2], outline=s[0])
    d.line([7, 1, 9, 1], fill=s[1][3])
    d.point((7, 2), fill=s[2])
    d.rectangle([7, 6, 9, 7], fill=s[1][1], outline=s[0])
    # torso in a coloured shirt with short sleeves
    d.rectangle([4, 8, 11, 18], fill=BLUE, outline=OUT)
    d.line([5, 9, 10, 9], fill=_lighten(BLUE))                       # shoulders
    d.rectangle([2, 8, 4, 12], fill=_darken(BLUE), outline=OUT)      # sleeves
    d.rectangle([11, 8, 13, 12], fill=_darken(BLUE), outline=OUT)
    d.point((7, 9), fill=_darken(BLUE)); d.point((8, 9), fill=_darken(BLUE))  # collar
    d.line([5, 17, 10, 17], fill=_darken(BLUE))                      # hem
    # forearms below the sleeves
    d.rectangle([2, 13, 3, 17], fill=s[1][1], outline=s[0])
    d.rectangle([12, 13, 13, 17], fill=s[1][1], outline=s[0])
    # hips
    d.rectangle([5, 19, 10, 23], fill=s[1][2], outline=s[0])
    d.line([6, 20, 9, 20], fill=s[1][3])
    # stand: metal pole + base disc
    d.rectangle([7, 24, 8, 28], fill=m[1][2], outline=m[0])
    box(d, 2, H - 3, W - 3, H - 1, m)


def draw_atm(d, W, H):
    m = RAMPS["metal"]
    box(d, 1, 0, W - 2, H - 1, m)
    panel(d, 2, 1, W - 3, 3, BLUE, top=_lighten(BLUE))               # brand header
    d.line([5, 2, 10, 2], fill=WHITE)
    panel(d, 3, 6, 12, 13, SCREEN)                                   # screen
    d.line([4, 8, 9, 8], fill=SCREEN_TEXT)
    d.line([4, 10, 11, 10], fill=SCREEN_TEXT)
    d.point((11, 7), fill=(150, 190, 210))                           # glass glint
    # keypad (3x3) + card slot with a green LED
    for ky in (16, 18, 20):
        for kx in (3, 5, 7):
            d.point((kx, ky), fill=m[1][3])
            d.point((kx + 1, ky + 1), fill=m[1][0])
    d.rectangle([10, 16, 12, 17], fill=(20, 24, 30), outline=OUT)    # card slot
    d.point((11, 20), fill=GREEN)                                    # LED
    # cash dispenser
    panel(d, 3, 24, 12, 27, m[1][0], top=m[1][3])
    d.rectangle([4, 25, 11, 26], fill=(20, 24, 30))
    d.line([2, H - 2, W - 3, H - 2], fill=m[1][0])                   # base shadow


def draw_magazine_rack(d, W, H):
    m = RAMPS["metal"]
    d.rectangle([0, 0, 1, H - 1], fill=m[1][2], outline=m[0])        # uprights
    d.rectangle([W - 2, 0, W - 1, H - 1], fill=m[1][2], outline=m[0])
    d.rectangle([0, 0, W - 1, 1], fill=m[1][2], outline=m[0])        # top rail
    # three tiers of covers, each on a wire lip
    tiers = [(3, RED, TEAL), (12, YELLOW, PURPLE), (21, BLUE, PINK)]
    for y, c1, c2 in tiers:
        _cover(d, 2, y, 5, 8, c1)
        _cover(d, 9, y, 5, 8, c2)
        d.rectangle([1, y + 8, W - 2, y + 8], fill=m[1][3])          # wire lip
    d.rectangle([0, H - 3, W - 1, H - 1], fill=m[1][1], outline=m[0])  # base rail


def draw_pallet_goods(d, W, H):
    wood = RAMPS["wood"]
    # boxes: two on the bottom, two smaller on top
    box(d, 2, 6, 15, 11, CARD)
    d.line([8, 7, 8, 10], fill=CARD[1][0])                           # tape stripes
    box(d, 17, 6, 29, 11, CARD)
    d.line([23, 7, 23, 10], fill=CARD[1][0])
    box(d, 4, 1, 14, 5, CARD)
    d.line([9, 2, 9, 4], fill=CARD[1][0])
    box(d, 16, 1, 27, 5, RAMPS["navy"])
    # shrink-wrap: pale outline around the stack + two shine streaks
    d.rectangle([1, 0, 30, 11], outline=WRAP_EDGE)
    d.line([5, 4, 8, 1], fill=WRAP_SHINE)
    d.line([20, 10, 25, 5], fill=WRAP_SHINE)
    # pallet: deck boards + three bearer blocks
    d.rectangle([0, 12, W - 1, 13], fill=wood[1][2], outline=wood[0])
    d.line([1, 12, W - 2, 12], fill=wood[1][3])
    for x in (1, 14, 27):
        d.rectangle([x, 14, x + 3, 15], fill=wood[1][1], outline=wood[0])


# ---- clutter (1x1) -------------------------------------------------------

def draw_cash_register(d, W, H):
    b = BEIGE
    # body + drawer
    box(d, 1, 8, 14, H - 1, b)
    d.line([2, 12, 13, 12], fill=b[1][0])                            # drawer seam
    d.rectangle([2, 13, 13, 14], fill=b[1][1])                       # drawer front
    d.rectangle([6, 13, 9, 14], fill=b[1][0])                        # handle
    # keys on the top face
    for kx in (3, 5):
        d.point((kx, 10), fill=b[1][0])
        d.point((kx + 1, 10), fill=b[2])
    # display on a stalk
    box(d, 7, 2, 13, 7, RAMPS["metal"])
    d.rectangle([8, 3, 12, 6], fill=SCREEN)
    d.line([9, 4, 11, 4], fill=SCREEN_TEXT)
    # receipt curl
    d.rectangle([3, 5, 5, 8], fill=WHITE, outline=OUT)


# ---- wall art ------------------------------------------------------------

def draw_security_camera(d, W, H):
    m = RAMPS["metal"]
    d.rectangle([0, 2, 2, 9], fill=m[1][1], outline=m[0])            # wall plate
    d.rectangle([3, 5, 5, 6], fill=m[1][0], outline=m[0])            # arm
    box(d, 5, 3, 14, 10, m)                                          # camera body
    d.rectangle([12, 4, 14, 9], fill=m[1][0], outline=m[0])          # lens hood
    d.rectangle([13, 6, 14, 7], fill=(20, 24, 30))                   # lens
    d.point((13, 6), fill=(150, 190, 210))                           # glass glint
    d.point((7, 5), fill=LED_RED)                                    # recording LED
    d.line([7, 8, 10, 8], fill=m[1][0])                              # vent line
    d.line([6, 11, 12, 12], fill=OUT)                                # wall shadow


def draw_aisle_sign(d, W, H):
    s = SIGN_BLUE
    m = RAMPS["metal"]
    d.line([6, 0, 6, 3], fill=m[1][3])                               # hanging chains
    d.line([25, 0, 25, 3], fill=m[1][3])
    box(d, 1, 3, W - 2, H - 2, s)
    # white "7"
    d.rectangle([5, 5, 10, 6], fill=WHITE)
    for i, x in enumerate((10, 9, 9, 8, 8, 7)):
        d.rectangle([x - 1, 7 + i, x, 7 + i], fill=WHITE)
    # white right-pointing arrow
    d.rectangle([15, 8, 23, 9], fill=WHITE)
    d.polygon([(23, 5), (28, 8), (28, 9), (23, 12)], fill=WHITE)
    d.line([2, H - 1, W - 3, H - 1], fill=OUT)                       # bottom shadow


ITEMS = [
    {
        "id": "ret_shopping_cart", "name": "Shopping Cart", "category": "furniture",
        "size": [2, 2], "zones": ["commercial"], "room_type": "retail",
        "weight": 10, "tool_tier": 0, "skill": 0, "scrap_time": 2.0, "xp": 4,
        "yields": [{"item": "scrap_metal", "min": 2, "max": 4}, {"item": "plastic", "min": 1, "max": 2}],
        "draw": draw_shopping_cart,
    },
    {
        "id": "ret_chest_freezer", "name": "Chest Freezer", "category": "furniture",
        "size": [2, 1], "zones": ["commercial"], "room_type": "retail",
        "weight": 14, "tool_tier": 1, "skill": 0, "scrap_time": 2.5, "xp": 5,
        "yields": [{"item": "scrap_metal", "min": 3, "max": 5}, {"item": "plastic", "min": 1, "max": 3}],
        "storage_slots": 6,
        "draw": draw_chest_freezer,
    },
    {
        "id": "ret_mannequin", "name": "Mannequin", "category": "furniture",
        "size": [1, 2], "zones": ["commercial"], "room_type": "retail",
        "weight": 6, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "plastic", "min": 2, "max": 4}, {"item": "cloth", "min": 1, "max": 2}],
        "draw": draw_mannequin,
    },
    {
        "id": "ret_atm", "name": "Cash Machine", "category": "furniture",
        "size": [1, 2], "zones": ["commercial"], "room_type": "retail",
        "weight": 18, "tool_tier": 1, "skill": 1, "scrap_time": 3.0, "xp": 7,
        "yields": [{"item": "scrap_metal", "min": 3, "max": 5}, {"item": "plastic", "min": 1, "max": 2},
                   {"item": "iron", "min": 0, "max": 1}],
        "draw": draw_atm,
    },
    {
        "id": "ret_magazine_rack", "name": "Magazine Rack", "category": "furniture",
        "size": [1, 2], "zones": ["commercial"], "room_type": "retail",
        "weight": 6, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 2}, {"item": "cloth", "min": 2, "max": 4}],
        "draw": draw_magazine_rack,
    },
    {
        "id": "ret_pallet_goods", "name": "Pallet of Goods", "category": "furniture",
        "size": [2, 1], "zones": ["commercial"], "room_type": "retail",
        "weight": 12, "tool_tier": 0, "skill": 0, "scrap_time": 2.0, "xp": 4,
        "yields": [{"item": "wood", "min": 3, "max": 5}, {"item": "plastic", "min": 2, "max": 4}],
        "draw": draw_pallet_goods,
    },
    {
        "id": "ret_cash_register", "name": "Cash Register", "category": "clutter",
        "size": [1, 1], "zones": ["commercial"], "room_type": "retail",
        "weight": 4, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "plastic", "min": 1, "max": 2}, {"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_cash_register,
    },
    {
        "id": "ret_security_camera", "name": "Security Camera", "category": "wall_art",
        "size": [1, 1], "zones": ["commercial"], "room_type": "retail",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "plastic", "min": 1, "max": 1}, {"item": "scrap_metal", "min": 0, "max": 1}],
        "wall_mounted": True,
        "draw": draw_security_camera,
    },
    {
        "id": "ret_aisle_sign", "name": "Aisle Sign", "category": "wall_art",
        "size": [2, 1], "zones": ["commercial"], "room_type": "retail",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "plastic", "min": 1, "max": 2}],
        "wall_mounted": True,
        "draw": draw_aisle_sign,
    },
]
