"""Roof zone - rooftop gear + trees (user request 2026-09-01).

Everything that sits on top of a skyscraper: HVAC and cooling plant,
comms masts and dishes, power gear, maintenance rigs (crane, davit,
window-washing platform), signage, an architectural crown, lightning
protection - and trees in three growth stages (sapling -> young ->
mature, ~2.5 floors tall) that players harvest for wood. Style per
docs/technical/TileArt.md - material ramps, 1px outlines, light
top-left / dark bottom-right shading, no per-pixel noise.
"""
from common import *  # noqa: F401,F403

# Canopy ramp for the trees (outline, tones dark->light, highlight).
LEAF = ((18, 34, 22), [(40, 84, 48), (56, 110, 62), (74, 136, 78), (96, 160, 94)], (124, 184, 116))


def _blob(d, x0, y0, x1, y1, ramp=LEAF):
    """One shaded canopy mass: dark body, mid upper-left, light crown."""
    o, t, hl = ramp
    d.ellipse([x0, y0, x1, y1], fill=t[1], outline=o)
    w = x1 - x0
    h = y1 - y0
    d.ellipse([x0 + w // 6, y0 + h // 8, x1 - w // 4, y0 + int(h * 0.62)], fill=t[2])
    d.ellipse([x0 + w // 4, y0 + h // 6, x1 - w // 2, y0 + h // 3], fill=hl)


# ------------------------------------------------------------- mechanical


def draw_hvac(d, W, H):
    mt, pl = RAMPS["metal"], RAMPS["plastic"]
    box(d, 0, 5, W - 1, H - 3, mt)                                # body
    d.rectangle([0, H - 2, W - 1, H - 1], fill=mt[1][0])          # base rail
    d.rectangle([4, 9, 19, 25], fill=mt[1][0], outline=mt[0])     # fan bay
    d.ellipse([6, 11, 17, 23], fill=mt[1][1], outline=mt[0])      # fan
    d.line([11, 12, 11, 22], fill=mt[1][3])
    d.line([7, 17, 16, 17], fill=mt[1][3])
    d.rectangle([25, 9, 43, 25], fill=pl[1][1], outline=pl[0])    # louvers
    for gy in range(11, 25, 3):
        d.line([26, gy, 42, gy], fill=pl[1][3])
    d.rectangle([20, 1, 28, 5], fill=mt[1][2], outline=mt[0])     # duct hood


def draw_cooling_tower(d, W, H):
    mt, pl = RAMPS["metal"], RAMPS["plastic"]
    box(d, 1, 10, W - 2, H - 3, mt)                               # shell
    d.rectangle([1, H - 2, W - 2, H - 1], fill=mt[1][0])          # base
    for gy in range(14, H - 4, 4):                                # louvers
        d.line([3, gy, W - 4, gy], fill=mt[1][0])
    d.ellipse([W // 2 - 12, 1, W // 2 + 12, 12], fill=mt[1][1], outline=mt[0])  # fan cowl
    d.ellipse([W // 2 - 8, 3, W // 2 + 8, 10], fill=(30, 38, 48), outline=mt[0])
    d.line([W // 2 - 7, 6, W // 2 + 7, 6], fill=mt[1][2])         # blades
    d.rectangle([4, 12, 12, 18], fill=pl[1][2], outline=pl[0])    # control box


def draw_exhaust_fan(d, W, H):
    mt = RAMPS["metal"]
    box(d, 0, 2, W - 1, H - 3, mt)
    d.rectangle([2, H - 2, W - 3, H - 1], fill=mt[1][0])          # curb
    d.ellipse([4, 5, W - 5, H - 6], fill=(30, 38, 48), outline=mt[0])  # intake
    d.line([W // 2, 6, W // 2, H - 7], fill=mt[1][2])             # blades
    d.line([5, H // 2 - 1, W - 6, H // 2 - 1], fill=mt[1][2])
    d.point((W // 2, H // 2 - 1), fill=mt[2])


def draw_vent_duct(d, W, H):
    mt = RAMPS["metal"]
    box(d, 0, 4, W - 1, H - 1, mt)                                # run
    for jx in range(10, W - 4, 12):                               # joint bands
        d.rectangle([jx, 3, jx + 1, H - 1], fill=mt[1][0])
    d.line([1, 5, W - 2, 5], fill=mt[2])
    d.rectangle([W - 8, 0, W - 1, 4], fill=mt[1][2], outline=mt[0])  # up-elbow


def draw_boiler_stack(d, W, H):
    mt, st = RAMPS["metal"], RAMPS["stone"]
    box(d, 2, H - 14, W - 3, H - 1, st, bevel=False)              # masonry base
    d.line([3, H - 13, W - 4, H - 13], fill=st[2])
    for by in range(H - 10, H - 2, 4):                            # coursing
        d.line([3, by, W - 4, by], fill=st[1][0])
    box(d, 6, 4, W - 7, H - 14, mt)                               # flue
    d.rectangle([4, 0, W - 5, 4], fill=mt[1][0], outline=mt[0])   # rain cap
    d.line([5, 1, W - 6, 1], fill=mt[1][2])
    for ry in range(8, H - 16, 10):                               # rivet bands
        d.line([7, ry, W - 8, ry], fill=mt[1][0])


def draw_pipes(d, W, H):
    mt, pl = RAMPS["metal"], RAMPS["plastic"]
    d.rectangle([0, 4, W - 1, 8], fill=mt[1][2], outline=mt[0])   # main run
    d.line([1, 5, W - 2, 5], fill=mt[2])
    d.rectangle([0, 10, W - 1, 12], fill=pl[1][2], outline=pl[0])  # small run
    for fx in (6, 22, 38):                                        # flanges
        d.rectangle([fx, 3, fx + 1, 9], fill=mt[1][0])
    d.ellipse([28, 0, 34, 6], fill=RED, outline=OUT)              # valve wheel
    d.rectangle([30, 6, 31, 9], fill=mt[1][0])
    d.rectangle([0, 13, W - 1, H - 1], fill=mt[1][0])             # sleepers


# ------------------------------------------------------------------ comms


def draw_antenna_array(d, W, H):
    mt, pl = RAMPS["metal"], RAMPS["plastic"]
    d.rectangle([W // 2 - 1, 2, W // 2, H - 4], fill=mt[1][2], outline=mt[0])  # pole
    d.rectangle([2, H - 4, W - 3, H - 1], fill=mt[1][1], outline=mt[0])        # mount
    for ay, side in ((8, 0), (20, 1), (32, 0), (44, 1)):          # panel antennas
        ax = 2 if side == 0 else W - 8
        d.rectangle([ax, ay, ax + 5, ay + 10], fill=WHITE, outline=OUT)
        d.line([ax + 1, ay + 1, ax + 1, ay + 9], fill=(200, 200, 196))
        d.line([ax + 6 if side == 0 else ax - 1, ay + 5,
                W // 2 - 1, ay + 7], fill=pl[1][0])               # feed cable
    d.point((W // 2, 1), fill=RED)                                # beacon


def draw_comm_mast(d, W, H):
    mt = RAMPS["metal"]
    for i in range(0, H - 6, 6):                                  # lattice X-bracing
        t = i / (H - 6.0)
        half = int(3 + t * 9)
        x0, x1 = W // 2 - half, W // 2 + half
        d.line([x0, i, x0 + 2, i + 6], fill=mt[1][2])
        d.line([x1, i, x1 - 2, i + 6], fill=mt[1][2])
        d.line([x0, i + 6, x1, i], fill=mt[1][1])
        d.line([x0, i, x1, i + 6], fill=mt[1][1])
    d.rectangle([2, H - 3, W - 3, H - 1], fill=mt[1][0], outline=mt[0])  # footing
    d.rectangle([W // 2 - 1, 0, W // 2, 6], fill=mt[1][3])        # tip
    d.point((W // 2, 0), fill=RED)                                # aircraft light
    d.rectangle([W // 2 - 4, 12, W // 2 + 3, 16], fill=WHITE, outline=OUT)  # drum dish


def draw_satellite_dish(d, W, H):
    mt, pl = RAMPS["metal"], RAMPS["plastic"]
    d.rectangle([W // 2 - 2, H - 14, W // 2 + 1, H - 4], fill=mt[1][1], outline=mt[0])  # pedestal
    d.rectangle([4, H - 4, W - 5, H - 1], fill=mt[1][0], outline=mt[0])
    d.ellipse([2, 2, W - 8, H - 16], fill=(226, 226, 220), outline=OUT)  # dish
    d.ellipse([6, 5, W - 14, H - 22], fill=(240, 240, 236))
    d.line([W - 12, 8, W - 4, 16], fill=pl[1][0])                 # feed arm
    d.rectangle([W - 7, 14, W - 4, 18], fill=pl[1][2], outline=pl[0])


def draw_radio_antenna(d, W, H):
    mt, pl = RAMPS["metal"], RAMPS["plastic"]
    d.rectangle([W // 2, 0, W // 2, H - 8], fill=mt[1][3])        # whip
    d.rectangle([W // 2 - 1, H - 16, W // 2 + 1, H - 8], fill=mt[1][1], outline=mt[0])
    d.rectangle([3, H - 8, W - 4, H - 1], fill=pl[1][1], outline=pl[0])  # tuner box
    d.line([4, H - 7, W - 5, H - 7], fill=pl[1][3])
    for cy in range(6, H - 18, 8):                                # coil marks
        d.line([W // 2 - 2, cy, W // 2 + 2, cy], fill=mt[1][2])


def draw_comm_cabinet(d, W, H):
    mt, pl = RAMPS["metal"], RAMPS["plastic"]
    box(d, 1, 2, W - 2, H - 2, mt)
    d.rectangle([1, H - 1, W - 2, H - 1], fill=mt[0])
    d.rectangle([4, 5, W - 5, 20], fill=(30, 38, 48), outline=mt[0])  # rack window
    for ly in range(7, 19, 3):                                    # status lights
        d.point((6, ly), fill=GREEN)
        d.point((9, ly), fill=YELLOW if ly % 2 else GREEN)
        d.line([12, ly, W - 7, ly], fill=(60, 72, 88))
    d.rectangle([4, 24, W - 5, H - 6], fill=pl[1][1], outline=pl[0])  # vent door
    for vy in range(26, H - 7, 3):
        d.line([5, vy, W - 6, vy], fill=pl[1][3])
    d.point((W - 4, H // 2), fill=mt[2])                          # handle


# ------------------------------------------------------------------ power


def draw_transformer(d, W, H):
    mt, pl = RAMPS["metal"], RAMPS["plastic"]
    box(d, 1, 8, W - 2, H - 2, mt)
    d.rectangle([1, H - 1, W - 2, H - 1], fill=mt[0])
    for fx in range(3, W - 3, 4):                                 # cooling fins
        d.line([fx, 10, fx, H - 4], fill=mt[1][0])
    for bx in (6, 15, 24):                                        # bushings
        d.rectangle([bx, 3, bx + 1, 8], fill=(226, 226, 220), outline=OUT)
        d.point((bx, 2), fill=mt[1][0])
    d.rectangle([W - 9, 11, W - 4, 16], fill=YELLOW, outline=OUT)  # warning plate
    d.rectangle([2, 5, 4, 8], fill=pl[1][1], outline=pl[0])       # conduit stub


def draw_switchgear(d, W, H):
    mt, pl = RAMPS["metal"], RAMPS["plastic"]
    box(d, 0, 1, W - 1, H - 2, mt)
    d.rectangle([0, H - 1, W - 1, H - 1], fill=mt[0])
    d.line([W // 2, 2, W // 2, H - 3], fill=mt[1][0])             # double doors
    for px, py in ((3, 5), (W // 2 + 3, 5)):
        d.rectangle([px, py, px + 9, py + 12], fill=pl[1][1], outline=pl[0])  # panels
        for ly in range(py + 2, py + 11, 3):
            d.line([px + 2, ly, px + 7, ly], fill=pl[1][3])
    d.rectangle([3, 24, W - 4, 30], fill=YELLOW, outline=OUT)     # DANGER strip
    d.line([5, 27, W - 6, 27], fill=OUT)
    d.point((W // 2 - 2, H // 2), fill=mt[2])                     # handles
    d.point((W // 2 + 2, H // 2), fill=mt[2])


def draw_cable_tray(d, W, H):
    mt, pl = RAMPS["metal"], RAMPS["plastic"]
    d.rectangle([0, 6, W - 1, 12], fill=mt[1][1], outline=mt[0])  # tray
    d.line([1, 7, W - 2, 7], fill=mt[1][3])
    for cy, c in ((8, RED), (9, BLUE), (10, (40, 40, 40)), (11, (90, 150, 110))):  # cables
        d.line([2, cy, W - 3, cy], fill=c)
    for lx in (4, W // 2, W - 6):                                 # legs
        d.rectangle([lx, 13, lx + 1, H - 1], fill=mt[1][0])


def draw_generator(d, W, H):
    mt, pl = RAMPS["metal"], RAMPS["plastic"]
    box(d, 0, 6, W - 1, H - 3, mt)                                # enclosure
    d.rectangle([0, H - 2, W - 1, H - 1], fill=mt[1][0])          # skid
    for gy in range(9, H - 5, 3):                                 # side louvers
        d.line([3, gy, 16, gy], fill=mt[1][0])
    d.rectangle([20, 9, 33, 22], fill=pl[1][1], outline=pl[0])    # control panel
    d.rectangle([22, 11, 31, 15], fill=(30, 38, 48))              # gauge glass
    d.point((24, 13), fill=GREEN)
    d.point((28, 13), fill=RED)
    d.rectangle([37, 9, 44, 24], fill=ORANGE, outline=OUT)        # fuel tank
    d.line([38, 10, 43, 10], fill=(240, 170, 90))
    d.rectangle([8, 2, 12, 6], fill=mt[1][0], outline=mt[0])      # exhaust
    d.point((10, 1), fill=mt[1][1])


# ---------------------------------------------------------- roof features


def draw_helipad(d, W, H):
    st = RAMPS["stone"]
    d.rectangle([0, 6, W - 1, H - 1], fill=st[1][1], outline=st[0])  # painted deck slab
    d.line([1, 7, W - 2, 7], fill=st[1][3])
    d.ellipse([W // 2 - 20, 6, W // 2 + 20, H - 1], outline=YELLOW)  # circle
    hx = W // 2
    d.rectangle([hx - 6, 8, hx - 4, H - 3], fill=WHITE)           # the H
    d.rectangle([hx + 4, 8, hx + 6, H - 3], fill=WHITE)
    d.rectangle([hx - 4, H // 2 + 2, hx + 4, H // 2 + 3], fill=WHITE)
    for lx in (2, W - 4):                                         # edge lights
        d.rectangle([lx, 3, lx + 1, 6], fill=RED, outline=OUT)


def draw_crane(d, W, H):
    mt = RAMPS["metal"]
    mx = 10                                                       # mast x-centre
    for i in range(10, H - 4, 6):                                 # mast lattice
        d.line([mx - 3, i, mx + 3, i + 6], fill=ORANGE)
        d.line([mx + 3, i, mx - 3, i + 6], fill=ORANGE)
        d.line([mx - 3, i, mx - 3, i + 6], fill=(240, 150, 70))
        d.line([mx + 3, i, mx + 3, i + 6], fill=(180, 100, 40))
    d.rectangle([2, H - 4, 18, H - 1], fill=mt[1][0], outline=mt[0])  # ballast base
    d.rectangle([mx - 4, 4, W - 1, 8], fill=ORANGE, outline=OUT)  # jib
    for jx in range(mx + 2, W - 4, 6):
        d.line([jx, 8, jx + 4, 4], fill=(240, 150, 70))
    d.rectangle([mx - 4, 0, mx + 4, 4], fill=mt[1][1], outline=mt[0])  # cab top
    d.rectangle([0, 5, mx - 4, 7], fill=mt[1][0])                 # counter-jib
    d.line([W - 8, 9, W - 8, 20], fill=mt[1][0])                  # hoist line
    d.rectangle([W - 10, 20, W - 6, 24], fill=mt[1][1], outline=mt[0])  # hook block


def draw_davit_arm(d, W, H):
    mt = RAMPS["metal"]
    d.rectangle([2, H - 4, W - 3, H - 1], fill=mt[1][0], outline=mt[0])  # base
    d.rectangle([6, 10, 9, H - 4], fill=mt[1][2], outline=mt[0])  # column
    d.line([7, 11, 7, H - 5], fill=mt[1][3])
    d.rectangle([6, 6, W - 4, 9], fill=mt[1][2], outline=mt[0])   # arm
    d.line([9, 9, W - 8, 12], fill=mt[1][0])                      # stay cable
    d.line([W - 6, 10, W - 6, H - 12], fill=mt[1][0])             # fall line
    d.rectangle([W - 8, H - 12, W - 4, H - 9], fill=YELLOW, outline=OUT)  # winch


def draw_window_rig(d, W, H):
    mt = RAMPS["metal"]
    for lx in (4, W - 6):                                         # suspension lines
        d.line([lx, 0, lx, H - 10], fill=mt[1][0])
    d.rectangle([1, H - 10, W - 2, H - 6], fill=BLUE, outline=OUT)  # platform
    d.line([2, H - 9, W - 3, H - 9], fill=(140, 180, 220))
    d.rectangle([1, H - 14, W - 2, H - 13], fill=mt[1][2])        # guardrail
    for px in range(3, W - 3, 6):
        d.line([px, H - 13, px, H - 10], fill=mt[1][1])
    d.rectangle([3, H - 5, 9, H - 1], fill=YELLOW, outline=OUT)   # motor L
    d.rectangle([W - 10, H - 5, W - 4, H - 1], fill=YELLOW, outline=OUT)  # motor R


def draw_anchor_point(d, W, H):
    mt = RAMPS["metal"]
    d.rectangle([2, H - 4, W - 3, H - 1], fill=mt[1][1], outline=mt[0])  # plate
    d.ellipse([5, 2, 10, 8], outline=YELLOW)                      # eye ring
    d.rectangle([6, 8, 9, H - 4], fill=mt[1][2], outline=mt[0])   # post
    d.point((7, 9), fill=mt[2])


def draw_big_sign(d, W, H):
    mt = RAMPS["metal"]
    d.rectangle([4, H - 6, 8, H - 1], fill=mt[1][0])              # posts
    d.rectangle([W - 9, H - 6, W - 5, H - 1], fill=mt[1][0])
    box(d, 0, 2, W - 1, H - 8, mt, bevel=False)                   # panel
    d.rectangle([2, 4, W - 3, H - 10], fill=(30, 34, 52), outline=OUT)  # dark face
    for lx, c in ((6, TEAL), (20, TEAL), (34, PINK), (48, TEAL), (62, YELLOW)):
        d.rectangle([lx, 8, lx + 8, H - 14], fill=c, outline=OUT)  # glowing letters
        d.rectangle([lx + 2, 10, lx + 6, H - 16], fill=(30, 34, 52))
    d.line([2, 4, W - 3, 4], fill=(80, 90, 120))                  # top sheen


def draw_logo_sign(d, W, H):
    mt = RAMPS["metal"]
    d.rectangle([W // 2 - 2, H - 8, W // 2 + 1, H - 1], fill=mt[1][0], outline=mt[0])
    d.ellipse([2, 2, W - 3, H - 10], fill=(30, 34, 52), outline=OUT)  # disc
    d.ellipse([8, 8, W - 9, H - 16], outline=TEAL)                # glowing ring
    d.ellipse([14, 14, W - 15, H - 22], fill=TEAL)                # core dot
    d.line([4, 6, W - 8, 6], fill=(80, 90, 120))


def draw_crown(d, W, H):
    mt, st = RAMPS["metal"], RAMPS["stone"]
    d.rectangle([0, H - 8, W - 1, H - 1], fill=st[1][1], outline=st[0])  # parapet base
    d.line([1, H - 7, W - 2, H - 7], fill=st[1][3])
    for inset, top in ((8, H - 8), (16, H - 22), (24, H - 34)):   # setback tiers
        d.rectangle([inset, top, W - 1 - inset, H - 8], fill=mt[1][1], outline=mt[0])
        d.line([inset + 1, top + 1, W - 2 - inset, top + 1], fill=mt[1][3])
        for wx in range(inset + 3, W - 3 - inset, 5):             # crown windows
            d.rectangle([wx, top + 4, wx + 2, top + 9], fill=YELLOW)
    d.rectangle([W // 2, 2, W // 2 + 1, H - 34], fill=mt[1][2])   # spire
    d.point((W // 2, 1), fill=RED)


def draw_lightning_rod(d, W, H):
    mt = RAMPS["metal"]
    d.rectangle([W // 2, 0, W // 2, H - 6], fill=mt[1][3])        # rod
    d.point((W // 2, 0), fill=(226, 226, 220))                    # air terminal
    d.rectangle([W // 2 - 2, H - 8, W // 2 + 2, H - 6], fill=mt[1][1], outline=mt[0])  # clamp
    d.rectangle([2, H - 6, W - 3, H - 1], fill=mt[1][0], outline=mt[0])  # base
    for cy in range(4, H - 10, 8):                                # earthing cable loops
        d.line([W // 2 + 1, cy, W // 2 + 3, cy + 4], fill=(140, 110, 70))
        d.line([W // 2 + 3, cy + 4, W // 2 + 1, cy + 8], fill=(140, 110, 70))


def draw_roof_hatch(d, W, H):
    mt = RAMPS["metal"]
    box(d, 0, 2, W - 1, H - 1, mt, bevel=False)                   # frame
    d.line([1, 3, W - 2, 3], fill=mt[2])
    for vx in range(4, W - 4, 5):                                 # vent louvers
        d.rectangle([vx, 5, vx + 2, H - 4], fill=mt[1][0])
        d.line([vx, 5, vx, H - 4], fill=(20, 24, 30))
    d.rectangle([0, 2, 2, H - 1], fill=mt[1][1], outline=mt[0])   # hinge blocks
    d.rectangle([W - 3, 2, W - 1, H - 1], fill=mt[1][1], outline=mt[0])
    d.rectangle([W // 2 - 2, H - 5, W // 2 + 2, H - 3], fill=YELLOW, outline=OUT)  # latch plate
    d.point((W // 2, H - 4), fill=OUT)                            # padlock eye


# ------------------------------------------------------------------ trees
# Detailed Terraria-style trees (user request 2026-09-01): lumpy canopies
# built from overlapping ellipses filled with clumped multi-tone leaf
# texture (deterministic hash, no random), dark silhouette outline, bark
# streaks and knots on tapered trunks, branch stubs with leaf tufts, and
# flared roots.

from PIL import Image as _Image, ImageDraw as _ImageDraw  # noqa: E402


def _lhash(x, y):
    return ((x * 73856093) ^ (y * 19349663)) & 0x7FFFFFFF


def _leafy(d, ellipses, W, H, seed=0):
    """Fill the union of `ellipses` with clumped leaf texture, outlined."""
    o, tones, hl = LEAF
    mask = _Image.new("1", (W, H), 0)
    md = _ImageDraw.Draw(mask)
    for e in ellipses:
        md.ellipse(e, fill=1)
    px = mask.load()

    def inside(x, y):
        return 0 <= x < W and 0 <= y < H and px[x, y]

    xs = [e[0] for e in ellipses] + [e[2] for e in ellipses]
    ys = [e[1] for e in ellipses] + [e[3] for e in ellipses]
    bx0, bx1, by0, by1 = min(xs), max(xs), min(ys), max(ys)
    for y in range(max(by0, 0), min(by1 + 1, H)):
        for x in range(max(bx0, 0), min(bx1 + 1, W)):
            if not inside(x, y):
                continue
            if not (inside(x - 1, y) and inside(x + 1, y) and inside(x, y - 1) and inside(x, y + 1)):
                d.point((x, y), fill=o)
                continue
            shade = ((x - bx0) / max(bx1 - bx0, 1)) * 0.35 + ((y - by0) / max(by1 - by0, 1)) * 0.65
            t = 3 - int(round(shade * 3))
            h = _lhash((x // 2) + seed, y // 2)      # 2x2 leaf clumps
            t = max(0, min(3, t + (h % 3) - 1))
            c = tones[t]
            if h % 19 == 0 and t >= 2:
                c = hl                                # sunlit sparkle
            d.point((x, y), fill=c)


def _trunk(d, x0, y0, x1, y1, taper=0):
    """Tapered trunk with bark streaks: lit left edge, shaded right."""
    o, t, hl = RAMPS["wood"]
    d.polygon([(x0 + taper, y0), (x1 - taper, y0), (x1, y1), (x0, y1)], fill=t[1], outline=o)
    d.line([x0 + taper + 1, y0 + 1, x0 + 1, y1 - 1], fill=t[3])
    d.line([x1 - taper - 1, y0 + 1, x1 - 1, y1 - 1], fill=t[0])
    for i, sx in enumerate(range(x0 + 2, x1 - 2, 3)):
        col = t[0] if i % 2 else t[2]
        y = y0 + 2 + (i * 5) % 6
        while y < y1 - 2:                                # dashed bark streaks
            dash = 3 + (sx * 7 + y) % 3
            d.line([sx + ((y // 9) % 2), y, sx + ((y // 9) % 2), min(y + dash, y1 - 2)], fill=col)
            y += dash + 2 + (sx + y) % 3


def _knot(d, x, y):
    o, t, hl = RAMPS["wood"]
    d.rectangle([x, y, x + 2, y + 1], fill=t[0], outline=o)
    d.point((x + 1, y), fill=t[2])


def draw_tree_sapling(d, W, H):
    wd = RAMPS["wood"]
    d.rectangle([W // 2 - 1, H - 12, W // 2, H - 1], fill=wd[1][1], outline=wd[0])  # stem
    d.point((W // 2 - 1, H - 8), fill=wd[1][3])
    d.point((W // 2, H - 5), fill=wd[1][0])
    _leafy(d, [(1, 2, 14, 15), (0, 6, 11, 18), (5, 5, 15, 17), (3, 0, 13, 9)], W, H, seed=5)
    d.rectangle([W // 2 - 4, H - 3, W // 2 + 3, H - 1], fill=(90, 70, 50))  # soil mound
    d.point((W // 2 - 3, H - 3), fill=(120, 96, 66))


def draw_tree_young(d, W, H):
    # Lanky adolescent (user reference): a thin trunk most of the height,
    # separate leaf clumps at the branch points, a small crown on top.
    wd = RAMPS["wood"]
    cx = W // 2
    _trunk(d, cx - 2, 16, cx + 2, H - 1, taper=1)
    d.polygon([(cx - 5, H - 1), (cx - 2, H - 7), (cx - 1, H - 1)], fill=wd[1][1], outline=wd[0])  # root flare
    d.polygon([(cx + 1, H - 1), (cx + 2, H - 7), (cx + 5, H - 1)], fill=wd[1][0], outline=wd[0])
    _knot(d, cx - 1, H - 40)
    # short branches, alternating sides, each ending in its own clump
    d.line([cx - 2, 44, cx - 10, 36], fill=wd[1][1])
    d.line([cx - 2, 45, cx - 10, 37], fill=wd[1][0])
    d.line([cx + 2, 66, cx + 11, 57], fill=wd[1][1])
    d.line([cx + 2, 67, cx + 11, 58], fill=wd[1][0])
    d.line([cx - 2, 88, cx - 11, 80], fill=wd[1][1])
    d.line([cx - 2, 89, cx - 11, 81], fill=wd[1][0])
    _leafy(d, [(1, 24, 19, 40), (4, 30, 16, 44)], W, H, seed=9)            # clump 1
    _leafy(d, [(W - 20, 46, W - 2, 62), (W - 16, 52, W - 4, 66)], W, H, seed=13)  # clump 2
    _leafy(d, [(2, 70, 18, 85), (5, 76, 15, 89)], W, H, seed=17)           # clump 3
    _leafy(d, [(cx - 9, 0, cx + 9, 20), (cx - 6, 8, cx + 11, 26)], W, H, seed=2)  # crown


def draw_tree_mature(d, W, H):
    wd = RAMPS["wood"]
    cx = W // 2
    _trunk(d, cx - 6, 100, cx + 6, H - 1, taper=2)
    # flared roots
    d.polygon([(cx - 14, H - 1), (cx - 6, H - 14), (cx - 4, H - 1)], fill=wd[1][1], outline=wd[0])
    d.polygon([(cx + 4, H - 1), (cx + 6, H - 14), (cx + 14, H - 1)], fill=wd[1][0], outline=wd[0])
    d.line([cx - 12, H - 2, cx - 6, H - 12], fill=wd[1][3])
    _knot(d, cx - 3, H - 60)
    _knot(d, cx + 1, H - 96)
    # branch stubs, Terraria-style: short diagonals ending in leaf tufts
    d.line([cx - 6, H - 84, cx - 17, H - 95], fill=wd[1][1])
    d.line([cx - 6, H - 83, cx - 17, H - 94], fill=wd[1][0])
    d.line([cx + 6, H - 116, cx + 18, H - 127], fill=wd[1][1])
    d.line([cx + 6, H - 115, cx + 18, H - 126], fill=wd[1][0])
    _leafy(d, [(2, H - 112, 26, H - 88)], W, H, seed=21)        # left tuft
    _leafy(d, [(W - 26, H - 144, W - 2, H - 120)], W, H, seed=27)  # right tuft
    # the crown: a big lumpy union reaching just past the trunk top
    _leafy(d, [(8, 8, W - 8, 116), (0, 34, 44, 108), (W - 44, 28, W, 104),
               (18, 0, W - 14, 56), (2, 14, 38, 68), (W - 40, 4, W - 2, 70),
               (14, 40, W - 10, 122)], W, H, seed=3)
    d.rectangle([cx - 8, H - 2, cx + 7, H - 1], fill=(90, 70, 50))  # root soil
    d.point((cx - 6, H - 2), fill=(120, 96, 66))


def _y(i, mn, mx):
    return {"item": i, "min": mn, "max": mx}


ITEMS = [
    {"id": "roof_hvac", "name": "HVAC Unit", "category": "roof",
     "size": [3, 2], "zones": ["roof"], "room_type": "roof",
     "weight": 30, "tool_tier": 1, "skill": 1, "scrap_time": 3.5, "xp": 8,
     "yields": [_y("scrap_metal", 6, 10), _y("plastic", 2, 4)],
     "draw": draw_hvac},
    {"id": "roof_cooling_tower", "name": "Cooling Tower", "category": "roof",
     "size": [4, 3], "zones": ["roof"], "room_type": "roof",
     "weight": 45, "tool_tier": 1, "skill": 1, "scrap_time": 4.5, "xp": 10,
     "yields": [_y("scrap_metal", 8, 14), _y("plastic", 3, 6)],
     "draw": draw_cooling_tower},
    {"id": "roof_exhaust_fan", "name": "Exhaust Fan", "category": "roof",
     "size": [2, 2], "zones": ["roof"], "room_type": "roof",
     "weight": 14, "tool_tier": 0, "skill": 0, "scrap_time": 2.0, "xp": 4,
     "yields": [_y("scrap_metal", 3, 5), _y("plastic", 1, 2)],
     "draw": draw_exhaust_fan},
    {"id": "roof_vent_duct", "name": "Ventilation Duct", "category": "roof",
     "size": [3, 1], "zones": ["roof"], "room_type": "roof",
     "weight": 8, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
     "yields": [_y("scrap_metal", 3, 5)],
     "draw": draw_vent_duct},
    {"id": "roof_boiler_stack", "name": "Boiler Stack", "category": "roof",
     "size": [2, 6], "zones": ["roof"], "room_type": "roof",
     "weight": 40, "tool_tier": 1, "skill": 1, "scrap_time": 4.0, "xp": 9,
     "yields": [_y("scrap_metal", 5, 8), _y("stone", 4, 8)],
     "draw": draw_boiler_stack},
    {"id": "roof_pipes", "name": "Pipe Run", "category": "roof",
     "size": [3, 1], "zones": ["roof"], "room_type": "roof",
     "weight": 9, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
     "yields": [_y("scrap_metal", 3, 5), _y("plastic", 1, 2)],
     "draw": draw_pipes},
    {"id": "roof_antenna_array", "name": "Antenna Array", "category": "roof",
     "size": [2, 5], "zones": ["roof"], "room_type": "roof",
     "weight": 16, "tool_tier": 1, "skill": 1, "scrap_time": 3.0, "xp": 7,
     "yields": [_y("scrap_metal", 4, 7), _y("plastic", 2, 4)],
     "draw": draw_antenna_array},
    {"id": "roof_comm_mast", "name": "Communication Mast", "category": "roof",
     "size": [2, 9], "zones": ["roof"], "room_type": "roof",
     "weight": 35, "tool_tier": 1, "skill": 2, "scrap_time": 5.0, "xp": 12,
     "yields": [_y("scrap_metal", 10, 16)],
     "draw": draw_comm_mast},
    {"id": "roof_satellite_dish", "name": "Satellite Dish", "category": "roof",
     "size": [3, 3], "zones": ["roof"], "room_type": "roof",
     "weight": 22, "tool_tier": 1, "skill": 1, "scrap_time": 3.0, "xp": 7,
     "yields": [_y("scrap_metal", 5, 8), _y("plastic", 2, 4)],
     "draw": draw_satellite_dish},
    {"id": "roof_radio_antenna", "name": "Radio Antenna", "category": "roof",
     "size": [1, 4], "zones": ["roof"], "room_type": "roof",
     "weight": 6, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
     "yields": [_y("scrap_metal", 2, 4), _y("plastic", 1, 2)],
     "draw": draw_radio_antenna},
    {"id": "roof_comm_cabinet", "name": "Comms Cabinet", "category": "roof",
     "size": [2, 3], "zones": ["roof"], "room_type": "roof",
     "weight": 24, "tool_tier": 1, "skill": 1, "scrap_time": 3.0, "xp": 7,
     "storage_slots": 8,
     "yields": [_y("scrap_metal", 5, 8), _y("plastic", 2, 4)],
     "draw": draw_comm_cabinet},
    {"id": "roof_transformer", "name": "Transformer", "category": "roof",
     "size": [2, 2], "zones": ["roof"], "room_type": "roof",
     "weight": 32, "tool_tier": 1, "skill": 2, "scrap_time": 3.5, "xp": 9,
     "yields": [_y("scrap_metal", 6, 9), _y("plastic", 1, 3)],
     "draw": draw_transformer},
    {"id": "roof_switchgear", "name": "Switchgear Panel", "category": "roof",
     "size": [2, 3], "zones": ["roof"], "room_type": "roof",
     "weight": 26, "tool_tier": 1, "skill": 1, "scrap_time": 3.0, "xp": 7,
     "yields": [_y("scrap_metal", 4, 7), _y("plastic", 2, 4)],
     "draw": draw_switchgear},
    {"id": "roof_cable_tray", "name": "Cable Tray", "category": "roof",
     "size": [3, 1], "zones": ["roof"], "room_type": "roof",
     "weight": 7, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
     "yields": [_y("scrap_metal", 2, 4), _y("plastic", 1, 3)],
     "draw": draw_cable_tray},
    {"id": "roof_generator", "name": "Standby Generator", "category": "roof",
     "size": [3, 2], "zones": ["roof"], "room_type": "roof",
     "weight": 38, "tool_tier": 1, "skill": 2, "scrap_time": 4.0, "xp": 10,
     "yields": [_y("scrap_metal", 8, 13), _y("plastic", 2, 4)],
     "draw": draw_generator},
    {"id": "roof_helipad", "name": "Helipad Markings", "category": "roof",
     "size": [6, 1], "zones": ["roof"], "room_type": "roof",
     "weight": 20, "tool_tier": 1, "skill": 0, "scrap_time": 3.0, "xp": 5,
     "yields": [_y("stone", 4, 8), _y("scrap_metal", 1, 3)],
     "draw": draw_helipad},
    {"id": "roof_crane", "name": "Rooftop Crane", "category": "roof",
     "size": [5, 9], "zones": ["roof"], "room_type": "roof",
     "weight": 60, "tool_tier": 2, "skill": 2, "scrap_time": 6.0, "xp": 16,
     "yields": [_y("scrap_metal", 16, 26)],
     "draw": draw_crane},
    {"id": "roof_davit_arm", "name": "Davit Arm", "category": "roof",
     "size": [3, 4], "zones": ["roof"], "room_type": "roof",
     "weight": 28, "tool_tier": 1, "skill": 1, "scrap_time": 3.5, "xp": 8,
     "yields": [_y("scrap_metal", 6, 10)],
     "draw": draw_davit_arm},
    {"id": "roof_window_rig", "name": "Window-Washing Rig", "category": "roof",
     "size": [3, 2], "zones": ["roof"], "room_type": "roof",
     "weight": 20, "tool_tier": 0, "skill": 1, "scrap_time": 2.5, "xp": 6,
     "yields": [_y("scrap_metal", 4, 7), _y("cloth", 1, 2)],
     "draw": draw_window_rig},
    {"id": "roof_anchor", "name": "Platform Anchor", "category": "clutter",
     "size": [1, 1], "zones": ["roof"], "room_type": "roof",
     "weight": 4, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
     "yields": [_y("scrap_metal", 1, 2)],
     "draw": draw_anchor_point},
    {"id": "roof_sign", "name": "Illuminated Sign", "category": "roof",
     "size": [5, 3], "zones": ["roof"], "room_type": "roof",
     "weight": 30, "tool_tier": 1, "skill": 1, "scrap_time": 4.0, "xp": 9,
     "yields": [_y("scrap_metal", 5, 9), _y("plastic", 3, 6)],
     "draw": draw_big_sign},
    {"id": "roof_logo_sign", "name": "Corporate Logo", "category": "roof",
     "size": [3, 3], "zones": ["roof"], "room_type": "roof",
     "weight": 18, "tool_tier": 1, "skill": 0, "scrap_time": 2.5, "xp": 6,
     "yields": [_y("scrap_metal", 3, 6), _y("plastic", 2, 4)],
     "draw": draw_logo_sign},
    {"id": "roof_crown", "name": "Architectural Crown", "category": "roof",
     "size": [6, 5], "zones": ["roof"], "room_type": "roof",
     "weight": 55, "tool_tier": 2, "skill": 2, "scrap_time": 6.0, "xp": 14,
     "yields": [_y("scrap_metal", 8, 14), _y("stone", 6, 10)],
     "draw": draw_crown},
    {"id": "roof_lightning_rod", "name": "Lightning Rod", "category": "roof",
     "size": [1, 6], "zones": ["roof"], "room_type": "roof",
     "weight": 8, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
     "yields": [_y("scrap_metal", 3, 5)],
     "draw": draw_lightning_rod},
    {"id": "roof_hatch", "name": "Roof Vent Hatch", "category": "roof",
     "size": [3, 1], "zones": ["roof"], "room_type": "roof",
     "weight": 20, "tool_tier": 1, "skill": 0, "scrap_time": 2.0, "xp": 0,
     "yields": [],
     "kind": "door", "fixed": True, "no_item": True, "lock_tier": 1,
     "desc": "Bolted over the shaft. A pry bar or better forces it - the way inside.",
     "draw": draw_roof_hatch},
    # Trees (user request): a growth-stage roll each midnight; wood on harvest.
    {"id": "tree_sapling", "name": "Tree Sapling", "category": "flora", "flora_weight": 3,
     "size": [1, 2], "zones": ["roof"], "room_type": "roof",
     "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
     "yields": [_y("wood", 1, 2)],
     "grows_into": "tree_young", "grow_chance": 0.5,
     "desc": "Plant it on a sunny roof; it grows a little every night.",
     "draw": draw_tree_sapling},
    {"id": "tree_young", "name": "Young Tree", "category": "flora", "flora_weight": 1,
     "size": [3, 8], "zones": ["roof"], "room_type": "roof",
     "weight": 30, "tool_tier": 1, "skill": 0, "scrap_time": 6.0, "xp": 6,
     "requires_tool": "axe",
     "yields": [_y("wood", 8, 14)],
     "grows_into": "tree_mature", "grow_chance": 0.35, "no_item": True,
     "draw": draw_tree_young},
    {"id": "tree_mature", "name": "Mature Tree", "category": "flora", "flora_weight": 1,
     "size": [5, 15], "zones": ["roof"], "room_type": "roof",
     "weight": 90, "tool_tier": 1, "skill": 1, "scrap_time": 14.0, "xp": 12,
     "requires_tool": "axe",
     "yields": [_y("wood", 25, 40)],
     "no_item": True,
     "draw": draw_tree_mature},
]


def draw_side_vent(d, W, H):
    mt = RAMPS["metal"]
    box(d, 0, 0, W - 1, H - 1, mt, bevel=False)                   # frame
    d.line([1, 1, W - 2, 1], fill=mt[2])
    for vy in range(4, H - 3, 4):                                 # louvers
        d.rectangle([3, vy, W - 4, vy + 1], fill=mt[1][0])
        d.line([3, vy, W - 4, vy], fill=(20, 24, 30))
    for c in ((1, 1), (W - 2, 1), (1, H - 2), (W - 2, H - 2)):    # corner bolts
        d.point(c, fill=mt[1][3])
    d.rectangle([W // 2 - 2, H - 6, W // 2 + 2, H - 4], fill=YELLOW, outline=OUT)  # latch
    d.point((W // 2, H - 5), fill=OUT)                            # padlock eye


def draw_roof_bush(d, W, H):
    wd = RAMPS["wood"]
    d.rectangle([W // 2 - 1, H - 6, W // 2, H - 1], fill=wd[1][1], outline=wd[0])  # stub stems
    d.line([W // 2 - 4, H - 2, W // 2 - 2, H - 6], fill=wd[1][0])
    _leafy(d, [(1, 4, W - 2, H - 4), (0, 9, W // 2 + 3, H - 2), (W // 2 - 4, 1, W - 1, H - 8)], W, H, seed=31)


def draw_roof_grass(d, W, H):
    o, tones, hl = LEAF
    for i, x in enumerate(range(1, W - 1, 2)):                    # blades
        top = 3 + ((x * 11) % 7)
        c = tones[1 + ((x + i) % 3)]
        d.line([x, H - 2, x + (1 if i % 2 else -1), top], fill=c)
        if i % 3 == 0:
            d.point((x, top - 1), fill=hl)
    d.rectangle([0, H - 2, W - 1, H - 1], fill=(90, 70, 50))      # soil line
    d.point((2, H - 2), fill=tones[0])
    d.point((W - 3, H - 2), fill=tones[0])


# ------------------------------------------- overgrowth + abandonment pass
# (user request 2026-09-01: the roofs read old and abandoned - ~30% of gear
# rolls a vined twin at gen; junk piles are pure dressing, hammer-cleared.)

VINE_DK = (34, 72, 40)
VINE_MD = (56, 110, 62)
VINE_LT = (96, 160, 94)


def _draw_vines(d, W, H):
    """Overgrowth overlay: drooping strands off the top edge, leaf pairs,
    and an ivy mound in a bottom corner. Deterministic (no random)."""
    for i, x in enumerate(range(2, W - 2, 5)):
        length = ((x * 13 + W) % max(H // 2, 4)) + max(H // 6, 3)
        for y in range(0, min(length, H - 2)):
            xo = x + ((y // 3) % 2)
            d.point((xo, y), fill=VINE_DK if i % 2 else VINE_MD)
            if y % 4 == 2:
                d.point((xo + 1, y), fill=VINE_MD)
                d.point((xo - 1, y + 1), fill=VINE_LT if y % 8 == 2 else VINE_MD)
    d.ellipse([-3, H - 6, 7, H + 2], fill=VINE_DK, outline=(18, 34, 22))
    d.point((2, H - 5), fill=VINE_MD)
    d.point((4, H - 4), fill=VINE_LT)
    d.ellipse([W - 6, H - 5, W + 2, H + 2], fill=VINE_DK, outline=(18, 34, 22))
    d.point((W - 4, H - 4), fill=VINE_MD)


def _vined(base_draw):
    def draw(d, W, H):
        base_draw(d, W, H)
        _draw_vines(d, W, H)
    return draw


def draw_junk_pile(d, W, H):
    st, wd, mt = RAMPS["stone"], RAMPS["wood"], RAMPS["metal"]
    d.polygon([(2, H - 1), (10, 5), (22, 8), (34, 3), (W - 3, H - 1)],
              fill=st[1][1], outline=st[0])                       # rubble heap
    d.line([12, 7, 20, H - 2], fill=wd[1][1])                     # planks
    d.line([26, 6, 36, H - 2], fill=wd[1][2])
    d.rectangle([6, H - 6, 12, H - 3], fill=mt[1][1], outline=mt[0])  # bent panel
    d.line([30, 5, 40, 9], fill=mt[1][2])                         # pipe stub
    d.point((16, 6), fill=st[2])
    d.point((33, 4), fill=st[1][3])


def draw_fallen_mast(d, W, H):
    mt = RAMPS["metal"]
    d.line([2, H - 3, W - 10, H - 8], fill=mt[1][2])              # toppled spar
    d.line([2, H - 2, W - 10, H - 7], fill=mt[1][0])
    for t in range(6, W - 14, 8):                                 # snapped bracing
        d.line([t, H - 4 - t // 12, t + 3, H - 9], fill=mt[1][1])
    d.rectangle([W - 10, H - 10, W - 7, H - 6], fill=mt[1][1], outline=mt[0])  # bent tip
    d.line([W - 7, H - 8, W - 3, H - 3], fill=mt[1][0])           # dangling stay
    d.rectangle([0, H - 3, 4, H - 1], fill=mt[1][0], outline=mt[0])  # sheared base
    d.point((3, H - 6), fill=RED)                                 # dead beacon


def draw_tarp_crates(d, W, H):
    wd, nv = RAMPS["wood"], RAMPS["navy"]
    d.rectangle([2, 6, 14, H - 1], fill=wd[1][2], outline=wd[0])  # crates
    d.rectangle([16, 9, 28, H - 1], fill=wd[1][1], outline=wd[0])
    d.polygon([(0, 8), (10, 1), (26, 4), (W - 1, 10), (W - 3, H - 1), (2, H - 2)],
              fill=nv[1][2], outline=nv[0])                       # draped tarp
    d.line([4, 6, 24, 4], fill=nv[1][3])                          # fold light
    d.line([8, 10, 26, 12], fill=nv[1][0])                        # fold shadow
    d.line([W - 4, 10, W - 1, H - 4], fill=nv[1][1])              # loose corner


ITEMS.extend([
    {"id": "side_vent", "name": "Wall Vent Grate", "category": "roof",
     "size": [2, 2], "zones": ["roof"], "room_type": "roof",
     "weight": 12, "tool_tier": 1, "skill": 0, "scrap_time": 2.0, "xp": 0,
     "yields": [],
     "kind": "door", "fixed": True, "no_item": True, "lock_tier": 1,
     "desc": "A padlocked grate over a breach in the wall. A pry bar or better forces it.",
     "draw": draw_side_vent},
    {"id": "roof_bush", "name": "Rooftop Bush", "category": "flora", "flora_weight": 2,
     "size": [2, 2], "zones": ["roof"], "room_type": "bush",
     "weight": 6, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 2,
     "yields": [{"item": "wood", "min": 1, "max": 2}],
     "draw": draw_roof_bush},
    {"id": "roof_grass", "name": "Grass Tuft", "category": "flora", "flora_weight": 3,
     "size": [1, 1], "zones": ["roof"], "room_type": "grass",
     "weight": 1, "tool_tier": 0, "skill": 0, "scrap_time": 0.5, "xp": 1,
     "yields": [],
     "draw": draw_roof_grass},
])

_JUNK = [
    {"id": "roof_junk_pile", "name": "Debris Pile", "size": [3, 1], "draw": draw_junk_pile},
    {"id": "roof_fallen_mast", "name": "Fallen Mast", "size": [4, 1], "draw": draw_fallen_mast},
    {"id": "roof_tarp_crates", "name": "Tarped Crates", "size": [2, 1], "draw": draw_tarp_crates},
]
for _j in _JUNK:
    _j.update({"category": "roof", "zones": ["roof"], "room_type": "roof",
               "kind": "decal", "no_item": True, "weight": 0,
               "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 0, "yields": []})
ITEMS.extend(_JUNK)

# Vined twins for the gear (same stats and yields; CityGen swaps ~30% in).
_VINE_SKIP = {"roof_hatch", "roof_anchor", "side_vent"}
_vined_items = []
for _it in list(ITEMS):
    if _it["id"] in _VINE_SKIP or _it.get("kind") in ("decal", "door")             or _it.get("category") == "flora":
        continue
    _v = dict(_it)
    _v["id"] = _it["id"] + "_vined"
    _v["name"] = _it["name"] + " (overgrown)"
    _v["draw"] = _vined(_it["draw"])
    _vined_items.append(_v)
ITEMS.extend(_vined_items)
