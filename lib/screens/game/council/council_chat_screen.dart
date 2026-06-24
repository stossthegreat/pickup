import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../services/audio_session.dart';
import '../../../services/auralay_api.dart' show AuralayApiError;
import '../../../services/creator_mode_store.dart';
import '../../../services/user_memory.dart';
import '../../../services/villain/villain_api.dart';
import '../../../theme/auralay_app_colors.dart';
import '../../../theme/auralay_app_typography.dart';
import '../../../widgets/debug_panel.dart';
import '../../../widgets/safe_close_button.dart';

/// THE COUNCIL — private back-and-forth with Lucien.
///
/// Voice in, voice out. The apprentice taps the big red mic, speaks,
/// taps to send. Whisper transcribes; the council prompt routes the
/// transcript to Lucien (two short paragraphs max, never both
/// monologue and ask); his reply lands in the scrollback as a Lucien
/// bubble + plays automatically in his voice. The mic comes back live
/// the moment the playback finishes — fluid back-and-forth, no
/// taps-to-continue. The chat scroll on screen IS the transcript,
/// surfaced exactly as the user spec'd.
class CouncilChatScreen extends StatefulWidget {
  const CouncilChatScreen({super.key});

  @override
  State<CouncilChatScreen> createState() => _CouncilChatScreenState();
}

enum _Phase {
  idle,        // mic ready
  recording,   // user speaking
  thinking,    // uploading + Whisper, before first token
  streaming,   // Lucien's words landing token-by-token
  speaking,    // playing Lucien's reply audio
  error,
}

class _CouncilChatScreenState extends State<CouncilChatScreen> {
  final AudioPlayer      _player    = AudioPlayer();
  final AudioRecorder    _recorder  = AudioRecorder();
  final ScrollController _scroll    = ScrollController();

  final List<_CouncilMsg> _msgs = [];
  _Phase _phase = _Phase.idle;
  bool   _disposed = false;
  String _error = '';
  String? _activeRecordingPath;
  DateTime? _recordingStarted;

  final List<DebugEvent> _events = [];
  void _log(String level, String tag, String message) {
    final e = DebugEvent(
      ts: DateTime.now(), level: level, tag: tag, message: message,
    );
    _events.add(e);
    if (_events.length > 60) _events.removeRange(0, _events.length - 60);
    // ignore: avoid_print
    print('[council] ${e.level.toUpperCase()} ${e.tag} ${e.message}');
  }

  @override
  void initState() {
    super.initState();
    // Crucial — iOS audioplayers default is playback-only, which
    // silently kills the recorder. Set the session before anything.
    // ignore: discarded_futures
    AudioSession.configureForPlayAndRecord();
    // ignore: discarded_futures
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _disposed = true;
    // ignore: discarded_futures
    WakelockPlus.disable();
    _player.dispose();
    // ignore: discarded_futures
    _recorder.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _shutdown() async {
    _disposed = true;
    try { await _player.stop();   } catch (_) {}
    try { await _recorder.stop(); } catch (_) {}
  }

  // ─── Recording ────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_disposed || _phase != _Phase.idle) return;
    try {
      if (!await _recorder.hasPermission()) {
        _fail('Microphone permission denied.');
        return;
      }
      await AudioSession.prepareForRecording(_player);
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/council_${DateTime.now().millisecondsSinceEpoch}.m4a';
      const cfg = RecordConfig(
        encoder:     AudioEncoder.aacLc,
        sampleRate:  44100,
        bitRate:     128000,
        numChannels: 1,
      );
      // v307 — !pri recover-and-retry, same shape as Arena.
      try {
        await _recorder.start(cfg, path: path);
      } catch (err) {
        if (!AudioSession.isInsufficientPriorityError(err)) rethrow;
        _log('warn', 'MIC', '!pri detected — recovering');
        await AudioSession.recoverFromPriorityConflict();
        try {
          await _recorder.start(cfg, path: path);
          _log('ok', 'MIC', '!pri recovery succeeded');
        } catch (err2) {
          _log('error', 'MIC', '!pri recovery FAILED: $err2');
          _fail(AudioSession.priorityConflictMessage);
          return;
        }
      }
      _activeRecordingPath = path;
      _recordingStarted   = DateTime.now();
      HapticFeedback.mediumImpact();
      _log('ok', 'MIC', 'recording → $path');
      setState(() => _phase = _Phase.recording);
    } catch (e) {
      _log('error', 'MIC', e.toString());
      _fail(e.toString());
    }
  }

  Future<void> _stopAndSend() async {
    if (_disposed || _phase != _Phase.recording) return;
    String? finalPath;
    try {
      finalPath = await _recorder.stop();
      finalPath ??= _activeRecordingPath;
      HapticFeedback.lightImpact();
    } catch (e) {
      _log('error', 'MIC', 'stop failed: $e');
    }
    if (finalPath == null) {
      _fail('No audio captured.');
      return;
    }
    await Future.delayed(const Duration(milliseconds: 200));
    final file = File(finalPath);
    final exists = await file.exists();
    final size   = exists ? await file.length() : 0;
    _log('info', 'MIC', 'stopped · file=${size}B exists=$exists');
    if (!exists || size < 200) {
      _fail('No audio captured — check mic permission.');
      return;
    }

    setState(() {
      _phase = _Phase.thinking;
      _error = '';
    });

    try {
      final memoryBlock = await UserMemory.buildSystemPromptBlock();
      final creator = await CreatorModeStore.isActive();
      final history = _msgs
          .map((m) => VillainHistoryEntry(role: m.role, text: m.text))
          .toList();
      _log('info', 'API', 'POST /v1/villain/council/stream · creator=$creator');

      _CouncilMsg? lucienMsg;     // grows as deltas arrive
      Uint8List? finalAudio;

      await for (final ev in VillainApi.councilVoiceStream(
        audioFile:   file,
        history:     history,
        memoryBlock: memoryBlock,
        creator:     creator,
      )) {
        if (!mounted || _disposed) return;
        if (ev.type == 'transcript') {
          if (ev.text.isNotEmpty) {
            setState(() =>
                _msgs.add(_CouncilMsg(role: 'user', text: ev.text)));
            _scrollDown();
          }
        } else if (ev.type == 'delta') {
          if (ev.text.isNotEmpty) {
            if (lucienMsg == null) {
              lucienMsg = _CouncilMsg(role: 'lucien', text: ev.text);
              setState(() {
                _msgs.add(lucienMsg!);
                _phase = _Phase.streaming;
              });
            } else {
              setState(() => lucienMsg!.text += ev.text);
            }
            _scrollDown();
          }
        } else if (ev.type == 'done') {
          if (lucienMsg != null && ev.text.isNotEmpty) {
            setState(() => lucienMsg!.text = ev.text);
          } else if (lucienMsg == null && ev.text.isNotEmpty) {
            setState(() =>
                _msgs.add(_CouncilMsg(role: 'lucien', text: ev.text)));
          }
          finalAudio = ev.audioBytes;
          _scrollDown();
        } else if (ev.type == 'error') {
          throw AuralayApiError('stream_error',
              ev.detail.isEmpty ? 'Lucien lost the line.' : ev.detail);
        }
      }

      try { await file.delete(); } catch (_) {}
      if (!mounted || _disposed) return;

      _log('ok', 'STREAM', 'reply len=${lucienMsg?.text.length ?? 0}');

      if (finalAudio != null && finalAudio.isNotEmpty) {
        setState(() => _phase = _Phase.speaking);
        try {
          await _player.play(BytesSource(finalAudio, mimeType: 'audio/mpeg'));
          try {
            await _player.onPlayerComplete.first
                .timeout(const Duration(seconds: 90));
          } catch (_) {}
        } catch (e) {
          _log('warn', 'PLAY', e.toString());
        }
      }

      if (!mounted || _disposed) return;
      setState(() => _phase = _Phase.idle);
    } catch (e) {
      try { await file.delete(); } catch (_) {}
      _log('error', 'API', e.toString());
      _fail(e.toString());
    }
  }

  void _fail(String msg) {
    if (!mounted || _disposed) return;
    setState(() {
      _phase = _Phase.error;
      _error = msg;
    });
  }

  void _onMicPress() {
    if (_phase == _Phase.idle) {
      // ignore: discarded_futures
      _startRecording();
    } else if (_phase == _Phase.recording) {
      // ignore: discarded_futures
      _stopAndSend();
    } else if (_phase == _Phase.error) {
      setState(() {
        _phase = _Phase.idle;
        _error = '';
      });
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── UI ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top chrome ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 14, 6),
              child: Row(
                children: [
                  Text('THE COUNCIL',
                      style: AppTypography.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 11,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(width: 8),
                  Container(
                    width: 5, height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.accent, shape: BoxShape.circle),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                    .fadeIn(duration: 800.ms).then().fadeOut(duration: 800.ms),
                  const Spacer(),
                  SafeCloseButton(onTearDown: _shutdown),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('Lucien is listening.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.accent,
                    fontSize: 13,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  )),
            ),

            // ── Chat list ────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _msgs.length
                    + (_phase == _Phase.thinking ? 1 : 0)
                    + (_msgs.isEmpty ? 1 : 0),
                itemBuilder: (_, i) {
                  if (_msgs.isEmpty && i == 0) return const _EmptyHint();
                  if (i == _msgs.length) return const _ThinkingBubble();
                  return _MessageBubble(msg: _msgs[i]);
                },
              ),
            ),

            // ── Error band ───────────────────────────────────────────
            if (_phase == _Phase.error)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.signalRedBorder, width: 0.8),
                ),
                child: Text(_error,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.signalRed,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    )),
              ),

            // ── Big mic button + status ──────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              decoration: const BoxDecoration(
                color: AppColors.base,
                border: Border(
                  top: BorderSide(color: AppColors.divider, width: 0.6),
                ),
              ),
              child: Column(
                children: [
                  _MicButton(phase: _phase, onPress: _onMicPress),
                  const SizedBox(height: 10),
                  Text(_statusLabel(),
                      style: AppTypography.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 11,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                      )),
                ],
              ),
            ),

            // ── Debug panel under input ─────────────────────────────
            DebugPanel(
              kvs: {
                'messages': '${_msgs.length}',
                'phase':    _phase.name,
                'err':      _error.isEmpty
                    ? '—'
                    : (_error.length > 60
                        ? '${_error.substring(0, 60)}…'
                        : _error),
              },
              events: _events,
              margin: const EdgeInsets.only(left: 10, bottom: 6),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel() {
    switch (_phase) {
      case _Phase.idle:      return 'TAP TO SPEAK';
      case _Phase.recording: return 'RECORDING · TAP TO SEND';
      case _Phase.thinking:  return 'LUCIEN IS LISTENING';
      case _Phase.streaming: return 'LUCIEN IS REPLYING';
      case _Phase.speaking:  return 'LUCIEN IS SPEAKING';
      case _Phase.error:     return 'TAP TO TRY AGAIN';
    }
  }
}

class _CouncilMsg {
  /// "user" | "lucien"
  final String role;
  String text;          // mutable — Lucien's bubble grows as tokens stream in
  _CouncilMsg({required this.role, required this.text});
}

class _MessageBubble extends StatelessWidget {
  final _CouncilMsg msg;
  const _MessageBubble({required this.msg});
  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.accent : AppColors.surface1,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(14),
                  topRight:    const Radius.circular(14),
                  bottomLeft:  Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppColors.divider, width: 0.6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(isUser ? 'YOU' : 'LUCIEN',
                        style: AppTypography.label.copyWith(
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.85)
                              : AppColors.accent,
                          fontSize: 9,
                          letterSpacing: 2.4,
                          fontWeight: FontWeight.w900,
                        )),
                  ),
                  Text(msg.text,
                      style: AppTypography.bodySmall.copyWith(
                        color: isUser ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.5,
                        fontStyle: isUser
                            ? FontStyle.normal
                            : FontStyle.italic,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.04, end: 0);
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider, width: 0.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                const SizedBox(width: 5),
                _Dot(delay: 200),
                const SizedBox(width: 5),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6, height: 6,
      decoration: const BoxDecoration(
        color: AppColors.accent, shape: BoxShape.circle),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
      .fadeIn(delay: delay.ms, duration: 500.ms)
      .then().fadeOut(duration: 500.ms);
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 30, 8, 30),
      child: Column(
        children: [
          Text('LUCIEN',
              style: AppTypography.label.copyWith(
                color: AppColors.accent,
                fontSize: 11,
                letterSpacing: 3,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 12),
          Text(
            '"Ask me what you cannot ask anyone else.  '
            'Speak less. Mean more."',
            textAlign: TextAlign.center,
            style: AppTypography.h1Italic.copyWith(
              color: AppColors.textSecondary,
              fontSize: 17,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 26),
          Text('TAP THE MIC BELOW',
              style: AppTypography.label.copyWith(
                color: AppColors.textTertiary,
                fontSize: 10,
                letterSpacing: 3,
                fontWeight: FontWeight.w900,
              )),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final _Phase phase;
  final VoidCallback onPress;
  const _MicButton({required this.phase, required this.onPress});
  @override
  Widget build(BuildContext context) {
    final isRecording = phase == _Phase.recording;
    final isWaiting   = phase == _Phase.thinking ||
                        phase == _Phase.streaming ||
                        phase == _Phase.speaking;
    final canTap      = !isWaiting;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: canTap ? () { HapticFeedback.mediumImpact(); onPress(); } : null,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: isRecording ? 100 : 88,
          height: isRecording ? 100 : 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: !canTap ? AppColors.surface3 : AppColors.accent,
            boxShadow: !canTap ? [] : [
              BoxShadow(
                color: AppColors.accent.withValues(
                    alpha: isRecording ? 0.55 : 0.30),
                blurRadius: isRecording ? 50 : 30,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Icon(
            isRecording
                ? Icons.stop_rounded
                : (!canTap
                    ? Icons.hourglass_empty_rounded
                    : Icons.mic_rounded),
            color: !canTap ? AppColors.textTertiary : Colors.white,
            size: isRecording ? 40 : 34,
          ),
        ),
      ),
    );
  }
}
