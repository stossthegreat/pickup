import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/rolodex_service.dart';
import '../../services/roster.dart';
import '../../theme/app_colors.dart';
import 'game_feel.dart';

/// THE SHELF — the Rolodex, seen every single day without being a card.
///
/// A collection nobody is reminded of is a menu item nobody opens. But
/// the day screen is already carrying three cards and the last thing it
/// needs is a fourth, so this is deliberately NOT one: a single line of
/// faces above the fold, some lit, most black. It reads in about half a
/// second and it says the only thing it needs to say — *there are people
/// you haven't got yet, and here is exactly how many.*
///
/// The silhouettes do all the work. A row of won faces would be a
/// trophy shelf; a row that's mostly black is an unfinished job.
class RolodexShelf extends StatefulWidget {
  final VoidCallback onTap;
  const RolodexShelf({super.key, required this.onTap});

  @override
  State<RolodexShelf> createState() => _RolodexShelfState();
}

class _RolodexShelfState extends State<RolodexShelf> {
  Set<String> _owned = const {};
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    await Rolodex.seedIfEmpty();
    final cards = await Rolodex.all();
    if (!mounted) return;
    setState(() {
      _owned = {for (final c in cards) c.girlId};
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox(height: 78);
    final won = _owned.length;
    final total = kRoster.length;

    return GestureDetector(
      onTap: () {
        Feel.tick();
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('THE ROLODEX',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 8.5,
                  letterSpacing: 3.2,
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(width: 9),
            Text('$won/$total',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 9.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                )),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                size: 17, color: AppColors.textMuted),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            // Expanded, not fixed widths: ten faces at a fixed 40pt
            // overflow a 360pt phone, and a shelf that scrolls sideways
            // hides exactly the thing it exists to show. Every roster
            // size fits, on every device, by construction.
            child: Row(
              children: [
                for (final (i, g) in kRoster.indexed)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: i == kRoster.length - 1 ? 0 : 5),
                      child: _Face(girl: g, owned: _owned.contains(g.id))
                          .animate()
                          .fadeIn(delay: (30 * i).ms, duration: 260.ms),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  final GirlBrief girl;
  final bool owned;
  const _Face({required this.girl, required this.owned});

  @override
  Widget build(BuildContext context) {
    final tint = rarityOf(girl).tint;
    final img = Image.asset(
      girl.asset,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.3),
      errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.surface2),
    );

    return Container(
      height: 46,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: owned
              ? tint.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: owned
            ? [BoxShadow(color: tint.withValues(alpha: 0.22), blurRadius: 10)]
            : null,
      ),
      child: owned
          ? img
          : ColorFiltered(
              colorFilter:
                  const ColorFilter.mode(Color(0xFF121216), BlendMode.srcIn),
              child: img,
            ),
    );
  }
}
