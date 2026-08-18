#!/usr/bin/env python3
"""
MISSING-IMPORT CHECKER — the cheapest build this repo can run.

There is no Flutter SDK in the authoring environment, so `flutter analyze`
never runs before a push and Codemagic is the first compiler that sees
anything. The most expensive failure mode in that setup is also the
dumbest: a symbol used without its import. It costs a full ~5 minute iOS
archive to discover, and it is trivially detectable with a text scan.

    lib/screens/academy/battles_screen.dart:195
    Error: The getter 'AuthService' isn't defined ...

WHAT IT DOES
Collects every type declared at column 0 across lib/ (class, enum, mixin,
extension, typedef, and top-level consts), then for every `Symbol.` usage
checks the file that uses it actually imports the file that defines it.

WHY IT ONLY CONSIDERS SYMBOLS DEFINED EXACTLY ONCE
A name found in two files is almost always this script mis-parsing an SDK
type (DateTime, Positioned, Timer). Ignoring those keeps the output at
zero false positives, which is the only way a checker like this survives
— one noisy run and nobody looks at it again. It trades a little recall
for total trust in what it does report.

    python3 tools/check_imports.py     # exit 1 if anything is missing
"""
import re, os, sys, glob, collections

DEF_RE = re.compile(
    r'^(?:abstract\s+final\s+|abstract\s+|final\s+|sealed\s+|base\s+'
    r'|interface\s+|mixin\s+)*'
    r'(?:class|enum|extension|typedef|mixin)\s+(\w+)', re.M)
TOPCONST_RE = re.compile(r'^(?:const|final)\s+[^\n=]*?\b(\w+)\s*=', re.M)


def main() -> int:
    files = glob.glob('lib/**/*.dart', recursive=True)
    if not files:
        print('no dart files under lib/ — run from the repo root')
        return 1

    defs = collections.defaultdict(set)
    for f in files:
        src = open(f).read()
        for m in DEF_RE.finditer(src):
            defs[m.group(1)].add(f)
        for m in TOPCONST_RE.finditer(src):
            defs[m.group(1)].add(f)
    uniq = {k: next(iter(v)) for k, v in defs.items() if len(v) == 1}

    seen, bad = set(), 0
    for f in files:
        src = open(f).read()
        body = re.sub(r'^import[^\n]*\n', '', src, flags=re.M)
        body = re.sub(r'//[^\n]*', '', body)
        body = re.sub(r"'(?:\\.|[^'\\])*'", "''", body)
        body = re.sub(r'"(?:\\.|[^"\\])*"', '""', body)

        imported = set()
        for m in re.finditer(r"^import\s+'([^']+)'", src, re.M):
            p = m.group(1)
            if p.startswith(('package:', 'dart:')):
                continue
            imported.add(os.path.normpath(os.path.join(os.path.dirname(f), p)))

        for m in re.finditer(r'\b([A-Z]\w+)\s*\.', body):
            sym = m.group(1)
            home = uniq.get(sym)
            if home is None or home == f or home in imported:
                continue
            if (f, sym) in seen:
                continue
            seen.add((f, sym))
            bad += 1
            print(f'MISSING IMPORT  {f}\n'
                  f'                uses {sym} → add {home}')

    print(f'--- {len(files)} files scanned, {bad} missing import(s)')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
