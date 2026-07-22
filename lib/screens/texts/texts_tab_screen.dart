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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your AI Wingman', style: AppTypography.h1Italic),
                const SizedBox(height: 4),
                Text(
                  'Analyse screenshots, write replies, fix dead chats and '
                  'help before you press send.',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // The chat, embedded — im-him header dropped. The screenshot +
          // pickup-line buttons now sit on the composer's tone row.
          Expanded(
            child: RizzChatScreen(
              embedded: true,
              onScreenshot: () =>
                  context.push('/rizz', extra: const RizzCardAction.upload()),
              onLines: () => context.push('/lines'),
            ),
          ),
        ],
      ),
    );
  }
}

