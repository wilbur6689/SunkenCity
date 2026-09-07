"""Business district flora (docs/Flora/flora.md section 6.1).

Corporate landscaping: clipped, containerised, symmetric in construction but
lit and worn asymmetrically. Cooler blue-green ramp (steel-blue district
tint), grey-blue steel tubs and troughs, a pale yellow glint on the locust.
Seven species x three stages; every drawer returns the REST frame.
"""
import random

from common import (BARK, LEAF, B2, B3, B4, B5, Canvas, blob, branch, canopy, ellipse_fn,
                    mask_area, outline_pass, shadow_band, shift_ramp, trunk, tuft)

BUS_LEAF = shift_ramp(LEAF, hue_deg=14, sat=0.9, val=0.98)     # cooler, toward teal
LOCUST_LEAF = shift_ramp(LEAF, hue_deg=4, sat=0.85, val=1.0)
LOCUST_LEAF[5] = (214, 222, 150)                                # pale yellow glint
STEEL = [(30, 34, 40), (70, 78, 90), (104, 116, 132), (150, 166, 184)]  # outline, dark, mid, light
SEED_HEAD = ((214, 200, 160), (160, 146, 110))                  # fountain grass plumes
DISTRICT = "business"


def LEAF_OF(sid):
    return LOCUST_LEAF if sid == "bus_locust" else BUS_LEAF


# --- containers --------------------------------------------------------------------

def tub(c: Canvas, x0, y0, x1, y1, lip=True):
    """A square steel planter: box + bevel (light top/left, dark bottom/right),
    its own tinted outline, soil showing at the top."""
    o, dark, mid, light = STEEL
    c.rect(x0, y0, x1, y1, mid)
    c.rect(x0, y0, x1, y0, light)            # top edge lit
    c.rect(x0, y0, x0, y1, light)            # left edge lit
    c.rect(x1, y0, x1, y1, dark)             # right edge dark
    c.rect(x0, y1, x1, y1, dark)             # bottom edge dark
    if lip and y1 - y0 >= 6:
        c.rect(x0 + 1, y0 + 2, x1 - 1, y0 + 2, dark)   # a shadow line under the lip
    # outline
    for x in range(x0 - 1, x1 + 2):
        c.put(x, y0 - 1, o)
        c.put(x, y1 + 1, o)
    for y in range(y0 - 1, y1 + 2):
        c.put(x0 - 1, y, o)
        c.put(x1 + 1, y, o)
    # soil at the rim (dark, one row inside the lip)
    c.rect(x0 + 1, y0 + 1, x1 - 1, y0 + 1, (52, 40, 30))
    # a scuff cluster on the lower right (wear, asymmetric)
    if x1 - x0 >= 12:
        c.rect(x1 - 4, y1 - 2, x1 - 3, y1 - 1, dark)


def ground_shadow(c: Canvas, x0, x1, y, leaf):
    shadow_band(c, x0, x1, y, leaf)


# --- Large: columnar cypress -----------------------------------------------------------

def cypress(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = BUS_LEAF, BARK
    cx = W // 2 + 1
    if stage == 0:  # 16 x 32: an upright spike - stem with two narrow leaf blobs stacked
        for y in range(H - 2, 9, -1):
            c.put(cx, y, bark[2] if y > H - 9 else leaf[2])
        blob(c, cx - 1, 15, B4, leaf, rng, glint=False)
        blob(c, cx, 10, B3, leaf, rng, glint=True)
        blob(c, cx - 2, 20, B3, leaf, rng, glint=False)
        shadow_band(c, cx - 3, cx + 2, H - 1, leaf)
        c.put(cx, H - 1, leaf[0])
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        return c
    if stage == 1:  # 32 x 96: a young flame, three stacked narrow masses
        tb, tt = H - 2, H - 10
        trunk(c, cx, tb, tt, 3, 2, bark)
        masses = [(cx, int(H * 0.70), 8, 20), (cx, int(H * 0.44), 8, 22), (cx - 1, int(H * 0.19), 5, 16)]
        canopy(c, masses, leaf, rng, step=2, density=(1.0, 0.9, 0.75), glint_frac=0.25)
        tuft(c, cx, H - 1, 4, leaf, rng)
    else:  # 48 x 192: tall narrow flame, one continuous highlight column up the left
        tb, tt = H - 2, H - 16
        trunk(c, cx, tb, tt, 5, 4, bark)
        masses = [
            (cx, int(H * 0.78), 12, 28),
            (cx, int(H * 0.58), 13, 30),
            (cx - 1, int(H * 0.38), 11, 28),
            (cx - 1, int(H * 0.20), 8, 22),
            (cx - 2, int(H * 0.07), 4, 12),
        ]
        canopy(c, masses, leaf, rng, step=3, density=(1.0, 0.9, 0.75), glint_frac=0.25)
        tuft(c, cx, H - 1, 6, leaf, rng, blades=4)
    outline_pass(c, leaf, bark)
    return c


# --- Medium: honey locust ----------------------------------------------------------------

def locust(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = LOCUST_LEAF, BARK
    cx = W // 2
    if stage == 0:  # 16 x 32: a whip with two feathery leaflets
        for y in range(H - 2, 8, -1):
            t = (H - 2 - y) / (H - 10)
            c.put(cx + int(round(-t)), y, bark[2] if y > H - 10 else leaf[2])
        for (lx, ly) in ((cx - 4, 13), (cx + 3, 10), (cx - 3, 19)):
            c.stamp(lx, ly, B3, leaf[1])
            c.put(lx - 1, ly - 1, leaf[3])
            c.put(lx, ly - 1, leaf[3])
            c.put(lx - 1, ly, leaf[4])
        shadow_band(c, cx - 3, cx + 2, H - 1, leaf)
        c.put(cx, H - 1, leaf[0])
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        return c
    if stage == 1:  # 48 x 72: an airy crown you can see the trunk through
        tb, tt = H - 2, int(H * 0.40)
        masses = [(cx + 6, int(H * 0.38), 12, 11), (cx - 7, int(H * 0.44), 11, 10), (cx - 1, int(H * 0.22), 10, 8)]
        canopy(c, masses, leaf, rng, step=1, density=(0.8, 0.65, 0.5), teeth=True)
        trunk(c, cx, tb, tt, 4, 2, bark, kink=1)
        branch(c, cx, tt + 6, cx - 8, tt - 4, 2, 1, bark)
        branch(c, cx, tt + 4, cx + 7, tt - 2, 2, 1, bark)
        tuft(c, cx, H - 1, 5, leaf, rng)
    else:  # 64 x 128: feathered crown of small clusters, trunk and limbs showing
        tb, tt = H - 2, int(H * 0.40)
        masses = [
            (cx + 13, int(H * 0.36), 15, 13),
            (cx - 14, int(H * 0.42), 14, 12),
            (cx + 2, int(H * 0.20), 14, 11),
            (cx - 3, int(H * 0.33), 16, 12),
        ]
        canopy(c, masses, leaf, rng, step=2, density=(0.8, 0.65, 0.5), teeth=True)
        trunk(c, cx, tb, tt, 6, 3, bark, kink=2)
        branch(c, cx + 1, tt + 10, cx - 15, tt - 6, 3, 1, bark)
        branch(c, cx + 1, tt + 6, cx + 14, tt - 8, 3, 1, bark)
        branch(c, cx + 2, tt + 2, cx + 3, tt - 12, 2, 1, bark)
        tuft(c, cx, H - 1, 7, leaf, rng, blades=4)
    outline_pass(c, leaf, bark)
    return c


# --- Small: ficus in a tub ---------------------------------------------------------------

def ficus(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = BUS_LEAF, BARK
    cx = W // 2
    if stage == 0:  # 16 x 24: a small tub with a sprout
        tub_top = H - 7
        for y in range(tub_top - 1, 7, -1):
            c.put(cx, y, bark[2] if y > tub_top - 5 else leaf[2])
        blob(c, cx - 3, 10, B4, leaf, rng, glint=True)
        blob(c, cx + 3, 12, B3, leaf, rng, glint=False)
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        tub(c, cx - 4, tub_top, cx + 3, H - 2, lip=False)
        return c
    if stage == 1:  # 32 x 48: a glossy young ball on a straight stem, in a tub
        tub_h = 10
        tub_top = H - 1 - tub_h
        tb, tt = tub_top - 1, int(H * 0.45)
        trunk(c, cx, tb, tt, 2, 2, bark, flare=False)
        masses = [(cx + 1, int(H * 0.30), 11, 10), (cx - 3, int(H * 0.24), 8, 7)]
        canopy(c, masses, leaf, rng, step=2, density=(1.0, 0.95, 0.8), teeth=False)
        outline_pass(c, leaf, bark)
        tub(c, cx - 7, tub_top, cx + 6, H - 2)
    else:  # 48 x 80: round glossy crown on a straight 3 px trunk over a square steel tub
        tub_h = 14
        tub_top = H - 1 - tub_h
        tb, tt = tub_top - 1, int(H * 0.42)
        trunk(c, cx, tb, tt, 3, 3, bark, flare=False)
        branch(c, cx, tt + 6, cx - 8, tt - 4, 2, 1, bark)
        branch(c, cx + 1, tt + 4, cx + 7, tt - 3, 2, 1, bark)
        masses = [(cx + 4, int(H * 0.30), 15, 13), (cx - 8, int(H * 0.34), 12, 11), (cx - 2, int(H * 0.20), 12, 9)]
        canopy(c, masses, leaf, rng, step=2, density=(1.0, 0.95, 0.85), teeth=False)
        outline_pass(c, leaf, bark)
        tub(c, cx - 10, tub_top, cx + 9, H - 2)
    return c


# --- Shrub: boxwood sphere ---------------------------------------------------------------

def box_sphere(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = BUS_LEAF, BARK
    if stage == 0:  # 16 x 16: clipped sprigs
        for (x, y, br) in ((6, 8, B3), (10, 7, B3), (8, 11, B2)):
            c.put(x, y + 2, bark[1])
            c.put(x, y + 3, bark[1])
            blob(c, x, y, br, leaf, rng, glint=False)
        shadow_band(c, 4, 12, H - 1, leaf)
        outline_pass(c, leaf, bark, skip=set(bark[1:]))
        return c
    if stage == 1:  # 32 x 24: a tight young ball
        masses = [(16, 12, 10, 9)]
    else:  # 32 x 32: the topiary sphere, smooth outline, a short visible stem
        masses = [(16, 14, 13, 12)]
        c.rect(15, H - 3, 16, H - 2, bark[1])
    canopy(c, masses, leaf, rng, step=2, density=(1.0, 0.95, 0.85), teeth=False, glint_frac=0.28)
    shadow_band(c, int(masses[0][0] - masses[0][2]) + 2, int(masses[0][0] + masses[0][2]) - 2, H - 1, leaf)
    outline_pass(c, leaf, bark)
    return c


# --- Shrub: boxwood cube in a trough -----------------------------------------------------

def _block_canopy(c: Canvas, x0, y0, x1, y1, leaf, rng, step=2):
    """A clipped rectangular hedge: shadow slab, then dark / mid / light strata
    as clusters in rects shrunk by `step` and pushed up-left; smooth edges."""
    shadow, tones = leaf[1], [leaf[2], leaf[3], leaf[4]]
    c.rect(x0, y0, x1, y1, shadow)
    for k, tone in enumerate(tones, start=1):
        rx0, ry0 = x0, y0                      # flush at the top-left
        rx1, ry1 = x1 - step * k, y1 - step * k
        if rx1 <= rx0 or ry1 <= ry0:
            break
        brush = B4 if (rx1 - rx0) > 10 else B3
        n = int((rx1 - rx0 + 1) * (ry1 - ry0 + 1) / mask_area(brush) * (1.6, 1.3, 1.0)[k - 1])
        clip = lambda px, py, a=x0, b=y0, d=x1, e=y1: a <= px <= d and b <= py <= e
        for _ in range(n):
            x = rng.randint(rx0, rx1)
            y = rng.randint(ry0, ry1)
            c.stamp(x, y, brush, tone, clip=clip)
    # glint: a few B2 on the top-left quarter
    for _ in range(max(1, (x1 - x0) // 8)):
        x = rng.randint(x0 + 1, x0 + (x1 - x0) // 3)
        y = rng.randint(y0 + 1, y0 + (y1 - y0) // 3)
        c.stamp(x, y, B2, leaf[5], clip=lambda px, py: c.get(px, py)[:3] in (leaf[3], leaf[4]))


def box_cube(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = BUS_LEAF, BARK
    if stage == 0:  # 16 x 16: a low trough with sprigs
        for (x, y, br) in ((5, 6, B3), (10, 5, B3)):
            c.put(x, y + 2, bark[1])
            blob(c, x, y, br, leaf, rng, glint=False)
        outline_pass(c, leaf, bark, skip=set(bark[1:]))
        tub(c, 2, H - 6, 13, H - 2, lip=False)
        return c
    if stage == 1:  # 32 x 24: a young block, not yet square, in a trough
        trough = (3, H - 7, 28, H - 2)
        _block_canopy(c, 6, 6, 25, H - 8, leaf, rng)
        c.put(8, 5, leaf[1]); c.put(9, 5, leaf[1]); c.put(18, 5, leaf[1])  # not yet clipped flat
        outline_pass(c, leaf, bark)
        tub(c, *trough, lip=False)
    else:  # 48 x 24: the squared hedge on a steel trough
        trough = (3, H - 7, 44, H - 2)
        _block_canopy(c, 5, 3, 42, H - 8, leaf, rng)
        outline_pass(c, leaf, bark)
        tub(c, *trough, lip=False)
    return c


# --- Grass: turf strip -------------------------------------------------------------------

def turf(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = BUS_LEAF
    dark, mid, light = leaf[2], leaf[3], leaf[4]
    if stage == 0:  # 16 x 8: sprouts
        for x, h in ((3, 2), (7, 2), (10, 3), (13, 2)):
            for k in range(h):
                c.put(x, H - 2 - k, mid if k < h - 1 else light)
        shadow_band(c, 2, 13, H - 1, leaf)
        return c
    top = 5 if stage == 2 else 3     # mown flat
    for i, x in enumerate(range(1, W - 1)):
        if (x * 5) % 3 == 0:
            continue                  # a few gaps so it is not a solid slab
        col = (dark, mid, mid, light)[(x * 3 + i) % 4]
        h = top if (x % 4) else top - 1
        for k in range(h):
            c.put(x, H - 2 - k, col if k < h - 1 else light)
    shadow_band(c, 0, W - 1, H - 1, leaf)
    return c


# --- Grass: fountain grass ---------------------------------------------------------------

def fountain(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = BUS_LEAF
    dark, mid, light = leaf[2], leaf[3], leaf[4]
    head, head_dark = SEED_HEAD
    if stage == 0:  # 16 x 8: a few arcing sprouts
        for x, h in ((5, 3), (9, 3), (12, 2)):
            for k in range(h):
                c.put(x - (1 if k == h - 1 else 0), H - 2 - k, mid if k < h - 1 else light)
        shadow_band(c, 3, 13, H - 1, leaf)
        return c
    cx = 8
    blades = [(-3, 8), (-1, 11), (1, 12), (3, 10), (5, 7), (0, 6)] if stage == 2 else [(-2, 6), (0, 8), (2, 7), (4, 5)]
    for i, (dx, h) in enumerate(blades):
        col = (dark, mid, light)[i % 3]
        x = cx + dx
        for k in range(h):
            # arc: straight up, then leaning over left by 2 px near the tip
            lean = 0 if k < h - 3 else (1 if k < h - 1 else 2)
            c.put(x - lean, H - 2 - k, col)
        if stage == 2 and i in (1, 2, 4):
            c.put(x - 2, H - 2 - h, head)
            c.put(x - 3, H - 2 - h, head)
            c.put(x - 3, H - 1 - h, head_dark)
    shadow_band(c, 2, W - 3, H - 1, leaf)
    return c


def _pin_tree(stage, H):
    return 2 if stage == 0 else int(H * 0.3)


def _pin_ficus(stage, H):
    return 7 if stage == 0 else (12 if H <= 48 else 18)


def _pin_shrub(stage, H):
    return 3 if stage == 0 else 5


def _pin_grass(stage, H):
    return 2 if stage == 0 else 3


SPECIES = {
    "bus_cypress": {
        "name": "Columnar Cypress", "slot": "tree", "draw": cypress, "pin": _pin_tree,
        "stages": [(2, 4), (4, 12), (6, 24)],
        "seed": {"kind": "ball", "tint": (128, 112, 84), "name": "Cypress Cone"},
        "desc": "A cypress spike. Grows into the tall narrow flame that lines the office plazas.",
    },
    "bus_locust": {
        "name": "Honey Locust", "slot": "tree", "draw": locust, "pin": _pin_tree,
        "stages": [(2, 4), (6, 9), (8, 16)],
        "seed": {"kind": "pip", "tint": (96, 60, 36), "name": "Locust Pod"},
        "desc": "A locust whip. An airy feathered crown you can see the trunk through when grown.",
    },
    "bus_ficus": {
        "name": "Tub Ficus", "slot": "tree", "draw": ficus, "pin": _pin_ficus,
        "stages": [(2, 3), (4, 6), (6, 10)],
        "seed": {"kind": "ball", "tint": (120, 70, 90), "name": "Fig Seed"},
        "desc": "A ficus sprout in a steel tub. Lobby greenery: a glossy round crown on a straight stem.",
    },
    "bus_box_sphere": {
        "name": "Boxwood Sphere", "slot": "shrub", "draw": box_sphere, "pin": _pin_shrub,
        "stages": [(2, 2), (4, 3), (4, 4)],
        "desc": "Boxwood sprigs. Clipped into a tight topiary ball - hand-harvest wood.",
    },
    "bus_box_cube": {
        "name": "Boxwood Trough", "slot": "shrub", "draw": box_cube, "pin": _pin_shrub,
        "stages": [(2, 2), (4, 3), (6, 3)],
        "desc": "Boxwood in a steel trough. Squares off into a plaza hedge - hand-harvest wood.",
    },
    "bus_turf": {
        "name": "Turf Strip", "slot": "grass", "draw": turf, "pin": _pin_grass,
        "stages": [(2, 1), (2, 2), (2, 2)],
        "desc": "Mown turf. Even, short, corporate.",
    },
    "bus_fountain_grass": {
        "name": "Fountain Grass", "slot": "grass", "draw": fountain, "pin": _pin_grass,
        "stages": [(2, 1), (2, 2), (2, 2)],
        "desc": "Ornamental fountain grass. Arcing blades with pale seed plumes when grown.",
    },
}
