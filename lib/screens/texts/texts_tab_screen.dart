import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../rizz/rizz_chat_screen.dart';
import '../rizz/rizz_tab_screen.dart' show RizzCardAction;

/// TEXTS — the AI text coach. The page IS the rizz chat (im-him header
/// stripped via embedded:true). The "Your AI Wingman" header scrolls WITH the
/// conversation (passed in as the chat's first list item), and the screenshot +
/// pickup-line buttons sit on the composer's tone row.
class TextsTabScreen extends StatelessWidget {
  const TextsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RizzChatScreen(
      embedded: true,
      onScreenshot: () =>
          context.push('/rizz', extra: const RizzCardAction.upload()),
      onLines: () => context.push('/lines'),
      header: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your AI Wingman', style: AppTypography.h1Italic),
            const SizedBox(height: 6),
            Text(
              'Analyse screenshots, write replies, fix dead chats and '
              'help before you press send.',
              style: AppTypography.bodySmall.copyWith(
                  color: AppColors.red, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
          ],
        ),
      ),
    );
  }
}
