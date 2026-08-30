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

# Top-level FUNCTIONS, e.g. `GirlBrief girlForVibe(String k) =>`.
# Only matters for bare calls — `girlForVibe(...)` has no dot, so the
# `Symbol.` scan below is blind to it. That blindness let a call to an
# unimported top-level function into free_flow_screen; the analyzer
# would have caught it, but the analyzer is Codemagic, five minutes and
# one failed archive away.
FUNC_RE = re.compile(
    r'^(?!import|export|part|return|if|for|while|switch|catch)'
    r'[A-Za-z_][\w<>,?\[\] ]*?\s+([a-z]\w*)\s*\(', re.M)

DEF_RE = re.compile(
    r'^(?:abstract\s+final\s+|abstract\s+|final\s+|sealed\s+|base\s+'
    r'|interface\s+|mixin\s+)*'
    r'(?:class|enum|extension|typedef|mixin)\s+(\w+)', re.M)
TOPCONST_RE = re.compile(r'^(?:const|final)\s+[^\n=]*?\b(\w+)\s*=', re.M)


def strip_noncode(text):
    """Blank out comments and string bodies, keeping code intact.

    Regex string-stripping was not good enough. Dart strings interpolate
    (`'${Foo.bar()}'`), nest quotes inside that interpolation, come in
    raw and triple-quoted flavours, and any one of those can confuse a
    naive `'...'` pattern into reading a CLOSING quote as an opening one
    — after which it swallows real code up to the next quote in the file
    and every symbol in between goes unchecked. That is a silent false
    negative in the one tool standing between a typo and a five-minute
    failed archive (it very nearly let a missing BackendHeaders import
    through), so this walks the text properly instead.

    Interpolation contents are KEPT: `'${InstallId.cached}'` is a real
    usage and needs its import like any other.
    """
    out, stack, i, n = [], [], 0, len(text)
    while i < n:
        c = text[i]
        in_str = bool(stack) and stack[-1][0] == 'str'
        if not in_str:
            if c == '/' and i + 1 < n and text[i + 1] == '/':
                while i < n and text[i] != '\n':
                    i += 1
                continue
            if c == '/' and i + 1 < n and text[i + 1] == '*':
                i += 2
                while i + 1 < n and not (text[i] == '*' and text[i + 1] == '/'):
                    if text[i] == '\n':
                        out.append('\n')
                    i += 1
                i += 2
                continue
            if stack and stack[-1][0] == 'interp':
                if c == '{':
                    stack[-1] = ('interp', stack[-1][1] + 1)
                    out.append(c); i += 1; continue
                if c == '}':
                    d = stack[-1][1] - 1
                    if d == 0:
                        stack.pop()
                    else:
                        stack[-1] = ('interp', d)
                    out.append(' '); i += 1; continue
            if c in '\'"':
                raw = i > 0 and text[i - 1] in 'rR'
                triple = text[i:i + 3] == c * 3
                stack.append(('str', c, raw, triple))
                out.append(' ')
                i += 3 if triple else 1
                continue
            out.append(c); i += 1; continue

        _, q, raw, triple = stack[-1]
        if not raw and c == '\\':
            i += 2; continue
        if not raw and c == '$' and i + 1 < n and text[i + 1] == '{':
            stack.append(('interp', 1)); out.append(' '); i += 2; continue
        if triple and text[i:i + 3] == q * 3:
            stack.pop(); out.append(' '); i += 3; continue
        if not triple and c == q:
            stack.pop(); out.append(' '); i += 1; continue
        if c == '\n':
            out.append('\n'); i += 1
            if not triple:
                stack.pop()   # unterminated — check_strings.py reports it
            continue
        i += 1
    return ''.join(out)


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

    # Same collection for top-level functions, kept in its own map so a
    # name that is also a method somewhere can be excluded without
    # weakening the type scan.
    funcs = collections.defaultdict(set)
    for f in files:
        for m in FUNC_RE.finditer(open(f).read()):
            funcs[m.group(1)].add(f)
    ufuncs = {k: next(iter(v)) for k, v in funcs.items() if len(v) == 1}

    # RE-EXPORTS. `export 'x.dart' show foo;` makes foo visible to
    # anyone importing THIS file, so importing the re-exporter is a
    # legitimate way to reach the symbol. Without following these the
    # scan reports files that compile perfectly well — and a checker
    # that cries wolf is one nobody reads.
    reexport = collections.defaultdict(set)
    for f in files:
        for m in re.finditer(r"^export\s+'([^']+)'", open(f).read(), re.M):
            t = m.group(1)
            if t.startswith(('package:', 'dart:')):
                continue
            reexport[f].add(os.path.normpath(os.path.join(os.path.dirname(f), t)))

    seen, bad = set(), 0
    for f in files:
        src = open(f).read()
        body = re.sub(r'^import[^\n]*\n', '', src, flags=re.M)
        body = strip_noncode(body)

        imported = set()
        for m in re.finditer(r"^import\s+'([^']+)'", src, re.M):
            p = m.group(1)
            if p.startswith(('package:', 'dart:')):
                continue
            imported.add(os.path.normpath(os.path.join(os.path.dirname(f), p)))
        # …plus whatever those imports re-export, one level deep, which
        # is as far as this pattern is ever used here.
        for direct in list(imported):
            imported |= reexport.get(direct, set())

        # Bare calls to top-level functions. `(?<![.\w$])` keeps method
        # calls (`x.foo()`), named args (`foo: bar`) and declarations
        # out of it.
        for m in re.finditer(r'(?<![.\w$])([a-z]\w*)\s*\(', body):
            fn = m.group(1)
            home = ufuncs.get(fn)
            if home is None or home == f or home in imported:
                continue
            if (f, fn) in seen:
                continue
            seen.add((f, fn))
            bad += 1
            print(f'MISSING IMPORT  {f}\n'
                  f'                calls {fn}() → add {home}')

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
