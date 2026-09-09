"""Draw the 16 px torch icon (assets/sprites/icons/torch.png) - user request 2026-09-07.

A rag-wrapped stick on the diagonal (grip bottom-left, flame top-right, so the paper doll's
grip-held rest pose carries the flame up and forward) with a three-tone flame. Never
overwrites an existing icon unless ICONS_FORCE=1.
    python tools/gen_torch_icon.py
"""
import os
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "icons" / "torch.png"

WOOD = [(58, 36, 24), (112, 72, 42), (150, 104, 62)]      # outline, base, light
RAG = [(120, 110, 96), (176, 164, 140)]
FLAME = [(190, 70, 20), (236, 132, 28), (250, 206, 70), (255, 244, 190)]


def main() -> None:
    if OUT.exists() and os.environ.get("ICONS_FORCE") != "1":
        print(f"{OUT.relative_to(ROOT)} exists (ICONS_FORCE=1 to redraw)")
        return
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = im.load()

    def put(x, y, c):
        if 0 <= x < 16 and 0 <= y < 16:
            px[x, y] = c + (255,)

    # stick: 2 px wide diagonal from (2,14) up to (9,7)
    for i in range(8):
        x, y = 2 + i, 14 - i
        put(x, y, WOOD[1])
        put(x + 1, y, WOOD[2] if i % 3 else WOOD[1])
        put(x, y + 1, WOOD[0])          # dark underside
    # rag wrap near the head
    for i in range(2):
        x, y = 8 + i, 8 - i
        put(x, y, RAG[1]); put(x + 1, y, RAG[0]); put(x, y + 1, RAG[0])
    # flame: teardrop above the head, lit top-left
    flame = {
        (11, 1): 3, (10, 2): 3, (11, 2): 2, (12, 2): 1,
        (9, 3): 2, (10, 3): 3, (11, 3): 2, (12, 3): 1, (13, 3): 0,
        (9, 4): 1, (10, 4): 2, (11, 4): 2, (12, 4): 1, (13, 4): 0,
        (10, 5): 1, (11, 5): 1, (12, 5): 0,
        (11, 6): 0,
    }
    for (x, y), t in flame.items():
        put(x, y, FLAME[t])
    # tinted sel-out outline around the stick (not the flame - it glows)
    src = im.copy().load()
    for y in range(16):
        for x in range(16):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < 16 and 0 <= yy < 16 and src[xx, yy][3] and src[xx, yy][:3] in WOOD + RAG:
                        put(x, y, WOOD[0])
                        break
    OUT.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)}")


PLACED = ROOT / "assets" / "sprites" / "objects" / "torch_placed.png"


def placed() -> None:
    """The planted torch (objects.json torch_placed, 1x2 cells = 8x16 px): a bracketed stick with
    a two-frame flickering flame; the strip plays ping-pong through WorldObject's sway clock."""
    if PLACED.exists() and os.environ.get("ICONS_FORCE") != "1":
        print(f"{PLACED.relative_to(ROOT)} exists (ICONS_FORCE=1 to redraw)")
        return
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = im.load()

    def put(x, y, c):
        if 0 <= x < 16 and 0 <= y < 16:
            px[x, y] = c + (255,)

    for f in range(2):
        ox = f * 8
        # stick, 2 px wide, rows 8-15, dark right edge
        for y in range(8, 16):
            put(ox + 3, y, WOOD[1])
            put(ox + 4, y, WOOD[0])
        # rag wrap
        put(ox + 3, 8, RAG[1]); put(ox + 4, 8, RAG[0]); put(ox + 2, 9, RAG[0]); put(ox + 5, 9, RAG[0])
        # flame: frame 0 leans left, frame 1 leans right and is a pixel taller
        if f == 0:
            flame = {(3, 2): 3, (2, 3): 2, (3, 3): 3, (4, 3): 1, (2, 4): 1, (3, 4): 2, (4, 4): 2, (5, 4): 0,
                     (2, 5): 0, (3, 5): 1, (4, 5): 1, (5, 5): 0, (3, 6): 0, (4, 6): 0, (3, 7): 0, (4, 7): 0}
        else:
            flame = {(4, 1): 3, (3, 2): 2, (4, 2): 3, (5, 2): 1, (3, 3): 1, (4, 3): 2, (5, 3): 2, (2, 4): 0,
                     (3, 4): 1, (4, 4): 2, (5, 4): 1, (2, 5): 0, (3, 5): 1, (4, 5): 1, (5, 5): 0,
                     (3, 6): 0, (4, 6): 0, (3, 7): 0, (4, 7): 0}
        for (x, y), t in flame.items():
            put(ox + x, y, FLAME[t])
    PLACED.parent.mkdir(parents=True, exist_ok=True)
    im.save(PLACED)
    print(f"wrote {PLACED.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
    placed()
