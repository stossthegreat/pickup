import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/scan_record.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/mirrorly_components.dart';

/// ASCEND — the home tab. One screen, one daily ritual.
class AscendScreen extends StatelessWidget {
  /// Switch the bottom-nav to a specific tab.
  final ValueChanged<int> onJumpToTab;

  /// Latest scan, if any. Drives whether the Potential card unlocks.
  final ScanRecord? latest;

  final int dayStreak;
  final int looksScore;
  final int auraScore;
  final int gameScore;

  const AscendScreen({
    super.key,
    required this.onJumpToTab,
    this.latest,
    this.dayStreak = 0,
    this.looksScore = 0,
    this.auraScore = 0,
    this.gameScore = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasScan = latest != null;
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Sp.xl),
          children: [
            // ── Masthead — streak chip is now an ACTION, top right,
            //    next to settings. Tappable → opens the streaks sheet.
            MirrorlyMasthead(
              title: 'Mirrorly',
              subtitle: 'Ascend',
              actions: [
                _StreakAction(
                  days: dayStreak,
                  onTap: () => _showStreaks(context),
                ),
                MastheadAction(
                  icon: Icons.tune,
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),

            const SizedBox(height: Sp.md),

            // ── Three pillar score cards. A touch bigger than before
            //    (they're the hero). LOOKS / AURA / GAME, each /10,
            //    zero until the user uses that pillar.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
              child: Row(
                children: [
                  Expanded(child: _PillarScore(
                    label: 'LOOKS',
                    score: looksScore,
                    color: AppColors.red,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _PillarScore(
                    label: 'AURA',
                    score: auraScore,
                    color: AppColors.accent,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _PillarScore(
                    label: 'GAME',
                    score: gameScore,
                    color: AppColors.signalAmber,
                  )),
                ],
              ),
            ),

            const SizedBox(height: Sp.md),

            // ── Today's Ascension — 3 missions with a hitting tagline.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
              child: _TodaysAscension(
                onJumpToTab: onJumpToTab,
                hasScan: hasScan,
              ),
            ).animate().fadeIn(delay: 120.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  void _showStreaks(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.base,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _StreaksSheet(
        looks: looksScore,
        aura:  auraScore,
        game:  gameScore,
        days:  dayStreak,
      ),
    );
  }
}

// ─── Streak action (top-right of masthead) ────────────────────────
// Compact pill: flame + day count, tap-to-open the streaks sheet.

class _StreakAction extends StatelessWidget {
  final int days;
  final VoidCallback onTap;
  const _StreakAction({required this.days, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final live = days > 0;
    final color = live ? AppColors.red : AppColors.textTertiary;
    return InkWell(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.50), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department_rounded, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              '$days',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pillar score card (a touch bigger than before) ──────────────

class _PillarScore extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  const _PillarScore({
    required this.label,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final live = score > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(Rd.lg),
        border: Border.all(
            color: live ? color.withOpacity(0.55) : AppColors.surface3,
            width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: color,
              fontSize: 11,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$score',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: live ? color : AppColors.textPrimary,
                    height: 1.0,
                    letterSpacing: -0.8,
                  ),
                ),
                TextSpan(
                  text: ' / 10',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    height: 1.0,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Today's Ascension — 3 missions + hitting tagline + pulsing CTA

class _TodaysAscension extends StatelessWidget {
  final ValueChanged<int> onJumpToTab;
  final bool hasScan;
  const _TodaysAscension({
    required this.onJumpToTab,
    required this.hasScan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(Rd.xl),
        border: Border.all(color: AppColors.surface3, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TODAY\'S ASCENSION',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              Text(
                '0 / 3',
                style: AppTypography.label.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Looks. Aura. Game. Become unavoidable.',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              color: AppColors.red,
              letterSpacing: 0.1,
              height: 1.35,
            ),
          ),
          const SizedBox(height: Sp.md),
          // ── LOOKS mission — pre-scan it's literally "scan your face."
          //    Once the user has a scan, swap to the real mog routine.
          _MissionRow(
            color: AppColors.red,
            icon: hasScan
                ? Icons.face_retouching_natural_outlined
                : Icons.center_focus_strong_rounded,
            category: 'LOOKS',
            title: hasScan ? 'Mog Streak' : 'Scan your face',
            minutes: hasScan ? 3 : 1,
            onTap: () {
              if (hasScan) {
                onJumpToTab(1);
              } else {
                // Route straight to the scan flow — same handler the
                // Looks tab "Begin Face Scan" CTA uses.
                context.push('/scan');
              }
            },
          ),
          const _MissionDivider(),
          _MissionRow(
            color: AppColors.accent,
            icon: Icons.remove_red_eye_outlined,
            category: 'AURA',
            title: 'Eye Contact Drill',
            minutes: 5,
            onTap: () => onJumpToTab(2),
          ),
          const _MissionDivider(),
          _MissionRow(
            color: AppColors.signalAmber,
            icon: Icons.chat_bubble_outline_rounded,
            category: 'GAME',
            title: 'Free Flow',
            minutes: 3,
            onTap: () => onJumpToTab(3),
          ),
        ],
      ),
    );
  }
}

class _MissionDivider extends StatelessWidget {
  const _MissionDivider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.surface3,
          margin: const EdgeInsets.symmetric(vertical: 2));
}

class _MissionRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String category;
  final String title;
  final int minutes;
  final VoidCallback onTap;
  const _MissionRow({
    required this.color,
    required this.icon,
    required this.category,
    required this.title,
    required this.minutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      borderRadius: BorderRadius.circular(Rd.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.45), width: 1),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: AppTypography.label.copyWith(
                      color: color,
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$minutes MIN',
              style: AppTypography.label.copyWith(
                color: AppColors.textTertiary,
                fontSize: 9.5,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            // Pulsing chase arrow — gives every mission row life.
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.6),
              ),
              child: Icon(Icons.arrow_forward_rounded, color: color, size: 15),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.10, 1.10),
                duration: 1100.ms,
                curve: Curves.easeInOut,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Streaks sheet — the "sick streaks" awards modal ─────────────
// Tap the streak pill in the masthead → this comes up. Lists every
// named streak the user can earn: pillar streaks (Mog / Aura /
// Charisma) plus combo streaks (Untouchable, Predator, Elite).
// Designed to feel like trophies — the user wants them.

class _StreaksSheet extends StatelessWidget {
  final int looks;
  final int aura;
  final int game;
  final int days;
  const _StreaksSheet({
    required this.looks,
    required this.aura,
    required this.game,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Sp.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STREAKS',
                    style: AppTypography.label.copyWith(
                      color: AppColors.red,
                      fontSize: 11,
                      letterSpacing: 3.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Earn them all. Become untouchable.',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.md),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Sp.lg, 0, Sp.lg, Sp.lg),
                children: [
                  _StreakAward(
                    icon: Icons.face_retouching_natural_outlined,
                    color: AppColors.red,
                    name: 'MOG STREAK',
                    body: 'Scan + Looks routine every day.',
                    progress: looks,
                    target: 7,
                  ),
                  const SizedBox(height: 10),
                  _StreakAward(
                    icon: Icons.remove_red_eye_outlined,
                    color: AppColors.accent,
                    name: 'AURA STREAK',
                    body: 'One Eye Contact drill every day.',
                    progress: aura,
                    target: 7,
                  ),
                  const SizedBox(height: 10),
                  _StreakAward(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: AppColors.signalAmber,
                    name: 'CHARISMA STREAK',
                    body: 'One Free Flow conversation every day.',
                    progress: game,
                    target: 7,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'COMBO STREAKS',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StreakAward(
                    icon: Icons.bolt_rounded,
                    color: AppColors.red,
                    name: 'UNTOUCHABLE',
                    body: 'All three pillars, seven days running.',
                    progress: days,
                    target: 7,
                  ),
                  const SizedBox(height: 10),
                  _StreakAward(
                    icon: Icons.workspace_premium_rounded,
                    color: AppColors.textPrimary,
                    name: 'PREDATOR',
                    body: 'Thirty days. No skips.',
                    progress: days,
                    target: 30,
                  ),
                  const SizedBox(height: 10),
                  _StreakAward(
                    icon: Icons.diamond_outlined,
                    color: AppColors.textPrimary,
                    name: 'ELITE',
                    body: 'A hundred days. Cult status.',
                    progress: days,
                    target: 100,
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

class _StreakAward extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final String body;
  final int progress;
  final int target;
  const _StreakAward({
    required this.icon,
    required this.color,
    required this.name,
    required this.body,
    required this.progress,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final earned = progress >= target;
    final ratio  = target == 0 ? 0.0
                                : (progress / target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(Rd.lg),
        border: Border.all(
            color: earned ? color : AppColors.surface3,
            width: earned ? 1.4 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(earned ? 0.20 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: color.withOpacity(earned ? 0.85 : 0.35),
                  width: 1),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: AppTypography.label.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      earned ? 'EARNED' : '$progress / $target',
                      style: AppTypography.label.copyWith(
                        color: earned ? color : AppColors.textTertiary,
                        fontSize: 10.5,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 3,
                    backgroundColor: AppColors.surface3,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
