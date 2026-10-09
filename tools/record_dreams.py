# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""Records the original's side of REPLAY-D in one batch: every level session of Keen Dreams v1.00 and
v1.93 (tools/cases/kdreams*/levelNN.json: a new game, the debug warp F10+W to the level, the same play),
each run once as <game>_<case>_a and decoded. A run already recorded and decoded is skipped, so the batch
can be stopped and started again. One line per run goes to F:/KeenReworkWork/port_runs/record_dreams.log.

    python tools/record_dreams.py [kdreams kdreams193]
"""
import subprocess
import sys
import time
from pathlib import Path

import common

LOG = Path("F:/KeenReworkWork/port_runs/record_dreams.log")


def say(line):
    print(line, flush=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(time.strftime("%H:%M:%S ") + line + "\n")


def main():
    games = sys.argv[1:] or ["kdreams", "kdreams193"]
    runs = []
    for g in games:
        runs += [(g, f"level{n:02d}") for n in range(1, 17)]
    root = Path(common.config()["oracle_runs"])
    tools = Path(__file__).parent
    for game, case in runs:
        name = f"{game}_{case}_a"
        if (root / name / "frames" / "frames.json").exists():
            say(f"{name}: already recorded")
            continue
        p = subprocess.run([sys.executable, str(tools / "oracle_run.py"), game, case, "--as", name],
                           capture_output=True, text=True, encoding="utf-8", errors="replace")
        last = (p.stdout.strip().splitlines() or ["(no output)"])[-1]
        if p.returncode != 0:
            say(f"{name}: RUN FAILED ({last})")
            continue
        d = subprocess.run([sys.executable, str(tools / "oracle_decode.py"), name], capture_output=True, text=True,
                           encoding="utf-8", errors="replace")
        say(f"{name}: {last} | {(d.stdout.strip().splitlines() or ['no decode output'])[-1]}")
    say("batch done")


if __name__ == "__main__":
    main()
