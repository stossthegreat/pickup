import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/dev_flags.dart';
import '../../services/local_store_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'freeflow/free_flow_screen.dart';

/// GAME tab — IS Free Flow. The tab opens straight onto the live
/// recording circle (INTO YOU loaded by default) so the user starts
/// pressing the orb the moment the tab paints. Character switching
/// + arena routing live as small chips inside the live chrome.
///
/// Free-tier gate stays — a non-pro user who hasn't used their free
/// session yet lands inside Free Flow; once they've consumed it the
/// tab shows a paywall card so we don't leak unlimited voice usage.
class GameTabScreen extends StatefulWidget {
  const GameTabScreen({super.key});

  @override
  State<GameTabScreen> createState() => _GameTabScreenState();
}

class _GameTabScreenState extends State<GameTabScreen> {
  bool _loaded = false;
  bool _gated  = false;

  @override
  void initState() {
    super.initState();
    _checkGate();
  }

  Future<void> _checkGate() async {
    final pro      = kBypassPaywall || await LocalStoreService.isSubscribed();
    final gameUsed = await LocalStoreService.gameFreeUsed();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _gated  = !pro && gameUsed;
    });
    // Non-pro user about to consume their one free session — mark
    // it now so the next time they hit the Game tab they see the
    // paywall instead of unlimited voice usage.
    if (!_gated && !pro) {
      await LocalStoreService.markGameFreeUsed();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: AppColors.base,
        body: SizedBox.shrink(),
      );
    }
    if (_gated) {
      return Scaffold(
        backgroundColor: AppColors.base,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('THE GAME',
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      color: AppColors.red,
                      fontSize: 12, letterSpacing: 3.6,
                      fontWeight: FontWeight.w800,
                    )),
                  const SizedBox(height: 12),
                  Text('You used your free flow.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textPrimary,
                      fontSize: 28, height: 1.15,
                      letterSpacing: -0.6,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w800,
                    )),
                  const SizedBox(height: 10),
                  Text(
                    'Mirrorly Pro unlocks unlimited Free Flow, every '
                    'arena scene, and the Rizz generator.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Material(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        await context.push('/paywall');
                        if (mounted) _checkGate();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        alignment: Alignment.center,
                        child: Text('UNLOCK WITH PRO',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13.5, letterSpacing: 2.8,
                            fontWeight: FontWeight.w900,
                          )),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return const FreeFlowScreen(tabMode: true);
  }
}
