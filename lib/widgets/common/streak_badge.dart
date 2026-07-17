import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
