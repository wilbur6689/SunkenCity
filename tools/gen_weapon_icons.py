"""Pixel-art icons for the district weapons and their ammo (Weapons.md §4).

    python tools/gen_weapon_icons.py            # only icons that don't exist yet
    ICONS_FORCE=1 python tools/gen_weapon_icons.py   # regenerate the generated set

Writes 16 px RGBA PNGs to assets/sprites/icons/<id>.png - a file there IS the
item's icon (Data.icon). Never overwrites an existing icon unless forced, so
Icon-Editor hand edits survive. Every weapon is a small template (knife,
axe, hammer, pistol, rifle ...) parameterised per item; the depth band tints
the metal (rust -> grey -> iron -> dark steel -> black with a brass trim) so
tier reads at a glance. Deterministic.
"""
import os
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "sprites" / "icons"
FORCE = os.environ.get("ICONS_FORCE") == "1"
S = 16

OUT = (24, 18, 14, 255)
# Metal by band: (shadow, mid, light)
METAL = {
    1: ((110, 80, 60), (150, 120, 95), (190, 165, 140)),      # rust-brown
    2: ((95, 100, 108), (140, 146, 154), (190, 195, 202)),    # grey
    3: ((70, 82, 100), (112, 128, 150), (165, 180, 200)),     # iron blue
    4: ((45, 50, 62), (80, 88, 104), (130, 140, 158)),        # dark steel
    5: ((28, 28, 34), (58, 58, 68), (105, 105, 118)),         # black
}
TRIM = {1: (150, 120, 95), 2: (190, 195, 202), 3: (165, 180, 200), 4: (130, 140, 158), 5: (214, 170, 70)}  # T5: brass
WOOD = ((92, 62, 36), (140, 98, 58), (186, 140, 88))
DARK = ((30, 30, 34), (52, 52, 58), (90, 90, 98))
YELLOW = ((150, 110, 20), (220, 170, 40), (245, 210, 90))
ORANGE = ((160, 80, 20), (225, 125, 40), (250, 175, 90))
RED = ((120, 30, 25), (190, 55, 45), (230, 110, 95))
BLUE = ((30, 70, 130), (60, 120, 200), (120, 180, 240))
GREEN = ((40, 100, 50), (80, 160, 90), (140, 210, 150))
BRASS = ((150, 110, 40), (214, 170, 70), (240, 210, 130))
WHITE = ((150, 150, 150), (210, 210, 210), (245, 245, 245))


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def px(self, x, y, c):
        if 0 <= x < S and 0 <= y < S:
            self.img.putpixel((x, y), c + (255,) if len(c) == 3 else c)

    def line(self, x0, y0, x1, y1, ramp, w=1, shade=1):
        self.d.line([x0, y0, x1, y1], fill=ramp[shade] + (255,), width=w)

    def rect(self, x0, y0, x1, y1, ramp, shade=1):
        self.d.rectangle([x0, y0, x1, y1], fill=ramp[shade] + (255,))

    def poly(self, pts, ramp, shade=1):
        self.d.polygon(pts, fill=ramp[shade] + (255,))

    def ellipse(self, x0, y0, x1, y1, ramp, shade=1):
        self.d.ellipse([x0, y0, x1, y1], fill=ramp[shade] + (255,))

    def finish(self):
        """Inner outline + a light bevel on top-left edges, dark on bottom-right."""
        src = self.img.copy()
        px = src.load()
        out = self.img.load()
        for y in range(S):
            for x in range(S):
                if px[x, y][3] == 0:
                    continue
                nbrs = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                edge = any(not (0 <= nx < S and 0 <= ny < S) or px[nx, ny][3] == 0 for nx, ny in nbrs)
                if edge:
                    out[x, y] = OUT
        # Bevel: opaque, non-outline pixels whose upper/left neighbour is outline get lighter.
        src2 = self.img.copy()
        p2 = src2.load()
        for y in range(S):
            for x in range(S):
                c = p2[x, y]
                if c[3] == 0 or c == OUT:
                    continue
                up = p2[x, y - 1] if y > 0 else OUT
                left = p2[x - 1, y] if x > 0 else OUT
                down = p2[x, y + 1] if y < S - 1 else OUT
                if up == OUT or left == OUT:
                    out[x, y] = tuple(min(255, v + 28) for v in c[:3]) + (255,)
                elif down == OUT:
                    out[x, y] = tuple(max(0, v - 22) for v in c[:3]) + (255,)
        return self.img


# --- Templates: each draws into a Canvas; (band) picks the metal ramp -------------------

def handle(c, x0, y0, x1, y1, ramp=WOOD, w=2):
    c.line(x0, y0, x1, y1, ramp, w)


def knife(c, m, length=9, width=2, grip=DARK):
    # diagonal: grip bottom-left, blade to top-right
    handle(c, 2, 13, 5, 10, grip, 2)
    c.poly([(5, 10), (5 + length, 10 - length), (5 + length + 1, 10 - length + 2), (7, 11)], m, 2)
    c.line(5, 10, 5 + length, 10 - length, m, 1, 1)
    c.px(4, 9, m[0]); c.px(6, 11, m[0])  # guard


def blade(c, m, grip=DARK):
    handle(c, 1, 14, 4, 11, grip, 2)
    c.poly([(4, 11), (13, 2), (15, 4), (6, 13)], m, 2)
    c.line(4, 11, 13, 2, m, 1, 1)


def axe(c, m, head=4, double=False, wood=WOOD):
    handle(c, 2, 14, 11, 5, wood, 2)
    c.poly([(9, 3), (13, 1), (15, 5), (12, 8)], m, 2)
    c.line(13, 1, 15, 5, m, 1, 2)
    if head > 4:
        c.poly([(8, 2), (13, 0), (15, 6), (11, 9)], m, 2)
    if double:
        c.poly([(6, 5), (9, 3), (12, 8), (9, 10)], m, 1)


def hammer(c, m, head_w=6, head_h=3, wood=WOOD, long=True):
    if long:
        handle(c, 2, 14, 10, 6, wood, 2)
    else:
        handle(c, 4, 13, 9, 8, wood, 2)
    cx, cy = 11, 5
    c.rect(cx - head_w // 2, cy - head_h // 2, cx + head_w // 2, cy + head_h // 2, m, 1)
    c.rect(cx - head_w // 2, cy - head_h // 2, cx + head_w // 2, cy - head_h // 2, m, 2)


def sledge(c, m, wood=WOOD):
    handle(c, 2, 14, 10, 6, wood, 2)
    c.poly([(7, 5), (12, 0), (15, 3), (10, 8)], m, 1)
    c.line(12, 0, 15, 3, m, 1, 2)


def bat(c, ramp=WOOD):
    c.line(2, 14, 6, 10, ramp, 2)
    c.line(6, 10, 13, 3, ramp, 3)
    c.line(2, 14, 3, 13, DARK, 2)


def club(c, ramp=WOOD):
    # A knotted rooftop branch: thin grip, thick head (hand-crafted Stage 1 weapon).
    c.line(2, 14, 7, 9, ramp, 2)
    c.line(7, 9, 12, 4, ramp, 4)
    c.px(9, 5, DARK[0]); c.px(12, 6, DARK[0]); c.px(11, 3, ramp[2])
    c.line(2, 14, 3, 13, DARK, 2)


def rod(c, m, hook=False, w=2, ramp=None):
    ramp = ramp or m
    c.line(2, 14, 13, 3, ramp, w)
    if hook:
        c.line(13, 3, 15, 5, ramp, 2)


def crowbar(c, m):
    c.line(2, 14, 11, 5, m, 2)
    c.line(11, 5, 14, 3, m, 2)
    c.line(14, 3, 15, 5, m, 2)
    c.poly([(1, 13), (3, 15), (0, 15)], m, 1)


def pipe_wrench(c, m):
    c.line(2, 14, 10, 6, m, 3)
    c.rect(9, 2, 14, 7, m, 1)
    c.rect(11, 0, 15, 3, m, 2)


def wrench(c, m):
    rod(c, m, w=2)
    c.rect(10, 1, 15, 6, m, 1)
    c.rect(12, 3, 15, 4, DARK, 0)


def pick(c, m, wood=WOOD):
    handle(c, 3, 14, 10, 7, wood, 2)
    c.poly([(5, 4), (10, 6), (15, 4), (14, 2), (10, 4), (6, 2)], m, 1)
    c.line(5, 4, 10, 6, m, 1, 2)


def spear(c, m, barbs=False, shaft=WOOD):
    c.line(1, 14, 11, 4, shaft, 2)
    c.poly([(10, 5), (15, 0), (14, 4), (12, 3)], m, 2)
    if barbs:
        c.px(12, 1, m[1]); c.px(11, 6, m[1]); c.px(13, 5, m[1])


def poker(c, m):
    c.line(2, 14, 12, 4, m, 2)
    c.line(12, 4, 14, 1, m, 2)
    c.line(12, 4, 14, 6, m, 1)
    c.rect(1, 13, 3, 15, DARK, 1)


def halligan(c, m):
    c.line(3, 13, 12, 4, m, 2)
    c.line(11, 5, 15, 3, m, 2)   # adze
    c.line(11, 5, 13, 1, m, 2)   # pick
    c.line(3, 13, 1, 15, m, 2)
    c.line(3, 13, 5, 15, m, 2)   # fork
    c.line(2, 15, 3, 15, m, 1, 0)


def cylinder(c, ramp, x0=5, y0=2, x1=10, y1=14, cap=None):
    c.rect(x0, y0, x1, y1, ramp, 1)
    c.rect(x0, y0, x0 + 1, y1, ramp, 2)
    if cap:
        c.rect(x0 + 1, y0 - 2, x1 - 1, y0, cap, 1)


def flashlight(c, m):
    c.line(2, 14, 9, 7, m, 3)
    c.poly([(8, 5), (12, 1), (15, 4), (11, 8)], m, 1)
    c.line(12, 1, 15, 4, YELLOW, 2, 2)


def baton(c, ramp=DARK, tip=None):
    c.line(2, 14, 13, 3, ramp, 3)
    c.line(2, 14, 4, 12, WOOD, 3, 0)
    if tip:
        c.line(11, 5, 13, 3, tip, 3, 2)


def stapler(c, m):
    c.rect(1, 8, 14, 12, m, 1)
    c.poly([(1, 8), (12, 4), (14, 7), (2, 9)], DARK, 1)
    c.rect(1, 12, 14, 13, DARK, 0)


def extinguisher(c):
    cylinder(c, RED, 5, 4, 10, 15, cap=DARK)
    c.line(7, 2, 11, 1, DARK, 2)
    c.rect(6, 7, 9, 9, WHITE, 2)


def desk_leg(c):
    c.line(2, 14, 12, 4, DARK, 3)
    c.rect(11, 1, 15, 5, DARK, 2)
    c.rect(1, 13, 3, 15, METAL[2], 1)


def powered_saw(c, m, blade_ramp=None):
    blade_ramp = blade_ramp or m
    c.rect(1, 7, 8, 13, ORANGE, 1)
    c.rect(2, 4, 5, 7, ORANGE, 2)
    c.ellipse(7, 1, 15, 9, blade_ramp, 1)
    c.ellipse(10, 4, 12, 6, DARK, 0)
    for x, y in ((8, 2), (14, 2), (8, 8), (14, 8), (11, 1), (11, 9), (7, 5), (15, 5)):
        c.px(x, y, blade_ramp[2])


def demolition_hammer(c, m):
    c.rect(2, 3, 10, 10, YELLOW, 1)
    c.rect(2, 3, 10, 4, YELLOW, 2)
    c.rect(4, 0, 8, 3, DARK, 1)  # handle
    c.line(10, 7, 15, 12, m, 2)   # chisel
    c.line(13, 10, 15, 12, m, 3, 2)


def cutter(c, m, spread=False):
    c.rect(1, 8, 8, 13, YELLOW, 1)
    c.rect(1, 12, 8, 13, DARK, 0)
    if spread:
        c.line(8, 9, 14, 3, m, 2)
        c.line(8, 12, 14, 15, m, 2)
        c.line(8, 9, 8, 12, m, 2)
    else:
        c.line(8, 9, 14, 5, m, 2)
        c.line(8, 12, 14, 10, m, 2)
        c.poly([(12, 5), (15, 6), (15, 8), (12, 9)], m, 2)


def pole_hook(c, m):
    c.line(1, 15, 12, 4, WOOD, 2)
    c.line(12, 4, 14, 1, m, 2)
    c.line(11, 5, 14, 6, m, 2)
    c.line(14, 6, 13, 8, m, 1)


def pistol(c, m, long=False, grip=DARK, revolver=False):
    barrel_end = 15 if long else 13
    c.rect(2, 5, barrel_end, 7, m, 1)
    c.rect(2, 5, barrel_end, 5, m, 2)
    c.rect(2, 7, 7, 8, m, 0)
    c.poly([(3, 8), (7, 8), (6, 14), (2, 14)], grip, 1)
    c.line(8, 8, 9, 10, DARK, 1, 0)  # trigger
    if revolver:
        c.ellipse(6, 4, 10, 8, m, 2)
        c.px(8, 6, DARK[0])


def smg(c, m):
    c.rect(1, 5, 14, 8, m, 1)
    c.rect(1, 5, 14, 5, m, 2)
    c.rect(12, 6, 15, 7, DARK, 1)
    c.poly([(2, 8), (5, 8), (4, 13), (1, 13)], DARK, 1)
    c.rect(7, 8, 9, 14, DARK, 1)   # magazine
    c.rect(0, 4, 3, 5, DARK, 0)    # stock nub


def rifle(c, m, scope=False, stock=WOOD, mag=False, pump=False, short=False):
    x0 = 3 if short else 1
    c.poly([(0, 6), (4, 6), (4, 10), (0, 12)], stock, 1)       # stock
    c.rect(4, 6, 12, 8, stock if stock is not DARK else DARK, 1)  # fore-end
    c.rect(4, 5, 15, 6, m, 1)                                   # barrel
    c.rect(4, 5, 15, 5, m, 2)
    c.rect(5, 8, 7, 10, DARK, 0)                                # trigger guard
    if scope:
        c.rect(5, 2, 10, 4, DARK, 1)
        c.px(5, 3, BLUE[2]); c.px(10, 3, BLUE[2])
    if mag:
        c.rect(7, 8, 9, 12, DARK, 1)
    if pump:
        c.rect(9, 7, 12, 9, DARK, 1)
    _ = x0


def shotgun(c, m, double=False, auto=False, stock=WOOD):
    c.poly([(0, 6), (4, 6), (4, 10), (0, 12)], stock, 1)
    c.rect(4, 5, 15, 7, m, 1)
    c.rect(4, 5, 15, 5, m, 2)
    c.rect(6, 7, 11, 9, stock if not auto else DARK, 1)  # pump / fore-end
    if double:
        c.rect(4, 4, 15, 4, m, 1)
    c.rect(5, 9, 7, 10, DARK, 0)


def bow(c, m, compound=True):
    c.line(4, 1, 4, 14, WHITE, 1, 2)                 # string
    c.d.arc([3, 0, 13, 15], 270, 90, fill=m[1] + (255,), width=2)
    if compound:
        c.ellipse(6, 0, 9, 3, DARK, 1)
        c.ellipse(6, 12, 9, 15, DARK, 1)
    c.rect(8, 6, 10, 9, WOOD, 1)                     # grip


def crossbow(c, m, compound=False):
    c.rect(1, 7, 14, 9, WOOD, 1)                     # stock
    c.rect(0, 8, 3, 11, WOOD, 0)
    c.d.arc([8, 1, 16, 15], 240, 120, fill=m[1] + (255,), width=2)  # prod
    c.line(11, 2, 11, 14, WHITE, 1, 2)               # string
    c.rect(4, 5, 7, 7, DARK, 1)                      # scope/latch
    if compound:
        c.ellipse(11, 0, 14, 3, DARK, 1)
        c.ellipse(11, 12, 14, 15, DARK, 1)


def nailgun(c, m, body=ORANGE):
    c.rect(3, 4, 11, 8, body, 1)
    c.rect(3, 4, 11, 4, body, 2)
    c.rect(11, 5, 14, 6, m, 1)                       # nose
    c.poly([(4, 8), (8, 8), (7, 14), (3, 14)], DARK, 1)  # grip
    c.rect(9, 8, 13, 13, DARK, 1)                    # magazine strip
    c.rect(10, 9, 12, 12, m, 2)


def flaregun(c):
    c.rect(2, 5, 12, 8, ORANGE, 1)
    c.rect(2, 5, 12, 5, ORANGE, 2)
    c.rect(11, 4, 15, 9, DARK, 1)                    # fat barrel
    c.poly([(3, 8), (7, 8), (6, 14), (2, 14)], DARK, 1)


def harpoongun(c, m, big=False):
    c.rect(1, 7, 10, 10, DARK, 1)
    c.rect(2, 5, 13, 7, m, 1)
    c.rect(2, 5, 13, 5, m, 2)
    c.line(6, 6, 15, 6, m, 1, 2)
    c.poly([(13, 4), (16, 6), (13, 8)], m, 2)
    c.poly([(2, 10), (5, 10), (4, 14), (1, 14)], DARK, 1)
    if big:
        c.rect(1, 2, 6, 5, DARK, 1)                  # air tank


def speargun(c, m):
    harpoongun(c, m)


# --- Ammo -----------------------------------------------------------------------------

def shells(c):
    for i, (x, y) in enumerate(((3, 3), (7, 5), (11, 7))):
        c.rect(x, y, x + 2, y + 7, RED, 1)
        c.rect(x, y + 6, x + 2, y + 7, BRASS, 1)


def arrows(c, m):
    for dy in (0, 4):
        c.line(1, 13 - dy, 13, 1 - dy + 0, WOOD, 1)
        c.px(13, 1 - dy + 0, m[1])
    c.line(1, 13, 13, 1, WOOD, 1)
    c.poly([(11, 3), (14, 0), (14, 3)], m, 2)
    c.line(1, 13, 3, 14, WHITE, 1, 2)
    c.line(1, 13, 0, 11, WHITE, 1, 2)


def bolts(c, m):
    for off in (0, 3):
        c.line(2 + off, 14, 11 + off, 5, DARK, 1)
        c.poly([(10 + off, 6), (13 + off, 3), (13 + off, 6)], m, 2)
        c.px(3 + off, 13, WHITE[2])


def nails(c, m):
    for x in (3, 6, 9, 12):
        c.line(x, 3, x, 13, m, 1)
        c.rect(x - 1, 2, x + 1, 2, m, 2)
        c.px(x, 14, m[0])


def rivets(c, m):
    for x, y in ((3, 4), (8, 4), (13, 4), (5, 10), (10, 10)):
        c.rect(x - 1, y, x + 1, y + 4, m, 1)
        c.rect(x - 2, y - 1, x + 2, y, m, 2)


def flares(c):
    for off in (0, 4):
        c.line(2 + off, 14, 9 + off, 3, RED, 3)
        c.line(9 + off, 3, 10 + off, 1, YELLOW, 2, 2)


def harpoon_bolt(c, m):
    c.line(1, 14, 12, 3, DARK, 2)
    c.poly([(11, 4), (15, 0), (14, 4), (12, 3)], m, 2)
    c.px(12, 1, m[1]); c.px(10, 6, m[1]); c.px(13, 5, m[1])
    c.line(1, 14, 3, 14, WHITE, 1, 2)


# --- Roster -> template calls -------------------------------------------------------

def spec(name, band, fn, **kw):
    return (band, fn, kw)


MELEE = {
    "baseball_bat": spec("Baseball Bat", 1, bat),
    "wood_club": spec("Wooden Club", 1, club),  # hand-crafted rooftop weapon (2026-09-06), not a district weapon
    "baton": spec("Baton", 1, baton),
    "crowbar": spec("Crowbar", 1, crowbar),
    "desk_leg": spec("Desk Leg", 1, desk_leg),
    "fire_extinguisher": spec("Fire Extinguisher", 1, extinguisher),
    "fireplace_poker": spec("Fireplace Poker", 1, poker),
    "halligan_tool": spec("Halligan Tool", 1, halligan),
    "hatchet": spec("Hatchet", 1, axe),
    "kitchen_knife": spec("Kitchen Knife", 1, knife, grip=WOOD),
    "letter_opener": spec("Letter Opener", 1, knife, length=8, width=1, grip=BRASS),
    "machete": spec("Machete", 1, blade),
    "nail_puller": spec("Nail Puller", 1, crowbar),
    "paper_cutter": spec("Paper Cutter", 1, blade, grip=DARK),
    "pipe_wrench": spec("Pipe Wrench", 1, wrench),
    "rebar_club": spec("Rebar Club", 1, rod, hook=True, w=2),
    "rescue_axe": spec("Rescue Axe", 1, axe, wood=RED),
    "stapler": spec("Stapler", 1, stapler),
    "utility_knife": spec("Utility Knife", 1, knife, length=6, grip=YELLOW),
    "boarding_axe": spec("Boarding Axe", 2, axe, double=True, wood=DARK),
    "breaching_tool": spec("Breaching Tool", 2, halligan),
    "demolition_hammer": spec("Demolition Hammer", 2, demolition_hammer),
    "security_flashlight": spec("Security Flashlight", 2, flashlight),
    "lump_hammer": spec("Lump Hammer", 2, hammer, long=False),
    "cane_machete": spec("Cane Machete", 2, blade, grip=WOOD),
    "pickaxe": spec("Pickaxe", 2, pick),
    "rescue_saw": spec("Rescue Saw", 2, powered_saw),
    "riot_baton": spec("Riot Baton", 2, baton, ramp=DARK, tip=None),
    "sledgehammer": spec("Sledgehammer", 2, sledge),
    "spear": spec("Spear", 2, spear),
    "splitting_maul": spec("Splitting Maul", 2, axe, head=6),
    "breaching_hammer": spec("Breaching Hammer", 3, sledge, wood=DARK),
    "dive_knife": spec("Dive Knife", 3, knife, grip=BLUE),
    "harpoon": spec("Harpoon", 3, spear, barbs=True, shaft=DARK),
    "felling_axe": spec("Felling Axe", 3, axe, head=6),
    "pinch_bar": spec("Pinch Bar", 3, crowbar),
    "broad_hatchet": spec("Broad Hatchet", 3, axe, head=6),
    "hunting_knife": spec("Hunting Knife", 3, knife, length=10, grip=WOOD),
    "industrial_cutter": spec("Industrial Cutter", 3, cutter),
    "breaching_sledge": spec("Breaching Sledge", 4, sledge, wood=DARK),
    "mattock": spec("Mattock", 4, pick),
    "hydraulic_cutter": spec("Hydraulic Cutter", 4, cutter),
    "industrial_saw": spec("Industrial Saw", 4, powered_saw),
    "pole_hook": spec("Pole Hook", 4, pole_hook),
    "rescue_spreader": spec("Rescue Spreader", 4, cutter, spread=True),
    "breaching_maul": spec("Breaching Maul", 5, sledge, wood=DARK),
    "shock_baton": spec("Shock Baton", 5, baton, ramp=DARK, tip=BLUE),
    "whaling_harpoon": spec("Whaling Harpoon", 5, spear, barbs=True, shaft=DARK),
    "tactical_axe": spec("Tactical Axe", 5, axe, wood=DARK),
}
RANGED = {
    "rifle_22": spec(".22 Rifle", 1, rifle, stock=WOOD),
    "compact_pistol": spec("Compact Pistol", 1, pistol),
    "compound_bow": spec("Compound Bow", 1, bow),
    "crossbow": spec("Crossbow", 1, crossbow),
    "flare_gun": spec("Flare Gun", 1, flaregun),
    "hunting_rifle": spec("Hunting Rifle", 1, rifle, scope=True),
    "nail_gun": spec("Nail Gun", 1, nailgun),
    "pellet_gun": spec("Pellet Gun", 1, pistol, long=True, grip=WOOD),
    "revolver": spec("Revolver", 1, pistol, revolver=True, grip=WOOD),
    "service_pistol": spec("Service Pistol", 1, pistol),
    "patrol_shotgun": spec("Patrol Shotgun", 2, shotgun, stock=DARK),
    "pump_shotgun": spec("Pump Shotgun", 2, shotgun),
    "rivet_gun": spec("Rivet Gun", 2, nailgun, body=YELLOW),
    "harpoon_gun": spec("Harpoon Gun", 3, harpoongun),
    "compound_crossbow": spec("Compound Crossbow", 3, crossbow, compound=True),
    "patrol_rifle": spec("Patrol Rifle", 3, rifle, stock=DARK, mag=True),
    "riot_shotgun": spec("Riot Shotgun", 3, shotgun, stock=DARK),
    "tactical_pistol": spec("Tactical Pistol", 3, pistol, long=True),
    "assault_carbine": spec("Assault Carbine", 4, rifle, stock=DARK, mag=True),
    "framing_nailer": spec("Framing Nailer", 4, nailgun, body=ORANGE),
    "hunting_magnum": spec("Hunting Magnum", 4, rifle, scope=True),
    "machine_pistol": spec("Machine Pistol", 4, smg),
    "semi_auto_rifle": spec("Semi-Auto Rifle", 4, rifle, mag=True),
    "semi_auto_shotgun": spec("Semi-Auto Shotgun", 4, shotgun, auto=True),
    "tactical_carbine": spec("Tactical Carbine", 4, rifle, stock=DARK, mag=True, scope=True),
    "tactical_shotgun": spec("Tactical Shotgun", 4, shotgun, stock=DARK, auto=True),
    "battle_rifle": spec("Battle Rifle", 5, rifle, stock=DARK, mag=True),
    "combat_shotgun": spec("Combat Shotgun", 5, shotgun, stock=DARK, auto=True, double=True),
    "dmr": spec("Designated Marksman Rifle", 5, rifle, stock=DARK, mag=True, scope=True),
    "whaling_gun": spec("Whaling Gun", 5, harpoongun, big=True),
    "industrial_rivet_gun": spec("Industrial Rivet Gun", 5, nailgun, body=YELLOW),
    "marksman_rifle": spec("Marksman Rifle", 5, rifle, scope=True),
    "military_carbine": spec("Military Carbine", 5, rifle, stock=DARK, mag=True),
    "sniper_rifle": spec("Sniper Rifle", 5, rifle, scope=True, stock=DARK),
}
AMMO = {
    "shotgun_shells": spec("Shotgun Shells", 2, shells),
    "arrows": spec("Arrows", 2, arrows),
    "crossbow_bolts": spec("Crossbow Bolts", 2, bolts),
    "nails": spec("Nails", 2, nails),
    "rivets": spec("Rivets", 3, rivets),
    "flares": spec("Flares", 1, flares),
    "harpoon": spec("Harpoon Bolt", 3, harpoon_bolt),
}
NO_METAL = {bat, club, extinguisher, desk_leg, flaregun, shells, flares, baton}


def draw(item_id, band, fn, kw):
    c = Canvas()
    m = METAL[band]
    if fn in NO_METAL:
        fn(c, **kw)
    else:
        fn(c, m, **kw)
    img = c.finish()
    if band == 5:
        # Brass trim pixel: a tier-5 tell on the handle end.
        img.putpixel((1, 14), TRIM[5] + (255,)) if img.getpixel((1, 14))[3] else img.putpixel((2, 13), TRIM[5] + (255,))
    return img


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    wrote = skipped = 0
    for group in (MELEE, RANGED, AMMO):
        for item_id, (band, fn, kw) in group.items():
            path = OUT_DIR / (item_id + ".png")
            if path.exists() and not FORCE:
                skipped += 1
                continue
            draw(item_id, band, fn, kw).save(path)
            wrote += 1
    print("weapon icons: wrote %d, kept %d existing" % (wrote, skipped))


if __name__ == "__main__":
    main()
