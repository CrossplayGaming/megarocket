# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""Let the local model (tools/ask_local.py's endpoint) work a task on its own, in its own git worktree.

    python tools/local_agent.py <task.md> [--model qwen3.8:27b-mtp-q4_K_M] [--steps 400]

The task file says what to do and what "done" means. The work happens in a worktree beside the task
file (<task folder>/wt, on branch local/<task name>), set up as an agent's worktree is (the config,
the native library copied, the import run), so the main checkout is never touched. The model has
tools to look, edit, run the project's own commands (an allowlist), keep a journal and finish.

The model's context is small, so the journal is its memory: it writes what is done and what is next
after every milestone. When the conversation nears the context, or after --fresh-every steps, it
starts again from the task, the journal and the last result (a compaction). Everything is logged to
<task folder>/log.txt, and the final report goes to <task folder>/REPORT.md. Run it again to resume:
the journal and the worktree carry over.
"""
import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import ask_local    # noqa: E402

MAIN = Path(__file__).resolve().parent.parent
ALLOWED = ("python tools/build_native.py", "python tools/gdtest.py", "python tools/regress.py",
           "python tools/check_headers.py", "git diff", "git status", "git log", "git add", "git commit",
           "godot ")
GODOT = MAIN / "godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe"
OUT_CAP = 6000

TOOLS = [
    {"name": "list_dir", "description": "List a folder of the worktree.", "params": {"path": "folder, relative to the worktree"}},
    {"name": "read_file", "description": "Read lines of a file (at most 250 at once; line numbers shown).",
     "params": {"path": "file", "start": "first line (1-based)", "end": "last line"}},
    {"name": "grep", "description": "Search files for a regular expression; returns path:line: text (at most 80).",
     "params": {"pattern": "regex", "path": "file or folder"}},
    {"name": "replace_in_file", "description": "Replace one exact, unique piece of text in a file. Keep the file's indentation (tabs in .gd).",
     "params": {"path": "file", "old": "exact text now in the file", "new": "replacement"}},
    {"name": "write_file", "description": "Create a file, or replace a small file whole.", "params": {"path": "file", "content": "the whole text"}},
    {"name": "run", "description": "Run one of the project's commands in the worktree (allowed: " + ", ".join(ALLOWED) +
     "). 'godot <args>' runs the project's Godot. Output is cut to its last 6000 characters.",
     "params": {"command": "the command line"}},
    {"name": "journal", "description": "Add to your journal (your memory across restarts): what is done, what you learned, what is next.",
     "params": {"note": "text"}},
    {"name": "finish", "description": "Stop: the task is done, or you are stuck. The report says what was done, every check run with its result, and what is open.",
     "params": {"report": "the final report"}},
]


def tool_specs():
    return [{"type": "function", "function": {"name": t["name"], "description": t["description"], "parameters": {
        "type": "object", "properties": {k: {"type": "string", "description": v} for k, v in t["params"].items()},
        "required": list(t["params"])}}} for t in TOOLS]


class Agent:
    def __init__(self, task: Path, model: str):
        self.task = task
        self.dir = task.parent
        self.name = re.sub(r"[^a-z0-9]+", "-", task.stem.lower()).strip("-")
        self.wt = self.dir / "wt"
        self.journal_path = self.dir / "JOURNAL.md"
        self.log_path = self.dir / "log.txt"
        self.model = model
        self.done = False

    def log(self, text: str) -> None:
        with open(self.log_path, "a", encoding="utf-8") as f:
            f.write(f"[{time.strftime('%H:%M:%S')}] {text}\n")

    def setup(self) -> None:
        if self.wt.exists():
            return
        subprocess.run(["git", "worktree", "add", "-b", "local/" + self.name, str(self.wt), "HEAD"], cwd=MAIN, check=True)
        cfg = {"game_data": str(MAIN / "game_data").replace("\\", "/"), "godot": str(GODOT).replace("\\", "/")}
        (self.wt / "tools/config.local.json").write_text(json.dumps(cfg), encoding="utf-8")
        (self.wt / "godot/bin").mkdir(exist_ok=True)
        (self.wt / "godot/bin/d2opl.windows.x86_64.dll").write_bytes((MAIN / "godot/bin/d2opl.windows.x86_64.dll").read_bytes())
        subprocess.run([str(GODOT), "--headless", "--path", str(self.wt / "godot"), "--import"], capture_output=True, timeout=900)
        self.log("worktree ready: " + str(self.wt))

    def path(self, p: str) -> Path:
        q = (self.wt / p).resolve()
        if self.wt.resolve() not in q.parents and q != self.wt.resolve():
            raise ValueError("outside the worktree: " + p)
        return q

    def tool(self, name: str, a: dict) -> str:
        if name == "list_dir":
            q = self.path(a.get("path", "."))
            return "\n".join(sorted((x.name + ("/" if x.is_dir() else "")) for x in q.iterdir()))[:OUT_CAP]
        if name == "read_file":
            lines = self.path(a["path"]).read_text(encoding="utf-8", errors="replace").splitlines()
            s = max(int(a.get("start") or 1), 1)
            e = min(int(a.get("end") or s + 249), s + 249, len(lines))
            return f"({len(lines)} lines)\n" + "\n".join(f"{i}: {lines[i - 1]}" for i in range(s, e + 1))
        if name == "grep":
            q = self.path(a.get("path", "."))
            files = [q] if q.is_file() else [f for f in q.rglob("*") if f.is_file() and f.suffix in (".gd", ".c", ".h", ".py", ".md", ".cfg", ".gdextension")]
            rx = re.compile(a["pattern"])
            out = []
            for f in files:
                for i, line in enumerate(f.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                    if rx.search(line):
                        out.append(f"{f.relative_to(self.wt)}:{i}: {line.strip()[:200]}")
                        if len(out) >= 80:
                            return "\n".join(out) + "\n(more cut)"
            return "\n".join(out) or "no match"
        if name == "replace_in_file":
            q = self.path(a["path"])
            raw = q.read_bytes().decode("utf-8")
            crlf = "\r\n" in raw
            text = raw.replace("\r\n", "\n")
            old = a["old"].replace("\r\n", "\n")
            n = text.count(old)
            if n != 1:
                return f"not replaced: the old text is found {n} times (it must be exactly once; read the file again)"
            text = text.replace(old, a["new"].replace("\r\n", "\n"))
            q.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))
            return "replaced"
        if name == "write_file":
            q = self.path(a["path"])
            q.parent.mkdir(parents=True, exist_ok=True)
            q.write_bytes(a["content"].replace("\r\n", "\n").encode("utf-8"))
            return f"written ({len(a['content'])} characters)"
        if name == "run":
            cmd = a["command"].strip()
            if not cmd.startswith(ALLOWED):
                return "not allowed; allowed commands start with: " + ", ".join(ALLOWED)
            limit = 1800
            if cmd.startswith("godot "):
                cmd = f'"{GODOT}" ' + cmd[6:]
                limit = 300    # a script that errors never quits: tests go through tools/gdtest.py (its own watchdog)
            try:
                r = subprocess.run(cmd, shell=True, cwd=self.wt, capture_output=True, text=True, encoding="utf-8",
                                   errors="replace", timeout=limit)
                out = (r.stdout + r.stderr)
                return f"exit {r.returncode}\n" + out[-OUT_CAP:]
            except subprocess.TimeoutExpired:
                return f"timed out after {limit} s (a Godot script that hits an error never quits: run tests with python tools/gdtest.py <test> --timeout 300)"
        if name == "journal":
            with open(self.journal_path, "a", encoding="utf-8") as f:
                f.write(f"\n## {time.strftime('%Y-%m-%d %H:%M')}\n{a['note']}\n")
            return "noted"
        if name == "finish":
            (self.dir / "REPORT.md").write_text(a["report"], encoding="utf-8")
            self.done = True
            return "finished"
        return "no such tool"

    def opening(self, last: str) -> list:
        journal = self.journal_path.read_text(encoding="utf-8") if self.journal_path.exists() else "(empty: you are starting)"
        system = ("You are a careful programmer working alone on one task in a git worktree of a Godot 4 project. "
                  "Use the tools; one step at a time; read before you edit; run the checks the task names. Your context "
                  "is small and is cleared from time to time: after every milestone, and before any long command, write "
                  "to your journal what is done and what is next, so you can continue after a restart. Never guess an "
                  "API: look it up in the files the task names. When the task is done or you are stuck, call finish.")
        user = (f"# The task\n\n{self.task.read_text(encoding='utf-8')}\n\n# Your journal so far\n\n{journal}\n\n"
                + (f"# The last result before the restart\n\n{last[-3000:]}\n\n" if last else "")
                + "Continue from the journal.")
        return [{"role": "system", "content": system}, {"role": "user", "content": user}]

    def run(self, steps: int, fresh_every: int) -> None:
        self.setup()
        ctx = next((int(m.get("context_length", 0)) for m in ask_local.models() if m.get("id") == self.model), 32768)
        msgs = self.opening("")
        since = 0
        last = ""
        for step in range(steps):
            if since >= fresh_every or sum(len(json.dumps(m)) for m in msgs) / 3.2 > ctx * 0.6:
                self.log("compaction: starting again from the task and the journal")
                msgs = self.opening(last)
                since = 0
            r = ask_local.call("/chat/completions", {"model": self.model, "messages": msgs, "tools": tool_specs(),
                                                      "reasoning_effort": "medium", "max_tokens": 6000, "temperature": 0.2},
                               timeout=900.0)
            msg = r.get("choices", [{}])[0].get("message", {})
            calls = msg.get("tool_calls") or []
            msgs.append({"role": "assistant", "content": msg.get("content") or "", "tool_calls": calls} if calls
                        else {"role": "assistant", "content": msg.get("content") or ""})
            if msg.get("content"):
                self.log("model: " + msg["content"][:1500])
            if not calls:
                msgs.append({"role": "user", "content": "Use a tool (journal, then the next step), or call finish."})
                continue
            for c in calls:
                fn = c.get("function", {})
                args = {}
                try:
                    args = json.loads(fn.get("arguments") or "{}")
                    result = self.tool(fn.get("name", ""), args)
                except Exception as e:    # a bad call is the model's to fix
                    result = f"error: {e}"
                self.log(f"step {step} {fn.get('name')} {json.dumps(args)[:300]}\n  -> {result[:800]}")
                last = f"{fn.get('name')}: {result}"
                msgs.append({"role": "tool", "tool_call_id": c.get("id", ""), "content": result})
            since += 1
            if self.done:
                self.log("finished")
                return
        self.log("step limit reached")
        (self.dir / "REPORT.md").write_text("Step limit reached before finish; see JOURNAL.md and log.txt.", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("task")
    ap.add_argument("--model", default=ask_local.DEFAULT_MODEL)
    ap.add_argument("--steps", type=int, default=400)
    ap.add_argument("--fresh-every", type=int, default=40)
    a = ap.parse_args()
    Agent(Path(a.task).resolve(), a.model).run(a.steps, a.fresh_every)
    return 0


if __name__ == "__main__":
    sys.exit(main())
