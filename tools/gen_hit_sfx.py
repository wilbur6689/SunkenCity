"""Hit sounds (user request 2026-09-06): synthesised, no source samples.

  player_hurt_1..3.wav  - a dull body thud with a short low grunt (the player took a hit)
  enemy_hit_1..3.wav    - a wet crunch: noise burst + a falling squelch (a monster took a hit)

16-bit mono 44.1 kHz like the other sfx. Deterministic per take. Run from the
repo root:  python tools/gen_hit_sfx.py
"""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio" / "sfx"
SR = 44100


def write(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.85 / peak
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))
    print("wrote", name, "%.0f ms" % (len(samples) * 1000.0 / SR))


def env(t, attack, decay):
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def player_hurt(take):
    rng = random.Random(100 + take)
    dur = 0.22 + rng.uniform(0.0, 0.05)
    n = int(SR * dur)
    f0 = 170.0 + rng.uniform(-15, 15)   # thud pitch, sweeping down
    g0 = 120.0 + rng.uniform(-10, 20)   # grunt fundamental
    out = []
    for i in range(n):
        t = i / SR
        thud = math.sin(2 * math.pi * (f0 * t - 60.0 * t * t)) * env(t, 0.003, 0.05)
        noise = (rng.random() * 2 - 1) * env(t, 0.002, 0.02) * 0.6
        grunt = 0.0
        if t > 0.03:
            tg = t - 0.03
            vib = 1.0 + 0.02 * math.sin(2 * math.pi * 28 * tg)
            grunt = (math.sin(2 * math.pi * g0 * vib * tg) * 0.6 + math.sin(2 * math.pi * 2 * g0 * vib * tg) * 0.25
                     + math.sin(2 * math.pi * 3 * g0 * vib * tg) * 0.1) * env(tg, 0.015, 0.07) * 0.7
        out.append(thud * 0.9 + noise + grunt)
    return out


def enemy_hit(take):
    rng = random.Random(200 + take)
    dur = 0.16 + rng.uniform(0.0, 0.05)
    n = int(SR * dur)
    f0 = 420.0 + rng.uniform(-60, 60)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SR
        raw = (rng.random() * 2 - 1)
        lp += (raw - lp) * 0.35                      # crude low-pass: wetter crunch
        crunch = lp * env(t, 0.002, 0.03) * 1.2
        squelch = math.sin(2 * math.pi * (f0 * t - 900.0 * t * t)) * env(t, 0.004, 0.045) * 0.6
        pop = math.sin(2 * math.pi * 90 * t) * env(t, 0.001, 0.02) * 0.5
        out.append(crunch + squelch + pop)
    return out


def main():
    for k in range(1, 4):
        write("player_hurt_%d.wav" % k, player_hurt(k))
        write("enemy_hit_%d.wav" % k, enemy_hit(k))


if __name__ == "__main__":
    main()
