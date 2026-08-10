import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// The Academy's chrome, matched 1:1 to the app's existing mission
/// cards — because the app already had a beautiful language and the
/// new surfaces were speaking a different one.
///
/// The house style: Playfair italic headings, soft gradient cards with
/// a low-opacity accent border and a dropped shadow, small tracked
/// accent pills, and 62pt portrait thumbs with a coloured rim.

/// Editorial section heading — "Today's Mission" energy.
class AcademyHeading extends StatelessWidget {
  final String title;
  final String? kicker; // small tracked label above
  final String? sub; // red italic line under
  final double size;
  const AcademyHeading(
      {super.key, required this.title, this.kicker, this.sub, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (kicker != null) ...[
        Text(kicker!, style: AppTypography.label),
        const SizedBox(height: 6),
      ],
      Text(title, style: AppTypography.h1Italic.copyWith(fontSize: size)),
      if (sub != null) ...[
        const SizedBox(height: 4),
        Text(sub!,
            style: GoogleFonts.inter(
              color: AppColors.red,
              fontSize: 14,
              height: 1.35,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            )),
      ],
    ]);
  }
}

/// The house card — same gradient, border and shadow as a mission card.
class AcademyCard extends StatelessWidget {
  final Widget child;
  final Color accent;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// Lift the accent (used for the live/urgent card of the moment).
  final bool hot;

  const AcademyCard({
    super.key,
    required this.child,
    this.accent = AppColors.accent,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.hot = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface2, AppColors.surface1],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: accent.withValues(alpha: hot ? 0.5 : 0.22)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8)),
          if (hot)
            BoxShadow(
                color: accent.withValues(alpha: 0.18), blurRadius: 26),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: card,
      ),
    );
  }
}

/// Small tracked accent pill — "AI · POST", "TIER 2", "DROP ZONE".
class AcademyPill extends StatelessWidget {
  final String label;
  final Color accent;
  final IconData? icon;
  const AcademyPill(
      {super.key, required this.label, required this.accent, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 10, color: accent),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: AppTypography.label
                .copyWith(color: accent, fontSize: 8.5, letterSpacing: 1.4)),
      ]),
    );
  }
}

/// 62pt portrait thumb with a rimmed glow — the app's signature object.
class AcademyThumb extends StatelessWidget {
  final String? asset;
  final Color accent;
  final IconData fallbackIcon;
  final double size;
  const AcademyThumb({
    super.key,
    required this.asset,
    required this.accent,
    this.fallbackIcon = Icons.person_rounded,
    this.size = 62,
  });

  @override
  Widget build(BuildContext context) {
    if (asset == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.22),
              accent.withValues(alpha: 0.06)
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Icon(fallbackIcon, color: accent, size: size * 0.42),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 10)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(asset!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                color: AppColors.surface3,
                child: Icon(fallbackIcon, color: accent))),
      ),
    );
  }
}
