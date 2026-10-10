#!/usr/bin/env python3
# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""Build the plain-language progress page from the build ledger.

Everything on it is computed from BUILD_LEDGER.md (unit statuses) except the
per-game stage mapping, the notes, what needs the user and the milestones,
which live in docs/progress.json.

Usage: python tools/progress_page.py --out <file.html>
"""
import argparse
import datetime
import html
import json
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

STATE_OF = {"verified": "done", "in progress": "partial", "ready": "ready", "blocked": "todo",
            "awaiting-user": "you", "deferred": "later"}
AREA_ORDER = ["HARN", "DATA", "SIM", "TIME", "REPLAY", "SCREENS", "MENU", "CTRL", "CHEAT", "FIX", "SHELL", "SAVE", "AUDIO", "REND", "ANDROID", "DIST", "V15"]
WORDS = {"done": "Done", "partial": "Under way", "ready": "Ready to start", "todo": "Not started",
         "you": "Needs you", "later": "Later"}


def ledger_units():
    text = (ROOT / "BUILD_LEDGER.md").read_text(encoding="utf-8")
    units = text[text.index("## Units"):text.index("## Judgment queue")]
    group = None
    out = OrderedDict()
    for line in units.splitlines():
        if line.startswith("### "):
            group = line[4:].split(" — ")[0].strip()
        elif line.startswith("| ") and not line.startswith("| ID") and not line.startswith("|---"):
            c = [x.strip() for x in line.strip().strip("|").split("|")]
            if len(c) < 6:
                continue
            raw = c[5].lower()
            state = next((v for k, v in STATE_OF.items() if raw.startswith(k)), None)
            if state is None:
                continue        # a row that was split into others
            # the ID's prefix names the area (DATA units sit under the HARN heading)
            prefix = c[0].split("-")[0]
            area = {"AND": "ANDROID", "SCR": "SCREENS"}.get(prefix, prefix)
            out[c[0]] = {"group": area if area in AREA_ORDER else group, "state": state}
    return out


def cell_state(ids, units):
    states = [units[i]["state"] for i in ids if i in units]
    if not states:
        return "todo"
    if all(s == "done" for s in states):
        return "done"
    if any(s in ("done", "partial") for s in states):
        return "partial"
    if any(s == "you" for s in states):
        return "you"
    if any(s == "ready" for s in states):
        return "ready"
    return "todo"


CSS = """
/* Layout: one column of panels; the game grid is a tile map (games down, stages across). */
:root {
  --bg: #eef0f7; --surface: #ffffff; --ink: #15173a; --muted: #585d80; --line: #d6d9ea;
  --accent: #2424b8;
  --done: #1d9a3c; --partial: #c48600; --ready: #0e8c9c; --you: #a2259e; --todo: #c9ccdc; --later: #b8bbd0;
  --on-state: #ffffff; --on-todo: #3c4063;
  --display: "VT323", "Lucida Console", "Courier New", monospace;
  --body: "IBM Plex Sans", "Segoe UI", system-ui, sans-serif;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #0a0b22; --surface: #14163b; --ink: #e9eaf8; --muted: #a0a3c8; --line: #2b2e5f; --accent: #8c8cff;
  --done: #3fcf63; --partial: #f0bd2e; --ready: #37c9d8; --you: #df5ade; --todo: #353863; --later: #2c2f57;
  --on-state: #0a0b22; --on-todo: #c4c7e6; color-scheme: dark; } }
:root[data-theme="dark"] {
  --bg: #0a0b22; --surface: #14163b; --ink: #e9eaf8; --muted: #a0a3c8; --line: #2b2e5f; --accent: #8c8cff;
  --done: #3fcf63; --partial: #f0bd2e; --ready: #37c9d8; --you: #df5ade; --todo: #353863; --later: #2c2f57;
  --on-state: #0a0b22; --on-todo: #c4c7e6; color-scheme: dark; }
* { box-sizing: border-box; }
body { background: var(--bg); color: var(--ink); font-family: var(--body); font-size: 15px; line-height: 1.5;
  padding-inline: 16px; padding-block: 28px 48px; }
.wrap { max-width: 1080px; margin: 0 auto; display: grid; gap: 22px; }
header { display: grid; gap: 14px; grid-template-columns: minmax(0, 1fr) auto; align-items: end; }
h1 { font-family: var(--display); font-weight: 400; font-size: 46px; line-height: 1; margin: 0; letter-spacing: 0.5px; color: var(--accent); }
.sub { color: var(--muted); margin: 6px 0 0; max-width: 62ch; text-wrap: pretty; }
.big { text-align: right; }
.big .num { font-family: var(--display); font-size: 64px; line-height: 0.9; font-variant-numeric: tabular-nums; }
.big .lbl { color: var(--muted); font-size: 13px; }
.overall { height: 14px; border-radius: 2px; display: flex; overflow: hidden; background: var(--todo); }
.overall span { display: block; height: 100%; }
.legend { display: flex; flex-wrap: wrap; gap: 6px 16px; font-size: 13px; color: var(--muted); }
.legend i { display: inline-block; width: 12px; height: 12px; margin-right: 6px; vertical-align: -1px; border-radius: 2px; }
section { background: var(--surface); border: 1px solid var(--line); border-radius: 6px; padding: 18px 18px 20px; min-width: 0; }
h2 { font-size: 13px; text-transform: uppercase; letter-spacing: 0.09em; color: var(--muted); margin: 0 0 12px; font-weight: 600; }
.scroll { overflow-x: auto; }
table.map { border-collapse: separate; border-spacing: 6px; width: 100%; min-width: 760px; margin: -6px; }
table.map th { font-weight: 600; font-size: 12.5px; text-align: left; color: var(--muted); padding: 0 4px 2px; vertical-align: bottom; }
table.map th.game { width: 150px; }
.gname { font-weight: 600; }
.gfull { font-size: 12px; color: var(--muted); }
td.tile { border-radius: 4px; padding: 8px 10px; vertical-align: top; height: 64px; }
td.tile .st { font-family: var(--display); font-size: 21px; line-height: 1; }
td.tile .note { font-size: 12px; line-height: 1.35; margin-top: 4px; }
.s-done { background: var(--done); color: var(--on-state); }
.s-partial { background: var(--partial); color: var(--on-state); }
.s-ready { background: var(--ready); color: var(--on-state); }
.s-you { background: var(--you); color: var(--on-state); }
.s-todo { background: var(--todo); color: var(--on-todo); }
.s-later { background: var(--later); color: var(--on-todo); }
.areas { display: grid; gap: 9px; }
.area { display: grid; grid-template-columns: 210px minmax(0, 1fr) 92px; gap: 12px; align-items: center; }
.area .name { font-size: 14px; }
.area .bar { height: 12px; display: flex; border-radius: 2px; overflow: hidden; background: var(--todo); }
.area .bar span { display: block; height: 100%; }
.area .count { font-size: 13px; color: var(--muted); text-align: right; font-variant-numeric: tabular-nums; }
.two { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 22px; }
ul.plain { list-style: none; margin: 0; padding: 0; display: grid; gap: 12px; }
.you-item { border-left: 4px solid var(--you); padding-left: 12px; }
.you-item b { display: block; }
.you-item span, .ms span { color: var(--muted); font-size: 13.5px; }
.ms { display: grid; grid-template-columns: 92px minmax(0, 1fr); gap: 10px; }
.ms time { font-family: var(--display); font-size: 19px; color: var(--accent); line-height: 1.2; font-variant-numeric: tabular-nums; }
footer { color: var(--muted); font-size: 12.5px; }
@media (max-width: 720px) {
  header { grid-template-columns: 1fr; }
  .big { text-align: left; }
  .two { grid-template-columns: 1fr; }
  .area { grid-template-columns: minmax(0, 1fr) 80px; }
  .area .bar { grid-column: 1 / -1; grid-row: 2; }
  h1 { font-size: 38px; }
}
"""


def bar(counter, total):
    parts = []
    for state in ("done", "partial", "you", "ready"):
        n = counter.get(state, 0)
        if n:
            parts.append(f'<span style="width:{100 * n / total:.2f}%;background:var(--{state})" title="{WORDS[state]}: {n}"></span>')
    return "".join(parts)


def build(out_path):
    units = ledger_units()
    prog = json.loads((ROOT / "docs/progress.json").read_text(encoding="utf-8"))
    counted = {k: v for k, v in units.items() if v["state"] != "later"}
    states = Counter(v["state"] for v in counted.values())
    total = len(counted)
    pct = round(100 * states["done"] / total)
    today = datetime.date.today().isoformat()

    head = ['<title>Megarocket Progress</title>',
            '<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
            '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;600&family=VT323&display=swap">',
            f"<style>{CSS}</style>"]

    legend = "".join(f'<span><i class="s-{s}" style="background:var(--{s})"></i>{WORDS[s]}</span>'
                     for s in ("done", "partial", "ready", "todo", "you"))

    # the game map
    rows = []
    hdr = '<tr><th class="game">Game</th>' + "".join(f"<th>{html.escape(s['label'])}</th>" for s in prog["stages"]) + "</tr>"
    for g in prog["games"]:
        cells = []
        for s in prog["stages"]:
            st = cell_state(g[s["key"]], units)
            note = g.get("notes", {}).get(s["key"], "")
            cells.append(f'<td class="tile s-{st}"><div class="st">{WORDS[st]}</div>'
                         + (f'<div class="note">{html.escape(note)}</div>' if note else "") + "</td>")
        full = f'<div class="gfull">{html.escape(g["full"])}</div>' if g["full"] else ""
        rows.append(f'<tr><th><div class="gname">{html.escape(g["name"])}</div>{full}</th>{"".join(cells)}</tr>')

    # the areas
    groups = OrderedDict((k, Counter()) for k in AREA_ORDER)
    for v in units.values():
        groups.setdefault(v["group"], Counter())[v["state"]] += 1
    groups = OrderedDict((k, c) for k, c in groups.items() if c)
    area_rows = []
    for gkey, c in groups.items():
        if gkey == "V15":
            continue
        n = sum(c.values())
        name = prog["areas"].get(gkey, gkey)
        area_rows.append(f'<div class="area"><div class="name">{html.escape(name)}</div>'
                         f'<div class="bar" role="img" aria-label="{c.get("done", 0)} of {n} done">{bar(c, n)}</div>'
                         f'<div class="count">{c.get("done", 0)} of {n} done</div></div>')

    you = "".join(f'<li class="you-item"><b>{html.escape(y["what"])}</b><span>{html.escape(y["why"])}</span></li>'
                  for y in prog["needs_you"])
    ms = "".join(f'<li class="ms"><time>{html.escape(m["date"][5:])}</time><span>{html.escape(m["text"])}</span></li>'
                 for m in prog["milestones"][:8])

    body = f"""
<div class="wrap">
  <header>
    <div>
      <h1>Megarocket 2.0</h1>
      <p class="sub">All seven Commander Keen games rebuilt as one program for Windows and Android, checked piece by piece against the originals running in DOSBox. A piece counts as done only when an automatic check proves it.</p>
    </div>
    <div class="big"><div class="num">{pct}%</div><div class="lbl">{states['done']} of {total} pieces proven</div></div>
  </header>
  <div class="overall" role="img" aria-label="{states['done']} of {total} pieces done">{bar(states, total)}</div>
  <div class="legend">{legend}</div>

  <section>
    <h2>Each game</h2>
    <div class="scroll"><table class="map">{hdr}{"".join(rows)}</table></div>
  </section>

  <section>
    <h2>Areas of work</h2>
    <div class="areas">{"".join(area_rows)}</div>
  </section>

  <div class="two">
    <section>
      <h2>Needs you</h2>
      <ul class="plain">{you}</ul>
    </section>
    <section>
      <h2>Recently finished</h2>
      <ul class="plain">{ms}</ul>
    </section>
  </div>

  <footer>Updated {today}. Counts come from the project's build ledger; "Later" items (version 1.5 goals) are left out of the totals.</footer>
</div>
"""
    Path(out_path).write_text("\n".join(head) + body, encoding="utf-8")
    return pct, states, total


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    print(build(a.out))
