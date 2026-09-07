"""Shared helpers for the flora sprite drawers (tools/flora_art/<district>.py).

The art rules are docs/Flora/flora.md (and the pixel-game-art skill):
  * one light, top-left: every lighter foliage layer is the previous layer
    shrunk and pushed up-left, so the darkest green shows along the bottom
    and right and in the gaps between clusters
  * foliage is CLUSTERS (one small brush set at 2-3 sizes), never noise or
    a flat blob; ragged on the light side, smooth on the dark side
  * a 6-step hue-shifted leaf ramp (outline, shadow, dark, mid, light,
    glint), a 4-step bark ramp, one accent per species
  * a 1 px hue-tinted outline, thinned at the top-left (sel-out), 2 px along
    the bottom-right
  * a ground tuft anchors free-standing plants
  * every plant is a sway STRIP: frame 0 is the rest pose, later frames shear
    the free end LEFT (the world's wind) with the base rows pinned

Species drawers build a REST FRAME (an RGBA Image of w*8 x h*8 px, the object
bottom row on the last image row) and hand it to `strip()`.
"""
from __future__ import annotations

import colorsys
import math
import random

from PIL import Image

CELL = 8  # px per world cell

# --- ramps ---------------------------------------------------------------------

# index: 0 outline, 1 shadow, 2 dark, 3 mid, 4 light, 5 glint
LEAF = [(18, 34, 26), (36, 79, 58), (51, 112, 72), (74, 144, 82), (116, 184, 90), (168, 220, 120)]
# index: 0 outline, 1 dark, 2 mid, 3 light
BARK = [(42, 26, 14), (94, 62, 38), (138, 94, 58), (184, 136, 90)]
SOIL = [(42, 26, 14), (94, 62, 38), (110, 92, 76)]


def shift(rgb, hue_deg=0.0, sat=1.0, val=1.0):
    """Rotate a colour's hue (degrees) and scale saturation / value."""
    h, s, v = colorsys.rgb_to_hsv(*(c / 255.0 for c in rgb))
    h = (h + hue_deg / 360.0) % 1.0
    s = max(0.0, min(1.0, s * sat))
    v = max(0.0, min(1.0, v * val))
    return tuple(int(round(c * 255)) for c in colorsys.hsv_to_rgb(h, s, v))


def shift_ramp(ramp, hue_deg=0.0, sat=1.0, val=1.0):
    return [shift(c, hue_deg, sat, val) for c in ramp]


# --- brushes -------------------------------------------------------------------

def _mask(rows):
    return [[ch == "1" for ch in r] for r in rows]


B2 = _mask(["11", "11"])
B3 = _mask([".1.", "111", ".1."])
B4 = _mask([".11.", "1111", ".11."])
B5 = _mask([".111.", "11111", "11111", ".111."])
B6 = _mask(["..11..", ".1111.", "111111", ".1111.", "..11.."])
BRUSHES = {"b2": B2, "b3": B3, "b4": B4, "b5": B5, "b6": B6}


def mask_area(m):
    return sum(sum(1 for c in r if c) for r in m)


class Canvas:
    """A tiny RGBA pixel canvas with bounds-checked writes."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.img.load()

    def put(self, x, y, rgb):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = (rgb[0], rgb[1], rgb[2], 255)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return (0, 0, 0, 0)

    def opaque(self, x, y):
        return self.get(x, y)[3] != 0

    def rect(self, x0, y0, x1, y1, rgb):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for x in range(min(x0, x1), max(x0, x1) + 1):
                self.put(x, y, rgb)

    def stamp(self, cx, cy, mask, rgb, clip=None):
        """Stamp a brush centred on (cx, cy); `clip(x, y)` may veto pixels."""
        mh, mw = len(mask), len(mask[0])
        ox, oy = cx - mw // 2, cy - mh // 2
        for j, row in enumerate(mask):
            for i, on in enumerate(row):
                if on:
                    x, y = ox + i, oy + j
                    if clip is None or clip(x, y):
                        self.put(x, y, rgb)


# --- foliage -------------------------------------------------------------------

def ellipse_fn(cx, cy, rx, ry):
    rx, ry = max(rx, 0.5), max(ry, 0.5)

    def inside(x, y):
        dx, dy = (x - cx) / rx, (y - cy) / ry
        return dx * dx + dy * dy <= 1.0

    return inside


def canopy(c: Canvas, masses, leaf, rng: random.Random, *, step=None, density=(1.0, 0.85, 0.7),
           glint_frac=0.3, teeth=True, layers=3):
    """Layered cluster foliage over a list of (cx, cy, rx, ry) masses.

    Masses are painted in list order (later = in front); each mass paints its
    silhouette in the SHADOW tone (so a front mass leaves a dark rim over the
    one behind), then `layers` lighter strata (dark, mid, light), each shrunk
    by `step` px and pushed up-left by the same amount so the top-left edge
    stays flush and the bottom-right keeps a widening dark margin. Strata are
    painted as brush clusters at a coverage `density` so the darker tone
    shows through in the gaps. The glint tone goes only on the upper-left
    `glint_frac` of each mass, as a few small clusters.
    """
    shadow, dark, mid, light, glint = leaf[1], leaf[2], leaf[3], leaf[4], leaf[5]
    tones = [dark, mid, light][:layers]
    for (mx, my, rx, ry) in masses:
        st = step if step is not None else max(1, int(round(min(rx, ry) / 5.0)))
        base = ellipse_fn(mx, my, rx, ry)
        # layer 0: silhouette in the shadow tone
        x0, x1 = int(mx - rx) - 1, int(mx + rx) + 2
        y0, y1 = int(my - ry) - 1, int(my + ry) + 2
        for y in range(y0, y1):
            for x in range(x0, x1):
                if base(x, y):
                    c.put(x, y, shadow)
        # ragged light side: 2-px teeth poking out along the top / left rim
        if teeth:
            n_teeth = max(2, int((rx + ry) / 3))
            for _ in range(n_teeth):
                a = rng.uniform(0.55, 1.9) * 3.14159  # top-left quadrant-ish arc
                tx = int(round(mx + rx * 1.0 * math.cos(a)))
                ty = int(round(my - ry * 1.0 * abs(math.sin(a))))
                if not base(tx, ty):
                    c.stamp(tx, ty, B2, shadow)
        # lighter strata as clusters
        for k, tone in enumerate(tones, start=1):
            shrink = st * k
            off = st * k
            region = ellipse_fn(mx - off, my - off, rx - shrink, ry - shrink)
            if rx - shrink < 1 or ry - shrink < 1:
                break
            area = 3.14159 * (rx - shrink) * (ry - shrink)
            brush = B5 if min(rx, ry) >= 9 else (B4 if min(rx, ry) >= 5 else B3)
            if k == len(tones):
                brush = B4 if min(rx, ry) >= 9 else B3
            dens = density[min(k - 1, len(density) - 1)]
            n = max(1, int(area / mask_area(brush) * dens * 1.6))
            bx0, bx1 = int(mx - off - (rx - shrink)), int(mx - off + (rx - shrink))
            by0, by1 = int(my - off - (ry - shrink)), int(my - off + (ry - shrink))
            for _ in range(n):
                x = rng.randint(bx0, max(bx0, bx1))
                y = rng.randint(by0, max(by0, by1))
                if region(x, y):
                    c.stamp(x, y, brush, tone, clip=base)
                    # each cluster is a tiny sphere: a 2-px lighter spot top-left
                    nxt = tones[k] if k < len(tones) else None
                    if nxt is not None and len(brush) >= 3:
                        for (dx, dy) in ((-1, -1), (0, -1)):
                            if base(x + dx, y + dy) and c.get(x + dx, y + dy)[:3] == tone:
                                c.put(x + dx, y + dy, nxt)
        # glint: a few small clusters on the upper-left of the mass
        gl_reg = ellipse_fn(mx - rx * 0.35, my - ry * 0.4, rx * glint_frac + 1, ry * glint_frac + 1)
        n_gl = max(1, int((rx * ry) / 40))
        for _ in range(n_gl):
            x = rng.randint(int(mx - rx), int(mx))
            y = rng.randint(int(my - ry), int(my))
            if gl_reg(x, y) and base(x, y):
                c.stamp(x, y, B2 if min(rx, ry) < 8 else B3, glint,
                        clip=lambda px, py: base(px, py) and c.get(px, py)[:3] in (light, mid))


def blob(c: Canvas, cx, cy, brush, leaf, rng: random.Random, glint=True):
    """One shaded leaf cluster (seedling leaves, sprigs): shadow mask, a
    lighter core pushed up-left, a glint pixel pair top-left."""
    shadow, dark, mid, light, gl = leaf[1], leaf[2], leaf[3], leaf[4], leaf[5]
    c.stamp(cx, cy, brush, shadow)
    inner = {"b6": B4, "b5": B3, "b4": B3, "b3": B2, "b2": B2}[_name(brush)]
    c.stamp(cx - 1, cy - 1, inner, mid, clip=lambda x, y: c.get(x, y)[:3] == shadow)
    if len(brush) >= 3:
        c.put(cx - 1, cy - 1, light)
        if glint:
            c.put(cx - 2, cy - 1, light if len(brush) < 4 else gl)


def _name(brush):
    for k, v in BRUSHES.items():
        if v is brush:
            return k
    return "b3"


# --- seedlings -----------------------------------------------------------------

def seedling(c: Canvas, W, H, rng, leaf, bark, leaves=3, lean=-1, accent=None):
    """Thin stem + 2-3 uneven leaf clusters + a small ground shadow. Not a
    shrunken tree: a sprout."""
    cx = W // 2 + 1
    top = H // 3
    stem_x = cx
    for y in range(H - 2, top - 1, -1):
        t = (H - 2 - y) / max(1, H - 2 - top)
        x = stem_x + int(round(lean * t))
        c.put(x, y, bark[2] if y > H - 2 - (H - top) // 3 else leaf[2])
    tip_x = stem_x + lean
    # leaves: the top pair and one lower, sizes uneven
    spots = [(tip_x - 3, top + 1, B4), (tip_x + 3, top + 2, B3)]
    if leaves >= 3:
        spots.append((stem_x + (2 if rng.random() < 0.5 else -3), top + (H - top) // 2, B3))
    for (lx, ly, br) in spots[:leaves]:
        blob(c, lx, ly, br, leaf, rng, glint=(br is B4))
    if accent is not None:
        c.put(tip_x - 1, top - 1, accent[0])
    shadow_band(c, cx - 3, cx + 2, H - 1, leaf)
    c.put(cx, H - 1, leaf[0])
    c.put(cx - 1, H - 1, leaf[0])


# --- wood ----------------------------------------------------------------------

def trunk(c: Canvas, cx, y_bottom, y_top, w_bottom, w_top, bark, *, kink=0, flare=True,
          mottle=None, rng: random.Random = None):
    """A tapering trunk from (cx, y_bottom) up to y_top; `kink` = total x
    drift at the top. Left third lit, right edge dark, flared base."""
    outline, dark, mid, light = bark
    h = max(1, y_bottom - y_top)
    for y in range(y_top, y_bottom + 1):
        t = (y_bottom - y) / h
        w = max(1, int(round(w_bottom + (w_top - w_bottom) * t)))
        x_c = cx + int(round(kink * t))
        x0 = x_c - w // 2
        if flare and y >= y_bottom - 1 and w >= 2:
            x0 -= 1
            w += 2
        for i in range(w):
            x = x0 + i
            if w >= 3 and i < max(1, w // 3):
                col = light
            elif i == w - 1 and w >= 2:
                col = dark
            else:
                col = mid
            c.put(x, y, col)
    if mottle and rng is not None:
        # pale patches (plane bark): 2x3 spots of light on the mid area
        for _ in range(mottle):
            y = rng.randint(y_top + 2, y_bottom - 3)
            t = (y_bottom - y) / h
            w = max(1, int(round(w_bottom + (w_top - w_bottom) * t)))
            if w < 4:
                continue
            x_c = cx + int(round(kink * t))
            x = rng.randint(x_c - w // 2 + 1, x_c + w // 2 - 2)
            for dy in range(3):
                for dx in range(2):
                    if c.get(x + dx, y + dy)[:3] == mid:
                        c.put(x + dx, y + dy, light)


def branch(c: Canvas, x0, y0, x1, y1, w0, w1, bark):
    """A tapering limb: thick at (x0, y0), thin at (x1, y1), lighter top edge."""
    outline, dark, mid, light = bark
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        t = i / n
        x = int(round(x0 + (x1 - x0) * t))
        y = int(round(y0 + (y1 - y0) * t))
        w = max(1, int(round(w0 + (w1 - w0) * t)))
        horizontal = abs(x1 - x0) > abs(y1 - y0)
        for k in range(w):
            if horizontal:
                c.put(x, y + k - w // 2, light if k == 0 and w > 1 else (dark if k == w - 1 and w > 1 else mid))
            else:
                c.put(x + k - w // 2, y, light if k == 0 and w > 1 else (dark if k == w - 1 and w > 1 else mid))


# --- ground --------------------------------------------------------------------

def tuft(c: Canvas, cx, y_bottom, half_w, leaf, rng: random.Random, blades=3):
    """Ground anchor: a shadow band on the bottom row (darkest under the
    trunk) and a few 1-px blades leaning left (the wind)."""
    outline, shadow, dark, mid = leaf[0], leaf[1], leaf[2], leaf[3]
    for x in range(cx - half_w, cx + half_w + 1):
        c.put(x, y_bottom, outline if abs(x - cx) <= max(1, half_w // 3) else shadow)
    xs = set()
    for _ in range(blades):
        x = cx + rng.choice([-half_w, -half_w + 1, half_w - 1, half_w, -half_w + 2])
        if x in xs:
            continue
        xs.add(x)
        h = rng.randint(2, 3)
        col = rng.choice([dark, mid])
        for k in range(h):
            c.put(x - (1 if k == h - 1 else 0), y_bottom - 1 - k, col)


def shadow_band(c: Canvas, x0, x1, y, leaf):
    for x in range(x0, x1 + 1):
        c.put(x, y, leaf[1])


# --- outline -------------------------------------------------------------------

def outline_pass(c: Canvas, leaf, bark=None, skip=(), thin_top_left=True, thicken=True):
    """1 px hue-tinted outline on transparent pixels touching the plant.
    Bark pixels get the bark outline. `skip`: colours that never get an
    outline (1-px stems / blades would fatten into 3-px bars). Sel-out:
    the outline is dropped above / left of light + glint pixels. Thicken:
    opaque shadow-tone pixels with air below or to the right turn outline,
    giving the 2-px bottom-right edge."""
    bark_set = set(bark[1:]) if bark else set()
    light_set = {leaf[4], leaf[5]}
    skip = set(skip)
    src = [[c.get(x, y) for x in range(c.w)] for y in range(c.h)]

    def op(x, y):
        return 0 <= x < c.w and 0 <= y < c.h and src[y][x][3] != 0

    adds = []
    for y in range(c.h):
        for x in range(c.w):
            if src[y][x][3] != 0:
                continue
            nb = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
            hits = [(nx, ny) for (nx, ny) in nb if op(nx, ny)]
            if not hits:
                continue
            cols = [src[ny][nx][:3] for (nx, ny) in hits]
            if all(col in skip for col in cols):
                continue
            if thin_top_left:
                # only neighbour(s) are below / right of us and lit -> no outline
                below_right = [(nx, ny) for (nx, ny) in hits if nx > x or ny > y]
                if len(below_right) == len(hits) and all(src[ny][nx][:3] in light_set for (nx, ny) in below_right):
                    continue
            if any(col in bark_set for col in cols) and not any(col not in bark_set and col not in skip for col in cols):
                adds.append((x, y, bark[0]))
            else:
                adds.append((x, y, leaf[0]))
    for (x, y, col) in adds:
        c.put(x, y, col)
    if thicken:
        for y in range(c.h):
            for x in range(c.w):
                col = src[y][x]
                if col[3] == 0 or col[:3] != leaf[1]:
                    continue
                if (not op(x + 1, y) and x + 1 < c.w) or (not op(x, y + 1) and y + 1 < c.h):
                    c.put(x, y, leaf[0])


# --- animation -----------------------------------------------------------------

def sway_frames(rest: Image.Image, pinned_rows, amp, glint_pair=None):
    """Ping-pong sway frames from a rest frame. Rows above the pinned zone
    shear LEFT progressively (top row = full amplitude, base = 0). With
    amp == 1 the strip is 2 frames, else 4 (0, a/2, a, a/2). At full
    amplitude the glint pixels step one px up-left onto a light/mid
    neighbour (leaves turning) when `glint_pair` = (glint, light) is given."""
    w, h = rest.size
    free = h - pinned_rows
    if free <= 1 or amp <= 0:
        return [rest]
    amps = [0, 1] if amp == 1 else [0, max(1, amp // 2), amp, max(1, amp // 2)]
    out = []
    for ai, a in enumerate(amps):
        fr = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        sp, dp = rest.load(), fr.load()
        for y in range(h):
            if y >= h - pinned_rows:
                dx = 0
            else:
                dx = int(round(a * (free - y) / free))
            for x in range(w):
                p = sp[x, y]
                if p[3]:
                    nx = x - dx
                    if 0 <= nx < w:
                        dp[nx, y] = p
        if glint_pair and a == amp and amp > 1:
            glint, light = glint_pair
            moves = []
            for y in range(1, h):
                for x in range(1, w):
                    if dp[x, y][:3] == glint and dp[x - 1, y - 1][3] and dp[x - 1, y - 1][:3] == light:
                        moves.append((x, y))
            for (x, y) in moves:
                dp[x, y] = light + (255,)
                dp[x - 1, y - 1] = glint + (255,)
        out.append(fr)
    return out


def strip(frames):
    w, h = frames[0].size
    img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.paste(f, (i * w, 0))
    return img


def amplitude(free_px):
    """1 px per 16 px of free height, capped at 3."""
    return max(1, min(3, free_px // 16))


def palette_count(img):
    return len({p for p in img.getdata() if p[3]})


def seed_icon(kind, tint, bark=BARK):
    """A 16 px seed icon: `kind` in {"samara", "pip", "ball"}; `tint` an RGB."""
    c = Canvas(16, 16)
    out = (24, 18, 14)
    dark, mid, light = bark[1], bark[2], bark[3]
    t_dark = shift(tint, 0, 1.0, 0.7)
    if kind == "pip":  # an apple pip: teardrop
        for (x, y0, y1) in ((7, 4, 11), (8, 3, 12), (9, 4, 11), (6, 6, 10), (10, 6, 10)):
            for y in range(y0, y1 + 1):
                c.put(x, y, mid)
        c.rect(7, 5, 7, 8, light)
        c.rect(10, 7, 10, 10, dark)
        c.put(8, 12, dark)
    elif kind == "samara":  # a winged seed: round body + a wing sweeping right-up
        for (x, y0, y1) in ((4, 8, 11), (5, 7, 12), (6, 7, 12), (7, 8, 11)):
            for y in range(y0, y1 + 1):
                c.put(x, y, mid)
        c.rect(5, 8, 5, 9, light)
        c.put(7, 11, dark)
        wing = [(8, 8), (9, 7), (10, 6), (11, 5), (12, 4), (9, 8), (10, 7), (11, 6), (12, 5), (13, 4)]
        for (x, y) in wing:
            c.put(x, y, tint)
        for (x, y) in ((9, 9), (10, 8), (11, 7), (12, 6)):
            c.put(x, y, t_dark)
    else:  # ball: a bristly seed ball
        for (x, y0, y1) in ((5, 6, 10), (6, 5, 11), (7, 4, 12), (8, 4, 12), (9, 5, 11), (10, 6, 10)):
            for y in range(y0, y1 + 1):
                c.put(x, y, tint)
        c.rect(6, 6, 7, 7, shift(tint, 0, 0.9, 1.3))
        for (x, y) in ((4, 8), (11, 8), (7, 3), (8, 13), (5, 5), (10, 11)):
            c.put(x, y, t_dark)
        c.rect(7, 12, 8, 14, mid)
    # tinted outline
    src = [[c.get(x, y) for x in range(16)] for y in range(16)]
    for y in range(16):
        for x in range(16):
            if src[y][x][3] == 0 and any(0 <= x + dx < 16 and 0 <= y + dy < 16 and src[y + dy][x + dx][3]
                                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                c.put(x, y, out)
    return c.img
