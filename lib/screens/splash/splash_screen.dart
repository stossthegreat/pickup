import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) context.go('/scan');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo mark
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1.5),
                color: AppColors.surface2,
              ),
              child: Center(
                child: Text('M',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    letterSpacing: -1,
                  )),
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(begin: const Offset(0.85, 0.85), duration: 500.ms, curve: Curves.easeOut),

            const SizedBox(height: 20),

            Text('MIRROR',
              style: AppTypography.label.copyWith(
                color: AppColors.textPrimary, fontSize: 13, letterSpacing: 5))
            .animate().fadeIn(delay: 300.ms, duration: 400.ms),

            const SizedBox(height: 6),

            Text('Geometric facial analysis',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12, color: AppColors.textTertiary))
            .animate().fadeIn(delay: 500.ms, duration: 400.ms),

            const SizedBox(height: 48),

            // Loading line
            SizedBox(
              width: 80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: const LinearProgressIndicator(
                  backgroundColor: Color(0xFF27272A),
                  valueColor: AlwaysStoppedAnimation(AppColors.measure),
                  minHeight: 1.5,
                ),
              ),
            ).animate().fadeIn(delay: 700.ms, duration: 300.ms),
          ],
        ),
      ),
    );
  }
}
