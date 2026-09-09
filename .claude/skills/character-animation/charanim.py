"""charanim - rig-and-pose frame composer for small pixel characters.

One REST frame + one PART MASK -> posed frames -> sprite sheet + anim data + previews.

    python charanim.py build project.json          # render sheet, anim.json, previews, gifs
    python charanim.py mask-template rest.png out.png  # grey copy of the rest frame to paint parts on
    python charanim.py check project.json          # rig coverage report, no rendering

project.json
{
  "rest": "rest.png",              # one frame, transparent background, character facing RIGHT
  "mask": "mask.png",              # same size; every opaque rest pixel painted a flat part colour
  "rig":  "rig.json",              # parts, pivots, z-order, hand points, feet row
  "clips": "clips.json",           # key poses + timing per clip
  "out_sheet": "sheet.png",
  "out_data":  "anim.json",
  "out_preview": "preview.png",    # every clip at 1x and 3x on a ground line
  "out_gif_dir": "gifs",           # optional: one gif per clip at 3x
  "cell": [32, 32]                 # optional: output cell (defaults to the rest frame size)
}

rig.json
{
  "feet_y": 31,                                   # first row BELOW the feet (ground line)
  "parts": {
    "head":     {"color": [255, 0, 0],   "pivot": [16, 13], "z": 5},
    "torso":    {"color": [0, 255, 0],   "pivot": [15, 14], "z": 3},
    "arm_near": {"color": [0, 0, 255],   "pivot": [15, 14], "z": 6, "hand": [15, 22], "over": "torso"},
    "arm_far":  {"color": [0, 255, 255], "pivot": [14, 14], "z": 1},
    "leg_near": {"color": [255, 255, 0], "pivot": [16, 22], "z": 4},
    "leg_far":  {"color": [255, 0, 255], "pivot": [14, 22], "z": 2}
  }
}
A pivot is the joint the part rotates about (shoulder, hip, neck). "hand" is the grip point a
held item attaches to; its transformed position per frame is written to anim.json. "over"
names the part this one is drawn on top of: that part is filled in underneath (nearest pixel
on the row), so the body is never hollow when the top part swings away.

clips.json
{
  "walk": {
    "fps": 10, "loop": true, "frames": 6,
    "keys": [
      {"t": 0, "ease": "smooth", "pose": {"leg_near": {"rot": 25}, "leg_far": {"rot": -25},
                                          "arm_near": {"rot": -20}, "arm_far": {"rot": 20},
                                          "body": {"dy": 0}}},
      {"t": 3, "pose": {...}},
      {"t": 6, "pose": <same as t 0>}            # a loop's last key = first key (t == frames)
    ],
    "hold": {"0": 2}                             # optional: frame index -> extra duration (x times)
  }
}
Pose parameters per part: dx, dy (px), rot (degrees, positive = clockwise on screen), flip
(bool), hide (bool). "body" applies to the whole composite: dx, dy, squash (vertical scale
about the feet, 1.0 = none; <1 compresses, >1 stretches), lean (px of x-shift at the head
relative to the feet; positive leans forward), rot (whole-body rotation about the feet centre).
Missing parameters interpolate from neighbouring keys; a clip's first key must set everything it
animates (unset = 0 / 1.0 / false). Ease per key applies to the segment LEAVING that key:
"linear", "in", "out", "smooth" (default smooth).
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw

NEAREST = Image.NEAREST
DEFAULT_PART = {"dx": 0.0, "dy": 0.0, "rot": 0.0, "flip": False, "hide": False}
DEFAULT_BODY = {"dx": 0.0, "dy": 0.0, "squash": 1.0, "lean": 0.0, "rot": 0.0}


# ----------------------------------------------------------------------------- rig

class Part:
    def __init__(self, name, spec, rest, mask):
        self.name = name
        self.pivot = tuple(spec.get("pivot", (rest.width // 2, rest.height // 2)))
        self.z = int(spec.get("z", 0))
        self.hand = tuple(spec["hand"]) if "hand" in spec else None
        col = tuple(spec["color"][:3])
        self.img = Image.new("RGBA", rest.size, (0, 0, 0, 0))
        src = rest.load()
        msk = mask.load()
        dst = self.img.load()
        self.pixels = 0
        for y in range(rest.height):
            for x in range(rest.width):
                if src[x, y][3] > 0 and msk[x, y][:3] == col and msk[x, y][3] > 0:
                    dst[x, y] = src[x, y]
                    self.pixels += 1


class Rig:
    def __init__(self, rest_path, mask_path, rig_path):
        self.rest = Image.open(rest_path).convert("RGBA")
        self.mask = Image.open(mask_path).convert("RGBA")
        if self.mask.size != self.rest.size:
            raise SystemExit("mask and rest frame differ in size")
        spec = json.load(open(rig_path, encoding="utf-8"))
        self.feet_y = int(spec.get("feet_y", self.rest.height))
        self.parts = {n: Part(n, s, self.rest, self.mask) for n, s in spec["parts"].items()}
        # A part drawn OVER another (an arm on the torso) is cut out of that part's
        # pixels; fill the part underneath so nothing is hollow when the top part
        # swings away ("over": "torso" in rig.json).
        for n, s in spec["parts"].items():
            if "over" in s and s["over"] in self.parts:
                _fill_under(self.parts[s["over"]], self.parts[n])
        # coverage: every opaque rest pixel must belong to exactly one part
        src = self.rest.load()
        msk = self.mask.load()
        colours = {tuple(p.mask_color) if hasattr(p, "mask_color") else None for p in []}
        known = {tuple(s["color"][:3]) for s in spec["parts"].values()}
        self.uncovered = []
        for y in range(self.rest.height):
            for x in range(self.rest.width):
                if src[x, y][3] > 0 and (msk[x, y][3] == 0 or msk[x, y][:3] not in known):
                    self.uncovered.append((x, y))

    def report(self):
        lines = [f"rest {self.rest.size[0]}x{self.rest.size[1]}, feet_y {self.feet_y}"]
        for p in sorted(self.parts.values(), key=lambda p: p.z):
            lines.append(f"  z{p.z:2d} {p.name:10s} {p.pixels:4d} px  pivot {p.pivot}"
                         + (f"  hand {p.hand}" if p.hand else ""))
        if self.uncovered:
            lines.append(f"  UNCOVERED: {len(self.uncovered)} rest pixels not in any part, e.g. {self.uncovered[:6]}")
        return "\n".join(lines)


def _fill_under(base, over):
    """Give `base` a pixel wherever `over` covers it, copying the nearest base pixel on
    that row (the shirt continues behind the arm)."""
    b = base.img.load()
    o = over.img.load()
    w, h = base.img.size
    for y in range(h):
        row = [x for x in range(w) if b[x, y][3] > 0]
        if not row:
            continue
        for x in range(w):
            if o[x, y][3] > 0 and b[x, y][3] == 0:
                nearest = min(row, key=lambda rx: abs(rx - x))
                if abs(nearest - x) <= 3:
                    b[x, y] = b[nearest, y]
                    base.pixels += 1


def fill_holes(img):
    """Close 1-px holes: a transparent pixel with 3+ opaque 4-neighbours takes the most
    common neighbour colour. Nearest-neighbour rotation punches such holes in limbs."""
    px = img.load()
    w, h = img.size
    fills = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                continue
            cols = []
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and px[xx, yy][3] > 0:
                    cols.append(px[xx, yy])
            if len(cols) >= 3:
                fills.append((x, y, max(set(cols), key=cols.count)))
    for x, y, c in fills:
        px[x, y] = c
    return img


# ----------------------------------------------------------------------------- poses

def _ease(w, kind):
    if kind == "linear":
        return w
    if kind == "in":
        return w * w
    if kind == "out":
        return 1.0 - (1.0 - w) * (1.0 - w)
    return w * w * (3.0 - 2.0 * w)  # smooth


def _lerp_pose(a, b, w, part_names):
    out = {}
    for name in list(part_names) + ["body"]:
        base = DEFAULT_BODY if name == "body" else DEFAULT_PART
        pa = a.get(name, {})
        pb = b.get(name, {})
        cur = {}
        for k, dflt in base.items():
            va = pa.get(k, dflt)
            vb = pb.get(k, dflt)
            if isinstance(dflt, bool):
                cur[k] = va if w < 0.5 else vb
            else:
                cur[k] = float(va) + (float(vb) - float(va)) * w
        out[name] = cur
    return out


def _fill_keys(keys, part_names):
    """Carry unset parameters forward from earlier keys so a key may set only what changes."""
    filled = []
    running = {}
    for k in keys:
        pose = json.loads(json.dumps(k.get("pose", {})))
        for name in list(part_names) + ["body"]:
            prev = running.get(name, {})
            merged = dict(prev)
            merged.update(pose.get(name, {}))
            pose[name] = merged
        running = pose
        filled.append({"t": float(k["t"]), "ease": k.get("ease", "smooth"), "pose": pose})
    return filled


def frame_poses(clip, part_names):
    n = int(clip["frames"])
    keys = _fill_keys(clip["keys"], part_names)
    if not keys:
        raise SystemExit("clip has no keys")
    poses = []
    for f in range(n):
        t = float(f)
        # find the segment
        if t <= keys[0]["t"]:
            poses.append(_lerp_pose(keys[0]["pose"], keys[0]["pose"], 0.0, part_names))
            continue
        seg = None
        for i in range(len(keys) - 1):
            if keys[i]["t"] <= t <= keys[i + 1]["t"]:
                seg = (keys[i], keys[i + 1])
                break
        if seg is None:
            last = keys[-1]
            poses.append(_lerp_pose(last["pose"], last["pose"], 0.0, part_names))
            continue
        a, b = seg
        span = b["t"] - a["t"]
        w = 0.0 if span <= 0 else (t - a["t"]) / span
        poses.append(_lerp_pose(a["pose"], b["pose"], _ease(w, a["ease"]), part_names))
    return poses


# ----------------------------------------------------------------------------- render

def _rotate_point(px, py, cx, cy, deg_cw):
    """Rotate a point about (cx, cy) by deg_cw degrees clockwise on screen (y down)."""
    a = math.radians(deg_cw)
    dx, dy = px - cx, py - cy
    return (cx + dx * math.cos(a) - dy * math.sin(a), cy + dx * math.sin(a) + dy * math.cos(a))


def render_frame(rig, pose, cell):
    """Compose one frame. Returns (image, anchors{part: (x, y)})."""
    w, h = cell
    ox = (w - rig.rest.width) // 2
    oy = h - rig.rest.height  # rest frame bottom-aligned in the cell
    canvas = Image.new("RGBA", cell, (0, 0, 0, 0))
    anchors = {}
    for part in sorted(rig.parts.values(), key=lambda p: p.z):
        pp = pose.get(part.name, DEFAULT_PART)
        if pp.get("hide"):
            continue
        img = part.img
        cx, cy = part.pivot
        if pp.get("flip"):
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
            cx = rig.rest.width - 1 - cx
        rot = float(pp.get("rot", 0.0))
        dx = int(round(float(pp.get("dx", 0.0))))
        dy = int(round(float(pp.get("dy", 0.0))))
        # PIL rotates counter-clockwise; our rot is clockwise on screen
        moved = img.rotate(-rot, resample=NEAREST, center=(cx, cy), translate=(dx, dy))
        if abs(rot) > 1e-3:
            moved = fill_holes(moved)
        canvas.alpha_composite(moved, (ox, oy))
        if part.hand:
            hx, hy = part.hand
            if pp.get("flip"):
                hx = rig.rest.width - 1 - hx
            rx, ry = _rotate_point(hx, hy, cx, cy, rot)
            anchors[part.name] = (rx + dx + ox, ry + dy + oy)
    body = pose.get("body", DEFAULT_BODY)
    feet = rig.feet_y + oy
    canvas, anchors = _apply_body(canvas, anchors, body, feet, cell)
    return canvas, anchors


def _apply_body(img, anchors, body, feet_y, cell):
    w, h = cell
    squash = float(body.get("squash", 1.0))
    lean = float(body.get("lean", 0.0))
    rot = float(body.get("rot", 0.0))
    dx = int(round(float(body.get("dx", 0.0))))
    dy = int(round(float(body.get("dy", 0.0))))
    bbox = img.getbbox()
    if bbox is None:
        return img, anchors
    if abs(squash - 1.0) > 1e-3:
        x0, y0, x1, y1 = bbox
        region = img.crop((x0, y0, x1, y1))
        nh = max(1, int(round((y1 - y0) * squash)))
        nw = max(1, int(round((x1 - x0) * (1.0 + (1.0 - squash) * 0.5))))  # keep a hint of volume
        region = region.resize((nw, nh), NEAREST)
        out = Image.new("RGBA", cell, (0, 0, 0, 0))
        nx = x0 - (nw - (x1 - x0)) // 2
        out.alpha_composite(region, (nx, y1 - nh))
        img = out
        anchors = {k: (v[0], y1 - (y1 - v[1]) * squash) for k, v in anchors.items()}
    if abs(lean) > 1e-3:
        src = img.load()
        out = Image.new("RGBA", cell, (0, 0, 0, 0))
        dst = out.load()
        span = max(1, feet_y)
        for y in range(h):
            shift = int(round(lean * (feet_y - y) / span))
            for x in range(w):
                if src[x, y][3] > 0 and 0 <= x + shift < w:
                    dst[x + shift, y] = src[x, y]
        img = out
        anchors = {k: (v[0] + lean * (feet_y - v[1]) / span, v[1]) for k, v in anchors.items()}
    if abs(rot) > 1e-3:
        # Rotate AND translate in one affine: a body laid over about its feet swings below the
        # cell, and a separate paste afterwards would have clipped that half away.
        cx = (bbox[0] + bbox[2]) / 2.0
        img = img.rotate(-rot, resample=NEAREST, center=(cx, feet_y), translate=(dx, dy))
        anchors = {k: _rotate_point(v[0], v[1], cx, feet_y, rot) for k, v in anchors.items()}
        anchors = {k: (v[0] + dx, v[1] + dy) for k, v in anchors.items()}
        dx, dy = 0, 0
    if dx or dy:
        out = Image.new("RGBA", cell, (0, 0, 0, 0))
        out.alpha_composite(img, (dx, dy)) if dx >= 0 and dy >= 0 else out.paste(img, (dx, dy), img)
        img = out
        anchors = {k: (v[0] + dx, v[1] + dy) for k, v in anchors.items()}
    return img, anchors


def cleanup(img):
    """Drop isolated single pixels left by nearest-neighbour rotation."""
    px = img.load()
    w, h = img.size
    kill = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            n = 0
            for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + ddx, y + ddy
                if 0 <= xx < w and 0 <= yy < h and px[xx, yy][3] > 0:
                    n += 1
            if n == 0:
                kill.append((x, y))
    for x, y in kill:
        px[x, y] = (0, 0, 0, 0)
    return img


# ----------------------------------------------------------------------------- build

def build(project_path):
    proj = json.load(open(project_path, encoding="utf-8"))
    base = os.path.dirname(os.path.abspath(project_path))
    P = lambda k: os.path.join(base, proj[k])
    rig = Rig(P("rest"), P("mask"), P("rig"))
    print(rig.report())
    clips = json.load(open(P("clips"), encoding="utf-8"))
    cell = tuple(proj.get("cell", rig.rest.size))
    part_names = list(rig.parts.keys())
    rendered = {}  # clip -> [(img, anchors)]
    for name, clip in clips.items():
        frames = []
        for pose in frame_poses(clip, part_names):
            img, anchors = render_frame(rig, pose, cell)
            frames.append((cleanup(fill_holes(img)), anchors))
        rendered[name] = frames
        print(f"  {name}: {len(frames)} frames @ {clip.get('fps', 8)} fps{' loop' if clip.get('loop') else ''}")
    # sheet: one row per clip
    cols = max(len(f) for f in rendered.values())
    sheet = Image.new("RGBA", (cell[0] * cols, cell[1] * len(rendered)), (0, 0, 0, 0))
    data = {"cell": list(cell), "clips": {}}
    for row, (name, frames) in enumerate(rendered.items()):
        clip = clips[name]
        hand_part = next((p.name for p in rig.parts.values() if p.hand), None)
        anchors = []
        for col, (img, anc) in enumerate(frames):
            sheet.alpha_composite(img, (col * cell[0], row * cell[1]))
            a = anc.get(hand_part) if hand_part else None
            anchors.append([round(a[0], 1), round(a[1], 1)] if a else None)
        data["clips"][name] = {"row": row, "frames": len(frames), "fps": clip.get("fps", 8),
                               "loop": bool(clip.get("loop", False)),
                               "hold": clip.get("hold", {}), "anchors": anchors}
    sheet.save(P("out_sheet"))
    json.dump(data, open(P("out_data"), "w", encoding="utf-8"), indent=2)
    _preview(rendered, cell, rig.feet_y + (cell[1] - rig.rest.height), P("out_preview"))
    if proj.get("out_gif_dir"):
        gdir = P("out_gif_dir")
        os.makedirs(gdir, exist_ok=True)
        for name, frames in rendered.items():
            _gif(name, frames, clips[name], cell, os.path.join(gdir, f"{name}.gif"))
    print(f"wrote {proj['out_sheet']}, {proj['out_data']}, {proj['out_preview']}")


def _preview(rendered, cell, feet_y, path):
    """Every clip at 1x and 3x on a ground line - judge at gameplay scale first."""
    cols = max(len(f) for f in rendered.values())
    pad = 4
    row_h = cell[1] * 3 + pad * 2 + 12
    W = (cell[0] * 3 + pad) * cols + 160
    H = row_h * len(rendered)
    out = Image.new("RGBA", (W, H), (58, 132, 168, 255))
    d = ImageDraw.Draw(out)
    for r, (name, frames) in enumerate(rendered.items()):
        y0 = r * row_h + 12
        d.text((4, r * row_h + 1), name, fill=(255, 255, 0, 255))
        # 1x strip on the left
        for c, (img, _) in enumerate(frames):
            x = 4 + c * (cell[0] + 1)
            if x + cell[0] < 160:
                d.line([(x, y0 + feet_y), (x + cell[0], y0 + feet_y)], fill=(90, 90, 100, 255))
                out.alpha_composite(img, (x, y0))
        # 3x strip
        for c, (img, anc) in enumerate(frames):
            x = 160 + c * (cell[0] * 3 + pad)
            big = img.resize((cell[0] * 3, cell[1] * 3), NEAREST)
            d.line([(x, y0 + feet_y * 3), (x + cell[0] * 3, y0 + feet_y * 3)], fill=(90, 90, 100, 255))
            out.alpha_composite(big, (x, y0))
            for k, (ax, ay) in anc.items():
                d.rectangle([x + ax * 3 - 1, y0 + ay * 3 - 1, x + ax * 3 + 1, y0 + ay * 3 + 1], fill=(255, 0, 0, 255))
    out.save(path)


def _gif(name, frames, clip, cell, path):
    fps = float(clip.get("fps", 8))
    hold = {int(k): float(v) for k, v in clip.get("hold", {}).items()}
    imgs = []
    durs = []
    for i, (img, _) in enumerate(frames):
        big = Image.new("RGBA", (cell[0] * 3, cell[1] * 3), (58, 132, 168, 255))
        big.alpha_composite(img.resize((cell[0] * 3, cell[1] * 3), NEAREST))
        imgs.append(big.convert("P", palette=Image.ADAPTIVE))
        durs.append(int(1000.0 / fps * hold.get(i, 1.0)))
    imgs[0].save(path, save_all=True, append_images=imgs[1:], duration=durs, loop=0 if clip.get("loop") else 1)


def mask_template(rest_path, out_path):
    rest = Image.open(rest_path).convert("RGBA")
    out = Image.new("RGBA", rest.size, (0, 0, 0, 0))
    src = rest.load()
    dst = out.load()
    for y in range(rest.height):
        for x in range(rest.width):
            if src[x, y][3] > 0:
                dst[x, y] = (128, 128, 128, 255)
    out.save(out_path)
    print(f"wrote {out_path}: paint each part a flat colour, list the colours in rig.json")


def check(project_path):
    proj = json.load(open(project_path, encoding="utf-8"))
    base = os.path.dirname(os.path.abspath(project_path))
    rig = Rig(os.path.join(base, proj["rest"]), os.path.join(base, proj["mask"]), os.path.join(base, proj["rig"]))
    print(rig.report())


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "build":
        build(sys.argv[2])
    elif cmd == "check":
        check(sys.argv[2])
    elif cmd == "mask-template":
        mask_template(sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
        sys.exit(1)
