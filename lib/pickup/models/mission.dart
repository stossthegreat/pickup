import 'metrics.dart';

/// Two kinds of mission. Roleplay = in-app scored scenes (endless, laddered).
/// RealWorld = exposure-style action challenges, the differentiator. Both
/// pour XP into the same Aura Level, but RealWorld pays far more.
enum MissionKind { roleplay, realWorld }

/// Difficulty tier — drives XP and the card's edge treatment.
enum MissionTier { warmup, standard, bold, elite }

extension MissionTierMeta on MissionTier {
  String get label => switch (this) {
        MissionTier.warmup => 'WARM-UP',
        MissionTier.standard => 'STANDARD',
        MissionTier.bold => 'BOLD',
        MissionTier.elite => 'ELITE',
      };
}

class Mission {
  final String id;
  final MissionKind kind;
  final MissionTier tier;
  final String title;
  final String subtitle;
  final int xp;
  final int unlockLevel;

  /// For roleplay missions: which character + which single skill is scored.
  final String? characterId;
  final Metric? focus;

  const Mission({
    required this.id,
    required this.kind,
    required this.tier,
    required this.title,
    required this.subtitle,
    required this.xp,
    this.unlockLevel = 1,
    this.characterId,
    this.focus,
  });

  bool get isRealWorld => kind == MissionKind.realWorld;
}
