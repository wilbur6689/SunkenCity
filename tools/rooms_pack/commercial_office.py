"""Commercial zone — corporate office floor items (cubicles / meeting / break room).

Drowned-city office scavenge set: waterlogged conference furniture, cubicle
partitions, dead electronics, and corporate wall dressing. Style per
docs/technical/TileArt.md via the common.py ramps/helpers.
"""
from common import *

WOOD = RAMPS["wood"]
METAL = RAMPS["metal"]
PLASTIC = RAMPS["plastic"]
FABRIC = RAMPS["fabric"]
CERAMIC = RAMPS["ceramic"]
NAVY = RAMPS["navy"]


# ---------------------------------------------------------------- furniture


def draw_conference_table(d, W, H):
    # long lacquered tabletop flush with the block top (things sit on it), sturdy end legs
    box(d, 3, 5, 6, H - 1, WOOD)                        # left leg
    box(d, W - 7, 5, W - 4, H - 1, WOOD)                # right leg
    box(d, 0, 0, W - 1, 4, WOOD)                        # top slab
    d.line([1, 1, W - 2, 1], fill=WOOD[2])              # polished highlight
    d.rectangle([7, 5, W - 8, 6], fill=WOOD[1][0])      # apron shadow


def draw_office_chair(d, W, H):
    # swivel chair: navy padded back + seat, gas lift, 5-star base w/ wheels
    box(d, 4, 3, 11, 15, NAVY)                          # backrest
    d.rectangle([6, 5, 9, 12], fill=NAVY[1][1])         # cushion stitch panel
    box(d, 2, 16, 13, 20, NAVY)                         # seat
    d.line([3, 17, 12, 17], fill=NAVY[2])
    d.rectangle([1, 12, 2, 16], fill=METAL[1][1], outline=None)   # armrests
    d.rectangle([13, 12, 14, 16], fill=METAL[1][1], outline=None)
    d.point((1, 12), fill=METAL[2]); d.point((13, 12), fill=METAL[2])
    d.rectangle([7, 21, 8, 26], fill=METAL[1][1])       # gas lift
    d.point((7, 21), fill=METAL[2])
    d.line([2, 28, 13, 28], fill=METAL[1][2])           # star base arms
    d.line([7, 26, 7, 28], fill=METAL[1][2])
    d.line([8, 26, 8, 28], fill=METAL[1][1])
    for x in (1, 7, 12):                                # casters
        d.rectangle([x, 29, x + 2, 31], fill=METAL[1][0], outline=OUT)


def draw_cubicle_wall(d, W, H):
    # freestanding partition: metal frame, sound-fabric infill, pinned notes
    box(d, 1, 0, W - 2, H - 1, METAL, bevel=False)      # frame
    d.line([2, 1, W - 3, 1], fill=METAL[1][3])
    box(d, 4, 4, W - 5, H - 6, FABRIC)                  # fabric panel
    d.rectangle([2, H - 3, 5, H - 1], fill=METAL[1][1], outline=OUT)     # feet
    d.rectangle([W - 6, H - 3, W - 3, H - 1], fill=METAL[1][1], outline=OUT)
    d.rectangle([7, 7, 13, 12], fill=WHITE, outline=OUT)                 # memo
    d.line([8, 9, 12, 9], fill=NAVY[1][1]); d.line([8, 11, 11, 11], fill=NAVY[1][1])
    d.rectangle([17, 10, 22, 15], fill=YELLOW, outline=OUT)              # sticky note
    d.point((19, 12), fill=ORANGE)


def draw_water_cooler(d, W, H):
    # blue bottle atop a white dispenser column
    box(d, 3, 14, 12, H - 2, CERAMIC)                   # cabinet
    d.rectangle([4, H - 2, 6, H - 1], fill=OUT)         # feet
    d.rectangle([9, H - 2, 11, H - 1], fill=OUT)
    d.rectangle([4, 19, 11, 24], fill=CERAMIC[1][0])    # drip alcove
    d.rectangle([5, 19, 6, 20], fill=BLUE)              # cold tap
    d.rectangle([9, 19, 10, 20], fill=RED)              # hot tap
    d.rectangle([7, 22, 8, 24], fill=WHITE)             # paper cup
    box(d, 3, 3, 12, 13, NAVY)                          # water bottle
    d.rectangle([4, 4, 5, 11], fill=NAVY[1][3])         # glass sheen
    d.line([4, 9, 11, 9], fill=NAVY[2])                 # water line
    d.rectangle([6, 0, 9, 3], fill=NAVY[1][0], outline=OUT)   # neck


def draw_copier(d, W, H):
    # prized office copier: scanner lid, control panel, output + paper trays
    box(d, 1, 10, W - 2, H - 3, CERAMIC)                # main body
    d.rectangle([3, H - 3, 5, H - 1], fill=OUT)         # feet
    d.rectangle([W - 6, H - 3, W - 4, H - 1], fill=OUT)
    box(d, 2, 6, W - 8, 10, METAL)                      # scanner lid
    d.line([3, 7, W - 10, 7], fill=METAL[2])
    box(d, W - 8, 4, W - 2, 10, CERAMIC)                # control console
    d.rectangle([W - 7, 5, W - 4, 7], fill=NAVY[1][2])  # screen
    d.point((W - 3, 8), fill=GREEN)                     # ready light
    d.rectangle([4, 14, W - 6, 15], fill=(40, 40, 44))  # output slot
    d.rectangle([5, 13, 12, 13], fill=WHITE)            # ejected page
    box(d, 4, 19, W - 5, 24, CERAMIC)                   # paper drawer
    d.line([8, 21, W - 9, 21], fill=CERAMIC[1][0])      # drawer pull
    box(d, 4, 25, W - 5, H - 4, CERAMIC)                # lower drawer
    d.line([8, 27, W - 9, 27], fill=CERAMIC[1][0])


# ------------------------------------------------------------------ storage

def draw_filing_cabinet(d, W, H):
    # steel 3-drawer vertical file
    box(d, 2, 1, 13, H - 1, METAL, bevel=False)
    d.line([3, 2, 12, 2], fill=METAL[1][3])
    for y0 in (3, 13, 23):                              # drawers
        box(d, 4, y0 + 1, 11, y0 + 8, METAL)
        d.rectangle([6, y0 + 3, 9, y0 + 4], fill=METAL[1][0])   # recessed pull
        d.line([6, y0 + 3, 9, y0 + 3], fill=METAL[2])
        d.rectangle([6, y0 + 6, 9, y0 + 6], fill=WHITE)         # label slot
    d.point((12, 4), fill=METAL[2])                     # lock cylinder


def draw_supply_cabinet(d, W, H):
    # tall gray double-door office supply cabinet
    box(d, 1, 0, W - 2, H - 1, METAL, bevel=False)
    d.line([2, 1, W - 3, 1], fill=METAL[1][3])
    box(d, 3, 3, W // 2 - 1, H - 4, METAL)              # left door
    box(d, W // 2, 3, W - 4, H - 4, METAL)              # right door
    d.rectangle([W // 2 - 3, 20, W // 2 - 3, 26], fill=METAL[2])   # handles
    d.rectangle([W // 2 + 2, 20, W // 2 + 2, 26], fill=METAL[2])
    for y in (7, 9, 11):                                # vent louvres
        d.line([6, y, W // 2 - 4, y], fill=METAL[1][0])
        d.line([W // 2 + 3, y, W - 7, y], fill=METAL[1][0])
    d.rectangle([2, H - 3, 4, H - 1], fill=OUT)         # feet
    d.rectangle([W - 5, H - 3, W - 3, H - 1], fill=OUT)


# ------------------------------------------------------------------ clutter

def draw_monitor(d, W, H):
    # dead desktop monitor on a stand
    box(d, 1, 1, 14, 11, NAVY)                          # bezel
    d.rectangle([3, 3, 12, 9], fill=(30, 38, 52))       # dark dead screen
    d.line([4, 4, 7, 4], fill=NAVY[1][3])               # glass glint
    d.point((13, 10), fill=GREEN)                       # standby led
    d.rectangle([6, 12, 9, 13], fill=METAL[1][1], outline=OUT)   # stand
    d.rectangle([3, 14, 12, 15], fill=METAL[1][2], outline=OUT)  # base


def draw_desk_phone(d, W, H):
    # corded office phone, handset resting on the wedge body
    d.polygon([(1, 9), (14, 9), (13, 15), (2, 15)], fill=CERAMIC[1][2], outline=OUT)
    d.line([3, 10, 12, 10], fill=CERAMIC[2])
    for yy in (11, 13):                                 # keypad rows
        for xx in (8, 10, 12):
            d.point((xx, yy), fill=CERAMIC[1][0])
    d.rectangle([3, 11, 6, 13], fill=NAVY[1][2])        # display
    d.rectangle([2, 6, 3, 9], fill=NAVY[1][1], outline=OUT)      # cradle posts
    d.rectangle([12, 6, 13, 9], fill=NAVY[1][1], outline=OUT)
    box(d, 1, 3, 14, 6, NAVY)                           # handset resting on cradle
    d.rectangle([5, 5, 10, 6], fill=NAVY[1][0])         # handset waist


def draw_paper_stack(d, W, H):
    # stack of soggy reports with a binder in the middle
    d.rectangle([3, 12, 13, 15], fill=WHITE, outline=OUT)        # bottom sheaf
    d.line([4, 13, 12, 13], fill=(196, 196, 190))
    d.rectangle([2, 9, 12, 11], fill=NAVY[1][2], outline=OUT)    # binder
    d.line([3, 10, 5, 10], fill=NAVY[1][3])
    d.rectangle([4, 5, 13, 8], fill=WHITE, outline=OUT)          # top sheaf
    d.line([5, 6, 11, 6], fill=BLUE)                             # printed lines
    d.line([5, 7, 9, 7], fill=(196, 196, 190))


def draw_trash_bin(d, W, H):
    # tapered mesh waste bin with a crumpled page
    d.polygon([(3, 4), (12, 4), (11, 15), (4, 15)], fill=METAL[1][1], outline=OUT)
    d.line([4, 5, 11, 5], fill=METAL[1][3])             # rim
    for x in (5, 7, 9):                                 # mesh ribs
        d.line([x, 7, x, 13], fill=METAL[1][0])
    d.polygon([(6, 1), (10, 2), (9, 4), (5, 4)], fill=WHITE, outline=OUT)  # crumpled paper


# ----------------------------------------------------------------- wall art

def draw_motivation_poster(d, W, H):
    # "TEAMWORK" sunset poster in a slim black frame
    d.rectangle([1, 0, 14, 15], fill=(38, 34, 32), outline=OUT)  # frame
    d.rectangle([3, 2, 12, 13], fill=NAVY[1][1])                 # dusk sky
    d.rectangle([3, 2, 12, 4], fill=NAVY[1][2])
    d.ellipse([6, 3, 9, 6], fill=ORANGE, outline=None)           # setting sun
    d.polygon([(3, 10), (7, 6), (10, 10)], fill=NAVY[1][0])      # mountain
    d.line([4, 12, 11, 12], fill=WHITE)                          # slogan bar
    d.point((5, 5), fill=YELLOW)                                 # glint


def draw_whiteboard(d, W, H):
    # wall whiteboard: aluminum frame, meeting scrawl, marker tray
    box(d, 0, 1, W - 1, H - 4, METAL, bevel=False)
    d.line([1, 2, W - 2, 2], fill=METAL[1][3])
    d.rectangle([2, 3, W - 3, H - 6], fill=WHITE, outline=None)  # board face
    d.line([4, 5, 15, 5], fill=NAVY[1][1])                       # agenda scrawl
    d.line([4, 7, 11, 7], fill=NAVY[1][1])
    d.line([18, 7, 26, 5], fill=RED)                             # trend arrow
    d.polygon([(26, 4), (28, 5), (26, 6)], fill=RED)
    d.line([20, 9, 27, 9], fill=DARKGREEN)
    d.rectangle([8, H - 3, W - 9, H - 2], fill=METAL[1][2], outline=OUT)  # pen tray
    d.rectangle([12, H - 4, 15, H - 4], fill=RED)                # marker
    d.rectangle([18, H - 4, 21, H - 4], fill=BLUE)


def draw_logo_sign(d, W, H):
    # backlit lobby sign for the drowned firm ("wave" mark + name bars)
    box(d, 0, 2, W - 1, H - 3, NAVY, bevel=False)
    d.line([1, 3, W - 2, 3], fill=NAVY[1][3])
    d.rectangle([1, H - 4, W - 2, H - 4], fill=NAVY[1][0])
    d.ellipse([3, 5, 10, 12], fill=TEAL, outline=OUT)            # wave roundel
    d.arc([4, 7, 9, 12], 200, 340, fill=WHITE)                   # wave crest
    d.line([13, 6, 27, 6], fill=WHITE)                           # company name
    d.line([13, 9, 23, 9], fill=CERAMIC[1][2])                   # tagline
    d.point((2, 4), fill=(154, 170, 186))                        # mount screws
    d.point((W - 3, 4), fill=(154, 170, 186))


# -------------------------------------------------------------------- items

ITEMS = [
    {
        "id": "com_conference_table", "surface": True, "name": "Conference Table",
        "category": "furniture", "size": [4, 1], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 20, "tool_tier": 0, "skill": 0,
        "scrap_time": 3.0, "xp": 6,
        "yields": [{"item": "wood", "min": 6, "max": 10},
                   {"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_conference_table,
    },
    {
        "id": "com_office_chair", "name": "Office Chair",
        "category": "furniture", "size": [1, 2], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 8, "tool_tier": 0, "skill": 0,
        "scrap_time": 2.0, "xp": 4,
        "yields": [{"item": "plastic", "min": 2, "max": 4},
                   {"item": "cloth", "min": 1, "max": 3},
                   {"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_office_chair,
    },
    {
        "id": "com_cubicle_wall", "name": "Cubicle Divider",
        "category": "furniture", "size": [2, 2], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 12, "tool_tier": 0, "skill": 0,
        "scrap_time": 2.5, "xp": 5,
        "yields": [{"item": "cloth", "min": 2, "max": 4},
                   {"item": "scrap_metal", "min": 2, "max": 4},
                   {"item": "plastic", "min": 1, "max": 2}],
        "draw": draw_cubicle_wall,
    },
    {
        "id": "com_water_cooler", "name": "Water Cooler",
        "category": "furniture", "size": [1, 2], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 10, "tool_tier": 0, "skill": 0,
        "scrap_time": 2.0, "xp": 4,
        "yields": [{"item": "plastic", "min": 4, "max": 6},
                   {"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_water_cooler,
    },
    {
        "id": "com_copier", "name": "Office Copier",
        "category": "furniture", "size": [2, 2], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 22, "tool_tier": 1, "skill": 1,
        "scrap_time": 4.0, "xp": 8,
        "yields": [{"item": "scrap_metal", "min": 4, "max": 6},
                   {"item": "plastic", "min": 3, "max": 5},
                   {"item": "iron", "min": 1, "max": 2}],
        "draw": draw_copier,
    },
    {
        "id": "com_filing_cabinet", "name": "Filing Cabinet",
        "category": "furniture", "size": [1, 2], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 14, "tool_tier": 1, "skill": 0,
        "scrap_time": 2.5, "xp": 5, "storage_slots": 6,
        "yields": [{"item": "scrap_metal", "min": 4, "max": 7},
                   {"item": "iron", "min": 0, "max": 1}],
        "draw": draw_filing_cabinet,
    },
    {
        "id": "com_supply_cabinet", "name": "Supply Cabinet",
        "category": "furniture", "size": [2, 3], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 18, "tool_tier": 1, "skill": 0,
        "scrap_time": 3.0, "xp": 6, "storage_slots": 10,
        "yields": [{"item": "scrap_metal", "min": 5, "max": 8},
                   {"item": "plastic", "min": 1, "max": 2}],
        "draw": draw_supply_cabinet,
    },
    {
        "id": "com_monitor", "name": "Desktop Monitor",
        "category": "clutter", "size": [1, 1], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 3, "tool_tier": 0, "skill": 0,
        "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "plastic", "min": 1, "max": 2},
                   {"item": "scrap_metal", "min": 0, "max": 1}],
        "draw": draw_monitor,
    },
    {
        "id": "com_desk_phone", "name": "Desk Phone",
        "category": "clutter", "size": [1, 1], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 1, "tool_tier": 0, "skill": 0,
        "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "plastic", "min": 1, "max": 2}],
        "draw": draw_desk_phone,
    },
    {
        "id": "com_paper_stack", "name": "Stack of Reports",
        "category": "clutter", "size": [1, 1], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 1, "tool_tier": 0, "skill": 0,
        "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "wood", "min": 1, "max": 2}],
        "draw": draw_paper_stack,
    },
    {
        "id": "com_trash_bin", "name": "Waste Bin",
        "category": "clutter", "size": [1, 1], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 2, "tool_tier": 0, "skill": 0,
        "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_trash_bin,
    },
    {
        "id": "com_motivation_poster", "name": "Motivational Poster",
        "category": "wall_art", "size": [1, 1], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 1, "tool_tier": 0, "skill": 0,
        "scrap_time": 1.0, "xp": 2, "wall_mounted": True,
        "yields": [{"item": "cloth", "min": 1, "max": 2}],
        "draw": draw_motivation_poster,
    },
    {
        "id": "com_whiteboard", "name": "Whiteboard",
        "category": "wall_art", "size": [2, 1], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 5, "tool_tier": 0, "skill": 0,
        "scrap_time": 1.5, "xp": 3, "wall_mounted": True,
        "yields": [{"item": "plastic", "min": 2, "max": 3},
                   {"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_whiteboard,
    },
    {
        "id": "com_logo_sign", "name": "Corporate Logo Sign",
        "category": "wall_art", "size": [2, 1], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 6, "tool_tier": 1, "skill": 0,
        "scrap_time": 1.5, "xp": 4, "wall_mounted": True,
        "yields": [{"item": "scrap_metal", "min": 2, "max": 3},
                   {"item": "plastic", "min": 1, "max": 2}],
        "draw": draw_logo_sign,
    },
]
