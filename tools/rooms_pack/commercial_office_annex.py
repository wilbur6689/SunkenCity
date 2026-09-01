"""Commercial zone — office annex items (server closet / reception / records).

Second office scavenge set: the IT closet rack, the lobby reception desk,
binder-stuffed record shelving, break-room appliances and the safety /
presentation wall dressing the main office pack left out. Style per
docs/technical/TileArt.md via the common.py ramps/helpers.
"""
from common import *

WOOD = RAMPS["wood"]
METAL = RAMPS["metal"]
PLASTIC = RAMPS["plastic"]
FABRIC = RAMPS["fabric"]
CERAMIC = RAMPS["ceramic"]
NAVY = RAMPS["navy"]          # doubles as dark appliance plastic (see com_monitor)

CORK = (176, 132, 82)         # cork face tones (board only)
CORK_DARK = (150, 108, 62)
CORK_LIGHT = (196, 154, 104)
COFFEE = (70, 44, 28)
PAPER_SHADE = (196, 196, 190)
RED_LIGHT = (222, 110, 96)
RED_DARK = (140, 40, 34)


def _dark(c):
    return tuple(max(0, v - 50) for v in c)


def _light(c):
    return tuple(min(255, v + 40) for v in c)


# ---------------------------------------------------------------- furniture

def draw_server_rack(d, W, H):
    # steel 1-column rack: dark bay interior, 1U drive sleds with status LEDs
    box(d, 1, 0, 14, H - 1, METAL, bevel=False)          # cabinet
    d.line([2, 1, 13, 1], fill=METAL[1][3])
    d.rectangle([3, 3, 12, H - 6], fill=METAL[1][0])     # rack interior
    for i in range(9):                                   # 1U sleds
        y0 = 4 + i * 4
        d.rectangle([4, y0, 11, y0 + 2], fill=METAL[1][2])
        d.line([4, y0, 11, y0], fill=METAL[1][3])        # sled top edge
        d.rectangle([5, y0 + 1, 7, y0 + 1], fill=METAL[1][0])   # pull slot
        d.point((10, y0 + 1), fill=RED if i in (2, 6) else GREEN)  # status LED
        if i in (1, 5, 7):
            d.point((9, y0 + 1), fill=ORANGE)            # activity LED
    d.line([4, H - 5, 11, H - 5], fill=METAL[1][1])      # vent louvre
    d.rectangle([2, H - 4, 13, H - 1], fill=METAL[1][0]) # plinth
    d.line([2, H - 4, 13, H - 4], fill=METAL[1][2])
    d.rectangle([2, H - 2, 4, H - 1], fill=OUT)          # feet
    d.rectangle([11, H - 2, 13, H - 1], fill=OUT)



def draw_reception_desk(d, W, H):
    # lobby front desk: panelled wood front, counter top flush with the block top
    box(d, 2, 5, W - 3, H - 1, WOOD, bevel=False)        # front panel
    d.line([3, 6, W - 4, 6], fill=WOOD[1][0])            # counter underside shadow
    for x in (16, 31):                                   # panel seams
        d.line([x, 7, x, H - 4], fill=WOOD[1][0])
        d.line([x + 1, 7, x + 1, H - 4], fill=WOOD[1][3])
    d.rectangle([3, H - 3, W - 4, H - 2], fill=WOOD[1][0])   # kick plate
    d.rectangle([19, 13, 28, 19], fill=NAVY[1][1], outline=OUT)  # firm plaque
    d.ellipse([21, 14, 25, 18], fill=TEAL, outline=None)         # wave roundel
    d.point((22, 15), fill=WHITE)
    box(d, 0, 0, W - 1, 4, WOOD)                         # counter slab
    d.line([1, 1, W - 2, 1], fill=WOOD[2])               # polished edge


def draw_office_bookcase(d, W, H):
    # records shelving: wood carcass packed with uniform ring binders
    o, t, hl = WOOD
    box(d, 0, 0, W - 1, H - 1, WOOD, bevel=False)
    d.line([1, 1, W - 2, 1], fill=hl)
    d.line([1, 2, 1, H - 2], fill=t[3])
    d.rectangle([3, 3, W - 4, H - 3], fill=t[0])         # dark interior
    for sy in (16, 30):                                  # shelf boards
        d.line([3, sy, W - 4, sy], fill=t[2])
        d.line([3, sy + 1, W - 4, sy + 1], fill=t[1])
    colors = [NAVY[1][1], RED, DARKGREEN, (52, 52, 58), WHITE, BLUE, NAVY[1][1], RED]

    def binder(x, bot, c):
        d.rectangle([x, bot - 10, x + 2, bot - 1], fill=c)
        d.line([x, bot - 10, x, bot - 1], fill=_dark(c))         # spine shadow edge
        d.point((x + 1, bot - 10), fill=_light(c))                # top edge catch
        d.rectangle([x + 1, bot - 8, x + 1, bot - 5],
                    fill=PAPER_SHADE if c == WHITE else WHITE)    # label window
        d.point((x + 1, bot - 3), fill=METAL[2])                  # ring rivet

    for i, x in enumerate(range(4, 28, 3)):              # top shelf: full row
        binder(x, 16, colors[i % len(colors)])
    for i, x in enumerate(range(4, 19, 3)):              # middle: half row ...
        binder(x, 30, colors[(i + 3) % len(colors)])
    d.rectangle([20, 27, 27, 29], fill=RED, outline=None)        # ... plus a toppled binder
    d.line([20, 27, 27, 27], fill=RED_LIGHT)
    d.rectangle([23, 28, 25, 28], fill=WHITE)
    for i, x in enumerate(range(4, 28, 3)):              # bottom shelf: full row
        binder(x, H - 3, colors[(i + 5) % len(colors)])


def draw_coat_rack(d, W, H):
    # freestanding steel pole on a disc base, hooked arms, one coat + a scarf
    d.rectangle([3, H - 3, 12, H - 1], fill=METAL[1][1], outline=OUT)   # base disc
    d.line([4, H - 2, 11, H - 2], fill=METAL[1][2])
    d.rectangle([7, 2, 8, H - 3], fill=METAL[1][2])      # pole
    d.line([7, 2, 7, H - 4], fill=METAL[2])
    d.line([8, 2, 8, H - 4], fill=METAL[1][1])
    d.rectangle([6, 0, 9, 2], fill=METAL[1][3], outline=OUT)   # finial
    for y in (4, 9):                                     # hook arms
        d.line([3, y, 7, y], fill=METAL[1][2])
        d.line([8, y, 12, y], fill=METAL[1][2])
        d.point((3, y - 1), fill=METAL[2])               # upturned tips
        d.point((12, y - 1), fill=METAL[2])
    d.rectangle([3, 5, 4, 14], fill=TEAL, outline=None)  # dangling scarf
    d.line([3, 5, 3, 14], fill=_dark(TEAL))
    d.point((4, 15), fill=_dark(TEAL))
    box(d, 9, 5, 14, 21, FABRIC)                         # hanging coat
    d.line([11, 6, 11, 9], fill=FABRIC[1][0])            # lapel gap
    d.line([13, 7, 13, 19], fill=FABRIC[1][1])           # sleeve seam
    d.point((11, 12), fill=OUT)                          # buttons
    d.point((11, 16), fill=OUT)


# ------------------------------------------------------------------ clutter

def draw_coffee_maker(d, W, H):
    # drip machine: black tower + hood, glass carafe half full on the warmer
    d.rectangle([1, 12, 14, 15], fill=NAVY[1][1], outline=OUT)   # warmer base
    d.line([2, 13, 13, 13], fill=NAVY[1][3])
    d.rectangle([10, 1, 14, 12], fill=NAVY[1][1], outline=OUT)   # reservoir tower
    d.line([11, 2, 11, 11], fill=NAVY[1][3])
    d.rectangle([1, 1, 14, 4], fill=NAVY[1][1], outline=OUT)     # hood
    d.line([2, 2, 13, 2], fill=NAVY[1][3])
    d.point((12, 8), fill=RED)                           # power light
    d.point((12, 10), fill=METAL[2])                     # switch
    d.rectangle([2, 6, 9, 12], fill=CERAMIC[2], outline=OUT)     # glass carafe
    d.rectangle([3, 9, 8, 11], fill=COFFEE)              # coffee level
    d.line([3, 7, 3, 8], fill=WHITE)                     # glass sheen
    d.point((1, 8), fill=OUT); d.point((0, 9), fill=OUT); d.point((1, 10), fill=OUT)  # handle
    d.point((5, 5), fill=COFFEE)                         # drip


def draw_shredder(d, W, H):
    # cross-cut shredder: dark head with feed slot, bin window full of strips
    box(d, 2, 2, 13, 6, NAVY)                            # head
    d.rectangle([5, 0, 10, 3], fill=WHITE, outline=None) # sheet being fed
    d.line([6, 1, 9, 1], fill=PAPER_SHADE)
    d.line([4, 4, 11, 4], fill=OUT)                      # feed slot
    d.point((3, 5), fill=GREEN)                          # ready light
    box(d, 3, 7, 12, 15, NAVY, bevel=False)              # bin
    d.line([4, 8, 4, 14], fill=NAVY[1][3])
    d.rectangle([5, 8, 10, 13], fill=NAVY[1][0])         # viewing window
    for x, top in ((5, 8), (7, 9), (9, 8)):              # shredded strips
        d.line([x, top, x, 13], fill=WHITE)
    d.line([6, 11, 6, 13], fill=PAPER_SHADE)
    d.line([8, 12, 8, 13], fill=PAPER_SHADE)


# ----------------------------------------------------------------- wall art

def draw_cork_board(d, W, H):
    # wood-framed cork board with pinned memo, sticky, photo and note
    box(d, 0, 0, W - 1, H - 1, WOOD, bevel=False)
    d.line([1, 1, W - 2, 1], fill=WOOD[1][3])
    d.line([1, H - 2, W - 2, H - 2], fill=WOOD[1][0])
    d.rectangle([2, 2, W - 3, H - 3], fill=CORK)         # cork face
    for x, y in ((4, 13), (12, 3), (19, 12), (29, 8), (17, 5)):   # cork grain dashes
        d.line([x, y, x + 1, y], fill=CORK_DARK)
    for x, y in ((11, 13), (20, 3), (29, 12)):
        d.point((x, y), fill=CORK_LIGHT)
    d.rectangle([4, 4, 10, 11], fill=WHITE, outline=OUT)         # memo
    d.line([5, 6, 9, 6], fill=NAVY[1][1]); d.line([5, 8, 8, 8], fill=NAVY[1][1])
    d.point((7, 4), fill=RED)
    d.rectangle([13, 6, 18, 11], fill=YELLOW, outline=OUT)       # sticky note
    d.line([14, 8, 17, 8], fill=ORANGE)
    d.point((15, 6), fill=BLUE)
    d.rectangle([21, 3, 28, 9], fill=WHITE, outline=OUT)         # photo
    d.rectangle([22, 4, 27, 8], fill=NAVY[1][2])
    d.rectangle([22, 7, 27, 8], fill=TEAL)
    d.point((24, 3), fill=RED)
    d.rectangle([23, 10, 28, 13], fill=PINK, outline=OUT)        # small note
    d.point((25, 10), fill=BLUE)


def draw_fire_extinguisher(d, W, H):
    # red cylinder on a steel wall bracket, hose down the left, valve on top
    d.rectangle([11, 2, 13, 13], fill=METAL[1][1], outline=OUT)  # bracket plate
    d.line([12, 3, 12, 12], fill=METAL[1][2])
    d.rectangle([4, 4, 10, 15], fill=RED, outline=OUT)   # cylinder
    d.line([5, 5, 5, 14], fill=RED_LIGHT)
    d.line([9, 5, 9, 14], fill=RED_DARK)
    d.rectangle([6, 10, 8, 12], fill=WHITE)              # label
    d.line([3, 4, 3, 11], fill=METAL[1][0])              # hose
    d.point((2, 11), fill=METAL[1][0])                   # nozzle
    d.rectangle([3, 7, 12, 9], fill=METAL[1][2], outline=OUT)    # bracket strap
    d.rectangle([6, 1, 8, 3], fill=METAL[1][1], outline=OUT)     # valve neck
    d.line([4, 1, 8, 0], fill=METAL[1][3])               # squeeze lever
    d.point((5, 2), fill=OUT)                            # pull pin


def draw_projector_screen(d, W, H):
    # ceiling case, pulled-down white screen, weighted bottom bar with tab
    box(d, 0, 0, W - 1, 4, METAL, bevel=False)           # housing
    d.line([1, 1, W - 2, 1], fill=METAL[1][3])
    d.rectangle([0, 0, 2, 4], fill=METAL[1][1], outline=OUT)     # end caps
    d.rectangle([W - 3, 0, W - 1, 4], fill=METAL[1][1], outline=OUT)
    d.point((1, 2), fill=METAL[2]); d.point((W - 2, 2), fill=METAL[2])
    d.rectangle([3, 5, W - 4, 12], fill=WHITE, outline=OUT)      # screen
    d.line([4, 5, 4, 11], fill=(40, 40, 44))             # black side borders
    d.line([W - 5, 5, W - 5, 11], fill=(40, 40, 44))
    d.line([5, 11, W - 6, 11], fill=PAPER_SHADE)         # curl shading at the bar
    d.rectangle([W - 14, 8, W - 8, 10], fill=(210, 206, 196))    # water stain
    d.line([W - 14, 8, W - 8, 8], fill=(196, 180, 150))
    d.rectangle([2, 12, W - 3, 14], fill=METAL[1][2], outline=OUT)   # weighted bar
    d.line([3, 13, W - 4, 13], fill=METAL[1][3])
    d.rectangle([W // 2 - 2, 15, W // 2 + 1, 15], fill=METAL[1][0])  # pull tab


# -------------------------------------------------------------------- items

ITEMS = [
    {
        "id": "com_server_rack", "name": "Server Rack",
        "category": "furniture", "size": [1, 3], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 20, "tool_tier": 1, "skill": 1,
        "scrap_time": 3.5, "xp": 7,
        "yields": [{"item": "scrap_metal", "min": 4, "max": 7},
                   {"item": "plastic", "min": 2, "max": 4}],
        "draw": draw_server_rack,
    },
    {
        "id": "com_reception_desk", "surface": True, "name": "Reception Desk",
        "category": "furniture", "size": [3, 2], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 22, "tool_tier": 0, "skill": 0,
        "scrap_time": 3.5, "xp": 7, "storage_slots": 6,
        "yields": [{"item": "wood", "min": 6, "max": 10},
                   {"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_reception_desk,
    },
    {
        "id": "com_office_bookcase", "name": "Binder Bookcase",
        "category": "furniture", "size": [2, 3], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 18, "tool_tier": 0, "skill": 0,
        "scrap_time": 3.0, "xp": 6, "storage_slots": 6,
        "yields": [{"item": "wood", "min": 5, "max": 8},
                   {"item": "cloth", "min": 1, "max": 2}],
        "draw": draw_office_bookcase,
    },
    {
        "id": "com_coat_rack", "name": "Coat Rack",
        "category": "furniture", "size": [1, 2], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 7, "tool_tier": 0, "skill": 0,
        "scrap_time": 2.0, "xp": 4,
        "yields": [{"item": "scrap_metal", "min": 2, "max": 3},
                   {"item": "cloth", "min": 1, "max": 2}],
        "draw": draw_coat_rack,
    },
    {
        "id": "com_coffee_maker", "name": "Coffee Maker",
        "category": "clutter", "size": [1, 1], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 2, "tool_tier": 0, "skill": 0,
        "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "plastic", "min": 1, "max": 2},
                   {"item": "scrap_metal", "min": 0, "max": 1}],
        "draw": draw_coffee_maker,
    },
    {
        "id": "com_shredder", "name": "Paper Shredder",
        "category": "clutter", "size": [1, 1], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 4, "tool_tier": 0, "skill": 0,
        "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "plastic", "min": 2, "max": 3}],
        "draw": draw_shredder,
    },
    {
        "id": "com_cork_board", "name": "Cork Board",
        "category": "wall_art", "size": [2, 1], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 3, "tool_tier": 0, "skill": 0,
        "scrap_time": 1.0, "xp": 2, "wall_mounted": True,
        "yields": [{"item": "wood", "min": 1, "max": 2}],
        "draw": draw_cork_board,
    },
    {
        "id": "com_fire_extinguisher", "name": "Fire Extinguisher",
        "category": "wall_art", "size": [1, 1], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 4, "tool_tier": 0, "skill": 0,
        "scrap_time": 1.0, "xp": 2, "wall_mounted": True,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_fire_extinguisher,
    },
    {
        "id": "com_projector_screen", "name": "Projector Screen",
        "category": "wall_art", "size": [3, 1], "zones": ["commercial", "business"],
        "room_type": "office", "weight": 6, "tool_tier": 0, "skill": 0,
        "scrap_time": 1.5, "xp": 3, "wall_mounted": True,
        "yields": [{"item": "cloth", "min": 2, "max": 3},
                   {"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_projector_screen,
    },
]
