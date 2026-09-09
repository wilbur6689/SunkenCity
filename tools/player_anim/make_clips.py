"""Author the diver's locomotion clips for the character-animation composer.

Writes clips.json + project.json next to this file; then build with
    python .claude/skills/character-animation/charanim.py build tools/player_anim/project.json
which renders assets/sprites/player_clips.png + data/player_anim.json (+ preview.png, gifs/).

Sign convention (clips.md): a hanging limb swings BACK at +rot, FORWARD at -rot. Body rot +85
lays the standing figure along the ground, head forward; body dx recentres that prone body in
the 48-wide cell. In a prone pose the standing "up" is prone FORWARD and the standing
"forward" is prone DOWN (into the ground), so a crawl arm reaching forward is rot -150.
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
# After rotating about the FEET the lying body straddles the ground row: lift it by half its
# thickness so it rests ON the ground (the cell bottom = the body origin's FEET_Y).
PRONE = {"rot": 85, "dx": -13, "dy": -7}
SWIM = {"rot": 80, "dx": -13, "dy": -7}


def prone(extra=None):
    d = dict(PRONE)
    d.update(extra or {})
    return d


def key(t, pose, ease=None):
    k = {"t": t, "pose": pose}
    if ease:
        k["ease"] = ease
    return k


def stride(a, b, lean, bob_down, flight, fps):
    """A 6-frame CONTACT / DOWN / FLIGHT cycle for each leg (walk-family)."""
    return {"fps": fps, "loop": True, "frames": 6, "keys": [
        key(0, {"leg_near": {"rot": a}, "leg_far": {"rot": -b}, "arm_near": {"rot": -a}, "body": {"lean": lean, "dy": 0}}),
        key(1, {"leg_near": {"rot": a * 0.3}, "leg_far": {"rot": -b * 0.2}, "arm_near": {"rot": -a * 0.3}, "body": {"dy": bob_down}}),
        key(2, {"leg_near": {"rot": -8}, "leg_far": {"rot": 8}, "arm_near": {"rot": 8}, "body": {"dy": flight}}),
        key(3, {"leg_near": {"rot": -b}, "leg_far": {"rot": a}, "arm_near": {"rot": b}, "body": {"dy": 0}}),
        key(4, {"leg_near": {"rot": -b * 0.2}, "leg_far": {"rot": a * 0.3}, "arm_near": {"rot": b * 0.3}, "body": {"dy": bob_down}}),
        key(5, {"leg_near": {"rot": 8}, "leg_far": {"rot": -8}, "arm_near": {"rot": -8}, "body": {"dy": flight}}),
        key(6, {"leg_near": {"rot": a}, "leg_far": {"rot": -b}, "arm_near": {"rot": -a}, "body": {"dy": 0}}),
    ]}


clips = {
    "idle": {"fps": 4, "loop": True, "frames": 4, "keys": [
        key(0, {"head": {"dy": 0}, "torso": {"dy": 0}, "arm_near": {"dy": 0}}),
        key(2, {"head": {"dy": -1}, "torso": {"dy": -1}, "arm_near": {"dy": -1}}),
        key(4, {"head": {"dy": 0}, "torso": {"dy": 0}, "arm_near": {"dy": 0}}),
    ]},
    "sprint": stride(45, 40, 4, 2, -1, 12),
    "jump_launch": {"fps": 12, "loop": False, "frames": 2, "hold": {"0": 2}, "keys": [
        key(0, {"body": {"squash": 0.85}, "arm_near": {"rot": 30}, "leg_near": {"rot": -12}, "leg_far": {"rot": 12}, "head": {"dy": 1}}, "in"),
        key(1, {"body": {"squash": 1.08}, "arm_near": {"rot": -60}, "leg_near": {"rot": 0}, "leg_far": {"rot": 0}, "head": {"dy": 0}}),
    ]},
    "rise": {"fps": 4, "loop": True, "frames": 2, "keys": [
        key(0, {"leg_near": {"rot": -25}, "leg_far": {"rot": 15}, "arm_near": {"rot": -120}, "body": {"squash": 1.0}}),
        key(1, {"leg_near": {"rot": -30}, "leg_far": {"rot": 18}, "arm_near": {"rot": -110}}),
    ]},
    "fall": {"fps": 4, "loop": True, "frames": 2, "keys": [
        key(0, {"leg_near": {"rot": -12}, "leg_far": {"rot": 10}, "arm_near": {"rot": -60}, "body": {"squash": 1.03}}),
        key(1, {"leg_near": {"rot": -16}, "leg_far": {"rot": 6}, "arm_near": {"rot": -45}}),
    ]},
    "land": {"fps": 10, "loop": False, "frames": 3, "hold": {"1": 2}, "keys": [
        key(0, {"body": {"squash": 1.0}, "arm_near": {"rot": -40}}, "in"),
        key(1, {"body": {"squash": 0.8}, "arm_near": {"rot": 20}, "head": {"dy": 1}}, "out"),
        key(2, {"body": {"squash": 1.0}, "arm_near": {"rot": 0}, "head": {"dy": 0}}),
    ]},
    "crawl": {"fps": 8, "loop": True, "frames": 6, "keys": [
        key(0, {"body": prone(), "head": {"rot": -70}, "arm_near": {"rot": -150}, "leg_near": {"rot": 30}, "leg_far": {"rot": 5}}),
        key(2, {"body": prone({"dy": -6}), "arm_near": {"rot": -90}, "leg_near": {"rot": 5}, "leg_far": {"rot": 30}}),
        key(3, {"body": prone(), "arm_near": {"rot": -30}, "leg_near": {"rot": 0}, "leg_far": {"rot": 35}}),
        key(5, {"body": prone({"dy": -6}), "arm_near": {"rot": -110}, "leg_near": {"rot": 30}, "leg_far": {"rot": 5}}),
        key(6, {"body": prone(), "arm_near": {"rot": -150}, "leg_near": {"rot": 30}, "leg_far": {"rot": 5}}),
    ]},
    "prone_idle": {"fps": 4, "loop": True, "frames": 4, "keys": [
        key(0, {"body": prone(), "head": {"rot": -70}, "arm_near": {"rot": -110}, "leg_near": {"rot": 10}, "leg_far": {"rot": 5}}),
        key(2, {"body": prone({"dy": -8}), "head": {"rot": -75}}),
        key(4, {"body": prone(), "head": {"rot": -70}}),
    ]},
    "climb": {"fps": 8, "loop": True, "frames": 4, "keys": [
        key(0, {"arm_near": {"rot": -150}, "leg_near": {"rot": -35}, "leg_far": {"rot": 5}, "body": {"dy": 0}}),
        key(1, {"arm_near": {"rot": -140}, "leg_near": {"rot": -30}, "leg_far": {"rot": 0}, "body": {"dy": -1}}),
        key(2, {"arm_near": {"rot": -60}, "leg_near": {"rot": 5}, "leg_far": {"rot": -35}, "body": {"dy": 0}}),
        key(3, {"arm_near": {"rot": -70}, "leg_near": {"rot": 0}, "leg_far": {"rot": -30}, "body": {"dy": -1}}),
        key(4, {"arm_near": {"rot": -150}, "leg_near": {"rot": -35}, "leg_far": {"rot": 5}, "body": {"dy": 0}}),
    ]},
    "climb_hang": {"fps": 3, "loop": True, "frames": 2, "keys": [
        key(0, {"arm_near": {"rot": -165}, "leg_near": {"rot": 0}, "leg_far": {"rot": 6}, "body": {"lean": 0}}),
        key(1, {"arm_near": {"rot": -160}, "leg_near": {"rot": 4}, "leg_far": {"rot": 2}, "body": {"lean": 1}}),
    ]},
    "climb_idle": {"fps": 3, "loop": True, "frames": 2, "keys": [
        key(0, {"arm_near": {"rot": -150}, "leg_near": {"rot": -25}, "leg_far": {"rot": 5}, "body": {"dy": 0}}),
        key(1, {"arm_near": {"rot": -148}, "leg_near": {"rot": -25}, "leg_far": {"rot": 5}, "body": {"dy": -1}}),
    ]},
    "tread_water": {"fps": 6, "loop": True, "frames": 6, "keys": [
        key(0, {"arm_near": {"rot": -25}, "leg_near": {"rot": -15}, "leg_far": {"rot": 15}, "body": {"dy": 0}}),
        key(1.5, {"arm_near": {"rot": 0}, "leg_near": {"rot": 0}, "leg_far": {"rot": 0}, "body": {"dy": 1}}),
        key(3, {"arm_near": {"rot": 25}, "leg_near": {"rot": 15}, "leg_far": {"rot": -15}, "body": {"dy": 0}}),
        key(4.5, {"arm_near": {"rot": 0}, "leg_near": {"rot": 0}, "leg_far": {"rot": 0}, "body": {"dy": -1}}),
        key(6, {"arm_near": {"rot": -25}, "leg_near": {"rot": -15}, "leg_far": {"rot": 15}, "body": {"dy": 0}}),
    ]},
    "prone_swim": {"fps": 8, "loop": True, "frames": 6, "keys": [
        key(0, {"body": dict(SWIM), "head": {"rot": -60}, "arm_near": {"rot": -160}, "leg_near": {"rot": 12}, "leg_far": {"rot": -8}}),
        key(2, {"arm_near": {"rot": -60}, "leg_near": {"rot": -8}, "leg_far": {"rot": 12}}),
        key(3, {"arm_near": {"rot": 20}, "leg_near": {"rot": 12}, "leg_far": {"rot": -8}}),
        key(4.5, {"arm_near": {"rot": 110}, "leg_near": {"rot": -8}, "leg_far": {"rot": 12}}),
        key(6, {"arm_near": {"rot": 200}, "leg_near": {"rot": 12}, "leg_far": {"rot": -8}}),
    ]},
    "underwater_float": {"fps": 4, "loop": True, "frames": 6, "keys": [
        key(0, {"body": {"rot": 65, "dx": -10, "dy": -6}, "head": {"rot": -40}, "arm_near": {"rot": -30}, "leg_near": {"rot": 10}, "leg_far": {"rot": -5}}),
        key(3, {"body": {"rot": 75, "dx": -12, "dy": -7}, "head": {"rot": -50}, "arm_near": {"rot": -60}, "leg_near": {"rot": -5}, "leg_far": {"rot": 10}}),
        key(6, {"body": {"rot": 65, "dx": -10, "dy": -6}, "head": {"rot": -40}, "arm_near": {"rot": -30}, "leg_near": {"rot": 10}, "leg_far": {"rot": -5}}),
    ]},
}

# ---- Actions (docs/PlayerAnimations.md section 2; the tool sprite is procedural on top).
# harvest_chop / weapon_swing are PHASE-DRIVEN in the engine: the body frame is picked from
# the tool's own phase, so the `hold` shares below carve the frames to the tool's timing
# (chop: lift 0-0.6, strike 0.6-0.85, hold; swing: wind 0-0.28, sweep 0.28-0.52, return).
clips.update({
    "tool_carry": {"fps": 2, "loop": True, "frames": 2, "keys": [
        key(0, {"arm_near": {"rot": 12, "dx": 1}, "torso": {"dy": 0}, "head": {"dy": 0}, "body": {"lean": 1}}),
        key(1, {"torso": {"dy": -1}, "head": {"dy": -1}, "arm_near": {"rot": 12, "dx": 1, "dy": -1}}),
        key(2, {"torso": {"dy": 0}, "head": {"dy": 0}, "arm_near": {"rot": 12, "dx": 1, "dy": 0}}),
    ]},
    "harvest_chop": {"fps": 6, "loop": False, "frames": 6,
                     "hold": {"0": 1.2, "1": 1.2, "2": 1.2, "3": 0.9, "4": 0.6, "5": 0.9}, "keys": [
        key(0, {"arm_near": {"rot": -20}, "body": {"lean": 0, "squash": 1.0}, "head": {"dy": 0}, "leg_near": {"rot": 0}}),
        key(1, {"arm_near": {"rot": -70}, "body": {"lean": -2}}),
        key(2, {"arm_near": {"rot": -150}, "body": {"lean": -1}, "head": {"dy": -1}}),
        key(3, {"arm_near": {"rot": -40}, "body": {"lean": 1}, "head": {"dy": 0}}, "in"),
        key(4, {"arm_near": {"rot": 50}, "body": {"lean": 3, "squash": 0.96}, "head": {"dy": 1}, "leg_near": {"rot": -6}}),
        key(5, {"arm_near": {"rot": 40}, "body": {"lean": 2, "squash": 1.0}, "head": {"dy": 0}, "leg_near": {"rot": -4}}),
    ]},
    "weapon_swing": {"fps": 6, "loop": False, "frames": 6,
                     "hold": {"0": 0.6, "1": 1.08, "2": 0.72, "3": 0.72, "4": 1.38, "5": 1.5}, "keys": [
        key(0, {"arm_near": {"rot": -10}, "body": {"lean": 0}, "head": {"dy": 0}, "leg_near": {"rot": 0}}),
        key(1, {"arm_near": {"rot": 45}, "body": {"lean": -2}, "head": {"dy": 0}}),
        key(2, {"arm_near": {"rot": -120}, "body": {"lean": 0}, "head": {"dy": -1}}, "in"),
        key(3, {"arm_near": {"rot": 30}, "body": {"lean": 4}, "head": {"dy": 1}, "leg_near": {"rot": -10}}),
        key(4, {"arm_near": {"rot": 50}, "body": {"lean": 2}, "head": {"dy": 0}, "leg_near": {"rot": -6}}, "out"),
        key(5, {"arm_near": {"rot": 0}, "body": {"lean": 0}, "leg_near": {"rot": 0}}),
    ]},
    "aim_shoot": {"fps": 12, "loop": False, "frames": 3, "hold": {"0": 1.0, "1": 1.0, "2": 1.5}, "keys": [
        key(0, {"arm_near": {"rot": -90}, "body": {"lean": 1}, "head": {"dx": 0, "dy": 0}}),
        key(1, {"arm_near": {"rot": -82}, "body": {"lean": -1}, "head": {"dx": -1, "dy": -1}}),
        key(2, {"arm_near": {"rot": -90}, "body": {"lean": 1}, "head": {"dx": 0, "dy": 0}}),
    ]},
    "use_item": {"fps": 8, "loop": False, "frames": 5, "hold": {"2": 2}, "keys": [
        key(0, {"arm_near": {"rot": 0}, "head": {"rot": 0}}),
        key(1, {"arm_near": {"rot": -110}}),
        key(2, {"arm_near": {"rot": -125}, "head": {"rot": -5}}),
        key(3, {"arm_near": {"rot": -110}, "head": {"rot": 0}}),
        key(4, {"arm_near": {"rot": 0}}),
    ]},
    "place": {"fps": 10, "loop": False, "frames": 4, "hold": {"2": 1.5}, "keys": [
        key(0, {"arm_near": {"rot": -30}, "body": {"lean": 0, "squash": 1.0}}),
        key(1, {"arm_near": {"rot": 30}, "body": {"lean": 2, "squash": 0.96}}),
        key(2, {"arm_near": {"rot": 35}, "body": {"lean": 2, "squash": 0.96}}),
        key(3, {"arm_near": {"rot": 10}, "body": {"lean": 0, "squash": 1.0}}),
    ]},
    "interact": {"fps": 10, "loop": False, "frames": 3, "hold": {"1": 2}, "keys": [
        key(0, {"arm_near": {"rot": -30}, "body": {"lean": 1}}),
        key(1, {"arm_near": {"rot": -38}, "body": {"lean": 2}}),
        key(2, {"arm_near": {"rot": 0}, "body": {"lean": 0}}),
    ]},
    "pick_up": {"fps": 10, "loop": False, "frames": 5, "keys": [
        key(0, {"arm_near": {"rot": -20}, "body": {"lean": 0, "squash": 1.0}, "head": {"dy": 0}}),
        key(1, {"arm_near": {"rot": 10}, "body": {"lean": 4, "squash": 0.85}, "head": {"dy": 2}}),
        key(2, {"arm_near": {"rot": 20}, "body": {"lean": 4, "squash": 0.85}, "head": {"dy": 2}}),
        key(3, {"arm_near": {"rot": 20}, "body": {"lean": 1, "squash": 1.0}, "head": {"dy": 0}}, "out"),
        key(4, {"arm_near": {"rot": 0}, "body": {"lean": 0}}),
    ]},
})

# ---- Reactions and status (docs/PlayerAnimations.md section 3).
LIE = {"rot": 88, "dx": -13, "dy": -7}   # collapsed flat on the ground, head forward
clips.update({
    "hurt": {"fps": 12, "loop": False, "frames": 3, "keys": [
        key(0, {"head": {"rot": -15, "dx": -1}, "body": {"lean": -3}, "arm_near": {"rot": -30}}, "out"),
        key(1, {"head": {"rot": -8, "dx": 0}, "body": {"lean": -2}, "arm_near": {"rot": -15}}),
        key(2, {"head": {"rot": 0}, "body": {"lean": 0}, "arm_near": {"rot": 0}}),
    ]},
    "drowning": {"fps": 8, "loop": True, "frames": 6, "keys": [
        key(0, {"arm_near": {"rot": -160}, "head": {"dy": 0}, "body": {"rot": -6, "dy": 0}, "leg_near": {"rot": -25}, "leg_far": {"rot": 20}}),
        key(1, {"arm_near": {"rot": -40}, "head": {"dy": 2}, "body": {"rot": 8, "dy": 2}, "leg_near": {"rot": 20}, "leg_far": {"rot": -25}}),
        key(2, {"arm_near": {"rot": -150}, "head": {"dy": -1}, "body": {"rot": -4, "dy": -1}, "leg_near": {"rot": -30}, "leg_far": {"rot": 10}}),
        key(3, {"arm_near": {"rot": -70}, "head": {"dy": 2}, "body": {"rot": 6, "dy": 2}, "leg_near": {"rot": 25}, "leg_far": {"rot": -15}}),
        key(4, {"arm_near": {"rot": -165}, "head": {"dy": 0}, "body": {"rot": -8, "dy": 0}, "leg_near": {"rot": -20}, "leg_far": {"rot": 25}}),
        key(5, {"arm_near": {"rot": -100}, "head": {"dy": 1}, "body": {"rot": 3, "dy": 1}, "leg_near": {"rot": 10}, "leg_far": {"rot": -20}}),
        key(6, {"arm_near": {"rot": -160}, "head": {"dy": 0}, "body": {"rot": -6, "dy": 0}, "leg_near": {"rot": -25}, "leg_far": {"rot": 20}}),
    ]},
    "death_land": {"fps": 5, "loop": False, "frames": 8, "hold": {"6": 2, "7": 4}, "keys": [
        key(0, {"head": {"rot": -15}, "body": {"lean": -3, "rot": 0, "dx": 0, "dy": 0}, "arm_near": {"rot": -30}, "leg_near": {"rot": 0}, "leg_far": {"rot": 0}}),
        key(1, {"head": {"rot": -10}, "body": {"lean": -4, "dx": -1}, "arm_near": {"rot": -50}}),
        key(2, {"head": {"rot": 10}, "body": {"lean": 0, "rot": 35, "dx": -3, "dy": -1}, "arm_near": {"rot": -80}, "leg_near": {"rot": -30}, "leg_far": {"rot": 15}}, "in"),
        key(3, {"head": {"rot": 25}, "body": {"rot": 65, "dx": -8, "dy": -4}, "arm_near": {"rot": -110}, "leg_near": {"rot": -40}, "leg_far": {"rot": 20}}),
        key(4, {"head": {"rot": 10}, "body": dict(LIE), "arm_near": {"rot": -120}, "leg_near": {"rot": -25}, "leg_far": {"rot": 10}}, "out"),
        key(5, {"head": {"rot": 0}, "body": dict(LIE), "arm_near": {"rot": -110}}),
        key(6, {"body": dict(LIE, dy=-6), "arm_near": {"rot": -90}, "leg_near": {"rot": -15}}),
        key(7, {"body": dict(LIE, dy=-6), "arm_near": {"rot": -85}}),
    ]},
    "death_water": {"fps": 4, "loop": False, "frames": 8, "hold": {"7": 4}, "keys": [
        key(0, {"arm_near": {"rot": -150}, "body": {"rot": -5, "dy": 0}, "head": {"dy": 0}, "leg_near": {"rot": -20}, "leg_far": {"rot": 15}}),
        key(1, {"arm_near": {"rot": -60}, "body": {"rot": 5, "dy": 1}, "head": {"dy": 1}, "leg_near": {"rot": 10}, "leg_far": {"rot": -10}}),
        key(2, {"arm_near": {"rot": -100}, "body": {"rot": 0, "dy": 2}, "head": {"dy": 2}, "leg_near": {"rot": 0}, "leg_far": {"rot": 0}}),
        key(3, {"arm_near": {"rot": -40}, "body": {"rot": 15, "dy": 3}, "head": {"rot": 10, "dy": 2}, "leg_near": {"rot": 10}, "leg_far": {"rot": 5}}),
        key(4, {"arm_near": {"rot": -20}, "body": {"rot": 30, "dy": 3}, "head": {"rot": 15}, "leg_near": {"rot": 15}, "leg_far": {"rot": 8}}),
        key(5, {"arm_near": {"rot": -30}, "body": {"rot": 42, "dy": 2, "dx": -3}, "head": {"rot": 12}, "leg_near": {"rot": 20}, "leg_far": {"rot": 12}}),
        key(6, {"arm_near": {"rot": -25}, "body": {"rot": 46, "dy": 2, "dx": -4}, "head": {"rot": 14}}),
        key(7, {"arm_near": {"rot": -30}, "body": {"rot": 44, "dy": 3, "dx": -4}, "head": {"rot": 12}}),
    ]},
    "wake_bed": {"fps": 6, "loop": False, "frames": 6, "hold": {"0": 2, "3": 1.5}, "keys": [
        key(0, {"body": dict(LIE), "head": {"rot": 0}, "arm_near": {"rot": -110}, "leg_near": {"rot": -10}, "leg_far": {"rot": 5}}),
        key(1, {"body": dict(LIE, dy=-8), "head": {"rot": -10}}),
        key(2, {"body": {"rot": 60, "dx": -8, "dy": -4}, "head": {"rot": -30}, "arm_near": {"rot": -60}, "leg_near": {"rot": -20}}, "in"),
        key(3, {"body": {"rot": 25, "dx": -3, "dy": -1}, "head": {"rot": -15}, "arm_near": {"rot": 20}, "leg_near": {"rot": -25}, "leg_far": {"rot": 5}}),
        key(4, {"body": {"rot": 12, "dx": -1, "dy": 0}, "head": {"rot": -8}, "arm_near": {"rot": 10}, "leg_near": {"rot": -10}}),
        key(5, {"body": {"rot": 0, "dx": 0, "dy": 0}, "head": {"rot": 0}, "arm_near": {"rot": 0}, "leg_near": {"rot": 0}, "leg_far": {"rot": 0}}),
    ]},
    "cold_shiver": {"fps": 12, "loop": True, "frames": 4, "keys": [
        key(0, {"torso": {"dy": 0}, "head": {"dx": 0}, "arm_near": {"rot": 20, "dx": 1}}),
        key(1, {"torso": {"dy": -1}, "head": {"dx": 1}, "arm_near": {"rot": 22, "dx": 1, "dy": -1}}),
        key(2, {"torso": {"dy": 0}, "head": {"dx": 0}, "arm_near": {"rot": 20, "dx": 1, "dy": 0}}),
        key(3, {"torso": {"dy": -1}, "head": {"dx": -1}, "arm_near": {"rot": 18, "dx": 1, "dy": -1}}),
        key(4, {"torso": {"dy": 0}, "head": {"dx": 0}, "arm_near": {"rot": 20, "dx": 1, "dy": 0}}),
    ]},
    "crush_strain": {"fps": 6, "loop": True, "frames": 6, "keys": [
        key(0, {"body": {"squash": 0.92, "lean": 0}, "arm_near": {"rot": -100}, "leg_near": {"rot": -8}, "leg_far": {"rot": 8}, "head": {"dy": 1}}),
        key(1, {"body": {"squash": 0.92, "lean": 1}, "head": {"dy": 2}}),
        key(2, {"body": {"squash": 0.96, "lean": 0}, "arm_near": {"rot": -110}, "head": {"dy": 0}}),
        key(3, {"body": {"squash": 0.92, "lean": -1}, "head": {"dy": 2}}),
        key(4, {"body": {"squash": 0.95, "lean": 0}, "arm_near": {"rot": -105}, "head": {"dy": 1}}),
        key(5, {"body": {"squash": 0.92, "lean": 1}, "head": {"dy": 2}}),
        key(6, {"body": {"squash": 0.92, "lean": 0}, "arm_near": {"rot": -100}, "head": {"dy": 1}}),
    ]},
})

json.dump(clips, open(HERE / "clips.json", "w"), indent=1)
proj = {"rest": "rest.png", "mask": "mask.png", "rig": "rig.json", "clips": "clips.json",
        "out_sheet": "../../assets/sprites/player_clips.png", "out_data": "../../data/player_anim.json",
        "out_preview": "preview.png", "out_gif_dir": "gifs", "cell": [48, 32]}
json.dump(proj, open(HERE / "project.json", "w"), indent=2)
print("clips.json + project.json written")
