#!/usr/bin/env python3
"""Catch unterminated Dart string literals.

WHY THIS EXISTS. Two iOS archives have now died on the same mistake:
writing Dart through a Python heredoc, where a `\n` meant for the Dart
source is eaten by Python first and becomes a REAL newline inside a
single-quoted string. Dart forbids that, so nothing complains until the
compiler runs — twelve minutes into a Codemagic build, past pod install.

The brace/paren balance check this repo already runs cannot see it: a
broken quote usually leaves brackets balanced. This walks the source
character by character instead, tracking whether it is in code, a
comment, or a string, and flags any single/double-quoted string still
open at end of line.

IT UNDERSTANDS INTERPOLATION, which the first version did not. Dart lets
you nest strings inside `${...}` — `'${m['k'] ?? 'x'}'` is legal and
common in this codebase — so the scanner keeps a stack: a string can
contain code, that code can contain more strings, and only a quote at
the right depth actually closes anything. Triple-quoted and raw strings
are handled too, since both legally span lines.
"""
import sys, pathlib

def scan(text):
    bad = []
    stack = []          # entries: ('str', quote, raw, triple) | ('interp', depth)
    i, line, n = 0, 1, len(text)
    while i < n:
        c = text[i]
        in_str = stack and stack[-1][0] == 'str'

        if not in_str:
            # comments only exist in code context
            if c == '/' and i + 1 < n and text[i+1] == '/':
                while i < n and text[i] != '\n': i += 1
                continue
            if c == '/' and i + 1 < n and text[i+1] == '*':
                i += 2
                while i + 1 < n and not (text[i] == '*' and text[i+1] == '/'):
                    if text[i] == '\n': line += 1
                    i += 1
                i += 2; continue
            if c == '\n': line += 1; i += 1; continue
            # interpolation brace bookkeeping
            if stack and stack[-1][0] == 'interp':
                if c == '{':
                    stack[-1] = ('interp', stack[-1][1] + 1); i += 1; continue
                if c == '}':
                    d = stack[-1][1] - 1
                    if d == 0: stack.pop()
                    else: stack[-1] = ('interp', d)
                    i += 1; continue
            if c in '\'"':
                raw = i > 0 and text[i-1] in 'rR'
                triple = text[i:i+3] == c*3
                stack.append(('str', c, raw, triple))
                i += 3 if triple else 1
                continue
            i += 1; continue

        # ── inside a string ──────────────────────────────────────────
        _, q, raw, triple = stack[-1]
        if not raw and c == '\\':
            i += 2; continue
        if not raw and c == '$' and i + 1 < n and text[i+1] == '{':
            stack.append(('interp', 1)); i += 2; continue
        if triple and text[i:i+3] == q*3:
            stack.pop(); i += 3; continue
        if not triple and c == q:
            stack.pop(); i += 1; continue
        if c == '\n':
            line += 1; i += 1
            if not triple:
                bad.append(line - 1)
                stack.pop()          # resync so one break isn't reported twice
            continue
        i += 1
    return bad

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'lib')
files = sorted(root.rglob('*.dart'))
total = 0
for f in files:
    for ln in scan(f.read_text()):
        print(f'{f}:{ln}: unterminated string literal')
        total += 1
print(f'--- {len(files)} files scanned, {total} unterminated string(s)')
sys.exit(1 if total else 0)
