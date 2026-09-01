"""Industrial zone — utility room (mechanical / maintenance floor) item set.

Founds the industrial zone: boiler-room, electrical-room and maintenance-shop
flavor. Style per docs/technical/TileArt.md via the common.py helpers:
material ramps, 1px hue-tinted outlines, light top/left + dark bottom/right
shading, no per-pixel noise. All drawing is deterministic.
"""
from common import *  # noqa: F401,F403 — OUT, WHITE, accents, RAMPS, box, panel, legs

METAL = RAMPS["metal"]
WOOD = RAMPS["wood"]
NAVY = RAMPS["navy"]
PLASTIC = RAMPS["plastic"]
CERAMIC = RAMPS["ceramic"]

# Painted-steel red ramp for the tool chest (same 5-step structure as RAMPS).
RED_STEEL = ((50, 18, 16),
             [(118, 40, 34), (148, 54, 44), (176, 70, 56), (198, 92, 74)],
             (216, 122, 100))

BLACK = (34, 32, 28)  # dark accent for hazard stripes / sign glyphs


def _hazard_stripe(d, x0, y, x1):
    """1px-tall alternating yellow/black hazard band."""
    for i, x in enumerate(range(x0, x1 + 1, 2)):
        d.rectangle([x, y, min(x + 1, x1), y + 1],
                    fill=YELLOW if i % 2 == 0 else BLACK)


# ---------------------------------------------------------------- furniture

def draw_generator(d, W, H):  # 48x32
    # skid base rails
    d.rectangle([0, H - 3, W - 1, H - 1], fill=METAL[1][0], outline=METAL[0])
    # main engine housing
    box(d, 1, 10, W - 14, H - 4, METAL)
    for y in range(15, H - 8, 3):  # cooling louvres
        d.line([5, y, W - 20, y], fill=METAL[1][0])
    # fuel tank on top (navy drum)
    box(d, 3, 4, W - 18, 10, NAVY)
    d.rectangle([7, 2, 10, 4], fill=METAL[1][1], outline=METAL[0])  # filler cap
    # alternator end can with fan
    box(d, W - 13, 7, W - 2, H - 4, METAL)
    d.ellipse([W - 11, 13, W - 4, 20], outline=METAL[1][3])
    d.line([W - 8, 14, W - 8, 19], fill=METAL[1][3])
    d.line([W - 10, 16, W - 5, 16], fill=METAL[1][3])
    d.point((W - 8, 16), fill=METAL[2])
    # exhaust stack
    d.rectangle([W - 17, 0, W - 15, 7], fill=METAL[1][1], outline=METAL[0])
    # hazard band along the housing skirt + status lamp
    _hazard_stripe(d, 3, H - 7, W - 17)
    d.point((W - 16, 12), fill=GREEN)


def draw_boiler(d, W, H):  # 32x48
    # feet
    d.rectangle([3, H - 3, 6, H - 1], fill=METAL[1][0], outline=METAL[0])
    d.rectangle([W - 7, H - 3, W - 4, H - 1], fill=METAL[1][0], outline=METAL[0])
    # top steam pipe + relief valve
    d.rectangle([12, 0, 16, 5], fill=METAL[1][1], outline=METAL[0])
    d.rectangle([20, 2, 23, 5], fill=ORANGE, outline=OUT)
    # domed cap
    d.rectangle([5, 5, W - 6, 9], fill=METAL[1][3], outline=METAL[0])
    # tank body
    box(d, 2, 9, W - 3, H - 4, METAL)
    # riveted bands
    for y in (18, 32):
        d.line([3, y, W - 4, y], fill=METAL[1][0])
        for x in range(5, W - 5, 5):
            d.point((x, y), fill=METAL[2])
    # pressure gauge
    d.ellipse([W - 13, 12, W - 7, 18], fill=WHITE, outline=OUT)
    d.line([W - 10, 15, W - 9, 13], fill=RED)
    # fire door with glow
    d.rectangle([8, H - 16, W - 9, H - 7], fill=(60, 30, 20), outline=OUT)
    d.rectangle([10, H - 13, W - 11, H - 9], fill=ORANGE)
    d.point((W // 2, H - 11), fill=(255, 220, 120))


def draw_pipe_manifold(d, W, H):  # 32x32
    # header pipe across the top
    box(d, 0, 5, W - 1, 11, METAL)
    d.line([1, 6, W - 2, 6], fill=METAL[2])
    # end flange
    d.rectangle([0, 4, 2, 12], fill=METAL[1][1], outline=METAL[0])
    # three drop pipes to the floor with flanges and valve wheels
    for i, x in enumerate((4, 14, 24)):
        d.rectangle([x, 12, x + 3, H - 1], fill=NAVY[1][2], outline=NAVY[0])
        d.line([x + 1, 13, x + 1, H - 2], fill=NAVY[1][3])
        d.rectangle([x - 1, 12, x + 4, 14], fill=METAL[1][1], outline=METAL[0])
        wheel = RED if i != 1 else YELLOW
        d.ellipse([x - 1, 18, x + 4, 23], outline=wheel)
        d.point((x + 1, 20), fill=wheel)
    # gauge on the header
    d.ellipse([8, 1, 12, 5], fill=WHITE, outline=OUT)
    d.point((10, 3), fill=RED)



def draw_tool_table(d, W, H):  # 48x32
    # steel worktop flush with the block top (tools / clutter sit on it)
    box(d, 0, 0, W - 1, 5, METAL)
    d.line([1, 1, W - 2, 1], fill=METAL[2])
    # angle-iron legs + lower shelf
    d.rectangle([2, 6, 4, H - 1], fill=METAL[1][1], outline=METAL[0])
    d.rectangle([W - 5, 6, W - 3, H - 1], fill=METAL[1][1], outline=METAL[0])
    d.rectangle([4, 20, W - 5, 22], fill=METAL[1][0], outline=METAL[0])
    d.rectangle([8, 15, 16, 20], fill=NAVY[1][1], outline=NAVY[0])  # crate on the shelf
    # red toolbox on the floor under the shelf
    box(d, 20, 25, 31, H - 1, RED_STEEL)
    d.rectangle([24, 23, 27, 25], fill=RED_STEEL[1][0], outline=RED_STEEL[0])


def draw_vent_unit(d, W, H):  # 32x32
    # duct up top
    d.rectangle([8, 0, 15, 6], fill=METAL[1][1], outline=METAL[0])
    d.line([9, 1, 14, 1], fill=METAL[1][3])
    # housing
    box(d, 1, 6, W - 2, H - 1, METAL)
    # fan opening with blades
    d.ellipse([4, 11, 17, 24], fill=METAL[1][0], outline=METAL[0])
    d.arc([5, 12, 16, 23], 170, 280, fill=METAL[1][3])  # rim catchlight
    d.line([7, 14, 14, 21], fill=METAL[1][2])
    d.line([14, 14, 7, 21], fill=METAL[1][2])
    d.point((10, 17), fill=METAL[2])
    # side grille
    for y in range(11, 25, 3):
        d.line([20, y, W - 5, y], fill=METAL[1][0])
    # warning label
    d.rectangle([21, H - 6, 25, H - 4], fill=YELLOW, outline=OUT)


def draw_barrel_rack(d, W, H):  # 32x32
    # frame uprights and rails
    d.rectangle([0, 2, 2, H - 1], fill=METAL[1][1], outline=METAL[0])
    d.rectangle([W - 3, 2, W - 1, H - 1], fill=METAL[1][1], outline=METAL[0])
    d.rectangle([1, 16, W - 2, 17], fill=METAL[1][0])
    # two drums lying on their sides (navy, hoop rings, hazard label)
    for y0 in (4, 20):
        box(d, 3, y0, W - 4, y0 + 10, NAVY)
        d.line([9, y0 + 1, 9, y0 + 9], fill=NAVY[1][3])   # hoops
        d.line([22, y0 + 1, 22, y0 + 9], fill=NAVY[1][3])
        d.rectangle([W - 6, y0 + 1, W - 5, y0 + 9], fill=NAVY[1][0])  # end rim
        d.rectangle([13, y0 + 3, 18, y0 + 7], fill=ORANGE, outline=OUT)  # label
        d.point((15, y0 + 5), fill=BLACK)


# ------------------------------------------------------- storage containers

def draw_tool_chest(d, W, H):  # 32x32
    # steel top surface
    d.rectangle([2, 1, W - 3, 3], fill=METAL[1][2], outline=METAL[0])
    d.line([3, 2, W - 4, 2], fill=METAL[2])
    # red cabinet body
    box(d, 2, 3, W - 3, H - 5, RED_STEEL)
    # drawer seams + steel pulls
    for y in (10, 16, 22):
        d.line([3, y, W - 4, y], fill=RED_STEEL[0])
        d.line([12, y - 3, 19, y - 3], fill=METAL[1][3])
    # side handle
    d.rectangle([0, 8, 1, 14], fill=METAL[1][1], outline=METAL[0])
    # casters
    d.ellipse([4, H - 5, 8, H - 1], fill=METAL[1][0], outline=METAL[0])
    d.ellipse([W - 9, H - 5, W - 5, H - 1], fill=METAL[1][0], outline=METAL[0])
    d.point((6, H - 4), fill=METAL[1][3])
    d.point((W - 7, H - 4), fill=METAL[1][3])


def draw_parts_shelf(d, W, H):  # 32x48
    # uprights
    d.rectangle([0, 0, 2, H - 1], fill=METAL[1][1], outline=METAL[0])
    d.rectangle([W - 3, 0, W - 1, H - 1], fill=METAL[1][1], outline=METAL[0])
    # shelves
    for y in (13, 28, 43):
        d.rectangle([1, y, W - 2, y + 1], fill=METAL[1][2], outline=METAL[0])
    # parts bins per shelf (open-front totes with label spot)
    bins = [
        [(4, PLASTIC), (14, NAVY), (23, PLASTIC)],
        [(4, NAVY), (14, PLASTIC), (23, NAVY)],
        [(4, PLASTIC), (14, NAVY), (23, PLASTIC)],
    ]
    for row, shelf_y in enumerate((13, 28, 43)):
        for x, ramp in bins[row]:
            box(d, x, shelf_y - 8, x + 6, shelf_y - 1, ramp)
            d.rectangle([x + 2, shelf_y - 6, x + 4, shelf_y - 5], fill=WHITE)
    # hazard band on the top beam
    _hazard_stripe(d, 3, 1, W - 4)


# ------------------------------------------------------------------ clutter

def draw_oil_can(d, W, H):  # 16x16
    # body
    box(d, 3, 8, 12, H - 1, METAL)
    # spout angling up-left
    d.polygon([(3, 8), (1, 2), (3, 2), (6, 8)], fill=METAL[1][2], outline=METAL[0])
    d.point((2, 3), fill=METAL[2])
    # loop handle
    d.rectangle([10, 4, 13, 8], outline=METAL[0])
    d.point((11, 5), fill=METAL[1][3])
    # label band
    d.rectangle([5, 10, 10, 12], fill=ORANGE, outline=OUT)


def draw_gas_cylinder(d, W, H):  # 16x16
    # valve + shoulder
    d.rectangle([7, 0, 8, 2], fill=METAL[1][2], outline=METAL[0])
    d.rectangle([5, 2, 10, 4], fill=PLASTIC[1][1], outline=PLASTIC[0])
    # tank body
    box(d, 4, 4, 11, H - 1, PLASTIC)
    d.line([5, 5, 5, H - 2], fill=PLASTIC[2])
    # label
    d.rectangle([6, 8, 9, 11], fill=WHITE, outline=OUT)
    d.point((7, 9), fill=RED)


def draw_bucket(d, W, H):  # 16x16
    # handle (top arc)
    d.arc([3, 2, 12, 10], 180, 360, fill=METAL[1][3])
    # tapered body
    d.polygon([(2, 6), (13, 6), (11, H - 1), (4, H - 1)], fill=METAL[1][2], outline=METAL[0])
    d.line([3, 7, 12, 7], fill=METAL[1][3])   # rim
    d.line([4, 8, 4, H - 3], fill=METAL[2])   # left highlight
    d.line([10, 9, 10, H - 3], fill=METAL[1][1])  # right shade
    d.line([5, H - 2, 10, H - 2], fill=METAL[1][0])


def draw_hose_coil(d, W, H):  # 16x16
    # coiled hose lying against the wall, seen face-on
    d.ellipse([1, 4, 13, H - 1], fill=NAVY[1][1], outline=NAVY[0])
    d.ellipse([4, 7, 10, 13], fill=NAVY[1][0], outline=NAVY[0])
    d.arc([3, 6, 11, 14], 150, 300, fill=NAVY[1][3])  # top-left sheen
    d.point((3, 6), fill=NAVY[2])
    # brass coupler poking out the side
    d.rectangle([12, 9, 15, 12], fill=YELLOW, outline=OUT)
    d.point((13, 10), fill=(255, 230, 150))


# ----------------------------------------------------------------- wall art

def draw_hazard_sign(d, W, H):  # 16x16
    d.rectangle([2, 2, 13, 13], fill=YELLOW, outline=OUT)
    d.line([3, 3, 12, 3], fill=(240, 214, 120))  # top light edge
    d.line([3, 12, 12, 12], fill=(170, 138, 52))  # bottom shade
    # lightning bolt
    d.polygon([(8, 4), (5, 9), (7, 9), (5, 12), (10, 7), (8, 7), (10, 4)], fill=BLACK)
    # mounting screws
    d.point((3, 3), fill=OUT)
    d.point((12, 3), fill=OUT)
    d.point((3, 12), fill=OUT)
    d.point((12, 12), fill=OUT)


def draw_pipe_diagram(d, W, H):  # 32x16
    # framed schematic board
    box(d, 0, 1, W - 1, H - 2, CERAMIC)
    d.rectangle([1, 2, W - 2, H - 3], outline=METAL[1][1])
    # title block
    d.rectangle([3, 4, 11, 5], fill=NAVY[1][1])
    # pipe run: main line with two drops and valve/junction marks
    d.line([4, 8, W - 5, 8], fill=NAVY[1][0])
    d.line([10, 8, 10, 12], fill=NAVY[1][0])
    d.line([21, 8, 21, 12], fill=NAVY[1][0])
    d.rectangle([9, 7, 11, 9], fill=RED)
    d.rectangle([20, 11, 22, 12], fill=RED)
    d.point((26, 8), fill=GREEN)
    d.line([4, 12, 7, 12], fill=NAVY[1][2])


# ------------------------------------------------------------------- items

ITEMS = [
    {
        "id": "ind_generator", "name": "Diesel Generator", "category": "furniture",
        "size": [3, 2], "zones": ["industrial"], "room_type": "utility",
        "weight": 26, "tool_tier": 1, "skill": 1, "scrap_time": 4.0, "xp": 8,
        "yields": [
            {"item": "scrap_metal", "min": 3, "max": 5},
            {"item": "iron", "min": 2, "max": 4},
            {"item": "plastic", "min": 1, "max": 2},
        ],
        "draw": draw_generator,
    },
    {
        "id": "ind_boiler", "name": "Boiler Tank", "category": "furniture",
        "size": [2, 3], "zones": ["industrial"], "room_type": "utility",
        "weight": 28, "tool_tier": 1, "skill": 0, "scrap_time": 3.5, "xp": 7,
        "yields": [
            {"item": "scrap_metal", "min": 4, "max": 6},
            {"item": "iron", "min": 2, "max": 3},
        ],
        "draw": draw_boiler,
    },
    {
        "id": "ind_pipe_manifold", "name": "Pipe Manifold", "category": "furniture",
        "size": [2, 2], "zones": ["industrial"], "room_type": "utility",
        "weight": 14, "tool_tier": 1, "skill": 0, "scrap_time": 2.5, "xp": 5,
        "yields": [
            {"item": "scrap_metal", "min": 3, "max": 4},
            {"item": "iron", "min": 1, "max": 2},
        ],
        "draw": draw_pipe_manifold,
    },
    {
        "id": "ind_tool_table", "surface": True, "name": "Machinist's Table", "category": "furniture",
        "size": [3, 2], "zones": ["industrial"], "room_type": "utility",
        "weight": 16, "tool_tier": 0, "skill": 0, "scrap_time": 3.0, "xp": 6,
        "yields": [
            {"item": "scrap_metal", "min": 3, "max": 5},
            {"item": "iron", "min": 1, "max": 2},
            {"item": "wood", "min": 1, "max": 2},
        ],
        "draw": draw_tool_table,
    },
    {
        "id": "ind_vent_unit", "name": "Ventilation Unit", "category": "furniture",
        "size": [2, 2], "zones": ["industrial"], "room_type": "utility",
        "weight": 15, "tool_tier": 1, "skill": 0, "scrap_time": 2.5, "xp": 5,
        "yields": [
            {"item": "scrap_metal", "min": 3, "max": 5},
            {"item": "plastic", "min": 0, "max": 1},
        ],
        "draw": draw_vent_unit,
    },
    {
        "id": "ind_barrel_rack", "name": "Barrel Rack", "category": "furniture",
        "size": [2, 2], "zones": ["industrial"], "room_type": "utility",
        "weight": 18, "tool_tier": 1, "skill": 0, "scrap_time": 3.0, "xp": 6,
        "yields": [
            {"item": "scrap_metal", "min": 2, "max": 4},
            {"item": "iron", "min": 1, "max": 2},
            {"item": "plastic", "min": 1, "max": 2},
        ],
        "draw": draw_barrel_rack,
    },
    {
        "id": "ind_tool_chest", "name": "Rolling Tool Chest", "category": "furniture",
        "size": [2, 2], "zones": ["industrial"], "room_type": "utility",
        "weight": 14, "tool_tier": 1, "skill": 0, "scrap_time": 2.5, "xp": 6,
        "storage_slots": 8,
        "yields": [
            {"item": "scrap_metal", "min": 3, "max": 4},
            {"item": "iron", "min": 1, "max": 2},
        ],
        "draw": draw_tool_chest,
    },
    {
        "id": "ind_parts_shelf", "name": "Parts Bin Shelf", "category": "furniture",
        "size": [2, 3], "zones": ["industrial"], "room_type": "utility",
        "weight": 16, "tool_tier": 0, "skill": 0, "scrap_time": 3.0, "xp": 6,
        "storage_slots": 12,
        "yields": [
            {"item": "scrap_metal", "min": 2, "max": 4},
            {"item": "plastic", "min": 2, "max": 3},
            {"item": "iron", "min": 0, "max": 1},
        ],
        "draw": draw_parts_shelf,
    },
    {
        "id": "ind_oil_can", "name": "Oil Can", "category": "clutter",
        "size": [1, 1], "zones": ["industrial"], "room_type": "utility",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_oil_can,
    },
    {
        "id": "ind_gas_cylinder", "name": "Gas Cylinder", "category": "clutter",
        "size": [1, 1], "zones": ["industrial"], "room_type": "utility",
        "weight": 4, "tool_tier": 1, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [
            {"item": "scrap_metal", "min": 1, "max": 2},
            {"item": "iron", "min": 0, "max": 1},
        ],
        "draw": draw_gas_cylinder,
    },
    {
        "id": "ind_bucket", "name": "Steel Bucket", "category": "clutter",
        "size": [1, 1], "zones": ["industrial"], "room_type": "utility",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_bucket,
    },
    {
        "id": "ind_hose_coil", "name": "Coiled Hose", "category": "clutter",
        "size": [1, 1], "zones": ["industrial"], "room_type": "utility",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [
            {"item": "plastic", "min": 1, "max": 2},
            {"item": "cloth", "min": 0, "max": 1},
        ],
        "draw": draw_hose_coil,
    },
    {
        "id": "ind_hazard_sign", "name": "Hazard Sign", "category": "wall_art",
        "size": [1, 1], "zones": ["industrial"], "room_type": "utility",
        "weight": 1, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "wall_mounted": True,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 1}],
        "draw": draw_hazard_sign,
    },
    {
        "id": "ind_pipe_diagram", "name": "Pipe Diagram Board", "category": "wall_art",
        "size": [2, 1], "zones": ["industrial"], "room_type": "utility",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "wall_mounted": True,
        "yields": [
            {"item": "wood", "min": 1, "max": 2},
            {"item": "scrap_metal", "min": 0, "max": 1},
        ],
        "draw": draw_pipe_diagram,
    },
]
