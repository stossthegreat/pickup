import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../rizz/rizz_chat_screen.dart';
import '../rizz/rizz_tab_screen.dart' show RizzCardAction;

/// TEXTS — the AI text coach. The page IS the rizz chat (im-him header
/// stripped via embedded:true). Two small red action cards sit on top:
/// Analyse Screenshot and Pickup Lines, deep-linking to the existing flows.
class TextsTabScreen extends StatelessWidget {
  const TextsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.sm),
            child: Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    label: 'Analyse Screenshot',
                    icon: Icons.image_outlined,
                    onTap: () =>
                        context.push('/rizz', extra: const RizzCardAction.upload()),
                  ),
                ),
                const SizedBox(width: Sp.sm),
                Expanded(
                  child: _ActionCard(
                    label: 'Pickup Lines',
                    icon: Icons.bolt_rounded,
                    onTap: () => context.push('/lines'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // The chat, embedded — im-him header dropped.
          const Expanded(child: RizzChatScreen(embedded: true)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionCard({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rd.md),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.red, AppColors.redDim],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(Rd.md),
            boxShadow: [BoxShadow(color: AppColors.redGlow, blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
