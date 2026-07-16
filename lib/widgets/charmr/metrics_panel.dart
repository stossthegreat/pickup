import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// The five scored dimensions of game + a weighted total. Charmr's progress
/// metrics — replaces the old im-him composite score on the Progress tab.
class MetricsPanel extends StatelessWidget {
  /// 0..100 each, in order: Confidence, Presence, Humor, Listening, Game.
  final List<double> values;
  const MetricsPanel({super.key, this.values = const [62, 48, 71, 55, 60]});

  static const _rows = <(String glyph, String label, Color color)>[
    ('⚡', 'Confidence', AppColors.red),
    ('◉', 'Presence', AppColors.measure),
    ('☺', 'Humor', AppColors.signalAmber),
    ('●', 'Listening', AppColors.signalGreen),
    ('♠', 'Game', AppColors.accent),
  ];

  double get _total {
    const w = [1.15, 1.0, 0.95, 0.95, 1.15];
    double s = 0, ws = 0;
    for (var i = 0; i < values.length && i < w.length; i++) {
      s += values[i] * w[i];
      ws += w[i];
    }
    return ws == 0 ? 0 : s / ws;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sp.md + 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface2, AppColors.surface1],
        ),
        borderRadius: BorderRadius.circular(Rd.xl),
        border: Border.all(color: AppColors.surface3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 14, height: 1, color: AppColors.red),
              const SizedBox(width: 8),
              Text('THE FIVE', style: AppTypography.label),
              const Spacer(),
              Text('TOTAL ', style: AppTypography.label),
              Text(_total.toStringAsFixed(0),
                  style: AppTypography.measurement
                      .copyWith(color: AppColors.red, fontSize: 15)),
              Text(' /100',
                  style: AppTypography.label.copyWith(color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: Sp.md),
          for (var i = 0; i < _rows.length; i++)
            _bar(_rows[i].$1, _rows[i].$2, _rows[i].$3,
                i < values.length ? values[i] : 0),
        ],
      ),
    );
  }

  Widget _bar(String glyph, String label, Color color, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('$glyph  ', style: TextStyle(fontSize: 12, color: color)),
            Expanded(
              child: Text(label.toUpperCase(),
                  style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary, letterSpacing: 1.6)),
            ),
            Text(value.toStringAsFixed(0),
                style: AppTypography.measurement.copyWith(color: color, fontSize: 13)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(children: [
              Container(height: 3, color: AppColors.surface3),
              LayoutBuilder(
                builder: (_, c) => Container(
                  height: 3,
                  width: c.maxWidth * (value / 100).clamp(0, 1),
                  decoration: BoxDecoration(
                    color: color,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
