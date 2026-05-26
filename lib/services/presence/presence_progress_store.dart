import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/presence/presence_lesson.dart';

/// Per-lesson best score + capped attempt history for the Presence
/// curriculum. Drives the progress band on the Eyes tab and the
/// improvement deltas on the share card.
abstract final class PresenceProgressStore {
  static const _historyKey = 'presence_history';
  static const int _historyCap = 100;

  /// Persist this attempt and update the per-lesson best if this
  /// charisma score is higher than what was stored. Returns the
  /// previous best (or null on first attempt).
  static Future<int?> record(PresenceResult r) async {
    final sp = await SharedPreferences.getInstance();

    int? prevBest;
    final prevRaw = sp.getString(_bestKey(r.lessonId));
    if (prevRaw != null) {
      try {
        final m = jsonDecode(prevRaw) as Map<String, dynamic>;
        prevBest = (m['score'] as num?)?.toInt();
      } catch (_) {}
    }

    if (prevBest == null || r.charisma > prevBest) {
      await sp.setString(_bestKey(r.lessonId), jsonEncode({
        'score': r.charisma,
        'ts':    r.timestampMs,
      }));
    }

    final hist = await _readHistory();
    hist.insert(0, r);
    if (hist.length > _historyCap) {
      hist.removeRange(_historyCap, hist.length);
    }
    await sp.setString(
        _historyKey, jsonEncode(hist.map((h) => h.toJson()).toList()));

    return prevBest;
  }

  static Future<int?> bestFor(String lessonId) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_bestKey(lessonId));
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return (m['score'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  static Future<int> completedCount() async {
    int n = 0;
    final sp = await SharedPreferences.getInstance();
    for (final k in sp.getKeys()) {
      if (k.startsWith('presence_best_')) {
        final raw = sp.getString(k);
        if (raw == null) continue;
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          if (((m['score'] as num?) ?? 0) > 0) n++;
        } catch (_) {}
      }
    }
    return n;
  }

  /// "This week vs the previous week" delta in average charisma
  /// score across all Presence drills. Returns null when there isn't
  /// enough history to compute.
  static Future<int?> weeklyImprovement() async {
    final hist = await _readHistory();
    if (hist.isEmpty) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    const weekMs = 7 * 24 * 60 * 60 * 1000;
    final thisWeek = hist
        .where((r) => now - r.timestampMs < weekMs)
        .map((r) => r.charisma)
        .toList();
    final lastWeek = hist
        .where((r) {
          final age = now - r.timestampMs;
          return age >= weekMs && age < 2 * weekMs;
        })
        .map((r) => r.charisma)
        .toList();
    if (thisWeek.isEmpty || lastWeek.isEmpty) return null;
    final thisAvg = thisWeek.reduce((a, b) => a + b) / thisWeek.length;
    final lastAvg = lastWeek.reduce((a, b) => a + b) / lastWeek.length;
    return (thisAvg - lastAvg).round();
  }

  static Future<List<PresenceResult>> _readHistory() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_historyKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => PresenceResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String _bestKey(String lessonId) => 'presence_best_$lessonId';
}
