import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../models/villain/scenes.dart';
import '../../../services/audio_session.dart';
import '../../../services/creator_mode_store.dart';
import '../../../services/user_memory.dart';
import '../../../services/villain/villain_api.dart';
import '../../../theme/auralay_app_colors.dart';
import '../../../theme/auralay_app_typography.dart';
import '../../../widgets/debug_panel.dart';
import '../../../widgets/safe_close_button.dart';

/// THE ARENA — scene session screen.
///
/// The flow the apprentice walks through:
///
///   1. INTRO  — Lucien narrates the room. Four-to-six short sentences
///               in his voice. Sets the temperature, places the
///               apprentice in the scene, warns him about her, states
///               his goal. (POST /v1/villain/scene/intro)
///
///   2. OPEN   — She speaks her verbatim opening line. (POST
///               /v1/villain/scene/open — TTS only.)
///
///   3. LOOP   — Big record button at the bottom. Apprentice taps to
///               record, taps to send. POST /v1/villain/scene/turn
///               with audio + history. Whisper + GPT-in-archetype +
///               TTS round-trip in one call. Her reply audio plays
///               while the transcript appears in the scrolling chat
///               above. Every third apprentice turn and on the final
///               turn, Lucien cuts in via /v1/villain/scene/coach with
///               a four-paragraph surgical breakdown.
///
///   4. CLOSE  — After 6 apprentice turns, the scene closes. DONE
///               CTA. Result saved to UserMemory.
///
/// UI choices that came directly from user feedback:
///   - The transcript is ALWAYS visible — every line she said, every
///     line he said, every Lucien cut-in — as a scrolling chat. No
///     "ephemeral big quote in the middle" pattern.
///   - The mic is a fat 110pt circle pinned to the bottom centre.
///     Idle red, recording red+larger, processing/playing grey. No
///     other interactive element competes with it.
///   - Pause is a real button in the top chrome and a full-screen
///     overlay when active. Audio pauses, recording cannot start.
///   - Every button has a 44pt+ tap target and an InkWell ripple.
class ArenaSessionScreen extends StatefulWidget {
  final VillainScene scene;
  const ArenaSessionScreen({super.key, required this.scene});

  @override
  State<ArenaSessionScreen> createState() => _ArenaSessionScreenState();
}

// Coach cuts in every Nth apprentice turn (and on the final turn).
const int _kCoachEvery = 3;
// Hard cap on apprentice turns per scene.
const int _kMaxTurns   = 6;

enum _Phase {
  introThinking,    // POSTing /scene/intro, no audio yet.
  introSpeaking,    // Lucien's narration playing.
  opening,          // She speaks her opener.
  listening,        // Mic idle, ready for tap-to-record.
  recording,        // Mic active.
  thinking,         // Uploading + waiting on her reply.
  diablaSpeaking,   // Her audio playing.
  coachThinking,    // Awaiting Lucien's cut-in.
  coachSpeaking,    // Lucien's audio playing.
  done,             // Scene closed.
  error,
}

/// One message in the scrolling chat.
class _ChatItem {
  final _Speaker speaker;
  final String   text;
  _ChatItem({required this.speaker, required this.text});
}

enum _Speaker { lucien, her, you }

class _ArenaSessionScreenState extends State<ArenaSessionScreen> {
  final AudioPlayer       _player    = AudioPlayer();
  final AudioRecorder     _recorder  = AudioRecorder();
  final ScrollController  _scroll    = ScrollController();

  _Phase _phase    = _Phase.introThinking;
  bool   _disposed = false;
  bool   _paused   = false;
  Completer<void>? _pauseLatch;

  String _errorMsg = '';

  // Conversation history fed to the prompt every turn. Distinct from
  // _chat, which is the on-screen scrollback (also includes Lucien
  // cut-ins, which never go into the conversation history fed to
  // her).
  final List<VillainHistoryEntry> _history = [];
  final List<_ChatItem>           _chat    = [];

  // Most recent in-scene lines — used as the verbatim coach context.
  String _lastDiablaLine     = '';
  String _lastApprenticeLine = '';

  int _apprenticeTurnCount = 0;
  String? _activeRecordingPath;

  // Creator UNCHAINED mode — loaded once at session start. When true,
  // every backend call carries creator:true so Lucien + the women run
  // the savage, roasting persona.
  bool _creator = false;

  // ─── Debug log ─────────────────────────────────────────────────────
  final List<DebugEvent> _events = [];

  void _log(String level, String tag, String message) {
    final e = DebugEvent(
      ts: DateTime.now(), level: level, tag: tag, message: message,
    );
    _events.add(e);
    if (_events.length > 60) _events.removeRange(0, _events.length - 60);
    // ignore: avoid_print
    print('[arena] ${e.level.toUpperCase()} ${e.tag} ${e.message}');
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Crucial — without this, iOS keeps audioplayers in playback-only
    // mode and the record plugin silently writes near-empty files when
    // the apprentice taps mic. This is the root cause of "Recording
    // too short — try again" we kept hitting in the Arena.
    // ignore: discarded_futures
    AudioSession.configureForPlayAndRecord();
    // ignore: discarded_futures
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    _disposed = true;
    // ignore: discarded_futures
    WakelockPlus.disable();
    _scroll.dispose();
    _player.dispose();
    // ignore: discarded_futures
    _recorder.dispose();
    super.dispose();
  }

  /// Pop the screen immediately, then tear down in the background.
  /// Awaiting _player.stop()/_recorder.stop() before popping used to
  /// swallow the DONE / X / GO BACK taps when teardown was slow.
  void _closeScreen() {
    if (!mounted) return;
    safePop(context);
    _disposed = true;
    // ignore: discarded_futures
    _player.stop().catchError((_) {});
    // ignore: discarded_futures
    _recorder.stop().catchError((_) {});
  }

  // ─── Pause / Resume ───────────────────────────────────────────────

  void _togglePause() {
    if (_paused) {
      _resume();
    } else {
      _pause();
    }
  }

  void _pause() {
    if (_paused || _disposed) return;
    HapticFeedback.lightImpact();
    setState(() {
      _paused = true;
      _pauseLatch = Completer<void>();
    });
    // ignore: discarded_futures
    _player.pause().catchError((_) {});
    _log('info', 'PAUSE', 'paused');
  }

  void _resume() {
    if (!_paused || _disposed) return;
    HapticFeedback.lightImpact();
    final latch = _pauseLatch;
    setState(() {
      _paused = false;
      _pauseLatch = null;
    });
    // ignore: discarded_futures
    _player.resume().catchError((_) {});
    if (latch != null && !latch.isCompleted) latch.complete();
    _log('info', 'PAUSE', 'resumed');
  }

  Future<void> _checkPauseGate() async {
    if (_pauseLatch != null && !_pauseLatch!.isCompleted) {
      await _pauseLatch!.future;
    }
  }

  // ─── Flow ─────────────────────────────────────────────────────────

  Future<void> _begin() async {
    if (_disposed) return;
    _creator = await CreatorModeStore.isActive();
    _log('info', 'SESSION',
        'BEGIN · scene=${widget.scene.id} · creator=$_creator');

    // 1) Lucien's cinematic narration.
    try {
      setState(() => _phase = _Phase.introThinking);
      _log('info', 'API', 'POST /v1/villain/scene/intro');
      final intro = await VillainApi.sceneIntro(
          sceneId: widget.scene.id, creator: _creator);
      if (_disposed || !mounted) return;
      _chat.add(_ChatItem(speaker: _Speaker.lucien, text: intro.reply));
      _scrollDown();
      setState(() => _phase = _Phase.introSpeaking);
      await _playBytes(intro.audioBytes);
      if (_disposed || !mounted) return;
    } catch (e) {
      _failWith(e);
      return;
    }

    // 2) Her opening line.
    try {
      setState(() => _phase = _Phase.opening);
      _log('info', 'API', 'POST /v1/villain/scene/open');
      final open = await VillainApi.sceneOpen(
        sceneId: widget.scene.id,
        opening: widget.scene.opening,
      );
      if (_disposed || !mounted) return;
      _lastDiablaLine = open.reply;
      _history.add(VillainHistoryEntry(role: 'diabla', text: open.reply));
      _chat.add(_ChatItem(speaker: _Speaker.her, text: open.reply));
      _scrollDown();
      setState(() => _phase = _Phase.diablaSpeaking);
      await _playBytes(open.audioBytes);
      if (_disposed || !mounted) return;
      setState(() => _phase = _Phase.listening);
    } catch (e) {
      _failWith(e);
    }
  }

  // ─── Recording ─────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_disposed || _phase == _Phase.recording || _paused) return;
    try {
      if (!await _recorder.hasPermission()) {
        _failWith(const _ArenaError('Microphone permission denied.'));
        return;
      }
      // CRITICAL — without this two-step handoff, record_darwin writes
      // a 28-byte m4a container with zero audio because iOS never
      // actually transitions the session out of playback mode.
      await AudioSession.prepareForRecording(_player);
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/arena_${DateTime.now().millisecondsSinceEpoch}.m4a';
      const cfg = RecordConfig(
        encoder:    AudioEncoder.aacLc,
        // 44.1kHz is the iOS native mic rate — using 16kHz means
        // the audio engine has to resample, and on some devices it
        // silently fails to start when paired with playAndRecord.
        sampleRate: 44100,
        bitRate:    128000,
        numChannels: 1,
      );
      // v307 — !pri recover-and-retry. If iOS denies the
      // recorder with OSStatus 561017449 because Spotify / a
      // phone call / Siri holds higher priority, run the
      // release-and-reassert dance + try once more. If the
      // retry also fails, surface the user-facing message
      // instead of just dying with a stack trace.
      try {
        await _recorder.start(cfg, path: path);
      } catch (err) {
        if (!AudioSession.isInsufficientPriorityError(err)) rethrow;
        _log('warn', 'MIC', '!pri detected — running recovery dance');
        await AudioSession.recoverFromPriorityConflict();
        try {
          await _recorder.start(cfg, path: path);
          _log('ok', 'MIC', '!pri recovery succeeded on retry');
        } catch (err2) {
          _log('error', 'MIC', '!pri recovery FAILED: $err2');
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AudioSession.priorityConflictMessage,
                style: AppTypography.label.copyWith(
                  color: Colors.white, fontSize: 13.5,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w600)),
              backgroundColor: AppColors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
            ));
          }
          rethrow;
        }
      }
      _activeRecordingPath = path;
      HapticFeedback.mediumImpact();
      _log('ok', 'MIC', 'recording → $path');
      setState(() => _phase = _Phase.recording);
    } catch (e) {
      _log('error', 'MIC', e.toString());
      _failWith(e);
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
      _failWith(const _ArenaError('Recording produced no audio file.'));
      return;
    }
    await Future.delayed(const Duration(milliseconds: 200));
    final file = File(finalPath);
    final exists = await file.exists();
    final size   = exists ? await file.length() : 0;
    _log('info', 'MIC', 'stopped · file=${size}B exists=$exists');
    if (!exists || size < 200) {
      _failWith(const _ArenaError(
        'No audio captured — check mic permission + that nothing '
        'else is using the microphone.',
      ));
      return;
    }
    setState(() => _phase = _Phase.thinking);
    await _sendTurn(file);
  }

  Future<void> _sendTurn(File audioFile) async {
    if (_disposed) return;
    try {
      final memoryBlock = await UserMemory.buildSystemPromptBlock(
        filterTopic: 'rizz',
      );
      _log('info', 'API', 'POST /v1/villain/scene/turn · history=${_history.length}');
      final turn = await VillainApi.sceneTurn(
        sceneId:     widget.scene.id,
        audioFile:   audioFile,
        history:     _history,
        memoryBlock: memoryBlock,
        creator:     _creator,
      );
      if (_disposed || !mounted) return;
      _lastApprenticeLine = turn.transcript;
      _lastDiablaLine     = turn.reply;
      _history.add(VillainHistoryEntry(role: 'user',   text: turn.transcript));
      _history.add(VillainHistoryEntry(role: 'diabla', text: turn.reply));
      _apprenticeTurnCount++;
      _log('ok', 'STT',  'user: "${_clip(turn.transcript, 60)}"');
      _log('ok', 'CHAT', 'her:  "${_clip(turn.reply, 60)}"');

      // Show the apprentice's transcribed line + her reply in the chat.
      _chat.add(_ChatItem(speaker: _Speaker.you, text: turn.transcript));
      _chat.add(_ChatItem(speaker: _Speaker.her, text: turn.reply));
      _scrollDown();

      setState(() => _phase = _Phase.diablaSpeaking);
      await _playBytes(turn.audioBytes);
      if (_disposed || !mounted) return;

      try { await audioFile.delete(); } catch (_) {}

      final isCoachTurn = _apprenticeTurnCount % _kCoachEvery == 0 ||
                          _apprenticeTurnCount >= _kMaxTurns;
      if (isCoachTurn) {
        await _runCoachCutIn();
        if (_disposed || !mounted) return;
      }

      if (_apprenticeTurnCount >= _kMaxTurns) {
        setState(() => _phase = _Phase.done);
        // ignore: discarded_futures
        _recordToMemory();
        _log('ok', 'SESSION', 'scene complete');
      } else {
        setState(() => _phase = _Phase.listening);
      }
    } catch (e) {
      _failWith(e);
    }
  }

  Future<void> _runCoachCutIn() async {
    if (_disposed) return;
    setState(() => _phase = _Phase.coachThinking);
    try {
      _log('info', 'API', 'POST /v1/villain/scene/coach');
      final memoryBlock = await UserMemory.buildSystemPromptBlock(
        filterTopic: 'rizz',
      );
      final coach = await VillainApi.sceneCoach(
        sceneId:             widget.scene.id,
        lastApprenticeLine:  _lastApprenticeLine,
        lastDiablaLine:      _lastDiablaLine,
        memoryBlock:         memoryBlock,
        creator:             _creator,
      );
      final clean = coach.reply.replaceAll('[COACH_DONE]', '').trim();
      _log('ok', 'COACH', '"${_clip(clean, 80)}"');
      _chat.add(_ChatItem(speaker: _Speaker.lucien, text: clean));
      _scrollDown();
      setState(() => _phase = _Phase.coachSpeaking);
      await _playBytes(coach.audioBytes);
    } catch (e) {
      _log('error', 'COACH', e.toString());
      // Coach failures must NOT kill the scene.
    }
  }

  Future<void> _playBytes(dynamic bytes) async {
    if (bytes == null || _disposed) return;
    await _checkPauseGate();
    if (_disposed) return;
    try {
      await _player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
      try {
        await _player.onPlayerComplete.first
            .timeout(const Duration(seconds: 120));
      } catch (_) {
        // TimeoutException — keep going.
      }
    } catch (e) {
      _log('warn', 'PLAY', e.toString());
    }
  }

  Future<void> _recordToMemory() async {
    await UserMemory.recordSession(
      topic:      'rizz',
      lessonName: widget.scene.title,
      score:      50,
      notes:      'Arena · ${widget.scene.title} · '
                  '${_apprenticeTurnCount} turns',
    );
  }

  void _failWith(Object e) {
    if (!mounted || _disposed) return;
    setState(() {
      _phase = _Phase.error;
      _errorMsg = e.toString();
    });
    _log('error', 'API', e.toString());
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

  String _clip(String s, int n) => s.length > n ? '${s.substring(0, n)}…' : s;

  // ─── UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Stack(
          children: [
            // Atmospheric red halo, drops slightly when Lucien is talking.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.4),
                      radius: 0.95,
                      colors: [
                        AppColors.accent.withValues(
                          alpha: _isCoachPhase || _phase == _Phase.introSpeaking
                              ? 0.10
                              : 0.22,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Top chrome — title, objective, turn pill, pause, X ──
            _TopChrome(
              scene:      widget.scene,
              turnCount:  _apprenticeTurnCount,
              maxTurns:   _kMaxTurns,
              paused:     _paused,
              onPause:    _togglePause,
              onClose:    _closeScreen,
            ),

            // ── Scrolling chat ─────────────────────────────────────
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 110, 0, 200),
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: _chat.length + (_isThinking ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _chat.length) return const _ThinkingBubble();
                    return _ChatBubble(item: _chat[i]);
                  },
                ),
              ),
            ),

            // ── Bottom — mic / done / error ────────────────────────
            Positioned(
              left: 0, right: 0, bottom: 18,
              child: _phase == _Phase.done
                  ? _DoneBar(onTap: _closeScreen)
                  : _phase == _Phase.error
                      ? _ErrorBar(
                          message: _errorMsg,
                          onClose: _closeScreen,
                        )
                      : _MicBar(
                          phase:   _phase,
                          paused:  _paused,
                          onPress: _onMicPress,
                          status:  _statusLabel(),
                        ),
            ),

            // ── PAUSED overlay ─────────────────────────────────────
            if (_paused)
              Positioned.fill(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.72),
                  child: InkWell(
                    onTap: _resume,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pause_rounded,
                              color: AppColors.accent, size: 64),
                          const SizedBox(height: 8),
                          Text('PAUSED',
                              style: AppTypography.label.copyWith(
                                color: AppColors.accent,
                                fontSize: 14,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w900,
                              )),
                          const SizedBox(height: 18),
                          Text('TAP TO RESUME',
                              style: AppTypography.label.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w900,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Debug panel ────────────────────────────────────────
            Positioned(
              left: 0, bottom: 0,
              child: DebugPanel(
                kvs: {
                  'scene':   widget.scene.id,
                  'phase':   _phase.name,
                  'turn':    '$_apprenticeTurnCount / $_kMaxTurns',
                  'history': '${_history.length}',
                  'chat':    '${_chat.length}',
                  'paused':  _paused ? 'yes' : 'no',
                  'mic':     _phase == _Phase.recording ? 'live' : 'idle',
                  'err':     _errorMsg.isEmpty
                      ? '—'
                      : (_errorMsg.length > 60
                          ? '${_errorMsg.substring(0, 60)}…'
                          : _errorMsg),
                },
                events: _events,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isCoachPhase =>
      _phase == _Phase.coachThinking || _phase == _Phase.coachSpeaking;

  bool get _isThinking =>
      _phase == _Phase.introThinking ||
      _phase == _Phase.thinking ||
      _phase == _Phase.coachThinking;

  void _onMicPress() {
    if (_paused) return;
    if (_phase == _Phase.listening) {
      // ignore: discarded_futures
      _startRecording();
    } else if (_phase == _Phase.recording) {
      // ignore: discarded_futures
      _stopAndSend();
    }
  }

  String _statusLabel() {
    switch (_phase) {
      case _Phase.introThinking:   return 'LUCIEN IS WATCHING';
      case _Phase.introSpeaking:   return 'LUCIEN IS NARRATING';
      case _Phase.opening:         return 'SHE IS OPENING';
      case _Phase.listening:       return 'TAP TO REPLY';
      case _Phase.recording:       return 'RECORDING · TAP TO SEND';
      case _Phase.thinking:        return 'SHE IS LISTENING';
      case _Phase.diablaSpeaking:  return 'SHE IS SPEAKING';
      case _Phase.coachThinking:   return 'LUCIEN IS WATCHING';
      case _Phase.coachSpeaking:   return 'LUCIEN IS CUTTING IN';
      case _Phase.done:            return 'SCENE COMPLETE';
      case _Phase.error:           return 'LINE DROPPED';
    }
  }
}

class _ArenaError implements Exception {
  final String message;
  const _ArenaError(this.message);
  @override
  String toString() => message;
}

// ─── Top chrome ──────────────────────────────────────────────────────

class _TopChrome extends StatelessWidget {
  final VillainScene scene;
  final int turnCount;
  final int maxTurns;
  final bool paused;
  final VoidCallback onPause;
  final VoidCallback onClose;

  const _TopChrome({
    required this.scene,
    required this.turnCount,
    required this.maxTurns,
    required this.paused,
    required this.onPause,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 6, left: 8, right: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Text(scene.title,
                    style: AppTypography.label.copyWith(
                      color: AppColors.accent,
                      fontSize: 11,
                      letterSpacing: 2.8,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.divider, width: 0.6),
                ),
                child: Text('TURN $turnCount / $maxTurns',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              const SizedBox(width: 4),
              _IconButton(
                icon: paused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                onTap: onPause,
              ),
              _IconButton(icon: Icons.close_rounded, onTap: onClose),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Text('TEACHING  ·  ${scene.law}',
                style: AppTypography.label.copyWith(
                  color: AppColors.accent,
                  fontSize: 10,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w900,
                )),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
            child: Text('OBJECTIVE  ·  ${scene.objective}',
                style: AppTypography.label.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w900,
                )),
          ),
        ],
      ),
    );
  }
}

/// 44pt-tap-target icon button with an InkWell so taps register
/// reliably. Used for pause + close in the top chrome.
class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44, height: 44,
          child: Center(
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}

// ─── Chat ────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final _ChatItem item;
  const _ChatBubble({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.speaker == _Speaker.lucien) return _LucienBubble(text: item.text);
    final isYou = item.speaker == _Speaker.you;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isYou ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: isYou ? AppColors.accent : AppColors.surface1,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(14),
                  topRight:    const Radius.circular(14),
                  bottomLeft:  Radius.circular(isYou ? 14 : 4),
                  bottomRight: Radius.circular(isYou ? 4 : 14),
                ),
                border: isYou
                    ? null
                    : Border.all(color: AppColors.accentBorder, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isYou ? 'YOU' : 'HER',
                      style: AppTypography.label.copyWith(
                        color: isYou
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppColors.accent,
                        fontSize: 9,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 4),
                  Text(item.text,
                      style: AppTypography.bodySmall.copyWith(
                        color: isYou ? Colors.white : AppColors.textPrimary,
                        fontSize: 14.5,
                        height: 1.5,
                        fontStyle: isYou
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

/// Lucien's contributions are visually distinct — a dark inset card
/// running full width with a ghost-grey label. He is not in the
/// scene with her, he is watching from outside.
class _LucienBubble extends StatelessWidget {
  final String text;
  const _LucienBubble({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF14141A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.textTertiary.withValues(alpha: 0.4),
              width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('LUCIEN',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 10.5,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w900,
                    )),
              ],
            ),
            const SizedBox(height: 10),
            Text(text,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.55,
                  fontStyle: FontStyle.italic,
                )),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0);
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

// ─── Mic bar (the one pinned to the bottom) ──────────────────────────

class _MicBar extends StatelessWidget {
  final _Phase phase;
  final bool paused;
  final VoidCallback onPress;
  final String status;
  const _MicBar({
    required this.phase,
    required this.paused,
    required this.onPress,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isRecording = phase == _Phase.recording;
    final isWaiting   = phase == _Phase.thinking ||
                        phase == _Phase.diablaSpeaking ||
                        phase == _Phase.coachThinking ||
                        phase == _Phase.coachSpeaking ||
                        phase == _Phase.opening ||
                        phase == _Phase.introThinking ||
                        phase == _Phase.introSpeaking;
    final canTap = !paused && !isWaiting;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: canTap ? () { HapticFeedback.mediumImpact(); onPress(); } : null,
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: isRecording ? 118 : 104,
              height: isRecording ? 118 : 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !canTap
                    ? AppColors.surface3
                    : AppColors.accent,
                boxShadow: !canTap
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.accent.withValues(
                              alpha: isRecording ? 0.55 : 0.30),
                          blurRadius: isRecording ? 60 : 36,
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
                size: isRecording ? 48 : 40,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(status,
            style: AppTypography.label.copyWith(
              color: AppColors.accent,
              fontSize: 11,
              letterSpacing: 3,
              fontWeight: FontWeight.w900,
            )),
      ],
    );
  }
}

class _DoneBar extends StatelessWidget {
  final VoidCallback onTap;
  const _DoneBar({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () { HapticFeedback.lightImpact(); onTap(); },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('DONE',
                style: AppTypography.label.copyWith(
                  color: Colors.white,
                  fontSize: 13,
                  letterSpacing: 3.6,
                  fontWeight: FontWeight.w900,
                )),
          ),
        ),
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  const _ErrorBar({required this.message, required this.onClose});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.signalRedBorder, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LINE DROPPED',
                style: AppTypography.label.copyWith(
                  color: AppColors.signalRed,
                  fontSize: 11,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(height: 6),
            Text(message,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  height: 1.4,
                )),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(100),
              child: InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface3,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: AppColors.divider, width: 0.6),
                  ),
                  child: Text('GO BACK',
                      style: AppTypography.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 10,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w900,
                      )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
