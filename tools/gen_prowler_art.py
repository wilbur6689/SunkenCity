"""Prowler strips (the T0 rooftop night monster, 2026-09-06).

A placeholder look until the bestiary grid names the real rooftop monsters:
the urban-pack walker_h clip set recoloured toward a cold, moon-washed
blue-grey with pale eyes, written as prowler.png (+ _idle/_attack/_hurt/
_dead) so Enemy loads it like any authored strip. Never touches the walker
files. Run from the repo root:  python tools/gen_prowler_art.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "sprites" / "enemies"
CLIPS = ["", "_idle", "_attack", "_hurt", "_dead"]


def recolour(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = (0.3 * r + 0.59 * g + 0.11 * b)
            # cold wash: crush the warm channels, lift blue, keep the shading
            nr = int(lum * 0.55)
            ng = int(lum * 0.68)
            nb = int(min(255, lum * 0.95 + 28))
            # the brightest few pixels (eyes / teeth in the source) go pale green
            if lum > 200:
                nr, ng, nb = 190, 255, 200
            px[x, y] = (nr, ng, nb, a)
    return img


def main():
    for clip in CLIPS:
        src = SRC / ("walker_h%s.png" % clip)
        if not src.exists():
            continue
        out = SRC / ("prowler%s.png" % clip)
        recolour(Image.open(src)).save(out)
        print("wrote", out.name)


if __name__ == "__main__":
    main()
