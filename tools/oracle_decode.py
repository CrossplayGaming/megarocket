# Copyright (C) 2026 the Megarocket contributors; adapted from the Sidescroller Recomps
# project (Copyright (C) 2026 its contributors), GPL v2 or later. See LICENSE.md.
"""Decode an oracle run's recordings into one frame sequence (see frames.py).

Usage: python tools/oracle_decode.py <run name>...
"""

import sys

import common
import frames


def decode(run_name):
    run_dir = common.config()["oracle_runs"] / run_name
    pointer = run_dir / "videos.txt"
    if not pointer.exists():
        print(f"COULD-NOT-RUN: {run_name} has no finished oracle run")
        return common.COULD_NOT_RUN
    videos = [run_dir / "capture" / name for name in pointer.read_text(encoding="ascii").split()]
    count = frames.from_videos(videos, run_dir / "frames", {"run": run_name, "videos": [v.name for v in videos]})
    seq = frames.Sequence(run_dir / "frames")
    print(f"{run_name}: {seq.raw_frames} recorded pictures, {count} distinct")
    return common.PASS if count > 0 else common.FAIL


if __name__ == "__main__":
    codes = [decode(name) for name in sys.argv[1:]]
    sys.exit(max(codes, default=common.COULD_NOT_RUN))
