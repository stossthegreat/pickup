import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/standing.dart';
import '../../services/streak_service.dart';
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


/// RANK — the second of the two pills, and the one that broke.
///
/// THE BUG. This used to print `tierFor(rizz_elo.rating).name`, which
/// meant a man read INITIATE on Home while every ascension surface in
/// the app still called him OBSERVER. Both were right. The app had three
/// ladders sharing five words, and rizz_elo.rating — the thing driving
/// this one — moves up to ±40 on every solo voice session, so two good
/// dailies promoted his identity. Ten days of work and two lucky
/// conversations produced the same word.
///
/// THE FIX. RANK is now EARNED DAYS and nothing else: ten days a rung,
/// OBSERVER → BECOME HIM, the same ladder the paywall sells and the
/// 60-day map draws. It cannot be rushed, it cannot jump, and it agrees
/// with every other screen because there is now exactly one source for
/// it. See standing.dart for the full table of who owns what.
///
/// The rating that used to live here hasn't gone anywhere — it's the
/// battle DIVISION, on the Battles screen, in its own vocabulary
/// (BRONZE III → LEGEND I) so the two can never be confused again.
class RankBadge extends StatefulWidget {
  const RankBadge({super.key});

  @override
  State<RankBadge> createState() => _RankBadgeState();
}

class _RankBadgeState extends State<RankBadge> {
  int _days = 0;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    final snap = await StreakService.progress();
    if (mounted) setState(() => _days = snap.ascensionDay);
  }

  /// Gold is RANK's colour and RANK's alone — see ascend_reveal.dart.
  /// It deepens as he climbs so the pill itself is evidence.
  Color get _tone {
    final rung = Standing.rungFor(_days);
    if (rung >= 5) return const Color(0xFFFFC53D);
    if (rung >= 3) return const Color(0xFFE0A82E);
    if (rung >= 1) return AppColors.textPrimary;
    return AppColors.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final rank = Standing.rankFor(_days);
    final tone = _tone;
    final glow = Standing.rungFor(_days) >= 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: tone.withValues(alpha: 0.5), width: 0.8),
        boxShadow: glow
            ? [BoxShadow(color: tone.withValues(alpha: 0.3), blurRadius: 14)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, color: tone, size: 15),
          const SizedBox(width: 5),
          Text(rank.label,
              style: GoogleFonts.inter(
                color: tone,
                fontSize: 13,
                height: 1,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w800,
              )),
          if (_days > 0) ...[
            const SizedBox(width: 6),
            // The day count, because RANK is days. Printing the unit
            // beside the word is what stops him wondering where it came
            // from — which is the entire failure this pill is fixing.
            Text('D$_days',
                style: GoogleFonts.inter(
                  color: tone.withValues(alpha: 0.75),
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
