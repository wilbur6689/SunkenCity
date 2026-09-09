"""Track the player's hand across the walk cycle (user request 2026-09-07).

Scans assets/sprites/player.png (32x32 frames; row 0 east, row 1 west; col 0
idle, cols 1-6 walk) for the skin-coloured forearm below the face and takes the
centre of its lowest row as the HAND pixel of that frame. Writes
data/hand_anchors.json: {"east": [[x, y] x 7], "west": [[x, y] x 7]} in frame
pixel coordinates. The held weapon's rest pose follows the frame's hand, so it
swings with the arm instead of floating beside a moving body
(Player._rest_centre reads it through Data.hand_anchors).

    python tools/gen_hand_anchors.py [--print]
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "assets" / "sprites" / "player.png"
OUT = ROOT / "data" / "hand_anchors.json"

FRAME = 32
COLS = 7
SKIN = [(231, 162, 128), (199, 142, 106), (132, 81, 70), (229, 166, 128)]
SKIN_TOLERANCE = 12  # per-channel: the west row is hand-drawn with its own skin tones


def is_skin(px):
    if px[3] == 0:
        return False
    return any(all(abs(px[i] - ref[i]) <= SKIN_TOLERANCE for i in range(3)) for ref in SKIN)
ARM_TOP = 14   # rows above this are the face
FEET_ROW = 25  # clusters reaching this low are boots, not hands
MIN_SIZE = 3


def clusters(points):
    points = set(points)
    out = []
    while points:
        seed = points.pop()
        stack = [seed]
        cluster = [seed]
        while stack:
            x, y = stack.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (x + dx, y + dy)
                    if q in points:
                        points.remove(q)
                        stack.append(q)
                        cluster.append(q)
        out.append(cluster)
    return out


def hand_of(im, col, row):
    ox, oy = col * FRAME, row * FRAME
    skin = [(x, y) for y in range(ARM_TOP, FRAME) for x in range(FRAME)
            if is_skin(im.getpixel((ox + x, oy + y)))]
    arms = [c for c in clusters(skin) if len(c) >= MIN_SIZE and max(y for _, y in c) < FEET_ROW]
    if not arms:
        raise SystemExit(f"no forearm found in frame col {col} row {row}")
    arm = max(arms, key=len)
    bottom = max(y for _, y in arm)
    xs = [x for x, y in arm if y == bottom]
    return [round(sum(xs) / len(xs), 1), bottom]


def main(argv):
    im = Image.open(SHEET).convert("RGBA")
    if im.size != (FRAME * COLS, FRAME * 2):
        raise SystemExit(f"unexpected sheet size {im.size}")
    data = {"east": [hand_of(im, c, 0) for c in range(COLS)],
            "west": [hand_of(im, c, 1) for c in range(COLS)]}
    OUT.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}")
    if "--print" in argv:
        for k, v in data.items():
            print(k, v)


if __name__ == "__main__":
    main(sys.argv[1:])
