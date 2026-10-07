#!/usr/bin/env python3
# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""How far a port run matches an oracle recording picture for picture AND
refresh for refresh.

tools/compare_frames.py judges a port by the order of its pictures alone (the
pass/fail rule, by design blind to timing). Fitting the port's processor-time
costs and key moments needs the timing signal that rule throws away: the
number of refreshes each picture stayed on screen. This scorer walks both
sequences together and reports the first picture where either the picture or
its duration differs. The recording's first and last pictures are partial and
are never counted.

Usage:
  python tools/timing_score.py <port run folder> <oracle run folder> [--tolerance 0] [--show N]
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import frames


def pictures(seq, first_partial):
    """(digest, refreshes) per distinct picture, consecutive repeats merged."""
    out = []
    for i in range(len(seq)):
        d, r = seq.digest(i), seq.repeats(i)
        if out and out[-1][0] == d:
            out[-1] = (d, out[-1][1] + r)
        else:
            out.append((d, r))
    if first_partial and out:
        out = out[1:]
    return out


def score(port_dir, oracle_dir, tolerance=0):
    port = pictures(frames.Sequence(Path(port_dir)), False)
    orc = pictures(frames.Sequence(Path(oracle_dir) / "frames"), True)
    # the port's run starts at power-on; the recording a little later: drop the
    # port's pictures before the recording's first complete one
    start = next((i for i, (d, _) in enumerate(port) if d == orc[0][0]), None)
    if start is None:
        return 0, "the recording's first picture is not in the port's run", port, orc, 0
    port = port[start:]
    n = min(len(port), len(orc) - 1)       # the recording's last picture is partial
    for k in range(n):
        if port[k][0] != orc[k][0]:
            return k, f"picture {k} differs", port, orc, start
        if abs(port[k][1] - orc[k][1]) > tolerance:
            return k, f"picture {k} lasts {port[k][1]} refreshes in the port, {orc[k][1]} in the recording", port, orc, start
    return n, f"all {n} pictures and their durations match", port, orc, start


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("port")
    ap.add_argument("oracle")
    ap.add_argument("--tolerance", type=int, default=0)
    ap.add_argument("--show", type=int, default=6, help="pictures to list around the first difference")
    args = ap.parse_args()
    k, note, port, orc, start = score(args.port, args.oracle, args.tolerance)
    print(f"timing score {k}: {note}")
    lo, hi = max(k - args.show, 0), k + args.show
    tp = sum(r for _, r in port[:lo])
    to = sum(r for _, r in orc[:lo])
    for i in range(lo, hi):
        p = port[i] if i < len(port) else None
        o = orc[i] if i < len(orc) else None
        mark = " " if p and o and p == o else "*"
        print(f"{mark} {i:4d}  port {p[0][:6] if p else '------'} x{p[1] if p else 0:<3d} @{tp/70.086:8.3f}   "
              f"oracle {o[0][:6] if o else '------'} x{o[1] if o else 0:<3d} @{to/70.086:8.3f}")
        tp += p[1] if p else 0
        to += o[1] if o else 0


if __name__ == "__main__":
    main()
