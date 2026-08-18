# SFX — the ten cues

**These are generated, not sourced.** Run `python3 tools/make_sfx.py` and
all ten are synthesised deterministically from the Python standard
library — no ffmpeg, no numpy, no licence, no waiting on anyone. Editing
a cue means editing its function in that script, not opening a DAW.

The app was wired for sound for eight builds and shipped silent the whole
time: every cue below was being called by every reveal, and this folder
contained nothing but this file.

`.wav`, mono, 44.1kHz, 16-bit — WAV because there's no MP3 encoder in the
build environment and `audioplayers` handles both on iOS and Android. The
whole folder is declared in pubspec, so nothing needs adding when a cue
changes.

Keep them PEAKED not loud: the reveal fires four cues inside two seconds
and anything mastered hot turns the sequence to mush.

| file | length | what it is |
|---|---|---|
| `reel_tick.wav` | **≤ 60ms** | one face passing on the reel. Fires ~25 times in three seconds, so it must be quiet enough to disappear and sharp enough to feel. Get this one wrong and the reel is unbearable. |
| `reel_land.wav` | ≤ 400ms | the reel stopping. A physical clunk — a machine part seating — not a chime. |
| `hold.wav` | ~1.4s | under SHE'S DECIDING. The only cue allowed length: a low rising tone that resolves the instant the axes start. This is the tension. |
| `axis.wav` | ≤ 120ms | one rubric axis landing. Five in a row build the score, so identical and rhythmic beats musical. |
| `score_land.wav` | ≤ 600ms | the number arriving. The biggest sound in the app — everything else is calibrated under this. |
| `grade_slam.wav` | ≤ 500ms | the letter grade stamping, a beat after the number. Separate cue on purpose: two events, two sounds. |
| `win.wav` | ≤ 900ms | S / A / B. Earned, not a fanfare. |
| `best.wav` | ≤ 900ms | a personal best. Should be recognisably *better* than `win`. |
| `near_miss.wav` | ≤ 600ms | 0.2 off the man above him. **Must not sound like failure** — this cue's job is to make him run it back, so it wants tension and an unresolved ending, not a buzzer. |
| `lost.wav` | ≤ 900ms | a streak or a day gone. The one cue allowed to be bleak. |

## Mixing

Rough relative levels, loudest first: `score_land` → `grade_slam` /
`best` / `win` → `reel_land` → `near_miss` / `lost` → `hold` → `axis` →
`reel_tick`.

`Sfx.muted` silences all of it. Haptics stay on when it's muted — a man
in a meeting still wants to feel the score land.
