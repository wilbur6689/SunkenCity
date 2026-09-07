"""Industrial district flora (docs/Flora/flora.md section 6.1).

Nothing was planted here - this is what grows where nobody stops it.
Desaturated dusty olive greens (rust-orange district tint), brown-grey and
rust accents, gangly sparse forms with the wood showing. Seven species x
three stages; every drawer returns the REST frame.
"""
import math
import random

from civ import BIRCH_BARK, birch_trunk
from common import (BARK, LEAF, B2, B3, B4, B5, Canvas, blob, branch, canopy, outline_pass,
                    seedling, shadow_band, shift_ramp, trunk, tuft)

IND_LEAF = shift_ramp(LEAF, hue_deg=-14, sat=0.62, val=0.92)        # dusty olive
IND_LEAF[5] = (176, 190, 120)                                        # a dry, muted glint
RUST = ((150, 72, 36), (98, 44, 22))                                  # seed clusters / cone tips
BERRY = ((44, 30, 52), (90, 60, 110))                                 # bramble: dark berry, a lit one
DUSTY_PURPLE = ((132, 96, 150), (168, 132, 186), (90, 62, 108))       # buddleia spikes
THISTLE = ((150, 100, 176), (196, 160, 210))
CRACK = (40, 40, 44)
DISTRICT = "industrial"


def LEAF_OF(sid):
    return IND_LEAF


# --- Large: tree of heaven -----------------------------------------------------------------

def ailanthus(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = IND_LEAF, BARK
    if stage == 0:
        seedling(c, W, H, rng, leaf, bark, leaves=3, lean=1, accent=RUST)
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        return c
    cx = W // 2 + 1
    rust, rust_dark = RUST
    if stage == 1:  # 48 x 96: gangly - sparse clusters on a visible trunk
        tb, tt = H - 2, int(H * 0.18)
        masses = [(cx + 9, int(H * 0.40), 9, 7), (cx - 9, int(H * 0.30), 9, 7), (cx + 3, int(H * 0.16), 8, 6), (cx - 7, int(H * 0.52), 7, 5)]
        canopy(c, masses, leaf, rng, step=1, density=(0.75, 0.6, 0.45))
        trunk(c, cx, tb, tt, 4, 2, bark, kink=2)
        branch(c, cx, int(H * 0.44), cx + 9, int(H * 0.40), 2, 1, bark)
        branch(c, cx + 1, int(H * 0.34), cx - 9, int(H * 0.31), 2, 1, bark)
        branch(c, cx + 1, int(H * 0.56), cx - 7, int(H * 0.53), 2, 1, bark)
        seeds = [(cx + 10, int(H * 0.44)), (cx - 6, int(H * 0.34))]
    else:  # 64 x 192: tall, gangly, sparse layered clusters, trunk visible most of the way
        tb, tt = H - 2, int(H * 0.12)
        masses = [
            (cx + 12, int(H * 0.40), 12, 8),
            (cx - 13, int(H * 0.30), 12, 8),
            (cx + 9, int(H * 0.20), 10, 7),
            (cx - 6, int(H * 0.12), 10, 7),
            (cx - 11, int(H * 0.52), 9, 6),
            (cx + 14, int(H * 0.58), 8, 5),
        ]
        canopy(c, masses, leaf, rng, step=1, density=(0.75, 0.6, 0.45))
        trunk(c, cx, tb, tt, 6, 3, bark, kink=3)
        branch(c, cx + 1, int(H * 0.44), cx + 13, int(H * 0.40), 3, 1, bark)
        branch(c, cx + 1, int(H * 0.34), cx - 13, int(H * 0.30), 3, 1, bark)
        branch(c, cx + 2, int(H * 0.24), cx + 9, int(H * 0.20), 2, 1, bark)
        branch(c, cx + 2, int(H * 0.55), cx - 11, int(H * 0.52), 2, 1, bark)
        branch(c, cx + 1, int(H * 0.61), cx + 14, int(H * 0.58), 2, 1, bark)
        seeds = [(cx + 14, int(H * 0.45)), (cx - 10, int(H * 0.35)), (cx + 8, int(H * 0.25)), (cx - 12, int(H * 0.56))]
    for (sx, sy) in seeds:  # rust-brown seed clusters hanging under the leaf masses
        for (dx, dy) in ((0, 0), (1, 0), (0, 1), (2, 1), (1, 2)):
            c.put(sx + dx, sy + dy, rust)
        c.put(sx + 2, sy + 2, rust_dark)
        c.put(sx + 1, sy + 1, rust_dark)
    tuft(c, cx, H - 1, 5 if stage == 1 else 7, leaf, rng)
    outline_pass(c, leaf, bark)
    return c


# --- Medium: silver birch pioneer ------------------------------------------------------------

def birch(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = IND_LEAF, BIRCH_BARK
    cx = W // 2 + 2
    if stage == 0:  # 16 x 32: a leaning white whip
        for y in range(H - 2, 9, -1):
            t = (H - 2 - y) / (H - 12)
            c.put(cx - int(round(2 * t)), y, bark[2] if y > 16 else leaf[2])
        c.put(cx, H - 8, (60, 60, 58))
        blob(c, cx - 5, 12, B3, leaf, rng, glint=False)
        blob(c, cx + 1, 10, B3, leaf, rng, glint=False)
        shadow_band(c, cx - 3, cx + 2, H - 1, leaf)
        c.put(cx, H - 1, leaf[0])
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        return c
    if stage == 1:  # 32 x 72: thin, leaning, a small loose crown
        tb, tt = H - 2, int(H * 0.36)
        birch_trunk(c, cx, tb, tt, 3, 2, rng, kink=-4)
        branch(c, cx - 4, tt + 3, cx - 10, tt - 4, 2, 1, bark)
        masses = [(cx - 5, int(H * 0.26), 9, 8), (cx + 3, int(H * 0.34), 6, 5)]
        canopy(c, masses, leaf, rng, step=2, density=(0.85, 0.7, 0.55))
        tuft(c, cx, H - 1, 4, leaf, rng)
    else:  # 48 x 128: the pioneer - tall, thin, leaning into the wind, crown small for its height
        tb, tt = H - 2, int(H * 0.30)
        birch_trunk(c, cx, tb, tt, 4, 2, rng, kink=-7)
        branch(c, cx - 7, tt + 4, cx - 16, tt - 6, 2, 1, bark)
        branch(c, cx - 6, tt + 2, cx + 4, tt - 5, 2, 1, bark)
        masses = [(cx - 8, int(H * 0.22), 12, 10), (cx + 3, int(H * 0.30), 8, 7), (cx - 14, int(H * 0.32), 7, 6)]
        canopy(c, masses, leaf, rng, step=2, density=(0.85, 0.7, 0.55))
        tuft(c, cx, H - 1, 5, leaf, rng)
    outline_pass(c, leaf, bark)
    return c


# --- Small: sumac thicket ----------------------------------------------------------------------

def sumac(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = IND_LEAF, BARK
    rust, rust_dark = RUST
    cx = W // 2
    if stage == 0:  # 16 x 24: two stems from one root, a cone tip on one
        for (sx, lean) in ((cx - 1, -1), (cx + 1, 1)):
            for y in range(H - 2, 8, -1):
                t = (H - 2 - y) / (H - 10)
                c.put(sx + int(round(lean * 2 * t)), y, bark[2] if y > H - 8 else leaf[2])
        blob(c, cx - 4, 11, B3, leaf, rng, glint=False)
        blob(c, cx + 4, 12, B3, leaf, rng, glint=False)
        c.put(cx - 3, 8, rust)
        c.put(cx - 3, 9, rust)
        c.put(cx - 2, 9, rust_dark)
        shadow_band(c, cx - 4, cx + 4, H - 1, leaf)
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        return c
    if stage == 1:  # 32 x 48: three stems fanning out, a small mass on each
        stems = [(cx - 1, cx - 9, int(H * 0.42)), (cx, cx + 1, int(H * 0.34)), (cx + 1, cx + 8, int(H * 0.46))]
        masses = [(cx - 9, int(H * 0.38), 8, 7), (cx + 1, int(H * 0.28), 9, 8), (cx + 8, int(H * 0.42), 8, 7)]
    else:  # 48 x 80: the thicket - five stems from one root
        stems = [(cx - 2, cx - 16, int(H * 0.46)), (cx - 1, cx - 7, int(H * 0.36)), (cx, cx + 1, int(H * 0.30)),
                 (cx + 1, cx + 8, int(H * 0.38)), (cx + 2, cx + 15, int(H * 0.50))]
        masses = [(cx - 16, int(H * 0.42), 9, 8), (cx - 7, int(H * 0.32), 10, 9), (cx + 1, int(H * 0.26), 11, 9),
                  (cx + 8, int(H * 0.34), 10, 8), (cx + 15, int(H * 0.46), 9, 8)]
    for (x0, x1, y1) in stems:
        branch(c, x0, H - 2, x1, y1, 2, 1, bark)
    canopy(c, masses, leaf, rng, step=1, density=(0.85, 0.7, 0.55))
    for (mx, my, rx, ry) in masses:  # a red-brown cone standing on each mass
        tx = int(mx) - 1
        ty = int(my - ry) - 1
        for dy in range(3):
            c.put(tx, ty + dy, rust)
            c.put(tx + 1, ty + dy, rust if dy < 2 else rust_dark)
        c.put(tx + 1, ty + 1, rust_dark)
    tuft(c, cx, H - 1, 4 if stage == 1 else 6, leaf, rng)
    outline_pass(c, leaf, bark)
    return c


# --- Shrub: bramble --------------------------------------------------------------------------

def arc_stem(c: Canvas, x0, y0, x1, peak, bark, tone_idx=1):
    """An arching 1-px cane from (x0, y0) up over `peak` rows and down to x1."""
    n = abs(x1 - x0)
    pts = []
    for i in range(n + 1):
        t = i / max(1, n)
        x = x0 + (i if x1 > x0 else -i)
        y = int(round(y0 - peak * math.sin(math.pi * t)))
        c.put(x, y, bark[tone_idx])
        pts.append((x, y))
    return pts


def bramble(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = IND_LEAF, BARK
    berry, berry_lit = BERRY
    if stage == 0:  # 16 x 16: one arching cane, two leaves
        arc_stem(c, 2, H - 2, 13, 8, bark)
        blob(c, 6, 7, B3, leaf, rng, glint=False)
        blob(c, 11, 9, B3, leaf, rng, glint=False)
        c.put(9, 6, berry)
        shadow_band(c, 1, 14, H - 1, leaf)
        outline_pass(c, leaf, bark, skip=set(bark[1:]))
        return c
    canes = [(2, W - 6, 11), (W - 3, 4, 9), (6, W - 2, 7)] if stage == 1 else \
        [(2, W - 8, H - 6), (W - 3, 6, H - 9), (8, W - 2, H - 12), (W - 10, 2, H - 14), (4, W - 12, H - 16)]
    pts = []
    for (x0, x1, peak) in canes:
        pts += arc_stem(c, x0, H - 2, x1, peak, bark)
    # sparse leaves hanging off the canes (never floating), never a solid mass
    n_leaves = 5 if stage == 1 else 10
    for i in range(n_leaves):
        (x, y) = pts[rng.randrange(len(pts))]
        blob(c, x + rng.choice((-1, 1)), y + 1, B3 if i % 3 else B4, leaf, rng, glint=False)
    # dark berries in pairs, on the canes
    for i in range(2 if stage == 1 else 5):
        (x, y) = pts[rng.randrange(len(pts))]
        c.put(x, y + 1, berry)
        c.put(x + 1, y + 1, berry)
        c.put(x, y + 2, berry_lit if i % 2 else berry)
    shadow_band(c, 1, W - 2, H - 1, leaf)
    outline_pass(c, leaf, bark, skip=set(bark[1:]))
    return c


# --- Shrub: buddleia ---------------------------------------------------------------------------

def buddleia(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = IND_LEAF, BARK
    pur, pur_light, pur_dark = DUSTY_PURPLE
    cx = W // 2
    if stage == 0:  # 16 x 16: a sprig with one small spike
        c.rect(8, 6, 8, H - 2, bark[1])
        blob(c, 5, 9, B3, leaf, rng, glint=False)
        blob(c, 11, 10, B3, leaf, rng, glint=False)
        for dy in range(3):
            c.put(8, 3 + dy, pur if dy else pur_light)
        c.put(9, 5, pur_dark)
        shadow_band(c, 4, 12, H - 1, leaf)
        outline_pass(c, leaf, bark, skip=set(bark[1:]))
        return c
    # a ragged spray: stems fanning from the base, a loose mass, spikes at the tips
    if stage == 1:  # 32 x 24
        tips = [(cx - 9, 6), (cx - 2, 3), (cx + 6, 5), (cx + 11, 9)]
        masses = [(cx - 4, 14, 10, 7), (cx + 6, 15, 8, 6)]
    else:  # 48 x 40
        tips = [(cx - 17, 12), (cx - 10, 6), (cx - 2, 3), (cx + 6, 5), (cx + 13, 9), (cx + 19, 15)]
        masses = [(cx - 8, 26, 13, 9), (cx + 8, 27, 12, 9), (cx, 18, 10, 7)]
    for (tx, ty) in tips:
        branch(c, cx, H - 2, tx, ty + 4, 2, 1, bark)
    canopy(c, masses, leaf, rng, step=1, density=(0.8, 0.65, 0.5))
    for (tx, ty) in tips:  # dusty purple spikes: 1 px wide, 4-5 tall, lit at the top
        for dy in range(5):
            c.put(tx, ty + dy, pur_light if dy == 0 else pur)
            if dy in (1, 3):
                c.put(tx + 1, ty + dy, pur_dark)
                c.put(tx - 1, ty + dy + 1, pur)
    shadow_band(c, int(masses[0][0] - masses[0][2]) + 1, int(masses[-2 if stage == 2 else -1][0] + masses[-2 if stage == 2 else -1][2]) - 1, H - 1, leaf)
    outline_pass(c, leaf, bark, skip=set(bark[1:]))
    return c


# --- Grass: thistle --------------------------------------------------------------------------

def thistle(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = IND_LEAF
    shadow, dark, mid, light = leaf[1], leaf[2], leaf[3], leaf[4]
    head, head_light = THISTLE
    if stage == 0:  # 16 x 8: two spiky sprouts
        for x in (5, 10):
            c.put(x, H - 2, dark)
            c.put(x, H - 3, mid)
            c.put(x - 1, H - 3, dark)
            c.put(x + 1, H - 3, dark)
            c.put(x, H - 4, light)
        shadow_band(c, 3, 12, H - 1, leaf)
        return c
    stems = [(7, 10), (11, 7)] if stage == 1 else [(6, 12), (10, 9), (13, 6)]
    for (x, h) in stems:
        for k in range(h):
            c.put(x, H - 2 - k, dark if k % 2 else mid)
            if k % 3 == 1 and k < h - 2:  # spiny leaves both sides
                c.put(x - 1, H - 2 - k, mid)
                c.put(x - 2, H - 3 - k, dark)
                c.put(x + 1, H - 2 - k, dark)
        if stage == 2:  # the head: a spiky cup with a purple crown
            ty = H - 2 - h
            c.put(x, ty, shadow)
            c.put(x - 1, ty, shadow)
            c.put(x + 1, ty, shadow)
            c.put(x, ty - 1, head)
            c.put(x - 1, ty - 1, head)
            c.put(x + 1, ty - 1, head)
            c.put(x, ty - 2, head_light)
    shadow_band(c, 3, W - 3, H - 1, leaf)
    return c


# --- Grass: cracked-concrete weeds ----------------------------------------------------------

def weeds(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = IND_LEAF
    dark, mid, light = leaf[2], leaf[3], leaf[4]
    # a 1-px dark crack across the slab row, the weeds sprouting from it
    crack = [(x, H - 1 + (0 if x % 4 else -1)) for x in range(1, W - 1)] if stage else [(x, H - 1) for x in range(4, 12)]
    for (x, y) in crack:
        c.put(x, y, CRACK)
    if stage == 0:
        for x, h in ((6, 2), (9, 3)):
            for k in range(h):
                c.put(x - (1 if k == h - 1 else 0), H - 2 - k, mid if k < h - 1 else light)
        return c
    blades = [(3, 5), (5, 8), (9, 6), (12, 9)] if stage == 1 else [(2, 6), (4, 9), (7, 5), (10, 11), (13, 7)]
    for i, (x, h) in enumerate(blades):
        col = (dark, mid)[i % 2]
        for k in range(h):
            bend = 1 if k >= h - 2 else 0
            c.put(x - bend, H - 2 - k, col if k < h - 1 else light)
    if stage == 2:  # a seed head gone to fluff
        c.stamp(9, H - 13, B2, (196, 190, 170))
    return c


def _pin_tree(stage, H):
    return 2 if stage == 0 else int(H * 0.3)


def _pin_shrub(stage, H):
    return 3 if stage == 0 else 4


def _pin_grass(stage, H):
    return 2 if stage == 0 else 3


SPECIES = {
    "ind_ailanthus": {
        "name": "Tree of Heaven", "slot": "tree", "draw": ailanthus, "pin": _pin_tree,
        "stages": [(2, 4), (6, 12), (8, 24)],
        "seed": {"kind": "samara", "tint": (150, 72, 36), "name": "Ailanthus Key"},
        "desc": "A tree-of-heaven sprout. Grows tall and gangly with sparse leaf layers and rust seed clusters - the weed tree of the yards.",
    },
    "ind_birch": {
        "name": "Pioneer Birch", "slot": "tree", "draw": birch, "pin": _pin_tree,
        "stages": [(2, 4), (4, 9), (6, 16)],
        "seed": {"kind": "ball", "tint": (200, 190, 170), "name": "Birch Catkin"},
        "desc": "A birch whip leaning into the wind. Thin, white-barked, a small crown for its height.",
    },
    "ind_sumac": {
        "name": "Sumac Thicket", "slot": "tree", "draw": sumac, "pin": _pin_tree,
        "stages": [(2, 3), (4, 6), (6, 10)],
        "seed": {"kind": "pip", "tint": (150, 72, 36), "name": "Sumac Drupe"},
        "desc": "Sumac suckers. A multi-stemmed thicket with red-brown cone tips when grown.",
    },
    "ind_bramble": {
        "name": "Bramble", "slot": "shrub", "draw": bramble, "pin": _pin_shrub,
        "stages": [(2, 2), (4, 3), (6, 4)],
        "desc": "Bramble canes. Arching, thorny, sparse-leaved, dark berries - hand-harvest wood.",
    },
    "ind_buddleia": {
        "name": "Buddleia", "slot": "shrub", "draw": buddleia, "pin": _pin_shrub,
        "stages": [(2, 2), (4, 3), (6, 5)],
        "desc": "A buddleia sprig. A ragged spray with dusty purple spikes - hand-harvest wood.",
    },
    "ind_thistle": {
        "name": "Thistle", "slot": "grass", "draw": thistle, "pin": _pin_grass,
        "stages": [(2, 1), (2, 2), (2, 2)],
        "desc": "Spiny thistle with a purple crown.",
    },
    "ind_weeds": {
        "name": "Concrete Weeds", "slot": "grass", "draw": weeds, "pin": _pin_grass,
        "stages": [(2, 1), (2, 2), (2, 2)],
        "desc": "Weeds through a crack in the slab.",
    },
}
