"""Shared palette + drawing helpers for room-pack item modules.

Style law (docs/technical/TileArt.md): each material is a ramp of ~5-7
colors — a hue-tinted near-black outline, 3-4 body tones ~25-30 luminance
apart, one highlight. Texture comes from small shaded shapes (light
top-left, dark bottom-right), never per-pixel noise. 1 block = 16 px.
"""

OUT = (24, 18, 14)          # universal hue-tinted outline
WHITE = (226, 226, 220)
RED = (190, 60, 50)
ORANGE = (220, 130, 50)
YELLOW = (222, 186, 80)
BLUE = (90, 140, 190)
TEAL = (70, 160, 150)
PURPLE = (150, 90, 190)
GREEN = (110, 210, 120)
DARKGREEN = (60, 130, 80)
PINK = (220, 140, 160)
BROWN_PAPER = (196, 168, 120)

# Material ramps: (outline, [tone_dark, tone, tone_light, tone_lighter], highlight)
RAMPS = {
    "wood":    ((40, 26, 14), [(94, 62, 38), (120, 82, 50), (146, 104, 66), (168, 126, 86)], (192, 152, 108)),
    "metal":   ((22, 28, 36), [(60, 70, 82), (80, 92, 106), (100, 114, 130), (120, 136, 152)], (154, 170, 186)),
    "stone":   ((30, 28, 26), [(66, 64, 62), (90, 88, 86), (114, 112, 110), (138, 136, 134)], (166, 164, 162)),
    "plastic": ((20, 44, 32), [(54, 100, 74), (70, 126, 92), (90, 150, 110), (112, 172, 130)], (142, 196, 156)),
    "fabric":  ((36, 24, 30), [(110, 70, 84), (140, 92, 104), (166, 116, 126), (188, 140, 148)], (210, 168, 172)),
    "ceramic": ((40, 40, 44), [(150, 150, 150), (180, 180, 180), (205, 205, 205), (218, 218, 214)], (240, 240, 240)),
    "navy":    ((16, 22, 34), [(44, 58, 84), (58, 76, 108), (74, 96, 130), (92, 116, 150)], (120, 148, 180)),
}


def box(d, x0, y0, x1, y1, ramp, bevel=True):
    """Filled rect with outline and a 1px light top/left, dark bottom/right bevel."""
    o, t, h = ramp
    d.rectangle([x0, y0, x1, y1], fill=t[2], outline=o)
    if bevel and x1 - x0 > 2 and y1 - y0 > 2:
        d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=t[3])
        d.line([x0 + 1, y0 + 1, x0 + 1, y1 - 1], fill=t[3])
        d.line([x0 + 1, y1 - 1, x1 - 1, y1 - 1], fill=t[1])
        d.line([x1 - 1, y0 + 1, x1 - 1, y1 - 1], fill=t[1])


def panel(d, x0, y0, x1, y1, fill, outline=OUT, top=None):
    """Flat panel: fill + outline + optional 1px lighter top edge."""
    d.rectangle([x0, y0, x1, y1], fill=fill, outline=outline)
    if top and x1 - x0 > 2:
        d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=top)


def legs(d, W, H, ramp, inset=2, width=1, height=3):
    """Simple furniture legs at both bottom corners."""
    o, t, _ = ramp
    d.rectangle([inset, H - height, inset + width, H - 1], fill=t[1], outline=o)
    d.rectangle([W - 2 - inset - width + 1, H - height, W - 1 - inset, H - 1], fill=t[1], outline=o)
