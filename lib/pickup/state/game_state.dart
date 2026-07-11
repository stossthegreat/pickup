import 'package:flutter/foundation.dart';
import '../models/metrics.dart';
import '../models/mission.dart';

/// The single source of truth for progression. One number the user cares
/// about: auraLevel. Everything — roleplay, missions, real-world — pours XP
/// here. Frontend-first: state is in-memory and seeded; the backend swap is
/// a later step (persist + sync).
class GameState extends ChangeNotifier {
  int xp = 2140;
  int streakDays = 4;
  MetricSet metrics = MetricSet.seed();
  final Set<String> _completed = {};

  // Her — the relationship warmth, 0..100, gated by level. Rises as you grow.
  double herWarmth = 18;

  bool isDone(String missionId) => _completed.contains(missionId);

  // ── Aura Level curve ────────────────────────────────────────────────────
  // Gentle early, steep late. xpForLevel(n) = total XP needed to REACH n.
  static int xpForLevel(int level) => (60 * (level - 1) * level / 2).round();

  int get auraLevel {
    var l = 1;
    while (xp >= xpForLevel(l + 1) && l < 100) {
      l++;
    }
    return l;
  }

  int get xpIntoLevel => xp - xpForLevel(auraLevel);
  int get xpForNextLevel => xpForLevel(auraLevel + 1) - xpForLevel(auraLevel);
  double get levelProgress =>
      xpForNextLevel == 0 ? 1 : (xpIntoLevel / xpForNextLevel).clamp(0, 1);

  /// The rank name shown under the number — real-world tiers are the top.
  String get rankTitle {
    final l = auraLevel;
    if (l < 10) return 'GHOST';
    if (l < 20) return 'ROOKIE';
    if (l < 35) return 'CONTENDER';
    if (l < 50) return 'OPERATOR';
    if (l < 70) return 'CLOSER';
    if (l < 90) return 'MENACE';
    return 'LEGEND';
  }

  double get totalScore => metrics.total;

  bool isLocked(int unlockLevel) => auraLevel < unlockLevel;

  // ── Mutations ───────────────────────────────────────────────────────────

  /// Award a roleplay/mission result. deltas nudge the metrics; xp lifts level.
  void awardResult({
    required int gainedXp,
    Map<Metric, double> deltas = const {},
    String? completeMissionId,
    bool realWorld = false,
  }) {
    final before = auraLevel;
    xp += gainedXp;
    if (deltas.isNotEmpty) metrics = metrics.bump(deltas);
    if (completeMissionId != null) _completed.add(completeMissionId);
    // Real-world action warms Her the most — the attachment engine rewards
    // real growth, not couch grinding.
    herWarmth = (herWarmth + (realWorld ? 6 : 2)).clamp(0, 100);
    lastLevelUp = auraLevel > before ? auraLevel : null;
    notifyListeners();
  }

  /// Non-null for one read after a level-up, so screens can celebrate.
  int? lastLevelUp;

  void completeMission(Mission m, {Map<Metric, double>? deltas}) {
    awardResult(
      gainedXp: m.xp,
      deltas: deltas ??
          (m.focus != null ? {m.focus!: 6.0} : const {}),
      completeMissionId: m.id,
      realWorld: m.isRealWorld,
    );
  }
}
