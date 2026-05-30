import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// ASCEND — the home tab. One destination, one daily ritual.
///
/// Replaces the old five-tab sprawl (Scan / Mirror / Eyes / Game /
/// Progress) with a single dashboard the user comes back to every
/// day: streak + level chips at the top, the potential gap + trait
/// improvements as the hero, three daily missions (one per pillar:
/// Looks, Presence, Game), and a "focus" card driving the highest-
/// ROI fix.
///
/// The point: every man's goal is the same — get more girls. Looks
/// open the door, game keeps her in the room. Mirrorly is the
/// system. Ascend is where you check in.
///
/// Numbers + missions are mocked for now (build-time defaults). Wire
/// real streak / level / per-pillar score / mission-of-the-day data
/// in once the home shape is approved.
class AscendScreen extends StatelessWidget {
  /// Switch the bottom-nav to a specific tab. Wired from HomeScreen
  /// so tapping a mission row jumps to the correct surface (Looks /
  /// Presence / Game).
  final ValueChanged<int> onJumpToTab;

  /// Mocked daily values until real data lands.
  final int dayStreak;
  final int level;
  final int potentialPoints;

  const AscendScreen({
    super.key,
    required this.onJumpToTab,
    this.dayStreak = 14,
    this.level = 7,
    this.potentialPoints = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Sp.xxl),
          children: [
            // ── Masthead.
            const _AscendMasthead(),

            const SizedBox(height: Sp.md),

            // ── Streak + Level chips, top right of the screen but
            //    BELOW the title (the title leans hard left; the
            //    chips need their own breathing room).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _StatChip(
                    icon: Icons.local_fire_department_rounded,
                    value: '$dayStreak',
                    label: 'DAY STREAK',
                    color: AppColors.red,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.hexagon_outlined,
                    value: '$level',
                    label: 'LEVEL',
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: Sp.lg),

            // ── Potential gap hero. Split current/best image on the
            //    right, big "+N POINTS" on the left, trait deltas
            //    listed beside the image.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
              child: _PotentialHero(points: potentialPoints),
            ).animate().fadeIn(duration: 400.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms,
                  curve: Curves.easeOut),

            const SizedBox(height: Sp.lg),

            // ── Today's Ascension — 3 missions, one per pillar.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
              child: _TodaysAscension(onJumpToTab: onJumpToTab),
            ).animate().fadeIn(delay: 160.ms, duration: 400.ms),

            const SizedBox(height: Sp.lg),

            // ── Focus card — highest-ROI fix.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
              child: _FocusCard(
                title: 'Lose Face Fat',
                pointGain: 6,
                body: 'Leaner face = stronger jawline, '
                      'more definition, more attraction.',
                onTap: () => onJumpToTab(1), // → Looks tab
              ),
            ).animate().fadeIn(delay: 240.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}

// ─── Masthead ───────────────────────────────────────────────────────
// "ASCEND" italic Playfair + three chevrons → ↑ ↑ ↑, with the
// "ATTRACTION OS" eyebrow underneath and the tagline below that.

class _AscendMasthead extends StatelessWidget {
  const _AscendMasthead();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ASCEND',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textPrimary,
                  letterSpacing: -1.4,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: _Chevrons(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'ATTRACTION OS',
            style: AppTypography.label.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10.5,
              letterSpacing: 3.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Sp.md),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
              children: const [
                TextSpan(text: 'You don\'t need luck.\n'),
                TextSpan(text: 'You need '),
                TextSpan(
                  text: 'a system',
                  style: TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chevrons extends StatelessWidget {
  const _Chevrons();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 28,
      child: Stack(
        children: const [
          Positioned(top: 0, left: 0, right: 0,
              child: Icon(Icons.keyboard_arrow_up_rounded,
                  size: 18, color: AppColors.red)),
          Positioned(top: 6, left: 0, right: 0,
              child: Icon(Icons.keyboard_arrow_up_rounded,
                  size: 18, color: AppColors.red)),
          Positioned(top: 12, left: 0, right: 0,
              child: Icon(Icons.keyboard_arrow_up_rounded,
                  size: 18, color: AppColors.red)),
        ],
      ),
    );
  }
}

// ─── Stat chip ─────────────────────────────────────────────────────
// Pill at the top right: glyph + number + label.

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: AppColors.textTertiary,
              fontSize: 9.5,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Potential hero ───────────────────────────────────────────────
// Split image of current/best face + trait deltas. Reuses the
// existing marketing assets as placeholders.

class _PotentialHero extends StatelessWidget {
  final int points;
  const _PotentialHero({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(Rd.xl),
        border: Border.all(color: AppColors.surface3, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Sp.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left: points + body + CTA
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR POTENTIAL',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                      children: [
                        TextSpan(
                          text: '+$points',
                          style: const TextStyle(
                            fontSize: 38,
                            color: AppColors.red,
                            letterSpacing: -1.8,
                          ),
                        ),
                        TextSpan(
                          text: ' POINTS',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sp.md),
                  Text(
                    'You\'re leaving points on the table. We fix that.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: Sp.md),
                  _SeeTransformationButton(),
                ],
              ),
            ),

            const SizedBox(width: Sp.md),

            // ── Right: trait improvements + view-plan link
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  _TraitDelta(
                      icon: Icons.face_retouching_natural_outlined,
                      label: 'JAWLINE',
                      delta: 4),
                  SizedBox(height: 8),
                  _TraitDelta(
                      icon: Icons.face_outlined,
                      label: 'FACE FAT',
                      delta: 6),
                  SizedBox(height: 8),
                  _TraitDelta(
                      icon: Icons.brightness_5_outlined,
                      label: 'SKIN',
                      delta: 3),
                  SizedBox(height: 8),
                  _TraitDelta(
                      icon: Icons.accessibility_new_rounded,
                      label: 'POSTURE',
                      delta: 2),
                  SizedBox(height: 8),
                  _TraitDelta(
                      icon: Icons.content_cut_rounded,
                      label: 'HAIR',
                      delta: 3),
                  SizedBox(height: 12),
                  Text(
                    'TAP TO VIEW PLAN',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: AppColors.red,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
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

class _SeeTransformationButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surface3, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SEE TRANSFORMATION',
            style: AppTypography.label.copyWith(
              color: AppColors.textPrimary,
              fontSize: 9.5,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_rounded,
              size: 12, color: AppColors.red),
        ],
      ),
    );
  }
}

class _TraitDelta extends StatelessWidget {
  final IconData icon;
  final String label;
  final int delta;
  const _TraitDelta({
    required this.icon,
    required this.label,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: AppColors.textSecondary,
            fontSize: 10,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '+$delta',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.red,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ─── Today's Ascension ──────────────────────────────────────────
// Section title + three mission rows + a CONTINUE ASCENSION CTA.
// One row per pillar (Looks / Presence / Game). Each row carries its
// own status: ✓ done, → next, 🔒 not unlocked yet. Tapping a row
// jumps to that tab.

class _TodaysAscension extends StatelessWidget {
  final ValueChanged<int> onJumpToTab;
  const _TodaysAscension({required this.onJumpToTab});

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
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              Text(
                '1 / 3 COMPLETE',
                style: AppTypography.label.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '3 MISSIONS. 15 MINUTES. ZERO EXCUSES.',
            style: AppTypography.label.copyWith(
              color: AppColors.textTertiary,
              fontSize: 9.5,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Sp.md),
          _MissionRow(
            color: AppColors.red,
            icon: Icons.face_retouching_natural_outlined,
            category: 'LOOKS',
            title: 'Jaw Posture',
            minutes: 3,
            state: _MissionState.done,
            onTap: () => onJumpToTab(1),
          ),
          const _MissionDivider(),
          _MissionRow(
            color: AppColors.accent,
            icon: Icons.remove_red_eye_outlined,
            category: 'PRESENCE',
            title: 'Eye Contact Drill',
            minutes: 5,
            state: _MissionState.current,
            onTap: () => onJumpToTab(2),
          ),
          const _MissionDivider(),
          _MissionRow(
            color: AppColors.signalAmber,
            icon: Icons.chat_bubble_outline_rounded,
            category: 'GAME',
            title: 'Ice Queen Challenge',
            minutes: 7,
            state: _MissionState.locked,
            onTap: () => onJumpToTab(3),
          ),
          const SizedBox(height: Sp.md),
          _ContinueAscensionButton(
            onTap: () => onJumpToTab(2), // → next incomplete
          ),
        ],
      ),
    );
  }
}

enum _MissionState { done, current, locked }

class _MissionDivider extends StatelessWidget {
  const _MissionDivider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.surface3,
          margin: const EdgeInsets.symmetric(vertical: 4));
}

class _MissionRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String category;
  final String title;
  final int minutes;
  final _MissionState state;
  final VoidCallback onTap;
  const _MissionRow({
    required this.color,
    required this.icon,
    required this.category,
    required this.title,
    required this.minutes,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      borderRadius: BorderRadius.circular(Rd.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // ── Coloured glyph tile
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.45), width: 1),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            // ── Label + title + duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: AppTypography.label.copyWith(
                      color: color,
                      fontSize: 10.5,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 11, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        '$minutes MIN',
                        style: AppTypography.label.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Status glyph (done / current / locked)
            _MissionStatusGlyph(state: state, color: color),
          ],
        ),
      ),
    );
  }
}

class _MissionStatusGlyph extends StatelessWidget {
  final _MissionState state;
  final Color color;
  const _MissionStatusGlyph({required this.state, required this.color});

  @override
  Widget build(BuildContext context) {
    final (icon, fg, bg, border) = switch (state) {
      _MissionState.done => (
          Icons.check_rounded,
          color,
          Colors.transparent,
          color,
        ),
      _MissionState.current => (
          Icons.arrow_forward_rounded,
          color,
          Colors.transparent,
          color,
        ),
      _MissionState.locked => (
          Icons.lock_rounded,
          AppColors.textTertiary,
          Colors.transparent,
          AppColors.surface3,
        ),
    };
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
      ),
      child: Icon(icon, color: fg, size: 18),
    );
  }
}

class _ContinueAscensionButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ContinueAscensionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () { HapticFeedback.mediumImpact(); onTap(); },
      borderRadius: BorderRadius.circular(Rd.lg),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(Rd.lg),
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withOpacity(0.35),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'CONTINUE ASCENSION',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.black, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Focus card ────────────────────────────────────────────────────
// Big-ROI fix for the week. Title + pill + body + before/after thumbs
// + view-plan CTA.

class _FocusCard extends StatelessWidget {
  final String title;
  final int pointGain;
  final String body;
  final VoidCallback onTap;
  const _FocusCard({
    required this.title,
    required this.pointGain,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      borderRadius: BorderRadius.circular(Rd.xl),
      child: Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(Rd.xl),
          border: Border.all(color: AppColors.surface3, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left column.
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FOCUS',
                    style: AppTypography.label.copyWith(
                      color: AppColors.red,
                      fontSize: 10.5,
                      letterSpacing: 2.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.red.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.red.withOpacity(0.55),
                              width: 1),
                        ),
                        child: Text(
                          'HIGHEST ROI',
                          style: AppTypography.label.copyWith(
                            color: AppColors.red,
                            fontSize: 9,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+$pointGain POINTS',
                        style: AppTypography.label.copyWith(
                          color: AppColors.red,
                          fontSize: 10,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Sp.md),
                  Text(
                    body,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: Sp.md),
                  Row(
                    children: [
                      Text(
                        'VIEW FULL PLAN',
                        style: AppTypography.label.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 12, color: AppColors.red),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Sp.md),
            // ── Right: before / after thumbs (reuses marketing assets).
            Expanded(
              flex: 5,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _BeforeAfterThumb(
                      asset: 'assets/marketing/before.jpg',
                      label: 'NOW',
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: AppColors.red),
                  ),
                  Expanded(
                    child: _BeforeAfterThumb(
                      asset: 'assets/marketing/after.jpg',
                      label: 'GOAL',
                      labelColor: AppColors.red,
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

class _BeforeAfterThumb extends StatelessWidget {
  final String asset;
  final String label;
  final Color labelColor;
  const _BeforeAfterThumb({
    required this.asset,
    required this.label,
    this.labelColor = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.2),
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surface1,
                alignment: Alignment.center,
                child: const Icon(Icons.face_outlined,
                    size: 24, color: AppColors.surface3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: labelColor,
            fontSize: 9.5,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
