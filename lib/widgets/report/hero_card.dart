import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// The hero moment. One screen. Six words. The screenshot that gets posted.
///
/// `82` · `THE MONARCH` · `TOP 14%` · `+14 MAX`
///
/// Counter animates 0 → score over 1.6s (variable reward — the reveal).
/// Archetype fades in +400ms. Percentile + potential pills pop last with
/// scale overshoot so they land with impact.
class HeroCard extends StatefulWidget {
  final int score;
  final String archetype;
  final int percentile; // e.g. 14 for "TOP 14%"
  final int potentialDelta; // e.g. 14 for "+14 MAX"

  const HeroCard({
    super.key,
    required this.score,
    required this.archetype,
    required this.percentile,
    required this.potentialDelta,
  });

  @override
  State<HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<HeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _counter;

  @override
  void initState() {
    super.initState();
    _counter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
      ..forward();
  }

  @override
  void dispose() {
    _counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.lg, 48, Sp.lg, 28),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.1,
          colors: [
            AppColors.gold.withValues(alpha: 0.18),
            const Color(0xFF0A0A0A),
          ],
        ),
        borderRadius: BorderRadius.circular(Rd.xxl),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.35), width: 0.9),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _counter,
            builder: (_, __) {
              final t = Curves.easeOutExpo.transform(_counter.value);
              final shown = (t * widget.score).round();
              return Text(
                '$shown',
                style: AppTypography.display.copyWith(
                  fontSize: 132,
                  height: 0.95,
                  letterSpacing: -5,
                  color: AppColors.gold,
                  shadows: [
                    Shadow(color: AppColors.gold.withValues(alpha: 0.45),
                      blurRadius: 28),
                  ],
                  fontStyle: FontStyle.italic,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Container(height: 1, width: 72, color: AppColors.gold.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(widget.archetype,
            style: AppTypography.label.copyWith(
              color: AppColors.textPrimary,
              fontSize: 19, letterSpacing: 5.2,
              fontWeight: FontWeight.w900))
            .animate().fadeIn(delay: 400.ms, duration: 500.ms)
            .slideY(begin: 0.3, end: 0, delay: 400.ms, duration: 500.ms,
              curve: Curves.easeOut),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pill(
                label: 'TOP ${widget.percentile}%',
                accent: AppColors.gold,
                delay: 1100,
              ),
              const SizedBox(width: 10),
              _pill(
                label: '+${widget.potentialDelta} POTENTIAL',
                accent: AppColors.signalGreen,
                delay: 1300,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill({required String label, required Color accent, required int delay}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.7), width: 0.8),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label,
        style: AppTypography.label.copyWith(
          color: accent,
          fontSize: 11, letterSpacing: 2.4,
          fontWeight: FontWeight.w900)),
    ).animate(
      onInit: (c) => c.forward(),
    ).fadeIn(
      delay: Duration(milliseconds: delay),
      duration: 400.ms,
    ).scaleXY(
      begin: 0.8,
      end: 1.0,
      delay: Duration(milliseconds: delay),
      duration: 400.ms,
      curve: Curves.elasticOut,
    );
  }
}
