"""Interior details room-pack — wall damage decals, HVAC/pipework, statuary.

Non-blocking dressing that makes tower interiors read as lived-in and decayed:
broken-wall decals and water stains (pure visuals, no item form), scrappable
vents, ducts and pipe runs for commercial/industrial floors, and stone
statuary for lobbies. Style per docs/technical/TileArt.md — material ramps,
1px outlines, light top-left / dark bottom-right shading, no per-pixel noise.
"""
from common import *  # noqa: F401,F403


def _dark(c, k=45):
    return (max(0, c[0] - k), max(0, c[1] - k), max(0, c[2] - k))


# ------------------------------------------------------------- wall decals


def draw_broken_wall_a(d, W, H):
    st = RAMPS["stone"]
    o, t, hl = st
    cav = (28, 24, 22)
    brick = (98, 60, 46)
    brick_d = (68, 42, 32)
    # irregular plaster patch (never a filled square)
    d.polygon([(8, 4), (21, 2), (28, 9), (27, 21), (18, 27), (7, 24), (4, 13)],
              fill=t[2], outline=o)
    d.line([(9, 4), (20, 3)], fill=t[3])                     # light top-left rim
    d.line([(8, 24), (17, 26)], fill=t[1])                   # dark lower rim
    # dark cavity revealing brick courses behind
    d.polygon([(11, 8), (21, 7), (24, 13), (21, 20), (12, 20), (9, 13)],
              fill=cav, outline=o)
    for by, off in ((9, 0), (13, 3), (16, 0)):
        for bx in range(12 + off, 20, 6):
            d.rectangle([bx, by, bx + 4, by + 2], fill=brick, outline=brick_d)
    # spiderweb cracks radiating past the patch edge
    for a, b in (((4, 13), (0, 11)), ((28, 9), (31, 6)), ((27, 21), (31, 25)),
                 ((8, 4), (5, 0)), ((18, 27), (16, 31)), ((7, 24), (3, 27))):
        d.line([a, b], fill=o)
    d.line([(31, 25), (29, 27)], fill=o)                     # crack fork
    d.line([(5, 0), (7, 1)], fill=o)
    # fallen chips at the bottom
    for cx, cy in ((6, 29), (12, 30), (21, 30), (26, 28)):
        d.rectangle([cx, cy, cx + 2, cy + 1], fill=t[1], outline=o)


def draw_broken_wall_b(d, W, H):
    st = RAMPS["stone"]
    o, t, hl = st
    cav = (24, 21, 19)
    stud = (54, 46, 38)
    rebar = (92, 78, 60)
    # wide crumbled plaster rim
    d.polygon([(6, 6), (18, 2), (33, 4), (43, 9), (44, 20), (34, 26), (16, 28),
               (5, 22), (3, 13)], fill=t[2], outline=o)
    d.line([(8, 5), (31, 4)], fill=t[3])                     # light top rim
    d.line([(8, 23), (32, 26)], fill=t[1])                   # dark lower rim
    # dark blast hole
    d.polygon([(10, 9), (28, 6), (39, 11), (40, 19), (30, 23), (13, 24), (8, 15)],
              fill=cav, outline=o)
    # exposed studs (vertical) and rebar (horizontal) across the hole
    for sx in (16, 25, 33):
        d.rectangle([sx, 8, sx + 1, 22], fill=stud)
    d.line([(9, 13), (23, 12)], fill=rebar)                  # snapped rebar
    d.line([(27, 13), (39, 12)], fill=rebar)
    d.line([(9, 18), (39, 18)], fill=rebar)
    # cracks spreading out
    for a, b in (((3, 13), (0, 11)), ((44, 9), (47, 6)), ((44, 20), (47, 24)),
                 ((18, 2), (15, 0)), ((16, 28), (13, 31)), ((34, 26), (37, 31))):
        d.line([a, b], fill=o)
    d.line([(47, 24), (45, 26)], fill=o)
    # chips
    for cx, cy in ((10, 30), (24, 30), (39, 29)):
        d.rectangle([cx, cy, cx + 2, cy + 1], fill=t[1], outline=o)


def draw_water_stain(d, W, H):
    # sparse semi-transparent streaks — reads as a stain, not a filled panel
    a_hi = (30, 36, 34, 150)
    a_md = (38, 46, 42, 100)
    a_lo = (48, 56, 50, 60)
    # source blot at the top (leak line)
    d.polygon([(7, 0), (25, 0), (27, 4), (20, 7), (11, 7), (5, 4)], fill=a_md)
    d.line([(8, 1), (24, 1)], fill=a_hi)
    d.line([(7, 5), (24, 5)], fill=a_lo)
    # streaks running down at varied start heights and lengths
    for x, y0, y1, aa in ((7, 6, 26, a_md), (10, 5, 38, a_hi), (13, 8, 30, a_md),
                          (16, 6, 44, a_hi), (19, 9, 24, a_md), (22, 6, 36, a_hi),
                          (25, 7, 20, a_lo)):
        d.line([(x, y0), (x, y1)], fill=aa)
        d.point((x, y1 + 1), fill=a_lo)
    # drip beads
    d.point((16, 46), fill=a_hi)
    d.point((10, 40), fill=a_md)
    d.point((22, 38), fill=a_lo)


# ---------------------------------------------------------- HVAC / pipework


def draw_wall_vent(d, W, H):
    mt = RAMPS["metal"]
    o, t, hl = mt
    box(d, 0, 0, W - 1, H - 1, mt)                           # frame
    d.rectangle([3, 3, W - 4, H - 4], fill=t[1], outline=t[0])  # recessed grille
    for sy in range(4, H - 5, 3):                            # louver slats
        d.line([(4, sy), (W - 5, sy)], fill=t[3])
        d.line([(4, sy + 1), (W - 5, sy + 1)], fill=t[0])
    for sx, sy in ((1, 1), (W - 2, 1), (1, H - 2), (W - 2, H - 2)):  # screws
        d.point((sx, sy), fill=hl)


def draw_duct_run(d, W, H):
    mt = RAMPS["metal"]
    o, t, hl = mt
    box(d, 0, 0, W - 1, 9, mt)                               # duct hugging the ceiling
    d.line([(1, 1), (W - 2, 1)], fill=hl)
    d.line([(1, 8), (W - 2, 8)], fill=t[0])
    for jx in (14, 30):                                      # raised joint collars
        d.rectangle([jx, 0, jx + 2, 9], fill=t[3], outline=o)
    d.rectangle([36, 9, 43, H - 1], fill=t[2], outline=o)    # downward register
    d.line([(37, 10), (42, 10)], fill=t[3])
    for sx in range(38, 43, 2):                              # register slats
        d.line([(sx, 12), (sx, H - 3)], fill=t[0])
    d.line([(37, H - 2), (42, H - 2)], fill=t[0])


def draw_wall_pipes(d, W, H):
    mt = RAMPS["metal"]
    o, t, hl = mt
    for py in (2, 9):                                        # two parallel runs
        d.rectangle([0, py, W - 1, py + 3], fill=t[2], outline=o)
        d.line([(1, py + 1), (W - 2, py + 1)], fill=hl)
        d.line([(1, py + 2), (W - 2, py + 2)], fill=t[1])
    for fx in (6, 22, 40):                                   # flanges
        d.rectangle([fx, 1, fx + 1, 6], fill=t[3], outline=o)
        d.rectangle([fx, 8, fx + 1, 13], fill=t[3], outline=o)
    # red valve wheel on the top pipe
    d.rectangle([30, 0, 37, 1], fill=RED, outline=_dark(RED, 60))
    d.point((31, 0), fill=(226, 120, 106))
    d.rectangle([33, 2, 34, 2], fill=_dark(RED, 60))         # stem


def draw_pipe_riser(d, W, H):
    mt = RAMPS["metal"]
    o, t, hl = mt
    d.rectangle([5, 0, 10, H - 1], fill=t[2], outline=o)     # vertical pipe
    d.line([(6, 1), (6, H - 2)], fill=hl)                    # light left edge
    d.line([(9, 1), (9, H - 2)], fill=t[0])                  # dark right edge
    for cy in (12, 34, 52):                                  # joint collars
        d.rectangle([4, cy, 11, cy + 2], fill=t[3], outline=o)
        d.line([(5, cy + 1), (10, cy + 1)], fill=t[2])
    d.rectangle([2, 23, 13, 26], fill=t[1], outline=o)       # wall bracket
    d.line([(3, 24), (12, 24)], fill=t[2])


# ---------------------------------------------------------------- statuary


def draw_statue_bust(d, W, H):
    ce, st = RAMPS["ceramic"], RAMPS["stone"]
    o, t, hl = ce
    d.rectangle([2, 12, 13, H - 1], fill=st[1][2], outline=st[0])  # plinth
    d.line([(3, 13), (12, 13)], fill=st[2])
    d.polygon([(3, 11), (12, 11), (10, 8), (5, 8)], fill=t[2], outline=o)  # shoulders
    d.rectangle([6, 2, 9, 7], fill=t[3], outline=o)          # head
    d.point((7, 3), fill=hl)
    d.line([(8, 4), (8, 6)], fill=t[1])                      # shaded right cheek


def draw_statue_stone(d, W, H):
    st = RAMPS["stone"]
    o, t, hl = st
    # two-step plinth
    d.rectangle([2, H - 4, W - 3, H - 1], fill=t[2], outline=o)
    d.line([(3, H - 3), (W - 4, H - 3)], fill=t[3])
    d.rectangle([6, H - 8, W - 7, H - 4], fill=t[2], outline=o)
    d.line([(7, H - 7), (W - 8, H - 7)], fill=t[3])
    # robe body with broader shoulders
    d.polygon([(11, 13), (20, 13), (22, 24), (23, H - 9), (8, H - 9), (9, 24)],
              fill=t[2], outline=o)
    d.line([(12, 14), (19, 14)], fill=t[3])                  # lit shoulder line
    d.rectangle([14, 11, 17, 12], fill=t[2])                 # neck
    d.line([(11, 16), (10, H - 10)], fill=t[3])              # light left fold
    d.line([(14, 24), (13, H - 10)], fill=t[1])              # fold shadow
    d.line([(18, 24), (19, H - 10)], fill=t[1])
    d.line([(21, 20), (21, H - 10)], fill=t[0])              # dark right edge
    # folded arm band
    d.rectangle([10, 20, 21, 22], fill=t[3], outline=o)
    d.line([(11, 21), (20, 21)], fill=t[2])
    # head
    d.rectangle([13, 4, 18, 10], fill=t[3], outline=o)
    d.point((14, 5), fill=hl)
    d.line([(17, 6), (17, 9)], fill=t[1])


def draw_statue_lion(d, W, H):
    st = RAMPS["stone"]
    o, t, hl = st
    # low plinth
    d.rectangle([1, H - 5, W - 2, H - 1], fill=t[2], outline=o)
    d.line([(2, H - 4), (W - 3, H - 4)], fill=t[3])
    # seated body in profile, facing right
    d.polygon([(6, H - 6), (6, 16), (8, 11), (14, 9), (22, 10), (28, 9),
               (34, 12), (36, H - 6)], fill=t[2], outline=o)
    d.line([(8, 13), (12, 10)], fill=t[3])                   # haunch highlight
    d.line([(9, 18), (11, 14)], fill=t[3])
    d.line([(15, 22), (14, H - 7)], fill=t[1])               # rear leg shadow
    # curled tail at the base
    d.rectangle([1, H - 9, 3, H - 7], fill=t[2], outline=o)
    d.line([(4, H - 7), (6, H - 8)], fill=t[1])
    # mane (darker ring)
    d.polygon([(26, 4), (34, 4), (37, 9), (36, 15), (28, 15), (25, 9)],
              fill=t[1], outline=o)
    d.line([(27, 5), (33, 5)], fill=t[2])
    # head / muzzle over the mane
    d.rectangle([32, 6, 39, 11], fill=t[3], outline=o)
    d.rectangle([33, 4, 34, 5], fill=t[1], outline=o)        # ear
    d.point((33, 7), fill=hl)
    d.point((37, 8), fill=o)                                 # eye
    d.line([(39, 9), (39, 10)], fill=t[0])                   # muzzle shade
    # front leg with paw
    d.rectangle([31, 17, 34, H - 6], fill=t[3], outline=o)
    d.line([(32, 18), (32, H - 7)], fill=hl)
    d.rectangle([31, H - 8, 36, H - 6], fill=t[3], outline=o)
    d.line([(35, H - 7), (35, H - 7)], fill=t[1])


# -------------------------------------------------------------------- items

_ALL_ZONES = ["residential", "business", "commercial", "industrial", "civil"]

ITEMS = [
    {
        "id": "decal_broken_wall_a", "name": "Cracked Wall", "category": "wall_detail",
        "kind": "decal", "size": [2, 2], "zones": _ALL_ZONES, "room_type": "detail",
        "wall_mounted": True, "no_item": True,
        "weight": 0, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 0,
        "yields": [],
        "draw": draw_broken_wall_a,
    },
    {
        "id": "decal_broken_wall_b", "name": "Cracked Wall", "category": "wall_detail",
        "kind": "decal", "size": [3, 2], "zones": _ALL_ZONES, "room_type": "detail",
        "wall_mounted": True, "no_item": True,
        "weight": 0, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 0,
        "yields": [],
        "draw": draw_broken_wall_b,
    },
    {
        "id": "decal_water_stain", "name": "Water Stain", "category": "wall_detail",
        "kind": "decal", "size": [2, 3], "zones": _ALL_ZONES, "room_type": "detail",
        "wall_mounted": True, "no_item": True,
        "weight": 0, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 0,
        "yields": [],
        "draw": draw_water_stain,
    },
    {
        "id": "int_wall_vent", "name": "Wall Vent", "category": "wall_detail",
        "size": [2, 1], "zones": ["commercial", "industrial", "civil"],
        "room_type": "detail", "wall_mounted": True,
        "weight": 4, "tool_tier": 0, "skill": 0, "scrap_time": 1.2, "xp": 2,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 3}],
        "draw": draw_wall_vent,
    },
    {
        "id": "int_duct_run", "name": "Ceiling Duct", "category": "wall_detail",
        "size": [3, 1], "zones": ["commercial", "industrial"],
        "room_type": "detail", "wall_mounted": True,
        "weight": 7, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "scrap_metal", "min": 2, "max": 4}],
        "draw": draw_duct_run,
    },
    {
        "id": "int_wall_pipes", "name": "Wall Pipes", "category": "wall_detail",
        "size": [3, 1], "zones": ["commercial", "industrial"],
        "room_type": "detail", "wall_mounted": True,
        "weight": 6, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "scrap_metal", "min": 2, "max": 4}],
        "draw": draw_wall_pipes,
    },
    {
        "id": "int_pipe_riser", "name": "Pipe Riser", "category": "wall_detail",
        "size": [1, 4], "zones": ["commercial", "industrial"],
        "room_type": "detail", "wall_mounted": True,
        "weight": 6, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "scrap_metal", "min": 2, "max": 4}],
        "draw": draw_pipe_riser,
    },
    {
        "id": "statue_bust", "name": "Marble Bust", "category": "clutter",
        "size": [1, 1], "zones": ["residential", "commercial"], "room_type": "detail",
        "weight": 8, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "stone", "min": 1, "max": 2}],
        "draw": draw_statue_bust,
    },
    {
        "id": "statue_stone", "name": "Stone Statue", "category": "statement",
        "size": [2, 3], "zones": ["residential", "commercial", "civil"],
        "room_type": "detail",
        "weight": 40, "tool_tier": 1, "skill": 1, "scrap_time": 3.5, "xp": 8,
        "yields": [{"item": "stone", "min": 4, "max": 8}],
        "draw": draw_statue_stone,
    },
    {
        "id": "statue_lion", "name": "Lion Statue", "category": "statement",
        "size": [3, 2], "zones": ["commercial", "civil"], "room_type": "detail",
        "weight": 40, "tool_tier": 1, "skill": 1, "scrap_time": 3.5, "xp": 8,
        "yields": [{"item": "stone", "min": 4, "max": 8}],
        "draw": draw_statue_lion,
    },
]
