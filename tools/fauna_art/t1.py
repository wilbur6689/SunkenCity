"""T1 "The Dry" creature drawers for the Bestiary Grid builder (tools/build_fauna.py).

Every drawer follows the contract in fauna_art/common.py: `d_x(d, f, p, c)` paints
ONE transparent c x c frame (f = 0..3) with flat fills, base art facing RIGHT; the
builder adds the 1 px dark outline. Ground creatures stand on y = c - 3, fliers and
swimmers are centred. Keep 1 px of margin on every side: the outline is drawn on
the whole 4-frame strip, so art touching a frame edge bleeds into its neighbour.

Palette notes: `p` comes from build_fauna.palette(); a few looks trip the wrong
family there ("heat-scarRED", "coveRED", "pale eyes" on a dark eel), so a couple of
drawers re-tone themselves from the look text (see `tones`).
"""
import math

from fauna_art.common import legs, wag

FRAMES = 4
WING = (214, 226, 236)          # translucent insect wing
WING_DARK = (150, 168, 190)     # a fly's smoky wing
BONE = (240, 238, 226)          # teeth, claws, talon tips
PINK = (226, 156, 150)          # noses, naked tails, ear insides
HORN = (206, 176, 96)           # beaks, talons, hooves
WATER = (120, 176, 196)         # strider dimples
FUNGUS = (196, 222, 160)        # mold rabbit growth
OIL = (104, 84, 132)            # oily sheen on the slug

TONES = {                        # local re-tones keyed by a word in the look
    "dark": dict(body=(52, 50, 58), light=(96, 94, 104), dark=(18, 18, 22)),
    "pale": dict(body=(196, 186, 176), light=(232, 226, 220), dark=(96, 84, 78)),
    "gray": dict(body=(120, 122, 128), light=(178, 180, 186), dark=(40, 42, 48)),
}


# ---- tiny pixel helpers -----------------------------------------------------
def R(d, x0, y0, x1, y1, col):
    if x1 < x0:
        x0, x1 = x1, x0
    if y1 < y0:
        y0, y1 = y1, y0
    d.rectangle([x0, y0, x1, y1], fill=col)


def P(d, x, y, col):
    d.point((x, y), fill=col)


def L(d, pts, col, w=1):
    d.line(pts, fill=col, width=w)


def E(d, x0, y0, x1, y1, col):
    d.ellipse([x0, y0, x1, y1], fill=col)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def tones(p, word):
    """A copy of p re-toned to the family `word` when the look names it
    (the eye stays black when the look asks for black/dark eyes)."""
    look = p["_look"]
    if word in look and word in TONES:
        q = dict(p)
        q.update(TONES[word])
        if "black eyes" in look or "dark eyes" in look or "swollen" in look:
            q["eye"] = (20, 20, 24)
        return q
    return p


def gait(f, amp=1):
    """Leg swing for a walk: forward, pass, back, pass."""
    return [amp, 0, -amp, 0][f]


def bob(f):
    """Body lift on the pass frames of a walk."""
    return [0, -1, 0, -1][f]


def quad(d, f, p, pairs, y, h, w=1, amp=1):
    """Two legs per pair root x: the near leg swings +s, the far one -s (mid tone).
    Consecutive pairs swing opposite (diagonal gait). Legs span rows y .. y+h-1."""
    s = gait(f, amp)
    far = mix(p["dark"], p["body"], 0.45)
    for i, x in enumerate(pairs):
        sg = s if i % 2 == 0 else -s
        R(d, x - sg, y, x - sg + w - 1, y + h - 1, far)
    for i, x in enumerate(pairs):
        sg = s if i % 2 == 0 else -s
        R(d, x + sg, y, x + sg + w - 1, y + h - 1, p["dark"])


# ---- mammals ----------------------------------------------------------------
def d_rat(d, f, p, c, long=False, big_ears=False):
    """Rat; the ceiling mouse gets big round ears, a smaller body and long thin limbs."""
    look = p["_look"]
    mouse = big_ears or "mouse" in look
    G = c - 3
    b = bob(f)
    belly = mix(p["body"], p["light"], 0.6)
    tail = mix(PINK, p["dark"], 0.35)
    x0 = 3 if long else (5 if mouse else 4)
    # naked tail, wagging
    L(d, [(x0 + 1, G - 2 + b), (1, G - 3 + b + wag(f))], tail)
    # body + lighter belly
    E(d, x0, G - 5 + b, 11, G - 1 + b, p["body"])
    E(d, x0 + 1, G - 3 + b, 10, G - 1 + b, belly)
    # head, snout, nose, eye
    E(d, 9, G - 5 + b, 13, G - 2 + b, p["body"])
    P(d, 14, G - 3 + b, p["body"])
    P(d, 14, G - 4 + b, PINK)
    P(d, 12, G - 4 + b, p["eye"])
    # ears
    if mouse:
        E(d, 9, G - 8 + b, 11, G - 6 + b, p["body"])
        E(d, 12, G - 8 + b, 14, G - 6 + b, p["body"])
        P(d, 10, G - 7 + b, PINK)
        P(d, 13, G - 7 + b, PINK)
    else:
        R(d, 11, G - 6 + b, 11, G - 6 + b, p["body"])
        P(d, 11, G - 6 + b, mix(p["body"], PINK, 0.5))
    # legs (the mouse's are long and thin)
    quad(d, f, p, (x0 + 2, 10), G - 1, 2, amp=1)


def d_weasel(d, f, p, c):
    """Long low tube, pale, bounding arch, dark eye, fangs."""
    G = c - 3
    arch = [0, 1, 0, 0][f]
    belly = mix(p["body"], p["light"], 0.6)
    # tail with a dark tip
    L(d, [(3, G - 3), (1, G - 5 + wag(f))], p["body"])
    P(d, 1, G - 5 + wag(f), p["dark"])
    # body: column by column so the middle can arch
    for x in range(2, 12):
        top = G - 4 - (arch if 4 <= x <= 9 else 0)
        R(d, x, top, x, top + 2, p["body"])
        if 3 <= x <= 10:
            P(d, x, top + 2, belly)
    # head, ear, eye, nose, oversized teeth
    R(d, 11, G - 5, 14, G - 3, p["body"])
    P(d, 11, G - 5, belly)
    P(d, 12, G - 6, p["body"])
    P(d, 13, G - 4, p["eye"])
    P(d, 14, G - 4, p["dark"])
    P(d, 14, G - 2, BONE)
    P(d, 12, G - 2, BONE)
    # short legs
    quad(d, f, p, (4, 10), G - 1, 2, amp=1)


def d_squirrel(d, f, p, c):
    """Hunched body, big curling tail behind, round head, oversized black eye."""
    p = tones(p, "gray")
    G = c - 3
    look = p["_look"]
    tw = [0, 1, 1, 0][f]
    tail = p["light"] if "hairless" in look else mix(p["body"], p["light"], 0.4)
    belly = mix(p["body"], p["light"], 0.5)
    # tail: up the back and curling forward over the body
    R(d, 1, G - 7, 3, G - 2, tail)
    R(d, 2, G - 9, 5 + tw, G - 8, tail)
    R(d, 1, G - 8, 3, G - 8, tail)
    P(d, 2, G - 7, mix(tail, p["dark"], 0.3))
    # body + belly
    E(d, 4, G - 6, 10, G - 1, p["body"])
    E(d, 5, G - 4, 9, G - 1, belly)
    # head, ears, eye, nose
    E(d, 9, G - 8, 13, G - 5, p["body"])
    P(d, 10, G - 9, p["body"])
    P(d, 12, G - 9, p["body"])
    R(d, 11, G - 7, 12, G - 6, p["eye"])
    P(d, 14, G - 6, PINK if "hairless" in look else p["dark"])
    # translucent skin patches
    if "translucent" in look:
        P(d, 6, G - 5, p["light"])
        P(d, 7, G - 3, p["light"])
        P(d, 9, G - 5, p["light"])
    # front paw + legs
    P(d, 10, G - 3, p["dark"])
    quad(d, f, p, (6, 9), G - 1, 2, amp=1)


def d_possum(d, f, p, c):
    """Grey body, pale pointed face, swollen dark eyes, naked pink tail, long claws."""
    G = c - 3
    b = bob(f)
    look = p["_look"]
    tail = mix(PINK, p["dark"], 0.3)
    belly = mix(p["body"], p["light"], 0.45)
    # naked tail, furry at the root
    L(d, [(5, G - 4 + b), (2, G - 8 + b + wag(f)), (1, G - 6 + b + wag(f))], tail)
    R(d, 5, G - 5 + b, 6, G - 4 + b, p["body"])
    # body, belly, patchy fur
    E(d, 5, G - 9 + b, 17, G - 2 + b, p["body"])
    E(d, 7, G - 5 + b, 15, G - 2 + b, belly)
    P(d, 8, G - 7 + b, p["dark"])
    P(d, 12, G - 8 + b, p["dark"])
    P(d, 14, G - 6 + b, p["dark"])
    # pointed pale face with round dark ears
    d.polygon([(15, G - 9 + b), (22, G - 5 + b), (15, G - 3 + b)], fill=p["light"])
    E(d, 15, G - 11 + b, 17, G - 9 + b, p["dark"])
    E(d, 18, G - 11 + b, 20, G - 9 + b, p["dark"])
    P(d, 16, G - 10 + b, PINK)
    P(d, 19, G - 10 + b, PINK)
    # swollen eyes (a red rim when the look says so), pink nose
    R(d, 18, G - 7 + b, 19, G - 6 + b, p["eye"])
    if "swollen" in look:
        P(d, 18, G - 5 + b, (200, 90, 90))
    P(d, 22, G - 5 + b, PINK)
    # legs with long claws
    quad(d, f, p, (8, 15), G - 2, 3, w=2, amp=1)
    s = gait(f)
    P(d, 17 + s, G, BONE)
    P(d, 10 - s, G, BONE)


def d_canine(d, f, p, c):
    """Feral dog: deep chest, enlarged jaw with teeth, running legs.
    Hyena look: sloped back, bristle mane, spots, dark stains round the mouth."""
    G = c - 3
    look = p["_look"]
    hyena = "hyena" in look or "stains" in look
    b = [0, -1, -1, 0][f]
    belly = mix(p["body"], p["light"], 0.4)
    # tail
    if hyena:
        L(d, [(5, G - 8 + b), (3, G - 5 + b + wag(f))], p["body"])
    else:
        L(d, [(5, G - 10 + b), (3, G - 13 + b + wag(f))], p["body"], w=2)
    # body
    if hyena:
        d.polygon([(5, G - 7 + b), (7, G - 9 + b), (12, G - 11 + b), (17, G - 11 + b), (17, G - 4 + b), (5, G - 4 + b)], fill=p["body"])
        R(d, 9, G - 12 + b, 14, G - 12 + b, p["dark"])                # bristle mane
        R(d, 11, G - 13 + b, 13, G - 13 + b, p["dark"])
        for sx, sy in ((7, G - 6), (9, G - 8), (11, G - 5), (13, G - 8), (15, G - 6)):
            P(d, sx, sy + b, p["dark"])                                 # spots
    else:
        d.rounded_rectangle([5, G - 10 + b, 17, G - 4 + b], radius=2, fill=p["body"])
        R(d, 12, G - 11 + b, 16, G - 10 + b, p["body"])                # powerful shoulders
        P(d, 8, G - 7 + b, p["dark"])                                   # patchy dirty fur
        P(d, 10, G - 9 + b, p["dark"])
        R(d, 13, G - 6 + b, 14, G - 6 + b, p["dark"])
    R(d, 7, G - 5 + b, 15, G - 4 + b, belly)
    # head: skull, ears, snout + enlarged lower jaw, eye, teeth
    E(d, 15, G - 15 + b, 21, G - 9 + b, p["body"])
    R(d, 16, G - 16 + b, 17, G - 15 + b, p["body"])
    R(d, 19, G - 16 + b, 19, G - 15 + b, p["body"])
    R(d, 19, G - 12 + b, 22, G - 9 + b, p["body"])
    R(d, 19, G - 8 + b, 22, G - 7 + b, mix(p["body"], p["dark"], 0.35))
    R(d, 20, G - 8 + b, 22, G - 8 + b, BONE)
    P(d, 22, G - 10 + b, p["dark"])
    P(d, 19, G - 13 + b, p["eye"])
    if "stains" in look:
        P(d, 21, G - 7 + b, (110, 30, 30))
        P(d, 19, G - 9 + b, (110, 30, 30))
        P(d, 22, G - 6 + b, (110, 30, 30))
    # running legs: two pairs, wide swing
    quad(d, f, p, (7, 15), G - 4 + b, 4 - b, w=2, amp=2)


def d_mole(d, f, p, c):
    """Fat low body, flattened oversized skull, pink snout, huge pale digging claws, no eyes."""
    G = c - 3
    dig = [0, 1, 2, 1][f]
    claw = mix(BONE, p["light"], 0.3)
    skull = mix(p["body"], p["dark"], 0.5)
    belly = mix(p["body"], p["light"], 0.3)
    dust = (176, 174, 166)
    # humped body, lighter belly, a little dust in the fur
    E(d, 3, G - 9, 16, G, p["body"])
    E(d, 5, G - 4, 14, G, belly)
    P(d, 7, G - 8, dust)
    P(d, 11, G - 9, dust)
    # flattened oversized skull: a hard wedge lower than the back, pink snout, no eyes
    d.polygon([(13, G - 7), (21, G - 7), (22, G - 5), (22, G - 3), (21, G - 2), (13, G - 2)], fill=skull)
    R(d, 14, G - 7, 21, G - 7, p["dark"])
    R(d, 22, G - 5, 22, G - 4, PINK)
    P(d, 21, G - 4, PINK)
    # digging claws: far hand tucked under the chin, near hand stroking forward
    R(d, 15, G - 2, 18, G, mix(claw, p["body"], 0.5))
    R(d, 17 + dig, G - 2, 20 + dig, G, claw)
    for cy in (G - 2, G - 1, G):
        P(d, 21 + dig, cy, BONE)
    P(d, 19 + dig, G - 1, mix(claw, p["dark"], 0.5))
    # back foot
    R(d, 6, G - 1, 8, G, p["dark"])
    if f == 2:                                                          # kicked-up dust
        P(d, 22, G - 8, dust)
        P(d, 20, G - 10, dust)


def d_goat(d, f, p, c):
    """Thin body on unusually long legs, neck up to a small head with big swept horns."""
    G = c - 3
    s = gait(f)
    far = mix(p["dark"], p["body"], 0.45)
    belly = mix(p["body"], p["light"], 0.4)
    horn = mix(p["light"], HORN, 0.4)
    # legs first (behind the body): long, thin, hooved
    for i, x in enumerate((7, 14)):
        sg = s if i == 0 else -s
        R(d, x - sg, G - 7, x - sg, G, far)
        R(d, x + sg, G - 7, x + sg, G, p["dark"])
    # body + belly + patches + stub tail
    d.rounded_rectangle([6, G - 11, 15, G - 7], radius=1, fill=p["body"])
    R(d, 7, G - 7, 14, G - 7, belly)
    P(d, 9, G - 10, p["dark"])
    P(d, 12, G - 9, p["dark"])
    P(d, 5, G - 12, p["body"])
    P(d, 5, G - 11, p["body"])
    # neck + head + muzzle + beard + ear + eye
    L(d, [(15, G - 10), (19, G - 15)], p["body"], w=3)
    R(d, 18, G - 17, 21, G - 14, p["body"])
    R(d, 21, G - 16, 22, G - 14, belly)
    P(d, 21, G - 13, p["light"])
    P(d, 21, G - 12, p["light"])
    P(d, 17, G - 16, p["body"])
    P(d, 20, G - 16, p["eye"])
    P(d, 22, G - 15, p["dark"])
    # oversized horns sweeping back
    L(d, [(19, G - 17), (17, G - 19), (15, G - 20)], horn, w=1)
    L(d, [(21, G - 17), (20, G - 19), (18, G - 20)], horn, w=1)
    P(d, 19, G - 18, horn)
    P(d, 21, G - 18, horn)


def d_horse(d, f, p, c):
    """Thin horse with a heavy muscular neck, dark mane, cloudy eye, patchy coat, gallop."""
    G = c - 3
    s = gait(f, 2)
    b = [0, 1, 1, 0][f]
    far = mix(p["dark"], p["body"], 0.45)
    belly = mix(p["body"], p["light"], 0.35)
    eye = p["eye"] if sum(p["eye"]) > 500 else (220, 240, 255)
    # far legs
    for i, x in enumerate((7, 20)):
        sg = s if i == 0 else -s
        R(d, x - sg, G - 12 + b, x - sg + 1, G, far)
        R(d, x - sg, G, x - sg + 1, G, p["dark"])
    # tail
    L(d, [(5, G - 17 + b), (3, G - 9 + b + wag(f))], p["dark"], w=2)
    # body (thin), belly, ribs, patches
    d.rounded_rectangle([5, G - 19 + b, 24, G - 12 + b], radius=3, fill=p["body"])
    R(d, 8, G - 13 + b, 21, G - 12 + b, belly)
    for rx in (12, 14, 16):
        R(d, rx, G - 16 + b, rx, G - 14 + b, mix(p["body"], p["light"], 0.2))
    R(d, 9, G - 18 + b, 11, G - 17 + b, p["dark"])
    P(d, 19, G - 15 + b, p["dark"])
    R(d, 7, G - 14 + b, 8, G - 14 + b, p["dark"])
    # near legs with hooves
    for i, x in enumerate((7, 20)):
        sg = s if i == 0 else -s
        R(d, x + sg, G - 12 + b, x + sg + 1, G, p["body"])
        R(d, x + sg, G - 6 + b, x + sg + 1, G, mix(p["body"], p["dark"], 0.4))
        R(d, x + sg, G, x + sg + 1, G, p["dark"])
    # muscular neck + mane
    d.polygon([(17, G - 19 + b), (22, G - 20 + b), (25, G - 26 + b), (29, G - 25 + b), (25, G - 15 + b), (20, G - 13 + b)], fill=p["body"])
    L(d, [(19, G - 20 + b), (25, G - 27 + b)], p["dark"], w=2)
    # head, ears, muzzle, nostril, cloudy eye
    d.rounded_rectangle([24, G - 27 + b, 30, G - 23 + b], radius=1, fill=p["body"])
    R(d, 25, G - 28 + b, 25, G - 28 + b, p["body"])
    R(d, 27, G - 28 + b, 27, G - 28 + b, p["body"])
    R(d, 29, G - 25 + b, 30, G - 23 + b, mix(p["body"], p["dark"], 0.3))
    P(d, 30, G - 24 + b, p["dark"])
    P(d, 27, G - 26 + b, eye)


def d_rabbit(d, f, p, c):
    """White rabbit hopping: ears up on the ground, laid back in the air; fungal patches."""
    G = c - 3
    hop = [0, -1, -2, -1][f]
    yb = G - 1 + hop
    look = p["_look"]
    shade = mix(p["body"], p["dark"], 0.35)
    # hind legs
    if f == 0:
        R(d, 3, G - 1, 7, G, shade)
    else:
        L(d, [(4, yb), (2, yb + 2)], shade, w=2)
    # body, fluffy tail, patchy fur
    E(d, 3, yb - 5, 11, yb, p["body"])
    R(d, 2, yb - 4, 3, yb - 3, p["light"])
    P(d, 6, yb - 3, shade)
    P(d, 8, yb - 2, shade)
    # head, eye, nose
    E(d, 9, yb - 7, 13, yb - 4, p["body"])
    P(d, 12, yb - 6, p["eye"])
    P(d, 14, yb - 5, PINK)
    # ears
    if f == 0:
        R(d, 9, yb - 11, 10, yb - 7, p["body"])
        R(d, 12, yb - 11, 13, yb - 7, p["body"])
        P(d, 10, yb - 9, PINK)
        P(d, 13, yb - 9, PINK)
        if "fungal" in look:
            P(d, 9, yb - 10, FUNGUS)
            P(d, 12, yb - 8, FUNGUS)
    else:
        L(d, [(10, yb - 7), (6, yb - 9)], p["body"], w=2)
        L(d, [(12, yb - 7), (8, yb - 10)], p["body"], w=1)
        if "fungal" in look:
            P(d, 7, yb - 9, FUNGUS)
    if "fungal" in look:
        P(d, 5, yb - 4, FUNGUS)
        P(d, 7, yb - 5, FUNGUS)
        P(d, 9, yb - 3, FUNGUS)
    # front paws
    if f == 0:
        R(d, 9, G, 10, G, shade)
    else:
        P(d, 10, yb + 1, shade)


# ---- insects & crawlers -----------------------------------------------------
def d_winged_insect(d, f, p, c):
    """Cicada / wasp / fly from the look: wasp = banded abdomen + long stinger,
    fly = fat blue-black body + cloudy eyes, cicada = stout grey + long clear wings + red eyes."""
    look = p["_look"]
    cy = c // 2
    flap = [-3, -1, 1, -1][f]
    legs(d, f, p, (8, 10, 12), cy + 3, h=1)
    if "yellow" in look:                                               # wasp
        yellow = p["light"]
        d.polygon([(3, cy + 1), (5, cy - 1), (8, cy - 1), (8, cy + 3), (5, cy + 3)], fill=p["body"])
        R(d, 5, cy, 5, cy + 2, yellow)
        R(d, 7, cy - 1, 7, cy + 3, yellow)
        L(d, [(3, cy + 1), (1, cy + 3)], p["dark"])                    # long stinger
        P(d, 9, cy + 1, p["body"])                                      # thin waist
        E(d, 9, cy - 1, 12, cy + 2, p["body"])
        P(d, 10, cy, yellow)
        E(d, 12, cy - 1, 14, cy + 1, p["body"])
        P(d, 14, cy, p["eye"])
        L(d, [(13, cy - 1), (14, cy - 4)], p["dark"])
        d.polygon([(10, cy - 1), (9, cy - 3 + flap), (4, cy - 3 + flap), (3, cy - 2 + flap), (7, cy - 1)], fill=WING)
    elif "blue-black" in look:                                          # fly
        E(d, 3, cy - 1, 9, cy + 4, p["body"])
        R(d, 4, cy + 1, 8, cy + 1, p["light"])
        R(d, 4, cy + 3, 8, cy + 3, p["light"])
        E(d, 8, cy - 2, 12, cy + 2, p["body"])
        E(d, 11, cy - 2, 14, cy + 1, p["body"])
        R(d, 12, cy - 2, 13, cy, p["eye"])                              # cloudy compound eye
        P(d, 13, cy - 1, mix(p["eye"], p["dark"], 0.4))
        d.polygon([(9, cy - 2), (8, cy - 4 + flap), (4, cy - 4 + flap), (3, cy - 3 + flap), (6, cy - 2)], fill=WING_DARK)
    else:                                                               # cicada
        p = tones(p, "gray")
        d.polygon([(2, cy + 1), (3, cy - 1), (11, cy - 1), (11, cy + 2), (3, cy + 3)], fill=p["body"])
        R(d, 4, cy, 9, cy, p["light"])
        R(d, 5, cy + 2, 10, cy + 2, mix(p["body"], p["dark"], 0.4))
        R(d, 10, cy - 2, 14, cy + 1, p["body"])
        R(d, 13, cy - 2, 14, cy - 1, p["eye"])                          # oversized red eye
        d.polygon([(11, cy - 2), (9, cy - 4 + flap), (2, cy - 3 + flap), (1, cy - 2 + flap), (4, cy - 1), (10, cy - 1)], fill=WING)
        L(d, [(9, cy - 3 + flap), (3, cy - 2 + flap)], mix(WING, p["dark"], 0.35))


def d_cricket(d, f, p, c):
    """Pale cricket with a thick abdomen, long trailing antennae and a big hind leg; hop arc."""
    G = c - 3
    hop = [0, -2, -3, -1][f]
    yb = G - 1 + hop
    belly = mix(p["body"], p["light"], 0.5)
    seg = mix(p["body"], p["dark"], 0.3)
    # thick abdomen with segments
    E(d, 4, yb - 3, 11, yb, p["body"])
    R(d, 5, yb, 10, yb, belly)
    for sx in (6, 8, 10):
        P(d, sx, yb - 3, seg)
    # thorax + head + eye
    E(d, 10, yb - 4, 13, yb - 1, p["body"])
    P(d, 12, yb - 3, p["eye"])
    # long antennae sweeping back
    L(d, [(12, yb - 4), (7, yb - 7)], p["dark"])
    L(d, [(13, yb - 4), (9, yb - 8)], p["dark"])
    # hind leg: folded on the ground, extended in the air
    if hop == 0 or f == 3:
        L(d, [(5, yb - 2), (2, yb - 5)], p["dark"], w=1)
        L(d, [(2, yb - 5), (3, G)], p["dark"], w=1)
        P(d, 3, yb - 4, p["dark"])
    else:
        L(d, [(5, yb - 1), (2, yb - 2)], p["dark"], w=1)
        L(d, [(2, yb - 2), (1, yb + 1)], p["dark"], w=1)
    # front legs
    L(d, [(10, yb), (9, yb + 1)], p["dark"])
    L(d, [(12, yb - 1), (13, yb + 1)], p["dark"])


def d_slug(d, f, p, c):
    """Black glossy slug: low blob with a raised front, oily sheen, pale feelers, trail."""
    G = c - 3
    st = [0, 1, 1, 0][f]
    fw = wag(f)
    feeler = (204, 194, 184)
    hi = mix(p["light"], (150, 150, 160), 0.4)
    # body: rear contracts and stretches
    E(d, 3 - st, G - 3, 12, G, p["body"])
    E(d, 9, G - 5, 13, G - 1, p["body"])
    # glossy highlight + oily sheen
    R(d, 5 - st, G - 3, 9, G - 3, hi)
    P(d, 10, G - 5, hi)
    R(d, 6, G - 2, 8, G - 2, OIL)
    P(d, 11, G - 4, OIL)
    # pale feelers (eye stalks) + shorter lower pair
    L(d, [(12, G - 5), (13 + (1 if fw > 0 else 0), G - 8 + (1 if fw < 0 else 0))], feeler)
    L(d, [(11, G - 5), (11 - (1 if fw > 0 else 0), G - 7)], feeler)
    P(d, 13, G - 3, feeler)
    # slimy trail behind
    R(d, 1, G, 2 - st, G, (70, 70, 84))


def d_silverfish(d, f, p, c):
    """Elongated metallic body tapering to three long trailing bristles, short legs."""
    G = c - 3
    w = wag(f)
    seg = mix(p["body"], p["dark"], 0.35)
    # body: flat teardrop, head end right
    d.polygon([(3, G - 2), (6, G - 4), (12, G - 4), (14, G - 3), (14, G - 2), (12, G - 1), (6, G - 1)], fill=p["body"])
    R(d, 7, G - 4, 11, G - 4, p["light"])
    for sx in (6, 8, 10, 12):
        R(d, sx, G - 3, sx, G - 1, seg)
    # head + eye + antennae
    E(d, 11, G - 4, 14, G - 1, p["body"])
    P(d, 13, G - 3, p["eye"])
    L(d, [(13, G - 4), (14, G - 7 + (1 if w > 0 else 0))], seg)
    L(d, [(12, G - 4), (11, G - 7 - (1 if w < 0 else 0))], seg)
    # three trailing bristles
    L(d, [(3, G - 2), (1, G - 5 + w)], seg)
    L(d, [(3, G - 2), (1, G - 2)], seg)
    L(d, [(3, G - 2), (1, G + 1 - w)], seg)
    # legs
    legs(d, f, p, (6, 9, 12), G, h=1)


def d_strider(d, f, p, c):
    """Water strider on the surface: stick body high on four very long legs, dimpled water."""
    p = tones(p, "dark")
    row = 14
    G = c - 3
    far = mix(p["dark"], p["body"], 0.5)
    row_stroke = [0, 2, 3, 1][f]           # middle legs row back and forth
    # body + head + eye
    R(d, 9, row, 15, row + 1, p["body"])
    R(d, 11, row, 13, row, p["light"])
    E(d, 15, row - 1, 17, row + 1, p["body"])
    P(d, 17, row, p["eye"])
    # short front legs
    L(d, [(16, row + 1), (18, row + 3), (19, row + 5)], p["dark"])
    L(d, [(15, row + 1), (17, row + 4)], far)
    # rear legs (back and out), middle legs (forward and out) - far pair first
    for tone, off in ((far, 1), (p["dark"], 0)):
        rk = (5 + off, row - 3)
        rf = (2 + off, G)
        L(d, [(10, row + 1), rk, rf], tone)
        mk = (17 + off + row_stroke // 2, row - 4)
        mf = (21 + off - row_stroke, G)
        L(d, [(12, row), mk, mf], tone)
        # dimples where the feet touch the water
        R(d, rf[0] - 1, G, rf[0] + 1, G, WATER)
        R(d, mf[0] - 1, G, mf[0] + 1, G, WATER)
    R(d, 18, G, 20, G, WATER)


def d_beetle(d, f, p, c):
    """Rebar tick: hard domed segmented body, small head, thin rigid legs."""
    p = tones(p, "dark")
    G = c - 3
    seg = p["light"]
    # domed body with segment ridges
    E(d, 3, G - 7, 12, G - 2, p["body"])
    R(d, 6, G - 6, 6, G - 3, seg)
    R(d, 9, G - 6, 9, G - 3, seg)
    R(d, 5, G - 7, 10, G - 7, mix(p["body"], p["light"], 0.4))
    # head (capitulum) + mouthparts + eye
    R(d, 12, G - 4, 14, G - 3, p["body"])
    P(d, 14, G - 2, p["dark"])
    P(d, 13, G - 4, p["eye"])
    # rigid legs: straight lines, front ones angled forward, rear ones back
    for i, lx in enumerate((4, 6, 9, 11)):
        dx = -1 if lx < 8 else 1
        sw = (f + i) % 2
        L(d, [(lx, G - 2), (lx + dx * (1 + sw), G)], p["dark"])


def d_scorpion(d, f, p, c):
    """Dark scorpion: flat segmented body, thick pincers opening, swollen tail curled over."""
    p = tones(p, "dark")
    G = c - 3
    cb = wag(f)
    op = [0, 1, 1, 0][f]
    seg = mix(p["body"], p["dark"], 0.45)
    hi = mix(p["body"], p["light"], 0.35)
    arm = mix(p["body"], p["light"], 0.15)
    far = mix(p["dark"], p["body"], 0.5)
    # legs (4 pairs) - thin, stepping
    for i, lx in enumerate((8, 10, 12, 14)):
        sw = (f + i) % 2
        L(d, [(lx, G - 2), (lx - 2 + sw, G)], p["dark"])
        L(d, [(lx + 1, G - 2), (lx + sw, G)], far)
    # far pincer, low and behind
    R(d, 17, G - 3, 21, G - 2, far)
    # flat segmented body + head, highlight ridge, heat scars, eye
    R(d, 6, G - 5, 15, G - 2, p["body"])
    R(d, 14, G - 6, 18, G - 2, p["body"])
    R(d, 7, G - 5, 13, G - 5, hi)
    for sx in (8, 10, 12):
        R(d, sx, G - 5, sx, G - 2, seg)
    P(d, 9, G - 4, p["accent"])
    P(d, 11, G - 3, p["accent"])
    P(d, 13, G - 4, p["accent"])
    P(d, 17, G - 6, p["eye"])
    # swollen tail: up from the rear, arching over the back, bulb + stinger pointing forward-down
    L(d, [(6, G - 4), (4, G - 6), (4, G - 9 + cb), (6, G - 12 + cb), (9, G - 13 + cb)], p["body"], w=2)
    P(d, 5, G - 7 + cb // 2, hi)
    P(d, 5, G - 10 + cb, hi)
    E(d, 9, G - 15 + cb, 12, G - 12 + cb, hi)
    L(d, [(12, G - 12 + cb), (14, G - 10 + cb)], p["accent"])
    P(d, 14, G - 9 + cb, p["accent"])
    # near pincer: thick arm, palm, a moving upper finger that opens
    L(d, [(18, G - 4), (20, G - 5)], arm, w=2)
    R(d, 19, G - 7, 21, G - 4, arm)
    R(d, 21, G - 5, 22, G - 4, arm)                                     # fixed lower finger
    R(d, 20, G - 9 - op, 22, G - 8 - op, arm)                           # moving upper finger
    R(d, 19, G - 8 - op, 19, G - 8, arm)
    P(d, 22, G - 4, p["dark"])
    P(d, 22, G - 8 - op, p["dark"])


def d_centipede(d, f, p, c):
    """Long undulating reddish-brown body, dozens of thin legs, dark armoured head."""
    G = c - 3
    seg = mix(p["body"], p["dark"], 0.45)
    hi = mix(p["body"], p["light"], 0.35)
    ys = {}
    for x in range(2, 20):
        s = round(1.0 * math.sin((x + f * 1.6) * 0.75))
        ys[x] = G - 3 + s
    # legs first (behind the body) - a pair every other column, stepping
    for i, x in enumerate(range(3, 20, 2)):
        yy = ys[x]
        sw = ((f + i) % 2)
        L(d, [(x, yy + 1), (x - 1 + sw, G)], p["dark"])
        L(d, [(x + 1, yy + 1), (x + sw, G)], mix(p["dark"], p["body"], 0.5))
        P(d, x, yy - 2, seg)                                            # far-side legs peeking over
    # body (3 tall) with a highlight ridge and segment lines
    for x in range(2, 20):
        yy = ys[x]
        R(d, x, yy - 1, x, yy + 1, p["body"])
        P(d, x, yy - 1, hi)
        if x % 2 == 1:
            R(d, x, yy - 1, x, yy + 1, seg)
    # dark armoured head, eye, antennae, fangs
    E(d, 18, G - 5, 22, G - 1, p["dark"])
    P(d, 21, G - 4, p["eye"])
    L(d, [(21, G - 5), (22, G - 8 + (f % 2))], p["dark"])
    L(d, [(20, G - 5), (20, G - 8 - (f % 2))], p["dark"])
    P(d, 22, G - 1, p["accent"])
    P(d, 22, G - 2, p["accent"])


def d_tortoise(d, f, p, c):
    """Heavy domed shell, cracked and dusted with mineral growth; head bobs, stubby legs."""
    G = c - 3
    hb = [0, 0, -1, 0][f]
    skin = mix(p["body"], (90, 100, 70), 0.4)
    plate = mix(p["body"], p["dark"], 0.5)
    mineral = (166, 176, 144)
    # legs
    quad(d, f, p, (6, 14), G - 2, 3, w=3, amp=1)
    # shell dome + rim
    d.chord([3, G - 11, 18, G + 3], 180, 360, fill=p["body"])
    R(d, 4, G - 4, 17, G - 3, plate)
    R(d, 5, G - 10, 16, G - 10, mix(p["body"], p["light"], 0.5))
    for sx in (7, 11, 15):
        R(d, sx, G - 9, sx, G - 5, plate)
    R(d, 4, G - 7, 17, G - 7, plate)
    L(d, [(8, G - 10), (10, G - 8), (9, G - 6), (11, G - 5)], p["dark"])   # crack
    for mx, my in ((5, G - 8), (13, G - 9), (16, G - 6), (9, G - 6)):
        P(d, mx, my, mineral)
    # tail
    P(d, 3, G - 4, skin)
    P(d, 2, G - 3, skin)
    # neck, head, eye, mouth
    R(d, 17, G - 5 + hb, 19, G - 3 + hb, skin)
    E(d, 18, G - 7 + hb, 22, G - 3 + hb, skin)
    P(d, 21, G - 6 + hb, p["eye"])
    P(d, 22, G - 4 + hb, p["dark"])


def d_snail(d, f, p, c):
    """Pale snail: thick spiral shell on a stretching foot, eye stalks swaying."""
    p = tones(p, "pale")
    G = c - 3
    ext = [0, 1, 1, 0][f]
    sw = wag(f)
    foot = p["light"]
    spiral = p["dark"]
    mineral = (172, 182, 160)
    # foot + head
    R(d, 2, G - 1, 12 + ext, G, foot)
    R(d, 10 + ext, G - 3, 13 + ext, G - 1, foot)
    P(d, 13 + ext, G - 3, mix(foot, p["dark"], 0.4))
    # eye stalks
    L(d, [(12 + ext, G - 4), (13 + ext + (1 if sw > 0 else 0), G - 7)], foot)
    L(d, [(11 + ext, G - 4), (11 + ext - (1 if sw < 0 else 0), G - 6)], foot)
    P(d, 13 + ext + (1 if sw > 0 else 0), G - 7, p["eye"])
    P(d, 11 + ext - (1 if sw < 0 else 0), G - 6, p["eye"])
    # thick spiral shell with mineral deposits
    E(d, 2, G - 10, 10, G - 2, p["body"])
    d.arc([3, G - 9, 9, G - 3], 200, 360 + 150, fill=spiral)
    d.arc([5, G - 7, 8, G - 5], 0, 300, fill=spiral)
    P(d, 6, G - 6, spiral)
    R(d, 4, G - 9, 7, G - 9, mix(p["body"], p["light"], 0.5))
    for mx, my in ((3, G - 5), (8, G - 9), (9, G - 4)):
        P(d, mx, my, mineral)
    # sticky trail
    R(d, 1, G, 1, G, (150, 160, 150))


def d_crab(d, f, p, c):
    """Small red crab: wide scratched shell, eye stalks, oversized claws snapping, scuttling legs."""
    G = c - 3
    op = [0, 1, 1, 0][f]
    hi = mix(p["body"], p["light"], 0.5)
    scratch = mix(p["body"], p["dark"], 0.5)
    # legs (3 per side)
    for i, lx in enumerate((3, 5, 10, 12)):
        dx = -1 if lx < 8 else 1
        sw = (f + i) % 2
        L(d, [(lx, G - 2), (lx + dx * (1 + sw), G)], p["dark"])
    # shell
    E(d, 3, G - 5, 12, G - 2, p["body"])
    R(d, 5, G - 5, 10, G - 5, hi)
    P(d, 5, G - 4, scratch)
    P(d, 6, G - 3, scratch)
    P(d, 9, G - 3, scratch)
    P(d, 10, G - 4, scratch)
    # eye stalks
    P(d, 6, G - 6, p["body"])
    P(d, 9, G - 6, p["body"])
    P(d, 6, G - 7, p["eye"])
    P(d, 9, G - 7, p["eye"])
    # oversized claws: arm + two fingers, the upper one lifts to open
    for ax, cx0, cx1 in ((12, 12, 14), (3, 1, 3)):
        P(d, ax, G - 4, p["body"])
        R(d, cx0, G - 7 - op, cx1, G - 6 - op, p["body"])
        R(d, cx0, G - 5, cx1, G - 4, p["body"])
        P(d, cx0 if ax == 12 else cx1, G - 6 - op, hi)


# ---- reptiles, birds, fish --------------------------------------------------
def d_lizard(d, f, p, c):
    """Low lizard: tapering tail wag, splayed stepping legs, pointed head; red markings on request."""
    G = c - 3
    look = p["_look"]
    thick = "thick" in look
    sb = wag(f)
    belly = mix(p["body"], p["light"], 0.4)
    # tail
    L(d, [(4, G - 2), (1, G - 3 + sb)], p["body"])
    P(d, 3, G - 1, p["body"])
    # body + belly
    E(d, 3, G - 4, 11, G - 1, p["body"])
    R(d, 5, G - 1, 10, G - 1, belly)
    # head + eye
    d.polygon([(10, G - 4), (14, G - 3), (14, G - 2), (10, G - 1)], fill=p["body"])
    P(d, 12, G - 3, p["eye"])
    # markings
    if "red" in look:
        for mx, my in ((5, G - 4), (7, G - 3), (9, G - 4), (11, G - 3), (3, G - 2)):
            P(d, mx, my, p["accent"])
    else:
        R(d, 4, G - 4, 9, G - 4, p["light"])
    # splayed legs: elbow out, foot down
    s = gait(f)
    for i, lx in enumerate((5, 10)):
        sg = s if i == 0 else -s
        L(d, [(lx, G - 2), (lx + sg, G)], p["dark"], w=2 if thick else 1)
        L(d, [(lx + 1, G - 2), (lx + 1 - sg, G - 1)], mix(p["dark"], p["body"], 0.5))


def d_snake(d, f, p, c):
    """Gutter snake slithering; the drain eel (look says 'eel') swims centred, dark, finned."""
    look = p["_look"]
    if "eel" in look:
        return _d_eel(d, f, p, c)
    G = c - 3
    belly = mix(p["body"], p["light"], 0.5)
    band = mix(p["body"], p["dark"], 0.5)
    for x in range(1, 12):
        s = round(1.2 * math.sin((x + f * 1.5) * 0.9))
        y = G - 1 + s
        if x < 3:
            R(d, x, y, x, y, p["body"])
        else:
            R(d, x, y - 1, x, y, p["body"])
            P(d, x, y, belly)
            if x in (4, 7, 10):
                P(d, x, y - 1, band)
    # head + eye + tongue flick
    E(d, 10, G - 3, 13, G - 1, p["body"])
    P(d, 12, G - 3, p["eye"])
    if f in (1, 3):
        P(d, 14, G - 2, (220, 60, 60))


def _d_eel(d, f, p, c):
    cy = c // 2
    body = mix(p["dark"], (16, 16, 20), 0.5)
    fin = mix(p["dark"], p["body"], 0.4)
    eye = (220, 240, 255) if "pale" in p["_look"] else p["eye"]
    ys = {}
    for x in range(1, 14):
        ys[x] = cy + round(1.5 * math.sin((x + f * 1.6) * 0.8))
    for x in range(1, 14):
        y = ys[x]
        if x < 3:
            R(d, x, y, x, y, body)
        else:
            R(d, x, y - 1, x, y, body)
            P(d, x, y - 2, fin)                                          # ribbon dorsal fin
    y = ys[13]
    R(d, 12, y - 1, 14, y + 1, body)
    P(d, 13, y - 1, eye)
    P(d, 14, y + 1, fin)


def d_owl(d, f, p, c):
    """Dark owl in flight: round head with a facial disc and big eyes, pinstriped chest,
    one big wing beating through four poses, long talons trailing."""
    cy = c // 2
    look = p["_look"]
    chest = p["light"]
    wing = mix(p["body"], p["light"], 0.85)
    edge = mix(chest, (200, 200, 210), 0.5)
    tip = [-6, -2, 3, -2][f]
    beak = HORN
    # tail fan behind
    d.polygon([(3, cy + 2), (7, cy), (7, cy + 4), (3, cy + 5)], fill=wing)
    R(d, 3, cy + 3, 4, cy + 3, edge)
    # far wing (small, opposite phase)
    d.polygon([(9, cy - 3), (13, cy - 3), (11, cy - 5 - tip // 2), (7, cy - 4 - tip // 2)], fill=mix(wing, p["dark"], 0.5))
    # body + chest
    E(d, 6, cy - 3, 17, cy + 4, p["body"])
    E(d, 9, cy - 1, 16, cy + 4, chest)
    if "suit" in look or "markings" in look:
        for sx in (11, 13, 15):
            R(d, sx, cy, sx, cy + 3, p["body"])                         # pinstripes
    # near wing: root along the shoulder, tip sweeping up / out / down
    if tip < 0:
        pts = [(8, cy - 2), (14, cy - 2), (12, cy - 3 + tip), (5, cy - 2 + tip), (3, cy + tip), (7, cy)]
    else:
        pts = [(8, cy - 1), (14, cy - 1), (10, cy + 2 + tip), (4, cy + 3 + tip), (2, cy + 1 + tip), (6, cy)]
    d.polygon(pts, fill=wing)
    if tip < 0:                                                         # lit leading edge + feather splits
        L(d, [(12, cy - 3 + tip), (4, cy - 1 + tip)], edge)
        for k in range(3):
            P(d, 4 + k * 2, cy + tip + k, mix(wing, p["dark"], 0.5))
    else:
        L(d, [(9, cy + 2 + tip), (3, cy + 2 + tip)], edge)
        P(d, 5, cy + 1 + tip, mix(wing, p["dark"], 0.5))
    # head, tufts, facial disc, eyes, beak
    E(d, 14, cy - 9, 22, cy - 1, p["body"])
    R(d, 15, cy - 10, 15, cy - 10, p["body"])
    R(d, 21, cy - 10, 21, cy - 10, p["body"])
    E(d, 15, cy - 8, 21, cy - 3, mix(p["body"], chest, 0.75))
    R(d, 16, cy - 7, 17, cy - 6, p["eye"])
    R(d, 19, cy - 7, 20, cy - 6, p["eye"])
    P(d, 17, cy - 6, p["dark"])
    P(d, 20, cy - 6, p["dark"])
    R(d, 18, cy - 5, 18, cy - 4, beak)
    # long talons
    L(d, [(11, cy + 4), (12, cy + 8)], beak)
    L(d, [(14, cy + 4), (15, cy + 8)], beak)
    P(d, 13, cy + 8, beak)
    P(d, 16, cy + 8, beak)


def d_minnow_school(d, f, p, c):
    """A loose school of six tiny silver fish, all heading right, tails flicking."""
    belly = p["light"]
    eye = p["eye"]
    mouth = mix(p["dark"], (20, 20, 24), 0.5)
    for i, (ox, oy) in enumerate(((3, 4), (10, 2), (15, 7), (5, 11), (12, 14), (17, 18))):
        dx = [0, 1, 0, -1][(f + i) % 4]
        wg = (f + i) % 2
        x = ox + dx
        d.polygon([(x - 2, oy - 1 + wg), (x, oy + 1), (x - 2, oy + 3 - wg)], fill=p["body"])
        E(d, x, oy, x + 4, oy + 2, p["body"])
        R(d, x + 1, oy + 2, x + 3, oy + 2, belly)
        P(d, x + 3, oy + 1, eye)
        P(d, x + 5, oy + 1, mouth)                                       # oversized open mouth


def d_mudskipper(d, f, p, c):
    """Brown mudskipper: bulging eyes on top, spiky dorsal fin, tail fin, front fins as legs; hops."""
    G = c - 3
    hop = [0, -2, -3, -1][f]
    yb = G - 1 + hop
    belly = mix(p["body"], p["light"], 0.5)
    fin = mix(p["body"], p["dark"], 0.35)
    # tail fin
    d.polygon([(1, yb - 4), (3, yb - 2), (3, yb), (1, yb + 1)], fill=fin)
    # body + belly
    E(d, 2, yb - 4, 12, yb, p["body"])
    E(d, 4, yb - 2, 11, yb, belly)
    # spiky dorsal fin
    d.polygon([(3, yb - 4), (5, yb - 7), (8, yb - 7), (9, yb - 4)], fill=fin)
    P(d, 5, yb - 6, p["light"])
    P(d, 7, yb - 6, p["light"])
    # head end, mouth
    R(d, 12, yb - 3, 13, yb - 1, p["body"])
    P(d, 13, yb - 1, p["dark"])
    # bulging eyes on top of the head
    R(d, 9, yb - 6, 10, yb - 5, p["light"])
    R(d, 11, yb - 6, 12, yb - 5, p["light"])
    P(d, 10, yb - 5, p["dark"])
    P(d, 12, yb - 5, p["dark"])
    # muscular front fins used as legs
    if hop == 0:
        d.polygon([(9, yb), (11, yb), (12, G), (10, G)], fill=fin)
        d.polygon([(4, yb), (6, yb), (6, G), (4, G)], fill=mix(fin, p["body"], 0.4))
    else:
        d.polygon([(9, yb), (11, yb), (9, yb + 2), (7, yb + 2)], fill=fin)
        d.polygon([(4, yb), (6, yb), (4, yb + 1), (3, yb + 1)], fill=mix(fin, p["body"], 0.4))


DRAW = {"rat": d_rat, "weasel": d_weasel, "squirrel": d_squirrel, "possum": d_possum,
        "winged_insect": d_winged_insect, "cricket": d_cricket, "slug": d_slug, "silverfish": d_silverfish,
        "strider": d_strider, "beetle": d_beetle, "scorpion": d_scorpion, "centipede": d_centipede,
        "tortoise": d_tortoise, "snail": d_snail, "owl": d_owl, "lizard": d_lizard, "snake": d_snake,
        "canine": d_canine, "mole": d_mole, "goat": d_goat, "horse": d_horse, "rabbit": d_rabbit,
        "crab": d_crab, "minnow_school": d_minnow_school, "mudskipper": d_mudskipper}
HITBOX = {}
CELL = {}
