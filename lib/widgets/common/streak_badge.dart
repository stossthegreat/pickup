import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/leaderboard_service.dart';
import '../../services/backend/tiers.dart';
import '../../services/economy.dart';
import '../../theme/app_colors.dart';

/// The clean streak flame pill — the exact look used on the Progress
/// masthead. A solid-red rounded pill with a white flame + day count and
/// a soft red glow. Shared so Missions and Progress read identically.
class StreakBadge extends StatelessWidget {
  final int days;
  const StreakBadge({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: AppColors.red.withValues(alpha: 0.45),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 5),
          Text('$days',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                height: 1,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w900,
              )),
        ],
      ),
    );
  }
}

/// XP pill — same rounded-99 silhouette as [StreakBadge] so the two sit
/// together as a set, but tinted in the accent colour instead of a solid
/// fill (XP is a running tally, not the hero streak).
class XpBadge extends StatelessWidget {
  final String label; // e.g. "2,140 XP"
  const XpBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 16),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.inter(
                color: AppColors.accent,
                fontSize: 13,
                height: 1,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w800,
              )),
        ],
      ),
    );
  }
}


/// RANK — the second of the two pills, and the other half of who he is.
///
/// A man in this app carries TWO standings and they measure different
/// things: his personal ladder (OBSERVER → HIM, moved by battles) and
/// his squad's. Both were being shown in the wrong places — the personal
/// tier was buried in the corner of the Battles card, where it read as a
/// property of battles rather than of him.
///
/// So it comes out of that card and sits next to XP, in the same pill,
/// at the same height. Two badges side by side is the whole of "who am
/// I here": what I've earned (XP) and where I stand (rank). The squad's
/// standing lives in the squad's own hero, where it belongs.
///
/// Self-loading so the masthead doesn't have to know about the ladder.
class RankBadge extends StatefulWidget {
  const RankBadge({super.key});

  @override
  State<RankBadge> createState() => _RankBadgeState();
}

class _RankBadgeState extends State<RankBadge> {
  LeaderboardEntry? _me;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    final me = await LeaderboardService.me();
    if (mounted) setState(() => _me = me);
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final tier = me == null ? kTiers.first : tierFor(me.rating);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border:
            Border.all(color: tier.color.withValues(alpha: 0.5), width: 0.8),
        boxShadow: tier.glow
            ? [BoxShadow(color: tier.color.withValues(alpha: 0.3), blurRadius: 14)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, color: tier.color, size: 15),
          const SizedBox(width: 5),
          Text(tier.name,
              style: GoogleFonts.inter(
                color: tier.color,
                fontSize: 13,
                height: 1,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w800,
              )),
          if (me != null) ...[
            const SizedBox(width: 6),
            Text(Economy.commas(me.rating),
                style: GoogleFonts.inter(
                  color: tier.color.withValues(alpha: 0.75),
                  fontSize: 11.5,
                  height: 1,
                  fontWeight: FontWeight.w900,
                )),
          ],
        ],
      ),
    );
  }
}
