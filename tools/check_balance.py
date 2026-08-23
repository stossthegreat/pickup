#!/usr/bin/env python3
"""
BRACKET-BALANCE CHECKER — the third cheap build this repo can run.

There is no Flutter SDK here, so Codemagic is the first compiler to see
anything and every syntax error costs a ~5 minute archive. check_imports
catches missing imports and check_strings catches unterminated literals;
this catches the other one that reaches the compiler as a wall of
unrelated errors hundreds of lines from the actual mistake — a brace,
paren or bracket that never closes, usually from a hand-edited or
scripted patch.

It reuses check_imports' tokenizer, so quotes, comments, raw and
triple-quoted strings and `${...}` interpolation are all understood and
brackets inside them are correctly ignored.

    python3 tools/check_balance.py [lib]     # exit 1 if anything is off
"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from check_imports import strip_noncode

PAIRS = {')': '(', ']': '[', '}': '{'}
OPEN = set(PAIRS.values())


def check(text):
    """Return (line, description) of the first imbalance, or None."""
    stack = []
    line = 1
    for ch in strip_noncode(text):
        if ch == '\n':
            line += 1
        elif ch in OPEN:
            stack.append((ch, line))
        elif ch in PAIRS:
            if not stack:
                return (line, f"stray closing '{ch}'")
            got, opened = stack.pop()
            if got != PAIRS[ch]:
                return (line,
                        f"'{ch}' closes '{got}' opened on line {opened}")
    if stack:
        got, opened = stack[-1]
        return (opened, f"'{got}' opened here is never closed")
    return None


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'lib')
    files = sorted(root.rglob('*.dart'))
    bad = 0
    for f in files:
        hit = check(f.read_text())
        if hit:
            bad += 1
            print(f'{f}:{hit[0]}: {hit[1]}')
    print(f'--- {len(files)} files scanned, {bad} unbalanced')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
