import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/dev_flags.dart';
import '../../models/gaze/gaze_lesson.dart';
import '../../models/gaze/gaze_syllabus.dart';
import '../../models/presence/presence_lesson.dart';
import '../../models/presence/presence_syllabus.dart';
import '../../services/gaze/gaze_progress_store.dart';
import '../../services/local_store_service.dart';
import '../../services/presence/presence_progress_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/mirrorly_components.dart';
import 'eyes_session_screen.dart';
import 'voice/eyes_voice_session_screen.dart';

/// EYES — two parts.
///
///   1. EYE CONTACT          — Pure gaze training. The face mesh,
///                             MediaPipe scoring, blink count, Lucien
///                             narrating the move. Existing eyes
///                             session screen.
///
///   2. EYE CONTACT + VOICE  — The hard one. You deliver a line WHILE
///                             holding the gaze. Camera + mic at the
///                             same time. Lucien narrates each line;
///                             you say it; the engine scores both
///                             your gaze and that you spoke.
class EyesTabScreen extends StatefulWidget {
  const EyesTabScreen({super.key});

  @override
  State<EyesTabScreen> createState() => _EyesTabScreenState();
}

class _EyesTabScreenState extends State<EyesTabScreen> {
  late Future<GazeLesson>     _nextGaze;
  late Future<PresenceLesson> _nextPresence;
  late Future<int>            _completedTotal;

  // Paywall entitlement state. `_pro` true ⇒ everything unlocked,
  // unlimited. Free users get one eye-contact lesson (Part One);
  // Part Two (Eye Contact + Voice) is pro-only. `_loaded` gates the
  // locked visual so a paying user never sees a lock flash on launch.
  bool _pro       = false;
  bool _eyesUsed  = false;
  bool _loaded    = false;

  @override
  void initState() {
    super.initState();
    _nextGaze       = _pickNextGaze();
    _nextPresence   = _pickNextPresence();
    _completedTotal = _countCompletedTotal();
    _loadEntitlements();
  }

  Future<int> _countCompletedTotal() async {
    final g = await GazeProgressStore.completedCount();
    final p = await PresenceProgressStore.completedCount();
    return g + p;
  }

  Future<void> _loadEntitlements() async {
    final pro      = kBypassPaywall ? true : await LocalStoreService.isSubscribed();
    final eyesUsed = await LocalStoreService.eyesFreeUsed();
    if (!mounted) return;
    setState(() {
      _pro      = pro;
      _eyesUsed = eyesUsed;
      _loaded   = true;
    });
  }

  Future<GazeLesson> _pickNextGaze() async {
    for (final l in GazeSyllabus.all) {
      final best = await GazeProgressStore.bestFor(l.id);
      if (best == null || best == 0) return l;
    }
    return GazeSyllabus.all.first;
  }

  Future<PresenceLesson> _pickNextPresence() async {
    for (final l in PresenceSyllabus.all) {
      final best = await PresenceProgressStore.bestFor(l.id);
      if (best == null || best == 0) return l;
    }
    return PresenceSyllabus.all.first;
  }

  Future<void> _reload() async {
    setState(() {
      _nextGaze       = _pickNextGaze();
      _nextPresence   = _pickNextPresence();
      _completedTotal = _countCompletedTotal();
    });
    _loadEntitlements();
  }

  // ── Paywall gating ────────────────────────────────────────────────
  // Part One (Eye Contact): pro = unlimited; free = exactly one lesson
  // (consumed on open), then paywall. Browsing the full library is
  // pro-only. Part Two (Eye Contact + Voice) is pro-only outright.
  bool get _eyeContactLocked => _loaded && !_pro && _eyesUsed;
  bool get _voiceLocked      => _loaded && !_pro;

  Future<void> _toPaywall() async {
    await context.push('/paywall');
    if (!mounted) return;
    _loadEntitlements();
  }

  Future<void> _onEyeContactBegin(GazeLesson l) async {
    if (_pro) { _openGaze(l); return; }
    if (!_eyesUsed) {
      await LocalStoreService.markEyesFreeUsed();
      if (!mounted) return;
      setState(() => _eyesUsed = true);
      _openGaze(l);
      return;
    }
    _toPaywall();
  }

  void _onEyeContactBrowse() {
    if (_pro) { _pickGaze(); return; }
    _toPaywall();          // full library is pro-only
  }

  void _onVoiceBegin(PresenceLesson l) {
    if (_pro) { _openVoice(l); return; }
    _toPaywall();
  }

  Future<void> _openGaze(GazeLesson l) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => EyesSessionScreen(lesson: l)),
    );
    _reload();
  }

  Future<void> _openVoice(PresenceLesson l) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => EyesVoiceSessionScreen(lesson: l)),
    );
    _reload();
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Sp.xxl),
          children: [
            // ── Masthead — EYES. + thesis + tune action.
            MirrorlyMasthead(
              title: 'Eyes.',
              subtitle: 'Two parts. Gaze first. Voice next.',
              actions: [
                MastheadAction(
                  icon: Icons.tune,
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),

            const SizedBox(height: Sp.lg),

            // ── Progress strip — "00 / 10 LESSONS · 0%" with a thin red bar.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
              child: FutureBuilder<int>(
                future: _completedTotal,
                builder: (_, snap) {
                  final done  = snap.data ?? 0;
                  final total = GazeSyllabus.all.length +
                                PresenceSyllabus.all.length;
                  return _ProgressStrip(done: done, total: total);
                },
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: Sp.lg),

            // ── Hook line — the close, just above the cards.
            const HookLine(
              'The man who breaks first loses. Train the eyes she actually meets.',
              emphasised: true,
            ).animate().fadeIn(delay: 80.ms, duration: 400.ms),

            const SizedBox(height: Sp.lg),

            // ── PART ONE — Eye Contact (gaze training).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
              child: FutureBuilder<GazeLesson>(
                future: _nextGaze,
                builder: (_, snap) {
                  final l        = snap.data ?? GazeSyllabus.all.first;
                  final upcoming = GazeSyllabus.all
                      .where((g) => g.id != l.id)
                      .take(3)
                      .toList();
                  final extra = math.max(0,
                      GazeSyllabus.all.length - 1 - upcoming.length);
                  return CharacterCard(
                    eyebrow: 'Part one',
                    title: 'Eye Contact',
                    body:
                        'Pure gaze training. Hold her eyes. Don\'t break first.',
                    assetPath: MirrorlyAssets.gazeNeutral,
                    locked: _eyeContactLocked,
                    inlinePanel: LessonListPanel(
                      rows: [
                        _rowFor(l.number, l.name),
                        for (final u in upcoming) _rowFor(u.number, u.name),
                      ],
                      currentSubtitle: l.oneLine,
                      currentCta: _eyeContactLocked ? 'Locked' : 'Start Lesson',
                      currentLocked: _eyeContactLocked,
                      onStart: () => _onEyeContactBegin(l),
                      extraCount: extra,
                    ),
                    footer: _BrowseButton(
                      label: 'See all ${GazeSyllabus.all.length} eye moves',
                      onTap: _onEyeContactBrowse,
                    ),
                  );
                },
              ),
            ).animate().fadeIn(delay: 160.ms, duration: 400.ms),

            const SizedBox(height: Sp.lg),

            // ── PART TWO — Eye Contact + Voice (Lucien's room).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
              child: FutureBuilder<PresenceLesson>(
                future: _nextPresence,
                builder: (_, snap) {
                  final l = snap.data ?? PresenceSyllabus.all.first;
                  return CharacterCard(
                    eyebrow: 'Part two',
                    title: 'Eye Contact + Voice',
                    body:
                        'Lock her gaze. Deliver the line. Don\'t blink, '
                        'don\'t shrink, don\'t apologise. Lucien reads it '
                        'once — then it\'s on you.',
                    assetPath: MirrorlyAssets.lucienSpeaking,
                    locked: _voiceLocked,
                    footer: PrimaryCta(
                      label: _voiceLocked ? 'Unlock With Pro' : 'Start Lesson',
                      icon: _voiceLocked
                          ? null
                          : Icons.play_arrow_rounded,
                      locked: _voiceLocked,
                      onTap: () => _onVoiceBegin(l),
                    ),
                  );
                },
              ),
            ).animate().fadeIn(delay: 240.ms, duration: 400.ms),

            const SizedBox(height: Sp.lg),
          ],
        ),
      ),
    );
  }

  LessonRowSpec _rowFor(int number, String name) => LessonRowSpec(
        label: 'Lesson ${number.toString().padLeft(2, '0')}',
        title: name,
      );

  /// Bottom-sheet picker — every move in the curriculum, pick any one.
  Future<void> _pickGaze() async {
    final l = await _showMovePicker(
      title:   'The Gaze · Choose a move',
      lessons: [
        for (final g in GazeSyllabus.all)
          (number: g.number, name: g.name, oneLine: g.oneLine),
      ],
    );
    if (l != null && mounted) _openGaze(GazeSyllabus.all[l]);
  }

  Future<int?> _showMovePicker({
    required String title,
    required List<({int number, String name, String oneLine})> lessons,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.base,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.82,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text(
                    title.toUpperCase(),
                    style: AppTypography.label.copyWith(
                      color: AppColors.red,
                      fontSize: 11,
                      letterSpacing: 2.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: lessons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final l = lessons[i];
                      return Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => Navigator.of(ctx).pop(i),
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              color: AppColors.surface1,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.surface3, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  l.number.toString().padLeft(2, '0'),
                                  style: GoogleFonts.playfairDisplay(
                                    color: AppColors.red,
                                    fontSize: 22,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.name.toUpperCase(),
                                        style: AppTypography.label.copyWith(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          letterSpacing: 1.8,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l.oneLine,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.red,
                                          fontSize: 12.5,
                                          height: 1.35,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: AppColors.red, size: 18),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Progress strip ─────────────────────────────────────────────────
// "00 / NN LESSONS  ────────  0%". Same visual as the mockup top band.

class _ProgressStrip extends StatelessWidget {
  final int done;
  final int total;
  const _ProgressStrip({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? done / total : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(Rd.lg),
        border: Border.all(color: AppColors.surface3, width: 1),
      ),
      child: Row(
        children: [
          Text(
            '${done.toString().padLeft(2, '0')} / $total LESSONS',
            style: AppTypography.label.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 3,
                backgroundColor: AppColors.surface3,
                valueColor: const AlwaysStoppedAnimation(AppColors.red),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${(ratio * 100).round()}%',
            style: AppTypography.label.copyWith(
              color: AppColors.red,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Browse button ─────────────────────────────────────────────────
// "See all 10 eye moves ↗" — sits in the Part 1 card footer.

class _BrowseButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _BrowseButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rd.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded,
                  size: 14, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
