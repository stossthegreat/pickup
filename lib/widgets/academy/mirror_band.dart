import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/mirror_service.dart';
import '../../theme/app_colors.dart';
import 'game_button.dart';
import 'game_feel.dart';

/// THE BAND — his title, one line, wherever identity belongs.
///
/// Deliberately NOT a card. The mirror's whole power is that it reads as
/// a fact about him rather than a feature we built, and facts don't come
/// in bordered containers with a header. One line, his name for himself,
/// tappable for why.
class MirrorBand extends StatefulWidget {
  const MirrorBand({super.key});

  @override
  State<MirrorBand> createState() => _MirrorBandState();
}

class _MirrorBandState extends State<MirrorBand> {
  MirrorRead? _read;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    final r = await MirrorService.read();
    if (mounted) setState(() => _read = r);
  }

  @override
  Widget build(BuildContext context) {
    final r = _read;
    if (r == null) return const SizedBox(height: 22);
    final t = r.trait;

    // Not enough evidence yet. Said plainly, with the count, because
    // "still reading you · 11 more lines" is an open loop and "no data"
    // is a dead end.
    if (t == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 4),
        child: Row(children: [
          const Icon(Icons.visibility_outlined,
              size: 13, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                'STILL READING YOU · ${r.toGo} MORE LINES',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 8.5,
                  letterSpacing: 2.6,
                  fontWeight: FontWeight.w900,
                )),
          ),
        ]),
      );
    }

    return GestureDetector(
      onTap: () {
        Feel.tick();
        showMirrorSheet(context, t);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 4),
        child: Row(children: [
          Icon(t.icon, size: 13, color: t.tint),
          const SizedBox(width: 8),
          Text('YOU ARE',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 8.5,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(width: 7),
          Text(t.title,
              style: GoogleFonts.inter(
                color: t.tint,
                fontSize: 9.5,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w900,
              )),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded,
              size: 15, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}

/// Why it says that. Opened from the band, and used as the full-screen
/// moment the first time a title lands or changes.
Future<void> showMirrorSheet(BuildContext context, Trait t,
    {bool announce = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MirrorSheet(trait: t, announce: announce),
  );
}

class _MirrorSheet extends StatefulWidget {
  final Trait trait;
  final bool announce;
  const _MirrorSheet({required this.trait, required this.announce});

  @override
  State<_MirrorSheet> createState() => _MirrorSheetState();
}

class _MirrorSheetState extends State<_MirrorSheet> {
  @override
  void initState() {
    super.initState();
    if (widget.announce) Feel.best();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trait;
    final tint = t.tint;
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint.withValues(alpha: 0.14), AppColors.base],
          stops: const [0, 0.5],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          26, 14, 26, 26 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 26),
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tint.withValues(alpha: 0.12),
            border: Border.all(color: tint.withValues(alpha: 0.5), width: 1.4),
            boxShadow: [
              BoxShadow(color: tint.withValues(alpha: 0.3), blurRadius: 26)
            ],
          ),
          child: Icon(t.icon, size: 27, color: tint),
        )
            .animate()
            .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                duration: 420.ms,
                curve: Curves.easeOutBack),
        const SizedBox(height: 18),
        Text(widget.announce ? 'YOU\'VE BECOME' : 'THE MIRROR SAYS',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 9,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w900,
                ))
            .animate()
            .fadeIn(delay: 200.ms),
        const SizedBox(height: 9),
        Text(t.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  height: 1,
                  letterSpacing: -1,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: tint.withValues(alpha: 0.5), blurRadius: 30)
                  ],
                ))
            .animate()
            .fadeIn(delay: 300.ms, duration: 320.ms)
            .slideY(begin: 0.18, end: 0, curve: Curves.easeOutCubic),
        const SizedBox(height: 18),
        Text(t.blurb,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 14.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ))
            .animate()
            .fadeIn(delay: 460.ms),
        const SizedBox(height: 20),
        // The honesty line. It's the reason he believes the rest of it —
        // a title with no stated basis is a horoscope, and one that
        // names its own evidence is a finding.
        Text(
                'Worked out from your own lines. Nobody picked this and '
                'nobody can. It changes when you do.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ))
            .animate()
            .fadeIn(delay: 620.ms),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: GameButton(
            label: widget.announce ? 'THAT\'S ME' : 'CLOSE',
            color: tint,
            textColor:
                tint.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
      ]),
    );
  }
}
