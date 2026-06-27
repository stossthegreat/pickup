import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// AI charisma coach voice player.
///
/// Plays direction clips during the 30-second test ("Look at the eyes",
/// "Hold the gaze", etc.). Each clip ID maps to an asset under
/// `assets/voice/<id>.mp3` (see assets/voice/README.txt for the full list
/// + recording spec).
///
/// Falls back gracefully when an asset is missing — silently no-ops on
/// audio playback so the test still runs end-to-end. The matching caption
/// (set by the caller) shows on screen regardless, so the user always
/// sees the direction even pre-voice-recording.
///
/// Reactive cues (eyes_back, slower, …) are rate-limited so the user
/// isn't drowning in corrections — at most one reactive cue per
/// [reactiveCooldown] window.
class VoiceCoach {
  final AudioPlayer _player = AudioPlayer();
  final Map<String, _CueState> _cueStates = {};
  final Map<String, bool> _assetExists = {};
  bool _disposed = false;
  bool _muted = false;

  // ── CHARISMA TEST CUES ─────────────────────────────────────────────────
  // Direction lines (8) — fired on phase transitions during the 30s test
  static const lookAtEyes    = 'look_at_eyes';
  static const lockHold      = 'lock_hold';
  static const smileBuild    = 'smile_build';
  static const eyesStay      = 'eyes_stay';
  static const followSlow    = 'follow_slow';
  static const nowBack       = 'now_back';
  static const dontMove      = 'dont_move';
  static const testComplete  = 'test_complete';

  // Reactive corrections (4) — fired when a signal slips mid-phase
  static const eyesBack      = 'eyes_back';
  static const slower        = 'slower';
  static const blinkLess     = 'blink_less';
  static const lockIn        = 'lock_in';

  // ── PRESENCE LESSON CUES ───────────────────────────────────────────────
  // 60-second guided choreography — fired by PresenceLessonEngine.
  // Each falls back to one of the charisma-test cues when the presence-
  // specific MP3 hasn't been recorded yet (the engine plays both — the
  // alt + the fallback — and silent assets are skipped).
  static const chinDownEyesUp = 'chin_down_eyes_up';
  static const slowClose      = 'slow_close';
  static const lookAwayReturn = 'look_away_return';
  static const halfSmile      = 'half_smile';
  static const theFlow        = 'the_flow';

  // ── VIRAL PRESENCE TEST CUES ───────────────────────────────────────────
  // 60-second post-paywall first-experience hook — PresenceTestEngine.
  // Each phase has its own brand-defining one-liner. Falls back to a
  // matching charisma-test cue if the alt isn't recorded yet.
  static const theSmolder    = 'the_smolder';
  static const theFall       = 'the_fall';        // vulnerability break
  static const theStillness  = 'the_stillness';
  static const theSlowBurn   = 'the_slow_burn';
  static const theTakeAway   = 'the_take_away';
  // Reserved for the lesson library's STICKY EYES standalone drill.
  // Not used by the current viral test engine.
  static const stickyEyes    = 'sticky_eyes';

  /// Reactive cues fire at most once every 2.5s.
  static const Duration reactiveCooldown = Duration(milliseconds: 2500);

  bool get muted => _muted;
  void setMuted(bool m) {
    _muted = m;
    if (m) {
      _player.stop();
    }
  }

  /// Play a one-shot cue. Returns immediately. If [rateLimit] is set,
  /// suppresses repeat plays inside that window.
  Future<void> play(String cueId, {Duration? rateLimit}) async {
    if (_disposed || _muted) return;

    final now = DateTime.now();
    final state = _cueStates.putIfAbsent(cueId, () => _CueState());
    if (rateLimit != null && state.lastPlayed != null) {
      if (now.difference(state.lastPlayed!) < rateLimit) return;
    }
    state.lastPlayed = now;

    final exists = await _hasAsset(cueId);
    if (!exists) return; // silent fallback — caption still shows

    try {
      await _player.stop();
      await _player.play(AssetSource('voice/$cueId.mp3'));
    } catch (e) {
      debugPrint('[voice-coach] play "$cueId" failed: $e');
    }
  }

  /// Convenience wrapper for reactive corrections — uses the standard
  /// 2.5s rate limit so the user isn't bombarded.
  Future<void> playReactive(String cueId) => play(cueId, rateLimit: reactiveCooldown);

  /// Play the first cue ID in [cueIds] whose asset actually exists.
  ///
  /// Used by the seduction lesson — each phase has a preferred
  /// seduction-specific clip plus a fallback to the charisma-test clip,
  /// so we never go silent even if the user only recorded the test set.
  Future<void> playFirstAvailable(List<String> cueIds) async {
    if (_disposed || _muted) return;
    for (final id in cueIds) {
      if (await _hasAsset(id)) {
        await play(id);
        return;
      }
    }
  }

  Future<bool> _hasAsset(String cueId) async {
    final cached = _assetExists[cueId];
    if (cached != null) return cached;
    try {
      // rootBundle.load throws if the asset isn't bundled. Cheap probe.
      await rootBundle.load('assets/voice/$cueId.mp3');
      _assetExists[cueId] = true;
      return true;
    } catch (_) {
      _assetExists[cueId] = false;
      return false;
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    try { await _player.stop(); } catch (_) {}
  }

  Future<void> dispose() async {
    _disposed = true;
    try { await _player.dispose(); } catch (_) {}
  }
}

class _CueState {
  DateTime? lastPlayed;
}
