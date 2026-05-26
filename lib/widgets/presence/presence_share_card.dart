import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/presence/presence_lesson.dart';
import '../../services/share_service.dart';
import '../../theme/auralay_app_colors.dart';
import '../../theme/auralay_app_typography.dart';

/// PRESENCE — full-screen share card.
///
/// Mirrors GazeShareCard structurally so the two curriculums feel
/// like siblings, but with PRESENCE's seven dimensions and the
/// "IMPOSSIBLE TO IGNORE" badge family. Headline number is the
/// CHARISMA composite, /100. Below it: voice authority, pace,
/// confidence, eye contact, warmth, tension. Then the transcript of
/// what was heard, then the fatal-flaw line in Lucien's voice.
class PresenceShareCard extends StatelessWidget {
  final PresenceResult result;
  final int? previousBest;
  final int? weeklyDelta;

  final VoidCallback onAgain;
  final VoidCallback onNext;
  final VoidCallback onClose;

  const PresenceShareCard({
    super.key,
    required this.result,
    required this.previousBest,
    required this.weeklyDelta,
    required this.onAgain,
    required this.onNext,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Scored out of 10 (internally 0–100).
    final score = (result.charisma / 10).round().clamp(0, 10).toInt();
    final prev10 = previousBest == null ? null : (previousBest! / 10).round();
    final isNewBest = prev10 == null || score > prev10;
    final delta = prev10 == null ? null : (score - prev10);

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.35),
                      radius: 0.95,
                      colors: [
                        AppColors.accent.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 6, right: 10,
              child: _IconButton(icon: Icons.close_rounded, onTap: onClose),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(22, 56, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('PRESENCE',
                      style: AppTypography.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 11,
                        letterSpacing: 3.6,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 8),
                  Text(
                    'LESSON ${result.lessonNumber.toString().padLeft(2, "0")}  ·  ${result.lessonName}',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      letterSpacing: 2.6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 26),

                  Center(
                    child: _ScoreHero(
                      score:     score,
                      isNewBest: isNewBest,
                      delta:     delta,
                    ),
                  ),

                  const SizedBox(height: 14),
                  Center(child: _BadgePill(badge: result.badge)),
                  const SizedBox(height: 24),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _DimRow(
                            label: 'VOICE AUTHORITY',
                            pct: result.dimPct(PresenceDimension.voiceAuthority),
                          ),
                          _DimRow(
                            label: 'PACE',
                            pct: result.dimPct(PresenceDimension.pace),
                            note: '${result.wpm} WPM',
                          ),
                          _DimRow(
                            label: 'CONFIDENCE',
                            pct: result.dimPct(PresenceDimension.confidence),
                          ),
                          _DimRow(
                            label: 'EYE CONTACT',
                            pct: result.dimPct(PresenceDimension.eyeContact),
                          ),
                          _DimRow(
                            label: 'WARMTH',
                            pct: result.dimPct(PresenceDimension.warmth),
                          ),
                          _DimRow(
                            label: 'TENSION',
                            pct: result.dimPct(PresenceDimension.tension),
                          ),

                          const SizedBox(height: 18),
                          Container(height: 0.5, color: AppColors.divider),
                          const SizedBox(height: 14),

                          // Transcript — what Whisper actually heard.
                          if (result.transcript.isNotEmpty) ...[
                            Text('WHAT HE HEARD',
                                style: AppTypography.label.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 9.5,
                                  letterSpacing: 2.4,
                                  fontWeight: FontWeight.w900,
                                )),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              child: SelectableText(
                                '"${result.transcript}"',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 13.5,
                                  height: 1.45,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Fatal flaw — Lucien's stamped one-liner.
                          if (result.fatalFlaw.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6),
                              child: Text('"${result.fatalFlaw}"',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.h1Italic.copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    height: 1.45,
                                    fontStyle: FontStyle.italic,
                                  )),
                            ),
                            const SizedBox(height: 6),
                            Text('— LUCIEN',
                                style: AppTypography.label.copyWith(
                                  color: AppColors.accent,
                                  fontSize: 10,
                                  letterSpacing: 3,
                                  fontWeight: FontWeight.w900,
                                )),
                          ],

                          if (weeklyDelta != null) ...[
                            const SizedBox(height: 18),
                            _WeeklyChip(delta: weeklyDelta!),
                          ],

                          const SizedBox(height: 22),
                        ],
                      ),
                    ),
                  ),

                  _PillButton(
                    label: 'SHARE',
                    filled: true,
                    onTap: () => ShareService.shareScore(
                      context:   context,
                      kindLabel: 'EYE CONTACT + VOICE',
                      subLabel:  result.lessonName,
                      score:     score,
                      badge:     result.badge,
                      verdict:   result.fatalFlaw,
                      stats: [
                        (label: 'VOICE',      score: (result.dimPct(PresenceDimension.voiceAuthority) / 10).round()),
                        (label: 'CONFIDENCE', score: (result.dimPct(PresenceDimension.confidence) / 10).round()),
                        (label: 'PACE',       score: (result.dimPct(PresenceDimension.pace) / 10).round()),
                        (label: 'EYE CONTACT',score: (result.dimPct(PresenceDimension.eyeContact) / 10).round()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _PillButton(
                        label: 'AGAIN', filled: false, onTap: onAgain)),
                      const SizedBox(width: 10),
                      Expanded(child: _PillButton(
                        label: 'NEXT', filled: false, onTap: onNext)),
                    ],
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

class _ScoreHero extends StatelessWidget {
  final int score;
  final bool isNewBest;
  final int? delta;
  const _ScoreHero({
    required this.score,
    required this.isNewBest,
    required this.delta,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('CHARISMA',
            style: AppTypography.label.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10,
              letterSpacing: 3,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(score.toString(),
                style: AppTypography.display.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 110,
                  height: 1.0,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -4,
                )),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text('/ 10',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 14,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  )),
            ),
          ],
        ),
        if (delta != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              delta! > 0
                  ? '+$delta vs last attempt'
                  : (delta! < 0
                      ? '$delta vs last attempt'
                      : 'matched your last attempt'),
              style: AppTypography.label.copyWith(
                color: delta! > 0
                    ? AppColors.signalGreen
                    : (delta! < 0
                        ? AppColors.accent
                        : AppColors.textSecondary),
                fontSize: 11,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        if (isNewBest && delta != null && delta! > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('NEW BEST',
                style: AppTypography.label.copyWith(
                  color: AppColors.signalGreen,
                  fontSize: 10.5,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                )),
          ),
      ],
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String badge;
  const _BadgePill({required this.badge});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.accentBorder, width: 0.8),
      ),
      child: Text(badge,
          style: AppTypography.label.copyWith(
            color: AppColors.accent,
            fontSize: 12.5,
            letterSpacing: 3.2,
            fontWeight: FontWeight.w900,
          )),
    );
  }
}

class _DimRow extends StatelessWidget {
  final String label;
  final int    pct;
  final String? note;
  const _DimRow({required this.label, required this.pct, this.note});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 10.5,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                )),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (pct / 100.0).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppColors.surface3,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 42,
            child: Text('${(pct / 10).round()}',
                textAlign: TextAlign.right,
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w900,
                )),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(note!,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 9.5,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  )),
            ),
        ],
      ),
    );
  }
}

class _WeeklyChip extends StatelessWidget {
  final int delta;
  const _WeeklyChip({required this.delta});
  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    final color = positive ? AppColors.signalGreen : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.8),
      ),
      child: Text(
        positive ? '+$delta this week' : '$delta this week',
        style: AppTypography.label.copyWith(
          color: color,
          fontSize: 11,
          letterSpacing: 2.2,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool   filled;
  final VoidCallback onTap;
  const _PillButton({
    required this.label, required this.filled, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () { HapticFeedback.lightImpact(); onTap(); },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? AppColors.accent : AppColors.surface1,
            borderRadius: BorderRadius.circular(12),
            border: filled
                ? null
                : Border.all(color: AppColors.accentBorder, width: 0.8),
          ),
          child: Text(label,
              style: AppTypography.label.copyWith(
                color: filled ? Colors.white : AppColors.accent,
                fontSize: 12,
                letterSpacing: 3,
                fontWeight: FontWeight.w900,
              )),
        ),
      ),
    );
  }
}

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
        onTap: () { HapticFeedback.lightImpact(); onTap(); },
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
