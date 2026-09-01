"""Industrial zone — plant room (heavy mechanical / service floor) item set.

Second industrial pack: the heavier plant-room hardware that sits alongside
industrial_utility.py — water heater, compressor, welding cart, cable reel,
drums and a pallet jack, plus wall-mounted fuse box and fire-hose cabinet.
Style per docs/technical/TileArt.md via the common.py helpers: material
ramps, 1px hue-tinted outlines, light top/left + dark bottom/right shading,
no per-pixel noise. All drawing is deterministic.
"""
import math

from common import *  # noqa: F401,F403 — OUT, WHITE, accents, RAMPS, box, panel, legs

METAL = RAMPS["metal"]
WOOD = RAMPS["wood"]
PLASTIC = RAMPS["plastic"]
CERAMIC = RAMPS["ceramic"]

# Painted-steel ramps (same 5-step structure as RAMPS).
RED_STEEL = ((50, 18, 16),
             [(118, 40, 34), (148, 54, 44), (176, 70, 56), (198, 92, 74)],
             (216, 122, 100))
BLUE_STEEL = ((16, 26, 46),
              [(40, 72, 120), (56, 96, 150), (76, 122, 178), (100, 148, 200)],
              (136, 180, 224))
YELLOW_PLASTIC = ((60, 44, 10),
                  [(150, 112, 30), (184, 142, 44), (212, 170, 64), (230, 194, 96)],
                  (244, 220, 140))
ORANGE_STEEL = ((70, 30, 8),
                [(160, 80, 28), (196, 104, 40), (222, 130, 54), (236, 158, 84)],
                (246, 190, 120))
RUBBER = ((12, 10, 10),
          [(30, 30, 34), (44, 44, 50), (58, 58, 66), (72, 72, 82)],
          (96, 96, 108))

BLACK = (34, 32, 28)        # dark accent for stencils / hazard stripes
CABLE = (24, 24, 28)        # black insulated cable
CABLE_SHEEN = (54, 54, 62)
HOSE = (120, 40, 36)        # welding hose (dark red)
GLASS = (116, 150, 170)
GLASS_SHINE = (214, 232, 238)


def _hazard_stripe(d, x0, y, x1):
    """1px-tall alternating yellow/black hazard band."""
    for i, x in enumerate(range(x0, x1 + 1, 2)):
        d.rectangle([x, y, min(x + 1, x1), y + 1],
                    fill=YELLOW if i % 2 == 0 else BLACK)


def _wheel(d, x0, y0, x1, y1):
    """Rubber wheel with a metal hub."""
    d.ellipse([x0, y0, x1, y1], fill=RUBBER[1][1], outline=RUBBER[0])
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    d.point((cx, cy), fill=METAL[1][3])
    d.point((x0 + 1, y0 + 1), fill=RUBBER[1][3])


def _horizontal_tank(d, x0, y0, x1, y1, ramp):
    """Horizontal cylinder with rounded ends and top/bottom shading."""
    o, t, h = ramp
    r = (y1 - y0) // 2
    d.ellipse([x0, y0, x0 + 2 * r, y1], fill=t[2], outline=o)
    d.ellipse([x1 - 2 * r, y0, x1, y1], fill=t[2], outline=o)
    d.rectangle([x0 + r, y0, x1 - r, y1], fill=t[2], outline=o)
    d.rectangle([x0 + r, y0 + 1, x1 - r, y1 - 1], fill=t[2])
    d.line([x0 + r, y0 + 1, x1 - r, y0 + 1], fill=t[3])
    d.line([x0 + r + 1, y0 + 2, x0 + r + 8, y0 + 2], fill=h)
    d.line([x0 + r, y1 - 1, x1 - r, y1 - 1], fill=t[1])
    d.line([x0 + r, y1 - 2, x1 - r, y1 - 2], fill=t[1])


# ---------------------------------------------------------------- furniture

def draw_water_heater(d, W, H):  # 16x48
    # feet
    d.rectangle([3, H - 3, 5, H - 1], fill=METAL[1][0], outline=METAL[0])
    d.rectangle([10, H - 3, 12, H - 1], fill=METAL[1][0], outline=METAL[0])
    # flue up the middle + cold-water inlet from the right
    d.rectangle([6, 0, 8, 6], fill=METAL[1][2], outline=METAL[0])
    d.rectangle([8, 2, W - 1, 4], fill=METAL[1][2], outline=METAL[0])
    d.line([9, 3, W - 2, 3], fill=METAL[1][3])
    d.rectangle([2, 5, 3, 6], fill=ORANGE, outline=None)  # relief valve
    # domed cap
    d.rectangle([3, 6, 12, 8], fill=CERAMIC[1][3], outline=CERAMIC[0])
    # white enamel tank body
    box(d, 2, 8, 13, H - 4, CERAMIC)
    d.line([3, 9, 3, H - 6], fill=CERAMIC[2])
    for y in (16, 36):  # shell seams
        d.line([3, y, 12, y], fill=CERAMIC[1][1])
    # energy-guide sticker
    d.rectangle([5, 19, 10, 24], fill=YELLOW, outline=OUT)
    d.rectangle([6, 21, 9, 21], fill=BLACK)
    # gas control box with knob + pilot lamp
    box(d, 4, 28, 11, 35, METAL)
    d.ellipse([8, 30, 10, 32], fill=RED_STEEL[1][2], outline=RED_STEEL[0])
    d.point((6, 31), fill=GREEN)
    # gas line running down the right side
    d.rectangle([11, 32, 14, 33], fill=METAL[1][1], outline=None)
    d.rectangle([13, 33, 14, H - 4], fill=METAL[1][1], outline=None)
    d.line([13, 34, 13, H - 5], fill=METAL[1][3])
    # brass drain valve, bottom left
    d.rectangle([0, 40, 2, 41], fill=YELLOW, outline=None)
    d.point((0, 40), fill=OUT)


def draw_air_compressor(d, W, H):  # 32x32
    # red horizontal receiver tank
    _horizontal_tank(d, 0, 13, W - 1, 26, RED_STEEL)
    d.rectangle([12, 18, 18, 21], fill=WHITE, outline=OUT)  # brand label
    d.point((14, 19), fill=BLACK)
    d.point((16, 20), fill=BLACK)
    # wheels (drawn after the tank so they sit in front)
    _wheel(d, 1, H - 7, 8, H - 1)
    _wheel(d, W - 9, H - 7, W - 2, H - 1)
    # electric motor with cooling fins
    box(d, 3, 3, 14, 13, METAL)
    for y in (6, 8, 10):
        d.line([5, y, 12, y], fill=METAL[1][0])
    d.point((4, 4), fill=METAL[2])
    # pump head with intake filter can on top
    box(d, 16, 6, 23, 13, METAL)
    d.line([18, 8, 21, 8], fill=METAL[1][0])
    d.line([18, 10, 21, 10], fill=METAL[1][0])
    d.ellipse([17, 1, 22, 6], fill=CERAMIC[1][2], outline=CERAMIC[0])
    d.point((18, 2), fill=CERAMIC[2])
    # belt between motor and pump
    d.line([14, 9, 16, 9], fill=RUBBER[1][1])
    # pressure gauge on a stem at the right end
    d.rectangle([26, 10, 27, 13], fill=METAL[1][1], outline=None)
    d.ellipse([24, 4, 30, 10], fill=WHITE, outline=OUT)
    d.line([27, 7, 28, 5], fill=RED)
    d.point((27, 7), fill=BLACK)


def draw_welding_cart(d, W, H):  # 32x32
    # base plate + wheels
    d.rectangle([1, H - 9, W - 2, H - 7], fill=METAL[1][1], outline=METAL[0])
    _wheel(d, 1, H - 7, 8, H - 1)
    _wheel(d, W - 9, H - 7, W - 2, H - 1)
    # push frame: upright + top bar
    d.rectangle([1, 3, 2, H - 9], fill=METAL[1][1], outline=METAL[0])
    d.rectangle([1, 1, 8, 3], fill=METAL[1][2], outline=METAL[0])
    # tall blue oxygen bottle
    box(d, 5, 8, 13, H - 9, BLUE_STEEL)
    d.line([6, 9, 6, H - 11], fill=BLUE_STEEL[2])
    d.rectangle([6, 6, 12, 8], fill=BLUE_STEEL[1][1], outline=BLUE_STEEL[0])
    d.rectangle([8, 2, 10, 6], fill=METAL[1][2], outline=METAL[0])
    d.ellipse([11, 1, 14, 4], fill=WHITE, outline=OUT)  # regulator gauge
    d.point((12, 2), fill=RED)
    # shorter green acetylene bottle
    box(d, 16, 11, 24, H - 9, PLASTIC)
    d.line([17, 12, 17, H - 11], fill=PLASTIC[2])
    d.rectangle([17, 9, 23, 11], fill=PLASTIC[1][1], outline=PLASTIC[0])
    d.rectangle([19, 5, 21, 9], fill=METAL[1][2], outline=METAL[0])
    d.ellipse([22, 4, 25, 7], fill=WHITE, outline=OUT)
    d.point((23, 5), fill=RED)
    # safety chain across both bottles to the frame
    for i, x in enumerate(range(2, 26)):
        d.point((x, 15), fill=METAL[1][3] if i % 2 == 0 else METAL[0])
    # hose coil hung on the right + torch lying on the base plate
    d.ellipse([25, 11, 31, 20], outline=HOSE)
    d.ellipse([24, 13, 30, 22], outline=HOSE)
    d.point((26, 12), fill=(170, 80, 70))
    d.rectangle([25, H - 11, 30, H - 10], fill=METAL[1][2], outline=None)
    d.point((30, H - 11), fill=YELLOW)


def draw_cable_spool(d, W, H):  # 32x32
    # rear flange (darker), offset up-right for depth
    d.ellipse([3, 0, W - 1, H - 4], fill=WOOD[1][0], outline=WOOD[0])
    # black cable peeking over the top of the rear flange gap
    d.arc([3, 0, W - 1, H - 4], 200, 330, fill=CABLE)
    # front flange: plank disc, cable showing through the seams
    cx, cy, r = 14, 17, 14
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WOOD[1][2], outline=WOOD[0])
    for x in (4, 9, 14, 19, 24):
        dy = int(math.sqrt(r * r - (x - cx) ** 2)) - 1
        d.line([x, cy - dy, x, cy + dy], fill=CABLE)
        d.line([x + 1, cy - dy + 1, x + 1, cy + dy - 1], fill=WOOD[1][3])
    d.arc([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1], 190, 280, fill=WOOD[2])
    d.arc([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1], 20, 110, fill=WOOD[1][1])
    # steel hub with bolt
    d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=METAL[1][1], outline=METAL[0])
    d.point((cx - 1, cy - 1), fill=METAL[2])
    d.point((cx, cy), fill=METAL[0])
    # cable tail slipping off the reel down to the floor
    d.line([26, 21, 30, 24], fill=CABLE, width=2)
    d.line([30, 24, 30, H - 1], fill=CABLE, width=2)
    d.line([31, 25, 31, H - 1], fill=CABLE_SHEEN)


def draw_drum_barrel(d, W, H):  # 16x32
    # blue steel drum with rolled rims
    box(d, 2, 1, 13, H - 2, BLUE_STEEL)
    d.line([3, 2, 3, H - 4], fill=BLUE_STEEL[2])
    d.rectangle([1, 0, 14, 2], fill=BLUE_STEEL[1][1], outline=BLUE_STEEL[0])
    d.line([2, 1, 13, 1], fill=BLUE_STEEL[1][3])
    d.rectangle([1, H - 3, 14, H - 1], fill=BLUE_STEEL[1][0], outline=BLUE_STEEL[0])
    # two rolling hoops
    for y in (11, 21):
        d.line([2, y, 13, y], fill=BLUE_STEEL[1][3])
        d.line([2, y + 1, 13, y + 1], fill=BLUE_STEEL[1][0])
    # stencil between the hoops
    d.rectangle([5, 14, 10, 18], fill=WHITE, outline=None)
    d.line([6, 15, 9, 17], fill=BLACK)
    d.line([6, 17, 9, 15], fill=BLACK)
    # bung caps on the lid
    d.point((5, 1), fill=BLUE_STEEL[0])
    d.point((10, 1), fill=BLUE_STEEL[0])


def draw_pallet_jack(d, W, H):  # 32x16
    # far fork peeking above the near one
    d.line([1, 8, 21, 8], fill=ORANGE_STEEL[1][1])
    # near fork
    box(d, 0, 9, 21, 12, ORANGE_STEEL)
    d.point((0, 12), fill=ORANGE_STEEL[1][0])
    # load wheel under the fork tip
    _wheel(d, 2, 11, 6, H - 1)
    # yellow hydraulic pump housing + steer wheel
    box(d, 21, 3, 28, 10, YELLOW_PLASTIC)
    _hazard_stripe(d, 22, 6, 27)
    _wheel(d, 22, 10, 28, H - 1)
    # tow handle rising up and back, rubber grip
    d.line([24, 3, 29, 0], fill=METAL[1][3])
    d.line([25, 4, 30, 1], fill=METAL[1][0])
    d.rectangle([29, 0, 31, 1], fill=RUBBER[1][2], outline=None)
    d.point((29, 0), fill=RUBBER[0])


# ------------------------------------------------------------------ clutter

def draw_mop_bucket(d, W, H):  # 16x16
    # yellow tapered bucket on casters
    d.polygon([(2, 6), (11, 6), (10, 13), (3, 13)],
              fill=YELLOW_PLASTIC[1][2], outline=YELLOW_PLASTIC[0])
    d.line([3, 7, 10, 7], fill=YELLOW_PLASTIC[1][3])
    d.line([3, 8, 3, 12], fill=YELLOW_PLASTIC[2])
    d.line([9, 8, 9, 12], fill=YELLOW_PLASTIC[1][1])
    d.line([4, 12, 9, 12], fill=YELLOW_PLASTIC[1][0])
    d.rectangle([3, 14, 4, 15], fill=RUBBER[1][1], outline=None)
    d.rectangle([9, 14, 10, 15], fill=RUBBER[1][1], outline=None)
    # mop head slumped over the left rim, handle leaning up
    d.rectangle([1, 4, 4, 6], fill=CERAMIC[1][2], outline=CERAMIC[0])
    d.line([1, 7, 1, 9], fill=CERAMIC[1][1])
    d.line([3, 7, 3, 8], fill=CERAMIC[1][1])
    d.line([4, 7, 7, 0], fill=WOOD[1][3])
    d.line([5, 7, 8, 0], fill=WOOD[0])
    # steel wringer clipped on the right rim
    box(d, 8, 2, 14, 6, METAL)
    d.line([13, 2, 15, 0], fill=METAL[1][3])


# ----------------------------------------------------------------- wall art

def draw_fuse_box(d, W, H):  # 16x32
    # grey steel panel
    box(d, 0, 0, W - 1, H - 1, METAL)
    # open cavity with rows of (mostly dead) fuses
    d.rectangle([2, 3, 13, H - 4], fill=(28, 32, 40), outline=METAL[0])
    d.line([3, 4, 3, H - 5], fill=METAL[1][0])  # bus bar
    fuse_colors = [
        (RUBBER[1][2], CERAMIC[1][1], RUBBER[1][2]),
        (CERAMIC[1][1], RUBBER[1][2], RED),
        (RUBBER[1][2], RUBBER[1][2], CERAMIC[1][1]),
        (RED, RUBBER[1][2], RUBBER[1][2]),
        (RUBBER[1][2], CERAMIC[1][1], RUBBER[1][2]),
    ]
    for row, y in enumerate((5, 10, 15, 20, 25)):
        for col, x in enumerate((5, 8, 11)):
            c = fuse_colors[row][col]
            d.rectangle([x, y, x + 1, y + 2], fill=c, outline=None)
            d.point((x, y), fill=RUBBER[1][3] if c == RUBBER[1][2] else WHITE)
    # dangling cut wires below the last row
    d.line([9, 28, 9, 30], fill=RED)
    d.line([11, 28, 12, 30], fill=CABLE_SHEEN)
    # door ajar (foreshortened) hinged on the left, catching light
    d.rectangle([0, 1, 4, H - 2], fill=METAL[1][3], outline=METAL[0])
    d.line([1, 2, 1, H - 3], fill=METAL[2])
    d.rectangle([1, 5, 3, 7], fill=YELLOW, outline=OUT)  # warning sticker
    d.point((3, 16), fill=METAL[0])  # latch


def draw_fire_hose_cabinet(d, W, H):  # 16x16
    # red steel frame with glass door
    box(d, 0, 0, W - 1, H - 1, RED_STEEL)
    d.rectangle([2, 2, 13, 13], fill=GLASS, outline=OUT)
    # coiled canvas hose behind the glass
    d.ellipse([3, 4, 12, 13], fill=CERAMIC[1][2], outline=OUT)
    d.ellipse([5, 6, 10, 11], outline=CERAMIC[1][0])
    d.ellipse([6, 7, 9, 10], fill=(60, 70, 80), outline=None)
    d.point((4, 6), fill=CERAMIC[2])
    # brass nozzle clipped in the top corner
    d.rectangle([10, 2, 12, 4], fill=YELLOW, outline=OUT)
    d.point((11, 3), fill=(255, 230, 150))
    # glass streak + door pull
    d.line([3, 5, 5, 3], fill=GLASS_SHINE)
    d.point((13, 8), fill=WHITE)


# ------------------------------------------------------------------- items

ITEMS = [
    {
        "id": "ind_water_heater", "name": "Water Heater", "category": "furniture",
        "size": [1, 3], "zones": ["industrial"], "room_type": "utility",
        "weight": 20, "tool_tier": 1, "skill": 1, "scrap_time": 3.0, "xp": 6,
        "yields": [
            {"item": "scrap_metal", "min": 3, "max": 5},
            {"item": "iron", "min": 1, "max": 2},
        ],
        "draw": draw_water_heater,
    },
    {
        "id": "ind_air_compressor", "name": "Air Compressor", "category": "furniture",
        "size": [2, 2], "zones": ["industrial"], "room_type": "utility",
        "weight": 18, "tool_tier": 1, "skill": 1, "scrap_time": 3.0, "xp": 6,
        "yields": [
            {"item": "scrap_metal", "min": 3, "max": 4},
            {"item": "iron", "min": 1, "max": 3},
        ],
        "draw": draw_air_compressor,
    },
    {
        "id": "ind_welding_cart", "name": "Welding Cart", "category": "furniture",
        "size": [2, 2], "zones": ["industrial"], "room_type": "utility",
        "weight": 16, "tool_tier": 1, "skill": 2, "scrap_time": 3.0, "xp": 7,
        "yields": [
            {"item": "scrap_metal", "min": 2, "max": 4},
            {"item": "iron", "min": 1, "max": 2},
            {"item": "plastic", "min": 1, "max": 2},
        ],
        "draw": draw_welding_cart,
    },
    {
        "id": "ind_cable_spool", "name": "Cable Spool", "category": "furniture",
        "size": [2, 2], "zones": ["industrial"], "room_type": "utility",
        "weight": 16, "tool_tier": 0, "skill": 0, "scrap_time": 2.5, "xp": 5,
        "yields": [
            {"item": "wood", "min": 3, "max": 5},
            {"item": "scrap_metal", "min": 1, "max": 2},
        ],
        "draw": draw_cable_spool,
    },
    {
        "id": "ind_drum_barrel", "name": "Steel Drum", "category": "furniture",
        "size": [1, 2], "zones": ["industrial"], "room_type": "utility",
        "weight": 10, "tool_tier": 1, "skill": 0, "scrap_time": 2.0, "xp": 4,
        "yields": [
            {"item": "scrap_metal", "min": 2, "max": 3},
            {"item": "iron", "min": 0, "max": 1},
        ],
        "draw": draw_drum_barrel,
    },
    {
        "id": "ind_pallet_jack", "name": "Pallet Jack", "category": "furniture",
        "size": [2, 1], "zones": ["industrial"], "room_type": "utility",
        "weight": 12, "tool_tier": 1, "skill": 1, "scrap_time": 2.5, "xp": 5,
        "yields": [
            {"item": "scrap_metal", "min": 2, "max": 3},
            {"item": "iron", "min": 1, "max": 2},
        ],
        "draw": draw_pallet_jack,
    },
    {
        "id": "ind_mop_bucket", "name": "Mop Bucket", "category": "clutter",
        "size": [1, 1], "zones": ["industrial"], "room_type": "utility",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [
            {"item": "plastic", "min": 1, "max": 2},
            {"item": "wood", "min": 0, "max": 1},
        ],
        "draw": draw_mop_bucket,
    },
    {
        "id": "ind_fuse_box", "name": "Fuse Box (dead)", "category": "wall_art",
        "size": [1, 2], "zones": ["industrial"], "room_type": "utility",
        "weight": 4, "tool_tier": 0, "skill": 1, "scrap_time": 1.5, "xp": 3,
        "wall_mounted": True,
        "yields": [
            {"item": "scrap_metal", "min": 1, "max": 2},
            {"item": "plastic", "min": 1, "max": 1},
        ],
        "draw": draw_fuse_box,
    },
    {
        "id": "ind_fire_hose_cabinet", "name": "Fire Hose Cabinet", "category": "wall_art",
        "size": [1, 1], "zones": ["industrial"], "room_type": "utility",
        "weight": 4, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "wall_mounted": True,
        "yields": [
            {"item": "scrap_metal", "min": 1, "max": 2},
            {"item": "cloth", "min": 1, "max": 2},
        ],
        "draw": draw_fire_hose_cabinet,
    },
]
