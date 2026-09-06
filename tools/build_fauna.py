"""Bestiary Grid fauna builder (user designs, 2026-09-06).

Reads the design sheets exported from the grid -
  docs/monsters/t0_roof_fauna.json   (T0 Rooftops: night spawns, 4 per district)
  docs/monsters/t1_dry_fauna.json    (T1 The Dry: dry-floor uniques, 4 per
                                      district, + 4 "open water" surface dwellers)
- and writes, idempotently (types tagged `grid_fauna: true` are replaced):

  data/enemies.json  - one type per creature: mode from the movement verb
                       (Flies -> fly, Swims -> swim water_only, Skims/the
                       mudskipper -> surface, else ground), hitbox by
                       archetype, flags from the special rule (armor, ambush,
                       stealth, enrage / enrage_at, knockback_resist), parsed
                       drops, a desc; a stat row per band the creature lives in
                       (hp / damage / speed LITERAL, aggro by size);
                       seeding.roof_night_types_by_district (T0),
                       seeding.district_fauna.dry (T1 interiors) and
                       seeding.surface_fauna (T1 open water)
  data/items.json    - drop items the sheet names that do not exist yet
                       (organic_material, paper) + 16 px icons
  assets/sprites/enemies/<id>.png - 4-frame square-cell strips per archetype,
                       palette from the "look" text, base art facing RIGHT

Run from the repo root:  python tools/build_fauna.py   (deterministic)
"""
import json
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SHEETS = [("t0", ROOT / "docs" / "monsters" / "t0_roof_fauna.json"),
          ("t1", ROOT / "docs" / "monsters" / "t1_dry_fauna.json"),
          ("t2", ROOT / "docs" / "monsters" / "t2_shallows_fauna.json")]
STAGE_BAND = {"t0": "roof", "t1": "dry", "t2": "shallows"}
ENEMIES = ROOT / "data" / "enemies.json"
ITEMS = ROOT / "data" / "items.json"
SPRITES = ROOT / "assets" / "sprites" / "enemies"
ICONS = ROOT / "assets" / "sprites" / "icons"
FRAMES = 4
AGGRO = {"Small": 22.0, "Medium": 24.0, "Large": 28.0}

ITEM_IDS = {"scrap metal": "scrap_metal", "cloth": "cloth", "plastic": "plastic", "stone": "stone", "wood": "wood",
            "organic material": "organic_material", "fish meat": "fish_meat", "paper": "paper"}
NEW_ITEMS = {
    "organic_material": ("Organic Matter", "Chitin, gristle and feathers off the city's fauna. Bait and fertiliser one day; scrap for now.",
                         [(96, 120, 60), (120, 150, 80)]),
    "paper": ("Paper", "Loose sheets and folders from the archives. Tinder, notes, and one day maps.", [(214, 206, 180), (236, 230, 210)]),
}


def slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


# Free-text drops (the T2 sheet names trophies without counts): each phrase
# lands on the nearest material family; unique trophy items are NOT created.
DROP_FAMILIES = [
    (("copper", "wire", "rebar", "brass", "valve", "grate", "gasket", "cart", "scrap", "metal", "mesh", "tooth", "teeth"), "scrap_metal"),
    (("paper", "document"), "paper"),
    (("concrete", "dust", "gravel", "lime", "stone", "crust"), "stone"),
    (("rubber", "hose", "tubing", "plastic", "glass", "neon", "bulb", "grease", "oil", "ink"), "plastic"),
    (("cloth", "hide", "skin", "fin", "scale"), "cloth"),
]


def parse_drops(text):
    out = []
    for part in [p.strip().lower() for p in (text or "").split(",") if p.strip()]:
        m = re.match(r"([a-z \-]+?)\s+(\d+)(?:-(\d+))?\s*\((\d+)%\)", part)
        if m:
            if m.group(1).strip() not in ITEM_IDS:
                continue
            lo = int(m.group(2))
            hi = int(m.group(3) or lo)
            out.append({"item": ITEM_IDS[m.group(1).strip()], "min": float(lo), "max": float(hi), "chance": int(m.group(4)) / 100.0})
            continue
        item = ITEM_IDS.get(part)
        if item is None:
            item = "organic_material"
            for words, fam in DROP_FAMILIES:
                if any(re.search(r"\b" + w, part) for w in words):  # whole-word starts ("dust" must not match "industrial")
                    item = fam
                    break
        out.append({"item": item, "min": 1.0, "max": 1.0, "chance": 0.5})
    return out


ARCH_KEYS = [  # checked in order, first match wins - the specific T2 names go first
             # T2 The Shallows (tools/fauna_art/t2.py draws these)
             ("rust-crested eel", "crested_eel"), ("sludge crab", "sludge_crab"), ("lamprey", "lamprey"),
             ("viper", "sea_snake"), ("snapping turtle", "snapping_turtle"), ("concrete ray", "ray"),
             ("barnacle leech", "barnacle_leech"), ("barnacle", "barnacle"), ("silt-dredger", "armored_catfish"),
             ("silt stalker", "silt_stalker"), ("squid", "squid"), ("anglerfish", "anglerfish"), ("moray", "moray"),
             ("hound", "sea_hound"), ("pike", "pike"), ("betta", "betta"), ("jellyfish", "jellyfish"),
             ("mantis shrimp", "mantis_shrimp"), ("skeleton crabs", "crab_swarm"), ("stingray", "ray"),
             ("octopus", "octopus"), ("gator", "gator"), ("hagfish", "hagfish"), ("urchin", "urchin"),
             ("reef shark", "reef_shark"), ("depth barracuda", "depth_barracuda"), ("anchovy", "bait_ball"),
             ("lionfish", "lionfish"),
             ("rat", "rat"), ("mouse", "rat"), ("weasel", "weasel"), ("squirrel", "squirrel"), ("possum", "possum"),
             ("roach", "roach"), ("cicada", "winged_insect"), ("cricket", "cricket"), ("wasp", "winged_insect"),
             ("fly", "winged_insect"), ("mantis", "mantis"), ("leech", "leech"), ("slug", "slug"), ("silverfish", "silverfish"),
             ("spider", "spider"), ("strider", "strider"), ("tick", "beetle"), ("beetle", "beetle"), ("scorpion", "scorpion"),
             ("centipede", "centipede"), ("brickback", "armadillo"), ("tortoise", "tortoise"), ("snail", "snail"),
             ("crow", "crow"), ("owl", "owl"), ("bat", "bat"), ("gecko", "lizard"), ("lizard", "lizard"),
             ("salamander", "lizard"), ("swarm", "pigeon_swarm"), ("pigeon", "pigeon"), ("frog", "frog"),
             ("snake", "snake"), ("eel", "snake"), ("cat", "cat"), ("raccoon", "raccoon"), ("hyena", "canine"),
             ("dog", "canine"), ("mole", "mole"), ("goat", "goat"), ("horse", "horse"), ("rabbit", "rabbit"),
             ("crab", "crab"), ("minnow", "minnow_school"), ("mudskipper", "mudskipper")]


def archetype(rec):
    n = rec["name"]
    for key, arch in ARCH_KEYS:
        if key in n:
            return arch
    return "rat"


HITBOX = {"rat": [10, 6], "weasel": [12, 5], "squirrel": [10, 7], "possum": [14, 8], "roach": [10, 5], "winged_insect": [10, 7],
          "cricket": [10, 6], "mantis": [10, 14], "leech": [10, 4], "slug": [10, 5], "silverfish": [11, 4], "spider": [14, 8],
          "strider": [14, 6], "beetle": [10, 6], "scorpion": [16, 8], "centipede": [18, 5], "armadillo": [14, 9],
          "tortoise": [16, 9], "snail": [10, 8], "crow": [10, 8], "owl": [12, 12], "bat": [12, 7], "lizard": [11, 5],
          "pigeon": [9, 8], "pigeon_swarm": [18, 12], "frog": [8, 6], "snake": [14, 4], "cat": [12, 9], "raccoon": [14, 10],
          "canine": [18, 11], "mole": [14, 8], "goat": [16, 14], "horse": [24, 18], "rabbit": [10, 9], "crab": [12, 6],
          "minnow_school": [16, 10], "mudskipper": [12, 6]}
HITBOX.update({"crested_eel": [22, 6], "sludge_crab": [16, 9], "lamprey": [18, 6], "sea_snake": [18, 5], "snapping_turtle": [20, 12],
               "ray": [22, 8], "barnacle_leech": [16, 7], "barnacle": [14, 10], "armored_catfish": [22, 10], "silt_stalker": [20, 8],
               "squid": [12, 18], "anglerfish": [16, 12], "moray": [22, 7], "sea_hound": [18, 11], "pike": [24, 6], "betta": [14, 12],
               "jellyfish": [12, 16], "mantis_shrimp": [16, 8], "crab_swarm": [20, 12], "octopus": [16, 14], "gator": [26, 9],
               "hagfish": [18, 5], "urchin": [12, 12], "reef_shark": [28, 10], "depth_barracuda": [30, 7], "bait_ball": [20, 14],
               "lionfish": [16, 14]})
CELL = {k: (32 if k == "horse" else 24 if v[0] >= 13 or v[1] >= 10 else 16) for k, v in HITBOX.items()}
CELL.update({"gator": 32, "reef_shark": 32, "depth_barracuda": 32, "pike": 32, "ray": 24, "crested_eel": 24, "moray": 24,
             "armored_catfish": 24, "silt_stalker": 24, "hagfish": 24, "sea_snake": 24, "lamprey": 24})

# Per-stage drawer modules (tools/fauna_art/t0.py, t1.py, t2.py): each may
# define DRAW / HITBOX / CELL dicts keyed by archetype; later stages override.
import importlib  # noqa: E402
import sys  # noqa: E402
sys.path.insert(0, str(ROOT / "tools"))
STAGE_MODULES = {}
for _stage in ("t0", "t1", "t2"):
    try:
        STAGE_MODULES[_stage] = importlib.import_module("fauna_art." + _stage)
    except ImportError:
        STAGE_MODULES[_stage] = None
for _m in STAGE_MODULES.values():
    if _m is not None:
        HITBOX.update(getattr(_m, "HITBOX", {}))
        CELL.update(getattr(_m, "CELL", {}))


def palette(rec):
    full_look = rec["look"]
    # Body colours are matched on the look with eye phrases removed and word
    # boundaries respected ("heat-scarred" is not red, "red eyes" is not a red body).
    import re as _re
    look = _re.sub(r"\b(\w[\w-]*)\s+eyes?\b", " ", full_look)
    look = " " + _re.sub(r"[^a-z\- ]", " ", look.lower()) + " "
    p = {"body": (110, 90, 70), "dark": (30, 24, 20), "light": (190, 170, 150), "eye": (240, 220, 80), "accent": (200, 60, 40), "_look": full_look}
    if " blue-black " in look:
        p.update(body=(34, 40, 66), light=(80, 90, 130), dark=(14, 16, 30))
    elif " black and yellow " in look:
        p.update(body=(30, 28, 26), light=(230, 190, 40), dark=(12, 12, 12))
    elif " black " in look and " red " in look:
        p.update(body=(28, 26, 30), light=(70, 66, 74), dark=(10, 10, 12), accent=(220, 50, 40))
    elif " black " in look:
        p.update(body=(28, 28, 32), light=(68, 68, 76), dark=(10, 10, 12))
    elif " silver " in look or " metallic " in look:
        p.update(body=(170, 178, 186), light=(220, 226, 232), dark=(70, 76, 84))
    elif " white " in look:
        p.update(body=(220, 216, 208), light=(245, 243, 238), dark=(120, 116, 110))
    elif " reddish-brown " in look or " reddish " in look:
        p.update(body=(150, 70, 50), light=(200, 120, 90), dark=(70, 26, 20))
    elif " red " in look:
        p.update(body=(190, 60, 46), light=(230, 120, 90), dark=(80, 20, 16))
    elif " gray " in look or " grey " in look:
        p.update(body=(120, 122, 128), light=(178, 180, 186), dark=(40, 42, 48))
    elif " brown " in look and " green " in look:
        p.update(body=(96, 118, 60), light=(150, 160, 100), dark=(40, 48, 24))
    elif " brown " in look:
        p.update(body=(112, 78, 46), light=(160, 124, 84), dark=(44, 30, 18))
    elif " pale blue " in look or " blue-gray " in look:
        p.update(body=(150, 176, 190), light=(210, 226, 234), dark=(60, 80, 96))
    elif " pale " in look:
        p.update(body=(196, 186, 176), light=(232, 226, 220), dark=(96, 84, 78))
    elif " green " in look:
        p.update(body=(60, 130, 60), light=(120, 190, 100), dark=(20, 60, 24))
    elif " dark " in look:
        p.update(body=(52, 50, 58), light=(96, 94, 104), dark=(18, 18, 22))
    if "yellow eyes" in full_look or "glowing yellow" in full_look:
        p["eye"] = (255, 230, 60)
    elif "red eyes" in full_look:
        p["eye"] = (240, 60, 50)
    elif "reflective" in full_look or "pale eyes" in full_look or "cloudy" in full_look:
        p["eye"] = (220, 240, 255)
    elif "swollen" in full_look or "black eyes" in full_look or "dark eyes" in full_look:
        p["eye"] = (20, 20, 24) if sum(p["body"]) > 300 else (240, 90, 90)
    else:
        p["eye"] = (20, 20, 24) if sum(p["body"]) > 300 else (240, 220, 120)
    return p


# ---- drawers ---------------------------------------------------------------
def legs(d, f, p, xs, y, h=2, w=1):
    for i, lx in enumerate(xs):
        sw = (f + i) % 2
        d.rectangle([lx + sw, y, lx + sw + w - 1, y + h - 1], fill=p["dark"])


def d_rat(d, f, p, c, long=False, big_ears=False):
    y = c - 5
    tail = [0, 1, 0, -1][f]
    d.line([(1, y - 1 + tail), (5, y + 1)], fill=p["body"])
    d.ellipse([3 if long else 4, y - 4, 12, y + 1], fill=p["body"])
    d.ellipse([10, y - 4, 14, y - 1], fill=p["body"])
    er = 2 if big_ears else 1
    d.rectangle([11, y - 5 - er + 1, 11, y - 5], fill=p["light"]); d.rectangle([13, y - 5 - er + 1, 13, y - 5], fill=p["light"])
    d.point((13, y - 3), fill=p["eye"])
    d.point((15, y - 2), fill=p["light"])
    legs(d, f, p, (6, 9), y + 2)


def d_weasel(d, f, p, c):
    y = c - 4
    wag = [0, 1, 0, -1][f]
    d.line([(1, y - 2 + wag), (4, y - 1)], fill=p["body"], width=2)
    d.rounded_rectangle([3, y - 3, 13, y], radius=2, fill=p["body"])
    d.ellipse([12, y - 4, 15, y - 1], fill=p["body"])
    d.point((14, y - 3), fill=p["eye"]); d.point((15, y - 2), fill=p["light"])
    legs(d, f, p, (5, 11), y + 1)


def d_squirrel(d, f, p, c):
    y = c - 4
    d.ellipse([1, y - 8, 6, y + 1], fill=p["light"])              # big tail
    d.ellipse([5, y - 4, 12, y + 1], fill=p["body"])
    d.ellipse([10, y - 6, 14, y - 2], fill=p["body"])
    d.point((11, y - 7), fill=p["body"]); d.point((13, y - 7), fill=p["body"])
    d.point((13, y - 5), fill=p["eye"])
    legs(d, f, p, (7, 10), y + 2)


def d_possum(d, f, p, c):
    y = c - 4
    d.line([(1, y - 4 + [0, 1, 0, -1][f]), (6, y - 1)], fill=p["light"])
    d.ellipse([5, y - 6, 17, y + 1], fill=p["body"])
    d.polygon([(16, y - 5), (22, y - 2), (16, y - 1)], fill=p["light"])
    d.point((17, y - 6), fill=p["body"]); d.point((19, y - 6), fill=p["body"])
    d.point((19, y - 3), fill=p["eye"])
    legs(d, f, p, (8, 14), y + 2, w=2)


def d_roach(d, f, p, c):
    y = c - 5
    d.ellipse([3, y - 3, 13, y + 1], fill=p["body"])
    d.line([(6, y - 3), (6, y + 1)], fill=p["light"]); d.line([(9, y - 3), (9, y + 1)], fill=p["light"])
    d.line([(12, y - 3), (15, y - 6 + (f % 2))], fill=p["light"]); d.line([(12, y - 3), (15, y - 5 - (f % 2))], fill=p["light"])
    for lx in (4, 7, 10):
        d.line([(lx, y + 1), (lx - 1 + (f % 2), y + 3)], fill=p["dark"])
    d.point((13, y - 1), fill=p["eye"])


def d_winged_insect(d, f, p, c):
    y = c // 2
    flap = [-3, 0, 2, 0][f]
    d.ellipse([4, y - 1, 12, y + 3], fill=p["body"])               # abdomen
    if sum(p["light"]) > 380 and "yellow" in p["_look"]:            # wasp bands
        for bx in (6, 9):
            d.line([(bx, y - 1), (bx, y + 3)], fill=p["light"])
        d.line([(3, y + 1), (1, y + 2)], fill=p["dark"])            # stinger
    d.ellipse([11, y - 2, 15, y + 1], fill=p["body"])               # head
    d.point((14, y - 1), fill=p["eye"]); d.point((13, y - 2), fill=p["eye"])
    wing = (200, 220, 230) if "translucent" in p["_look"] else p["light"]
    d.polygon([(5, y - 1), (11, y - 1), (8, y - 4 + flap)], fill=wing)
    legs(d, f, p, (7, 10), y + 4, h=1)


def d_cricket(d, f, p, c):
    y = c - 5
    hop = [0, -2, -3, -1][f]
    d.ellipse([3, y - 3 + hop, 12, y + 1 + hop], fill=p["body"])
    d.ellipse([11, y - 3 + hop, 14, y + hop], fill=p["body"])
    d.line([(13, y - 3 + hop), (16, y - 7 + hop)], fill=p["light"]); d.line([(13, y - 3 + hop), (15, y - 8 + hop)], fill=p["light"])
    d.line([(6, y + hop), (3, y - 4 + hop)], fill=p["dark"]); d.line([(3, y - 4 + hop), (2, y + 2)], fill=p["dark"])  # big back leg
    d.point((13, y - 2 + hop), fill=p["eye"])


def d_mantis(d, f, p, c):
    y = c - 3
    d.line([(4, y - 8), (14, y - 6)], fill=p["body"], width=2)
    d.line([(14, y - 6), (17, y - 12)], fill=p["body"], width=2)
    d.ellipse([16, y - 15, 20, y - 12], fill=p["body"])
    d.point((19, y - 14), fill=p["eye"])
    r = [0, 1, 2, 1][f]
    d.line([(17, y - 11), (21, y - 13 - r)], fill=p["light"], width=2); d.line([(21, y - 13 - r), (22, y - 9 - r)], fill=p["light"])
    for lx in (7, 11):
        d.line([(lx, y - 6), (lx - 2 + (f % 2), y)], fill=p["dark"]); d.line([(lx + 1, y - 6), (lx + 3 - (f % 2), y)], fill=p["dark"])


def d_leech(d, f, p, c):
    y = c - 4
    w = [0, 1, 0, -1][f]
    d.line([(2, y + w), (5, y - 1), (8, y + 1 + w), (11, y - 1), (14, y)], fill=p["body"], width=3)
    d.ellipse([12, y - 2, 15, y + 1], fill=p["body"]); d.point((14, y), fill=p["dark"])
    for bx in (4, 8):
        d.point((bx, y - 1), fill=(240, 200, 60))


def d_slug(d, f, p, c):
    y = c - 4
    st = [0, 1, 0, -1][f]
    d.ellipse([2, y - 3, 13 + st, y + 1], fill=p["body"])
    d.line([(6, y - 3), (11, y - 3)], fill=p["light"])            # glossy highlight
    d.line([(12, y - 3), (14, y - 6)], fill=p["light"]); d.line([(13, y - 2), (15, y - 4)], fill=p["light"])  # feelers
    d.line([(1, y + 2), (4, y + 2)], fill=(90, 90, 100))            # trail


def d_silverfish(d, f, p, c):
    y = c - 4
    w = [0, 1, 0, -1][f]
    d.polygon([(3, y), (13, y - 2), (15, y), (13, y + 2)], fill=p["body"])
    for bx in (5, 8, 11):
        d.line([(bx, y - 1), (bx, y + 1)], fill=p["light"])
    for k in (-2, 0, 2):
        d.line([(3, y), (0, y + k + w)], fill=p["light"])            # bristles
    d.line([(14, y - 1), (16, y - 3)], fill=p["light"]); d.line([(14, y + 1), (16, y + 3)], fill=p["light"])
    d.point((13, y), fill=p["eye"])


def d_spider(d, f, p, c):
    y = c - 6
    d.ellipse([4, y - 4, 13, y + 2], fill=p["light"])
    for bx in (6, 9, 11):
        d.point((bx, y - 1), fill=p["dark"])
    d.ellipse([12, y - 3, 17, y + 1], fill=p["body"])
    d.point((16, y - 2), fill=p["eye"]); d.point((17, y - 1), fill=p["eye"])
    for i, lx in enumerate((6, 9, 12, 15)):
        sw = (f + i) % 2
        d.line([(lx, y - 2), (lx - 4 + sw, y - 6)], fill=p["body"]); d.line([(lx - 4 + sw, y - 6), (lx - 6 + sw, y + 3)], fill=p["body"])
        d.line([(lx, y), (lx + 3 - sw, y + 5)], fill=p["body"])


def d_strider(d, f, p, c):
    y = c - 8
    d.line([(6, y), (14, y - 1)], fill=p["body"], width=2)
    d.point((15, y - 1), fill=p["eye"])
    for i, lx in enumerate((7, 10, 13)):
        sw = (f + i) % 2
        d.line([(lx, y), (lx - 6 + sw, y + 6)], fill=p["dark"]); d.line([(lx, y), (lx + 6 - sw, y + 6)], fill=p["dark"])
    d.line([(1, y + 7), (22, y + 7)], fill=(90, 130, 150))          # the water film it stands on


def d_beetle(d, f, p, c):
    y = c - 5
    d.ellipse([3, y - 5, 13, y + 1], fill=p["body"])
    d.line([(8, y - 5), (8, y + 1)], fill=p["dark"])
    d.ellipse([12, y - 2, 15, y + 1], fill=p["dark"]); d.point((14, y - 1), fill=p["eye"])
    for lx in (5, 8, 11):
        d.line([(lx, y + 1), (lx - 1 + (f % 2), y + 3)], fill=p["dark"], width=2)


def d_scorpion(d, f, p, c):
    y = c - 5
    curl = [0, -1, -2, -1][f]
    d.ellipse([5, y - 3, 15, y + 1], fill=p["body"])
    d.line([(5, y - 1), (2, y - 5), (3, y - 10 + curl)], fill=p["body"], width=2)   # tail up over the back
    d.polygon([(2, y - 11 + curl), (5, y - 10 + curl), (3, y - 8 + curl)], fill=p["accent"])  # sting
    d.line([(15, y - 2), (19, y - 4)], fill=p["body"], width=2); d.ellipse([18, y - 6, 22, y - 2], fill=p["body"])  # pincer
    d.line([(15, y), (19, y + 1)], fill=p["body"], width=2); d.ellipse([18, y - 1, 22, y + 3], fill=p["body"])
    d.point((14, y - 2), fill=p["eye"])
    legs(d, f, p, (7, 10, 13), y + 2)


def d_centipede(d, f, p, c):
    y = c - 5
    pts = [(x, y + round(1.2 * math.sin((x + f * 1.5) * 0.8))) for x in range(2, 21)]
    d.line(pts, fill=p["body"], width=3)
    for i, (x, yy) in enumerate(pts[::2]):
        d.line([(x, yy + 1), (x - 1 + ((f + i) % 2), yy + 4)], fill=p["light"]); d.line([(x, yy - 1), (x - 1 + ((f + i) % 2), yy - 4)], fill=p["light"])
    d.ellipse([19, y - 3, 23, y + 1], fill=p["dark"]); d.point((22, y - 1), fill=p["eye"])


def d_armadillo(d, f, p, c):
    y = c - 4
    d.ellipse([3, y - 9, 19, y + 1], fill=p["body"])
    for bx in range(6, 18, 3):
        d.line([(bx, y - 8), (bx, y)], fill=p["dark"])
    d.ellipse([17, y - 4, 22, y], fill=p["light"]); d.point((21, y - 3), fill=p["eye"])
    legs(d, f, p, (6, 10, 14), y + 1, w=2)


def d_tortoise(d, f, p, c):
    y = c - 4
    d.chord([3, y - 10, 19, y + 2], 180, 360, fill=p["body"])       # dome shell
    for bx in (7, 11, 15):
        d.line([(bx, y - 8), (bx, y - 1)], fill=p["dark"])
    d.line([(4, y - 4), (18, y - 4)], fill=p["dark"])                # crack
    d.ellipse([17, y - 4, 22, y], fill=p["light"]); d.point((21, y - 3), fill=p["eye"])
    legs(d, f, p, (5, 15), y + 1, w=3)


def d_snail(d, f, p, c):
    y = c - 3
    d.line([(2, y), (11, y)], fill=p["light"], width=3)              # foot
    d.line([(10, y - 1), (14, y - 5 + [0, 0, -1, 0][f])], fill=p["light"], width=2)  # neck
    d.point((14, y - 6), fill=p["eye"]); d.point((12, y - 6), fill=p["eye"])
    d.ellipse([2, y - 9, 11, y - 1], fill=p["body"])                 # shell
    d.arc([4, y - 7, 9, y - 3], 0, 300, fill=p["dark"])               # spiral
    d.line([(0, y + 2), (4, y + 2)], fill=(150, 160, 150))            # trail


def d_bird(d, f, p, c, beak_len=2, stone=False):
    y = c // 2
    flap = [-3, -1, 1, -1][f]
    d.ellipse([4, y - 2, 12, y + 3], fill=p["body"]); d.ellipse([10, y - 4, 14, y - 1], fill=p["body"])
    d.line([(14, y - 3), (14 + beak_len, y - 3)], fill=(220, 190, 80)); d.point((12, y - 3), fill=p["eye"])
    d.polygon([(5, y - 1), (9, y - 1), (7, y + flap - 2)], fill=p["light"]); d.line([(1, y + 1), (4, y)], fill=p["body"])
    if stone:
        for sx, sy in ((6, y), (8, y + 1), (10, y - 1)):
            d.point((sx, sy), fill=(150, 150, 150))


def d_crow(d, f, p, c):
    d_bird(d, f, p, c, beak_len=3)


def d_pigeon(d, f, p, c):
    d_bird(d, f, p, c, beak_len=1, stone=True)


def d_pigeon_swarm(d, f, p, c):
    for i, (ox, oy) in enumerate(((0, 8), (6, 2), (8, 11))):
        im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d_bird(ImageDraw.Draw(im), (f + i) % FRAMES, p, 16, beak_len=1)
        d._image.paste(im, (ox, oy), im)


def d_owl(d, f, p, c):
    y = c // 2
    flap = [-4, -1, 2, -1][f]
    d.ellipse([7, y - 4, 17, y + 8], fill=p["body"])                 # upright body
    d.ellipse([8, y - 9, 16, y - 2], fill=p["body"])                  # round head
    d.point((8, y - 9), fill=p["body"]); d.point((16, y - 9), fill=p["body"])  # tufts
    d.ellipse([9, y - 7, 11, y - 5], fill=p["eye"]); d.ellipse([13, y - 7, 15, y - 5], fill=p["eye"])
    d.point((12, y - 4), fill=(220, 190, 80))
    d.line([(12, y - 1), (12, y + 6)], fill=p["light"])               # the "suit" stripe
    d.polygon([(7, y), (1, y + flap), (3, y + 4 + flap // 2), (7, y + 4)], fill=p["dark"])
    d.polygon([(17, y), (23, y + flap), (21, y + 4 + flap // 2), (17, y + 4)], fill=p["dark"])
    d.line([(10, y + 8), (10, y + 10)], fill=(220, 190, 80)); d.line([(14, y + 8), (14, y + 10)], fill=(220, 190, 80))


def d_bat(d, f, p, c):
    y = c // 2
    flap = [-4, -1, 2, -1][f]
    d.ellipse([6, y - 2, 10, y + 3], fill=p["body"]); d.ellipse([6, y - 4, 10, y - 1], fill=p["body"])
    d.point((6, y - 5), fill=p["body"]); d.point((10, y - 5), fill=p["body"])
    d.point((7, y - 3), fill=p["eye"]); d.point((9, y - 3), fill=p["eye"])
    wing = p["light"] if "translucent" in p["_look"] else p["dark"]
    d.polygon([(6, y), (0, y + flap), (2, y + 3 + flap // 2), (6, y + 2)], fill=wing)
    d.polygon([(10, y), (15, y + flap), (13, y + 3 + flap // 2), (10, y + 2)], fill=wing)


def d_lizard(d, f, p, c):
    y = c - 4
    d.line([(1, y + 1), (5, y)], fill=p["body"])
    d.ellipse([4, y - 2, 12, y + 1], fill=p["body"])
    d.polygon([(11, y - 2), (16, y - 1), (11, y + 1)], fill=p["body"]); d.point((13, y - 1), fill=p["eye"])
    if "red" in p["_look"]:
        for bx in (6, 9):
            d.point((bx, y - 1), fill=p["accent"])
    for lx in (6, 10):
        d.line([(lx, y + 1), (lx - 2 + (f % 2) * 2, y + 3)], fill=p["dark"]); d.line([(lx, y - 2), (lx - 2 + ((f + 1) % 2) * 2, y - 4)], fill=p["dark"])


def d_frog(d, f, p, c):
    y = c - 4
    hop = [0, -2, -3, -1][f]
    d.ellipse([4, y - 4 + hop, 12, y + 1 + hop], fill=p["body"]); d.ellipse([10, y - 5 + hop, 14, y - 2 + hop], fill=p["body"])
    d.point((13, y - 4 + hop), fill=p["eye"]); d.point((11, y - 5 + hop), fill=p["eye"])
    d.line([(4, y + hop), (2, y + 2)], fill=p["dark"], width=2); d.line([(9, y + 1 + hop), (10, y + 2)], fill=p["dark"])


def d_snake(d, f, p, c):
    y = c - 3
    pts = [(x, y + round(1.4 * math.sin((x + f * 1.6) * 0.9))) for x in range(1, 15)]
    d.line(pts, fill=p["body"], width=2)
    d.ellipse([13, y - 2, 16, y], fill=p["body"]); d.point((15, y - 1), fill=p["eye"])


def d_cat(d, f, p, c):
    y = c - 4
    tail = [0, -1, -2, -1][f]
    d.line([(1, y - 2 + tail), (4, y - 1)], fill=p["body"])
    d.ellipse([3, y - 4, 12, y + 1], fill=p["body"]); d.ellipse([10, y - 6, 15, y - 2], fill=p["body"])
    d.point((11, y - 7), fill=p["body"]); d.point((14, y - 7), fill=p["body"])
    d.point((12, y - 4), fill=p["eye"]); d.point((14, y - 4), fill=p["eye"])
    legs(d, f, p, (5, 10), y + 1, h=3); d.point((5, y + 3), fill=p["light"])


def d_raccoon(d, f, p, c):
    y = c - 4
    d.line([(1, y - 3), (5, y - 1)], fill=p["body"], width=2)
    for bx in (2, 4):
        d.point((bx, y - 3), fill=p["dark"])
    d.ellipse([4, y - 8, 17, y + 1], fill=p["body"]); d.ellipse([15, y - 7, 22, y - 2], fill=p["light"])
    d.rectangle([17, y - 6, 22, y - 5], fill=p["dark"]); d.point((18, y - 6), fill=p["eye"]); d.point((21, y - 6), fill=p["eye"])
    d.point((16, y - 8), fill=p["body"]); d.point((20, y - 8), fill=p["body"])
    legs(d, f, p, (7, 13), y + 1, h=3, w=2)


def d_canine(d, f, p, c):
    y = c - 5
    d.line([(1, y - 6 + [0, 1, 0, -1][f]), (4, y - 4)], fill=p["body"], width=2)
    d.rounded_rectangle([3, y - 7, 17, y - 1], radius=2, fill=p["body"])
    if "hyena" in p["_look"] or "stains" in p["_look"]:
        d.rectangle([5, y - 9, 10, y - 7], fill=p["dark"])            # hyena hump
    d.rounded_rectangle([15, y - 9, 22, y - 4], radius=1, fill=p["body"])   # head + jaw
    d.point((16, y - 10), fill=p["body"]); d.point((19, y - 10), fill=p["body"])
    d.point((20, y - 8), fill=p["eye"])
    d.line([(20, y - 5), (23, y - 5)], fill=p["light"])              # teeth line
    if "stains" in p["_look"]:
        d.point((22, y - 4), fill=(120, 30, 30))
    legs(d, f, p, (5, 8, 13, 16), y - 1, h=4, w=2)


def d_mole(d, f, p, c):
    y = c - 4
    d.ellipse([3, y - 6, 17, y + 1], fill=p["body"])
    d.rectangle([15, y - 7, 22, y - 2], fill=p["body"])               # flattened skull
    d.line([(22, y - 4), (23, y - 4)], fill=(230, 160, 160))          # snout
    d.polygon([(16, y - 1), (20, y + 2), (13, y + 2)], fill=p["light"])  # big claws
    legs(d, f, p, (6, 10), y + 1, h=2, w=2)


def d_goat(d, f, p, c):
    y = c - 3
    d.rounded_rectangle([5, y - 11, 16, y - 6], radius=2, fill=p["body"])
    d.line([(15, y - 10), (21, y - 13)], fill=p["body"], width=2)     # neck
    d.rounded_rectangle([19, y - 16, 23, y - 12], radius=1, fill=p["body"])
    d.line([(20, y - 16), (17, y - 21)], fill=p["light"], width=2); d.line([(22, y - 16), (20, y - 21)], fill=p["light"], width=2)  # horns
    d.point((22, y - 14), fill=p["eye"]); d.point((23, y - 11), fill=p["light"])
    for i, lx in enumerate((6, 9, 12, 15)):
        sw = (f + i) % 2
        d.line([(lx + sw, y - 6), (lx + sw, y)], fill=p["dark"])      # long thin legs
    d.point((4, y - 10), fill=p["body"])


def d_horse(d, f, p, c):
    y = c - 3
    d.rounded_rectangle([5, y - 15, 22, y - 7], radius=3, fill=p["body"])
    d.polygon([(20, y - 14), (26, y - 23), (29, y - 22), (24, y - 12)], fill=p["body"])   # muscular neck
    d.rounded_rectangle([26, y - 25, 31, y - 19], radius=1, fill=p["body"])
    d.point((27, y - 26), fill=p["body"]); d.point((30, y - 26), fill=p["body"])
    d.point((29, y - 23), fill=p["eye"])
    for k in range(6):
        d.point((21 + k, y - 24 + k), fill=p["dark"])                  # mane
    d.line([(4, y - 13), (1, y - 6 + [0, 1, 0, -1][f])], fill=p["dark"], width=2)  # tail
    for i, lx in enumerate((7, 10, 17, 20)):
        sw = (f + i) % 2
        d.rectangle([lx + sw, y - 7, lx + sw + 1, y], fill=p["dark"])


def d_rabbit(d, f, p, c):
    y = c - 4
    hop = [0, -2, -3, -1][f]
    d.ellipse([3, y - 6 + hop, 12, y + 1 + hop], fill=p["body"])
    d.ellipse([10, y - 7 + hop, 14, y - 3 + hop], fill=p["body"])
    d.rectangle([10, y - 12 + hop, 11, y - 7 + hop], fill=p["light"]); d.rectangle([13, y - 12 + hop, 14, y - 7 + hop], fill=p["light"])  # ears
    if "fungal" in p["_look"]:
        d.point((11, y - 11 + hop), fill=(200, 220, 160)); d.point((6, y - 6 + hop), fill=(200, 220, 160))
    d.point((13, y - 5 + hop), fill=p["eye"]); d.point((3, y - 5 + hop), fill=p["light"])
    d.line([(4, y + 1 + hop), (2, y + 2)], fill=p["dark"], width=2); d.line([(10, y + 1 + hop), (11, y + 2)], fill=p["dark"])


def d_crab(d, f, p, c):
    y = c - 5
    d.ellipse([4, y - 3, 12, y + 1], fill=p["body"])
    d.point((6, y - 1), fill=p["dark"]); d.point((10, y - 2), fill=p["dark"])                 # scratches
    d.point((6, y - 4), fill=p["eye"]); d.point((10, y - 4), fill=p["eye"])                    # eye stalks
    op = [0, 1, 0, 1][f]
    d.ellipse([12, y - 5 - op, 16, y - 2], fill=p["body"]); d.ellipse([0, y - 5 - op, 4, y - 2], fill=p["body"])  # big claws
    for i, lx in enumerate((3, 5, 11, 13)):
        d.line([(lx, y + 1), (lx + (-1 if lx < 8 else 1), y + 3 - ((f + i) % 2))], fill=p["dark"])


def d_minnow_school(d, f, p, c):
    for i, (ox, oy) in enumerate(((1, 3), (8, 1), (12, 8), (4, 12), (14, 15), (7, 18))):
        wag = (f + i) % 2
        d.ellipse([ox, oy, ox + 5, oy + 2], fill=p["body"])
        d.polygon([(ox, oy + 1), (ox - 2, oy - 1 + wag), (ox - 2, oy + 3 - wag)], fill=p["body"])
        d.point((ox + 4, oy + 1), fill=p["eye"])


def d_mudskipper(d, f, p, c):
    y = c - 4
    hop = [0, -1, -2, -1][f]
    d.line([(1, y + 1 + hop), (4, y + hop)], fill=p["body"], width=2)
    d.ellipse([3, y - 3 + hop, 13, y + 1 + hop], fill=p["body"])
    d.polygon([(6, y - 3 + hop), (9, y - 6 + hop), (11, y - 3 + hop)], fill=p["light"])          # dorsal
    d.ellipse([11, y - 5 + hop, 13, y - 3 + hop], fill=p["eye"]); d.ellipse([9, y - 5 + hop, 11, y - 3 + hop], fill=p["eye"])  # bulging eyes
    d.line([(6, y + 1 + hop), (4, y + 3)], fill=p["light"], width=2); d.line([(11, y + 1 + hop), (13, y + 3)], fill=p["light"], width=2)  # front fins as legs


DRAW = {"rat": d_rat, "weasel": d_weasel, "squirrel": d_squirrel, "possum": d_possum, "roach": d_roach,
        "winged_insect": d_winged_insect, "cricket": d_cricket, "mantis": d_mantis, "leech": d_leech, "slug": d_slug,
        "silverfish": d_silverfish, "spider": d_spider, "strider": d_strider, "beetle": d_beetle, "scorpion": d_scorpion,
        "centipede": d_centipede, "armadillo": d_armadillo, "tortoise": d_tortoise, "snail": d_snail, "crow": d_crow,
        "owl": d_owl, "bat": d_bat, "lizard": d_lizard, "pigeon": d_pigeon, "pigeon_swarm": d_pigeon_swarm, "frog": d_frog,
        "snake": d_snake, "cat": d_cat, "raccoon": d_raccoon, "canine": d_canine, "mole": d_mole, "goat": d_goat,
        "horse": d_horse, "rabbit": d_rabbit, "crab": d_crab, "minnow_school": d_minnow_school, "mudskipper": d_mudskipper}


def outline(img, colour=(10, 12, 16, 255)):
    src = img.copy()
    px = src.load()
    out = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < w and 0 <= yy < h and px[xx, yy][3] != 0 and px[xx, yy] != colour:
                        out[x, y] = colour
                        break


def drawer_for(arch):
    """A stage module's drawer wins over the built-in one."""
    for _stage in ("t2", "t1", "t0"):
        m = STAGE_MODULES.get(_stage)
        if m is not None and arch in getattr(m, "DRAW", {}):
            return m.DRAW[arch]
    return DRAW.get(arch)


def strip(arch, pal, rec):
    c = CELL[arch]
    img = Image.new("RGBA", (c * FRAMES, c), (0, 0, 0, 0))
    fn = drawer_for(arch)
    if fn is None:
        raise SystemExit("no drawer for archetype %r (%s) - add it to tools/fauna_art/t*.py" % (arch, rec["name"]))
    for f in range(FRAMES):
        fr = Image.new("RGBA", (c, c), (0, 0, 0, 0))
        d = ImageDraw.Draw(fr)
        if arch == "rat" and fn is d_rat:
            d_rat(d, f, pal, c, long="mouse" not in rec["name"] and "rat" not in rec["name"], big_ears="mouse" in rec["name"])
        else:
            fn(d, f, pal, c)
        img.paste(fr, (f * c, 0), fr)
    outline(img)
    return img


def special_flags(rec):
    s = (rec.get("special") or "").lower()
    flags = {}
    if "reduces incoming damage" in s or "resistant to damage" in s or "armor" in s:
        flags["armor"] = 0.25
    if "motionless" in s or "hide" in s or "hidden" in s or "freezes" in s or "emerge suddenly" in s:
        flags["ambush"] = True
    if "difficult to see" in s or "difficult to detect" in s or "silent" in s:
        flags["stealth"] = 0.4
    if "aggressive when damaged" in s:
        flags["enrage"] = 0.5
    if "aggressive below half" in s:
        flags["enrage"] = 0.5
        flags["enrage_at"] = 0.5
    if "resistant to knockback" in s:
        flags["knockback_resist"] = 0.8
    if "high defense" in s or "slime coat reduces" in s or "reflects" in s:
        flags["armor"] = max(flags.get("armor", 0.0), 0.3)
    if "semi-invisible" in s or "camouflage" in s:
        flags["stealth"] = 0.5
        flags["ambush"] = True
    if "heals" in s and "damage dealt" in s:
        flags["lifesteal"] = 0.5
    if "gains speed when player is injured" in s or "territory" in s:
        flags["enrage"] = 0.3
    return flags


def mode_of(rec):
    m = rec["movement"]
    if m == "Flies":
        return "fly"
    if m in ("Swims", "Glides", "Floats", "Stationary") or "Swims" in m:  # Crawls/Swims lives in flooded floors: a swimmer
        return "swim"
    if m == "Skims" or rec["name"] == "mudskipper":
        return "surface"
    return "ground"


def ensure_items(items):
    have = {i["id"] for i in items["items"]}
    for iid, (name, desc, cols) in NEW_ITEMS.items():
        if iid in have:
            continue
        items["items"].append({"authored_icon": True, "category": "material", "id": iid, "name": name, "desc": desc,
                               "icon": [0.0, 0.0], "weight": 0.2 if iid != "paper" else 0.05})
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        if iid == "paper":
            d.rectangle([3, 2, 12, 13], fill=cols[1]); d.rectangle([4, 4, 11, 12], fill=cols[0])
            for ly in (5, 7, 9, 11):
                d.line([(5, ly), (10, ly)], fill=(120, 110, 90))
        else:
            d.ellipse([3, 5, 13, 13], fill=cols[0]); d.ellipse([5, 3, 11, 9], fill=cols[1]); d.point((7, 5), fill=(170, 200, 120))
        outline(img)
        img.save(ICONS / (iid + ".png"))


def main():
    enemies = json.load(open(ENEMIES, encoding="utf-8"))
    items = json.load(open(ITEMS, encoding="utf-8"))
    ensure_items(items)
    enemies["types"] = [t for t in enemies["types"] if not t.get("grid_fauna") and not t.get("roof_fauna")]
    for band in enemies["bands"].values():
        for tid in [k for k in band if k.endswith("__grid__")]:
            band.pop(tid)
    roof_by_district, dry_by_district, surface = {}, {}, []
    fauna_by_band = {"dry": dry_by_district}   # band -> district -> [ids] (T1 dry floors, T2 flooded shallows floors, ...)
    open_water_by_band = {}                     # band -> [ids] (T2+ open-water hunters)
    total = 0
    for stage, path in SHEETS:
        design = {k: v for k, v in json.load(open(path, encoding="utf-8")).items() if not k.startswith("_")}
        for rec in design.values():
            tid = slug(rec["name"])
            arch = archetype(rec)
            pal = palette(rec)
            mode = mode_of(rec)
            open_water = rec["district"] == "open water"
            t = {
                "id": tid, "name": rec["name"].title(), "grid_fauna": True, "stage": stage,
                "district": "open_water" if open_water else rec["district"], "mode": mode,
                "size": [float(HITBOX[arch][0]), float(HITBOX[arch][1])],
                "bleeds": arch in {"rat", "weasel", "squirrel", "possum", "cat", "raccoon", "crow", "owl", "pigeon", "pigeon_swarm",
                                   "bat", "armadillo", "canine", "mole", "goat", "horse", "rabbit", "mudskipper"},
                "pounds": False, "authored_sprites": True,
                "desc": "%s - %s. Lives: %s.%s" % (rec["look"][0].upper() + rec["look"][1:], rec["attack"], rec["lives"],
                                                    (" " + rec["special"]) if rec.get("special") else ""),
                "drops": parse_drops(rec.get("drops", "")),
            }
            if mode == "swim":
                t["water_only"] = True
            if rec.get("ranged"):
                t["ranged"] = True
                t["range_blocks"] = float(rec.get("range_blocks", 3) or 3)
            if rec["movement"] == "Stationary":
                t["stationary"] = True
            t.update(special_flags(rec))
            enemies["types"].append(t)
            row = {"hp": float(rec["hp"]), "damage": float(rec["damage"]), "speed": float(rec["speed"]), "aggro": AGGRO.get(rec["size"], 24.0)}
            band = STAGE_BAND[stage]
            bands = [band] if not (stage == "t1" and open_water) else ["dry", "shallows"]
            for b in bands:
                enemies["bands"].setdefault(b, {})[tid] = row
            if stage == "t0":
                roof_by_district.setdefault(rec["district"], []).append(tid)
            elif stage == "t1" and open_water:
                surface.append(tid)
            elif open_water:
                open_water_by_band.setdefault(band, []).append(tid)
            else:
                fauna_by_band.setdefault(band, {}).setdefault(rec["district"], []).append(tid)
            strip(arch, pal, rec).save(SPRITES / (tid + ".png"))
            total += 1
    seeding = enemies["seeding"]
    seeding["roof_night_types_by_district"] = roof_by_district
    seeding["district_fauna"] = fauna_by_band
    share = seeding.setdefault("district_fauna_share", {"dry": 0.3})
    for b in fauna_by_band:
        share.setdefault(b, 0.3)
    seeding["surface_fauna"] = surface
    seeding.setdefault("surface_fauna_spacing", [50.0, 120.0])
    seeding["open_water_fauna"] = open_water_by_band
    seeding.setdefault("open_water_fauna_spacing", [70.0, 150.0])
    json.dump(enemies, open(ENEMIES, "w", encoding="utf-8", newline="\n"), indent=2, ensure_ascii=False)
    open(ENEMIES, "a", encoding="utf-8", newline="\n").write("\n")
    json.dump(items, open(ITEMS, "w", encoding="utf-8", newline="\n"), indent=2, ensure_ascii=False)
    open(ITEMS, "a", encoding="utf-8", newline="\n").write("\n")
    print("grid fauna: %d types; T0 %s; district fauna %s; surface %s; open water %s" % (
        total, {k: len(v) for k, v in roof_by_district.items()},
        {b: {k: len(v) for k, v in d.items()} for b, d in fauna_by_band.items()}, surface,
        {b: v for b, v in open_water_by_band.items()}))


if __name__ == "__main__":
    main()
