"""Variant families — lamps and clocks (user request 2026-09-01).

One floor lamp and one wall clock existed; a drowned city had every kind.
Each item carries the zones it belongs in, so the room editor palettes and
the generator's clutter sprinkle pick them up per zone. All are decorative
scrap (the power is off); a piece can be made a working light later by
switching its entry to kind "light" with a light block.
Style per docs/technical/TileArt.md.
"""
from common import *  # noqa: F401,F403


def _dark(c, k=45):
    return (max(0, c[0] - k), max(0, c[1] - k), max(0, c[2] - k))


def _light(c, k=35):
    return (min(255, c[0] + k), min(255, c[1] + k), min(255, c[2] + k))


CREAM = (222, 196, 140)
LED_RED = (230, 60, 50)
LED_DIM = (70, 26, 24)

# ------------------------------------------------------------------- lamps


def draw_desk_lamp(d, W, H):
    mt = RAMPS["metal"]
    o, t, hl = mt
    d.rectangle([2, H - 3, 9, H - 1], fill=t[1], outline=o)      # base
    d.line([3, H - 2, 8, H - 2], fill=hl)
    d.line([5, H - 4, 8, 6], fill=t[2])                          # lower arm
    d.line([6, H - 4, 9, 6], fill=t[0])
    d.line([8, 6, 12, 4], fill=t[2])                             # upper arm
    d.polygon([(9, 2), (15, 4), (13, 8), (7, 6)], fill=t[2], outline=o)  # head
    d.line([9, 3, 14, 4], fill=hl)
    d.point((11, 7), fill=YELLOW)                                # bulb
    d.point((12, 7), fill=(250, 226, 150))


def draw_wall_sconce(d, W, H):
    mt = RAMPS["metal"]
    o, t, hl = mt
    d.rectangle([6, 9, 9, H - 1], fill=t[1], outline=o)          # backplate
    d.line([7, 10, 7, H - 2], fill=hl)
    d.line([7, 9, 7, 6], fill=t[2])                              # arm
    d.polygon([(3, 6), (12, 6), (11, 1), (4, 1)], fill=CREAM, outline=o)  # shade (upward)
    d.line([4, 2, 11, 2], fill=_light(CREAM))
    d.line([5, 5, 10, 5], fill=_dark(CREAM, 40))
    d.point((7, 0), fill=YELLOW)                                 # glow above rim
    d.point((8, 0), fill=YELLOW)


def draw_lava_lamp(d, W, H):
    mt = RAMPS["metal"]
    o, t, hl = mt
    d.polygon([(4, H - 1), (11, H - 1), (9, H - 5), (6, H - 5)], fill=t[2], outline=o)  # base cone
    d.line([6, H - 4, 6, H - 2], fill=hl)
    glass_bg, blob, blob_hi = (120, 40, 110), (240, 120, 60), (250, 190, 110)
    d.polygon([(5, H - 6), (10, H - 6), (11, 3), (4, 3)], fill=glass_bg, outline=o)  # glass
    d.rectangle([5, 5, 6, 6], fill=blob)                         # blobs
    d.rectangle([7, 8, 9, 10], fill=blob)
    d.point((8, 8), fill=blob_hi)
    d.rectangle([5, 12, 7, 13], fill=blob)
    d.point((5, 12), fill=blob_hi)
    d.rectangle([5, 1, 10, 3], fill=t[2], outline=o)             # cap
    d.line([6, 2, 9, 2], fill=hl)
    d.line([5, 4, 5, H - 7], fill=(160, 80, 150))                # glass edge light


def draw_pendant_lamp(d, W, H):
    mt = RAMPS["metal"]
    o, t, hl = mt
    d.rectangle([7, 0, 8, 12], fill=t[0])                        # cord
    d.rectangle([5, 0, 10, 1], fill=t[1], outline=o)             # ceiling cap
    d.polygon([(7, 12), (8, 12), (14, 26), (1, 26)], fill=t[2], outline=o)  # shade cone
    d.line([7, 13, 3, 25], fill=hl)
    d.line([8, 13, 12, 25], fill=t[0])
    d.rectangle([2, 26, 13, 27], fill=t[1], outline=o)           # rim
    d.rectangle([6, 28, 9, 29], fill=YELLOW)                     # bulb
    d.point((7, 30), fill=(250, 226, 150))


def draw_work_light(d, W, H):
    mt = RAMPS["metal"]
    o, t, hl = mt
    d.rectangle([2, H - 3, 13, H - 1], fill=t[1], outline=o)     # tripod-ish base
    d.line([7, H - 4, 7, 14], fill=t[2])                         # post
    d.line([8, H - 4, 8, 14], fill=t[0])
    d.rectangle([3, 3, 12, 14], fill=YELLOW, outline=o)          # yellow housing
    d.rectangle([4, 4, 11, 13], fill=(250, 226, 150))            # lens
    for y in range(5, 13, 2):                                    # cage bars
        d.line([4, y, 11, y], fill=o)
    d.line([7, 4, 7, 13], fill=o)
    d.rectangle([5, 1, 10, 2], fill=t[1], outline=o)             # handle
    d.point((4, 4), fill=WHITE)


def draw_candles(d, W, H):
    wd = RAMPS["wood"]
    d.rectangle([2, H - 3, 13, H - 1], fill=wd[1][2], outline=wd[0])  # tray
    d.line([3, H - 2, 12, H - 2], fill=wd[2])
    for x, top in ((3, 6), (7, 3), (11, 8)):                     # three candles
        d.rectangle([x, top, x + 2, H - 4], fill=WHITE, outline=(170, 170, 160))
        d.line([x, top, x, H - 5], fill=(240, 240, 232))
        d.point((x + 1, top - 1), fill=OUT)                      # wick
        d.point((x + 1, top - 2), fill=ORANGE)                   # flame
        d.point((x + 1, top - 3), fill=YELLOW)


# ------------------------------------------------------------------ clocks


def draw_desk_clock(d, W, H):
    mt, ce = RAMPS["metal"], RAMPS["ceramic"]
    d.ellipse([2, 4, 13, 15], fill=mt[1][2], outline=mt[0])      # body
    d.ellipse([4, 6, 11, 13], fill=ce[1][3], outline=ce[1][1])   # face
    d.point((5, 7), fill=ce[2])
    d.line([7, 9, 7, 7], fill=OUT)                               # hands
    d.line([7, 9, 9, 10], fill=OUT)
    d.point((7, 9), fill=RED)
    d.ellipse([1, 1, 5, 5], fill=mt[1][3], outline=mt[0])        # bells
    d.ellipse([10, 1, 14, 5], fill=mt[1][3], outline=mt[0])
    d.rectangle([3, H - 1, 5, H - 1], fill=mt[0])                # feet
    d.rectangle([10, H - 1, 12, H - 1], fill=mt[0])


def draw_digital_clock(d, W, H):
    nv = RAMPS["navy"]
    box(d, 0, 4, W - 1, 12, nv, bevel=False)
    d.line([1, 5, W - 2, 5], fill=nv[1][3])
    d.rectangle([2, 6, W - 3, 10], fill=(20, 12, 12))            # display
    # "12:00"-ish segments: 4 digit cells, colon
    for i, x in enumerate((3, 6, 10, 13)):
        d.rectangle([x, 7, x + 1, 9], fill=LED_DIM)
        d.line([x, 7, x, 9], fill=LED_RED)                       # lit segments
        d.point((x + 1, 7), fill=LED_RED)
        if i % 2:
            d.point((x + 1, 9), fill=LED_RED)
    d.point((8, 7), fill=LED_RED)                                # colon
    d.point((8, 9), fill=LED_RED)


def draw_grandfather_clock(d, W, H):
    wd, ce, mt = RAMPS["wood"], RAMPS["ceramic"], RAMPS["metal"]
    o, t, hl = wd
    d.rectangle([1, 0, W - 2, 2], fill=t[3], outline=o)          # crown
    box(d, 2, 2, W - 3, H - 2, wd, bevel=False)                  # case
    d.line([3, 3, W - 4, 3], fill=hl)
    d.line([3, 4, 3, H - 4], fill=t[3])
    d.line([W - 4, 4, W - 4, H - 4], fill=t[1])
    d.ellipse([4, 5, 11, 12], fill=ce[1][3], outline=o)          # face
    d.point((5, 6), fill=ce[2])
    d.line([7, 8, 7, 6], fill=OUT)                               # hands
    d.line([7, 8, 9, 9], fill=OUT)
    d.rectangle([4, 15, 11, H - 6], fill=(30, 26, 20), outline=t[0])  # glass door
    d.line([5, 16, 5, H - 7], fill=(70, 62, 50))
    d.line([7, 16, 7, H - 12], fill=mt[1][3])                    # pendulum rod
    d.ellipse([5, H - 13, 9, H - 9], fill=YELLOW, outline=OUT)   # bob
    d.point((6, H - 12), fill=(250, 226, 150))
    d.rectangle([5, 19, 5, 24], fill=mt[1][2])                   # weights
    d.rectangle([10, 19, 10, 24], fill=mt[1][2])
    d.rectangle([0, H - 2, W - 1, H - 1], fill=t[1], outline=o)  # plinth


def draw_station_clock(d, W, H):
    mt, ce = RAMPS["metal"], RAMPS["ceramic"]
    d.ellipse([1, 1, W - 2, H - 2], fill=mt[1][1], outline=mt[0])  # rim
    d.ellipse([3, 3, W - 4, H - 4], fill=ce[1][3], outline=ce[1][1])  # face
    d.ellipse([5, 5, 10, 10], fill=WHITE)                        # sheen
    d.ellipse([6, 6, W - 7, H - 7], fill=ce[1][3])
    cx, cy = W // 2, H // 2
    for tx, ty in ((cx, 5), (W - 6, cy), (cx, H - 6), (5, cy)):  # quarter marks
        d.rectangle([tx - 1, ty - 1, tx, ty], fill=OUT)
    for tx, ty in ((cx + 8, cy - 8), (cx - 8, cy - 8), (cx + 8, cy + 8), (cx - 8, cy + 8)):
        d.point((tx, ty), fill=OUT)
    d.line([cx, cy, cx, cy - 9], fill=OUT)                       # minute hand
    d.line([cx - 1, cy, cx - 1, cy - 8], fill=OUT)
    d.line([cx, cy, cx + 6, cy + 4], fill=OUT)                   # hour hand
    d.line([cx, cy, cx - 5, cy + 7], fill=RED)                   # second hand
    d.rectangle([cx - 1, cy - 1, cx, cy], fill=RED)


def draw_modern_clock(d, W, H):
    wd, ce = RAMPS["wood"], RAMPS["ceramic"]
    d.polygon([(7, 0), (14, 4), (14, 11), (7, 15), (1, 11), (1, 4)], fill=wd[1][2], outline=wd[0])  # hexagon
    d.polygon([(7, 2), (12, 5), (12, 10), (7, 13), (3, 10), (3, 5)], fill=ce[1][3], outline=ce[1][1])
    d.point((5, 5), fill=ce[2])
    d.line([7, 8, 7, 4], fill=OUT)                               # hands only, no numerals
    d.line([7, 8, 10, 9], fill=OUT)
    d.point((7, 8), fill=TEAL)


def draw_punch_clock(d, W, H):
    mt, ce = RAMPS["metal"], RAMPS["ceramic"]
    o, t, hl = mt
    box(d, 1, 0, W - 2, H - 1, mt, bevel=False)
    d.line([2, 1, W - 3, 1], fill=hl)
    d.rectangle([3, 2, W - 4, 7], fill=ce[1][3], outline=o)      # small dial window
    d.line([7, 5, 7, 3], fill=OUT)
    d.line([7, 5, 9, 6], fill=OUT)
    d.rectangle([3, 9, W - 4, 10], fill=(20, 12, 12))            # card slot
    d.line([4, 9, W - 5, 9], fill=LED_RED)
    d.rectangle([5, 12, 10, 14], fill=BROWN_PAPER, outline=OUT)  # time card sticking out
    d.point((6, 13), fill=_dark(BROWN_PAPER, 30))


# -------------------------------------------------------------------- items

ITEMS = [
    # lamps
    {
        "id": "res_desk_lamp", "name": "Desk Lamp", "category": "clutter",
        "size": [1, 1], "zones": ["residential", "business", "commercial", "civil"], "room_type": "any",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_desk_lamp,
    },
    {
        "id": "res_wall_sconce", "name": "Wall Sconce", "category": "wall_art",
        "size": [1, 1], "zones": ["residential", "business", "commercial"], "room_type": "any",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "wall_mounted": True,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 1},
                   {"item": "cloth", "min": 0, "max": 1}],
        "draw": draw_wall_sconce,
    },
    {
        "id": "res_lava_lamp", "name": "Lava Lamp", "category": "clutter",
        "size": [1, 1], "zones": ["residential"], "room_type": "any",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 1},
                   {"item": "plastic", "min": 0, "max": 1}],
        "draw": draw_lava_lamp,
    },
    {
        "id": "res_pendant_lamp", "name": "Pendant Lamp", "category": "wall_art",
        "size": [1, 2], "zones": ["residential", "business", "commercial"], "room_type": "any",
        "weight": 3, "tool_tier": 0, "skill": 0, "scrap_time": 1.2, "xp": 2,
        "wall_mounted": True,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_pendant_lamp,
    },
    {
        "id": "ind_work_light", "name": "Caged Work Light", "category": "furniture",
        "size": [1, 2], "zones": ["industrial", "commercial"], "room_type": "any",
        "weight": 5, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "yields": [{"item": "scrap_metal", "min": 2, "max": 3},
                   {"item": "plastic", "min": 0, "max": 1}],
        "draw": draw_work_light,
    },
    {
        "id": "res_candles", "name": "Candle Tray", "category": "clutter",
        "size": [1, 1], "zones": ["residential"], "room_type": "any",
        "weight": 1, "tool_tier": 0, "skill": 0, "scrap_time": 0.8, "xp": 1,
        "yields": [{"item": "wood", "min": 1, "max": 1},
                   {"item": "cloth", "min": 0, "max": 1}],
        "draw": draw_candles,
    },
    # clocks
    {
        "id": "res_desk_clock", "name": "Alarm Clock", "category": "clutter",
        "size": [1, 1], "zones": ["residential"], "room_type": "any",
        "weight": 1, "tool_tier": 0, "skill": 0, "scrap_time": 0.8, "xp": 1,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 1}],
        "draw": draw_desk_clock,
    },
    {
        "id": "com_digital_clock", "name": "Digital Clock", "category": "wall_art",
        "size": [1, 1], "zones": ["business", "commercial", "civil", "industrial"], "room_type": "any",
        "weight": 2, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "wall_mounted": True,
        "yields": [{"item": "plastic", "min": 1, "max": 2}],
        "draw": draw_digital_clock,
    },
    {
        "id": "res_grandfather_clock", "name": "Grandfather Clock", "category": "furniture",
        "size": [1, 3], "zones": ["residential"], "room_type": "any",
        "weight": 20, "tool_tier": 0, "skill": 1, "scrap_time": 3.5, "xp": 7,
        "yields": [{"item": "wood", "min": 5, "max": 8},
                   {"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_grandfather_clock,
    },
    {
        "id": "com_station_clock", "name": "Large Wall Clock", "category": "wall_art",
        "size": [2, 2], "zones": ["business", "commercial", "civil"], "room_type": "any",
        "weight": 6, "tool_tier": 0, "skill": 0, "scrap_time": 1.5, "xp": 3,
        "wall_mounted": True,
        "yields": [{"item": "scrap_metal", "min": 2, "max": 3},
                   {"item": "plastic", "min": 0, "max": 1}],
        "draw": draw_station_clock,
    },
    {
        "id": "res_modern_clock", "name": "Modern Clock", "category": "wall_art",
        "size": [1, 1], "zones": ["residential", "business", "commercial"], "room_type": "any",
        "weight": 1, "tool_tier": 0, "skill": 0, "scrap_time": 1.0, "xp": 2,
        "wall_mounted": True,
        "yields": [{"item": "wood", "min": 1, "max": 1}],
        "draw": draw_modern_clock,
    },
    {
        "id": "ind_punch_clock", "name": "Punch Clock", "category": "wall_art",
        "size": [1, 1], "zones": ["industrial", "commercial"], "room_type": "any",
        "weight": 4, "tool_tier": 0, "skill": 0, "scrap_time": 1.2, "xp": 2,
        "wall_mounted": True,
        "yields": [{"item": "scrap_metal", "min": 1, "max": 2}],
        "draw": draw_punch_clock,
    },
]
