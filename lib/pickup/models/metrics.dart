import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// The five scored dimensions of game. Every roleplay turn, mission, and
/// Bro cut-in nudges these. Their weighted blend is the Total Score, which
/// drives the Aura Level. Real-world action is scored separately and weighs
/// the heaviest — you cannot max out from the couch.
enum Metric { confidence, presence, humor, listening, game }

extension MetricMeta on Metric {
  String get label => switch (this) {
        Metric.confidence => 'Confidence',
        Metric.presence => 'Presence',
        Metric.humor => 'Humor',
        Metric.listening => 'Listening',
        Metric.game => 'Game',
      };

  String get glyph => switch (this) {
        Metric.confidence => '⚡', // ⚡
        Metric.presence => '◉', // ◉
        Metric.humor => '☺', // ☺
        Metric.listening => '●', // ●
        Metric.game => '♠', // ♠
      };

  Color get color => switch (this) {
        Metric.confidence => AppColors.red,
        Metric.presence => AppColors.measure,
        Metric.humor => AppColors.signalAmber,
        Metric.listening => AppColors.signalGreen,
        Metric.game => AppColors.accent,
      };

  String get blurb => switch (this) {
        Metric.confidence => 'Holding your frame under pressure.',
        Metric.presence => 'Eye contact, tonality, taking up space.',
        Metric.humor => 'Wit, teasing, push-pull.',
        Metric.listening => 'Reading her, catching the thread.',
        Metric.game => 'Calibration, timing, the close.',
      };
}

/// A 0–100 score per metric, held as doubles so small increments read.
class MetricSet {
  final Map<Metric, double> values;
  const MetricSet(this.values);

  factory MetricSet.seed() => const MetricSet({
        Metric.confidence: 34,
        Metric.presence: 28,
        Metric.humor: 41,
        Metric.listening: 22,
        Metric.game: 30,
      });

  double get(Metric m) => values[m] ?? 0;

  /// Weighted total — Game and Confidence carry more; this is the number
  /// on the profile hero.
  double get total {
    const w = {
      Metric.confidence: 1.15,
      Metric.presence: 1.0,
      Metric.humor: 0.95,
      Metric.listening: 0.95,
      Metric.game: 1.15,
    };
    double sum = 0, wsum = 0;
    for (final m in Metric.values) {
      sum += get(m) * w[m]!;
      wsum += w[m]!;
    }
    return sum / wsum;
  }

  MetricSet bump(Map<Metric, double> deltas) {
    final next = Map<Metric, double>.from(values);
    deltas.forEach((m, d) {
      next[m] = ((next[m] ?? 0) + d).clamp(0, 100);
    });
    return MetricSet(next);
  }
}
