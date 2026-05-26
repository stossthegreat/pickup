import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../models/lessons/syllabus.dart';
import '../../services/auralay_api.dart';
import '../../services/user_memory.dart';
import '../../theme/auralay_app_colors.dart';
import '../../theme/auralay_app_typography.dart';
import '../../widgets/debug_panel.dart';
import '../../widgets/lesson_briefing_card.dart';
import '../../widgets/safe_close_button.dart';

/// The voice / rizz teacher session.
///
/// This used to drive the OpenAI Realtime WebSocket. It now copies the
/// proven eyes pattern: each beat is a /v1/diablo/speak TTS call,
/// played sequentially, with a silent practice window in between
/// where the apprentice repeats the line out loud. No streaming, no
/// WebSocket, no microphone capture — just the same TTS path that
/// has been reliably working for the eye-contact lessons.
///
/// Per target line, runs the five-beat loop:
///   1. NAME    — "Target one." (number)
///   2. WHY     — lesson one-liner (only on the first target line of
///                 the lesson — repeating it on every line is noise)
///   3. DEMO    — Diabla / Lucien delivers the line in their voice
///   4. YOU GO  — "Your turn." + the delivery cue
///   5. PRACTICE WINDOW — 10s silent practice with the line on screen
///   6. JUDGE   — Canned advance line ("Move on.")
class TeacherSessionScreen extends StatefulWidget {
  /// "lucien" or "diabla"
  final String teacherId;

  /// "rhetoric" or "rizz"
  final String topic;

  /// In LESSON mode — the lesson to teach. Null = PRACTICE or ROLEPLAY mode.
  final Lesson? lesson;

  /// In ROLEPLAY mode — the scenario. Currently runs through the scene
  /// description as a single "demo" beat; full dialogue path comes
  /// later. Null otherwise.
  final Scenario? roleplay;

  /// Display name across the top of the screen.
  final String teacherDisplayName;

  const TeacherSessionScreen({
    super.key,
    required this.teacherId,
    required this.topic,
    required this.lesson,
    required this.teacherDisplayName,
    this.roleplay,
  });

  @override
  State<TeacherSessionScreen> createState() => _TeacherSessionScreenState();
}

enum _Phase {
  briefing,
  name,        // Diabla says "Target one." etc
  why,         // The one-liner (first line only)
  demo,        // Diabla performs the line
  youGo,       // "Your turn." + cue
  practice,    // silent window, user repeats the line out loud
  judge,       // "Good. Move on."
  done,
  error,
}

class _TeacherSessionScreenState extends State<TeacherSessionScreen> {
  final AudioPlayer _player = AudioPlayer();

  _Phase _phase = _Phase.briefing;
  int _lineIndex = 0;
  bool _disposed = false;
  bool _speaking = false;
  bool _paused = false;
  Completer<void>? _pauseLatch;

  // Practice-window countdown.
  int _practiceElapsed = 0;
  Timer? _practiceTimer;
  static const int _practiceSeconds = 10;

  String _errorMsg = '';

  // ─── Debug log ─────────────────────────────────────────────────────────
  final List<DebugEvent> _events = [];
  static const int _maxEvents = 60;

  bool get _isRoleplay   => widget.roleplay != null;
  bool get _isLessonMode => widget.lesson != null && !_isRoleplay;
  bool get _isPractice   => widget.lesson == null && !_isRoleplay;

  void _log(String level, String tag, String message) {
    final e = DebugEvent(
      ts: DateTime.now(), level: level, tag: tag, message: message,
    );
    _events.add(e);
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }
    // ignore: avoid_print
    print('[teacher] ${e.level.toUpperCase()} ${e.tag} ${e.message}');
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    _practiceTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _shutdown() async {
    _disposed = true;
    _practiceTimer?.cancel();
    try { await _player.stop(); } catch (_) {}
  }

  void _begin() {
    _log('info', 'SESSION', 'BEGIN tapped · '
        'mode=${_isRoleplay ? "roleplay" : _isLessonMode ? "lesson" : "practice"} '
        'teacher=${widget.teacherId}');
    _runLesson();
  }

  // ─── Pause / Resume ───────────────────────────────────────────────────

  void _pause() {
    if (_paused || _disposed) return;
    _log('info', 'SESSION', 'PAUSE');
    setState(() {
      _paused = true;
      _pauseLatch = Completer<void>();
    });
    _practiceTimer?.cancel();
    _practiceTimer = null;
    // ignore: discarded_futures
    _player.pause().catchError((_) {});
  }

  void _resume() {
    if (!_paused || _disposed) return;
    _log('info', 'SESSION', 'RESUME');
    final latch = _pauseLatch;
    setState(() {
      _paused = false;
      _pauseLatch = null;
    });
    // ignore: discarded_futures
    _player.resume().catchError((_) {});
    if (latch != null && !latch.isCompleted) latch.complete();
    if (_phase == _Phase.practice) _resumePracticeTimer();
  }

  Future<void> _checkPauseGate() async {
    if (_pauseLatch != null && !_pauseLatch!.isCompleted) {
      await _pauseLatch!.future;
    }
  }

  void _resumePracticeTimer() {
    _practiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _disposed || _paused) return;
      setState(() => _practiceElapsed++);
      if (_practiceElapsed >= _practiceSeconds) {
        _practiceTimer?.cancel();
        _afterPractice();
      }
    });
  }

  // ─── Lesson loop ───────────────────────────────────────────────────────

  Future<void> _runLesson() async {
    if (_disposed) return;

    if (_isRoleplay) {
      // For now roleplay just speaks the scene setup + opening line,
      // then closes. Full back-and-forth needs the /v1/diablo/turn
      // path (planned). The lesson drill below is what works today.
      final s = widget.roleplay!;
      setState(() => _phase = _Phase.demo);
      await _speak('${s.name}. ${s.setting}');
      if (_disposed || !mounted) return;
      await _beat();
      await _speak('You sit down. She glances over. Say something.');
      if (_disposed || !mounted) return;
      setState(() => _phase = _Phase.done);
      return;
    }

    if (_isPractice) {
      // Practice mode also collapses to a single Diabla opener for now.
      setState(() => _phase = _Phase.demo);
      await _speak('Practice mode. Tonight there is no syllabus. Open '
          'the line yourself. Say something worth my time.');
      if (_disposed || !mounted) return;
      setState(() => _phase = _Phase.done);
      return;
    }

    // ── Lesson mode — the main path ──────────────────────────────────
    final lesson = widget.lesson!;
    _log('info', 'LESSON', '${lesson.name} · ${lesson.targetLines.length} lines');

    for (int i = 0; i < lesson.targetLines.length; i++) {
      if (_disposed || !mounted) return;
      _lineIndex = i;
      final line = lesson.targetLines[i];

      // 1. NAME — short header.
      setState(() => _phase = _Phase.name);
      await _speak('Target ${i + 1}.');
      if (_disposed || !mounted) return;
      await _beat();

      // 2. WHY — one-liner, only on the FIRST target line of the lesson.
      if (i == 0) {
        setState(() => _phase = _Phase.why);
        await _speak(lesson.oneLine);
        if (_disposed || !mounted) return;
        await _beat();
      }

      // 3. DEMO — Diabla delivers the line in voice.
      setState(() => _phase = _Phase.demo);
      await _speak(line.line);
      if (_disposed || !mounted) return;
      await _beat();

      // 4. YOU GO — hand the floor.
      setState(() => _phase = _Phase.youGo);
      await _speak('Your turn. ${line.cue}.');
      if (_disposed || !mounted) return;
      await _beat(short: true);

      // 5. PRACTICE WINDOW — silent N seconds for the apprentice to
      //    repeat the line out loud. Same pattern the eyes screen uses
      //    for "hold the gaze for X seconds" — Diabla goes quiet, the
      //    line stays on screen, a countdown ticks down.
      if (_disposed || !mounted) return;
      setState(() {
        _phase = _Phase.practice;
        _practiceElapsed = 0;
      });
      _resumePracticeTimer();
      // Wait for the practice timer to finish OR a pause to resolve.
      while (_practiceElapsed < _practiceSeconds && !_disposed && mounted) {
        await Future.delayed(const Duration(milliseconds: 250));
        await _checkPauseGate();
      }
      if (_disposed || !mounted) return;
    }

    // Close the lesson.
    setState(() => _phase = _Phase.judge);
    await _speak(_closingLine(lesson));
    if (_disposed || !mounted) return;
    await _recordMemory(lesson);
    setState(() => _phase = _Phase.done);
    _log('ok', 'LESSON', 'complete');
  }

  void _afterPractice() {
    // Hook for any post-practice work — currently a no-op; the lesson
    // loop polls _practiceElapsed and advances itself.
  }

  String _closingLine(Lesson l) {
    if (widget.teacherId.toLowerCase() == 'diabla') {
      return 'Good. That is enough for tonight. Sleep on it, sweet boy.';
    }
    return 'Good. Practise what you said until the words stop feeling '
           'like yours and start feeling like the room\'s. Goodnight.';
  }

  Future<void> _recordMemory(Lesson l) async {
    await UserMemory.recordSession(
      topic:      widget.topic,
      lessonName: l.name,
      score:      50,
      notes:      'Drilled ${l.targetLines.length} lines under '
                  '${widget.teacherDisplayName}.',
    );
  }

  // ─── Voice ─────────────────────────────────────────────────────────────

  Future<void> _beat({bool short = false}) async {
    if (_disposed) return;
    await _checkPauseGate();
    await Future.delayed(
      Duration(milliseconds: short ? 400 : 800),
    );
  }

  /// What the teacher's voice mode maps to on the /v1/diablo/speak
  /// backend route. The personas file accepts either "lucien" or
  /// "diabla" / one of the legacy aliases — we hand it the raw teacher
  /// id and the backend resolves it.
  String get _speakMode => widget.teacherId.toLowerCase();

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    if (_disposed) return;
    await _checkPauseGate();
    if (_disposed) return;
    setState(() => _speaking = true);
    _log('info', 'TTS', 'speak[$_speakMode]: '
        '"${text.length > 60 ? "${text.substring(0, 60)}…" : text}"');
    try {
      final bytes = await AuralayApi.diabloSpeak(
        text: text,
        mode: _speakMode,
      );
      if (!mounted || _disposed) return;
      if (bytes != null && bytes.isNotEmpty) {
        await _player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
        try {
          await _player.onPlayerComplete.first
              .timeout(const Duration(seconds: 60));
        } catch (_) {
          // TimeoutException OR stream-closed — keep going.
        }
      } else {
        _log('warn', 'TTS', 'no audio bytes returned — silent caption');
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    } catch (e) {
      _log('error', 'TTS', e.toString());
      if (!_disposed && mounted) {
        setState(() {
          _phase = _Phase.error;
          _errorMsg = e.toString();
        });
      }
    }
    if (!mounted || _disposed) return;
    setState(() => _speaking = false);
  }

  // ─── UI ────────────────────────────────────────────────────────────────

  LessonBriefingCard _buildBriefing() {
    if (_isRoleplay) {
      final s = widget.roleplay!;
      return LessonBriefingCard(
        topLabel: 'ROLEPLAY',
        title:    s.name,
        subtitle: s.oneLineCard,
        sectionLabel: 'THE SCENE',
        items: [
          BriefingItem(primary: 'SETTING', secondary: s.setting),
        ],
        goal: 'Listen. Respond out loud. Earn the moment.',
        onBegin: _begin,
      );
    }
    if (_isLessonMode) {
      final l = widget.lesson!;
      return LessonBriefingCard(
        topLabel: 'LESSON ${l.number.toString().padLeft(2, "0")}',
        title:    l.name,
        subtitle: l.oneLine,
        sectionLabel: "TONIGHT YOU'LL DELIVER",
        items: [
          for (final t in l.targetLines)
            BriefingItem(primary: '"${t.line}"', secondary: t.cue),
        ],
        goal: '${widget.teacherDisplayName} delivers each line. You '
              'repeat it under her watch. Ten seconds per line.',
        onBegin: _begin,
      );
    }
    return LessonBriefingCard(
      topLabel: 'PRACTICE',
      title:    widget.teacherDisplayName,
      subtitle: 'Off-curriculum. She opens. You answer.',
      sectionLabel: 'HOW IT WORKS',
      items: const [
        BriefingItem(
          primary:   'NO SYLLABUS',
          secondary: 'She decides what to say first.',
        ),
      ],
      goal: 'Listen. Practice the response out loud.',
      onBegin: _begin,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.briefing) {
      return Scaffold(
        backgroundColor: AppColors.base,
        body: SafeArea(child: _buildBriefing()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Stack(
          children: [
            // Persona ember halo.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.35),
                      radius: 0.95,
                      colors: [
                        AppColors.accent.withValues(
                          alpha: _phase == _Phase.demo ? 0.32 : 0.18,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Top chrome ────────────────────────────────────────────
            Positioned(
              top: 6, left: 14, right: 14,
              child: Row(
                children: [
                  Text(widget.teacherDisplayName,
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
                    .fadeIn(duration: 800.ms)
                    .then().fadeOut(duration: 800.ms),
                  const Spacer(),
                  if (_isLessonMode)
                    _ModeChip(label: 'LESSON ${widget.lesson!.number.toString().padLeft(2, "0")}')
                  else if (_isRoleplay)
                    _ModeChip(label: 'ROLEPLAY')
                  else
                    _ModeChip(label: 'PRACTICE'),
                  const SizedBox(width: 8),
                  _PauseButton(paused: _paused, onTap: _paused ? _resume : _pause),
                  const SizedBox(width: 2),
                  SafeCloseButton(onTearDown: _shutdown),
                ],
              ),
            ),

            // ── Lesson title (lesson mode only) ──────────────────────
            if (_isLessonMode)
              Positioned(
                top: 56, left: 20, right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.lesson!.name,
                        style: AppTypography.display.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 30,
                          letterSpacing: -1,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        )),
                    const SizedBox(height: 6),
                    Text(widget.lesson!.oneLine,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.accent,
                          fontSize: 13.5,
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                        )),
                  ],
                ),
              ),

            // ── Centre — target line caption (lesson mode) ───────────
            if (_isLessonMode && _phase != _Phase.done)
              Positioned(
                left: 20, right: 20,
                top: 180, bottom: 200,
                child: Center(
                  child: _TargetLineCard(
                    line: widget.lesson!.targetLines[_lineIndex].line,
                    cue:  widget.lesson!.targetLines[_lineIndex].cue,
                    showCue: _phase == _Phase.youGo ||
                             _phase == _Phase.practice,
                    isUserTurn: _phase == _Phase.practice,
                  ),
                ),
              ),

            // ── Centre — practice countdown ───────────────────────────
            if (_phase == _Phase.practice && _isLessonMode)
              Positioned(
                left: 0, right: 0, bottom: 140,
                child: Center(
                  child: _PracticeCountdown(
                    elapsed: _practiceElapsed,
                    total:   _practiceSeconds,
                  ),
                ),
              ),

            // ── Done CTA ─────────────────────────────────────────────
            if (_phase == _Phase.done)
              Positioned(
                left: 0, right: 0, bottom: 80,
                child: Center(
                  child: _DoneCTA(onTap: () {
                    // ignore: discarded_futures
                    _shutdown();
                    if (Navigator.canPop(context)) context.pop();
                  }),
                ),
              ),

            // ── Error state ──────────────────────────────────────────
            if (_phase == _Phase.error)
              Positioned(
                left: 20, right: 20, bottom: 80,
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
                      Text(_errorMsg,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 12.5,
                            height: 1.4,
                          )),
                    ],
                  ),
                ),
              ),

            // ── Bottom — status label ─────────────────────────────────
            Positioned(
              left: 0, right: 0, bottom: 24,
              child: Center(
                child: Text(_statusLabel(),
                    style: AppTypography.label.copyWith(
                      color: AppColors.accent,
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w900,
                    )),
              ),
            ),

            // ── PAUSED overlay ────────────────────────────────────────
            if (_paused)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _resume,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.72),
                    alignment: Alignment.center,
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

            // ── Debug panel ───────────────────────────────────────────
            Positioned(
              left: 0, bottom: 0,
              child: DebugPanel(
                kvs: {
                  'mode':    _isRoleplay
                      ? 'roleplay'
                      : _isLessonMode
                          ? 'lesson'
                          : 'practice',
                  'phase':   _phase.name,
                  'teacher': widget.teacherId,
                  'topic':   widget.topic,
                  'line':    _isLessonMode
                      ? '${_lineIndex + 1}/${widget.lesson!.targetLines.length}'
                      : '—',
                  'speak':   _speaking ? 'yes' : 'no',
                  'paused':  _paused ? 'yes' : 'no',
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

  String _statusLabel() {
    if (_speaking) return '${widget.teacherDisplayName} IS SPEAKING';
    switch (_phase) {
      case _Phase.briefing: return 'READY';
      case _Phase.name:     return 'NAMING THE MOVE';
      case _Phase.why:      return 'TELLING YOU WHY';
      case _Phase.demo:     return 'LISTEN';
      case _Phase.youGo:    return 'YOUR TURN';
      case _Phase.practice: return 'SAY IT OUT LOUD';
      case _Phase.judge:    return 'CLOSING';
      case _Phase.done:     return 'LESSON COMPLETE';
      case _Phase.error:    return 'LINE DROPPED';
    }
  }
}

// ─── Pieces ─────────────────────────────────────────────────────────────

class _TargetLineCard extends StatelessWidget {
  final String line;
  final String cue;
  final bool showCue;
  final bool isUserTurn;
  const _TargetLineCard({
    required this.line,
    required this.cue,
    required this.showCue,
    required this.isUserTurn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUserTurn ? AppColors.accent : AppColors.accentBorder,
          width: isUserTurn ? 1.4 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGlow.withValues(
                alpha: isUserTurn ? 0.35 : 0.18),
            blurRadius: 28,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isUserTurn ? 'SAY THIS' : 'THE LINE',
              style: AppTypography.label.copyWith(
                color: AppColors.accent,
                fontSize: 10,
                letterSpacing: 2.8,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 10),
          Text('"$line"',
              style: AppTypography.h1Italic.copyWith(
                color: Colors.white,
                fontSize: 22,
                height: 1.35,
                fontStyle: FontStyle.italic,
              )),
          if (showCue) ...[
            const SizedBox(height: 14),
            Container(height: 0.5, color: AppColors.divider),
            const SizedBox(height: 10),
            Text(cue,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                )),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06, end: 0);
  }
}

class _PracticeCountdown extends StatelessWidget {
  final int elapsed;
  final int total;
  const _PracticeCountdown({required this.elapsed, required this.total});

  @override
  Widget build(BuildContext context) {
    final remaining = (total - elapsed).clamp(0, total);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.accentBorder, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0,
                minHeight: 3,
                backgroundColor: AppColors.surface3,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('$remaining s',
              style: AppTypography.label.copyWith(
                color: AppColors.accent,
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
              )),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  const _ModeChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.accentBorder, width: 0.8),
      ),
      child: Text(label,
          style: AppTypography.label.copyWith(
            color: AppColors.accent,
            fontSize: 10,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w900,
          )),
    );
  }
}

class _PauseButton extends StatelessWidget {
  final bool paused;
  final VoidCallback onTap;
  const _PauseButton({required this.paused, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: paused ? 'Resume' : 'Pause',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44, height: 44,
          alignment: Alignment.center,
          child: Icon(
            paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: AppColors.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _DoneCTA extends StatelessWidget {
  final VoidCallback onTap;
  const _DoneCTA({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 60),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
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
    );
  }
}
