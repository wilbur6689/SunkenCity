"""Hospital clinic (outpatient / exam / nurse-station) room-pack items for SunkenCity.

Companion to hospital_ward.py: the working side of a drowned hospital floor —
the nurse station, exam room, supply shelving, waiting area and lab bench.
Style per docs/technical/TileArt.md: material ramps, 1px outlines, light
top/left + dark bottom/right shading, 5-7 colors per item, bottom-anchored
floor items, wall art fills its canvas. Deterministic drawing.
"""
from common import *

MET = RAMPS["metal"]
CER = RAMPS["ceramic"]
PLA = RAMPS["plastic"]
NAV = RAMPS["navy"]
FAB = RAMPS["fabric"]
WOOD = RAMPS["wood"]

# hospital-teal vinyl / moulded plastic ramp (outline, 4 body tones, highlight)
TEA = ((18, 44, 42), [(48, 118, 110), (70, 160, 150), (92, 178, 168), (112, 192, 182)], (144, 214, 204))
RUBBER = (58, 58, 64)
RUBBER_DK = (34, 34, 40)


# --- furniture ------------------------------------------------------------


def draw_nurse_station(d, W, H):
    # base cabinet (white), full width to the floor
    box(d, 2, 4, W - 3, H - 1, CER)
    # teal front band under the counter lip
    panel(d, 2, 4, W - 3, 7, TEAL, top=(110, 190, 180))
    # door seams + drawer handles
    for x in (17, 31):
        d.line([x, 9, x, H - 3], fill=CER[1][1])
    for x in (9, 24, 39):
        d.rectangle([x - 1, 13, x + 1, 13], fill=MET[1][1])
    # kick plate shadow
    d.line([3, H - 2, W - 4, H - 2], fill=CER[1][0])
    # counter top flush with the block top (monitor / tray / clutter sit on it)
    panel(d, 0, 0, W - 1, 3, CER[1][3], outline=OUT, top=CER[2])
    # ward sign on the front
    d.rectangle([19, 17, 30, 23], fill=TEAL, outline=OUT)
    d.rectangle([24, 18, 25, 22], fill=WHITE)
    d.rectangle([22, 19, 27, 21], fill=WHITE)



def draw_exam_table(d, W, H):
    # metal legs + cross brace
    d.rectangle([4, 9, 5, H - 1], fill=MET[1][1], outline=MET[0])
    d.rectangle([W - 6, 9, W - 5, H - 1], fill=MET[1][1], outline=MET[0])
    d.rectangle([6, 12, W - 7, 13], fill=MET[1][1], outline=MET[0])
    # frame rail under the pad
    d.rectangle([1, 7, W - 2, 8], fill=MET[1][2], outline=MET[0])
    # padded teal top flush with the block top (things sit on it)
    box(d, 1, 0, W - 2, 6, TEA)
    d.line([14, 2, 14, 5], fill=TEA[1][0])                       # vinyl seams
    d.line([27, 2, 27, 5], fill=TEA[1][0])
    # paper sheet along the pad + roll at the head end
    d.rectangle([3, 0, W - 11, 1], fill=WHITE)
    d.line([3, 0, W - 11, 0], fill=CER[2])
    d.rectangle([W - 10, 0, W - 3, 2], fill=CER[1][2], outline=OUT)
    d.line([W - 9, 1, W - 4, 1], fill=CER[2])


def draw_supply_shelving(d, W, H):
    # uprights (light left edge, dark right edge)
    for x in (1, W - 3):
        d.rectangle([x, 0, x + 1, H - 1], fill=MET[1][1], outline=MET[0])
        d.line([x, 1, x, H - 2], fill=MET[1][3])
    # wire shelves
    for y in (12, 24, 36, H - 3):
        d.rectangle([1, y, W - 2, y + 1], fill=MET[1][2], outline=MET[0])
        for x in range(4, W - 4, 2):
            d.point((x, y + 1), fill=MET[1][0])
    # shelf 1: two cardboard boxes
    panel(d, 4, 4, 14, 11, BROWN_PAPER, top=(214, 190, 146))
    d.line([9, 5, 9, 10], fill=(166, 138, 92))
    panel(d, 17, 6, 27, 11, BROWN_PAPER, top=(214, 190, 146))
    d.line([18, 8, 26, 8], fill=(166, 138, 92))
    # shelf 2: bottles + small box
    box(d, 4, 16, 7, 23, CER)
    d.rectangle([4, 15, 7, 16], fill=TEAL, outline=OUT)
    panel(d, 9, 17, 12, 23, TEAL, top=(110, 190, 180))
    panel(d, 14, 15, 18, 23, ORANGE, top=(235, 160, 90))
    d.rectangle([14, 14, 18, 15], fill=WHITE, outline=OUT)
    d.rectangle([15, 19, 17, 20], fill=WHITE)
    box(d, 20, 17, 27, 23, CER)
    d.rectangle([22, 19, 25, 20], fill=RED)
    # shelf 3: big carton + white supply boxes
    panel(d, 4, 27, 16, 35, BROWN_PAPER, top=(214, 190, 146))
    d.line([10, 28, 10, 34], fill=(166, 138, 92))
    d.rectangle([6, 30, 8, 31], fill=RED)
    box(d, 18, 28, 27, 31, CER)
    box(d, 18, 32, 27, 35, CER)
    d.rectangle([21, 33, 24, 34], fill=TEAL)
    # bottom shelf: navy tote bin with a lid
    box(d, 4, 40, 27, H - 3, NAV)
    d.rectangle([3, 39, 28, 40], fill=NAV[1][3], outline=NAV[0])
    d.rectangle([8, 42, 15, 43], fill=WHITE)


def draw_scale(d, W, H):
    # footplate
    box(d, 1, H - 4, 14, H - 1, MET)
    d.line([3, H - 3, 12, H - 3], fill=MET[2])
    # column (light left, dark right)
    d.rectangle([5, 9, 9, H - 4], fill=MET[1][1], outline=MET[0])
    d.line([6, 10, 6, H - 5], fill=MET[1][3])
    # height rod behind the dial
    d.rectangle([12, 0, 12, H - 5], fill=MET[1][2])
    d.rectangle([10, 0, 14, 0], fill=MET[1][3])
    # dial head (white face, metal rim)
    d.ellipse([2, 0, 11, 9], fill=CER[1][2], outline=MET[0])
    d.line([4, 1, 6, 1], fill=CER[2])
    for p in ((6, 2), (3, 5), (9, 5), (6, 7)):
        d.point(p, fill=NAV[1][0])
    # needle
    d.line([6, 4, 4, 2], fill=RED)
    d.point((6, 4), fill=OUT)


def draw_crutches(d, W, H):
    # two crutches leaning together: pads touch at the top, tips splay
    def crutch(px, dirx):
        # underarm pad
        d.rectangle([px, 0, px + 5, 2], fill=RUBBER, outline=OUT)
        d.line([px + 1, 1, px + 4, 1], fill=(88, 88, 96))
        cx = px + 2 + (1 if dirx > 0 else 0)
        # twin upper shafts
        d.line([cx - 1, 3, cx - 1 + dirx, 14], fill=MET[1][3])
        d.line([cx + 1, 3, cx + 1 + dirx, 14], fill=MET[1][1])
        # hand grip joining them
        d.rectangle([cx - 2 + dirx, 14, cx + 2 + dirx, 15], fill=RUBBER, outline=OUT)
        # single lower shaft
        d.line([cx + dirx, 16, cx + dirx * 2, H - 4], fill=MET[1][2])
        d.line([cx + dirx + 1, 16, cx + dirx * 2 + 1, H - 4], fill=MET[1][0])
        # rubber tip
        tx = cx + dirx * 2
        d.rectangle([tx - 1, H - 3, tx + 2, H - 1], fill=RUBBER_DK, outline=OUT)

    crutch(2, -1)
    crutch(8, 1)


def draw_waiting_chairs(d, W, H):
    # metal beam + legs with feet
    d.rectangle([2, 11, W - 3, 12], fill=MET[1][1], outline=MET[0])
    for x in (6, W - 8):
        d.rectangle([x, 13, x + 1, H - 1], fill=MET[1][1], outline=MET[0])
        d.rectangle([x - 1, H - 1, x + 2, H - 1], fill=MET[0])
    # three moulded teal seats
    for x in (1, 16, 31):
        # backrest
        box(d, x + 1, 0, x + 13, 5, TEA)
        # seat pan
        box(d, x, 7, x + 14, 10, TEA)
        # bracket between back and seat
        d.rectangle([x + 6, 6, x + 8, 6], fill=MET[1][1])


# --- clutter --------------------------------------------------------------

def draw_microscope(d, W, H):
    # base plate
    d.rectangle([1, 12, 14, 15], fill=MET[1][1], outline=MET[0])
    d.line([2, 13, 13, 13], fill=MET[1][3])
    # arm
    d.rectangle([9, 3, 12, 12], fill=NAV[1][1], outline=NAV[0])
    d.line([10, 4, 10, 11], fill=NAV[1][3])
    # eyepiece tube + bridge to the arm
    d.rectangle([4, 0, 7, 6], fill=NAV[1][1], outline=NAV[0])
    d.line([5, 1, 5, 5], fill=NAV[1][3])
    d.rectangle([7, 3, 9, 4], fill=NAV[1][1])
    d.rectangle([4, 0, 7, 0], fill=MET[1][3])
    # objective lens
    d.rectangle([5, 7, 6, 8], fill=MET[1][3])
    # stage with a slide, lamp beneath
    d.rectangle([2, 9, 9, 10], fill=MET[1][2], outline=MET[0])
    d.line([4, 9, 7, 9], fill=WHITE)
    d.point((5, 11), fill=YELLOW)
    # focus knob
    d.rectangle([13, 7, 14, 8], fill=MET[1][3], outline=MET[0])


# --- wall art -------------------------------------------------------------

def draw_defibrillator(d, W, H):
    # carry handle
    d.rectangle([5, 0, 10, 1], fill=RUBBER, outline=OUT)
    # red AED case
    panel(d, 1, 1, 14, 14, RED, top=(220, 100, 80))
    d.line([2, 13, 13, 13], fill=(140, 40, 35))
    d.line([13, 2, 13, 13], fill=(140, 40, 35))
    # white front label with a red heart
    d.rectangle([3, 3, 12, 10], fill=WHITE, outline=(140, 40, 35))
    for x, y in ((6, 4), (8, 4), (5, 5), (6, 5), (7, 5), (8, 5), (9, 5),
                 (6, 6), (7, 6), (8, 6), (7, 7)):
        d.point((x, y), fill=RED)
    d.point((6, 4), fill=(235, 110, 100))
    # bolt on the heart + status lamp
    d.point((10, 8), fill=YELLOW)
    d.point((11, 9), fill=YELLOW)
    d.point((4, 12), fill=GREEN)
    d.rectangle([7, 12, 10, 12], fill=(140, 40, 35))


def draw_anatomy_poster(d, W, H):
    # wooden frame with a white chart
    box(d, 0, 0, W - 1, H - 1, WOOD)
    d.rectangle([2, 2, W - 3, H - 3], fill=CER[1][3], outline=CER[1][0])
    ink = NAV[1][1]
    # title line
    d.line([4, 4, 11, 4], fill=ink)
    # figure: head, torso, arms, legs
    d.ellipse([6, 6, 9, 9], fill=PINK, outline=OUT)
    d.rectangle([5, 10, 10, 18], fill=PINK, outline=OUT)
    d.line([6, 11, 6, 17], fill=(236, 168, 184))
    d.line([4, 11, 3, 17], fill=PINK)
    d.line([11, 11, 12, 17], fill=PINK)
    d.rectangle([5, 19, 6, 26], fill=PINK, outline=OUT)
    d.rectangle([9, 19, 10, 26], fill=PINK, outline=OUT)
    # organs: heart + lungs / gut lines
    d.point((8, 12), fill=RED)
    d.point((7, 12), fill=RED)
    d.line([6, 14, 9, 14], fill=(150, 90, 100))
    d.line([6, 16, 9, 16], fill=(150, 90, 100))
    # callout labels on the margins
    d.line([2, 12, 3, 12], fill=ink)
    d.line([12, 8, 13, 8], fill=ink)
    d.line([12, 20, 13, 20], fill=ink)
    d.line([2, 23, 3, 23], fill=ink)
    d.line([4, 28, 11, 28], fill=NAV[1][2])


ITEMS = [
    {
        "id": "hos_nurse_station", "surface": True, "name": "Nurse Station", "category": "furniture",
        "size": [3, 2], "zones": ["civil"], "room_type": "ward",
        "weight": 24, "tool_tier": 1, "skill": 0, "scrap_time": 4.0, "xp": 8,
        "storage_slots": 6,
        "yields": [
            {"item": "wood", "min": 3, "max": 5},
            {"item": "plastic", "min": 2, "max": 3},
            {"item": "scrap_metal", "min": 1, "max": 2},
        ],
        "draw": draw_nurse_station,
    },
    {
        "id": "hos_exam_table", "surface": True, "name": "Exam Table", "category": "furniture",
        "size": [3, 1], "zones": ["civil"], "room_type": "ward",
        "weight": 16, "tool_tier": 1, "skill": 0, "scrap_time": 3.0, "xp": 6,
        "yields": [
            {"item": "scrap_metal", "min": 2, "max": 4},
            {"item": "cloth", "min": 2, "max": 3},
        ],
        "draw": draw_exam_table,
    },
    {
        "id": "hos_supply_shelving", "name": "Supply Shelving", "category": "furniture",
        "size": [2, 3], "zones": ["civil"], "room_type": "ward",
        "weight": 18, "tool_tier": 1, "skill": 0, "scrap_time": 3.5, "xp": 7,
        "storage_slots": 8,
        "yields": [
            {"item": "scrap_metal", "min": 3, "max": 5},
            {"item": "plastic", "min": 1, "max": 3},
        ],
        "draw": draw_supply_shelving,
    },
    {
        "id": "hos_scale", "name": "Physician's Scale", "category": "furniture",
        "size": [1, 2], "zones": ["civil"], "room_type": "ward",
        "weight": 10, "tool_tier": 1, "skill": 0, "scrap_time": 2.0, "xp": 4,
        "yields": [{"item": "scrap_metal", "min": 2, "max": 4}],
        "draw": draw_scale,
    },
    {
        "id": "hos_crutches", "name": "Crutches", "category": "furniture",
        "size": [1, 2], "zones": ["civil"], "room_type": "ward",
        "weight": 4, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [
            {"item": "scrap_metal", "min": 1, "max": 2},
            {"item": "plastic", "min": 1, "max": 2},
        ],
        "draw": draw_crutches,
    },
    {
        "id": "hos_waiting_chairs", "name": "Waiting-Room Chairs", "category": "furniture",
        "size": [3, 1], "zones": ["civil"], "room_type": "ward",
        "weight": 16, "tool_tier": 1, "skill": 0, "scrap_time": 3.0, "xp": 6,
        "yields": [
            {"item": "plastic", "min": 3, "max": 5},
            {"item": "scrap_metal", "min": 2, "max": 3},
        ],
        "draw": draw_waiting_chairs,
    },
    {
        "id": "hos_microscope", "name": "Microscope", "category": "clutter",
        "size": [1, 1], "zones": ["civil"], "room_type": "ward",
        "weight": 3, "tool_tier": 0, "skill": 1, "scrap_time": 1.5, "xp": 3,
        "yields": [
            {"item": "scrap_metal", "min": 1, "max": 2},
            {"item": "plastic", "min": 1, "max": 2},
        ],
        "draw": draw_microscope,
    },
    {
        "id": "hos_defibrillator", "name": "Wall Defibrillator", "category": "wall_art",
        "size": [1, 1], "zones": ["civil"], "room_type": "ward",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.2, "xp": 3,
        "wall_mounted": True,
        "yields": [
            {"item": "plastic", "min": 1, "max": 2},
            {"item": "scrap_metal", "min": 0, "max": 1},
        ],
        "draw": draw_defibrillator,
    },
    {
        "id": "hos_anatomy_poster", "name": "Anatomy Poster", "category": "wall_art",
        "size": [1, 2], "zones": ["civil"], "room_type": "ward",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.2, "xp": 3,
        "wall_mounted": True,
        "yields": [
            {"item": "cloth", "min": 0, "max": 1},
            {"item": "wood", "min": 1, "max": 2},
        ],
        "draw": draw_anatomy_poster,
    },
]
