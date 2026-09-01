"""Hospital ward (patient care floor) room-pack items for SunkenCity.

Scrappable furniture, storage, clutter, and wall art for drowned hospital
patient rooms / nurses stations. Style per docs/technical/TileArt.md:
material ramps, 1px outlines, light top/left + dark bottom/right shading,
5-7 colors per item, bottom-anchored floor items. Deterministic drawing.
"""
from common import *

MET = RAMPS["metal"]
CER = RAMPS["ceramic"]
PLA = RAMPS["plastic"]
NAV = RAMPS["navy"]
FAB = RAMPS["fabric"]


# --- furniture ------------------------------------------------------------

def draw_gurney(d, W, H):
    # wheels
    d.ellipse([4, H - 6, 9, H - 1], fill=MET[1][0], outline=MET[0])
    d.ellipse([W - 10, H - 6, W - 5, H - 1], fill=MET[1][0], outline=MET[0])
    d.point((6, H - 4), fill=MET[2])
    d.point((W - 8, H - 4), fill=MET[2])
    # legs + cross brace
    d.rectangle([6, H - 11, 7, H - 6], fill=MET[1][1])
    d.rectangle([W - 8, H - 11, W - 7, H - 6], fill=MET[1][1])
    d.rectangle([9, H - 9, W - 10, H - 8], fill=MET[1][1])
    # bed frame
    box(d, 1, H - 15, W - 2, H - 11, MET)
    # mattress
    box(d, 2, H - 20, W - 3, H - 15, CER)
    # teal blanket over the foot end
    panel(d, 3, H - 19, 20, H - 16, TEAL, top=(110, 190, 180))
    # pillow at the head end
    box(d, W - 13, H - 24, W - 4, H - 19, CER)
    # fold-up side rail
    d.rectangle([3, H - 24, 4, H - 20], fill=MET[1][2])
    d.rectangle([13, H - 24, 14, H - 20], fill=MET[1][2])
    d.rectangle([3, H - 25, 14, H - 24], fill=MET[1][3])


def draw_iv_stand(d, W, H):
    # rolling base
    d.rectangle([2, H - 3, 13, H - 1], fill=MET[1][1], outline=MET[0])
    # pole (light left, dark right)
    d.rectangle([7, 4, 8, H - 3], fill=MET[1][1])
    d.line([7, 4, 7, H - 4], fill=MET[1][3])
    # hook bar
    d.rectangle([3, 3, 12, 4], fill=MET[1][2], outline=MET[0])
    # hanging IV bag with fluid
    panel(d, 2, 5, 7, 13, WHITE, top=(240, 240, 236))
    d.rectangle([3, 9, 6, 12], fill=TEAL)
    d.line([3, 9, 5, 9], fill=(110, 190, 180))
    # drip tube looping down to the pole
    d.line([4, 14, 4, 21], fill=TEAL)
    d.line([4, 21, 6, 23], fill=TEAL)
    d.point((7, 24), fill=TEAL)


def draw_privacy_screen(d, W, H):
    # two folded curtain panels, offset to read as a hinge
    box(d, 1, 3, 14, H - 5, CER)
    box(d, 15, 5, 30, H - 3, CER)
    # teal band across each panel
    d.rectangle([2, 7, 13, 9], fill=TEAL)
    d.line([2, 7, 13, 7], fill=(110, 190, 180))
    d.rectangle([16, 9, 29, 11], fill=TEAL)
    d.line([16, 9, 29, 9], fill=(110, 190, 180))
    # fabric sag folds
    d.line([6, 12, 6, H - 7], fill=CER[1][1])
    d.line([10, 12, 10, H - 7], fill=CER[1][1])
    d.line([20, 14, 20, H - 5], fill=CER[1][1])
    d.line([25, 14, 25, H - 5], fill=CER[1][1])
    # feet
    d.rectangle([3, H - 4, 4, H - 1], fill=MET[1][1], outline=MET[0])
    d.rectangle([11, H - 4, 12, H - 1], fill=MET[1][1], outline=MET[0])
    d.rectangle([18, H - 2, 19, H - 1], fill=MET[1][1])
    d.rectangle([26, H - 2, 27, H - 1], fill=MET[1][1])


def draw_wheelchair(d, W, H):
    # push handle + backrest
    d.rectangle([5, 1, 10, 2], fill=MET[1][2], outline=MET[0])
    box(d, 5, 3, 9, 16, NAV)
    # seat
    box(d, 7, 14, 22, 18, NAV)
    # big rear wheel (open rim so the seat shows through)
    d.ellipse([1, 13, 19, 31], outline=MET[0])
    d.ellipse([2, 14, 18, 30], outline=MET[1][1])
    d.ellipse([4, 16, 16, 28], outline=MET[1][3])
    d.line([10, 18, 10, 26], fill=MET[1][1])
    d.line([6, 22, 14, 22], fill=MET[1][1])
    d.point((10, 22), fill=MET[2])
    # frame down to the caster
    d.line([22, 18, 26, 26], fill=MET[1][1])
    # footrest
    d.rectangle([26, 22, 30, 23], fill=MET[1][2])
    # front caster
    d.ellipse([24, 26, 29, 31], fill=MET[1][0], outline=MET[0])
    d.point((26, 28), fill=MET[2])


def draw_vitals_monitor(d, W, H):
    # rolling base + pole
    d.rectangle([2, H - 3, 13, H - 1], fill=MET[1][1], outline=MET[0])
    d.rectangle([7, 12, 8, H - 3], fill=MET[1][1])
    d.line([7, 13, 7, H - 4], fill=MET[1][3])
    # monitor shell
    box(d, 1, 1, 14, 12, PLA)
    # screen with ECG trace
    d.rectangle([3, 3, 12, 8], fill=NAV[1][0], outline=NAV[0])
    d.line([4, 6, 5, 6], fill=GREEN)
    d.point((6, 4), fill=GREEN)
    d.point((7, 7), fill=GREEN)
    d.line([8, 5, 10, 5], fill=GREEN)
    d.point((11, 6), fill=GREEN)
    # button row
    d.point((4, 10), fill=TEAL)
    d.point((6, 10), fill=YELLOW)
    d.point((8, 10), fill=RED)


# --- storage --------------------------------------------------------------

def draw_med_cabinet(d, W, H):
    box(d, 1, 1, W - 2, H - 2, CER)
    # upper glass doors with shelf + glint
    d.rectangle([4, 5, 14, 17], fill=NAV[1][1], outline=OUT)
    d.rectangle([17, 5, 27, 17], fill=NAV[1][1], outline=OUT)
    d.line([5, 11, 13, 11], fill=NAV[1][2])
    d.line([18, 11, 26, 11], fill=NAV[1][2])
    d.line([6, 9, 9, 6], fill=NAV[2])
    d.line([19, 9, 22, 6], fill=NAV[2])
    # bottles behind the glass
    d.point((7, 10), fill=WHITE)
    d.point((10, 10), fill=TEAL)
    d.point((21, 10), fill=WHITE)
    d.point((24, 10), fill=ORANGE)
    # counter divide
    d.rectangle([2, 19, W - 3, 20], fill=CER[1][1])
    # lower double doors with red cross
    d.line([15, 22, 15, H - 5], fill=CER[1][1])
    d.rectangle([14, 25, 17, 32], fill=RED)
    d.rectangle([11, 28, 20, 29], fill=RED)
    d.point((12, 38), fill=MET[1][3])
    d.point((19, 38), fill=MET[1][3])
    # feet
    d.rectangle([2, H - 2, 4, H - 1], fill=OUT)
    d.rectangle([W - 5, H - 2, W - 3, H - 1], fill=OUT)


def draw_linen_hamper(d, W, H):
    # casters
    d.ellipse([3, H - 5, 7, H - 1], fill=MET[1][0], outline=MET[0])
    d.ellipse([W - 8, H - 5, W - 4, H - 1], fill=MET[1][0], outline=MET[0])
    d.point((5, H - 3), fill=MET[2])
    d.point((W - 6, H - 3), fill=MET[2])
    # frame bar
    d.rectangle([2, H - 7, W - 3, H - 5], fill=MET[1][1], outline=MET[0])
    # canvas bag with sag folds
    box(d, 3, 9, W - 4, H - 7, FAB)
    d.line([9, 12, 9, H - 9], fill=FAB[1][0])
    d.line([16, 12, 16, H - 9], fill=FAB[1][0])
    d.line([23, 12, 23, H - 9], fill=FAB[1][0])
    # metal rim
    d.rectangle([2, 8, W - 3, 10], fill=MET[1][2], outline=MET[0])
    # linens piled over the top
    d.rectangle([6, 4, 15, 8], fill=WHITE, outline=OUT)
    d.line([7, 6, 14, 6], fill=(198, 198, 192))
    d.rectangle([17, 5, 24, 8], fill=CER[1][2], outline=OUT)


# --- clutter --------------------------------------------------------------

def draw_pill_bottles(d, W, H):
    # amber prescription bottle with white cap
    panel(d, 2, 7, 7, 14, ORANGE, top=(235, 160, 90))
    d.rectangle([2, 5, 7, 7], fill=WHITE, outline=OUT)
    d.rectangle([3, 10, 6, 12], fill=WHITE)
    # white bottle with teal cap
    box(d, 9, 4, 14, 14, CER)
    d.rectangle([9, 2, 14, 4], fill=TEAL, outline=OUT)
    d.rectangle([10, 8, 13, 10], fill=RED)
    # spilled pills
    d.point((5, 15), fill=WHITE)
    d.point((8, 15), fill=RED)


def draw_bedpan(d, W, H):
    # stainless pan, wide and shallow
    d.rectangle([1, 9, 12, 15], fill=MET[1][2], outline=MET[0])
    d.line([2, 10, 11, 10], fill=MET[2])
    d.rectangle([3, 11, 10, 13], fill=MET[1][0])
    d.point((4, 12), fill=MET[1][2])
    # grip tab
    d.rectangle([12, 11, 14, 13], fill=MET[1][1], outline=MET[0])


def draw_biohazard_bin(d, W, H):
    # red sharps bin
    panel(d, 3, 6, 12, 15, RED, top=(220, 100, 80))
    d.line([4, 14, 11, 14], fill=(140, 40, 35))
    # lid + knob
    d.rectangle([2, 4, 13, 6], fill=(150, 45, 40), outline=OUT)
    d.rectangle([6, 2, 9, 4], fill=(150, 45, 40), outline=OUT)
    # biohazard trefoil dots
    d.point((7, 9), fill=YELLOW)
    d.point((5, 11), fill=YELLOW)
    d.point((9, 11), fill=YELLOW)


def draw_oxygen_tank(d, W, H):
    # standing cylinder with valve
    panel(d, 9, 3, 14, 14, TEAL, top=(110, 190, 180))
    d.line([10, 4, 10, 13], fill=(130, 205, 195))
    d.rectangle([10, 1, 13, 3], fill=MET[1][2], outline=MET[0])
    # fallen cylinder at its foot
    d.rectangle([0, 11, 8, 15], fill=(58, 138, 128), outline=OUT)
    d.line([1, 12, 7, 12], fill=(110, 190, 180))
    d.rectangle([0, 12, 1, 14], fill=MET[1][1])


# --- wall art -------------------------------------------------------------

def draw_eye_chart(d, W, H):
    box(d, 2, 0, 13, 14, CER)
    ink = NAV[1][0]
    # big E
    d.line([6, 2, 8, 2], fill=ink)
    d.line([6, 3, 7, 3], fill=ink)
    d.line([6, 4, 8, 4], fill=ink)
    d.line([6, 2, 6, 4], fill=ink)
    # shrinking letter rows
    d.line([5, 6, 6, 6], fill=ink)
    d.line([8, 6, 9, 6], fill=ink)
    for x in (4, 6, 8, 10):
        d.point((x, 8), fill=NAV[1][1])
    for x in (5, 7, 9):
        d.point((x, 10), fill=NAV[1][2])
    # red cutoff line
    d.line([5, 12, 10, 12], fill=RED)


def draw_xray_lightbox(d, W, H):
    box(d, 0, 0, W - 1, H - 1, MET)
    d.rectangle([2, 2, W - 3, H - 3], fill=NAV[1][0], outline=NAV[0])
    # two clipped films
    d.rectangle([4, 4, 13, H - 5], fill=NAV[1][2], outline=NAV[0])
    d.rectangle([18, 4, 27, H - 5], fill=NAV[1][2], outline=NAV[0])
    # left film: spine + ribs
    d.line([8, 5, 8, 10], fill=WHITE)
    d.line([6, 6, 10, 6], fill=WHITE)
    d.line([6, 8, 10, 8], fill=WHITE)
    # right film: long bones
    d.line([21, 5, 23, 10], fill=WHITE)
    d.line([24, 5, 25, 10], fill=WHITE)
    # power lamp
    d.point((28, H - 2), fill=GREEN)


def draw_sanitizer(d, W, H):
    # wall bracket
    d.rectangle([4, 1, 11, 3], fill=MET[1][1], outline=MET[0])
    # dispenser shell
    box(d, 3, 3, 12, 11, CER)
    # gel level window + teal label
    d.rectangle([5, 5, 7, 9], fill=TEAL, outline=OUT)
    d.line([5, 5, 6, 5], fill=(110, 190, 180))
    d.rectangle([9, 5, 10, 6], fill=TEAL)
    # nozzle + drip
    d.rectangle([6, 11, 9, 13], fill=MET[1][1], outline=MET[0])
    d.point((7, 14), fill=TEAL)


ITEMS = [
    {
        "id": "hos_gurney", "name": "Hospital Gurney", "category": "furniture",
        "size": [3, 2], "zones": ["civil"], "room_type": "ward",
        "weight": 20, "tool_tier": 1, "skill": 0, "scrap_time": 3.5, "xp": 7,
        "yields": [
            {"item": "scrap_metal", "min": 3, "max": 5},
            {"item": "cloth", "min": 2, "max": 4},
            {"item": "plastic", "min": 1, "max": 2},
        ],
        "draw": draw_gurney,
    },
    {
        "id": "hos_iv_stand", "name": "IV Stand", "category": "furniture",
        "size": [1, 2], "zones": ["civil"], "room_type": "ward",
        "weight": 6, "tool_tier": 1, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [
            {"item": "scrap_metal", "min": 2, "max": 4},
            {"item": "plastic", "min": 2, "max": 3},
        ],
        "draw": draw_iv_stand,
    },
    {
        "id": "hos_privacy_screen", "name": "Privacy Screen", "category": "furniture",
        "size": [2, 2], "zones": ["civil"], "room_type": "ward",
        "weight": 10, "tool_tier": 0, "skill": 0, "scrap_time": 2.0, "xp": 4,
        "yields": [
            {"item": "cloth", "min": 3, "max": 5},
            {"item": "scrap_metal", "min": 1, "max": 2},
            {"item": "plastic", "min": 1, "max": 2},
        ],
        "draw": draw_privacy_screen,
    },
    {
        "id": "hos_wheelchair", "name": "Wheelchair", "category": "furniture",
        "size": [2, 2], "zones": ["civil"], "room_type": "ward",
        "weight": 14, "tool_tier": 1, "skill": 0, "scrap_time": 3.0, "xp": 6,
        "yields": [
            {"item": "scrap_metal", "min": 3, "max": 5},
            {"item": "plastic", "min": 1, "max": 2},
            {"item": "cloth", "min": 1, "max": 2},
        ],
        "draw": draw_wheelchair,
    },
    {
        "id": "hos_vitals_monitor", "name": "Vitals Monitor", "category": "furniture",
        "size": [1, 2], "zones": ["civil"], "room_type": "ward",
        "weight": 10, "tool_tier": 0, "skill": 1, "scrap_time": 2.5, "xp": 8,
        "yields": [
            {"item": "plastic", "min": 3, "max": 5},
            {"item": "scrap_metal", "min": 2, "max": 3},
            {"item": "iron", "min": 0, "max": 1},
        ],
        "draw": draw_vitals_monitor,
    },
    {
        "id": "hos_med_cabinet", "name": "Medicine Cabinet", "category": "furniture",
        "size": [2, 3], "zones": ["civil"], "room_type": "ward",
        "weight": 18, "tool_tier": 1, "skill": 0, "scrap_time": 3.5, "xp": 7,
        "storage_slots": 10,
        "yields": [
            {"item": "scrap_metal", "min": 3, "max": 5},
            {"item": "plastic", "min": 2, "max": 3},
            {"item": "iron", "min": 1, "max": 2},
        ],
        "draw": draw_med_cabinet,
    },
    {
        "id": "hos_linen_hamper", "name": "Linen Hamper", "category": "furniture",
        "size": [2, 2], "zones": ["civil"], "room_type": "ward",
        "weight": 12, "tool_tier": 0, "skill": 0, "scrap_time": 2.0, "xp": 5,
        "storage_slots": 6,
        "yields": [
            {"item": "cloth", "min": 4, "max": 6},
            {"item": "scrap_metal", "min": 1, "max": 2},
            {"item": "plastic", "min": 1, "max": 2},
        ],
        "draw": draw_linen_hamper,
    },
    {
        "id": "hos_pill_bottles", "name": "Pill Bottles", "category": "clutter",
        "size": [1, 1], "zones": ["civil"], "room_type": "ward",
        "weight": 1, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "plastic", "min": 1, "max": 2}],
        "draw": draw_pill_bottles,
    },
    {
        "id": "hos_bedpan", "name": "Bedpan", "category": "clutter",
        "size": [1, 1], "zones": ["civil"], "room_type": "ward",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_bedpan,
    },
    {
        "id": "hos_biohazard_bin", "name": "Biohazard Bin", "category": "clutter",
        "size": [1, 1], "zones": ["civil"], "room_type": "ward",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.2, "xp": 3,
        "yields": [{"item": "plastic", "min": 1, "max": 3}],
        "draw": draw_biohazard_bin,
    },
    {
        "id": "hos_oxygen_tank", "name": "Oxygen Tanks", "category": "clutter",
        "size": [1, 1], "zones": ["civil"], "room_type": "ward",
        "weight": 4, "tool_tier": 1, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 3}],
        "draw": draw_oxygen_tank,
    },
    {
        "id": "hos_eye_chart", "name": "Eye Chart", "category": "wall_art",
        "size": [1, 1], "zones": ["civil"], "room_type": "ward",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "wall_mounted": True,
        "yields": [{"item": "wood", "min": 1, "max": 2}],
        "draw": draw_eye_chart,
    },
    {
        "id": "hos_xray_lightbox", "name": "X-ray Lightbox", "category": "wall_art",
        "size": [2, 1], "zones": ["civil"], "room_type": "ward",
        "weight": 6, "tool_tier": 1, "skill": 0, "scrap_time": 2.0, "xp": 5,
        "wall_mounted": True,
        "yields": [
            {"item": "scrap_metal", "min": 2, "max": 3},
            {"item": "plastic", "min": 1, "max": 2},
        ],
        "draw": draw_xray_lightbox,
    },
    {
        "id": "hos_sanitizer", "name": "Sanitizer Dispenser", "category": "wall_art",
        "size": [1, 1], "zones": ["civil"], "room_type": "ward",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "wall_mounted": True,
        "yields": [{"item": "plastic", "min": 1, "max": 2}],
        "draw": draw_sanitizer,
    },
]
