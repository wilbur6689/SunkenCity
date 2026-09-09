"""Convert dropped-in sound effects into game SFX.

Each entry in SOURCES maps a game sfx name (what `Audio.play_sfx` / `play_world_sfx`
loads from assets/audio/sfx/<name>.wav) to a source recording under docs/Examples/Audio.
The source is mixed to mono, resampled to 44.1 kHz 16-bit, trimmed to the sound
(leading silence dropped, a short tail after the last audible block), and peak-
normalised. Re-runs overwrite: the conversion is deterministic. Requires ffmpeg on PATH.

    python tools/convert_sfx.py            # convert every entry
    python tools/convert_sfx.py sword_swoosh
"""
import array
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "audio" / "sfx"

SOURCES = {
    # weapon swing sweep (user drop 2026-09-07)
    "sword_swoosh": ROOT / "docs/Examples/Audio/sfx/character/SwordSwoosh.wav",
}

RATE = 44100
THRESHOLD = 0.02   # of peak: below this a 20 ms block counts as silence
LEAD_MS = 10       # keep this much before the first audible block
TAIL_MS = 120      # and this much after the last one
PEAK = 0.9         # normalise the loudest sample to this


def convert(name: str, src: Path) -> None:
    if not src.exists():
        print(f"  {name}: missing source {src}")
        return
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td) / "mono.wav"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-ac", "1",
                        "-ar", str(RATE), "-sample_fmt", "s16", str(tmp)], check=True)
        with wave.open(str(tmp)) as w:
            samples = array.array("h", w.readframes(w.getnframes()))
    blk = RATE // 50
    peak = max(1, max(abs(s) for s in samples))
    audible = [i for i in range(0, len(samples), blk)
               if max((abs(s) for s in samples[i:i + blk]), default=0) >= peak * THRESHOLD]
    if not audible:
        print(f"  {name}: silent source")
        return
    start = max(0, audible[0] - RATE * LEAD_MS // 1000)
    end = min(len(samples), audible[-1] + blk + RATE * TAIL_MS // 1000)
    cut = samples[start:end]
    gain = PEAK * 32767 / peak
    out = array.array("h", (int(max(-32768, min(32767, s * gain))) for s in cut))
    # a short fade at both ends so the trim never clicks
    fade = min(len(out) // 4, RATE * 5 // 1000)
    for i in range(fade):
        out[i] = int(out[i] * i / fade)
        out[-1 - i] = int(out[-1 - i] * i / fade)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    dst = OUT_DIR / f"{name}.wav"
    with wave.open(str(dst), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(out.tobytes())
    print(f"  {name}: {len(out) / RATE:.2f} s -> {dst.relative_to(ROOT)}")


def main(argv: list[str]) -> None:
    names = argv or list(SOURCES)
    for name in names:
        if name not in SOURCES:
            print(f"  unknown sfx {name}; known: {', '.join(SOURCES)}")
            continue
        convert(name, SOURCES[name])


if __name__ == "__main__":
    main(sys.argv[1:])
