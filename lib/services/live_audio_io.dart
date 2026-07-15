import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

import 'audio_session.dart';

/// Streaming audio I/O for the realtime live session.
///
/// MIC IN  — uses `record`'s startStream() to pull PCM16 chunks from
///           the microphone at 24kHz mono. Hands each chunk to the
///           supplied callback. The realtime WebSocket sends them on.
///
/// VOICE OUT — accumulates PCM16 chunks Diablo sends back. Once a
///             response is complete, wraps the accumulated PCM in a
///             WAV header and plays it with audioplayers.
///
/// This is "chunked streaming", not true sub-100ms streaming — the
/// playback waits for the full response before starting. Latency:
/// ~1-2s from user speech end to Diablo speech start (vs ~5-7s on
/// the request/response flow). True chunk-by-chunk playback needs
/// flutter_sound; tracked for push 14.
class LiveAudioIO {
  static const int _sampleRate = 24000;     // Realtime API expects 24kHz
  static const int _channels   = 1;
  static const int _bitsPerSample = 16;

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer   _player   = AudioPlayer();
  StreamSubscription<Uint8List>? _micSub;
  final List<int> _pendingPcm = [];

  bool _capturing = false;
  bool get isCapturing => _capturing;
  bool _audioContextConfigured = false;

  /// Configures the iOS audio session so the player can output through
  /// the speaker WHILE the recorder is capturing. Default
  /// audioplayers context is `playback` (record-incompatible) — the
  /// realtime tabs need `playAndRecord` with `defaultToSpeaker` so
  /// Diabla's voice routes to the loudspeaker, not the ear-speaker,
  /// during a live conversation. Without this the user sees "DIABLA
  /// IS SPEAKING" but hears nothing — the session is muted by the
  /// recorder owning the audio category.
  Future<void> _ensureAudioContext() async {
    if (_audioContextConfigured) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: const {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.allowBluetooth,
              AVAudioSessionOptions.allowBluetoothA2DP,
            },
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.voiceCommunication,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      _audioContextConfigured = true;
    } catch (_) {
      // Setting audio context can fail on first call on some devices —
      // we'll try again next playback attempt.
    }
  }

  // ─── MIC ────────────────────────────────────────────────────────────────

  /// Begin streaming PCM16 chunks from the mic. Each chunk is handed
  /// to [onChunk] for forwarding (typically straight to
  /// [RealtimeSession.sendAudioChunk]).
  ///
  /// Returns true on success, false if permission was denied.
  Future<bool> startMic({
    required void Function(Uint8List pcm16le) onChunk,
  }) async {
    if (_capturing) return true;
    if (!await _recorder.hasPermission()) return false;

    // Configure play+record audio session BEFORE the recorder grabs
    // the audio engine; otherwise playback gets routed to ear-speaker
    // (or silenced entirely) on iOS.
    await _ensureAudioContext();

    // v307 — !pri recover-and-retry. Service-level, so we throw a
    // human-readable error on final failure; the caller surfaces it
    // however it wants (snackbar, banner, log). AudioSession's
    // message constant gives every caller identical user-facing
    // copy.
    const cfg = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: _channels,
      // Echo cancellation + noise suppression where the platform
      // exposes them — keeps Diablo's voice out of the mic loop.
      echoCancel: true,
      noiseSuppress: true,
    );
    Stream<Uint8List> stream;
    try {
      stream = await _recorder.startStream(cfg);
    } catch (err) {
      if (!AudioSession.isInsufficientPriorityError(err)) rethrow;
      await AudioSession.recoverFromPriorityConflict();
      try {
        stream = await _recorder.startStream(cfg);
      } catch (_) {
        throw Exception(AudioSession.priorityConflictMessage);
      }
    }
    _micSub = stream.listen(onChunk);
    _capturing = true;
    return true;
  }

  Future<void> stopMic() async {
    if (!_capturing) return;
    await _micSub?.cancel();
    _micSub = null;
    await _recorder.stop();
    _capturing = false;
  }

  // ─── DIABLO VOICE OUT ──────────────────────────────────────────────────

  /// Append a PCM16 audio chunk that arrived from the realtime
  /// WebSocket. Chunks accumulate until [flushAndPlay] is called
  /// (typically on the `response.done` event).
  void appendPcm(Uint8List chunk) {
    _pendingPcm.addAll(chunk);
  }

  /// Wrap all accumulated PCM in a WAV header and play it. Resets
  /// the buffer afterwards so the next response starts clean.
  Future<void> flushAndPlay() async {
    if (_pendingPcm.isEmpty) return;
    final pcm = Uint8List.fromList(_pendingPcm);
    _pendingPcm.clear();
    final wav = _wrapInWavHeader(
      pcm: pcm,
      sampleRate: _sampleRate,
      channels:   _channels,
      bitsPerSample: _bitsPerSample,
    );
    // Make sure the iOS audio session is play+record before playback
    // — if startMic hasn't yet been called (e.g. teacher speaks first
    // before VAD warmup), the session may still be in default category
    // which would silence the speaker.
    await _ensureAudioContext();
    try {
      await _player.play(BytesSource(wav, mimeType: 'audio/wav'));
    } catch (_) {
      // Playback can fail mid-response if the screen tears down —
      // swallow silently rather than crash the session.
    }
  }

  /// Cancel any audio Diablo is currently speaking (used when the user
  /// starts talking over her — we duck her voice immediately).
  Future<void> interruptPlayback() async {
    _pendingPcm.clear();
    try {
      await _player.stop();
    } catch (_) {}
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await stopMic();
    await _recorder.dispose();
    await _player.dispose();
  }

  // ─── WAV header builder ────────────────────────────────────────────────

  static Uint8List _wrapInWavHeader({
    required Uint8List pcm,
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    final byteRate   = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize   = pcm.length;
    final chunkSize  = 36 + dataSize;

    final header = BytesBuilder()
      ..add(_ascii('RIFF'))
      ..add(_u32le(chunkSize))
      ..add(_ascii('WAVE'))
      ..add(_ascii('fmt '))
      ..add(_u32le(16))                  // PCM fmt chunk size
      ..add(_u16le(1))                   // audio format = PCM
      ..add(_u16le(channels))
      ..add(_u32le(sampleRate))
      ..add(_u32le(byteRate))
      ..add(_u16le(blockAlign))
      ..add(_u16le(bitsPerSample))
      ..add(_ascii('data'))
      ..add(_u32le(dataSize))
      ..add(pcm);
    return header.toBytes();
  }

  static List<int> _ascii(String s) => s.codeUnits;
  static List<int> _u16le(int v) =>
      [v & 0xFF, (v >> 8) & 0xFF];
  static List<int> _u32le(int v) =>
      [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
}
