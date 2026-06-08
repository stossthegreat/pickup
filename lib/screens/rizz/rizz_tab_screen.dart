import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/mirrorly_components.dart';

/// RIZZ tab — three clean red cards, nothing else.
///
/// Modeled on PlugAI / Rizz-style landings — large rectangular cards
/// stacked vertically, big icon on the left, big italic title + clean
/// subtitle on the right. Black surface + brand red + white = the
/// Mirrorly editorial voice rendered in card form.
///
/// Card 1 — UPLOAD A SCREENSHOT (opens the generator + photo picker)
/// Card 2 — GIMME A PICKUP LINE (opens the curated arsenal)
/// Card 3 — CHAT WITH MIRRORLY (NEW — opens the rizz advisor chat)
class RizzTabScreen extends StatelessWidget {
  const RizzTabScreen({super.key});

  void _go(BuildContext context, String route, {Object? extra}) {
    HapticFeedback.selectionClick();
    context.push(route, extra: extra);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const MirrorlyMasthead(title: 'Rizz'),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _RizzCard(
                icon:     Icons.center_focus_strong_rounded,
                title:    'Upload a screenshot',
                subtitle: 'Get rizz on how to respond',
                onTap:    () => _go(context, '/rizz',
                    extra: const RizzCardAction.upload()),
              ),
            ).animate().fadeIn(duration: 360.ms)
              .slideY(begin: 0.02, end: 0, duration: 360.ms,
                  curve: Curves.easeOut),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _RizzCard(
                icon:     Icons.chat_bubble_outline_rounded,
                title:    'Gimme a pickup line',
                subtitle: 'Curated arsenal of killer rizz',
                onTap:    () => _go(context, '/lines'),
              ),
            ).animate().fadeIn(delay: 120.ms, duration: 360.ms)
              .slideY(begin: 0.02, end: 0, duration: 360.ms,
                  curve: Curves.easeOut),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _RizzCard(
                icon:     Icons.auto_awesome_rounded,
                title:    'Chat with Mirrorly',
                subtitle: 'Ask anything. We coach.',
                onTap:    () => _go(context, '/rizz-chat'),
                badge:    'NEW',
              ),
            ).animate().fadeIn(delay: 240.ms, duration: 360.ms)
              .slideY(begin: 0.02, end: 0, duration: 360.ms,
                  curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}

/// Routing payload for the upload-screenshot card. Reuses the same
/// /rizz generator route; the boolean tells it to fire the image
/// picker on first frame so the user lands inside the iOS photo
/// sheet without an extra tap.
class RizzCardAction {
  final bool launchUpload;
  const RizzCardAction.upload() : launchUpload = true;
}

/// One of the three red cards. Big icon-on-the-left layout — the
/// composition matches PlugAI / Rizz exactly but in the Mirrorly
/// black + red + white voice. Italic Playfair title to keep brand
/// consistency with the rest of the app's editorial cards.
class _RizzCard extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final VoidCallback onTap;
  final String?      badge;
  const _RizzCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.red,
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            splashColor: Colors.white.withValues(alpha: 0.08),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 26, 22, 26),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.4),
                    blurRadius: 30, spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Icon(icon, color: Colors.white, size: 54),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 24, height: 1.1,
                            letterSpacing: -0.4,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w800,
                          )),
                        const SizedBox(height: 8),
                        Text(subtitle,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 14, height: 1.35,
                            fontWeight: FontWeight.w500,
                          )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // NEW badge — small pill in the top-left corner.
          if (badge != null)
            Positioned(
              top: -8, left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10, offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(badge!,
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 10, letterSpacing: 2.4,
                    fontWeight: FontWeight.w900,
                  )),
              ),
            ),
        ],
      ),
    );
  }
}
