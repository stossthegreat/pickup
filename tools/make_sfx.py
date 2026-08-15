#!/usr/bin/env python3
"""
THE TEN CUES — synthesised, not sourced.

The app has been fully wired for sound since b14x and has shipped silent
the whole time: ten named cues in sfx_service.dart, a written brief in
assets/sfx/README.md, and zero audio files in git. Every reveal in the
product — the count-up, the grade slam, the reel, the verdict — was a
silent film.

Buying or commissioning ten UI cues is a week of back-and-forth. UI sound
is not music: it is short, synthetic, and entirely describable in maths,
so this generates all ten deterministically with nothing but the Python
standard library. No ffmpeg, no numpy, no licence, no waiting.

Output is 16-bit mono 44.1kHz WAV. WAV rather than MP3 because there is
no encoder in this environment and audioplayers handles both on iOS and
Android — the extension in sfx_service.dart matches.

Run:  python3 tools/make_sfx.py
"""

import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')

# Relative levels, straight off the mixing table in assets/sfx/README.md.
# The reveal fires four cues inside two seconds; anything mastered hot
# turns the sequence to mush, so these are deliberately far apart.
LEVEL = {
    'score_land': 1.00,
    'grade_slam': 0.90,
    'best':       0.90,
    'win':        0.85,
    'reel_land':  0.70,
    'near_miss':  0.60,
    'lost':       0.60,
    'hold':       0.35,
    'axis':       0.30,
    'reel_tick':  0.18,
}


# ── primitives ───────────────────────────────────────────────────────

def silence(ms):
    return [0.0] * int(SR * ms / 1000)


def env(buf, attack_ms=2, decay_ms=None, curve=2.2):
    """Percussive envelope: near-instant attack, exponential decay.

    The attack is what makes a UI cue feel like a CLICK rather than a
    note. Anything over a few milliseconds and it stops reading as an
    event and starts reading as music."""
    n = len(buf)
    a = max(1, int(SR * attack_ms / 1000))
    d = n - a if decay_ms is None else int(SR * decay_ms / 1000)
    out = []
    for i, s in enumerate(buf):
        if i < a:
            g = i / a
        else:
            t = (i - a) / max(1, d)
            g = max(0.0, 1.0 - t) ** curve
        out.append(s * g)
    return out


def tone(freq, ms, shape='sine', detune=0.0, sweep=None):
    """One voice. `sweep` is an end frequency for a glide."""
    n = int(SR * ms / 1000)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n if n else 0
        f = freq if sweep is None else freq + (sweep - freq) * t
        f *= (1.0 + detune)
        phase += 2 * math.pi * f / SR
        if shape == 'sine':
            s = math.sin(phase)
        elif shape == 'tri':
            s = 2 / math.pi * math.asin(math.sin(phase))
        elif shape == 'square':
            s = 1.0 if math.sin(phase) >= 0 else -1.0
        else:
            s = math.sin(phase)
        out.append(s)
    return out


def noise(ms, seed=1):
    """White noise. Deterministic so a rebuild is byte-identical."""
    rng = random.Random(seed)
    return [rng.uniform(-1, 1) for _ in range(int(SR * ms / 1000))]


def lowpass(buf, cutoff_hz):
    """One-pole lowpass. Turns white noise into a thud or a hiss."""
    a = math.exp(-2 * math.pi * cutoff_hz / SR)
    out, y = [], 0.0
    for s in buf:
        y = (1 - a) * s + a * y
        out.append(y)
    return out


def mix(*layers):
    n = max(len(x) for x in layers)
    out = [0.0] * n
    for lay in layers:
        for i, s in enumerate(lay):
            out[i] += s
    return out


def cat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def at(buf, offset_ms, layer):
    """Place `layer` into `buf` starting at offset (extends if needed)."""
    o = int(SR * offset_ms / 1000)
    need = o + len(layer)
    if len(buf) < need:
        buf = buf + [0.0] * (need - len(buf))
    for i, s in enumerate(layer):
        buf[o + i] += s
    return buf


def bell(freq, ms, level=1.0):
    """A struck tone: fundamental plus a quiet inharmonic partial. Two
    partials is the difference between a beep and something that sounds
    like an object was hit."""
    return [
        (a + b * 0.28) * level
        for a, b in zip(
            env(tone(freq, ms), attack_ms=3, curve=2.6),
            env(tone(freq * 2.76, ms * 0.55), attack_ms=1, curve=3.4)
            + [0.0] * (int(SR * ms / 1000) - int(SR * ms * 0.55 / 1000)),
        )
    ]


def write(name, buf):
    peak = max(abs(s) for s in buf) or 1.0
    gain = LEVEL[name] / peak
    # Soft clip rather than hard — a UI cue that crackles on a cheap
    # phone speaker is worse than one that's a hair quieter.
    frames = b''.join(
        struct.pack('<h', int(max(-1.0, min(1.0, math.tanh(s * gain * 1.1)))
                              * 32000))
        for s in buf
    )
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f'{name}.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    ms = int(len(buf) / SR * 1000)
    print(f'  {name}.wav  {ms}ms  {os.path.getsize(path) // 1024}KB')


# ── the ten ──────────────────────────────────────────────────────────

def make_reel_tick():
    """One face passing. Fires ~25 times in three seconds — the cue most
    likely to become unbearable, so it's 22ms and nearly inaudible."""
    return env(tone(2400, 22, 'tri'), attack_ms=0.4, curve=3.5)


def make_reel_land():
    """The reel stopping. A machine part seating: low body, noise
    transient on top. A chime here would make it a toy."""
    body = env(tone(120, 260, sweep=78), attack_ms=1, curve=2.4)
    click = env(lowpass(noise(60, seed=7), 3000), attack_ms=0.3, curve=4.0)
    return mix([s * 0.85 for s in body], [s * 0.5 for s in click])


def make_hold():
    """Under SHE'S DECIDING. The only cue allowed length — a low tone
    rising for a second and a half, unresolved, so the axes landing feel
    like a release rather than a start."""
    n_ms = 1400
    base = tone(96, n_ms, sweep=150)
    fifth = tone(144, n_ms, sweep=226, detune=0.002)
    buf = mix([s * 0.7 for s in base], [s * 0.35 for s in fifth])
    # Slow swell in, and a tremble that gets faster — tension you can
    # hear tightening.
    out = []
    n = len(buf)
    for i, s in enumerate(buf):
        t = i / n
        swell = min(1.0, t * 3.2)
        trem = 1.0 + 0.10 * math.sin(2 * math.pi * (3 + t * 7) * i / SR)
        out.append(s * swell * trem)
    return out


def make_axis():
    """One rubric axis landing. Five identical hits in a row, so it has
    to be rhythmic rather than melodic."""
    return env(tone(1180, 90, 'tri'), attack_ms=1, curve=3.0)


def make_score_land():
    """The number arriving. The biggest sound in the app — everything
    else is calibrated underneath this one."""
    sub = env(tone(64, 420, sweep=48), attack_ms=1, curve=1.8)
    body = env(tone(196, 300, sweep=147), attack_ms=1.5, curve=2.4)
    air = env(lowpass(noise(120, seed=11), 6000), attack_ms=0.5, curve=3.0)
    return mix(
        [s * 0.95 for s in sub],
        [s * 0.55 for s in body],
        [s * 0.30 for s in air],
    )


def make_grade_slam():
    """The letter stamping, a beat after the number. Two events, two
    sounds — a stamp is an impact, not a note."""
    thump = env(tone(88, 300, sweep=52), attack_ms=0.6, curve=2.0)
    crack = env(lowpass(noise(90, seed=23), 9000), attack_ms=0.2, curve=4.5)
    ring = env(tone(330, 220), attack_ms=2, curve=3.2)
    return mix(
        [s * 0.9 for s in thump],
        [s * 0.55 for s in crack],
        [s * 0.22 for s in ring],
    )


def make_win():
    """S / A / B. A major triad arriving in sequence — earned, not a
    fanfare. Three notes is a result; eight notes is a slot machine
    telling you you've won 2p."""
    buf = []
    for i, f in enumerate((523.25, 659.25, 783.99)):  # C5 E5 G5
        buf = at(buf, i * 105, bell(f, 520 - i * 60, level=0.8 + i * 0.1))
    return buf


def make_best():
    """A personal best. Recognisably BETTER than win: four notes, ends
    an octave up, with a shimmer on the last one. The pattern people
    learn first because it's the one they want."""
    buf = []
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.50)):
        buf = at(buf, i * 95, bell(f, 560 - i * 70, level=0.75 + i * 0.12))
    buf = at(buf, 300, [s * 0.30 for s in bell(1568.0, 420)])
    return buf


def make_near_miss():
    """0.2 off the man above him. This cue's job is to make him run it
    back, so it must NOT sound like failure — it rises and then stops on
    an unresolved interval. No landing, no buzzer."""
    a = bell(587.33, 300, level=0.9)              # D5
    b = bell(830.61, 460, level=0.85)             # G#5 — a tritone up
    buf = at(list(a), 150, b)
    return buf


def make_lost():
    """A streak or a day gone. The one cue allowed to be bleak: two
    notes falling, slow, minor. It should feel like something closing."""
    a = bell(392.00, 420, level=0.9)              # G4
    b = bell(311.13, 620, level=0.8)              # Eb4
    buf = at(list(a), 260, b)
    low = env(tone(78, 700, sweep=62), attack_ms=8, curve=1.6)
    return mix(buf, [s * 0.35 for s in low])


CUES = {
    'reel_tick': make_reel_tick,
    'reel_land': make_reel_land,
    'hold': make_hold,
    'axis': make_axis,
    'score_land': make_score_land,
    'grade_slam': make_grade_slam,
    'win': make_win,
    'best': make_best,
    'near_miss': make_near_miss,
    'lost': make_lost,
}

if __name__ == '__main__':
    print('Synthesising the ten cues →', os.path.normpath(OUT))
    for name, fn in CUES.items():
        write(name, fn())
    print('done.')
