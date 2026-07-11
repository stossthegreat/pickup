import '../models/mission.dart';
import '../models/metrics.dart';

/// Today's slate. In production this rotates daily off the backend; here it's
/// a hand-tuned seed that shows the mix: roleplay reps + the real-world ladder.
abstract final class Missions {
  static const today = <Mission>[
    // ── Real-world: the hero, the differentiator ──────────────────────────
    Mission(
      id: 'rw_eyes3',
      kind: MissionKind.realWorld,
      tier: MissionTier.warmup,
      title: 'Hold eye contact with 3 strangers',
      subtitle: 'One second longer than feels comfortable. Then look away calm.',
      xp: 120,
      unlockLevel: 1,
    ),
    Mission(
      id: 'rw_compliment',
      kind: MissionKind.realWorld,
      tier: MissionTier.standard,
      title: 'Give one genuine compliment out loud',
      subtitle: 'Something specific, not looks. To a stranger. No agenda.',
      xp: 200,
      unlockLevel: 3,
    ),
    Mission(
      id: 'rw_open',
      kind: MissionKind.realWorld,
      tier: MissionTier.bold,
      title: 'Start one conversation with someone new',
      subtitle: 'Twenty seconds. That\'s the whole mission. Report back after.',
      xp: 350,
      unlockLevel: 6,
    ),

    // ── Roleplay reps: endless, laddered, feed the same level ─────────────
    Mission(
      id: 'rp_ice_open',
      kind: MissionKind.roleplay,
      tier: MissionTier.warmup,
      title: 'Open the Ice Queen without a boring "hey"',
      subtitle: 'Seraphina · scored on your first move',
      xp: 80,
      characterId: 'ice_queen',
      focus: Metric.game,
      unlockLevel: 1,
    ),
    Mission(
      id: 'rp_chaos_laugh',
      kind: MissionKind.roleplay,
      tier: MissionTier.standard,
      title: 'Make the Chaos Girl laugh in 4 messages',
      subtitle: 'Nyx · scored on Humor',
      xp: 120,
      characterId: 'chaos',
      focus: Metric.humor,
      unlockLevel: 1,
    ),
    Mission(
      id: 'rp_hold_frame',
      kind: MissionKind.roleplay,
      tier: MissionTier.bold,
      title: 'She\'s testing you — hold your frame',
      subtitle: 'Seraphina · don\'t get needy · scored on Confidence',
      xp: 160,
      characterId: 'ice_queen',
      focus: Metric.confidence,
      unlockLevel: 2,
    ),
  ];
}
