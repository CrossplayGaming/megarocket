# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""TIME-D's fit: the costs (machine units) of the work the Dreams port does at once and the original
does not, on the key-fed level sessions (HARN-22: their keys are exact, so what is left between the
port and a recording up to the first difference of play is the time of the loads and the drawing).

For a set of costs the port runs every session (tools/dreams_case.py), and each is scored: how far it
matches (the recording's picture reached) and, at each place the original shows its work in progress
(a loading box, its bar, text being printed), how many refreshes the recording then runs behind the
port (the drift; 0 when the load took the original's time). The fit raises the pictures matched in all,
then lowers the drift, one cost at a time by factors (coordinate descent), and writes the costs to
godot/data/dreams_costs.json (tools/dreams_case.py passes them to the port; the host applies them in play).

    python tools/calibrate_dreams.py [--games kdreams kdreams193] [--workers 8] [--rounds 6]
    python tools/calibrate_dreams.py --report       # the current costs' score per session
    python tools/calibrate_dreams.py --override kdreams193 [--names ...]
                                    # one release's own costs, fitted on its sessions alone (by_game)
"""
import argparse
import concurrent.futures
import hashlib
import json
import sys
import time
from pathlib import Path

import common
import dreams_case
import frames
import timing_score

COSTS = Path(__file__).parent.parent / "godot" / "data" / "dreams_costs.json"    # (the game reads it too: the host)
WORK = Path("F:/KeenReworkWork/port_runs")
# the costs fitted and where each starts (Galaxy's TIME-G values for the shared engine's work)
# (lzhbyte: v1.93's title, LZH-packed, takes the original 0.6 s after the mode set: 28500 a byte)
# (mapbyte, mapword: CA_CacheMap's Huffman input bytes and RLEW words a plane; their start is the fit of the
# recordings' plain "Loading" box, from the warp to the level's title, on the map's sizes: 0.93 refreshes +
# 2.79e-4 a compressed byte + 2.57e-4 a word of the three planes)
START = {"grbyte": 5100, "mapbyte": 4750, "mapword": 1457, "sprchunk": 0, "sprbyte": 0, "mmmove": 0, "audiobyte": 0,
         "lzhbyte": 28500, "mapscan": 0, "mmscan": 0, "grexp": 0}
# (not fitted: "vga", a cost per access to the card's memory, drm_boot's; tried 2026-10-10 at 20-400 on all
# 32 sessions, every value matched fewer pictures (v1.93 2487 -> 976 at 20): DOSBox's drawing costs nothing)
# ("pitphase" in dreams_costs.json is no work but the machine's timer phase: drm_boot's --timer_offset, the
# units added to the first tic after the program sets the timer. Fitted 2026-10-10 on all 32 sessions in 0.5M
# steps (it decides how many tics fall between two refreshes, so TimeCount's parity and the bar's steps):
# 4.0M-5.0M matched 6574-6934 and cut every stage's error, 4.5M best; the score is rough in it (4.25M: 5565).
# Leave it out of a fit by factors: --names the costs)
FACTORS = (0.5, 0.75, 0.9, 1.1, 1.25, 1.5, 2.0)


def say(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


def load_by_game():
    """The releases' own costs where they differ from the shared ones: {game: {name: units}}."""
    if COSTS.exists():
        return json.loads(COSTS.read_text(encoding="utf-8")).get("by_game", {})
    return {}


def write_costs(costs, by_game, matched, drift):
    doc = {"costs": costs, "matched": matched, "drift": drift}
    if by_game:
        doc["by_game"] = by_game
    COSTS.write_text(json.dumps(doc, indent=1) + "\n", encoding="utf-8")


def load_costs():
    if COSTS.exists():
        # (a cost new since the file was written starts at 0, the port's time before it)
        return {**{k: 0 for k in START}, **{k: int(v) for k, v in json.loads(COSTS.read_text(encoding="utf-8"))["costs"].items()}}
    return dict(START)


def sessions(games):
    """The recorded key-fed sessions: [(game, case)]."""
    out = []
    root = Path(common.config()["oracle_runs"])
    for g in games:
        for n in range(1, 17):
            case = f"level{n:02d}"
            run = root / f"{g}_{case}_a"
            spec = dreams_case.CASES / g / f"{case}.json"
            if (run / "frames" / "frames.json").exists() and json.loads(spec.read_text(encoding="utf-8")).get("keyfeed"):
                out.append((g, case))
    return out


def costs_arg(costs):
    return ",".join(f"{k}:{v}" for k, v in sorted(costs.items()) if v)


def session_score(g, c, costs):
    """(pictures matched, of n, total |drift| at the passes, the drifts, (the drift at the stop, the stop's note))."""
    arg = costs_arg(costs)
    tag = hashlib.md5(f"{g}{c}{arg}".encode()).hexdigest()[:10]
    out = WORK / f"cald_{g}_{c}_{tag}"
    spec = json.loads((dreams_case.CASES / g / f"{c}.json").read_text(encoding="utf-8"))
    dreams_case.run_feed(g, spec["held"], out, spec["seconds"] + 12, extra=(f"--costs={arg}",) if arg else (), case=c)
    oracle = Path(common.config()["oracle_runs"]) / f"{g}_{c}_a"
    try:
        port = timing_score.pictures(frames.Sequence(out / g), False)
        orc = timing_score.pictures(frames.Sequence(oracle / "frames"), True)
    except FileNotFoundError:
        return 0, 1, 0, [], (0, "no run")
    port, orc = dreams_case.align(port, orc)
    if not port:
        return 0, len(orc) - 1, 0, [], (0, "the recording's first pictures are not in the port's run")
    j, note, n, _err, skips, k = dreams_case.level_score(port, orc)
    drifts = []
    for jj, a, b, kk in skips:
        drifts.append(sum(r for _, r in orc[:jj + b]) - sum(r for _, r in port[:kk + a]))
    # how far the recording runs behind the port where they part (refreshes): the time of the loads before
    stop = sum(r for _, r in orc[:j]) - sum(r for _, r in port[:k])
    return j, n, sum(abs(x) for x in drifts), drifts, (stop, note.split(" (")[0])


def evaluate(pool, runs, costs, by_game=None):
    by_game = by_game or {}
    futs = {pool.submit(session_score, g, c, {**costs, **by_game.get(g, {})}): (g, c) for g, c in runs}
    res = {futs[f]: f.result() for f in futs}
    matched = sum(r[0] for r in res.values())
    drift = sum(r[2] for r in res.values())
    return (matched, -drift), res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--games", nargs="*", default=["kdreams", "kdreams193"])
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--rounds", type=int, default=6)
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--names", nargs="*", help="fit only these costs (default: all)")
    ap.add_argument("--override", default="", help="fit this release's own costs on its sessions alone")
    a = ap.parse_args()
    if a.override:
        a.games = [a.override]
    runs = sessions(a.games)
    if not runs:
        print("COULD-NOT-RUN: no key-fed recordings")
        return 2
    pool = concurrent.futures.ThreadPoolExecutor(a.workers)
    shared = load_costs()
    by_game = load_by_game()
    if a.override:
        # the release's costs: the shared ones with its own over them; only the differences are kept
        costs = {**shared, **by_game.get(a.override, {})}
        best, res = evaluate(pool, runs, costs)
    else:
        costs = shared
        best, res = evaluate(pool, runs, costs, by_game)
    say(f"{len(runs)} sessions; costs {costs}: {best[0]} pictures matched, drift {-best[1]}")
    if a.report:
        for (g, c), (j, n, d, drifts, (stop, note)) in sorted(res.items()):
            # (the sessions share their start, a new game and the warp: its drifts are the same in each)
            print(f"  {g} {c}: {j} of {n}; at the stop the recording {stop:+d} refreshes on ({note}); "
                  f"last drifts {drifts[-6:]}")
        return 0
    for rnd in range(a.rounds):
        moved = False
        for name in (a.names or list(costs)):
            base = costs[name]
            trials = [int(base * f) for f in FACTORS] if base else [1000, 3000, 10000, 30000, 100000]
            trials = [t for t in dict.fromkeys(trials) if t != base]
            scored = []
            for t in trials:
                trial = dict(costs, **{name: t})
                scored.append((evaluate(pool, runs, trial, None if a.override else by_game)[0], t))
            top = max(scored)
            if top[0] > best:
                best, costs[name] = top[0], top[1]
                moved = True
                say(f"round {rnd + 1}: {name} {base} -> {top[1]}: {best[0]} pictures matched, drift {-best[1]}")
                _save(a, costs, shared, by_game, best)
        if not moved:
            break
    say(f"costs {costs}: {best[0]} pictures matched, drift {-best[1]}")
    _save(a, costs, shared, by_game, best)
    return 0


def _save(a, costs, shared, by_game, best):
    """The fit so far: the shared costs, or (--override) the release's differences from them. The totals
    kept are the shared fit's (an override's score is its release's alone: --report gives the whole)."""
    if a.override:
        by_game = dict(by_game)
        by_game[a.override] = {k: v for k, v in costs.items() if v != shared.get(k)}
        doc = json.loads(COSTS.read_text(encoding="utf-8")) if COSTS.exists() else {}
        write_costs(shared, by_game, doc.get("matched", 0), doc.get("drift", 0))
    else:
        write_costs(costs, by_game, best[0], -best[1])


if __name__ == "__main__":
    sys.exit(main())
