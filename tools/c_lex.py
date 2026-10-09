# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
"""C source helpers for the generators: comments removed in one pass from the left, strings and
character literals kept. (A `//*` starts a line comment, not a block: a two-pass stripper that
removes `/* */` first takes id_us.c's `//*se = '\\0';` for the start of a block and swallows the
190 lines after it.)"""
import re

_LEXEME = re.compile(r'"(?:\\.|[^"\\\n])*"|' + r"'(?:\\.|[^'\\\n])*'|" + r"//[^\n]*|/\*.*?\*/", re.S)


def strip_comments(text):
    def keep(m):
        s = m.group(0)
        if s.startswith("//"):
            return ""
        if s.startswith("/*"):
            return "\n" * s.count("\n")
        return s
    return _LEXEME.sub(keep, text)
