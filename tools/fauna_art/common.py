"""Shared helpers for the Bestiary Grid sprite drawers (tools/fauna_art/t*.py).

Contract for a drawer:  def d_name(d, f, p, c) -> None
  d  - PIL ImageDraw on ONE transparent c x c RGBA frame
  f  - frame index 0..3 (FRAMES); use it for a walk/flap/wag cycle
  p  - palette dict: body, dark, light, eye, accent (RGB tuples) + "_look" (the
       design's look text, for conditional details like stripes or glow)
  c  - the cell size in px (16 small, 24 medium, 32 large, 40 for long fish)
Base art FACES RIGHT (the engine flips for facing < 0); the builder adds the
1 px dark outline afterwards, so draw flat fills. Keep the feet/belly near
y = c - 3 for ground creatures and the body centred for swimmers and fliers
(the hitbox is centred on the sprite).
"""
from PIL import Image

FRAMES = 4


def legs(d, f, p, xs, y, h=2, w=1):
    """Alternating little legs at columns xs, top at y."""
    for i, lx in enumerate(xs):
        sw = (f + i) % 2
        d.rectangle([lx + sw, y, lx + sw + w - 1, y + h - 1], fill=p["dark"])


def wag(f, amp=1):
    """A 4-frame -amp..amp wobble."""
    return [0, amp, 0, -amp][f]


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


def render_strip(fn, cell, pal, frames=FRAMES):
    img = Image.new("RGBA", (cell * frames, cell), (0, 0, 0, 0))
    from PIL import ImageDraw
    for f in range(frames):
        fr = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        fn(ImageDraw.Draw(fr), f, pal, cell)
        img.paste(fr, (f * cell, 0), fr)
    outline(img)
    return img
