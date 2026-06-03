import 'package:audioplayers/audioplayers.dart';

/// Shared iOS / Android audio-session configuration.
///
/// The "Recording too short — 28-byte file" bug across Arena, Presence
/// and Council was a classic iOS audio-session handoff failure:
///
///   1. audioplayers plays Lucien's narration → AVAudioSession lands
///      in playback or playback-ish state, owned by audioplayers.
///   2. User taps mic → record_darwin calls
///      AVAudioSession.setCategory(.playAndRecord). On iOS this
///      SHOULD switch the session, but in practice if audioplayers
///      is still "holding" the session, the switch silently fails
///      and the recorder writes ~28 bytes of m4a container header
///      with zero audio samples behind it.
///
/// Fix is a two-step handshake (see [prepareForRecording]):
///   - Stop the audioplayers instance the screen is using, wait for
///     iOS to release.
///   - Re-assert playAndRecord on the global audioplayers context so
///     when record_darwin sets it again the session actually moves.
///
/// Call [configureForPlayAndRecord] at the top of every screen that
/// does both play and record. Call [prepareForRecording] in the same
/// async sequence as [recorder.start()], passing the screen's local
/// AudioPlayer so we can stop it cleanly first.
abstract final class AudioSession {
  static bool _configured = false;

  /// One-time setup at the top of the screen.
  static Future<void> configureForPlayAndRecord() async {
    if (_configured) return;
    try {
      await AudioPlayer.global.setAudioContext(_playAndRecordContext());
      _configured = true;
    } catch (_) {
      // Will retry next time.
    }
  }

  /// Force the next [configureForPlayAndRecord] call to actually run
  /// setAudioContext again instead of short-circuiting on the cached
  /// flag. Use when tearing down a screen that owns the mic / speaker
  /// so the next screen\'s configure re-asserts the session context.
  /// Solves the AVAudioSessionError (OSStatus 561017449) we saw when
  /// navigating NEXT LESSON from THE LOCK to THE DROP — the previous
  /// recorder hadn\'t released the session, the new screen short-
  /// circuited configure, and record_darwin\'s startStream blew up.
  static void invalidate() {
    _configured = false;
  }

  /// Force the session into a clean record-capable state RIGHT BEFORE
  /// recorder.start(). The two-step (stop the player, give iOS ~250ms,
  /// re-assert the category) is what stops record_darwin writing a
  /// 28-byte ghost file because iOS hasn't actually handed it the mic.
  static Future<void> prepareForRecording(AudioPlayer player) async {
    try { await player.stop(); } catch (_) {}
    // Give iOS a beat to release the playback session.
    await Future.delayed(const Duration(milliseconds: 250));
    try {
      await AudioPlayer.global.setAudioContext(_playAndRecordContext());
    } catch (_) {}
    // Second short pause so the new category is fully applied before
    // record_darwin tries to set it again from Swift.
    await Future.delayed(const Duration(milliseconds: 100));
  }

  static AudioContext _playAndRecordContext() => AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord,
          options: const {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.allowBluetooth,
            AVAudioSessionOptions.allowBluetoothA2DP,
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.voiceCommunication,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      );
}
