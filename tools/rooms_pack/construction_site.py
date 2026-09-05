"""Construction district — building-site item set (docs/DistrictsOverhaul.md).

Dresses the unfinished towers: scaffolds, stacked sheet goods, a mixer,
rebar, sawhorses, barrows, barriers and small site clutter. Everything
scraps to wood / scrap metal / plastic / cloth only - the construction
palette is wood-and-metal and GL-28 (no surface iron) must hold. Style per
docs/technical/TileArt.md via the common.py helpers; deterministic.
"""
from common import *  # noqa: F401,F403 — OUT, WHITE, accents, RAMPS, box, panel, legs

METAL = RAMPS["metal"]
WOOD = RAMPS["wood"]
PLASTIC = RAMPS["plastic"]
FABRIC = RAMPS["fabric"]

BLACK = (34, 32, 28)
# Painted-steel safety orange (same 5-step structure as RAMPS).
ORANGE_STEEL = ((60, 26, 10),
                [(150, 70, 20), (190, 96, 30), (220, 130, 50), (236, 160, 84)],
                (246, 190, 120))
# Pale plywood face.
PLY = ((70, 48, 24),
       [(168, 128, 78), (196, 154, 96), (216, 176, 116), (228, 194, 138)],
       (238, 210, 160))


def _stripes(d, x0, y0, x1, y1, a, b, step=3):
    """Diagonal-ish alternating bands (hazard tape / barrier faces)."""
    for i, x in enumerate(range(x0, x1 + 1, step)):
        d.rectangle([x, y0, min(x + step - 1, x1), y1], fill=a if i % 2 == 0 else b)


# ---------------------------------------------------------------- furniture

def draw_scaffold(d, W, H):  # 48x48: two-tier tube scaffold with plank decks
    o, t, h = METAL
    # uprights
    for x in (1, W // 2 - 1, W - 3):
        d.rectangle([x, 0, x + 1, H - 1], fill=t[2], outline=o)
    # feet plates
    for x in (0, W // 2 - 2, W - 4):
        d.rectangle([x, H - 3, x + 3, H - 1], fill=t[1], outline=o)
    # ledgers + decks at two tiers
    for deck_y in (H // 2 - 2, 4):
        d.rectangle([0, deck_y, W - 1, deck_y + 1], fill=t[3], outline=o)
        box(d, 2, deck_y + 2, W - 3, deck_y + 4, WOOD)
        for px in range(6, W - 4, 8):  # plank seams
            d.line([px, deck_y + 2, px, deck_y + 4], fill=WOOD[0])
    # diagonal brace (lower bay)
    d.line([3, H - 4, W // 2 - 2, H // 2 + 3], fill=t[1])
    d.line([W // 2 + 1, H - 4, W - 4, H // 2 + 3], fill=t[1])


def draw_plywood_stack(d, W, H):  # 32x16: banded stack of sheets on bearers
    o, t, h = PLY
    # bearers
    box(d, 2, H - 3, 6, H - 1, WOOD)
    box(d, W - 7, H - 3, W - 3, H - 1, WOOD)
    # sheets
    for i, y in enumerate(range(H - 5, 1, -2)):
        d.rectangle([1, y, W - 2, y + 1], fill=t[(i % 3) + 1], outline=o)
    d.line([2, 2, W - 3, 2], fill=h)
    # strapping
    for x in (8, W - 9):
        d.rectangle([x, 1, x, H - 4], fill=BLACK)


def draw_cement_mixer(d, W, H):  # 32x32: drum on a wheeled frame
    o, t, h = METAL
    # frame + wheels
    d.rectangle([4, H - 8, W - 5, H - 6], fill=t[1], outline=o)
    for cx in (7, W - 8):
        d.ellipse([cx - 4, H - 8, cx + 3, H - 1], fill=t[0], outline=o)
        d.ellipse([cx - 1, H - 5, cx, H - 4], fill=h)
    d.rectangle([W // 2 - 1, H - 14, W // 2, H - 8], fill=t[2], outline=o)
    # drum (tilted bucket) - safety orange
    oo, ot, oh = ORANGE_STEEL
    d.ellipse([6, 3, W - 7, H - 10], fill=ot[2], outline=oo)
    d.ellipse([9, 5, W - 12, H - 16], fill=ot[1], outline=oo)  # mouth
    d.ellipse([10, 6, W - 15, H - 20], fill=BLACK)
    d.line([8, H - 12, W - 9, H - 12], fill=oh)
    # hand crank
    d.rectangle([W - 6, 10, W - 4, 12], fill=t[3], outline=o)


def draw_rebar_bundle(d, W, H):  # 48x16: tied bundle of rusty bars
    o, t, h = METAL
    rust = ((40, 22, 12), [(112, 58, 30), (140, 76, 40), (164, 96, 54), (186, 118, 72)], (206, 140, 92))
    ro, rt, rh = rust
    for i, y in enumerate(range(H - 3, 3, -2)):
        shade = rt[(i % 3) + 1]
        d.rectangle([1 + (i % 2), y, W - 2 - (i % 2), y], fill=shade)
        d.point((1 + (i % 2), y), fill=ro)
        d.point((W - 2 - (i % 2), y), fill=ro)
    d.line([3, 5, W - 4, 5], fill=rh)
    # ties
    for x in (10, W // 2, W - 11):
        d.rectangle([x, 3, x + 1, H - 2], fill=t[3], outline=o)
    # bearers
    box(d, 4, H - 2, 8, H - 1, WOOD, bevel=False)
    box(d, W - 9, H - 2, W - 5, H - 1, WOOD, bevel=False)


def draw_sawhorse(d, W, H):  # 32x16: A-frame trestle with a plank across
    o, t, h = WOOD
    d.rectangle([0, 2, W - 1, 4], fill=t[2], outline=o)  # top beam
    d.line([1, 3, W - 2, 3], fill=h)
    for x0 in (3, W - 8):  # splayed legs
        d.line([x0 + 2, 5, x0, H - 1], fill=t[1])
        d.line([x0 + 3, 5, x0 + 5, H - 1], fill=t[1])
        d.line([x0 + 1, 5, x0 - 1, H - 1], fill=o)
        d.line([x0 + 4, 5, x0 + 6, H - 1], fill=o)
    d.rectangle([5, H - 6, W - 6, H - 5], fill=t[0])  # stretcher


def draw_wheelbarrow(d, W, H):  # 32x16: tray, frame and one wheel
    o, t, h = METAL
    oo, ot, oh = ORANGE_STEEL
    # tray
    d.polygon([(6, 3), (W - 3, 3), (W - 6, 10), (9, 10)], fill=ot[2], outline=oo)
    d.line([8, 4, W - 5, 4], fill=oh)
    # handles + frame
    d.line([0, 5, 7, 6], fill=t[2])
    d.line([0, 6, 7, 7], fill=o)
    d.rectangle([W - 10, 10, W - 7, 12], fill=t[1], outline=o)
    d.rectangle([10, 10, 12, H - 1], fill=t[1], outline=o)  # rear leg
    # wheel
    d.ellipse([W - 12, 8, W - 5, H - 1], fill=t[0], outline=o)
    d.ellipse([W - 9, 11, W - 8, 12], fill=h)


def draw_tarp_pile(d, W, H):  # 32x16: heaped blue tarp over sheet goods
    o, t, h = RAMPS["navy"]
    d.ellipse([0, 4, W - 1, H + 6], fill=t[2], outline=o)
    d.chord([3, 2, W - 8, H + 2], 180, 360, fill=t[3], outline=o)
    d.line([6, 6, 12, 5], fill=h)
    d.line([16, 7, 22, 6], fill=h)
    # weighted corners: a block and a rope
    box(d, W - 7, H - 4, W - 2, H - 1, WOOD, bevel=False)
    d.line([2, H - 2, 6, H - 5], fill=BROWN_PAPER)


def draw_hazard_barrier(d, W, H):  # 32x16: striped A-barrier
    oo, ot, oh = ORANGE_STEEL
    d.rectangle([0, 2, W - 1, 8], fill=WHITE, outline=oo)
    _stripes(d, 1, 3, W - 2, 7, ot[2], WHITE, step=4)
    d.line([1, 2, W - 2, 2], fill=oh)
    o, t, h = METAL
    for x0 in (3, W - 6):
        d.rectangle([x0, 9, x0 + 1, H - 1], fill=t[2], outline=o)
    d.rectangle([2, H - 1, W - 3, H - 1], fill=t[1])


# ---------------------------------------------------------------- clutter

def draw_paint_bucket(d, W, H):  # 16x16: lidded plastic pail with a drip
    o, t, h = PLASTIC
    d.rectangle([3, 5, W - 4, H - 1], fill=t[2], outline=o)
    d.rectangle([2, 4, W - 3, 6], fill=t[3], outline=o)  # lid
    d.line([4, 7, 4, H - 3], fill=h)
    d.arc([3, 1, W - 4, 8], 180, 360, fill=METAL[1][2])  # handle
    d.rectangle([W - 6, 9, W - 5, 12], fill=WHITE)  # drip


def draw_toolbox(d, W, H):  # 16x16: red steel toolbox
    red = ((50, 18, 16), [(118, 40, 34), (148, 54, 44), (176, 70, 56), (198, 92, 74)], (216, 122, 100))
    o, t, h = red
    d.rectangle([1, 8, W - 2, H - 1], fill=t[2], outline=o)
    d.rectangle([1, 6, W - 2, 8], fill=t[3], outline=o)  # lid
    d.line([2, 7, W - 3, 7], fill=h)
    d.rectangle([6, 3, W - 7, 6], fill=METAL[1][2], outline=METAL[0])  # handle
    d.rectangle([W // 2 - 1, 9, W // 2, 10], fill=METAL[1][3])  # latch


ITEMS = [
    {
        "id": "con_scaffold", "name": "Tube Scaffold", "category": "furniture",
        "size": [3, 3], "zones": ["construction"], "room_type": "site",
        "weight": 24, "tool_tier": 0, "skill": 0, "scrap_time": 3.5, "xp": 6,
        "yields": [
            {"item": "scrap_metal", "min": 3, "max": 5},
            {"item": "wood", "min": 2, "max": 4},
        ],
        "draw": draw_scaffold,
    },
    {
        "id": "con_plywood_stack", "name": "Plywood Stack", "category": "furniture",
        "size": [2, 1], "zones": ["construction"], "room_type": "site",
        "weight": 18, "tool_tier": 0, "skill": 0, "scrap_time": 2.5, "xp": 4,
        "yields": [{"item": "wood", "min": 4, "max": 6}],
        "draw": draw_plywood_stack,
    },
    {
        "id": "con_cement_mixer", "name": "Cement Mixer", "category": "furniture",
        "size": [2, 2], "zones": ["construction"], "room_type": "site",
        "weight": 26, "tool_tier": 1, "skill": 1, "scrap_time": 3.5, "xp": 6,
        "yields": [
            {"item": "scrap_metal", "min": 3, "max": 5},
            {"item": "plastic", "min": 1, "max": 2},
        ],
        "draw": draw_cement_mixer,
    },
    {
        "id": "con_rebar_bundle", "name": "Rebar Bundle", "category": "furniture",
        "size": [3, 1], "zones": ["construction"], "room_type": "site",
        "weight": 22, "tool_tier": 1, "skill": 1, "scrap_time": 3.0, "xp": 5,
        "yields": [{"item": "scrap_metal", "min": 4, "max": 6}],
        "draw": draw_rebar_bundle,
    },
    {
        "id": "con_sawhorse", "name": "Sawhorse", "category": "furniture",
        "size": [2, 1], "zones": ["construction"], "room_type": "site",
        "weight": 8, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "wood", "min": 2, "max": 3}],
        "draw": draw_sawhorse,
    },
    {
        "id": "con_wheelbarrow", "name": "Wheelbarrow", "category": "furniture",
        "size": [2, 1], "zones": ["construction"], "room_type": "site",
        "weight": 12, "tool_tier": 0, "skill": 0, "scrap_time": 2.0, "xp": 4,
        "yields": [
            {"item": "scrap_metal", "min": 2, "max": 3},
            {"item": "plastic", "min": 1, "max": 1},
        ],
        "draw": draw_wheelbarrow,
    },
    {
        "id": "con_tarp_pile", "name": "Tarped Pile", "category": "furniture",
        "size": [2, 1], "zones": ["construction"], "room_type": "site",
        "weight": 14, "tool_tier": 0, "skill": 0, "scrap_time": 2.0, "xp": 3,
        "yields": [
            {"item": "cloth", "min": 2, "max": 3},
            {"item": "wood", "min": 1, "max": 2},
        ],
        "draw": draw_tarp_pile,
    },
    {
        "id": "con_hazard_barrier", "name": "Hazard Barrier", "category": "furniture",
        "size": [2, 1], "zones": ["construction"], "room_type": "site",
        "weight": 9, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [
            {"item": "plastic", "min": 2, "max": 3},
            {"item": "scrap_metal", "min": 1, "max": 1},
        ],
        "draw": draw_hazard_barrier,
    },
    {
        "id": "con_paint_bucket", "name": "Paint Bucket", "category": "clutter",
        "size": [1, 1], "zones": ["construction"], "room_type": "site",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 0.8, "xp": 1,
        "yields": [{"item": "plastic", "min": 1, "max": 2}],
        "draw": draw_paint_bucket,
    },
    {
        "id": "con_toolbox", "name": "Toolbox", "category": "clutter",
        "size": [1, 1], "zones": ["construction"], "room_type": "site",
        "weight": 5, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_toolbox,
    },
]
