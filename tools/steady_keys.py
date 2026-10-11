# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""SCR-01V: moves a screen case's keys to moments where what the port shows does not depend on where the
display's refreshes fall (HARN-06's cases, tools/screen_case.py).

KEYFEED.COM types a case's keys into the original at the same moments the port's runner gives them, but the
two machines' refresh grids can stand a fraction of a refresh apart (and DOSBox Staging 0.83's, which the
screen cases are recorded on, is not the 0.80 the port's timing is fitted to). A key read one refresh later
can meet a loop at another step: Keen 1-3's main menu reads the arrows on six refreshes of every thirteen
and draws its spinning cursor between, the title's animated tiles stop at whatever phase the clock has when
a window is drawn over them, a text window scrolls a line more or less. Placed on such an edge, a key gives
the original one picture and the port another, a difference in timing, not in content.

For each key (keys pressed together count as one), in order, the port is run with it moved by up to four
refreshes either way (the original has met the main menu's first key up to three refreshes before the port:
Keen 2) and by half a refresh. If the pictures that stay up `settled` refreshes from the key to the next are
not the same in all eleven runs, the key is moved a refresh at a time (later, then earlier, up to `--reach`
refreshes) and, failing that, held half a refresh or a refresh shorter or longer, until they are.
Screens named at a moved key's time, and the case's mask edges between it and the next key, move with it. Design the case in the port first (`screen_case.py
port`), steady its keys, then record it: a recording is the result of its keys.

    python tools/steady_keys.py <game> <case> [--write] [--reach 24] [--from SECONDS]
"""
import argparse
import json
import sys
from concurrent.futures import ThreadPoolExecutor

import common
import frames
import screen_case as sc

PERTURB = [0, -4, -3, -2, -1, -0.5, 0.5, 1, 2, 3, 4]     # refreshes the key is moved by in the trial runs
HOLDS = [0.0, -0.5, 0.5, -1.0, 1.0]           # refreshes the key's hold is changed by, tried in this order


def groups(held):
    """The keys' indexes in groups pressed together (overlapping), in order."""
    out = []
    for i, k in enumerate(held):
        if out and k[0] < max(held[j][0] + held[j][2] for j in out[-1]):
            out[-1].append(i)
        else:
            out.append([i])
    return out


def moved(held, idx, d, r=0.0):
    """The keys `idx` pressed `d` refreshes later and each held `r` refreshes longer."""
    h = [list(k) for k in held]
    for i in idx:
        h[i][0] = round(h[i][0] + d / sc.REFRESH_HZ, 4)
        h[i][2] = round(h[i][2] + r / sc.REFRESH_HZ, 4)
    return h


def steady(game, case, reach=24, start_from=0.0, say=print):
    """The case's keys and screens with every key moved to a steady moment, and whether all were found."""
    base = sc.load(game, case)
    held = [list(k) for k in base["held"]]
    screens = [list(s) for s in base["screens"]]
    ok = True

    def pictures(trial, slot, t0, t1):
        spec = dict(base, held=trial, may_exit=True)
        out = sc.work_dir(game, case, sc.checkout_tag(f"steady{slot}")) / "port"
        code, folder, _ = sc.run_port(game, case, out, say=lambda s: None, spec=spec, seconds=round(t1 + 0.6, 3))
        if folder is None:
            return None
        view = sc.View(frames.Sequence(folder), base["masks"], t1 + 0.6, "port")
        sig = []
        for e in view.entries:
            if t0 <= e.at < t1 and e.reps >= base["settled"] and (not sig or sig[-1] != e.digest):
                sig.append(e.digest)
        return sig

    with ThreadPoolExecutor(max_workers=len(PERTURB)) as pool:
        gi = 0
        while gi < len(groups(held)):
            gs = groups(held)
            idx = gs[gi]
            t = held[idx[0]][0]
            gi += 1
            if t < start_from:
                continue
            t_end = held[gs[gi][0]][0] if gi < len(gs) else base["seconds"]
            prev_up = max((held[j][0] + held[j][2] for g in gs[:gi - 1] for j in g), default=0.0)
            found = None
            for r in HOLDS:
                for move in [0] + [m for k in range(1, reach + 1) for m in (k, -k)]:
                    cand = moved(held, idx, move, r)
                    t0 = cand[idx[0]][0]
                    if t0 < prev_up + 0.1 or max(cand[i][0] + cand[i][2] for i in idx) > t_end - 0.1:
                        continue
                    sigs = list(pool.map(lambda a: pictures(moved(cand, idx, a[0]), a[1], t0 - 3 / sc.REFRESH_HZ, t_end),
                                         list(zip(PERTURB, range(len(PERTURB))))))
                    if sigs[0] is not None and all(s == sigs[0] for s in sigs[1:]):
                        found = (move, r, cand, t0)
                        break
                if found:
                    break
            name = "+".join(held[i][1] for i in idx)
            if found is None:
                say(f"  {name} at {t:.3f}: no steady moment within {reach} refreshes")
                ok = False
                continue
            move, r, cand, t0 = found
            if move or r:
                for s in screens:
                    if abs(s[0] - t) < 1e-6:
                        s[0] = round(t0, 3)
                # a mask's start or end between this key and the next belongs to this key's screen: it moves too
                for m in base["masks"]:
                    for edge in ("from", "to"):
                        if t <= m[edge] < t_end:
                            m[edge] = round(m[edge] + t0 - t, 3)
                held = cand
                say(f"  {name} at {t:.3f}: moved {move:+d} refreshes to {t0:.3f}" + (f", held {r:+.1f}" if r else ""))
            else:
                say(f"  {name} at {t:.3f}: steady")
    for k in held:
        k[0], k[2] = round(k[0], 3), round(k[2], 3)
    return held, sorted(screens), base["masks"], ok


def main():
    ap = argparse.ArgumentParser(description="SCR-01V: a screen case's keys moved off the refresh edges")
    ap.add_argument("game")
    ap.add_argument("case")
    ap.add_argument("--write", action="store_true", help="write the moved keys into the case's file")
    ap.add_argument("--reach", type=int, default=24, help="refreshes a key may move either way")
    ap.add_argument("--from", dest="start", type=float, default=0.0, help="leave the keys before this time")
    a = ap.parse_args()
    if sc.load(a.game, a.case) is None:
        print(f"COULD-NOT-RUN: no case tools/cases/{a.game}/{sc.case_name(a.case)}.json")
        return common.COULD_NOT_RUN
    held, screens, masks, ok = steady(a.game, a.case, a.reach, a.start)
    print(json.dumps(held))
    if a.write:
        path = sc.CASES / a.game / f"{sc.case_name(a.case)}.json"
        doc = json.loads(path.read_text(encoding="utf-8"))
        doc["held"], doc["screens"] = held, screens
        for m, moved_m in zip(doc.get("masks", []), masks):
            for edge in ("from", "to"):
                if edge in m:
                    m[edge] = moved_m[edge]
        path.write_text(json.dumps(doc, indent=1) + "\n", encoding="utf-8", newline="\n")
        print(f"written {path} (record it again: python tools/screen_case.py record {a.game} {sc.case_name(a.case)})")
    return common.PASS if ok else common.FAIL


if __name__ == "__main__":
    sys.exit(main())
