import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// SOUND — the half of "game feel" the app was missing entirely.
///
/// A slot machine is roughly half audio. Ours had a count-up, a grade
/// slam and a spinning reel, all of them silent, which is why the whole
/// thing felt like a very good chart rather than a machine. Nothing else
/// on the polish list moves the felt quality this much per hour.
///
/// IT SHIPPED SILENT FOR EIGHT BUILDS. Every cue below was wired, every
/// reveal called them, and `git ls-files assets/sfx/` returned exactly
/// one file: the README describing the sounds nobody had made. The whole
/// app was a silent film.
///
/// The ten cues now exist and are SYNTHESISED, not sourced — see
/// tools/make_sfx.py, which generates all of them deterministically from
/// the Python standard library. UI sound is not music: it's short,
/// synthetic and entirely describable in maths, so commissioning it was
/// never the right move. Re-running that script rebuilds them
/// byte-identically, and the levels come straight off the mixing table
/// in assets/sfx/README.md.
///
/// WAV, not MP3: there's no encoder in the build environment and
/// audioplayers handles both on iOS and Android. Every play is still
/// wrapped, so a missing or corrupt file is a logged no-op rather than a
/// crash.
///
/// Two rules the mixing has to respect:
///   · Cues are SHORT. Anything over ~600ms collides with the next beat
///     of the reveal and turns a sequence into a mush.
///   · The reel tick is played dozens of times in three seconds. It has
///     to be quiet enough to disappear and sharp enough to feel.
class Sfx {
  static final _pool = AudioPlayer(playerId: 'sfx');
  static final _tickPool = AudioPlayer(playerId: 'sfx_tick');
  static bool _muted = false;

  /// Settings can silence the lot. Haptics stay — a man in a meeting
  /// still wants to feel the score land.
  static bool get muted => _muted;
  static set muted(bool v) => _muted = v;

  static Future<void> _play(AudioPlayer p, String file) async {
    if (_muted) return;
    try {
      await p.stop();
      await p.play(AssetSource('sfx/$file'), volume: 0.85);
    } catch (e) {
      // No file yet, or no audio route. Never fatal, never visible.
      if (kDebugMode) debugPrint('Sfx: $file unavailable ($e)');
    }
  }

  // ── The reel ────────────────────────────────────────────────────────
  /// One face passing. Fires ~25 times in under three seconds, so this
  /// is the cue most likely to become irritating — keep it under 60ms
  /// and well below the others in level.
  static void reelTick() => _play(_tickPool, 'reel_tick.wav');

  /// The reel stopping. A physical clunk, not a chime.
  static void reelLand() => _play(_pool, 'reel_land.wav');

  // ── The reveal ──────────────────────────────────────────────────────
  /// Under SHE'S DECIDING. The only cue allowed to be longer — a low
  /// rising tone that resolves the instant the axes start.
  static void hold() => _play(_pool, 'hold.wav');

  /// One axis landing. Five of these in a row build the score, so they
  /// want to be identical and rhythmic rather than musical.
  static void axis() => _play(_tickPool, 'axis.wav');

  /// The number arriving. The biggest sound in the app.
  static void scoreLand() => _play(_pool, 'score_land.wav');

  /// The grade stamping a beat later. Separate cue on purpose — two
  /// events, two sounds, or the moment reads as one thing.
  static void gradeSlam() => _play(_pool, 'grade_slam.wav');

  // ── Outcomes ────────────────────────────────────────────────────────
  static void win() => _play(_pool, 'win.wav');
  static void personalBest() => _play(_pool, 'best.wav');

  /// The near miss. Must NOT sound like failure — it's the cue that has
  /// to make him want to run it back, so it wants tension, not a buzzer.
  static void nearMiss() => _play(_pool, 'near_miss.wav');

  /// A streak or a day lost. The one cue in the app allowed to be bleak.
  static void lost() => _play(_pool, 'lost.wav');

  static Future<void> dispose() async {
    await _pool.dispose();
    await _tickPool.dispose();
  }
}
