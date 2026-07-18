import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../services/local_store_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/imhim_wordmark.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final onboarded = await LocalStoreService.isOnboarded();
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    // First ever launch → the 10-beat emotional onboarding funnel, which
    // flows into name+age → AI consent → paywall → the app. Returning
    // users go straight to /home (the Missions tab). There is NO face
    // scan anywhere.
    // Let everyone into the app — the paywall fires on ACTIONS (opening a
    // girl, starting a mission or a call), not as an entry wall. They see
    // what they're buying first.
    if (!onboarded) {
      context.go('/onboarding/story');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Black with a faint red glow up top ─────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 1.0,
                  colors: [
                    AppColors.red.withValues(alpha: 0.12),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          // ── Center mark — app logo + wordmark ──────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App logo (the red crown), with a soft red halo.
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.red.withValues(alpha: 0.35),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/icons/appstore.png',
                      width: 104, height: 104, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox(width: 104, height: 104),
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 700.ms).scale(
                    begin: const Offset(0.88, 0.88),
                    delay: 200.ms, duration: 700.ms, curve: Curves.easeOutBack),

                const SizedBox(height: Sp.xl),

                // Brand — editorial serif "Im" white + "Him" red.
                const ImHimWordmark(fontSize: 56, letterSpacing: -2)
                  .animate().fadeIn(delay: 900.ms, duration: 800.ms)
                  .slideY(begin: 0.15, end: 0,
                      delay: 900.ms, duration: 800.ms, curve: Curves.easeOut),

                const SizedBox(height: Sp.sm),

                // Italic undertagline — the new brand promise.
                Text('the guy who owns the room.',
                  style: AppTypography.h1Italic.copyWith(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.2))
                  .animate().fadeIn(delay: 1300.ms, duration: 700.ms),
              ],
            ),
          ),

          // ── Bottom progress hairline ─────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Loading bar
                    SizedBox(
                      width: size.width,
                      child: const LinearProgressIndicator(
                        backgroundColor: AppColors.surface2,
                        valueColor: AlwaysStoppedAnimation(AppColors.red),
                        minHeight: 1,
                      ),
                    ).animate().fadeIn(delay: 1600.ms, duration: 500.ms),

                    const SizedBox(height: Sp.sm),

                    Row(
                      children: [
                        Text('BECOME THE MAN WHO OWNS THE ROOM',
                          style: AppTypography.label.copyWith(
                            color: AppColors.textMuted, fontSize: 9, letterSpacing: 2.8)),
                        const Spacer(),
                        Text('v1.0',
                          style: AppTypography.label.copyWith(
                            color: AppColors.textMuted, fontSize: 9, letterSpacing: 2.8)),
                      ],
                    ).animate().fadeIn(delay: 1800.ms, duration: 500.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
