import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-lesson completion state — score, dimension breakdown, last-played
/// timestamp. Lets the tab pages show the progress ring + the radar.
///
/// One key per curriculum so Rhetoric + Rizz progress don't collide:
///   * `progress_rhetoric` — Map<lessonId, LessonProgress>
///   * `progress_rizz`     — Map<lessonId, LessonProgress>
class LessonProgress {
  final int totalScore;                 // 0–60
  final Map<String, int> dimensions;    // dim → 0–10
  final int lastPlayedMs;               // epoch ms

  const LessonProgress({
    required this.totalScore,
    required this.dimensions,
    required this.lastPlayedMs,
  });

  bool get isComplete => totalScore > 0;

  Map<String, dynamic> toJson() => {
        'totalScore': totalScore,
        'dimensions': dimensions,
        'lastPlayedMs': lastPlayedMs,
      };

  factory LessonProgress.fromJson(Map<String, dynamic> j) => LessonProgress(
        totalScore: (j['totalScore'] as num?)?.toInt() ?? 0,
        dimensions: ((j['dimensions'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        lastPlayedMs: (j['lastPlayedMs'] as num?)?.toInt() ?? 0,
      );
}

enum CurriculumKey { rhetoric, rizz }

class LessonProgressStore {
  static String _storeKey(CurriculumKey c) =>
      c == CurriculumKey.rhetoric ? 'progress_rhetoric' : 'progress_rizz';

  static Future<Map<String, LessonProgress>> readAll(CurriculumKey c) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey(c));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, LessonProgress.fromJson(v as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<LessonProgress?> get(CurriculumKey c, String lessonId) async {
    final all = await readAll(c);
    return all[lessonId];
  }

  static Future<void> write(
    CurriculumKey c,
    String lessonId,
    LessonProgress p,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await readAll(c);
    all[lessonId] = p;
    final encoded = json.encode(all.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_storeKey(c), encoded);
  }

  /// Aggregate radar — average each dimension across every completed lesson.
  /// Returns an empty map if nothing has been played yet.
  static Future<Map<String, double>> dimensionAverages(CurriculumKey c) async {
    final all = await readAll(c);
    if (all.isEmpty) return {};
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final p in all.values) {
      for (final entry in p.dimensions.entries) {
        sums[entry.key] = (sums[entry.key] ?? 0) + entry.value;
        counts[entry.key] = (counts[entry.key] ?? 0) + 1;
      }
    }
    return sums.map((k, v) => MapEntry(k, v / (counts[k] ?? 1)));
  }

  /// How many lessons completed in this curriculum.
  static Future<int> completedCount(CurriculumKey c) async {
    final all = await readAll(c);
    return all.values.where((p) => p.isComplete).length;
  }
}
