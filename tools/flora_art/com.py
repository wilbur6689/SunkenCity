"""Commercial district flora (docs/Flora/flora.md section 6.1).

Showy, tropical, decorative - plants bought to be looked at. Warmer,
slightly yellow greens (neon-pink district tint), hot accents: magnolia and
bougainvillea pinks, hibiscus red, mixed planter-bed heads. Seven species x
three stages; every drawer returns the REST frame.
"""
import math
import random

from common import (BARK, LEAF, B2, B3, B4, B5, B6, Canvas, blob, branch, canopy, outline_pass,
                    seedling, shadow_band, shift, shift_ramp, trunk, tuft)

COM_LEAF = shift_ramp(LEAF, hue_deg=-12, sat=1.05, val=1.02)       # warm, yellow-leaning
MAG_LEAF = shift_ramp(LEAF, hue_deg=-4, sat=1.0, val=0.9)          # glossy, darker magnolia leaves
MAG_LEAF[5] = (196, 226, 150)                                       # sharp gloss glint
PALM_BARK = [BARK[0], (104, 82, 58), (150, 122, 84), (192, 166, 122)]
MAGENTA = ((214, 60, 150), (150, 30, 100), (240, 150, 210))         # bougainvillea: base, dark, light
MAG_BLOSSOM = ((236, 176, 206), (244, 236, 240))                    # magnolia: pink, white
HIBISCUS = ((204, 52, 64), (240, 200, 80))                          # red petals, yellow centre
BED_HEADS = ((226, 110, 160), (236, 200, 80), (240, 236, 224))      # pink, yellow, white
CONCRETE = [(38, 36, 34), (84, 82, 80), (114, 112, 110), (144, 142, 140)]
FRUIT = ((120, 78, 40), (80, 50, 26))
DISTRICT = "commercial"


def LEAF_OF(sid):
    return MAG_LEAF if sid == "com_magnolia" else COM_LEAF


# --- Large: fan palm ------------------------------------------------------------------------

def frond(c: Canvas, x0, y0, direction, length, rise, droop, w0, leaf, lit, pinnae=True):
    """One palm frond from (x0, y0): out `direction` (-1 left / +1 right), rising
    then drooping; base width w0 tapering to 1; jagged pinnae teeth along it."""
    shadow, dark, mid, light = leaf[1], leaf[2], leaf[3], leaf[4]
    core = light if lit else mid
    under = mid if lit else dark
    steps = max(length, 4)
    for i in range(steps + 1):
        t = i / steps
        x = int(round(x0 + direction * length * t))
        y = int(round(y0 - rise * math.sin(math.pi * min(t, 0.5)) + droop * t * t))
        w = max(1, int(round(w0 * (1 - 0.8 * t))))
        for k in range(w):
            c.put(x, y + k, core if k == 0 else (under if k < w - 1 else shadow))
        if pinnae and i % 2 == 0 and 0.15 < t < 0.95:
            c.put(x, y - 1, under)            # a leaflet up
            c.put(x, y + w, shadow)           # a leaflet down


def palm_trunk(c: Canvas, cx, y_bottom, y_top, w, bark, kink=0):
    trunk(c, cx, y_bottom, y_top, w, max(2, w - 1), bark, kink=kink, flare=True)
    # rings: a dark row then a light row every 4 rows (ringed trunk, flora.md 1.3)
    h = y_bottom - y_top
    for y in range(y_top + 3, y_bottom - 2, 4):
        t = (y_bottom - y) / max(1, h)
        x_c = cx + int(round(kink * t))
        ww = max(2, int(round(w + (max(2, w - 1) - w) * t)))
        for x in range(x_c - ww // 2, x_c - ww // 2 + ww):
            if c.get(x, y)[3]:
                c.put(x, y, bark[1])
            if c.get(x, y - 1)[3] and c.get(x, y - 1)[:3] != bark[3]:
                c.put(x, y - 1, bark[3] if x < x_c else bark[2])


def palm(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = COM_LEAF, PALM_BARK
    cx = W // 2
    if stage == 0:  # 16 x 32: a fan of three short fronds from a stub
        c.rect(cx, H - 6, cx, H - 2, bark[2])
        frond(c, cx, H - 6, -1, 6, 4, 2, 2, leaf, True, pinnae=False)
        frond(c, cx, H - 7, 1, 6, 5, 3, 2, leaf, False, pinnae=False)
        frond(c, cx, H - 7, -1, 3, 9, 0, 2, leaf, True, pinnae=False)
        shadow_band(c, cx - 3, cx + 3, H - 1, leaf)
        c.put(cx, H - 1, leaf[0])
        outline_pass(c, leaf, bark, skip=set(bark[1:]))
        return c
    if stage == 1:  # 32 x 80: a young palm - short ringed trunk, five fronds
        top = int(H * 0.42)
        palm_trunk(c, cx, H - 2, top, 4, bark, kink=1)
        cx2 = cx + 1
        frond(c, cx2, top, -1, 15, 7, 9, 3, leaf, True)
        frond(c, cx2, top, 1, 14, 6, 10, 3, leaf, False)
        frond(c, cx2 - 1, top - 1, -1, 11, 11, 3, 3, leaf, True)
        frond(c, cx2 + 1, top - 1, 1, 10, 11, 4, 3, leaf, False)
        frond(c, cx2, top - 2, -1, 4, 13, 0, 2, leaf, True)
        tuft(c, cx, H - 1, 4, leaf, rng)
    else:  # 64 x 160: ringed trunk, a crown of seven long fronds, a fruit cluster
        top = int(H * 0.36)
        palm_trunk(c, cx, H - 2, top, 7, bark, kink=3)
        cx2 = cx + 3
        frond(c, cx2, top + 2, -1, 29, 10, 22, 5, leaf, True)
        frond(c, cx2 + 1, top + 2, 1, 27, 9, 22, 5, leaf, False)
        frond(c, cx2 - 1, top - 1, -1, 26, 20, 10, 4, leaf, True)
        frond(c, cx2 + 2, top - 1, 1, 25, 19, 11, 4, leaf, False)
        frond(c, cx2 - 1, top - 3, -1, 16, 28, 3, 4, leaf, True)
        frond(c, cx2 + 1, top - 3, 1, 15, 27, 4, 4, leaf, False)
        frond(c, cx2, top - 4, 1, 4, 32, 0, 3, leaf, True)
        # fruit cluster hanging right of the crown
        fr, fr_dark = FRUIT
        for (dx, dy) in ((3, 6), (5, 7), (4, 9), (6, 9), (5, 11), (3, 8)):
            c.put(cx2 + dx, top + dy, fr)
            c.put(cx2 + dx + 1, top + dy + 1, fr_dark)
        tuft(c, cx, H - 1, 7, leaf, rng, blades=4)
    outline_pass(c, leaf, bark)
    return c


# --- Medium: magnolia ----------------------------------------------------------------------

def magnolia(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = MAG_LEAF, BARK
    pink, white = MAG_BLOSSOM
    if stage == 0:
        seedling(c, W, H, rng, leaf, bark, leaves=2, lean=1, accent=(pink,))
        c.put(W // 2 + 1, H // 3 - 1, white)
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        return c
    cx = W // 2
    if stage == 1:  # 48 x 72: loose crown, a few big blossoms
        tb, tt = H - 2, int(H * 0.50)
        branch(c, cx, tt + 4, cx - 9, tt - 8, 3, 1, bark)
        branch(c, cx, tt + 2, cx + 8, tt - 5, 3, 1, bark)
        trunk(c, cx, tb, tt, 4, 3, bark, kink=1)
        masses = [(cx + 6, int(H * 0.36), 12, 10), (cx - 7, int(H * 0.40), 11, 10), (cx, int(H * 0.24), 11, 9)]
        canopy(c, masses, leaf, rng, step=2, density=(0.95, 0.8, 0.65))
        big_blossoms(c, masses, rng, 4, pink, white)
        tuft(c, cx, H - 1, 5, leaf, rng)
    else:  # 64 x 128: broad loose crown, glossy dark leaves, large blossoms
        tb, tt = H - 2, int(H * 0.58)
        branch(c, cx, tt + 6, cx - 15, tt - 12, 4, 2, bark)
        branch(c, cx + 1, tt + 4, cx + 13, tt - 10, 4, 2, bark)
        branch(c, cx, tt, cx + 3, tt - 22, 3, 1, bark)
        trunk(c, cx, tb, tt, 6, 5, bark, kink=-1)
        masses = [
            (cx + 13, int(H * 0.40), 16, 13),
            (cx - 14, int(H * 0.44), 15, 13),
            (cx + 2, int(H * 0.24), 15, 11),
            (cx - 2, int(H * 0.36), 18, 13),
        ]
        canopy(c, masses, leaf, rng, step=3, density=(0.95, 0.8, 0.65))
        big_blossoms(c, masses, rng, 9, pink, white)
        tuft(c, cx, H - 1, 7, leaf, rng, blades=4)
    outline_pass(c, leaf, bark)
    return c


def big_blossoms(c: Canvas, masses, rng, n, pink, white):
    """3x3 plus blossoms with a white top-left petal, spread over the crown."""
    placed, tries = 0, 0
    while placed < n and tries < 120:
        tries += 1
        (mx, my, rx, ry) = masses[rng.randrange(len(masses))]
        x = int(mx + rng.uniform(-rx * 0.7, rx * 0.7))
        y = int(my + rng.uniform(-ry * 0.7, ry * 0.5))
        if not all(c.opaque(x + dx, y + dy) for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1))):
            continue
        if any(c.get(x + dx, y + dy)[:3] in (pink, white) for dx in range(-4, 5) for dy in range(-4, 5)):
            continue
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            c.put(x + dx, y + dy, pink)
        c.put(x - 1, y - 1, white)
        c.put(x, y - 1, white)
        placed += 1


# --- Small: bougainvillea on a frame -----------------------------------------------------

def bougainvillea(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = COM_LEAF, BARK
    mag, mag_dark, mag_light = MAGENTA
    cx = W // 2
    if stage == 0:  # 16 x 24: a stem tied to a post with a magenta tip
        c.rect(cx + 2, 6, cx + 2, H - 2, bark[1])            # the post
        for y in range(H - 2, 9, -1):
            c.put(cx + (1 if y < 14 else 0), y, leaf[2])
        blob(c, cx - 2, 13, B3, leaf, rng, glint=False)
        c.stamp(cx + 1, 8, B3, mag)
        c.put(cx, 7, mag_light)
        c.put(cx + 2, 9, mag_dark)
        shadow_band(c, cx - 3, cx + 4, H - 1, leaf)
        outline_pass(c, leaf, bark, skip=set(bark[1:]) | {leaf[2]})
        return c
    if stage == 1:  # 32 x 48: frame + a young mass starting to cascade
        posts = (cx - 8, cx + 8)
        bar_y = int(H * 0.62)
        for px in posts:
            c.rect(px, bar_y - 1, px, H - 2, bark[1])
        c.rect(posts[0], bar_y, posts[1], bar_y, bark[2])
        trunk(c, cx, H - 2, int(H * 0.5), 3, 2, bark, flare=False)
        masses = [(cx - 1, int(H * 0.36), 11, 9), (cx + 7, int(H * 0.54), 6, 7)]
        canopy(c, masses, leaf, rng, step=2, density=(0.9, 0.75, 0.6))
        magenta_tips(c, masses, rng, 0.55)
        tuft(c, cx, H - 1, 5, leaf, rng)
    else:  # 48 x 80: small tree with cascading side masses over a frame
        posts = (cx - 14, cx + 14)
        bar_y = int(H * 0.62)
        for px in posts:
            c.rect(px, bar_y - 1, px, H - 2, bark[1])
        c.rect(posts[0], bar_y, posts[1], bar_y, bark[2])
        c.rect(posts[0], bar_y + 1, posts[1], bar_y + 1, bark[1])
        trunk(c, cx, H - 2, int(H * 0.46), 4, 3, bark, kink=-1)
        masses = [
            (cx - 2, int(H * 0.30), 16, 10),         # crown
            (cx - 13, int(H * 0.56), 7, 11),         # left cascade, hanging over the frame
            (cx + 13, int(H * 0.52), 7, 10),         # right cascade
            (cx + 4, int(H * 0.38), 12, 8),          # front mass
        ]
        canopy(c, masses, leaf, rng, step=2, density=(0.9, 0.75, 0.6))
        magenta_tips(c, masses, rng, 0.6)
        tuft(c, cx, H - 1, 6, leaf, rng)
    outline_pass(c, leaf, bark)
    return c


def magenta_tips(c: Canvas, masses, rng, share):
    """The one accent-heavy species: magenta clusters over the OUTER rim of
    each mass (share = fraction of rim samples that flower), lighter pixel
    top-left, darker bottom-right - the same tiny-sphere rule as leaves."""
    mag, mag_dark, mag_light = MAGENTA
    for (mx, my, rx, ry) in masses:
        n = int((rx + ry) * 1.2)
        for _ in range(n):
            if rng.random() > share:
                continue
            a = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(0.6, 0.95)
            x = int(round(mx + rx * r * math.cos(a)))
            y = int(round(my + ry * r * math.sin(a)))
            if not c.opaque(x, y):
                continue
            c.stamp(x, y, B3, mag, clip=lambda px, py: c.opaque(px, py))
            if c.get(x - 1, y - 1)[3]:
                c.put(x - 1, y - 1, mag_light)
            if c.get(x + 1, y + 1)[3]:
                c.put(x + 1, y + 1, mag_dark)


# --- Shrub: hibiscus --------------------------------------------------------------------

def hibiscus(stage, W, H, rng):
    c = Canvas(W, H)
    leaf, bark = COM_LEAF, BARK
    red, yellow = HIBISCUS
    if stage == 0:  # 16 x 16: big-leaved sprig with one bud
        c.rect(8, 6, 8, H - 2, bark[1])
        blob(c, 5, 8, B4, leaf, rng, glint=False)
        blob(c, 11, 10, B4, leaf, rng, glint=False)
        c.stamp(8, 5, B2, red)
        c.put(8, 4, red)
        shadow_band(c, 4, 12, H - 1, leaf)
        outline_pass(c, leaf, bark, skip=set(bark[1:]))
        return c
    if stage == 1:  # 32 x 24
        masses = [(11, 12, 9, 8), (21, 11, 9, 8)]
        n = 2
    else:  # 32 x 32: a dome of big leaves
        masses = [(10, 19, 9, 9), (22, 18, 9, 9), (16, 11, 10, 8)]
        n = 3
        c.rect(15, H - 3, 16, H - 2, bark[1])
    canopy(c, masses, leaf, rng, step=2, density=(0.85, 0.7, 0.55))
    # big leaves: a few B5 clusters in mid with a light top-left, on the rim
    for (mx, my, rx, ry) in masses:
        for _ in range(2):
            x = int(mx + rng.uniform(-rx * 0.6, rx * 0.6))
            y = int(my + rng.uniform(-ry * 0.6, ry * 0.4))
            c.stamp(x, y, B5, leaf[3], clip=lambda px, py: c.opaque(px, py))
            c.put(x - 1, y - 1, leaf[4])
            c.put(x - 2, y - 1, leaf[4])
    flowers(c, masses, rng, n, red, yellow)
    shadow_band(c, int(masses[0][0] - masses[0][2]) + 1, int(masses[-1][0] + masses[-1][2]) - 1, H - 1, leaf)
    outline_pass(c, leaf, bark)
    return c


def flowers(c: Canvas, masses, rng, n, petal, centre):
    """3x3 plus flowers with a centre dot, never touching each other."""
    placed, tries = 0, 0
    while placed < n and tries < 80:
        tries += 1
        (mx, my, rx, ry) = masses[rng.randrange(len(masses))]
        x = int(mx + rng.uniform(-rx * 0.6, rx * 0.6))
        y = int(my + rng.uniform(-ry * 0.6, ry * 0.3))
        if not all(c.opaque(x + dx, y + dy) for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1))):
            continue
        if any(c.get(x + dx, y + dy)[:3] in (petal, centre) for dx in range(-4, 5) for dy in range(-4, 5)):
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c.put(x + dx, y + dy, petal)
        c.put(x, y, centre)
        placed += 1


# --- Shrub: planter bed ------------------------------------------------------------------

def trough(c: Canvas, x0, y0, x1, y1):
    """A low concrete planter: box + bevel + tinted outline, soil at the rim."""
    o, dark, mid, light = CONCRETE
    c.rect(x0, y0, x1, y1, mid)
    c.rect(x0, y0, x1, y0, light)
    c.rect(x0, y0, x0, y1, light)
    c.rect(x1, y0, x1, y1, dark)
    c.rect(x0, y1, x1, y1, dark)
    for x in range(x0 - 1, x1 + 2):
        c.put(x, y0 - 1, o)
        c.put(x, y1 + 1, o)
    for y in range(y0 - 1, y1 + 2):
        c.put(x0 - 1, y, o)
        c.put(x1 + 1, y, o)
    c.rect(x0 + 1, y0 + 1, x1 - 1, y0 + 1, (52, 40, 30))
    if x1 - x0 > 14:  # a crack, asymmetric wear
        c.put(x1 - 6, y1 - 1, dark)
        c.put(x1 - 7, y1 - 2, dark)


def bed(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = COM_LEAF
    heads = BED_HEADS
    trough_h = 5
    ty0, ty1 = H - 1 - trough_h, H - 2
    if stage == 0:  # 16 x 16: a short trough, two sprouts
        for x, h in ((5, 3), (10, 4)):
            for k in range(h):
                c.put(x, ty0 - 2 - k, leaf[3] if k < h - 1 else leaf[4])
            c.put(x - 1, ty0 - 2, leaf[2])
        trough(c, 2, ty0, 13, ty1)
        return c
    # low bedding plants: a row of small leaf clusters with coloured heads
    n_plants = 4 if stage == 1 else 7
    xs = [4 + i * ((W - 8) // max(1, n_plants - 1)) for i in range(n_plants)]
    for i, x in enumerate(xs):
        x += (i % 3) - 1                                  # irregular spacing
        h = 3 + (i * 5) % 3
        base_y = ty0 - 2
        c.put(x, base_y, leaf[2])                         # stem
        c.put(x, base_y - 1, leaf[2])
        blob(c, x, base_y - h, B3, leaf, rng, glint=False)
        if stage == 2 or i % 2 == 0:
            c.put(x - 1, base_y - h - 2, heads[i % 3])
            c.put(x, base_y - h - 2, heads[i % 3])
    outline_pass(c, leaf, None, skip={leaf[2]})
    trough(c, 2, ty0, W - 3, ty1)
    return c


# --- Grass: monstera ---------------------------------------------------------------------

def monstera(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = COM_LEAF
    dark, mid, light, glint = leaf[2], leaf[3], leaf[4], leaf[5]

    def big_leaf(x, y, w=6):
        # a broad leaf: shadow mask, mid body pushed up-left, slits from the right edge
        mask = B6 if w >= 6 else B5
        c.stamp(x, y, mask, leaf[1])
        c.stamp(x - 1, y - 1, B4 if w >= 6 else B3, mid, clip=lambda px, py: c.get(px, py)[:3] == leaf[1])
        c.put(x - 2, y - 1, light)
        c.put(x - 1, y - 2, light)
        c.put(x - 2, y - 2, glint)
        c.put(x + 2, y, leaf[1])            # split slits
        c.put(x + 1, y + 1, leaf[1])
        c.put(x, y + 2, dark)               # stem into the leaf

    if stage == 0:  # 16 x 8: two small leaves
        for x, y in ((5, 3), (11, 4)):
            c.stamp(x, y, B3, leaf[1])
            c.put(x - 1, y - 1, mid)
            c.put(x, y - 1, light)
            c.put(x, y + 2, dark)
        shadow_band(c, 3, 13, H - 1, leaf)
        return c
    stems = [(5, 8), (11, 9)] if stage == 1 else [(4, 6), (11, 5), (8, 10)]
    for (x, y) in stems:
        for k in range(y + 2, H - 1):
            c.put(x + (1 if k > y + 4 else 0), k, dark)
    for (x, y) in stems:
        big_leaf(x, y, 6 if stage == 2 else 5)
    shadow_band(c, 1, W - 2, H - 1, leaf)
    outline_pass(c, leaf, None, skip={dark})
    return c


# --- Grass: fern -------------------------------------------------------------------------

def fern(stage, W, H, rng):
    c = Canvas(W, H)
    leaf = COM_LEAF
    dark, mid, light = leaf[2], leaf[3], leaf[4]

    def frond_arc(x0, y0, direction, length, tone):
        # spine 1 px arcing out and over; pinnae alternate either side
        for i in range(length):
            t = i / max(1, length - 1)
            x = x0 + int(round(direction * length * 0.55 * t))
            y = y0 - int(round(length * (t - 0.35 * t * t)))
            c.put(x, y, dark)
            if i % 2 == 1 and 0.1 < t < 0.9:
                c.put(x - 1, y, tone)
                c.put(x + 1, y, tone)
            if i % 4 == 3 and t < 0.8:
                c.put(x - 1, y - 1, light if tone is mid else mid)

    if stage == 0:  # 16 x 8: two sprouting fronds
        frond_arc(6, H - 2, -1, 4, mid)
        frond_arc(10, H - 2, 1, 3, mid)
        shadow_band(c, 3, 13, H - 1, leaf)
        return c
    base_y = H - 2
    if stage == 1:
        frond_arc(8, base_y, -1, 8, mid)
        frond_arc(9, base_y, 1, 7, mid)
        frond_arc(8, base_y, 0, 6, light)
    else:
        frond_arc(7, base_y, -1, 12, mid)
        frond_arc(9, base_y, 1, 10, mid)
        frond_arc(8, base_y, -1, 8, light)
        frond_arc(9, base_y, 1, 6, light)
        frond_arc(8, base_y, 0, 9, mid)
    shadow_band(c, 2, W - 3, H - 1, leaf)
    return c


def _pin_tree(stage, H):
    return 2 if stage == 0 else int(H * 0.3)


def _pin_shrub(stage, H):
    return 3 if stage == 0 else 5


def _pin_bed(stage, H):
    return 8


def _pin_grass(stage, H):
    return 2 if stage == 0 else 3


SPECIES = {
    "com_palm": {
        "name": "Fan Palm", "slot": "tree", "draw": palm, "pin": _pin_tree,
        "stages": [(2, 4), (4, 10), (8, 20)],
        "seed": {"kind": "ball", "tint": (150, 100, 56), "name": "Palm Nut"},
        "desc": "A palm sprout. Grows a ringed trunk and a crown of fronds - mall-front greenery.",
    },
    "com_magnolia": {
        "name": "Magnolia", "slot": "tree", "draw": magnolia, "pin": _pin_tree,
        "stages": [(2, 4), (6, 9), (8, 16)],
        "seed": {"kind": "pip", "tint": (196, 70, 60), "name": "Magnolia Seed"},
        "desc": "A magnolia sapling. Glossy dark leaves and big pink blossoms when grown.",
    },
    "com_bougainvillea": {
        "name": "Bougainvillea", "slot": "tree", "draw": bougainvillea, "pin": _pin_tree,
        "stages": [(2, 3), (4, 6), (6, 10)],
        "seed": {"kind": "samara", "tint": (214, 60, 150), "name": "Bougainvillea Cutting"},
        "desc": "A bougainvillea cutting tied to a post. Cascades magenta over its frame when grown.",
    },
    "com_hibiscus": {
        "name": "Hibiscus", "slot": "shrub", "draw": hibiscus, "pin": _pin_shrub,
        "stages": [(2, 2), (4, 3), (4, 4)],
        "desc": "A hibiscus sprig. Big leaves and red flowers - hand-harvest wood.",
    },
    "com_bed": {
        "name": "Planter Bed", "slot": "shrub", "draw": bed, "pin": _pin_bed,
        "stages": [(2, 2), (4, 2), (6, 2)],
        "desc": "A concrete planter bed of mixed bedding plants. Hand-harvest.",
    },
    "com_monstera": {
        "name": "Monstera", "slot": "grass", "draw": monstera, "pin": _pin_grass,
        "stages": [(2, 1), (2, 2), (2, 2)],
        "desc": "Broad split leaves. Escaped lobby decor.",
    },
    "com_fern": {
        "name": "Fern", "slot": "grass", "draw": fern, "pin": _pin_grass,
        "stages": [(2, 1), (2, 2), (2, 2)],
        "desc": "Arching fern fronds in the shade of the signs.",
    },
}
