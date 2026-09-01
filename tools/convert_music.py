"""Convert music/ambient source WAVs from the audio drop folder into the
game's OGG assets (docs/Examples/Audio/README.md workflow).

Music: docs/Examples/Audio/music/*.wav -> assets/audio/music/<lowercase>.ogg
Only converts when the source is newer than the target (or the target is
missing), so re-runs are cheap. Requires ffmpeg on PATH.

After adding a NEW track, also add its path to MUSIC_POOLS in
scripts/audio/audio_manager.gd (adventure* -> adventure pool, threat* -> threat).
"""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
JOBS = [
    (ROOT / "docs" / "Examples" / "Audio" / "music", ROOT / "assets" / "audio" / "music"),
]


def main() -> int:
    converted = 0
    for src_dir, out_dir in JOBS:
        if not src_dir.exists():
            continue
        out_dir.mkdir(parents=True, exist_ok=True)
        for wav in sorted(src_dir.glob("*.wav")):
            ogg = out_dir / (wav.stem.lower() + ".ogg")
            if ogg.exists() and ogg.stat().st_mtime >= wav.stat().st_mtime:
                continue
            cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav),
                   "-c:a", "libvorbis", "-q:a", "5", str(ogg)]
            print("convert", wav.name, "->", ogg.relative_to(ROOT))
            if subprocess.call(cmd) != 0:
                print("FAILED:", wav)
                return 1
            converted += 1
    print("done: %d converted" % converted)
    return 0


if __name__ == "__main__":
    sys.exit(main())
