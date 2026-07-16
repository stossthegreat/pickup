import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/mirrorly_components.dart';
import '../game/freeflow/free_flow_screen.dart';

/// PRACTICE — a 2×3 grid of six AI women. Tap one and her REALTIME VOICE
/// roleplay opens straight onto the live orb (red HOLD-TO-SPEAK circle,
/// Lucien step-in, END & GET SCORED) with that character preselected.
///
/// This is the exact screen that was the main surface of ImHim's Game
/// tab — [FreeFlowScreen]. Each card just pushes it with the matching
/// `initialVibeKey`, so the OpenAI Realtime session, scoring, and every
/// backend endpoint are identical to the tab + picker paths. Nothing new
/// to wire when the backend is plugged in — it already speaks this
/// contract.
class PracticeTabScreen extends StatelessWidget {
  const PracticeTabScreen({super.key});

  // Six women, each mapped 1:1 to a realtime roleplay persona
  // (`_Vibe.key` inside free_flow_screen.dart). Portrait + accent chosen
  // to match her vibe; the hook mirrors her in-session tagline so the
  // card and the live persona read as the same character.
  static const _cast = <_CastMember>[
    _CastMember(
      vibe: 'cold',
      name: 'Ice Queen',
      hook: 'Selective. Gives you nothing. Earn every inch.',
      asset: 'assets/characters/women/ice_queen.png',
      accent: Color(0xFF38BDF8),
    ),
    _CastMember(
      vibe: 'into_you',
      name: 'Into You',
      hook: 'Already a little into you. Don\'t get needy.',
      asset: 'assets/characters/women/arena.png',
      accent: Color(0xFFF472B6),
    ),
    _CastMember(
      vibe: 'chaos',
      name: 'Chaos',
      hook: 'Fast, loud, jumps topics. Keep up.',
      asset: 'assets/characters/women/chaos_girl.png',
      accent: Color(0xFFE8222A),
    ),
    _CastMember(
      vibe: 'testing',
      name: 'Testing You',
      hook: 'Smart. Testing you constantly. Don\'t fold.',
      asset: 'assets/characters/women/intellectual.png',
      accent: Color(0xFF8B94F5),
    ),
    _CastMember(
      vibe: 'ice_then_fire',
      name: 'Ice Then Fire',
      hook: 'Starts ice cold. Warms only if you hold.',
      asset: 'assets/characters/women/socialite.png',
      accent: Color(0xFFFBBF24),
    ),
    _CastMember(
      vibe: 'sweet',
      name: 'Sweet',
      hook: 'Warm and genuine. Kill the arrogance.',
      asset: 'assets/characters/women/shy_girl.png',
      accent: Color(0xFF4ADE80),
    ),
  ];

  void _openRoleplay(BuildContext context, String vibeKey) {
    // Push on the ROOT navigator so the live session covers the bottom
    // nav bar (true full-screen), and so SafeCloseButton / safePop can
    // reliably pop back to this grid. tabMode stays false → the
    // standalone close button renders.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => FreeFlowScreen(initialVibeKey: vibeKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.md),
              child: MirrorlyMasthead(
                eyebrow: 'PRACTICE · VOICE',
                title: 'Who\'s it tonight?',
                subtitle: 'Six women, six ways to get read. Pick one — she picks up.',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, 120),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: Sp.sm + 4,
                crossAxisSpacing: Sp.sm + 4,
                childAspectRatio: 0.70,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final member = _cast[i];
                  return _GirlCard(
                    name: member.name,
                    hook: member.hook,
                    asset: member.asset,
                    accent: member.accent,
                    onTap: () => _openRoleplay(context, member.vibe),
                  )
                      .animate()
                      .fadeIn(delay: (60 * i).ms, duration: 320.ms)
                      .slideY(begin: 0.06, curve: Curves.easeOut);
                },
                childCount: _cast.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One woman in the Practice roster — her realtime persona key plus the
/// card's display fields.
class _CastMember {
  final String vibe;
  final String name;
  final String hook;
  final String asset;
  final Color accent;
  const _CastMember({
    required this.vibe,
    required this.name,
    required this.hook,
    required this.asset,
    required this.accent,
  });
}

class _GirlCard extends StatelessWidget {
  final String name, hook, asset;
  final Color accent;
  final VoidCallback onTap;
  const _GirlCard({
    required this.name,
    required this.hook,
    required this.asset,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Rd.xl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(asset, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surface2,
                      child: Icon(Icons.person_outline_rounded, color: accent, size: 40),
                    )),
            // Legibility gradient
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.transparent, Colors.black],
                  stops: [0.0, 0.42, 1.0],
                ),
              ),
            ),
            // Voice badge, top-right
            Positioned(
              top: Sp.sm + 2,
              right: Sp.sm + 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(Rd.sm),
                  border: Border.all(color: accent.withOpacity(0.7)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.mic_none_rounded, size: 11, color: accent),
                  const SizedBox(width: 4),
                  Text('VOICE',
                      style: AppTypography.label
                          .copyWith(color: accent, fontSize: 8, letterSpacing: 1.4)),
                ]),
              ),
            ),
            // Name + hook, bottom
            Positioned(
              left: Sp.md,
              right: Sp.md,
              bottom: Sp.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: 24, height: 2.5, color: accent,
                      margin: const EdgeInsets.only(bottom: 8)),
                  Text(name,
                      style: AppTypography.h3.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(hook,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                          color: Colors.white70, height: 1.3, fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
