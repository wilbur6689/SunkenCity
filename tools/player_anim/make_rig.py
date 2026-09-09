"""Rig the diver's rest frame for the character-animation composer.

Writes rest.png (frame 0 of assets/sprites/player.png), mask.png (parts by row band +
the near arm's column band + skin) and rig.json. Re-run after the rest frame changes.
    python tools/player_anim/make_rig.py
"""
import json
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
rest = Image.open(ROOT / "assets/sprites/player.png").convert("RGBA").crop((0, 0, 32, 32))
rest.save(HERE / "rest.png")
COL = {"head": (255, 0, 0), "torso": (0, 255, 0), "arm_near": (0, 0, 255),
       "leg_near": (255, 255, 0), "leg_far": (255, 0, 255)}
mask = Image.new("RGBA", rest.size, (0, 0, 0, 0))
src, dst = rest.load(), mask.load()
for y in range(32):
    for x in range(32):
        if src[x, y][3] == 0:
            continue
        if y <= 12:
            part = "head"                       # hair + face (rows 1-12)
        elif y <= 22:
            part = "arm_near" if (13 <= x <= 15 and y >= 15) else "torso"  # near arm hangs on the front
        else:
            part = "leg_near" if x >= 16 else "leg_far"                    # legs split at the midline
        dst[x, y] = COL[part] + (255,)
mask.save(HERE / "mask.png")
rig = {"feet_y": 31, "parts": {
    "head":     {"color": [255, 0, 0],   "pivot": [15, 13], "z": 5},
    "torso":    {"color": [0, 255, 0],   "pivot": [15, 14], "z": 3},
    "arm_near": {"color": [0, 0, 255],   "pivot": [14, 14], "z": 6, "hand": [14, 22], "over": "torso"},
    "leg_near": {"color": [255, 255, 0], "pivot": [17, 22], "z": 4},
    "leg_far":  {"color": [255, 0, 255], "pivot": [14, 22], "z": 2}}}
json.dump(rig, open(HERE / "rig.json", "w"), indent=2)
print("rig written")
