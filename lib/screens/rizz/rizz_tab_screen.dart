import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/mirrorly_components.dart';

/// RIZZ tab — two cards. The generator (paste her text or screenshot,
/// get 3 replies) and The arsenal (curated 125-line library).
/// Editorial composition: italic Playfair masthead, two clean cards,
/// no portrait noise. Nothing else competes for attention.
class RizzTabScreen extends StatelessWidget {
  const RizzTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            MirrorlyMasthead(
              title: 'Rizz',
              actions: [
                MastheadAction(
                  icon: Icons.tune,
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'Type what she said or drop a screenshot. '
                'Get three replies that hit — safest to boldest.',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 15, height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 22),

            // RIZZ GENERATOR — the AI hero action. Solid red, prominent.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _RizzGeneratorCard(onTap: () => context.push('/rizz')),
            ).animate().fadeIn(duration: 380.ms)
              .slideY(begin: 0.02, end: 0, duration: 380.ms,
                  curve: Curves.easeOut),

            const SizedBox(height: 14),

            // THE ARSENAL — curated library, outline card.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _ArsenalCard(onTap: () => context.push('/lines')),
            ).animate().fadeIn(delay: 120.ms, duration: 380.ms)
              .slideY(begin: 0.02, end: 0, duration: 380.ms,
                  curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}

class _RizzGeneratorCard extends StatelessWidget {
  final VoidCallback onTap;
  const _RizzGeneratorCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.red,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.white.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.red.withValues(alpha: 0.4),
                blurRadius: 32, spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THE GENERATOR',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11, letterSpacing: 3.0,
                        fontWeight: FontWeight.w800,
                      )),
                    const SizedBox(height: 8),
                    Text('Drop her text.\nGet 3 hits.',
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 26, height: 1.1,
                        letterSpacing: -0.5,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w800,
                      )),
                    const SizedBox(height: 8),
                    Text('Type it. Or drop a screenshot.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 13.5, height: 1.4,
                        fontWeight: FontWeight.w500,
                      )),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.bolt_rounded,
                color: Colors.white, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArsenalCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ArsenalCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface1,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: AppColors.red.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.red.withValues(alpha: 0.32), width: 0.9),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THE ARSENAL',
                      style: GoogleFonts.inter(
                        color: AppColors.red,
                        fontSize: 11, letterSpacing: 3.0,
                        fontWeight: FontWeight.w800,
                      )),
                    const SizedBox(height: 8),
                    Text('125 lines.\nThe ones that pull.',
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.textPrimary,
                        fontSize: 26, height: 1.1,
                        letterSpacing: -0.5,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w800,
                      )),
                    const SizedBox(height: 8),
                    Text('Openers · tease · heat · cold · close.',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 13.5, height: 1.4,
                        fontWeight: FontWeight.w500,
                      )),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.red, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
