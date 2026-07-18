import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/ascension_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// THE ASCENSION MAP — the spine of the app.
///
/// A vertical path of the seven rank nodes (Observer → Become Him), Day 1 at
/// the top winding down to Day 60. The user's earned day marks their position:
/// nodes behind them are lit and banked, the node ahead shows a partial fill
/// and exactly what it unlocks, and everything past it is locked.
///
/// Every feature in the app plugs into this: finishing a mission moves you
/// forward, bosses live at the 10-day nodes, unlocks appear on the node that
/// grants them. The map doesn't compete with those systems — it gives them a
/// home and makes "Become Him" a place you can see yourself walking toward.
class AscensionMap extends StatelessWidget {
  /// Earned ascension day, 1..60 (StreakService — days you actually showed up).
  final int day;

  /// Fires when the user taps the CONTINUE call-to-action under the map —
  /// wired to jump to the Missions tab so the map is the front door to today.
  final VoidCallback? onContinue;

  const AscensionMap({super.key, required this.day, this.onContinue});

  /// Escalating heat ramp, one colour per node. Green cool start → red danger
  /// → indigo/violet → gold finale, so the climb visibly warms as it rises.
  static const List<Color> _rankColors = [
    Color(0xFF4ADE80), // Observer  — green
    Color(0xFFFBBF24), // Initiate  — amber
    Color(0xFFFB923C), // Contender — orange
    Color(0xFFE8222A), // Dangerous — red (brand)
    Color(0xFF8B94F5), // Him       — indigo
    Color(0xFFA855F7), // Elite     — violet
    Color(0xFFFFC94D), // Become Him— gold
  ];

  static const List<IconData> _rankIcons = [
    Icons.visibility_rounded,      // Observer
    Icons.local_fire_department_rounded, // Initiate
    Icons.bolt_rounded,            // Contender
    Icons.whatshot_rounded,        // Dangerous
    Icons.workspace_premium_rounded, // Him
    Icons.diamond_rounded,         // Elite
    Icons.emoji_events_rounded,    // Become Him
  ];

  @override
  Widget build(BuildContext context) {
    final ranks = AscensionService.ranks();
    final total = AscensionService.totalDays;
    final d = day.clamp(1, total);

    // Index of the highest rank reached (current band), and the next target.
    int reachedIdx = 0;
    for (var i = 0; i < ranks.length; i++) {
      if (d >= ranks[i].minDay) reachedIdx = i;
    }
    final targetIdx = reachedIdx < ranks.length - 1 ? reachedIdx + 1 : -1;

    final currentRank = ranks[reachedIdx];
    final daysToNext =
        targetIdx == -1 ? 0 : (ranks[targetIdx].minDay - d).clamp(0, total);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header — names the surface + where you stand right now. ──
          Row(
            children: [
              Text('THE ASCENSION',
                  style: AppTypography.label.copyWith(
                    color: AppColors.red,
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                  )),
              const Spacer(),
              Text('DAY $d / $total',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Text('${currentRank.label}  ·  BECOME HIM',
              style: AppTypography.h3.copyWith(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              )),
          const SizedBox(height: 16),

          // ── The path. ──
          for (var i = 0; i < ranks.length; i++)
            _MapNode(
              rank: ranks[i],
              color: _rankColors[i],
              icon: _rankIcons[i],
              isFirst: i == 0,
              isLast: i == ranks.length - 1,
              reached: d >= ranks[i].minDay,
              isCurrent: i == reachedIdx,
            ),

          const SizedBox(height: 6),

          // ── The nudge + CTA — "X days to the next unlock". This is the
          //    dopamine line: it names exactly what's a few days away. ──
          if (targetIdx != -1)
            _NextUnlockBar(
              daysToNext: daysToNext,
              nextLabel: ranks[targetIdx].label,
              unlock: ranks[targetIdx].unlock,
              color: _rankColors[targetIdx],
              onContinue: onContinue,
            )
          else
            _FinalReachedBar(onContinue: onContinue),
        ],
      ),
    );
  }
}

/// One node + the line segment feeding into it from above.
class _MapNode extends StatelessWidget {
  final AscendRank rank;
  final Color color;
  final IconData icon;
  final bool isFirst;
  final bool isLast;
  final bool reached;
  final bool isCurrent;

  const _MapNode({
    required this.rank,
    required this.color,
    required this.icon,
    required this.isFirst,
    required this.isLast,
    required this.reached,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final badge = _badge();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left rail: connecting line + node badge. ──
          SizedBox(
            width: 44,
            child: Column(
              children: [
                // The rail is lit through every reached node and muted after,
                // so the path visibly fills up to where you stand. The exact
                // "% to next" lives in the CLIMB bar below the map.
                Expanded(
                  child: isFirst
                      ? const SizedBox(width: 3)
                      : _Line(lit: reached, color: color),
                ),
                badge,
                Expanded(
                  child: isLast
                      ? const SizedBox(width: 3)
                      : _Line(lit: reached, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // ── Right: the rank content. ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 2),
              child: _content(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge() {
    final dim = !reached;
    final ring = dim ? AppColors.surface3 : color;
    final fill = reached ? color.withValues(alpha: 0.18) : AppColors.surface2;
    final core = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: ring, width: 2),
        boxShadow: reached
            ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12)]
            : null,
      ),
      child: Icon(
        reached ? icon : Icons.lock_rounded,
        size: 18,
        color: reached ? color : AppColors.textTertiary,
      ),
    );
    if (isCurrent) {
      // Gentle pulse on the node you're standing on. (The badge already
      // carries a static glow via its BoxDecoration.)
      return core
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1.0, end: 1.12, duration: 900.ms, curve: Curves.easeInOut);
    }
    return core;
  }

  Widget _content() {
    final dim = !reached;
    final labelColor = dim ? AppColors.textTertiary : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('DAY ${rank.minDay}',
                style: AppTypography.label.copyWith(
                  color: dim ? AppColors.textMuted : color,
                  fontSize: 9.5,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                )),
            if (isCurrent) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: color.withValues(alpha: 0.6), width: 0.8),
                ),
                child: Text('YOU ARE HERE',
                    style: AppTypography.label.copyWith(
                      color: color,
                      fontSize: 8,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w900,
                    )),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(rank.label,
            style: AppTypography.h3.copyWith(
              color: labelColor,
              fontSize: 17,
              height: 1.05,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 3),
        Text(rank.tagline,
            style: AppTypography.bodySmall.copyWith(
              color: dim ? AppColors.textMuted : AppColors.textSecondary,
              fontSize: 11.5,
              height: 1.3,
            )),
        if (rank.unlock.isNotEmpty) ...[
          const SizedBox(height: 7),
          _UnlockChip(text: rank.unlock, color: color, reached: reached),
        ],
      ],
    );
  }
}

/// A vertical connector segment — lit (rank colour) once you've reached the
/// node it feeds, muted grey until then.
class _Line extends StatelessWidget {
  final bool lit;
  final Color color;
  const _Line({required this.lit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 3,
        decoration: BoxDecoration(
          color: lit ? color : AppColors.surface3,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// The "what opens here" pill under each rank.
class _UnlockChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool reached;
  const _UnlockChip({required this.text, required this.color, required this.reached});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: reached ? color.withValues(alpha: 0.10) : AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: reached ? color.withValues(alpha: 0.35) : AppColors.surface3,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(reached ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 11,
              color: reached ? color : AppColors.textTertiary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                style: AppTypography.bodySmall.copyWith(
                  color: reached ? AppColors.textSecondary : AppColors.textTertiary,
                  fontSize: 10.5,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }
}

/// The dopamine bar under the path — "3 DAYS to CONTENDER · what unlocks".
class _NextUnlockBar extends StatelessWidget {
  final int daysToNext;
  final String nextLabel;
  final String unlock;
  final Color color;
  final VoidCallback? onContinue;
  const _NextUnlockBar({
    required this.daysToNext,
    required this.nextLabel,
    required this.unlock,
    required this.color,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final dayWord = daysToNext == 1 ? 'DAY' : 'DAYS';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onContinue,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.04)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: AppTypography.label.copyWith(
                          fontSize: 12.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w900,
                        ),
                        children: [
                          TextSpan(text: '$daysToNext $dayWord ',
                              style: TextStyle(color: color)),
                          TextSpan(text: 'TO $nextLabel',
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(unlock,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.25,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onContinue != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text('CLIMB',
                          style: AppTypography.label.copyWith(
                            color: Colors.black,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w900,
                          )),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 14, color: Colors.black),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown once the user has reached Day 60 — the summit.
class _FinalReachedBar extends StatelessWidget {
  final VoidCallback? onContinue;
  const _FinalReachedBar({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC94D);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gold.withValues(alpha: 0.18), gold.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: gold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text('You reached the summit. You are Him.',
                style: AppTypography.h3.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                )),
          ),
        ],
      ),
    );
  }
}
