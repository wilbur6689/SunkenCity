"""LAN two-process smoke (docs/technical/MultiplayerImpl.md §8; the LAN gate).

Launches a headless HOST (`--host=<port> --seed=<n> --character=lan_host --net-probe=<secs>`),
waits for its `NETHOST ready` line, then runs one or more headless CLIENTS
(`--join=127.0.0.1:<port> --character=lan_alice --net-probe=<secs> --net-drive`) and compares
the NETPROBE lines each process prints once a second.

Scenarios (all on by default; disable with --no-<name>):
  join     client A joins, is driven right for 2 s, leaves through the real leave path
             * grid / water / record hashes equal at A's last probe (host probe at the same t)
             * players == 2 on both ends while A is connected
             * A's lp.x moved
             * A's character file exists on disk afterwards (client-side save)
  rejoin   client B joins with A's character name: its last lp is within a few blocks of
             A's last lp (host-side resume / the client's own file)
  mutate   the host runs --net-mutate (places/mines blocks, pours water, edits a chest,
             spawns an item beside the joining player 2 s after READY); grid and records must
             still match at the end (water may drift out of the client's window: reported)
  closes   the host closes the world while client C is in it: C must land on the title
             with the reason and exit by itself

Exit 0 when every enabled check passes, 1 otherwise. Logs land in tools/_lan_smoke/.

Usage:  python tools/lan_smoke.py [--port 47140] [--seed 900007] [--secs 8]
                                  [--no-rejoin] [--no-mutate] [--no-closes] [--keep-saves]
"""
import argparse
import os
import re
import subprocess
import sys
import time

GODOT = r"C:\Programming\Godot_v4.8\Godot_v4.8-dev2_win64.exe"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "tools", "_lan_smoke")
USER_DIR = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "SunkenCity")
HOST_CHAR = "lan_host"
CLIENT_CHAR = "lan_alice"
BLOCK = 8.0

PROBE_RE = re.compile(
    r"NETPROBE t=(\d+) mode=(\w+) peers=(\d+) players=(\d+) grid=(-?\d+) water=(-?\d+) "
    r"records=(\d+) enemies=(\d+) items=(\d+) lp=([-\d.,]+|none)")

failures = []


def check(cond, msg):
    print(("  ok:   " if cond else "  FAIL: ") + msg)
    if not cond:
        failures.append(msg)


def parse_probe(line):
    m = PROBE_RE.search(line)
    if not m:
        return None
    lp = m.group(10)
    lpx = lpy = None
    if lp != "none":
        lpx, lpy = (float(v) for v in lp.split(","))
    return {"t": int(m.group(1)), "mode": m.group(2), "peers": int(m.group(3)),
            "players": int(m.group(4)), "grid": int(m.group(5)), "water": int(m.group(6)),
            "records": int(m.group(7)), "enemies": int(m.group(8)), "items": int(m.group(9)),
            "lpx": lpx, "lpy": lpy, "wall": None}


def probes_in(path):
    out = []
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            p = parse_probe(line)
            if p:
                out.append(p)
    return out


def read_log(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def launch(args, log_path):
    log = open(log_path, "w", encoding="utf-8", errors="replace")
    proc = subprocess.Popen([GODOT, "--path", ROOT, "--headless", "--"] + args,
                            stdout=log, stderr=subprocess.STDOUT, cwd=ROOT)
    return proc, log


def wait_for_line(path, needle, timeout, proc):
    t0 = time.time()
    while time.time() - t0 < timeout:
        if proc.poll() is not None:
            return needle in read_log(path)
        if needle in read_log(path):
            return True
        time.sleep(0.2)
    return False


def wait_exit(proc, timeout):
    try:
        proc.wait(timeout=timeout)
        return True
    except subprocess.TimeoutExpired:
        proc.kill()
        return False


def script_errors(path):
    txt = read_log(path)
    return txt.count("SCRIPT ERROR") + txt.count("Parse Error")


def host_probe_at(hp, t_wall_hint, players_needed):
    """The host probe to compare against: the last host probe that still saw
    `players_needed` bodies (the client's final state lands before it leaves)."""
    cands = [p for p in hp if p["players"] >= players_needed]
    return cands[-1] if cands else (hp[-1] if hp else None)


def clean_saves(seed):
    for rel in ("saves/worlds/world_%d.world" % seed,
                "saves/chars/%s.char" % HOST_CHAR, "saves/chars/%s.char" % CLIENT_CHAR):
        p = os.path.join(USER_DIR, rel)
        if os.path.exists(p):
            os.remove(p)


def run_client(name, char, port, secs, extra, log_path, timeout):
    proc, log = launch(["--join=127.0.0.1:%d" % port, "--character=%s" % char,
                        "--net-probe=%d" % secs] + extra, log_path)
    exited = wait_exit(proc, timeout)
    log.close()
    check(exited, "%s exited by itself" % name)
    check(script_errors(log_path) == 0, "%s log has no script errors" % name)
    return probes_in(log_path)


def scenario_session(a, port, mutate, closes):
    """One host process; the join (+ rejoin) clients run inside it."""
    tag = "mutate" if mutate else ("closes" if closes else "join")
    host_log = os.path.join(OUT_DIR, "host_%s.log" % tag)
    client_secs = a.secs + (6 if mutate else 0)
    if closes:
        host_secs = 14           # the host closes while C is still probing
        client_secs = 40
    else:
        host_secs = client_secs * (2 if a.rejoin and not mutate else 1) + 20
    host_args = ["--host=%d" % port, "--seed=%d" % a.seed, "--character=%s" % HOST_CHAR,
                 "--net-probe=%d" % host_secs]
    if mutate:
        host_args.append("--net-mutate")
    print("== scenario %s: host port %d seed %d (host %d s, client %d s)" % (tag, port, a.seed, host_secs, client_secs))
    host, hlog = launch(host_args, host_log)
    try:
        if not wait_for_line(host_log, "NETHOST ready", 120.0, host):
            check(False, "host printed NETHOST ready (see %s)" % host_log)
            return
        print("   host up")
        if closes:
            c_log = os.path.join(OUT_DIR, "client_closes.log")
            cp = run_client("client C", CLIENT_CHAR, port, client_secs, [], c_log, host_secs + 60.0)
            txt = read_log(c_log)
            check("NETPROBE disconnected: Disconnected: host closed the world" in txt,
                  "client C landed on the title with 'host closed the world'")
            check(len(cp) >= 2 and cp[-1]["players"] == 2, "client C saw 2 players before the close")
            return
        a_log = os.path.join(OUT_DIR, "client_a_%s.log" % tag)
        ap = run_client("client A", CLIENT_CHAR, port, client_secs, ["--net-drive"], a_log, client_secs + 90.0)
        hp_now = probes_in(host_log)
        if not ap or not hp_now:
            check(False, "NETPROBE lines present (host %d, client %d)" % (len(hp_now), len(ap)))
            return
        c = ap[-1]
        h = host_probe_at(hp_now, None, 2)
        print("   host   @2p: %s" % h)
        print("   client last: %s" % c)
        check(c["mode"] == "client" and h["mode"] == "host", "modes host/client")
        check(h["grid"] == c["grid"], "grid hash equal (%d vs %d)" % (h["grid"], c["grid"]))
        if mutate:
            if h["water"] == c["water"]:
                check(True, "water hash equal after mutation")
            else:
                print("  note: water hash differs after mutation (%d vs %d) - water outside the client's window is allowed to drift" % (h["water"], c["water"]))
        else:
            check(h["water"] == c["water"], "water hash equal (%d vs %d)" % (h["water"], c["water"]))
        check(h["records"] == c["records"], "records equal (%d vs %d)" % (h["records"], c["records"]))
        peak_host = max(p["players"] for p in hp_now)
        peak_client = max(p["players"] for p in ap)
        check(peak_host == 2 and peak_client == 2, "players == 2 on both while connected (host peak %d, client peak %d)" % (peak_host, peak_client))
        first = next((p for p in ap if p["lpx"] is not None), None)
        moved = first is not None and c["lpx"] is not None and abs(c["lpx"] - first["lpx"]) > BLOCK
        check(moved, "client A lp.x moved (%s -> %s)" % (first and first["lpx"], c["lpx"]))
        if mutate:
            check("items=1" in read_log(a_log) or c["items"] >= 1 or "mutate" in read_log(host_log),
                  "host ran --net-mutate")
        char_file = os.path.join(USER_DIR, "saves", "chars", CLIENT_CHAR + ".char")
        check(os.path.exists(char_file), "client A wrote its character file (%s)" % char_file)
        if a.rejoin and not mutate:
            b_log = os.path.join(OUT_DIR, "client_b.log")
            bp = run_client("client B", CLIENT_CHAR, port, max(4, a.secs // 2), [], b_log, a.secs + 90.0)
            if bp:
                b = bp[-1]
                print("   client B last: %s" % b)
                same = b["lpx"] is not None and c["lpx"] is not None and \
                    abs(b["lpx"] - c["lpx"]) <= 5 * BLOCK and abs(b["lpy"] - c["lpy"]) <= 5 * BLOCK
                check(same, "client B resumed near A's last position (%s,%s -> %s,%s)" % (c["lpx"], c["lpy"], b["lpx"], b["lpy"]))
                hb = host_probe_at(probes_in(host_log), None, 2)
                check(hb["grid"] == b["grid"] and hb["records"] == b["records"], "client B grid/records equal the host's")
            else:
                check(False, "client B printed NETPROBE lines")
    finally:
        if not wait_exit(host, host_secs + 60.0):
            check(False, "host exited by itself")
        hlog.close()
        check(script_errors(host_log) == 0, "host log has no script errors (%s)" % tag)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", type=int, default=47140)
    ap.add_argument("--seed", type=int, default=900007)
    ap.add_argument("--secs", type=int, default=8, help="client probe seconds")
    ap.add_argument("--no-rejoin", dest="rejoin", action="store_false")
    ap.add_argument("--no-mutate", dest="mutate", action="store_false")
    ap.add_argument("--no-closes", dest="closes", action="store_false")
    ap.add_argument("--keep-saves", action="store_true", help="don't delete the test world/character files first")
    a = ap.parse_args()

    os.makedirs(OUT_DIR, exist_ok=True)
    if not a.keep_saves:
        clean_saves(a.seed)
    scenario_session(a, a.port, mutate=False, closes=False)
    if a.mutate:
        scenario_session(a, a.port + 1, mutate=True, closes=False)
    if a.closes:
        scenario_session(a, a.port + 2, mutate=False, closes=True)
    print("== lan_smoke: %d failures" % len(failures))
    for f in failures:
        print("  FAIL: " + f)
    print("== lan_smoke: %s" % ("PASS" if not failures else "FAIL"))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
