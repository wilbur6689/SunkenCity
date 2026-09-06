"""T2 The Shallows creature drawers (docs/monsters/t2_shallows_fauna.json).

Every creature here lives underwater. Contract in common.py: d is an
ImageDraw on one transparent c x c frame, f the frame 0..3, p the palette
(body / dark / light / eye / accent + "_look"), art faces RIGHT, flat fills
(the builder outlines). Swimmers are centred on y = c // 2; bottom crawlers
sit on y = c - 3; the stationary pair are drawn attached to their structure.
"""
import math

from fauna_art.common import legs, wag

RUST = (146, 78, 40)
RUST_D = (96, 46, 24)
IRON = (86, 90, 98)
IRON_L = (132, 136, 144)
GLASS = (204, 232, 248)
SHELL = (222, 216, 200)
SHELL_D = (160, 152, 136)
PAPER = (236, 230, 212)
INK = (28, 30, 44)
RED_HOT = (250, 70, 30)
RED_GLOW = (255, 160, 70)
NEON_M = (244, 64, 210)
NEON_C = (80, 240, 255)
NEON_Y = (250, 236, 80)
SLIME = (188, 222, 232)
TOXIC = (176, 222, 60)
WHITE = (246, 244, 240)


def _sine(x0, x1, y, f, amp=1.5, k=0.6, phase=1.6):
    return [(x, y + round(amp * math.sin((x + f * phase) * k))) for x in range(x0, x1 + 1)]


def _tail(d, x, y, f, col, h=3, back=3, amp=1):
    """Forked tail whose tip is at x - back, wagging up/down."""
    w = wag(f, amp)
    d.polygon([(x, y), (x - back, y - h + w), (x - back, y + h + w)], fill=col)


def _fish_eye(d, x, y, p):
    d.point((x, y), fill=p["eye"])


# ---- industrial -------------------------------------------------------------
def d_crested_eel(d, f, p, c):
    y = c // 2
    pts = _sine(2, 19, y, f, amp=1.5, k=0.6)
    d.line(pts, fill=p["body"], width=3)
    d.line([(x, yy + 1) for x, yy in pts], fill=p["light"])           # belly sheen
    d.polygon([(3, pts[1][1]), (1, pts[1][1] - 2), (1, pts[1][1] + 2)], fill=p["light"])
    for x, yy in pts[3::5]:                                              # rusted crests, spaced so each reads
        d.polygon([(x - 1, yy - 1), (x, yy - 4), (x + 2, yy - 1)], fill=RUST)
        d.point((x, yy - 3), fill=RUST_D)
    d.ellipse([17, y - 3, 23, y + 2], fill=p["dark"])                    # darker head so it stands off the body
    d.ellipse([18, y - 2, 23, y + 1], fill=p["body"])
    d.line([(20, y + 1), (23, y + 1)], fill=p["dark"])                   # mouth
    d.point((22, y - 1), fill=(240, 220, 120))
    if f % 2:                                                            # shock crackle
        d.point((14, pts[13][1] - 5), fill=NEON_C); d.point((8, pts[7][1] + 4), fill=NEON_C)


def d_sludge_crab(d, f, p, c):
    y = c - 3
    op = [0, 1, 2, 1][f]
    body, sheen = (58, 54, 60), (92, 80, 104)
    d.ellipse([6, y - 8, 18, y - 1], fill=body)
    d.ellipse([8, y - 8, 16, y - 5], fill=sheen)                         # oily sheen
    d.point((10, y - 7), fill=(150, 100, 170)); d.point((14, y - 6), fill=(100, 150, 160))
    d.rectangle([8, y - 10, 10, y - 8], fill=IRON_L); d.rectangle([13, y - 10, 16, y - 9], fill=IRON_L)  # pipe fragments
    d.point((9, y - 9), fill=IRON); d.point((15, y - 10), fill=IRON)
    for dx in (7, 12, 17):                                               # sludge drips
        d.line([(dx, y - 1), (dx, y + (f + dx) % 2)], fill=body)
    d.point((11, y - 10), fill=p["eye"]); d.point((12, y - 10), fill=p["eye"])
    d.line([(11, y - 9), (11, y - 8)], fill=body); d.line([(12, y - 9), (12, y - 8)], fill=body)
    d.ellipse([17, y - 8 - op, 23, y - 3], fill=body); d.ellipse([1, y - 8 - op, 7, y - 3], fill=body)   # heavy claws
    d.line([(20, y - 4 - op), (23, y - 5 - op)], fill=(30, 28, 32)); d.line([(4, y - 4 - op), (1, y - 5 - op)], fill=(30, 28, 32))
    d.point((19, y - 7 - op), fill=sheen); d.point((4, y - 7 - op), fill=sheen)
    for i, lx in enumerate((5, 8, 16, 19)):
        d.line([(lx, y - 2), (lx + (-2 if lx < 12 else 2), y + 1 - ((f + i) % 2))], fill=(30, 28, 32), width=1)


def d_lamprey(d, f, p, c):
    y = c // 2
    body, light = (98, 90, 86), (136, 128, 122)
    pts = _sine(3, 19, y, f, amp=1.0, k=0.7)
    d.line(pts, fill=body, width=5)
    d.line([(x, yy + 2) for x, yy in pts], fill=light)
    d.polygon([(4, pts[1][1]), (1, pts[1][1] - 3), (1, pts[1][1] + 3)], fill=body)
    d.ellipse([17, y - 3, 23, y + 3], fill=body)                          # head
    for i, rx in enumerate((13, 15, 17)):                                # heated throat rings
        hot = RED_HOT if (f + i) % 2 == 0 else RED_GLOW
        d.line([(rx, pts[rx - 2][1] - 2), (rx, pts[rx - 2][1] + 2)], fill=hot)
    d.ellipse([20, y - 2, 23, y + 2], fill=RED_GLOW)                      # round sucker mouth
    d.ellipse([21, y - 1, 22, y + 1], fill=p["dark"])
    d.point((21, y), fill=RED_HOT)
    d.point((19, y - 2), fill=(240, 220, 120))


def d_sea_snake(d, f, p, c):
    y = c // 2
    body, light = (40, 40, 48), (104, 104, 120)
    pts = _sine(2, 19, y, f, amp=1.3, k=0.55)
    d.line(pts, fill=body, width=3, joint="curve")
    d.line([(x, yy - 1) for x, yy in pts], fill=light, joint="curve")     # slick highlight along the back
    for x, yy in pts[1::4]:
        d.point((x, yy - 1), fill=(150, 150, 170))                         # wet glints
    d.polygon([(2, pts[0][1]), (1, pts[0][1] - 3), (1, pts[0][1] + 3)], fill=body)  # paddle tail
    d.rounded_rectangle([18, y - 3, 23, y + 1], radius=2, fill=body)
    d.line([(19, y - 3), (22, y - 3)], fill=light)
    d.point((21, y - 2), fill=TOXIC)                                       # eye
    d.line([(20, y + 1), (23, y + 1)], fill=(60, 60, 70))
    d.point((23, y + 2 - f % 2), fill=(240, 60, 60))                       # flicking tongue
    for i, dx in enumerate((6, 11, 16)):                                   # chemical residue dripping off
        drop = (f + i) % 4
        d.point((dx, pts[dx - 2][1] + 2 + drop), fill=TOXIC)
        d.point((dx, pts[dx - 2][1] + 1), fill=(120, 160, 50))


# ---- construction -----------------------------------------------------------
def d_snapping_turtle(d, f, p, c):
    y = c - 3
    shell, ridge = (84, 92, 70), (54, 60, 44)
    d.chord([3, y - 13, 18, y + 1], 180, 360, fill=shell)
    d.rectangle([3, y - 6, 18, y - 3], fill=shell)
    for bx in (7, 11, 15):
        d.line([(bx, y - 11), (bx, y - 3)], fill=ridge)
    d.line([(4, y - 7), (17, y - 7)], fill=ridge)
    d.line([(6, y - 9), (5, y - 15)], fill=RUST, width=1); d.line([(12, y - 12), (13, y - 17)], fill=RUST)   # rebar out of the shell
    d.line([(9, y - 12), (8, y - 14)], fill=RUST_D); d.point((13, y - 17), fill=RUST_D)
    d.rectangle([2, y - 3, 18, y - 2], fill=ridge)                        # plastron edge
    jaw = [0, 1, 2, 1][f]
    d.rounded_rectangle([16, y - 9, 23, y - 4], radius=2, fill=p["body"])   # heavy head
    d.rectangle([18, y - 4, 23, y - 3 + jaw], fill=p["dark"])              # opening lower jaw
    d.line([(19, y - 4), (23, y - 4)], fill=RUST)                          # rebar fused into the jaw
    d.point((23, y - 5), fill=RUST_D)
    d.point((21, y - 8), fill=p["eye"])
    d.line([(3, y - 3), (0, y - 1 + wag(f))], fill=p["body"], width=2)     # spiked tail
    d.point((1, y - 3 + wag(f)), fill=ridge)
    legs(d, f, p, (5, 14), y - 2, h=4, w=3)


def d_ray(d, f, p, c):
    y = c // 2
    glow = "glowing" in p["_look"]
    body = (56, 52, 78) if glow else p["body"]
    light = (98, 92, 130) if glow else p["light"]
    w = wag(f)
    d.line([(1, y + 2 + w * 2), (6, y)], fill=body, width=2)              # whip tail
    d.point((3, y + 1 + w * 2), fill=p["dark"])
    d.polygon([(5, y), (12, y - 6 + w), (21, y), (12, y + 6 - w)], fill=body)     # top-view diamond
    d.polygon([(8, y), (12, y - 3 + w), (18, y), (12, y + 3 - w)], fill=light)
    if glow:
        for i, (sx, sy, col) in enumerate(((9, y - 1, NEON_M), (12, y - 3, NEON_C), (15, y - 1, NEON_Y),
                                           (12, y + 2, NEON_M), (16, y + 1, NEON_C), (8, y + 1, NEON_Y))):
            if (f + i) % 4 != 3:
                d.point((sx, sy), fill=col)
    else:
        d.line([(8, y - 1), (11, y + 1), (14, y - 2)], fill=p["dark"])      # concrete cracks
        d.line([(12, y + 2), (16, y + 3)], fill=p["dark"])
        d.point((10, y + 3), fill=p["dark"])
    d.point((19, y - 1), fill=p["eye"]); d.point((19, y + 1), fill=p["eye"])


def d_barnacle_leech(d, f, p, c):
    y = c // 2
    pts = _sine(3, 19, y, f, amp=1.2, k=0.7)
    d.line(pts, fill=p["body"], width=4)
    d.line([(x, yy + 1) for x, yy in pts], fill=p["light"])
    for i, (x, yy) in enumerate(pts[1::3]):
        d.line([(x, yy - 2), (x, yy + 2)], fill=p["dark"])                  # segments
        d.polygon([(x - 1, yy - 1), (x + 1, yy - 4), (x + 3, yy - 1)], fill=SHELL if i % 2 == 0 else SHELL_D)  # barnacle plates
    d.ellipse([1, pts[0][1] - 1, 4, pts[0][1] + 1], fill=p["body"])
    d.ellipse([18, y - 2, 23, y + 2], fill=p["body"])                      # sucker head
    d.ellipse([20, y - 1, 23, y + 1], fill=p["dark"])
    d.point((22, y), fill=(200, 60, 60))
    d.point((19, y - 2), fill=p["eye"])


def d_barnacle(d, f, p, c):
    y = c - 3
    d.rectangle([1, y - 4, 22, y], fill=RUST)                              # corroded I-beam stub
    d.rectangle([1, y - 4, 22, y - 4], fill=(180, 110, 60))
    d.rectangle([1, y, 22, y], fill=RUST_D)
    for rx in (3, 9, 16, 20):
        d.point((rx, y - 2), fill=RUST_D)
    d.rectangle([10, y - 12, 13, y - 4], fill=RUST)                        # vertical web with a bolt
    d.point((11, y - 9), fill=IRON_L)
    cones = ((3, y - 4, 5, 4), (7, y - 4, 4, 6), (13, y - 4, 5, 5), (18, y - 4, 4, 4), (9, y - 12, 4, 4), (14, y - 10, 3, 3))
    for i, (bx, by, bw, bh) in enumerate(cones):
        col = SHELL if i % 2 == 0 else SHELL_D
        d.polygon([(bx, by), (bx + bw // 2, by - bh), (bx + bw // 2 + 1, by - bh), (bx + bw, by)], fill=col)
        d.line([(bx + bw // 2, by - bh + 1), (bx + bw // 2 + 1, by - bh + 1)], fill=p["dark"])   # opening
        d.point((bx + 1, by - 1), fill=(120, 116, 104))
    shooter = cones[1]
    tip = (shooter[0] + shooter[2] // 2, shooter[1] - shooter[3])
    if f in (1, 2):                                                        # shard spit
        for k in range(1, 3 + f):
            d.point((tip[0] + k, tip[1] - k - 1), fill=WHITE)
    elif f == 3:
        d.point((tip[0], tip[1] - 1), fill=(240, 120, 120))                # feeding fan
        d.point((tip[0] + 1, tip[1] - 1), fill=(240, 120, 120))


def d_armored_catfish(d, f, p, c):
    y = c // 2
    body, light = (118, 110, 96), (168, 160, 144)
    _tail(d, 5, y, f, body, h=4, back=4)
    d.ellipse([4, y - 4, 19, y + 4], fill=body)
    d.rounded_rectangle([13, y - 4, 22, y + 3], radius=2, fill=body)         # broad flat head
    d.chord([5, y, 21, y + 5], 0, 180, fill=light)                          # belly
    for bx in (7, 10, 13):
        d.line([(bx, y - 4), (bx, y + 1)], fill=(84, 78, 68))               # stone plates
        d.point((bx + 1, y - 3), fill=(190, 184, 170))
    d.polygon([(8, y - 4), (10, y - 8), (12, y - 4)], fill=(84, 78, 68))    # dorsal spine
    d.polygon([(11, y + 4), (9, y + 7 + wag(f)), (14, y + 4)], fill=light)  # pectoral
    d.line([(22, y + 2), (23, y + 6 + wag(f))], fill=light)                 # barbels
    d.line([(21, y + 3), (19, y + 7 - wag(f))], fill=light)
    d.line([(22, y - 1), (23, y - 4 + wag(f))], fill=light)
    d.point((20, y - 2), fill=p["eye"])
    d.line([(21, y + 2), (23, y + 2)], fill=(84, 78, 68))


# ---- business ---------------------------------------------------------------
def d_silt_stalker(d, f, p, c):
    y = c // 2
    ghost, ghost_l = (150, 190, 205, 150), (205, 230, 240, 170)
    _tail(d, 6, y, f, ghost, h=3, back=4)
    d.ellipse([5, y - 3, 19, y + 3], fill=ghost)
    d.polygon([(17, y - 3), (23, y), (17, y + 3)], fill=ghost)
    d.line([(7, y), (18, y)], fill=ghost_l)                                # visible spine
    for bx in (9, 12, 15):
        d.line([(bx, y - 2), (bx, y + 2)], fill=ghost_l)
    d.polygon([(10, y - 3), (12, y - 6), (14, y - 3)], fill=ghost_l)
    for i, (tx, ty) in enumerate(((9, y + 3), (12, y + 3), (15, y + 3))):   # long dark tentacles
        sw = wag((f + i) % 4)
        d.line([(tx, ty), (tx - 4, ty + 3 + sw), (tx - 9, ty + 5 - sw)], fill=p["dark"])
    d.point((20, y - 1), fill=(240, 90, 90))                                # the only solid thing: an eye
    d.point((11, y - 1), fill=p["dark"])                                    # swallowed morsel


def d_squid(d, f, p, c):
    x = c // 2
    sq = [0, 1, 0, -1][f]                                                      # mantle pulse
    body, light = (206, 196, 190), (236, 228, 222)
    d.polygon([(x - 2, 2), (x - 7 + sq, 6), (x - 2, 9)], fill=light)          # lateral fins, swept out
    d.polygon([(x + 2, 2), (x + 7 - sq, 6), (x + 2, 9)], fill=light)
    d.polygon([(x - 3, 1), (x, 0), (x + 3, 1), (x + 4 + sq, 6), (x + 4, 12), (x - 4, 12), (x - 4 - sq, 6)], fill=body)  # tapered mantle
    d.line([(x, 2), (x, 11)], fill=light)                                      # highlight down the mantle
    for k in (3, 6, 9):
        d.point((x - 2, k), fill=(180, 150, 150))                              # chromatophore flecks
    d.polygon([(x - 5 - sq, 4), (x - 7, 12), (x - 4, 11), (x - 3, 5)], fill=PAPER)   # shredded documents plastered on
    d.polygon([(x + 3, 5), (x + 5 + sq, 4), (x + 7, 9), (x + 4, 12)], fill=PAPER)
    d.line([(x - 6, 7), (x - 5, 7)], fill=(120, 120, 140)); d.line([(x - 6, 9), (x - 5, 9)], fill=(120, 120, 140))   # print lines
    d.line([(x + 4, 7), (x + 6, 7)], fill=(120, 120, 140))
    d.point((x + 5, 5), fill=(220, 60, 60))                                    # a red "CONFIDENTIAL" stamp corner
    d.rounded_rectangle([x - 4, 12, x + 4, 16], radius=1, fill=body)           # head
    d.ellipse([x - 4, 12, x - 1, 15], fill=WHITE); d.point((x - 2, 13), fill=INK)   # big squid eyes
    d.ellipse([x + 1, 12, x + 4, 15], fill=WHITE); d.point((x + 3, 13), fill=INK)
    for i, ax in enumerate((x - 3, x - 1, x + 1, x + 3)):                      # arms
        sw = wag((f + i) % 4)
        d.line([(ax, 16), (ax + sw, 19), (ax - sw, 22)], fill=body, width=1)
    for i, ax in enumerate((x - 5, x + 5)):                                    # two long feeding tentacles
        sw = wag((f + 2 * i) % 4)
        d.line([(ax, 16), (ax + sw, 20), (ax, 23)], fill=light)
        d.point((ax, 23), fill=body)
    d.polygon([(x, 17), (x - 2, 21), (x + 1, 20)], fill=PAPER)                  # a sheet caught in the arms
    d.point((x + 2, 19), fill=INK); d.point((x - 1, 22), fill=INK)              # ink beads


def d_anglerfish(d, f, p, c):
    y = c // 2
    body, belly = (46, 50, 66), (78, 84, 104)
    _tail(d, 5, y, f, body, h=3, back=3)
    d.ellipse([4, y - 5, 18, y + 6], fill=body)
    d.chord([6, y, 17, y + 6], 0, 180, fill=belly)
    jaw = [1, 2, 3, 2][f]
    d.polygon([(14, y - 3), (23, y - 2), (22, y + 1), (14, y + 1)], fill=body)          # upper jaw
    d.polygon([(14, y + 1), (23, y + 1 + jaw), (15, y + 4 + jaw)], fill=body)           # gaping lower jaw
    d.rectangle([15, y + 1, 21, y + jaw], fill=(150, 40, 60))                           # throat
    for tx in (16, 18, 20, 22):
        d.point((tx, y), fill=WHITE); d.point((tx - 1, y + 1 + jaw), fill=WHITE)         # fangs
    d.point((15, y - 2), fill=(240, 220, 120)); d.point((15, y - 3), fill=WHITE)         # bulging eye
    d.polygon([(8, y - 5), (10, y - 8), (12, y - 5)], fill=belly)                        # small dorsal
    d.polygon([(9, y + 6), (7, y + 8), (12, y + 6)], fill=belly)
    d.line([(12, y - 5), (14, y - 9), (19, y - 10)], fill=belly)                         # lure stalk
    bulb = [NEON_C, NEON_M, (60, 60, 70), NEON_Y][f]                                      # flickering sign bulb
    d.rectangle([19, y - 12, 22, y - 10], fill=bulb)
    d.point((20, y - 11), fill=WHITE if f != 2 else (90, 90, 100))
    if f != 2:
        d.point((18, y - 13), fill=bulb); d.point((23, y - 9), fill=bulb)


def d_moray(d, f, p, c):
    y = c // 2
    pts = _sine(2, 17, y, f, amp=1.6, k=0.55)
    d.line([(x, yy - 3) for x, yy in pts], fill=p["light"], width=1)        # continuous dorsal ribbon
    d.line(pts, fill=p["body"], width=4)
    d.line([(x, yy + 1) for x, yy in pts], fill=(76, 74, 84))
    for x, yy in pts[1::4]:
        d.point((x, yy), fill=(130, 120, 80))                                # mottling
    d.polygon([(2, pts[0][1]), (1, pts[0][1] - 3), (1, pts[0][1] + 3)], fill=p["light"])
    jaw = [1, 2, 2, 1][f]
    d.rounded_rectangle([15, y - 3, 23, y], radius=1, fill=p["body"])        # head
    d.polygon([(15, y), (23, y + jaw), (16, y + 3)], fill=p["body"])          # lower jaw
    d.line([(17, y + 1), (22, y + 1)], fill=(150, 40, 50))                   # throat
    for tx in (18, 20, 22):
        d.point((tx, y), fill=WHITE); d.point((tx - 1, y + 1 + jaw), fill=WHITE)   # needle teeth
    d.point((19, y - 2), fill=(240, 220, 120))
    d.point((23, y - 2), fill=(200, 170, 80))                                 # brass trim caught on the snout


# ---- residential ------------------------------------------------------------
def d_sea_hound(d, f, p, c):
    y = c // 2
    body, slick = (96, 92, 84), (140, 136, 128)
    d.line([(1, y - 3 + wag(f)), (5, y - 1)], fill=body, width=2)             # tail streaming
    d.rounded_rectangle([4, y - 4, 17, y + 2], radius=2, fill=body)
    d.line([(6, y - 3), (14, y - 3)], fill=slick)                              # wet sheen
    d.rounded_rectangle([15, y - 6, 22, y - 1], radius=1, fill=body)           # head
    d.rectangle([18, y - 1, 23, y], fill=body)                                 # muzzle
    d.line([(19, y), (23, y)], fill=WHITE)                                     # bared teeth
    d.polygon([(15, y - 6), (13, y - 8), (16, y - 5)], fill=body)               # ear laid back
    for gx in (15, 16, 17):
        d.line([(gx, y - 1), (gx, y + 1)], fill=(210, 60, 70))                  # external gills
    d.point((20, y - 4), fill=p["eye"])
    for i, lx in enumerate((6, 13)):                                            # paddling webbed paws
        k = ((f + i) % 4)
        py = y + 3 + [0, 1, 2, 1][k]
        d.line([(lx, y + 2), (lx - 1, py)], fill=body, width=2)
        d.polygon([(lx - 2, py), (lx + 1, py), (lx - 1, py + 2)], fill=slick)


def d_pike(d, f, p, c):
    y = c // 2
    body, belly, spot = (92, 108, 62), (168, 176, 118), (60, 74, 40)
    _tail(d, 5, y, f, body, h=4, back=4)
    d.ellipse([4, y - 3, 26, y + 3], fill=body)
    d.chord([6, y, 25, y + 3], 0, 180, fill=belly)
    for sx in range(7, 24, 3):
        d.point((sx, y - 2), fill=spot); d.point((sx + 1, y + 1), fill=belly)
    d.polygon([(23, y - 3), (30, y), (23, y + 3)], fill=body)                   # long flat snout
    d.line([(24, y + 1), (29, y + 1)], fill=p["dark"])                          # jaw line
    for tx in (25, 27, 29):
        d.point((tx, y - 1), fill=WHITE); d.point((tx - 1, y + 2), fill=WHITE)     # teeth protruding
    d.polygon([(9, y - 3), (11, y - 7), (14, y - 3)], fill=belly)                 # dorsal set far back
    d.polygon([(9, y + 3), (11, y + 6), (14, y + 3)], fill=belly)
    d.polygon([(17, y + 3), (15, y + 6 + wag(f)), (20, y + 3)], fill=belly)
    d.point((26, y - 1), fill=(240, 220, 100))


def d_betta(d, f, p, c):
    y = c // 2
    body, fin, fin_d, fin_l = (186, 44, 40), (246, 128, 60), (128, 30, 40), (255, 190, 110)
    w = wag(f)
    d.polygon([(10, y), (2, y - 7 + w), (1, y + w), (2, y + 7 + w)], fill=fin)      # huge tail fan
    for k in range(-6, 7, 2):                                                       # serrated, dark-tipped edge
        d.point((2 if k % 4 else 3, y + k + w), fill=fin_d)
    for k in (-4, 0, 4):
        d.line([(9, y), (4, y + k + w)], fill=fin_l)                                # fin rays
    d.polygon([(10, y - 3), (9, y - 9 - w), (17, y - 7 - w), (17, y - 3)], fill=fin)  # dorsal
    d.polygon([(10, y + 3), (9, y + 9 + w), (17, y + 7 + w), (17, y + 3)], fill=fin)  # anal
    for k in (10, 12, 14, 16):
        d.point((k, y - 8 - w + (k - 10) // 3), fill=fin_d); d.point((k, y + 8 + w - (k - 10) // 3), fill=fin_d)
    d.line([(12, y - 4), (12, y - 7 - w)], fill=fin_l); d.line([(12, y + 4), (12, y + 7 + w)], fill=fin_l)
    d.ellipse([9, y - 3, 19, y + 3], fill=body)
    d.chord([10, y, 18, y + 3], 0, 180, fill=(150, 30, 34))                          # darker belly
    d.line([(11, y - 2), (17, y - 2)], fill=(230, 90, 80))                           # iridescent back
    d.polygon([(17, y - 2), (22, y), (17, y + 2)], fill=body)
    d.polygon([(14, y + 2), (12, y + 5 - w), (17, y + 3)], fill=fin_d)               # pelvic streamer
    d.point((18, y - 1), fill=p["eye"]); d.point((19, y - 1), fill=WHITE)
    d.point((21, y + 1), fill=p["dark"])


# ---- commercial -------------------------------------------------------------
def d_jellyfish(d, f, p, c):
    x = c // 2
    sq = [0, 1, 0, -1][f]
    top, bottom = 3 - sq, 10 + sq
    d.chord([x - 5 - sq, top, x + 5 + sq, bottom + (bottom - top)], 180, 360, fill=NEON_M)   # bell
    d.chord([x - 3 - sq, top + 2, x + 3 + sq, bottom + (bottom - top) - 2], 180, 360, fill=NEON_C)
    d.rectangle([x - 5 - sq, bottom, x + 5 + sq, bottom], fill=(200, 60, 180))
    for i, tx in enumerate(range(x - 4, x + 5, 2)):                                  # tentacles
        sw = wag((f + i) % 4)
        col = NEON_C if i % 2 else NEON_M
        d.line([(tx, bottom + 1), (tx + sw, bottom + 6), (tx - sw, bottom + 11)], fill=col)
    d.line([(x - 1, bottom + 1), (x - 1, bottom + 4)], fill=WHITE, width=2)            # oral arms
    for i, (sx, sy) in enumerate(((x - 7, 6), (x + 7, 4), (x - 6, 13), (x + 7, 12), (x, 1))):   # static sparks
        if (f + i) % 3 == 0:
            d.point((sx, sy), fill=NEON_Y)


def d_mantis_shrimp(d, f, p, c):
    y = c - 3
    body, seg, belly, orange = (58, 148, 96), (34, 100, 70), (120, 200, 140), (240, 130, 40)
    d.rounded_rectangle([4, y - 7, 16, y - 1], radius=2, fill=body)                       # segmented body
    d.line([(5, y - 2), (15, y - 2)], fill=belly)
    for sx in range(6, 16, 3):
        d.line([(sx, y - 7), (sx, y - 3)], fill=seg)
        d.point((sx + 1, y - 6), fill=orange)                                             # colour bands
    d.polygon([(4, y - 4), (1, y - 8 + wag(f)), (1, y + wag(f))], fill=(80, 160, 220))    # telson fan
    d.point((2, y - 4 + wag(f)), fill=orange); d.point((2, y - 6 + wag(f)), fill=(160, 220, 250))
    for gx, gy in ((6, y - 10), (10, y - 11), (13, y - 9)):                                # glass shards riding the back
        d.polygon([(gx, y - 7), (gx + 1, gy), (gx + 3, y - 7)], fill=GLASS)
        d.point((gx + 1, gy + 1), fill=WHITE)
    d.rounded_rectangle([15, y - 7, 20, y - 1], radius=1, fill=(70, 120, 170))            # head shield
    d.rectangle([16, y - 10, 17, y - 8], fill=(60, 200, 255)); d.rectangle([19, y - 10, 20, y - 8], fill=(60, 200, 255))   # stalked eyes
    d.point((16, y - 9), fill=p["dark"]); d.point((19, y - 9), fill=p["dark"])
    d.line([(16, y - 8), (16, y - 7)], fill=seg); d.line([(20, y - 8), (20, y - 7)], fill=seg)
    d.line([(20, y - 5), (23, y - 8)], fill=orange)                                        # antennae
    punch = [0, 0, 3, 1][f]                                                                 # raptorial club strike
    d.rectangle([18, y - 3, 19 + punch, y - 2], fill=(200, 100, 30))
    d.rectangle([19 + punch, y - 4, 21 + punch, y - 1], fill=orange)
    if punch == 3:
        d.point((23, y - 6), fill=WHITE); d.point((23, y), fill=WHITE)                     # cavitation flash
    legs(d, f, p, (6, 9, 12, 15), y - 1, h=2)


def d_crab_swarm(d, f, p, c):
    y = c - 3
    wire = (168, 170, 182)
    d.rectangle([4, y - 10, 20, y - 2], outline=wire)                                     # tipped cart basket
    for gx in range(7, 20, 3):
        d.line([(gx, y - 10), (gx, y - 2)], fill=wire)
    d.line([(4, y - 6), (20, y - 6)], fill=wire)
    d.line([(20, y - 10), (23, y - 13)], fill=wire, width=1)                              # handle
    d.point((5, y), fill=p["dark"]); d.point((19, y), fill=p["dark"])                     # wheels
    d.line([(5, y - 2), (5, y - 1)], fill=wire); d.line([(19, y - 2), (19, y - 1)], fill=wire)
    bone, bone_d = (222, 212, 192), (150, 140, 124)
    for i, (cx, cy) in enumerate(((3, y - 12), (10, y - 8), (16, y - 3), (7, y - 1), (21, y - 7))):
        k = (f + i) % 2
        d.ellipse([cx, cy, cx + 5, cy + 2], fill=bone)
        d.point((cx + 1, cy + 1), fill=bone_d); d.point((cx + 4, cy + 1), fill=bone_d)   # hollow sockets
        d.point((cx - 1, cy - k), fill=bone); d.point((cx + 6, cy - k), fill=bone)         # claws
        d.line([(cx + 1, cy + 3), (cx + k, cy + 4)], fill=bone_d); d.line([(cx + 4, cy + 3), (cx + 5 - k, cy + 4)], fill=bone_d)


# ---- civil ------------------------------------------------------------------
def d_octopus(d, f, p, c):
    y = c - 3
    d.rectangle([0, y - 11, 7, y - 1], fill=IRON)                                          # cast-iron drain pipe
    d.rectangle([6, y - 12, 8, y], fill=IRON_L)                                             # flange
    d.line([(1, y - 10), (5, y - 10)], fill=IRON_L)
    d.point((2, y - 4), fill=RUST); d.point((4, y - 7), fill=RUST_D)
    d.ellipse([7, y - 15, 17, y - 5], fill=p["body"])                                       # mantle
    for mx, my in ((9, y - 12), (13, y - 13), (11, y - 8), (15, y - 9), (14, y - 6)):
        d.point((mx, my), fill=p["light"])                                                  # mottling
    d.ellipse([13, y - 11, 15, y - 9], fill=(240, 220, 120)); d.point((14, y - 10), fill=p["dark"])   # eye
    d.point((11, y - 11), fill=(240, 220, 120)); d.point((11, y - 12), fill=p["dark"])
    for i, (ax, ay, ex) in enumerate(((9, y - 5, 4), (12, y - 5, 12), (15, y - 6, 18), (17, y - 8, 22))):   # arms
        sw = wag((f + i) % 4)
        d.line([(ax, ay), (ax + (ex - ax) // 2, y - 2 + sw), (ex, y - 1 - sw)], fill=p["body"], width=2)
        d.point((ax + (ex - ax) // 2, y - 1 + sw), fill=p["light"])                        # suckers
        d.point((ex - 1, y - sw), fill=p["light"])


def d_gator(d, f, p, c):
    y = c // 2 + 3
    body, belly = p["body"], p["light"]
    grime, rustc = (120, 118, 96), RUST
    tw = wag(f, 2)
    d.line([(1, y + 1 + tw), (6, y - 1), (10, y - 1)], fill=body, width=3)                 # tail
    for tx in (2, 4, 6, 8):
        d.point((tx, y - 3 + (tw if tx < 6 else 0)), fill=grime)                           # tail scutes
    d.rounded_rectangle([8, y - 4, 22, y + 2], radius=2, fill=body)
    d.chord([9, y - 1, 21, y + 3], 0, 180, fill=belly)
    for sx in range(10, 22, 3):
        d.point((sx, y - 4), fill=grime); d.point((sx + 1, y - 2), fill=rustc)              # grime + rust crust
    jaw = [0, 1, 2, 1][f]
    d.rounded_rectangle([20, y - 3, 30, y - 1], radius=1, fill=body)                        # long flat snout
    d.polygon([(21, y - 1), (30, y - 1), (30, y + jaw), (21, y + 1)], fill=body)              # lower jaw
    for tx in (23, 25, 27, 29):
        d.point((tx, y - 1), fill=WHITE); d.point((tx - 1, y + jaw), fill=WHITE)              # teeth
    d.point((28, y - 4), fill=body); d.point((28, y - 2), fill=body)
    d.ellipse([22, y - 5, 24, y - 3], fill=(200, 210, 220)); d.point((23, y - 4), fill=(170, 180, 190))   # blind, clouded eye
    d.point((30, y - 3), fill=p["dark"])
    for i, lx in enumerate((10, 18)):                                                         # short legs paddling
        k = (f + i) % 2
        d.line([(lx, y + 2), (lx - 2 + k * 2, y + 5)], fill=body, width=2)
        d.line([(lx - 3 + k * 2, y + 5), (lx + k * 2, y + 5)], fill=grime)


def d_hagfish(d, f, p, c):
    y = c // 2
    body, light = (148, 128, 130), (190, 172, 172)
    pts = _sine(2, 20, y, f, amp=1.6, k=0.7)
    d.line(pts, fill=body, width=3)
    d.line([(x, yy - 1) for x, yy in pts], fill=light)
    d.polygon([(2, pts[0][1]), (1, pts[0][1] - 2), (1, pts[0][1] + 2)], fill=light)
    d.ellipse([18, y - 2, 23, y + 2], fill=body)                                            # eyeless head
    d.line([(22, y - 1), (23, y - 3)], fill=light); d.line([(23, y), (23, y + 2)], fill=light)   # barbels
    d.point((22, y + 1), fill=p["dark"])                                                    # slit mouth
    for i, sx in enumerate((4, 9, 14)):                                                     # slime strands
        drop = (f + i) % 3
        d.line([(sx, pts[sx - 1][1] + 2), (sx, pts[sx - 1][1] + 3 + drop)], fill=SLIME)
        d.point((sx, pts[sx - 1][1] + 4 + drop), fill=(160, 200, 214))
    d.point((7, pts[6][1]), fill=SLIME); d.point((16, pts[15][1] + 1), fill=SLIME)


def d_urchin(d, f, p, c):
    cx, cy = 12, 11
    wheel = (150, 82, 44)
    d.ellipse([3, 15, 20, 21], outline=wheel, width=2)                                       # valve handwheel
    d.line([(12, 16), (12, 21)], fill=wheel); d.line([(5, 18), (19, 18)], fill=wheel)
    d.rectangle([10, 19, 13, 22], fill=IRON); d.point((11, 20), fill=IRON_L)                  # stem
    d.point((6, 16), fill=RUST_D); d.point((17, 20), fill=RUST_D)
    shell, spine, tip = (70, 30, 92), (40, 18, 56), (150, 100, 190)
    bristle = [0, 1, 0, -1][f]
    for i in range(16):                                                                        # spines
        a = i * math.pi / 8 + (0.1 if f % 2 else 0.0)
        ln = 6 + (bristle if i % 2 else -bristle)
        ex, ey = cx + round(math.cos(a) * ln), cy + round(math.sin(a) * ln)
        ex, ey = max(0, min(23, ex)), max(0, min(23, ey))
        d.line([(cx, cy), (ex, ey)], fill=spine)
        d.point((ex, ey), fill=tip)
    d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=shell)
    d.ellipse([cx - 2, cy - 3, cx + 1, cy - 1], fill=(104, 52, 128))
    d.point((cx, cy), fill=(240, 120, 60))                                                    # aristotle's lantern
    if f == 2:                                                                                 # spine burst
        for a in (0.4, 1.9, 3.5, 5.0):
            d.point((cx + round(math.cos(a) * 10), cy + round(math.sin(a) * 9)), fill=tip)


# ---- open water -------------------------------------------------------------
def d_reef_shark(d, f, p, c):
    y = c // 2
    body, belly = p["body"], p["light"]
    w = wag(f)
    d.polygon([(5, y), (1, y - 6 + w), (3, y + w), (2, y + 4 + w)], fill=body)                  # heterocercal tail
    d.ellipse([4, y - 4, 26, y + 4], fill=body)
    d.polygon([(22, y - 4), (31, y), (22, y + 4)], fill=body)                                   # snout
    d.chord([6, y, 29, y + 4], 0, 180, fill=belly)
    d.polygon([(13, y - 4), (17, y - 10), (20, y - 4)], fill=body)                              # dorsal
    for k in range(3):
        d.point((18 + k, y - 8 + k * 2), fill=belly)                                           # serrated trailing edge
    d.polygon([(15, y + 4), (11, y + 8 - w), (20, y + 4)], fill=body)                           # pectoral
    d.point((12, y + 7 - w), fill=belly)
    d.polygon([(6, y - 4), (7, y - 6), (9, y - 4)], fill=body)                                  # second dorsal
    for gx in (21, 22, 23):
        d.line([(gx, y - 1), (gx, y + 1)], fill=p["dark"])                                      # gill slits
    d.line([(25, y + 2), (30, y + 1)], fill=p["dark"])                                          # mouth
    d.point((26, y + 2), fill=WHITE); d.point((28, y + 2), fill=WHITE)
    d.point((26, y - 1), fill=p["dark"])                                                        # eye


def d_depth_barracuda(d, f, p, c):
    y = c // 2
    body, belly, lat = p["body"], p["light"], (110, 118, 130)
    w = wag(f)
    d.polygon([(4, y), (1, y - 4 + w), (2, y + w), (1, y + 4 + w)], fill=body)                  # forked tail
    d.ellipse([3, y - 2, 27, y + 3], fill=body)
    d.chord([5, y + 1, 26, y + 3], 0, 180, fill=belly)
    d.line([(6, y), (25, y)], fill=lat)                                                          # lateral line
    for sx in range(8, 24, 4):
        d.point((sx, y - 1), fill=lat)
    d.polygon([(23, y - 2), (30, y + 1), (23, y + 3)], fill=body)                                # long jaw
    d.polygon([(23, y + 1), (31, y + 2), (24, y + 3)], fill=body)                                # underbite
    d.point((29, y + 1), fill=WHITE); d.point((27, y), fill=WHITE); d.point((30, y + 3), fill=WHITE)
    d.polygon([(10, y - 2), (12, y - 5), (14, y - 2)], fill=lat)                                 # twin dorsals
    d.polygon([(18, y - 2), (20, y - 5), (22, y - 2)], fill=lat)
    d.polygon([(16, y + 3), (14, y + 5 + w), (19, y + 3)], fill=belly)
    d.rectangle([24, y - 1, 25, y], fill=p["eye"])                                               # glowing yellow eye
    d.point((26, y - 1), fill=(255, 250, 200)); d.point((23, y - 2), fill=(200, 180, 60))


_BAIT = [(4, 9), (7, 6), (10, 4), (14, 4), (17, 6), (19, 9), (20, 12), (18, 15), (15, 17), (11, 18), (7, 17), (4, 14),
         (8, 10), (12, 8), (15, 10), (13, 13), (9, 13), (16, 13), (6, 12), (11, 11), (13, 6), (17, 12), (10, 15), (14, 15)]


def d_bait_ball(d, f, p, c):
    for i, (bx, by) in enumerate(_BAIT):
        k = (f + i) % 4
        ox = [0, 1, 0, -1][k]
        flash = (i + f) % 3 == 0                                                                   # the shimmer rolls through the ball
        d.rectangle([bx + ox - 1, by, bx + ox + 2, by + 1], fill=WHITE if flash else p["light"])
        d.line([(bx + ox - 1, by + 1), (bx + ox + 2, by + 1)], fill=p["light"] if flash else p["body"])
        d.point((bx + ox - 2, by + (k % 2)), fill=p["body"])                                        # tail flick
        d.point((bx + ox + 2, by), fill=p["dark"])                                                 # eye


def d_lionfish(d, f, p, c):
    y = c // 2
    red, white = (200, 60, 50), p["light"]
    w = wag(f)
    for i in range(9):                                                                             # dorsal fan of spines
        sx = 8 + i
        d.line([(sx, y - 3), (sx - 3 + i // 2 + w, y - 10 + abs(i - 4) // 2)], fill=red if i % 2 else white)
    for i in range(5):                                                                             # pectoral fan
        d.line([(13, y + 2), (7 + i * 2 - w, y + 9 - abs(i - 2))], fill=red if i % 2 else white)
    for i in range(4):
        d.line([(9, y + 2), (4 + i * 2, y + 7 - i // 2 - w)], fill=white if i % 2 else red)
    d.polygon([(8, y), (3, y - 4 + w), (3, y + 4 + w)], fill=white)                                # tail
    d.point((4, y - 2 + w), fill=red); d.point((4, y + 2 + w), fill=red)
    d.ellipse([7, y - 3, 18, y + 3], fill=white)
    d.polygon([(16, y - 3), (22, y), (16, y + 3)], fill=white)
    for sx in (9, 12, 15, 18):
        d.line([(sx, y - 3), (sx - 1, y + 3)], fill=red)                                           # stripes
    d.line([(19, y - 1), (22, y)], fill=red)
    d.point((19, y - 1), fill=p["dark"]); d.point((20, y - 1), fill=(240, 220, 120))               # eye
    d.line([(20, y + 1), (22, y + 1)], fill=p["dark"])


DRAW = {"crested_eel": d_crested_eel, "sludge_crab": d_sludge_crab, "lamprey": d_lamprey, "sea_snake": d_sea_snake,
        "snapping_turtle": d_snapping_turtle, "ray": d_ray, "barnacle_leech": d_barnacle_leech, "barnacle": d_barnacle,
        "armored_catfish": d_armored_catfish, "silt_stalker": d_silt_stalker, "squid": d_squid, "anglerfish": d_anglerfish,
        "moray": d_moray, "sea_hound": d_sea_hound, "pike": d_pike, "betta": d_betta, "jellyfish": d_jellyfish,
        "mantis_shrimp": d_mantis_shrimp, "crab_swarm": d_crab_swarm, "octopus": d_octopus, "gator": d_gator,
        "hagfish": d_hagfish, "urchin": d_urchin, "reef_shark": d_reef_shark, "depth_barracuda": d_depth_barracuda,
        "bait_ball": d_bait_ball, "lionfish": d_lionfish}
HITBOX = {}
CELL = {}
