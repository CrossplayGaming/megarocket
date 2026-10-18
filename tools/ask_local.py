# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""Ask the local model (the RTX 5090 behind LocalAI Studio) a question and print its answer.

For work that costs reading rather than judgment: summarising a long log, finding a pattern in big
files, a first draft. Files given with --file are put before the question, cut to fit the model's
context (the app reports it per model).

    python tools/ask_local.py "What failed and why?" --file run.log
    python tools/ask_local.py --models
    python tools/ask_local.py "..." --model ornith:35b --effort low --max-tokens 2000

The endpoint is LocalAI Studio's OpenAI-compatible pass-through, its URL in the environment variable
LOCALAI_BASE_URL or tools/config.local.json ("localai_url"); the key is the
pairing code in the user environment variable LOCALAI_PAIRING_CODE, which the user sets. It is read
at run time (from the process, else the Windows user environment) and never printed, logged or put
on a command line. One request at a time; the first after a model switch takes 5-20 s to load.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

def _base() -> str:
    """The LocalAI Studio server's /v1 URL: LOCALAI_BASE_URL, else tools/config.local.json's "localai_url" (a
    machine's own settings, never committed)."""
    if os.environ.get("LOCALAI_BASE_URL"):
        return os.environ["LOCALAI_BASE_URL"]
    try:
        with open(os.path.join(os.path.dirname(__file__), "config.local.json"), encoding="utf-8") as f:
            return str(json.load(f).get("localai_url", ""))
    except (OSError, ValueError):
        return ""


BASE = _base()
DEFAULT_MODEL = "qwen3.8:27b-mtp-q4_K_M"
KEY_VAR = "LOCALAI_PAIRING_CODE"
CHARS_PER_TOKEN = 3.5    # a cautious guess for code and logs


def key() -> str:
    k = os.environ.get(KEY_VAR, "")
    if not k and sys.platform == "win32":
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as h:
                k = str(winreg.QueryValueEx(h, KEY_VAR)[0])
        except OSError:
            k = ""
    if not k:
        sys.exit(f"ask_local: {KEY_VAR} is not set. Ask the user to set it as a user environment variable.")
    return k


def call(path: str, body: dict | None = None, timeout: float = 600.0) -> dict:
    if not BASE:
        sys.exit("ask_local: no server URL: set LOCALAI_BASE_URL or \"localai_url\" in tools/config.local.json.")
    req = urllib.request.Request(BASE + path, data=None if body is None else json.dumps(body).encode("utf-8"),
                                 headers={"Authorization": "Bearer " + key(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:500]
        sys.exit(f"ask_local: HTTP {e.code} from {path}: {detail}")
    except urllib.error.URLError as e:
        sys.exit(f"ask_local: cannot reach {BASE} ({e.reason}); is Tailscale up and the app running?")


def models() -> list:
    return call("/models", timeout=30.0).get("data", [])


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("question", nargs="?", default="")
    ap.add_argument("--file", action="append", default=[], help="a file to put before the question (repeatable)")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--effort", default="none", choices=["none", "low", "medium", "high"],
                    help="thinking: none is fastest (summaries); high for reasoning")
    ap.add_argument("--max-tokens", type=int, default=4000, help="the answer's length at most")
    ap.add_argument("--system", default="Answer concisely and precisely. Quote exact lines when they matter. "
                                        "Say so plainly when the input does not contain the answer.")
    ap.add_argument("--models", action="store_true", help="list the models and their context lengths")
    a = ap.parse_args()
    if a.models:
        for m in models():
            print(f"{m.get('id')}  context {m.get('context_length', '?')}")
        return 0
    if not a.question:
        ap.error("a question is needed")
    ctx = next((int(m.get("context_length", 0)) for m in models() if m.get("id") == a.model), 0)
    if ctx == 0:
        sys.exit(f"ask_local: no model {a.model!r} on the server (see --models)")
    room = int((ctx - a.max_tokens - 1000) * CHARS_PER_TOKEN) - len(a.question) - len(a.system)
    parts = []
    for path in a.file:
        with open(path, encoding="utf-8", errors="replace") as f:
            parts.append(f"=== {path} ===\n{f.read()}")
    text = "\n\n".join(parts)
    cut = ""
    if len(text) > room:
        # keep the start and the end (a log's setup and its failure); say what was left out
        half = max(room // 2, 0)
        cut = f"[{len(text) - 2 * half} characters cut from the middle to fit the model's context]"
        text = text[:half] + "\n\n" + cut + "\n\n" + text[len(text) - half:]
    content = (text + "\n\n=== Question ===\n" + a.question) if text else a.question
    r = call("/chat/completions", {"model": a.model, "messages": [{"role": "system", "content": a.system},
                                                                   {"role": "user", "content": content}],
                                   "reasoning_effort": a.effort, "max_tokens": a.max_tokens, "temperature": 0.2})
    msg = r.get("choices", [{}])[0].get("message", {})
    print(msg.get("content", "").strip())
    use = r.get("usage", {})
    print(f"\n[{a.model}: {use.get('prompt_tokens', '?')} in, {use.get('completion_tokens', '?')} out"
          + (f"; {cut}" if cut else "") + "]", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
