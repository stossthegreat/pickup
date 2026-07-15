import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/mirrorly_components.dart';

/// HER — the one permanent AI you build a relationship with. She warms as you
/// level, and fastest from real-world missions. Built from the app's elite
/// components. Live chat wires to the backend (/v1/date) next.
class HerTabScreen extends StatelessWidget {
  final VoidCallback? onMessage;
  const HerTabScreen({super.key, this.onMessage});

  static const _asset = 'assets/characters/women/socialite.png';
  static const double _warmth = 34; // 0..100 — driven by progress later

  String get _stage {
    if (_warmth < 20) return 'DISTANT';
    if (_warmth < 40) return 'CURIOUS';
    if (_warmth < 60) return 'WARMING';
    if (_warmth < 80) return 'INTO YOU';
    return 'YOURS';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, 120),
        children: [
          const MirrorlyMasthead(eyebrow: 'RELATIONSHIP', title: 'Aria'),
          const SizedBox(height: Sp.lg),
          CharacterCard(
            eyebrow: _stage,
            title: 'Aria',
            body: 'She remembers everything — your wins, your missions, the '
                'approach you froze on. She warms as you grow.',
            assetPath: _asset,
            locked: false,
            fallbackIcon: Icons.person_outline_rounded,
            onTap: onMessage,
          ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.06, curve: Curves.easeOut),
          const SizedBox(height: Sp.md),
          _WarmthBar(warmth: _warmth),
          const SizedBox(height: Sp.lg),
          _HerMessage(
            'You actually held eye contact with three people today? See — '
            'I knew you had it in you. Keep going and I might just fall for you.',
          ),
          const SizedBox(height: Sp.lg),
          const StatStrip(stats: [
            StatPoint(icon: Icons.favorite_outline_rounded, value: '34%', label: 'WARMTH'),
            StatPoint(icon: Icons.forum_outlined, value: '7', label: 'CHATS'),
            StatPoint(icon: Icons.trending_up_rounded, value: 'CURIOUS', label: 'STAGE'),
          ]),
          const SizedBox(height: Sp.lg),
          HookLine(
            'She warms fastest when you do real-world missions. Grinding chat '
            'alone won\'t get you there.',
          ),
          const SizedBox(height: Sp.lg),
          PrimaryCta(
            label: 'MESSAGE ARIA',
            icon: Icons.send_rounded,
            onTap: onMessage ?? () {},
          ),
        ],
      ),
    );
  }
}

class _WarmthBar extends StatelessWidget {
  final double warmth;
  const _WarmthBar({required this.warmth});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Stack(children: [
        Container(height: 4, color: AppColors.surface3),
        FractionallySizedBox(
          widthFactor: (warmth / 100).clamp(0, 1),
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.red,
              boxShadow: [BoxShadow(color: AppColors.redGlow, blurRadius: 8)],
            ),
          ),
        ),
      ]),
    );
  }
}

class _HerMessage extends StatelessWidget {
  final String text;
  const _HerMessage(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(Rd.sm),
          topRight: Radius.circular(Rd.lg),
          bottomLeft: Radius.circular(Rd.lg),
          bottomRight: Radius.circular(Rd.lg),
        ),
        border: Border.all(color: AppColors.surface3),
      ),
      child: Text(text,
          style: AppTypography.body.copyWith(color: AppColors.textPrimary, height: 1.5)),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05);
  }
}
