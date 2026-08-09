import 'dart:ui';

import '../../theme/app_colors.dart';

/// The ladder — the same five rungs the paywall promises (OBSERVER →
/// HIM) made real as live ELO tiers. The promise they bought is the
/// ladder they climb.
class RizzTier {
  final String name;
  final int min; // inclusive rating floor
  final Color color;
  final bool glow; // top tiers render with a glow shadow
  const RizzTier(this.name, this.min, this.color, {this.glow = false});
}

/// Neon reserved for the summit (matches the paywall's HIM pulse).
const kNeon = Color(0xFF2EE87A);

const List<RizzTier> kTiers = [
  RizzTier('OBSERVER',   0,    AppColors.textTertiary),
  RizzTier('INITIATE',   1100, AppColors.textPrimary),
  RizzTier('CONTENDER',  1300, AppColors.red),
  RizzTier('DANGEROUS',  1600, AppColors.red, glow: true),
  RizzTier('HIM',        1900, kNeon, glow: true),
];

RizzTier tierFor(int rating) {
  var t = kTiers.first;
  for (final tier in kTiers) {
    if (rating >= tier.min) t = tier;
  }
  return t;
}

/// Next tier above [rating], or null at the summit.
RizzTier? nextTier(int rating) {
  for (final tier in kTiers) {
    if (rating < tier.min) return tier;
  }
  return null;
}

/// 0..1 progress from the current tier floor to the next tier floor.
double tierProgress(int rating) {
  final cur = tierFor(rating);
  final next = nextTier(rating);
  if (next == null) return 1;
  return ((rating - cur.min) / (next.min - cur.min)).clamp(0.0, 1.0);
}
