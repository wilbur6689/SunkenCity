"""Civil district flora (docs/Flora/flora.md section 6.1).

Park and memorial planting: the grandest trees, formal beds, clipped
evergreens. Clean mid greens closest to the base ramp (civic-green district
tint); purple, poppy-red and white accents. Seven species x three stages;
every drawer returns the REST frame.

The 14x30 "great oak" landmark from the roster is deferred: the growth chain
is deterministic per dawn, so a fourth stage would turn every oak into a
landmark - it needs a rarity roll at seeding first (FloraChecklist.md).
"""
import random

from common import (BARK, LEAF, B2, B3, B4, B5, Canvas, blob, branch, canopy, outline_pass,
                    seedling, shadow_band, shift_ramp, trunk, tuft)

CIV_LEAF = shift_ramp(LEAF, hue_deg=2, sat=0.95, val=1.0)          # the base ramp, near enough
LINDEN_LEAF = shift_ramp(LEAF, hue_deg=-6, sat=0.95, val=1.02)
LINDEN_LEAF[5] = (200, 224, 140)                                    # pale yellow-green glint
RHODO_LEAF = shift_ramp(LEAF, hue_deg=6, sat=0.9, val=0.88)         # big dark glossy leaves
YEW_LEAF = shift_ramp(LEAF, hue_deg=12, sat=0.8, val=0.78)          # dark clipped evergreen
YEW_LEAF[5] = shift_ramp(LEAF, hue_deg=12, sat=0.8, val=0.9)[4]      # a restrained glint
BIRCH_BARK = [(48, 48, 52), (150, 150, 146), (214, 214, 206), (240, 240, 234)]
BIRCH_FLECK = (60, 60, 58)
OAK_BARK = [BARK[0], (84, 58, 36), (124, 88, 54), (166, 124, 80)]
PURPLE = ((150, 90, 190), (196, 150, 226), (104, 56, 140))          # rhodo trusses: base, light, dark
POPPY = ((204, 52, 40), (60, 24, 24))                                # petals, centre
DISTRICT = "civil"


def LEAF_OF(sid):
    return {"civ_linden": LINDEN_LEAF, "civ_rhodo": RHODO_LEAF, "civ_yew": YEW_LEAF}.get(sid, CIV_LEAF)


# --- Large: park oak --------------------------------------------------------------------

def oak(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = CIV_LEAF, OAK_BARK
    if stage == 0:
        seedling(c, W, H, rng, leaf, bark, leaves=3, lean=-1)
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        return c
    cx = W // 2 + 1
    if stage == 1:  # 48 x 96: a young oak - stout trunk, two forks, three crowns
        tb, tt = H - 2, int(H * 0.52)
        branch(c, cx, tt + 6, cx - 12, tt - 8, 3, 1, bark)
        branch(c, cx + 1, tt + 4, cx + 10, tt - 7, 3, 1, bark)
        trunk(c, cx, tb, tt, 5, 4, bark, kink=-1)
        masses = [(cx + 8, int(H * 0.36), 14, 12), (cx - 10, int(H * 0.40), 13, 12), (cx - 1, int(H * 0.22), 13, 10)]
        canopy(c, masses, leaf, rng, step=2)
        tuft(c, cx, H - 1, 6, leaf, rng)
    else:  # 80 x 192: a massive spreading crown of six sub-crowns on a thick forked trunk
        tb, tt = H - 2, int(H * 0.52)
        branch(c, cx - 1, tt + 12, cx - 22, tt - 12, 6, 2, bark)
        branch(c, cx + 2, tt + 8, cx + 20, tt - 10, 6, 2, bark)
        branch(c, cx, tt + 4, cx - 6, tt - 30, 5, 2, bark)
        branch(c, cx + 1, tt + 2, cx + 12, tt - 26, 4, 2, bark)
        trunk(c, cx, tb, tt, 10, 8, bark, kink=1)
        masses = [
            (cx + 18, int(H * 0.34), 21, 17),   # right lobe (back)
            (cx - 20, int(H * 0.38), 19, 16),   # left lobe, lower
            (cx + 8, int(H * 0.15), 18, 14),    # top right
            (cx - 9, int(H * 0.18), 17, 14),    # top left
            (cx - 3, int(H * 0.29), 27, 18),    # centre (front)
            (cx + 10, int(H * 0.45), 16, 10),   # a low bough
        ]
        canopy(c, masses, leaf, rng, step=3)
        tuft(c, cx, H - 1, 10, leaf, rng, blades=5)
    outline_pass(c, leaf, bark)
    return c


# --- Medium: linden ---------------------------------------------------------------------

def linden(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = LINDEN_LEAF, BARK
    if stage == 0:
        seedling(c, W, H, rng, leaf, bark, leaves=2, lean=1)
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        return c
    cx = W // 2
    if stage == 1:  # 48 x 72: a tidy young heart - pointed top, rounded wide base
        tb, tt = H - 2, int(H * 0.52)
        trunk(c, cx, tb, tt, 4, 3, bark)
        branch(c, cx, tt + 3, cx - 6, tt - 6, 2, 1, bark)
        masses = [(cx + 6, int(H * 0.40), 12, 10), (cx - 7, int(H * 0.42), 12, 10), (cx - 1, int(H * 0.26), 10, 9), (cx - 1, int(H * 0.12), 5, 5)]
        canopy(c, masses, leaf, rng, step=2)
        tuft(c, cx, H - 1, 5, leaf, rng)
    else:  # 64 x 128: the heart-shaped crown
        tb, tt = H - 2, int(H * 0.56)
        trunk(c, cx, tb, tt, 6, 4, bark, kink=1)
        branch(c, cx, tt + 4, cx - 10, tt - 10, 3, 1, bark)
        branch(c, cx + 1, tt + 2, cx + 9, tt - 8, 3, 1, bark)
        masses = [
            (cx + 13, int(H * 0.42), 16, 13),
            (cx - 14, int(H * 0.44), 16, 13),
            (cx - 1, int(H * 0.30), 18, 13),
            (cx, int(H * 0.15), 11, 10),
            (cx - 1, int(H * 0.05), 5, 5),     # the point
        ]
        canopy(c, masses, leaf, rng, step=3)
        tuft(c, cx, H - 1, 7, leaf, rng, blades=4)
    outline_pass(c, leaf, bark)
    return c


# --- Small: weeping birch --------------------------------------------------------------

def birch_trunk(c: Canvas, cx, y_bottom, y_top, w0, w1, rng, kink=0):
    trunk(c, cx, y_bottom, y_top, w0, w1, BIRCH_BARK, kink=kink)
    # dark flecks: 2x1 bars on the mid tone, irregularly spaced
    h = y_bottom - y_top
    y = y_top + 3
    while y < y_bottom - 3:
        t = (y_bottom - y) / max(1, h)
        x_c = cx + int(round(kink * t))
        w = max(1, int(round(w0 + (w1 - w0) * t)))
        x = x_c - w // 2 + rng.randint(0, max(0, w - 2))
        c.put(x, y, BIRCH_FLECK)
        if w >= 3:
            c.put(x + 1, y, BIRCH_FLECK)
        y += rng.randint(3, 6)


def strands(c: Canvas, masses, leaf, rng, n_per, length):
    """Weeping strands: 2-px-wide (shadow + mid) verticals hanging from the
    lower rim of each mass, leaning left near the tip, a leaf tip at the end.
    Drawn after the outline pass so they stay 2 px, never 3."""
    shadow, dark, mid, light = leaf[1], leaf[2], leaf[3], leaf[4]
    for (mx, my, rx, ry) in masses:
        for i in range(n_per):
            x = int(mx + rx * rng.uniform(-0.85, 0.85))
            y = int(my + ry * 0.6)
            while not c.opaque(x, y) and y > my:
                y -= 1
            ln = rng.randint(int(length * 0.5), length)
            for k in range(ln):
                yy = y + k
                xx = x - (1 if k > ln - 4 else 0)
                c.put(xx, yy, shadow if k % 5 == 4 else dark)
                c.put(xx + 1, yy, mid if k % 3 else light)
            c.stamp(x - 1, y + ln, B2, mid)
            c.put(x - 1, y + ln, light)


def birch(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = CIV_LEAF, BIRCH_BARK
    cx = W // 2 + 1
    if stage == 0:  # 16 x 24: a white whip with two leaves and one hanging strand
        for y in range(H - 2, 7, -1):
            c.put(cx, y, bark[2] if y > 13 else leaf[2])
        c.put(cx, H - 6, BIRCH_FLECK)
        blob(c, cx - 3, 10, B3, leaf, rng, glint=False)
        blob(c, cx + 3, 9, B3, leaf, rng, glint=False)
        shadow_band(c, cx - 3, cx + 2, H - 1, leaf)
        c.put(cx, H - 1, leaf[0])
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        for k in range(5):
            c.put(cx + 3, 11 + k, leaf[2])
            c.put(cx + 4, 11 + k, leaf[3])
        return c
    if stage == 1:  # 32 x 48
        tb, tt = H - 2, int(H * 0.40)
        birch_trunk(c, cx, tb, tt, 3, 2, rng, kink=-1)
        branch(c, cx - 1, tt + 3, cx - 7, tt - 3, 2, 1, bark)
        masses = [(cx - 1, int(H * 0.28), 11, 7), (cx + 4, int(H * 0.36), 7, 5)]
        canopy(c, masses, leaf, rng, step=2, density=(0.9, 0.75, 0.6))
        tuft(c, cx, H - 1, 4, leaf, rng)
        outline_pass(c, leaf, bark)
        strands(c, masses, leaf, rng, 3, 10)
    else:  # 48 x 80: white flecked trunk, a loose top, long drooping strands
        tb, tt = H - 2, int(H * 0.36)
        birch_trunk(c, cx, tb, tt, 4, 2, rng, kink=-2)
        branch(c, cx - 2, tt + 4, cx - 12, tt - 4, 2, 1, bark)
        branch(c, cx - 1, tt + 2, cx + 9, tt - 3, 2, 1, bark)
        masses = [(cx - 4, int(H * 0.24), 14, 8), (cx + 8, int(H * 0.32), 9, 6), (cx - 10, int(H * 0.34), 8, 6)]
        canopy(c, masses, leaf, rng, step=2, density=(0.9, 0.75, 0.6))
        tuft(c, cx, H - 1, 5, leaf, rng)
        outline_pass(c, leaf, bark)
        strands(c, masses, leaf, rng, 4, 18)
    return c


# --- Shrub: rhododendron -------------------------------------------------------------

def rhodo(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = RHODO_LEAF, BARK
    pur, pur_light, pur_dark = PURPLE
    if stage == 0:  # 16 x 16: big-leaved sprig with a bud
        c.rect(8, 6, 8, H - 2, bark[1])
        blob(c, 5, 8, B4, leaf, rng, glint=False)
        blob(c, 11, 10, B4, leaf, rng, glint=False)
        c.stamp(8, 5, B2, pur)
        c.put(8, 4, pur_light)
        shadow_band(c, 4, 12, H - 1, leaf)
        outline_pass(c, leaf, bark, skip=set(bark[1:]))
        return c
    if stage == 1:  # 32 x 24
        masses = [(11, 13, 9, 8), (21, 12, 9, 8)]
        n = 2
    else:  # 48 x 32: a wide dome
        masses = [(12, 20, 11, 10), (36, 19, 11, 10), (24, 14, 14, 10)]
        n = 5
        for x in (14, 24, 34):
            c.rect(x, H - 3, x, H - 2, bark[1])
    canopy(c, masses, leaf, rng, step=2, density=(0.9, 0.75, 0.6))
    for (mx, my, rx, ry) in masses:  # big leaves on the rim
        for _ in range(2):
            x = int(mx + rng.uniform(-rx * 0.6, rx * 0.6))
            y = int(my + rng.uniform(-ry * 0.6, ry * 0.4))
            c.stamp(x, y, B5, leaf[3], clip=lambda px, py: c.opaque(px, py))
            c.put(x - 1, y - 1, leaf[4])
            c.put(x - 2, y - 1, leaf[4])
    trusses(c, masses, rng, n, pur, pur_light, pur_dark)
    shadow_band(c, int(masses[0][0] - masses[0][2]) + 1, int(masses[1][0] + masses[1][2]) - 1, H - 1, leaf)
    outline_pass(c, leaf, bark)
    return c


def trusses(c: Canvas, masses, rng, n, col, light, dark):
    """2x3 flower trusses: a B3 plus in the base colour, light top-left, dark bottom."""
    placed, tries = 0, 0
    while placed < n and tries < 80:
        tries += 1
        (mx, my, rx, ry) = masses[rng.randrange(len(masses))]
        x = int(mx + rng.uniform(-rx * 0.6, rx * 0.6))
        y = int(my + rng.uniform(-ry * 0.7, ry * 0.2))
        if not all(c.opaque(x + dx, y + dy) for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1))):
            continue
        if any(c.get(x + dx, y + dy)[:3] in (col, light, dark) for dx in range(-4, 5) for dy in range(-4, 5)):
            continue
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1)):
            c.put(x + dx, y + dy, col)
        c.put(x - 1, y - 1, light)
        c.put(x, y + 1, dark)
        placed += 1


# --- Shrub: memorial yew --------------------------------------------------------------

def yew(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = YEW_LEAF, BARK
    if stage == 0:  # 16 x 16: a dark little spike
        c.rect(8, H - 5, 8, H - 2, bark[1])
        blob(c, 8, 8, B4, leaf, rng, glint=False)
        blob(c, 8, 5, B3, leaf, rng, glint=False)
        shadow_band(c, 5, 11, H - 1, leaf)
        outline_pass(c, leaf, bark, skip=set(bark[1:]))
        return c
    cx = W // 2 + 1
    if stage == 1:  # 32 x 32: a young clipped cone
        c.rect(cx - 1, H - 4, cx, H - 2, bark[1])
        masses = [(cx, 22, 11, 8), (cx, 14, 8, 7), (cx - 1, 7, 4, 5)]
    else:  # 32 x 48: the memorial cone, smooth clipped outline
        c.rect(cx - 1, H - 5, cx, H - 2, bark[1])
        masses = [(cx, 38, 13, 9), (cx, 28, 11, 9), (cx, 18, 8, 8), (cx - 1, 9, 5, 6), (cx - 1, 3, 2, 3)]
    canopy(c, masses, leaf, rng, step=2, density=(1.0, 0.95, 0.8), teeth=False, glint_frac=0.2)
    shadow_band(c, int(masses[0][0] - masses[0][2]) + 2, int(masses[0][0] + masses[0][2]) - 2, H - 1, leaf)
    outline_pass(c, leaf, bark)
    return c


# --- Grass: meadow tuft ------------------------------------------------------------------

def meadow(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = CIV_LEAF
    dark, mid, light = leaf[2], leaf[3], leaf[4]
    red, red_dark = POPPY
    if stage == 0:  # 16 x 8
        for x, h in ((2, 3), (6, 2), (9, 3), (13, 2)):
            for k in range(h):
                c.put(x - (1 if k == h - 1 else 0), H - 2 - k, mid if k < h - 1 else light)
        shadow_band(c, 1, 14, H - 1, leaf)
        return c
    heights = [6, 10, 8, 12, 7, 5, 11, 8] if stage == 2 else [4, 6, 5, 7, 4, 3, 6, 5]
    xs = [1, 3, 4, 6, 8, 10, 12, 14]
    for i, (x, h) in enumerate(zip(xs, heights)):
        col = (dark, mid, light, mid)[(i * 5) % 4]
        for k in range(h):
            bend = 1 if k >= h - 3 else 0
            c.put(x - bend, H - 2 - k, col if k < h - 1 else light)
    if stage == 2:  # poppies: 2x2 red heads with a dark centre
        for (x, y) in ((4, 3), (11, 2)):
            c.stamp(x, y, B2, red)
            c.put(x, y, red_dark)
            c.put(x, y + 2, dark)
            c.put(x, y + 3, dark)
    shadow_band(c, 0, W - 1, H - 1, leaf)
    return c


# --- Grass: ivy ---------------------------------------------------------------------------

def ivy(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = CIV_LEAF
    shadow, dark, mid, light = leaf[1], leaf[2], leaf[3], leaf[4]

    def heart(x, y, tone, lit):
        c.stamp(x, y, B3, shadow)
        c.put(x - 1, y - 1, tone)
        c.put(x + 1, y - 1, tone)
        c.put(x, y, tone)
        c.put(x - 1, y - 1, lit)

    if stage == 0:  # 16 x 8: a short trailing stem with two leaves
        for x in range(4, 12):
            c.put(x, H - 3 + (1 if x % 5 == 0 else 0), dark)
        heart(5, H - 5, mid, light)
        heart(10, H - 5, dark, mid)
        shadow_band(c, 3, 12, H - 1, leaf)
        return c
    # trailing stems low along the ground, leaves climbing a little
    runs = [(1, 14, H - 3), (3, 12, H - 7)] if stage == 1 else [(0, 15, H - 3), (2, 13, H - 7), (5, 11, H - 11)]
    for (x0, x1, y) in runs:
        for x in range(x0, x1 + 1):
            c.put(x, y + (1 if (x * 7) % 5 == 0 else 0), dark)
    leaves = [(3, H - 5, mid, light), (8, H - 6, dark, mid), (13, H - 5, mid, light), (6, H - 9, mid, light), (11, H - 10, dark, mid)]
    if stage == 2:
        leaves += [(4, H - 13, mid, light), (9, H - 13, light, leaf[5])]
    for (x, y, tone, lit) in leaves:
        heart(x, y, tone, lit)
    shadow_band(c, 0, W - 1, H - 1, leaf)
    return c


def _pin_tree(stage, H):
    return 2 if stage == 0 else int(H * 0.3)


def _pin_shrub(stage, H):
    return 3 if stage == 0 else 5


def _pin_grass(stage, H):
    return 2 if stage == 0 else 3


SPECIES = {
    "civ_oak": {
        "name": "Park Oak", "slot": "tree", "draw": oak, "pin": _pin_tree,
        "stages": [(2, 4), (6, 12), (10, 24)],
        "seed": {"kind": "pip", "tint": (140, 96, 50), "name": "Acorn"},
        "desc": "An oak seedling. The grandest tree in the city: a massive spreading crown on a thick forked trunk.",
    },
    "civ_linden": {
        "name": "Linden", "slot": "tree", "draw": linden, "pin": _pin_tree,
        "stages": [(2, 4), (6, 9), (8, 16)],
        "seed": {"kind": "samara", "tint": (170, 160, 110), "name": "Linden Seed"},
        "desc": "A linden sapling. A tidy heart-shaped crown with a pale glint - the avenue tree of the civic squares.",
    },
    "civ_birch": {
        "name": "Weeping Birch", "slot": "tree", "draw": birch, "pin": _pin_tree,
        "stages": [(2, 3), (4, 6), (6, 10)],
        "seed": {"kind": "ball", "tint": (200, 190, 170), "name": "Birch Catkin"},
        "desc": "A birch whip. White flecked bark and long drooping strands when grown.",
    },
    "civ_rhodo": {
        "name": "Rhododendron", "slot": "shrub", "draw": rhodo, "pin": _pin_shrub,
        "stages": [(2, 2), (4, 3), (6, 4)],
        "desc": "A rhododendron sprig. A wide dome of big dark leaves and purple trusses - hand-harvest wood.",
    },
    "civ_yew": {
        "name": "Memorial Yew", "slot": "shrub", "draw": yew, "pin": _pin_shrub,
        "stages": [(2, 2), (4, 4), (4, 6)],
        "desc": "A yew seedling. Clipped into a dark memorial cone - hand-harvest wood.",
    },
    "civ_meadow": {
        "name": "Meadow Tuft", "slot": "grass", "draw": meadow, "pin": _pin_grass,
        "stages": [(2, 1), (2, 2), (2, 2)],
        "desc": "Tall meadow grass. Poppies when left alone.",
    },
    "civ_ivy": {
        "name": "Ivy", "slot": "grass", "draw": ivy, "pin": _pin_grass,
        "stages": [(2, 1), (2, 2), (2, 2)],
        "desc": "Trailing ivy along the parapet.",
    },
}
