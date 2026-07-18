import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/imhim_wordmark.dart';

/// The Mission Card — a full-screen, film-ready card you show RIGHT BEFORE
/// the approach. Built to be screen-recorded / posted: the mission, the
/// ImHim mark, a bold prompt. Pops `true` when they mark it done.
class MissionCardScreen extends StatelessWidget {
  final String title;
  final String sub;
  final int tier;
  final bool done;
  const MissionCardScreen({
    super.key,
    required this.title,
    required this.sub,
    required this.tier,
    this.done = false,
  });

  void _share() {
    // ignore: discarded_futures
    AnalyticsService.missionCardShared(title: title);
    Share.share('Today\'s mission: $title.\n\nI\'m doing it. Your move. — ImHim');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.1,
                  colors: [Color(0x33E5393B), Colors.black],
                  stops: [0.0, 0.75],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ImHimWordmark(fontSize: 26, letterSpacing: -0.4),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text('TODAY\'S MISSION · TIER $tier',
                      style: GoogleFonts.inter(
                        color: AppColors.red,
                        fontSize: 12,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w800,
                      )).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 18),
                  Text(title,
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 44,
                            height: 1.05,
                            letterSpacing: -0.5,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w800,
                          ))
                      .animate()
                      .fadeIn(delay: 120.ms, duration: 500.ms)
                      .slideY(begin: 0.06, end: 0),
                  const SizedBox(height: 18),
                  Text(sub,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 17,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      )).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                  const SizedBox(height: 22),
                  Text('Film this. Then go do it.',
                          style: GoogleFonts.inter(
                            color: AppColors.red,
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w700,
                          ))
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(delay: 500.ms, duration: 500.ms)
                      .then()
                      .fade(begin: 1, end: 0.45, duration: 1400.ms),
                  const Spacer(flex: 2),
                  Row(
                    children: [
                      Expanded(
                        child: _btn('SHARE', Icons.ios_share_rounded, AppColors.accent,
                            filled: false, onTap: () {
                          HapticFeedback.selectionClick();
                          _share();
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _btn(done ? 'DONE' : 'I DID IT', Icons.check_circle_rounded,
                            AppColors.red,
                            filled: true, onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context, !done);
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, IconData icon, Color color,
      {required bool filled, required VoidCallback onTap}) {
    return SizedBox(
      height: 58,
      child: Material(
        color: filled ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: filled ? Colors.white : color),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.inter(
                    color: filled ? Colors.white : color,
                    fontSize: 13,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w900,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
