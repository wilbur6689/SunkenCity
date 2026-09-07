"""Construction district flora (docs/Flora/flora.md section 6.1).

Pioneers in rubble: the youngest flora in the city, so the seeding weights
favour seedlings and midlings (WEIGHTS 5:2:1). Yellow-green shifted ramp
(hi-vis district tint), rust rebar and hi-vis tape accents. Seven species x
three stages; every drawer returns the REST frame.
"""
import math
import random

from civ import strands
from common import (BARK, LEAF, B2, B3, B4, B5, Canvas, blob, branch, canopy, outline_pass,
                    seedling, shadow_band, shift_ramp, trunk, tuft)

CON_LEAF = shift_ramp(LEAF, hue_deg=-20, sat=0.95, val=1.04)          # yellow-green
CON_LEAF[5] = (208, 226, 128)
REBAR = [(40, 26, 20), (110, 58, 36), (150, 84, 50), (186, 120, 80)]   # rust ramp
HIVIS = ((240, 220, 60), (196, 170, 30))
CREAM = ((236, 232, 200), (200, 194, 160))                             # elder flower plates
ELDERBERRY = (36, 28, 44)
RAGWORT = ((236, 200, 60), (170, 130, 30))
RUBBLE = [(38, 36, 34), (84, 82, 80), (114, 112, 110), (144, 142, 140)]
DISTRICT = "construction"
# the youngest district: seedlings dominate (docs/Flora/flora.md 6.1)
WEIGHTS = {"tree": (5, 2, 1), "shrub": (4, 2, 1), "grass": (3, 2, 2)}


def LEAF_OF(sid):
    return CON_LEAF


# --- Large: willow -------------------------------------------------------------------------

def willow(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = CON_LEAF, BARK
    if stage == 0:
        seedling(c, W, H, rng, leaf, bark, leaves=3, lean=-1)
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        # one drooping strand from the top leaf
        for k in range(5):
            c.put(W // 2 - 3, H // 3 + 4 + k, leaf[2])
            c.put(W // 2 - 2, H // 3 + 4 + k, leaf[3])
        return c
    cx = W // 2 + 2
    if stage == 1:  # 48 x 96: a young willow - a leaning trunk, a loose mound, strands starting
        tb, tt = H - 2, int(H * 0.46)
        trunk(c, cx, tb, tt, 5, 3, bark, kink=-3)
        branch(c, cx - 3, tt + 4, cx - 12, tt - 6, 3, 1, bark)
        branch(c, cx - 2, tt + 2, cx + 7, tt - 5, 3, 1, bark)
        masses = [(cx - 4, int(H * 0.32), 16, 11), (cx + 6, int(H * 0.40), 10, 8), (cx - 12, int(H * 0.42), 9, 7)]
        canopy(c, masses, leaf, rng, step=2, density=(0.9, 0.75, 0.6))
        tuft(c, cx, H - 1, 6, leaf, rng)
        outline_pass(c, leaf, bark)
        strands(c, masses, leaf, rng, 4, 16)
    else:  # 80 x 176: the weeping mass - a big rounded crown, curtains of strands all round
        tb, tt = H - 2, int(H * 0.50)
        trunk(c, cx, tb, tt, 8, 5, bark, kink=-4)
        branch(c, cx - 4, tt + 6, cx - 22, tt - 10, 4, 2, bark)
        branch(c, cx - 3, tt + 3, cx + 16, tt - 8, 4, 2, bark)
        branch(c, cx - 4, tt, cx - 6, tt - 24, 3, 1, bark)
        masses = [
            (cx + 12, int(H * 0.36), 18, 13),
            (cx - 20, int(H * 0.40), 16, 12),
            (cx - 4, int(H * 0.20), 20, 13),
            (cx - 6, int(H * 0.32), 24, 14),
        ]
        canopy(c, masses, leaf, rng, step=3, density=(0.9, 0.75, 0.6))
        tuft(c, cx, H - 1, 8, leaf, rng, blades=4)
        outline_pass(c, leaf, bark)
        strands(c, masses, leaf, rng, 5, 30)
    return c


# --- Medium: poplar ---------------------------------------------------------------------------

def poplar(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = CON_LEAF, BARK
    cx = W // 2 + 1
    if stage == 0:  # 16 x 32: an upright whip, leaves close to the stem
        for y in range(H - 2, 7, -1):
            c.put(cx, y, bark[2] if y > H - 12 else leaf[2])
        blob(c, cx - 2, 10, B3, leaf, rng, glint=True)
        blob(c, cx + 2, 14, B3, leaf, rng, glint=False)
        blob(c, cx - 2, 18, B3, leaf, rng, glint=False)
        shadow_band(c, cx - 3, cx + 2, H - 1, leaf)
        c.put(cx, H - 1, leaf[0])
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        return c
    if stage == 1:  # 32 x 80: a narrow young column
        tb, tt = H - 2, H - 14
        trunk(c, cx, tb, tt, 3, 2, bark)
        masses = [(cx, int(H * 0.72), 8, 14), (cx, int(H * 0.48), 9, 15), (cx - 1, int(H * 0.24), 7, 13), (cx - 1, int(H * 0.08), 4, 7)]
        canopy(c, masses, leaf, rng, step=2, density=(0.9, 0.8, 0.7), glint_frac=0.35)
        tuft(c, cx, H - 1, 4, leaf, rng)
    else:  # 48 x 160: the column - broadleaf, so teeth on the rim; the glint flicker is its accent
        tb, tt = H - 2, H - 22
        trunk(c, cx, tb, tt, 5, 3, bark)
        masses = [(cx, int(H * 0.78), 12, 22), (cx, int(H * 0.58), 13, 24), (cx - 1, int(H * 0.38), 12, 22),
                  (cx - 1, int(H * 0.20), 9, 18), (cx - 2, int(H * 0.06), 5, 10)]
        canopy(c, masses, leaf, rng, step=3, density=(0.9, 0.8, 0.7), glint_frac=0.35)
        tuft(c, cx, H - 1, 6, leaf, rng, blades=4)
    outline_pass(c, leaf, bark)
    return c


# --- Small: elder --------------------------------------------------------------------------

def elder(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = CON_LEAF, BARK
    cream, cream_dark = CREAM
    cx = W // 2
    if stage == 0:  # 16 x 24: a shrubby sprout with one flower plate
        seedling(c, W, H, rng, leaf, bark, leaves=2, lean=-1)
        c.rect(cx - 3, H // 3 - 2, cx - 1, H // 3 - 2, cream)
        c.put(cx, H // 3 - 2, cream_dark)
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        return c
    if stage == 1:  # 32 x 48: several stems, a loose low crown
        stems = [(cx - 1, cx - 7, int(H * 0.44)), (cx, cx + 1, int(H * 0.36)), (cx + 1, cx + 7, int(H * 0.46))]
        masses = [(cx - 5, int(H * 0.36), 9, 7), (cx + 5, int(H * 0.40), 9, 7), (cx, int(H * 0.26), 8, 6)]
        n_plates, n_berries = 3, 2
    else:  # 48 x 72: a shrubby small tree
        stems = [(cx - 2, cx - 12, int(H * 0.46)), (cx, cx - 2, int(H * 0.34)), (cx + 2, cx + 11, int(H * 0.48))]
        masses = [(cx - 10, int(H * 0.38), 11, 8), (cx + 9, int(H * 0.42), 11, 8), (cx - 1, int(H * 0.26), 13, 9), (cx + 2, int(H * 0.36), 9, 6)]
        n_plates, n_berries = 5, 4
    for (x0, x1, y1) in stems:
        branch(c, x0, H - 2, x1, y1, 2, 1, bark)
    canopy(c, masses, leaf, rng, step=2, density=(0.9, 0.75, 0.6))
    # cream flower plates: 3x1 bars on the upper rim; black berry clusters lower down
    for i in range(n_plates):
        (mx, my, rx, ry) = masses[i % len(masses)]
        x = int(mx + rng.uniform(-rx * 0.5, rx * 0.5))
        y = int(my - ry * rng.uniform(0.3, 0.8))
        if c.opaque(x, y):
            c.rect(x - 1, y, x + 1, y, cream)
            c.put(x + 2, y, cream_dark)
            c.put(x, y + 1, cream_dark)
    for i in range(n_berries):
        (mx, my, rx, ry) = masses[i % len(masses)]
        x = int(mx + rng.uniform(-rx * 0.5, rx * 0.5))
        y = int(my + ry * rng.uniform(0.1, 0.6))
        if c.opaque(x, y):
            c.stamp(x, y, B2, ELDERBERRY)
            c.put(x, y + 1, ELDERBERRY)
    tuft(c, cx, H - 1, 4 if stage == 1 else 6, leaf, rng)
    outline_pass(c, leaf, bark)
    return c


# --- Shrub: ragwort clump -----------------------------------------------------------------------

def ragwort(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = CON_LEAF
    shadow, dark, mid, light = leaf[1], leaf[2], leaf[3], leaf[4]
    yel, yel_dark = RAGWORT
    if stage == 0:  # 16 x 16: ragged upright leaves, no flower yet
        for (x, h) in ((6, 7), (9, 9), (11, 6)):
            for k in range(h):
                c.put(x, H - 2 - k, dark if k % 2 else mid)
                if k % 3 == 2:
                    c.put(x - 1, H - 2 - k, mid)
                    c.put(x + 1, H - 3 - k, light)
        shadow_band(c, 4, 12, H - 1, leaf)
        return c
    stems = [(6, 14), (11, 18), (17, 15), (24, 19)] if stage == 1 else [(6, 18), (11, 24), (16, 20), (21, 26), (26, 22)]
    for i, (x, h) in enumerate(stems):
        for k in range(h):
            c.put(x, H - 2 - k, dark if k % 2 else mid)
            if (k + i * 3) % 5 in (1, 2) and k % 2 and k < h - 4:  # ragged lobed leaves, staggered per stem
                c.put(x - 1, H - 2 - k, mid)
                c.put(x - 2, H - 2 - k, dark)
                c.put(x - 2, H - 3 - k, mid)
                c.put(x + 1, H - 3 - k, light)
                c.put(x + 2, H - 3 - k, mid)
        if stage == 2 or i % 2 == 1:  # yellow heads: a 3-px bar with a darker eye
            ty = H - 2 - h
            c.rect(x - 1, ty, x + 1, ty, yel)
            c.put(x, ty - 1, yel)
            c.put(x + 1, ty, yel_dark)
    shadow_band(c, 3, W - 4, H - 1, leaf)
    outline_pass(c, leaf, None, skip={dark, mid})
    return c


# --- Shrub: rebar ivy ------------------------------------------------------------------------

def rebar_ivy(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = CON_LEAF
    shadow, dark, mid, light = leaf[1], leaf[2], leaf[3], leaf[4]
    o, r_dark, r_mid, r_light = REBAR
    hv, hv_dark = HIVIS

    def heart(x, y, tone, lit):
        c.stamp(x, y, B3, shadow)
        c.put(x - 1, y - 1, tone)
        c.put(x + 1, y - 1, tone)
        c.put(x, y, tone)
        c.put(x - 1, y - 1, lit)

    def rod(x0, y_bottom, y_top, bend_at, bend_dx):
        # a bent rebar rod: vertical, then kinked toward bend_dx above bend_at
        for y in range(y_bottom, y_top - 1, -1):
            x = x0 + (bend_dx * (bend_at - y) // max(1, bend_at - y_top) if y < bend_at else 0)
            c.put(x, y, r_mid)
            c.put(x + 1, y, r_dark)
            if (y * 3) % 7 == 0:
                c.put(x, y, r_light)   # ribbed highlight
        return x0 + bend_dx

    if stage == 0:  # 16 x 16: a rod stub with one climbing leaf
        rod(8, H - 2, 4, 7, 1)
        heart(6, H - 6, mid, light)
        c.put(8, 5, hv)
        c.put(9, 5, hv)
        shadow_band(c, 5, 11, H - 1, leaf)
        return c
    if stage == 1:  # 16 x 40: a taller rod, vines halfway up
        top = 6
        tip_x = rod(8, H - 2, top, 18, 2)
        c.rect(tip_x, top + 1, tip_x + 1, top + 2, hv)     # hi-vis tape near the tip
        c.put(tip_x + 1, top + 2, hv_dark)
        leaves = [(6, H - 6, mid, light), (10, H - 10, dark, mid), (5, H - 14, mid, light), (9, H - 18, mid, light)]
    else:  # 32 x 56: two rods, one bent, vines climbing most of the way
        top = 6
        rod(11, H - 2, top + 8, 24, -3)
        tip_x = rod(20, H - 2, top, 22, 3)
        c.rect(tip_x, top + 1, tip_x + 1, top + 2, hv)
        c.put(tip_x + 1, top + 2, hv_dark)
        c.rect(9, top + 10, 10, top + 11, hv)
        leaves = [(9, H - 6, mid, light), (13, H - 10, dark, mid), (18, H - 8, mid, light), (22, H - 14, dark, mid),
                  (10, H - 18, mid, light), (19, H - 22, mid, light), (14, H - 26, dark, mid), (21, H - 32, mid, light),
                  (8, H - 30, mid, light), (17, H - 38, mid, leaf[5])]
    # the vine: a dark 1-px stem winding up between the leaves
    prev = None
    for (x, y, tone, lit) in sorted(leaves, key=lambda l: -l[1]):
        if prev is not None:
            branch(c, prev[0], prev[1], x, y + 2, 1, 1, [o, dark, dark, dark])
        prev = (x, y)
    for (x, y, tone, lit) in leaves:
        heart(x, y, tone, lit)
    shadow_band(c, 4, W - 5, H - 1, leaf)
    return c


# --- Grass: horsetail ------------------------------------------------------------------------

def horsetail(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = CON_LEAF
    shadow, dark, mid, light = leaf[1], leaf[2], leaf[3], leaf[4]
    stems = [(5, 4), (9, 5), (12, 3)] if stage == 0 else ([(3, 8), (7, 11), (11, 9), (14, 6)] if stage == 1 else [(2, 10), (5, 13), (8, 11), (11, 14), (14, 9)])
    for i, (x, h) in enumerate(stems):
        for k in range(h):
            y = H - 2 - k
            joint = k % 3 == 2
            c.put(x, y, dark if joint else (mid if i % 2 else light))
            c.put(x + 1, y, shadow if joint else dark)
            if joint and stage > 0:  # whorls of 1-px needles at each joint
                c.put(x - 1, y, mid)
                c.put(x + 2, y, dark)
        c.put(x, H - 2 - h, shadow)  # the cone tip
        c.put(x + 1, H - 2 - h, shadow)
    shadow_band(c, 1, W - 2, H - 1, leaf)
    return c


# --- Grass: moss on rubble ------------------------------------------------------------------

def moss(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = CON_LEAF
    shadow, dark, mid, light, glint = leaf[1], leaf[2], leaf[3], leaf[4], leaf[5]
    o, r_dark, r_mid, r_light = RUBBLE
    # a grey stone lump (bevel: light top-left, dark bottom-right)
    if stage == 0:
        lump = [(4, H - 2, 11, H - 2), (5, H - 3, 10, H - 3), (6, H - 4, 8, H - 4)]
    else:
        lump = [(2, H - 2, 13, H - 2), (3, H - 3, 12, H - 3), (4, H - 4, 11, H - 4), (5, H - 5, 9, H - 5), (6, H - 6, 8, H - 6)]
    for (x0, y, x1, _) in lump:
        c.rect(x0, y, x1, y, r_mid)
        c.put(x0, y, r_light)
        c.put(x1, y, r_dark)
    c.put(lump[-1][0], lump[-1][1], r_light)
    # the moss pad: a low green cap over the top-left of the lump, thickening with the stage
    pads = [(6, H - 5, B2), (8, H - 5, B2)] if stage == 0 else \
        ([(5, H - 7, B3), (8, H - 7, B3), (7, H - 6, B2)] if stage == 1 else
         [(4, H - 7, B4), (8, H - 8, B4), (11, H - 6, B3), (6, H - 9, B2)])
    for (x, y, br) in pads:
        c.stamp(x, y, br, dark)
        c.stamp(x - 1, y - 1, B2, mid)
        c.put(x - 1, y - 1, light)
    if stage == 2:
        c.put(5, H - 10, glint)
        c.put(8, H - 10, glint)
    for x in range(lump[0][0] - 1, lump[0][2] + 2):   # tinted outline on the slab row
        c.put(x, H - 1, o)
    return c


def _pin_tree(stage, H):
    return 2 if stage == 0 else int(H * 0.3)


def _pin_shrub(stage, H):
    return 3 if stage == 0 else 4


def _pin_rod(stage, H):
    return 4 if stage == 0 else int(H * 0.4)


def _pin_grass(stage, H):
    return 2 if stage == 0 else 3


def _pin_static(stage, H):
    return H  # a stone does not sway


SPECIES = {
    "con_willow": {
        "name": "Willow", "slot": "tree", "draw": willow, "pin": _pin_tree,
        "stages": [(2, 4), (6, 12), (10, 22)],
        "seed": {"kind": "samara", "tint": (200, 196, 150), "name": "Willow Catkin"},
        "desc": "A willow sprout. Grows where the site flooded: a weeping mass of strands over a leaning trunk.",
    },
    "con_poplar": {
        "name": "Poplar", "slot": "tree", "draw": poplar, "pin": _pin_tree,
        "stages": [(2, 4), (4, 10), (6, 20)],
        "seed": {"kind": "ball", "tint": (210, 206, 190), "name": "Poplar Fluff"},
        "desc": "A poplar whip. A narrow column whose leaves flicker light and dark in the wind.",
    },
    "con_elder": {
        "name": "Elder", "slot": "tree", "draw": elder, "pin": _pin_tree,
        "stages": [(2, 3), (4, 6), (6, 9)],
        "seed": {"kind": "pip", "tint": (60, 40, 70), "name": "Elderberry"},
        "desc": "An elder sprout. A shrubby small tree: cream flower plates, black berries.",
    },
    "con_ragwort": {
        "name": "Ragwort Clump", "slot": "shrub", "draw": ragwort, "pin": _pin_shrub,
        "stages": [(2, 2), (4, 3), (4, 4)],
        "desc": "Ragwort. Ragged upright stems with yellow heads - hand-harvest.",
    },
    "con_rebar_ivy": {
        "name": "Rebar Ivy", "slot": "shrub", "draw": rebar_ivy, "pin": _pin_rod,
        "stages": [(2, 2), (2, 5), (4, 7)],
        "desc": "Ivy climbing a bent rebar rod, hi-vis tape still on the tip - hand-harvest.",
    },
    "con_horsetail": {
        "name": "Horsetail", "slot": "grass", "draw": horsetail, "pin": _pin_grass,
        "stages": [(2, 1), (2, 2), (2, 2)],
        "desc": "Jointed horsetail stems in the wet rubble.",
    },
    "con_moss": {
        "name": "Moss on Rubble", "slot": "grass", "draw": moss, "pin": _pin_static,
        "stages": [(2, 1), (2, 2), (2, 2)],
        "desc": "A moss pad over a lump of broken concrete.",
    },
}
