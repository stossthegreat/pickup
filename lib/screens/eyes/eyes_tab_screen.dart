import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../models/gaze/gaze_lesson.dart';
import '../../models/gaze/gaze_syllabus.dart';
import '../../models/presence/presence_lesson.dart';
import '../../models/presence/presence_syllabus.dart';
import '../../services/gaze/gaze_progress_store.dart';
import '../../services/presence/presence_progress_store.dart';
import '../../theme/auralay_app_colors.dart';
import '../../theme/auralay_app_typography.dart';
import 'eyes_session_screen.dart';
import 'voice/eyes_voice_session_screen.dart';

/// EYES — two parts.
///
///   1. EYE CONTACT          — Pure gaze training. The face mesh,
///                             MediaPipe scoring, blink count, Diabla
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
  late Future<int>            _completedGaze;
  late Future<int>            _completedPresence;

  @override
  void initState() {
    super.initState();
    _nextGaze          = _pickNextGaze();
    _nextPresence      = _pickNextPresence();
    _completedGaze     = GazeProgressStore.completedCount();
    _completedPresence = PresenceProgressStore.completedCount();
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
      _nextGaze          = _pickNextGaze();
      _nextPresence      = _pickNextPresence();
      _completedGaze     = GazeProgressStore.completedCount();
      _completedPresence = PresenceProgressStore.completedCount();
    });
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

  /// Bottom-sheet picker — every move in the curriculum, pick any one.
  Future<void> _pickGaze() async {
    final l = await _showMovePicker(
      title:   'THE GAZE · CHOOSE A MOVE',
      lessons: [
        for (final g in GazeSyllabus.all)
          (number: g.number, name: g.name, oneLine: g.oneLine),
      ],
    );
    if (l != null && mounted) _openGaze(GazeSyllabus.all[l]);
  }

  Future<void> _pickVoice() async {
    final l = await _showMovePicker(
      title:   'EYE CONTACT + VOICE · CHOOSE A MOVE',
      lessons: [
        for (final p in PresenceSyllabus.all)
          (number: p.number, name: p.name, oneLine: p.oneLine),
      ],
    );
    if (l != null && mounted) _openVoice(PresenceSyllabus.all[l]);
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
                  child: Text(title,
                      style: AppTypography.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 11,
                        letterSpacing: 2.8,
                        fontWeight: FontWeight.w900,
                      )),
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
                                  color: AppColors.accentBorder, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                Text(l.number.toString().padLeft(2, '0'),
                                    style: AppTypography.display.copyWith(
                                      color: AppColors.accent,
                                      fontSize: 22,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w900,
                                    )),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(l.name,
                                          style: AppTypography.label.copyWith(
                                            color: AppColors.textPrimary,
                                            fontSize: 13,
                                            letterSpacing: 1.8,
                                            fontWeight: FontWeight.w900,
                                          )),
                                      const SizedBox(height: 4),
                                      Text(l.oneLine,
                                          style:
                                              AppTypography.bodySmall.copyWith(
                                            color: AppColors.accent,
                                            fontSize: 12.5,
                                            height: 1.35,
                                            fontStyle: FontStyle.italic,
                                          )),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: AppColors.accent, size: 18),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Stack(
          children: [
            // Atmospheric red halo at the top.
            Positioned(
              top: -60, left: 0, right: 0, height: 320,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.4),
                      radius: 0.9,
                      colors: [
                        AppColors.accent.withValues(alpha: 0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(onSettings: () => context.push('/settings')),
                  const _BrandHeader(),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ProgressBand(completed: _completedGaze),
                  ),
                  const SizedBox(height: 22),

                  // ── CARD 1 — Eye Contact ────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FutureBuilder<GazeLesson>(
                      future: _nextGaze,
                      builder: (_, snap) {
                        final l = snap.data ?? GazeSyllabus.all.first;
                        return _PartCard(
                          partLabel: 'PART ONE',
                          title:     'EYE CONTACT',
                          subtitle:
                              'Pure gaze training. Hold her eyes. Don\'t '
                              'break first.',
                          lessonLabel:
                              'LESSON ${l.number.toString().padLeft(2, "0")}  ·  ${l.name}',
                          lessonOneLine: l.oneLine,
                          cta:       'BEGIN',
                          primary:   true,         // both cards equal
                          browseLabel: 'SEE ALL ${GazeSyllabus.all.length} EYE MOVES',
                          onBrowse:  _pickGaze,
                          onTap:     () => _openGaze(l),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── CARD 2 — Eye Contact + Voice ────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FutureBuilder<PresenceLesson>(
                      future: _nextPresence,
                      builder: (_, snap) {
                        final l = snap.data ?? PresenceSyllabus.all.first;
                        return _PartCard(
                          partLabel: 'PART TWO',
                          title:     'EYE CONTACT + VOICE',
                          subtitle:
                              'Hold the gaze and deliver the line. Lucien '
                              'reads it once. You say it back to the '
                              'camera.',
                          lessonLabel:
                              'LESSON ${l.number.toString().padLeft(2, "0")}  ·  ${l.name}',
                          lessonOneLine: l.oneLine,
                          cta:       'BEGIN',
                          primary:   true,         // both cards equal
                          browseLabel: 'SEE ALL ${PresenceSyllabus.all.length} VOICE MOVES',
                          onBrowse:  _pickVoice,
                          onTap:     () => _openVoice(l),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 26),

                  // ── Thesis ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface1,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.divider, width: 0.6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('THE PROGRESSION',
                              style: AppTypography.label.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 9.5,
                                letterSpacing: 2.6,
                                fontWeight: FontWeight.w900,
                              )),
                          const SizedBox(height: 8),
                          Text(
                            'Master the gaze first. Then carry the gaze '
                            'through your voice. Then nobody can look '
                            'away from you.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top bar ─────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onSettings;
  const _TopBar({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 0),
      child: Row(
        children: [
          Text('EYES',
              style: AppTypography.label.copyWith(
                color: AppColors.accent,
                fontSize: 10,
                letterSpacing: 3,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(width: 6),
          Container(
            width: 4, height: 4,
            decoration: const BoxDecoration(
              color: AppColors.accent, shape: BoxShape.circle),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onSettings,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 44, height: 44,
                child: Center(
                  child: Icon(Icons.tune_rounded,
                      color: AppColors.textSecondary, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EYES.',
              style: AppTypography.display.copyWith(
                fontSize: 52,
                letterSpacing: -1.8,
                height: 0.95,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              )).animate().fadeIn(duration: 480.ms).slideY(begin: 0.04, end: 0),
          const SizedBox(height: 6),
          Text('Two parts. Gaze first. Voice next.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.accent,
                fontSize: 12.5,
                height: 1.4,
                fontStyle: FontStyle.italic,
              )).animate(delay: 120.ms).fadeIn(duration: 500.ms),
        ],
      ),
    );
  }
}

class _ProgressBand extends StatelessWidget {
  final Future<int> completed;
  const _ProgressBand({required this.completed});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: completed,
      builder: (_, snap) {
        final done = snap.data ?? 0;
        final total = GazeSyllabus.all.length;
        final ratio = total > 0 ? done / total : 0.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider, width: 0.6),
          ),
          child: Row(
            children: [
              Text(
                '${done.toString().padLeft(2, "0")} / $total LESSONS',
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5,
                  letterSpacing: 2.4,
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
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${(ratio * 100).round()}%',
                  style: AppTypography.label.copyWith(
                    color: AppColors.accent,
                    fontSize: 10.5,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                  )),
            ],
          ),
        );
      },
    );
  }
}

/// One of the two Eyes mode cards. Material+InkWell for reliable
/// tap-target — no GestureDetector-only buttons here.
class _PartCard extends StatelessWidget {
  final String partLabel;
  final String title;
  final String subtitle;
  final String lessonLabel;
  final String lessonOneLine;
  final String cta;
  final bool   primary;
  final String browseLabel;
  final VoidCallback onBrowse;
  final VoidCallback onTap;

  const _PartCard({
    required this.partLabel,
    required this.title,
    required this.subtitle,
    required this.lessonLabel,
    required this.lessonOneLine,
    required this.cta,
    required this.primary,
    required this.browseLabel,
    required this.onBrowse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(20),
            // Both cards get red borders + glow now — the user can
            // pick whichever they want; neither is the "secondary".
            // Previously Part Two looked dim/optional, which made
            // people skip it.
            border: Border.all(
              color: AppColors.accent,
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.accentGlow,
                blurRadius: 44,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(partLabel,
                      style: AppTypography.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 10,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                      )),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded,
                      color: primary
                          ? AppColors.accent
                          : AppColors.textTertiary,
                      size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: AppTypography.display.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 30,
                    letterSpacing: -1.0,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  )),
              const SizedBox(height: 10),
              Text(subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  )),
              const SizedBox(height: 16),
              Container(height: 0.5, color: AppColors.divider),
              const SizedBox(height: 12),
              Text(lessonLabel,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 6),
              Text(lessonOneLine,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.accent,
                    fontSize: 13,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  )),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: primary
                      ? AppColors.accent
                      : AppColors.surface3,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cta,
                        style: AppTypography.label.copyWith(
                          color: primary ? Colors.white : AppColors.accent,
                          fontSize: 12,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        color: primary ? Colors.white : AppColors.accent,
                        size: 16),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Browse-all button — an obvious, full-width tap target so
              // it's clear you can pick ANY move, not just the next one.
              // Its own InkWell so the tap doesn't trigger the card's
              // "begin next" onTap.
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onBrowse,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.accentBorder, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.grid_view_rounded,
                            color: AppColors.accent, size: 15),
                        const SizedBox(width: 9),
                        Text(browseLabel,
                            style: AppTypography.label.copyWith(
                              color: AppColors.accent,
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w900,
                            )),
                        const SizedBox(width: 7),
                        const Icon(Icons.expand_more_rounded,
                            color: AppColors.accent, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.04, end: 0);
  }
}
