import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/mirrorly_components.dart';
import '../roleplay/girl_chat_screen.dart';

/// PRACTICE — a 2×3 grid of six AI women. Tap one and her TEXTING
/// roleplay opens: flirt back and forth over text, her interest meter
/// moving with every line. A 📞 in the header takes it live on the
/// realtime VOICE orb ([FreeFlowScreen]) for the same character.
///
/// Text roleplay runs on POST /v1/date/turn; the voice handoff uses the
/// matching realtime persona key. Both backends already speak these
/// contracts, so nothing new is wired here.
class PracticeTabScreen extends StatelessWidget {
  const PracticeTabScreen({super.key});

  // Six women. `vibe` is the realtime VOICE persona key (FreeFlowScreen);
  // `character` is the /v1/date TEXTING roleplay id. `opener` is her
  // first text line.
  static const _cast = <_CastMember>[
    _CastMember(
      vibe: 'cold',
      character: 'ice_queen',
      name: 'Ice Queen',
      hook: 'Selective. Gives you nothing. Earn every inch.',
      opener: 'let me guess. you practised that in the mirror.',
      asset: 'assets/characters/women/ice_queen.png',
      accent: Color(0xFF38BDF8),
    ),
    _CastMember(
      vibe: 'into_you',
      character: 'into_you',
      name: 'Into You',
      hook: 'Already a little into you. Don\'t get needy.',
      opener: 'oh, it\'s you. i was kind of hoping you\'d text.',
      asset: 'assets/characters/women/arena.png',
      accent: Color(0xFFF472B6),
    ),
    _CastMember(
      vibe: 'chaos',
      character: 'chaos',
      name: 'Chaos',
      hook: 'Fast, loud, jumps topics. Keep up.',
      opener: 'you look like a bad decision. i love bad decisions.',
      asset: 'assets/characters/women/chaos_girl.png',
      accent: Color(0xFFE8222A),
    ),
    _CastMember(
      vibe: 'testing',
      character: 'intellectual',
      name: 'Testing You',
      hook: 'Smart. Testing you constantly. Don\'t fold.',
      opener: 'say something interesting. i\'ll wait.',
      asset: 'assets/characters/women/intellectual.png',
      accent: Color(0xFF8B94F5),
    ),
    _CastMember(
      vibe: 'ice_then_fire',
      character: 'socialite',
      name: 'Ice Then Fire',
      hook: 'Starts ice cold. Warms only if you hold.',
      opener: 'everyone here wants something from me. what do you want?',
      asset: 'assets/characters/women/socialite.png',
      accent: Color(0xFFFBBF24),
    ),
    _CastMember(
      vibe: 'sweet',
      character: 'shy',
      name: 'Sweet',
      hook: 'Warm and genuine. Kill the arrogance.',
      opener: 'oh — hi. i didn\'t think you\'d actually text first.',
      asset: 'assets/characters/women/shy_girl.png',
      accent: Color(0xFF4ADE80),
    ),
  ];

  void _openChat(BuildContext context, _CastMember m) {
    // Push the texting roleplay on the ROOT navigator so it covers the
    // bottom nav (true full-screen) and pops cleanly back to the grid.
    // The 📞 inside the chat opens the same girl on the voice orb.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => GirlChatScreen(
          config: GirlChatConfig(
            characterId: m.character,
            vibeKey: m.vibe,
            name: m.name,
            archetype: m.hook,
            portraitAsset: m.asset,
            accent: m.accent,
            opener: m.opener,
          ),
        ),
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
                eyebrow: 'PRACTICE · TEXT + VOICE',
                title: 'Who\'s it tonight?',
                subtitle: 'Text her. Tap 📞 to take it live. Six women, six ways to get read.',
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
                    onTap: () => _openChat(context, member),
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

/// One woman in the Practice roster — her voice persona key + text
/// roleplay id plus the card's display fields.
class _CastMember {
  final String vibe; // realtime VOICE persona key (FreeFlowScreen)
  final String character; // /v1/date TEXTING roleplay id
  final String name;
  final String hook;
  final String opener; // her first text line
  final String asset;
  final Color accent;
  const _CastMember({
    required this.vibe,
    required this.character,
    required this.name,
    required this.hook,
    required this.opener,
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
            // Text + voice badge, top-right
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
                  Icon(Icons.chat_bubble_outline_rounded, size: 10, color: accent),
                  const SizedBox(width: 3),
                  Icon(Icons.call_rounded, size: 10, color: accent),
                  const SizedBox(width: 4),
                  Text('CHAT',
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
