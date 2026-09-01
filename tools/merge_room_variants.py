"""Merge validated room-variant files into data/rooms.json.

Usage (from the project root):
    python tools/merge_room_variants.py            # merges every tools/room_variants/*.json
    python tools/merge_room_variants.py a.json b.json

Each file is validated with check_room_variants first; a file with errors is
skipped and reported. Rooms whose id already exists in the library are
replaced (re-runs are safe); new ids are appended. Numbers are written as
ints and keys in the canonical order used by the Room Editor.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import check_room_variants as chk  # noqa: E402

ORDER = ["id", "zone", "type", "width", "height", "depth_min", "depth_max", "objects", "blocks"]


def norm(v):
    if isinstance(v, float) and v.is_integer():
        return int(v)
    if isinstance(v, list):
        return [norm(x) for x in v]
    if isinstance(v, dict):
        return {k: norm(x) for k, x in v.items()}
    return v


def main(files):
    lib_path = ROOT / "data" / "rooms.json"
    lib = json.loads(lib_path.read_text(encoding="utf-8"))
    by_id = {r["id"]: i for i, r in enumerate(lib["rooms"])}
    added = replaced = 0
    for f in files:
        data = json.loads(Path(f).read_text(encoding="utf-8"))
        rooms = data.get("rooms", [])
        errors, seen = [], set()
        # ids from this same file may already be in the library (re-merge) — only
        # collisions with OTHER rooms count.
        chk.EXISTING = {r["id"] for r in lib["rooms"]} - {r.get("id") for r in rooms}
        for r in rooms:
            chk.check_room(r, errors, seen)
        if errors:
            print(f"SKIP {f}: {len(errors)} errors")
            for e in errors:
                print("   ", e)
            continue
        for r in rooms:
            r = norm(r)
            r = {k: r[k] for k in ORDER if k in r} | {k: v for k, v in r.items() if k not in ORDER}
            if r["id"] in by_id:
                lib["rooms"][by_id[r["id"]]] = r
                replaced += 1
            else:
                by_id[r["id"]] = len(lib["rooms"])
                lib["rooms"].append(r)
                added += 1
        print(f"merged {f}: {len(rooms)} rooms")
    lib_path.write_text(json.dumps(norm(lib), indent=1) + "\n", encoding="utf-8")
    print(f"rooms.json: {len(lib['rooms'])} rooms ({added} added, {replaced} replaced)")


if __name__ == "__main__":
    args = sys.argv[1:] or sorted(str(p) for p in (ROOT / "tools" / "room_variants").glob("*.json") if not p.name.startswith("_"))
    main(args)
