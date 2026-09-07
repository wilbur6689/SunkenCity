"""Residential district flora (docs/Flora/flora.md section 6.1).

Domestic planting gone a bit wild: amber-warm greens, fruit and blossom
accents. Seven species x three stages (seedling / midling / full). Every
drawer returns the REST frame; build_flora.py turns it into a sway strip.

    SPECIES[id] = {
        "name", "slot" (tree|shrub|grass), "stages": [(w, h), (w, h), (w, h)]
        "draw": fn(stage, W, H, rng) -> Canvas,
        "pin": fn(stage, H) -> pinned bottom rows,
        "seed": {"kind", "tint"} for trees (a per-species seed item),
        "desc": hover text for the seedling item,
        + per-stage harvest tables built by build_flora.py from "slot"
    }
"""
import random

from common import (BARK, LEAF, B2, B3, B4, B5, Canvas, blob, branch, canopy, outline_pass,
                    seedling, shadow_band, shift, shift_ramp, trunk, tuft)

# Residential leaf ramp: a touch warmer than the base (amber district tint).
RES_LEAF = shift_ramp(LEAF, hue_deg=-6, sat=1.0, val=1.0)
MAPLE_LEAF = shift_ramp(LEAF, hue_deg=-22, sat=1.05, val=1.0)  # warm, toward orange
MAPLE_LEAF[5] = (232, 170, 90)  # orange-amber glint
PLANE_BARK = [BARK[0], (108, 92, 72), (156, 140, 112), (200, 188, 160)]  # pale mottled
APPLE_RED = ((190, 52, 44), (128, 30, 26))
ROSE_PINK = ((226, 110, 150), (160, 60, 100))
DAISY = ((236, 236, 224), (224, 192, 70))  # petals, centre
CLOVER_WHITE = ((232, 232, 220), (180, 180, 168))


# --- Large: London plane ---------------------------------------------------------

def plane(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = RES_LEAF, PLANE_BARK
    if stage == 0:
        seedling(c, W, H, rng, leaf, bark, leaves=3, lean=-1)
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        return c
    cx = W // 2 + 1
    if stage == 1:  # 48 x 96: a young plane, two crowns, a visible fork
        tb, tt = H - 2, int(H * 0.50)
        branch(c, cx, tt + 6, cx - 10, tt - 10, 3, 1, bark)
        branch(c, cx, tt + 4, cx + 9, tt - 8, 3, 1, bark)
        trunk(c, cx, tb, tt, 4, 3, bark, kink=1, mottle=2, rng=rng)
        masses = [(cx + 8, int(H * 0.34), 14, 13), (cx - 9, int(H * 0.38), 13, 12), (cx - 1, int(H * 0.17), 13, 11)]
        canopy(c, masses, leaf, rng)
        tuft(c, cx, H - 1, 5, leaf, rng)
    else:  # 80 x 192: broad ragged crown of four sub-crowns on a tall pale trunk
        tb, tt = H - 2, int(H * 0.55)
        branch(c, cx, tt + 12, cx - 22, tt - 22, 5, 2, bark)
        branch(c, cx + 1, tt + 8, cx + 20, tt - 18, 5, 2, bark)
        branch(c, cx - 1, tt + 4, cx - 4, tt - 40, 4, 2, bark)
        trunk(c, cx, tb, tt, 8, 6, bark, kink=2, mottle=6, rng=rng)
        masses = [
            (cx + 15, int(H * 0.36), 22, 18),   # right lobe (back)
            (cx - 17, int(H * 0.42), 20, 17),   # left lobe, lower
            (cx + 1, int(H * 0.15), 20, 15),    # top lobe
            (cx - 4, int(H * 0.30), 25, 18),    # centre (front)
        ]
        canopy(c, masses, leaf, rng, step=3)
        tuft(c, cx, H - 1, 8, leaf, rng, blades=4)
    outline_pass(c, leaf, bark)
    return c


# --- Medium: apple ---------------------------------------------------------------

def apple(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = RES_LEAF, BARK
    if stage == 0:
        seedling(c, W, H, rng, leaf, bark, leaves=2, lean=1)
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        return c
    cx = W // 2
    if stage == 1:  # 48 x 72: round crown, low fork, a couple of fruits
        tb, tt = H - 2, int(H * 0.55)
        branch(c, cx, tt + 4, cx - 8, tt - 8, 3, 1, bark)
        branch(c, cx, tt + 2, cx + 7, tt - 6, 3, 1, bark)
        trunk(c, cx, tb, tt, 4, 3, bark, kink=-1)
        masses = [(cx + 5, int(H * 0.36), 12, 11), (cx - 6, int(H * 0.40), 12, 12), (cx, int(H * 0.24), 11, 9)]
        canopy(c, masses, leaf, rng)
        fruit(c, masses, rng, 3)
        tuft(c, cx, H - 1, 5, leaf, rng)
    else:  # 64 x 128: short thick trunk, big round crown, red fruit
        tb, tt = H - 2, int(H * 0.62)
        branch(c, cx, tt + 6, cx - 14, tt - 14, 4, 2, bark)
        branch(c, cx + 1, tt + 4, cx + 12, tt - 12, 4, 2, bark)
        branch(c, cx, tt, cx + 2, tt - 24, 3, 1, bark)
        trunk(c, cx, tb, tt, 7, 5, bark, kink=-1)
        masses = [
            (cx + 12, int(H * 0.40), 16, 14),
            (cx - 13, int(H * 0.43), 16, 14),
            (cx + 1, int(H * 0.22), 17, 12),
            (cx - 1, int(H * 0.36), 19, 15),
        ]
        canopy(c, masses, leaf, rng, step=3)
        fruit(c, masses, rng, 7)
        tuft(c, cx, H - 1, 7, leaf, rng, blades=4)
    outline_pass(c, leaf, bark)
    return c


def fruit(c: Canvas, masses, rng, n):
    """2x2 red apples hanging in the lower half of the crown, never in the glint zone."""
    red, red_dark = APPLE_RED
    placed = 0
    tries = 0
    while placed < n and tries < 60:
        tries += 1
        (mx, my, rx, ry) = masses[rng.randrange(len(masses))]
        x = int(mx + rng.uniform(-rx * 0.7, rx * 0.7))
        y = int(my + rng.uniform(0.0, ry * 0.75))
        if not c.opaque(x, y) or not c.opaque(x + 1, y + 1):
            continue
        if any(c.get(x + dx, y + dy)[:3] == red for dx in range(-3, 5) for dy in range(-3, 5)):
            continue
        c.put(x, y, red)
        c.put(x + 1, y, red)
        c.put(x, y + 1, red)
        c.put(x + 1, y + 1, red_dark)
        placed += 1


# --- Small: ornamental maple ----------------------------------------------------

def maple(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = MAPLE_LEAF, BARK
    if stage == 0:  # 16 x 24
        seedling(c, W, H, rng, leaf, bark, leaves=2, lean=-1, accent=(MAPLE_LEAF[5],))
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        return c
    cx = W // 2 + 1
    if stage == 1:  # 32 x 48: a bent whip with a small flat-bottomed umbrella
        tb, tt = H - 2, int(H * 0.52)
        trunk(c, cx, tb, tt, 2, 2, bark, kink=-3)
        branch(c, cx - 3, tt + 2, cx - 9, tt - 3, 2, 1, bark)
        branch(c, cx - 3, tt + 1, cx + 5, tt - 3, 2, 1, bark)
        masses = [(cx - 2, int(H * 0.36), 12, 7), (cx - 4, int(H * 0.28), 8, 5)]
        canopy(c, masses, leaf, rng, step=2)
        tuft(c, cx, H - 1, 4, leaf, rng)
    else:  # 48 x 80: umbrella crown, thin bent trunk
        tb, tt = H - 2, int(H * 0.50)
        trunk(c, cx, tb, tt, 3, 2, bark, kink=-4)
        branch(c, cx - 4, tt + 2, cx - 16, tt - 6, 2, 1, bark)
        branch(c, cx - 4, tt + 1, cx + 12, tt - 5, 2, 1, bark)
        branch(c, cx - 4, tt, cx - 2, tt - 14, 2, 1, bark)
        masses = [(cx + 4, int(H * 0.36), 15, 8), (cx - 10, int(H * 0.38), 13, 8), (cx - 3, int(H * 0.26), 16, 8)]
        canopy(c, masses, leaf, rng, step=2)
        tuft(c, cx, H - 1, 5, leaf, rng)
    outline_pass(c, leaf, bark)
    return c


# --- Shrub: privet hedge --------------------------------------------------------

def hedge(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = RES_LEAF, BARK
    if stage == 0:  # 16 x 16: a few sprigs
        for (x, y, br) in ((5, 7, B3), (10, 6, B4), (8, 10, B3)):
            c.put(x, y + 2, bark[1])
            c.put(x, y + 3, bark[1])
            blob(c, x, y, br, leaf, rng, glint=False)
        shadow_band(c, 3, 12, H - 1, leaf)
        outline_pass(c, leaf, bark, skip=set(bark[1:]))
        return c
    # a long low mound: cluster texture on the top, plain dark belly
    if stage == 1:  # 32 x 24
        masses = [(10, 13, 9, 7), (21, 12, 10, 8)]
    else:  # 48 x 24
        masses = [(9, 14, 9, 7), (24, 12, 13, 9), (38, 13, 10, 8)]
    canopy(c, masses, leaf, rng, step=2, density=(0.9, 0.7, 0.55))
    # belly: below the mass centre-line the lighter tones give way to shadow
    for (mx, my, rx, ry) in masses:
        for y in range(my + ry // 2, my + ry + 1):
            for x in range(int(mx - rx), int(mx + rx) + 1):
                p = c.get(x, y)
                if p[3] and p[:3] in (leaf[3], leaf[4], leaf[5]):
                    c.put(x, y, leaf[2])
    # twig stubs at the base
    for x in (int(masses[0][0]) - 2, int(masses[-1][0]) + 3):
        c.put(x, H - 2, bark[1])
        c.put(x, H - 3, bark[1])
    shadow_band(c, int(masses[0][0] - masses[0][2]) + 1, int(masses[-1][0] + masses[-1][2]) - 1, H - 1, leaf)
    outline_pass(c, leaf, bark)
    return c


# --- Shrub: rose bush -----------------------------------------------------------

def rose(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = RES_LEAF, BARK
    pink, pink_dark = ROSE_PINK
    if stage == 0:  # 16 x 16: a rose sprig with one bud
        for y in range(H - 2, 5, -1):
            c.put(8, y, bark[1])
        blob(c, 5, 8, B3, leaf, rng, glint=False)
        blob(c, 11, 10, B3, leaf, rng, glint=False)
        c.put(8, 5, pink)
        c.put(9, 5, pink)
        c.put(8, 4, pink)
        c.put(9, 4, pink_dark)
        shadow_band(c, 4, 12, H - 1, leaf)
        outline_pass(c, leaf, bark, skip=set(bark[1:]))
        return c
    if stage == 1:  # 32 x 24: two masses, thorny stems, 2 blossoms
        masses = [(11, 12, 9, 8), (21, 11, 9, 8)]
        stems = ((12, H - 2, 12, 10), (20, H - 2, 19, 9))
        n_bloss = 2
    else:  # 32 x 32: dome of three masses, 4 blossoms
        masses = [(10, 19, 9, 9), (22, 18, 9, 9), (16, 11, 10, 8)]
        stems = ((11, H - 2, 11, 14), (21, H - 2, 20, 12), (16, H - 2, 16, 16))
        n_bloss = 4
    for (x0, y0, x1, y1) in stems:
        branch(c, x0, y0, x1, y1, 1, 1, bark)
    canopy(c, masses, leaf, rng, step=2, density=(0.9, 0.75, 0.6))
    # thorny gaps: 1-px bark stems show through the canopy here and there
    for (x0, y0, x1, y1) in stems:
        for y in range(y1, y1 + 5):
            if c.opaque(x1, y):
                c.put(x1, y, bark[1])
    blossoms(c, masses, rng, n_bloss, pink, pink_dark)
    shadow_band(c, int(masses[0][0] - masses[0][2]) + 1, int(masses[-1][0] + masses[-1][2]) - 1, H - 1, leaf)
    outline_pass(c, leaf, bark)
    return c


def blossoms(c: Canvas, masses, rng, n, col, col_dark):
    """Plus-shaped 3x3 flowers with a darker lower-right petal, on the upper
    two thirds of the masses, never touching each other."""
    placed, tries = 0, 0
    while placed < n and tries < 80:
        tries += 1
        (mx, my, rx, ry) = masses[rng.randrange(len(masses))]
        x = int(mx + rng.uniform(-rx * 0.6, rx * 0.6))
        y = int(my + rng.uniform(-ry * 0.6, ry * 0.3))
        if not all(c.opaque(x + dx, y + dy) for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1))):
            continue
        if any(c.get(x + dx, y + dy)[:3] in (col, col_dark) for dx in range(-4, 5) for dy in range(-4, 5)):
            continue
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1)):
            c.put(x + dx, y + dy, col)
        c.put(x, y + 1, col_dark)
        placed += 1


# --- Grass: lawn tuft -----------------------------------------------------------

def lawn(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = RES_LEAF
    dark, mid, light = leaf[2], leaf[3], leaf[4]
    if stage == 0:  # 16 x 8: sprouts
        for x, h in ((3, 2), (6, 3), (10, 2), (12, 3)):
            for k in range(h):
                c.put(x - (1 if k == h - 1 else 0), H - 2 - k, mid if k < h - 1 else light)
        shadow_band(c, 2, 13, H - 1, leaf)
        return c
    # blades 1 px wide, uneven heights, all leaning left, tallest off-centre
    heights = [4, 7, 5, 9, 6, 4, 8, 5] if stage == 2 else [3, 5, 4, 6, 4, 3, 5, 4]
    xs = [1, 3, 5, 6, 8, 10, 12, 14]
    for i, (x, h) in enumerate(zip(xs, heights)):
        col = (dark, mid, light)[(i * 7) % 3]
        for k in range(h):
            bend = 1 if k >= h - 2 else 0
            c.put(x - bend, H - 2 - k, col if k < h - 1 else light)
    if stage == 2:  # daisies: a 3-px white plus with a yellow centre
        petal, centre = DAISY
        for (x, y) in ((4, 4), (11, 3)):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                c.put(x + dx, y + dy, petal)
            c.put(x, y, centre)
            c.put(x, y + 2, dark)
            c.put(x, y + 3, dark)
    shadow_band(c, 0, W - 1, H - 1, leaf)
    return c


# --- Grass: clover -------------------------------------------------------------

def clover(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = RES_LEAF
    dark, mid, light = leaf[2], leaf[3], leaf[4]

    def trio(x, y, tone, lit):
        for (dx, dy) in ((-1, -1), (1, -1), (0, 1)):
            c.stamp(x + dx, y + dy, B2, tone)
        c.put(x - 1, y - 2, lit)
        c.put(x, y + 3, dark)  # stem
    if stage == 0:  # 16 x 8
        trio(5, 3, mid, light)
        trio(11, 4, dark, mid)
        shadow_band(c, 3, 13, H - 1, leaf)
        return c
    spots = [(4, 5, mid, light), (11, 4, dark, mid), (8, 9, mid, light)] if stage == 1 else \
        [(3, 6, dark, mid), (8, 4, mid, light), (13, 6, mid, light), (5, 10, mid, light), (11, 10, dark, mid)]
    for (x, y, tone, lit) in spots:
        trio(x, y, tone, lit)
    if stage == 2:  # one white clover flower
        w, w_dark = CLOVER_WHITE
        c.rect(9, 1, 10, 2, w)
        c.put(10, 2, w_dark)
        c.put(9, 3, dark)
    shadow_band(c, 1, W - 2, H - 1, leaf)
    return c


def _pin_tree(stage, H):
    return 2 if stage == 0 else int(H * 0.3)


def _pin_shrub(stage, H):
    return 3 if stage == 0 else 4


def _pin_grass(stage, H):
    return 2 if stage == 0 else 3


SPECIES = {
    "res_plane": {
        "name": "London Plane", "slot": "tree", "draw": plane, "pin": _pin_tree,
        "stages": [(2, 4), (6, 12), (10, 24)],
        "seed": {"kind": "ball", "tint": (150, 118, 70), "name": "Plane Seed Ball"},
        "desc": "A plane sapling. Pale mottled bark, a broad ragged crown when grown - the big wood tree of the housing blocks.",
    },
    "res_apple": {
        "name": "Apple Tree", "slot": "tree", "draw": apple, "pin": _pin_tree,
        "stages": [(2, 4), (6, 9), (8, 16)],
        "seed": {"kind": "pip", "tint": (120, 60, 40), "name": "Apple Pip"},
        "desc": "An apple sapling. Grows a round crown with red fruit over a short thick trunk.",
    },
    "res_maple": {
        "name": "Ornamental Maple", "slot": "tree", "draw": maple, "pin": _pin_tree,
        "stages": [(2, 3), (4, 6), (6, 10)],
        "seed": {"kind": "samara", "tint": (196, 96, 48), "name": "Maple Samara"},
        "desc": "A maple whip. A thin bent trunk under a flat amber-edged umbrella when grown.",
    },
    "res_hedge": {
        "name": "Privet Hedge", "slot": "shrub", "draw": hedge, "pin": _pin_shrub,
        "stages": [(2, 2), (4, 3), (6, 3)],
        "desc": "Privet sprigs. Left alone they knit into a long low hedge - hand-harvest wood, no axe.",
    },
    "res_rose": {
        "name": "Rose Bush", "slot": "shrub", "draw": rose, "pin": _pin_shrub,
        "stages": [(2, 2), (4, 3), (4, 4)],
        "desc": "A rose sprig. Thorny stems and pink blossoms once it fills out - hand-harvest wood.",
    },
    "res_lawn": {
        "name": "Lawn Tuft", "slot": "grass", "draw": lawn, "pin": _pin_grass,
        "stages": [(2, 1), (2, 2), (2, 2)],
        "desc": "Lawn grass. Daisies when it is left to grow.",
    },
    "res_clover": {
        "name": "Clover", "slot": "grass", "draw": clover, "pin": _pin_grass,
        "stages": [(2, 1), (2, 2), (2, 2)],
        "desc": "A clover patch. Fodder and fertiliser one day; organic matter for now.",
    },
}

DISTRICT = "residential"


def LEAF_OF(sid):
    return MAPLE_LEAF if sid == "res_maple" else RES_LEAF
