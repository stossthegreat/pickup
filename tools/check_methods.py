#!/usr/bin/env python3
"""
MISSING-METHOD CHECKER — the fourth cheap build this repo can run.

    lib/screens/paywall/paywall_screen.dart:125:5:
    Error: The method '_loadOfferings' isn't defined for the type
    '_PaywallScreenState'.

That one cost a full iOS archive. A scripted edit that deleted three
functions walked its start-of-block search back too far and took a
fourth with it, leaving the call site behind. check_imports, _strings
and _balance all passed: the file parses, the brackets match, nothing is
unimported. It is simply a call to something that is no longer there.

WHAT IT DOES
Per file, collects every PRIVATE method, getter and top-level function it
declares, then finds every bare `_name(` call in that same file's
code and reports any that nothing declares. Private members cannot come
from another file, so a file is the whole world for this check — no
cross-file resolution, no false positives from inheritance.

WHAT IT DELIBERATELY SKIPS
  · private CLASSES (`_Thing(...)` constructor calls) — capitalised
  · anything declared as a field holding a function
  · `super._x()` and `other._x()` — only bare self-calls are checked

    python3 tools/check_methods.py [lib]
"""
import re, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from check_imports import strip_noncode

# `Future<void> _foo(` / `void _foo(` / `String get _bar` / `_foo(` ctors
# The return type may itself contain parentheses AND braces — Dart
# records, positional and named, are all over this codebase
# (`List<({String label, int score})> _freeflowShareStats(`) — and are (`List<(String, String)> _liveLines(`,
# `Future<(Set<int>, int)> _rebuild(`). Leaving `()` out of the type
# character class made every one of those read as undeclared.
# The keyword guard stops `if (_foo(x))` being read as a declaration now
# that parentheses are allowed. And every gap is [ \t] rather than \s:
# with \s the whitespace after the return type matched across NEWLINES,
# so a match beginning in a run of blank lines swallowed the declaration
# below it and captured the one after that instead — the declaration was
# there, and the scan reported it missing.
#
# The return type is REQUIRED, not optional. Optional, it matched a bare
# call statement on its own line — `    _loadOfferings();` reads exactly
# like a declaration with the type left off — so the very deletion this
# tool was written to catch declared itself and passed. And the type
# must START with a word character: with a bare space inside its class,
# the INDENTATION qualified as a return type and `    _loadOfferings(`
# matched anyway.
DECL = re.compile(
    r'^[ \t]*(?!(?:if|for|while|switch|return|await|else|catch|assert)\b)'
    r'(?:@\w+\s+)*(?:static\s+|final\s+|const\s+|late\s+)*'
    r'(?:[\w<>][\w<>,?\[\]\.\(\)\{\} ]*[ \t]+)(?:get[ \t]+)?(_[a-z]\w*)[ \t]*(?:\(|=>|=|;)', re.M)
# a field that holds a callable, e.g. `final VoidCallback _onTap;`
FIELD = re.compile(r'^[ \t]*(?:final|late|var|const)[ \t][\w<>,?\[\]\. ]*\s(_[a-z]\w*)\s*[;=]', re.M)
CALL  = re.compile(r'(?<![.\w$])(_[a-z]\w*)\s*\(')


def check(path):
    code = strip_noncode(open(path).read())
    declared = {m.group(1) for m in DECL.finditer(code)}
    declared |= {m.group(1) for m in FIELD.finditer(code)}
    # locals and params named _foo are callable too (closures)
    declared |= set(re.findall(r'\b(?:final|var)\s+(_[a-z]\w*)\s*=', code))
    declared |= set(re.findall(r'\(\s*(?:[\w<>,?\[\]]+\s+)?(_[a-z]\w*)\s*\)', code))
    missing = []
    for m in CALL.finditer(code):
        n = m.group(1)
        if n not in declared and n not in missing:
            missing.append(n)
    return missing


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'lib')
    files = sorted(root.rglob('*.dart'))
    bad = 0
    for f in files:
        for n in check(f):
            bad += 1
            print(f'MISSING METHOD  {f}\n                calls {n}() — not declared in this file')
    print(f'--- {len(files)} files scanned, {bad} missing method(s)')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
