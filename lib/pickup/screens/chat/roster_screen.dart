import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../data/characters.dart';
import '../../models/character.dart';
import '../../state/game_state.dart';
import 'roleplay_chat_screen.dart';

/// The Chat tab — pick who you're practising on. Free-play scenes (no mission
/// focus), laddered by unlock level so there's always a next girl to earn.
class RosterScreen extends StatelessWidget {
  const RosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.md),
            sliver: SliverList.list(children: [
              Text('PRACTICE', style: AppTypography.label),
              const SizedBox(height: Sp.xs),
              Text('Who\'s it tonight?', style: AppTypography.h1Italic),
              const SizedBox(height: 6),
              Text(
                'Every girl reads you differently. Beat one, unlock the next.',
                style: AppTypography.bodySmall,
              ),
            ]),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, 120),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: Sp.sm + 4,
                crossAxisSpacing: Sp.sm + 4,
                childAspectRatio: 0.66,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final c = Roster.women[i];
                  final locked = g.isLocked(c.unlockLevel);
                  return _CharTile(character: c, locked: locked)
                      .animate()
                      .fadeIn(delay: (50 * i).ms, duration: 300.ms)
                      .slideY(begin: 0.08, curve: Curves.easeOut);
                },
                childCount: Roster.women.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CharTile extends StatelessWidget {
  final Character character;
  final bool locked;
  const _CharTile({required this.character, required this.locked});

  @override
  Widget build(BuildContext context) {
    final accent = Color(character.accentValue);
    return GestureDetector(
      onTap: locked
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RoleplayChatScreen(character: character),
              )),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Rd.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(character.asset, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surface2,
                      child: Icon(Icons.person, color: accent, size: 40),
                    )),
            // Legibility scrim
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.4, 1],
                ),
              ),
            ),
            if (locked)
              Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_outline,
                        color: AppColors.textSecondary, size: 22),
                    const SizedBox(height: 6),
                    Text('AURA ${character.unlockLevel}',
                        style: AppTypography.label
                            .copyWith(color: AppColors.signalAmber)),
                  ]),
                ),
              ),
            Positioned(
              left: Sp.md,
              right: Sp.md,
              bottom: Sp.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 2,
                    color: accent,
                    margin: const EdgeInsets.only(bottom: 8),
                  ),
                  Text(character.name,
                      style: AppTypography.h3.copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(character.archetype.split(' · ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
