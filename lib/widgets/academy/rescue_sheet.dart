import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/sfx_service.dart';
import '../../services/streak_rescue_service.dart';
import '../../theme/app_colors.dart';
import '../../services/backend/tiers.dart';
import 'game_feel.dart';

/// THE RESCUE SHEET — shown once, the moment he opens the app to a run
/// that stopped yesterday.
///
/// The number is the whole argument. "12 DAYS" in the largest type on
/// the screen, past tense, already gone unless he does something — then
/// one button that undoes it. Everything else on the sheet is small.
class RescueSheet {
  static Future<bool> show(BuildContext context, RescueOffer offer) async {
    Feel.lost();
    Sfx.lost();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _Sheet(offer: offer),
    );
    return saved == true;
  }
}

class _Sheet extends StatefulWidget {
  final RescueOffer offer;
  const _Sheet({required this.offer});

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  bool _busy = false;

  Future<void> _rescue() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await StreakRescue.spend(widget.offer);
    if (!mounted) return;
    if (ok) {
      Feel.win();
      Sfx.win();
    }
    Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 34),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('YOUR RUN STOPPED',
            style: GoogleFonts.inter(
              color: AppColors.red,
              fontSize: 10,
              letterSpacing: 3.6,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 18),

        // The argument, in one number.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${o.runLength}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 76,
                  height: 1,
                  letterSpacing: -4,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                        color: AppColors.red.withValues(alpha: 0.45),
                        blurRadius: 40)
                  ],
                )),
            const SizedBox(width: 8),
            Text(o.runLength == 1 ? 'DAY' : 'DAYS',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                )),
          ],
        ),
        const SizedBox(height: 14),
        Text(
            o.available
                ? 'You missed yesterday, so the climb went with it — the '
                    'ladder and the flame are the same number.\n\nYou can '
                    'have this one back.'
                : 'You missed yesterday, so the climb went with it. You\'ve '
                    'already used your rescue this '
                    '${o.isPro ? "week" : "month"} — this one stands.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 24),

        if (o.available) ...[
          _Btn(
            label: _busy ? 'SAVING…' : 'SAVE MY ${o.runLength} DAYS',
            filled: true,
            onTap: _rescue,
          ),
          const SizedBox(height: 10),
          Text(
              o.isPro
                  ? 'One rescue a week on Pro. It stays rare on purpose — a '
                      'streak you can always buy back isn\'t a streak.'
                  : 'One rescue a month. Pro gets one a week.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              )),
          if (!o.isPro) ...[
            const SizedBox(height: 14),
            _Btn(
              label: 'GET PRO',
              filled: false,
              onTap: () {
                Feel.tick();
                Navigator.of(context).pop(false);
                context.push('/paywall', extra: {'source': 'streak_rescue'});
              },
            ),
          ],
        ] else
          _Btn(
            label: 'START AGAIN TODAY',
            filled: true,
            onTap: () {
              Feel.banked();
              Navigator.of(context).pop(false);
            },
          ),
        const SizedBox(height: 12),
        if (o.available)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Let it go — start again today',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                )),
          ),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _Btn(
      {required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? kNeon : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: filled
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.14)),
          boxShadow: filled
              ? [BoxShadow(color: kNeon.withValues(alpha: 0.4), blurRadius: 24)]
              : null,
        ),
        child: Text(label,
            style: GoogleFonts.inter(
              color: filled ? Colors.black : AppColors.textSecondary,
              fontSize: 13.5,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w900,
            )),
      ),
    );
  }
}
