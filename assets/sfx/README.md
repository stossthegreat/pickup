# SFX — the ten files

The app is wired for sound and ships silent. Drop these in and they play;
until then every cue is a logged no-op, exactly like the character
portraits falling back to a glyph. No pubspec change is needed — the
whole folder is declared.

`.mp3`, mono, 44.1kHz. Keep them PEAKED not loud: the reveal fires four
cues inside two seconds and anything mastered hot turns the sequence to
mush.

| file | length | what it is |
|---|---|---|
| `reel_tick.mp3` | **≤ 60ms** | one face passing on the reel. Fires ~25 times in three seconds, so it must be quiet enough to disappear and sharp enough to feel. Get this one wrong and the reel is unbearable. |
| `reel_land.mp3` | ≤ 400ms | the reel stopping. A physical clunk — a machine part seating — not a chime. |
| `hold.mp3` | ~1.4s | under SHE'S DECIDING. The only cue allowed length: a low rising tone that resolves the instant the axes start. This is the tension. |
| `axis.mp3` | ≤ 120ms | one rubric axis landing. Five in a row build the score, so identical and rhythmic beats musical. |
| `score_land.mp3` | ≤ 600ms | the number arriving. The biggest sound in the app — everything else is calibrated under this. |
| `grade_slam.mp3` | ≤ 500ms | the letter grade stamping, a beat after the number. Separate cue on purpose: two events, two sounds. |
| `win.mp3` | ≤ 900ms | S / A / B. Earned, not a fanfare. |
| `best.mp3` | ≤ 900ms | a personal best. Should be recognisably *better* than `win`. |
| `near_miss.mp3` | ≤ 600ms | 0.2 off the man above him. **Must not sound like failure** — this cue's job is to make him run it back, so it wants tension and an unresolved ending, not a buzzer. |
| `lost.mp3` | ≤ 900ms | a streak or a day gone. The one cue allowed to be bleak. |

## Mixing

Rough relative levels, loudest first: `score_land` → `grade_slam` /
`best` / `win` → `reel_land` → `near_miss` / `lost` → `hold` → `axis` →
`reel_tick`.

`Sfx.muted` silences all of it. Haptics stay on when it's muted — a man
in a meeting still wants to feel the score land.
