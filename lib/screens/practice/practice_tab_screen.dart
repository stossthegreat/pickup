import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/villain/scenes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/mirrorly_components.dart';
import '../game/arena/arena_session_screen.dart';

/// PRACTICE — a 2×2 grid of six AI women. Tap one and her realtime VOICE
/// roleplay opens (red record button, Lucien cutting in). Reuses the
/// existing ArenaSessionScreen; this screen is just the elite picker.
class PracticeTabScreen extends StatelessWidget {
  const PracticeTabScreen({super.key});

  // Six scenes, each paired with its render. Order chosen for visual variety.
  static const _cast = <(String sceneId, String asset, Color accent)>[
    ('ice_girl', 'assets/characters/women/ice_queen.png', Color(0xFF38BDF8)),
    ('chaos_girl', 'assets/characters/women/chaos_girl.png', Color(0xFFE8222A)),
    ('hot_girl_who_knows_it', 'assets/characters/women/socialite.png', Color(0xFFFBBF24)),
    ('intellectual_girl', 'assets/characters/women/intellectual.png', Color(0xFF8B94F5)),
    ('sweet_girl', 'assets/characters/women/shy_girl.png', Color(0xFF4ADE80)),
    ('first_date_girl', 'assets/characters/women/arena.png', Color(0xFFF472B6)),
  ];

  VillainScene _scene(String id) =>
      VillainScenes.all.firstWhere((s) => s.id == id, orElse: () => VillainScenes.all.first);

  String _pretty(String title) {
    // "ICE GIRL" -> "Ice Girl"
    return title
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
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
                  final (id, asset, accent) = _cast[i];
                  final scene = _scene(id);
                  return _GirlCard(
                    name: _pretty(scene.title),
                    hook: scene.oneLine,
                    asset: asset,
                    accent: accent,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ArenaSessionScreen(scene: scene),
                    )),
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
