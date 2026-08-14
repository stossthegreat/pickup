import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart';
import '../../services/rolodex_service.dart';
import '../../services/share_service.dart';
import '../../widgets/share/rizz_card.dart';
import '../../services/roster.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/game_feel.dart';
import '../../widgets/academy/squad_chrome.dart';

/// THE ROLODEX — the trophy case.
///
/// One screen, one job: show him what he owns and what's missing, in
/// that order, and make the gap between the two impossible to ignore.
///
/// The locked cards are the point. An empty slot with a silhouette, a
/// rarity and a number he has to hit is an open loop; a screen that only
/// showed what he'd won would be a receipt. Every strong collection UI
/// in the world shows you the holes.
class RolodexScreen extends StatefulWidget {
  const RolodexScreen({super.key});

  @override
  State<RolodexScreen> createState() => _RolodexScreenState();
}

class _RolodexScreenState extends State<RolodexScreen> {
  List<NumberCard> _cards = const [];
  bool _loading = true;

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
      _cards = cards;
      _loading = false;
    });
  }

  NumberCard? _cardFor(String id) {
    for (final c in _cards) {
      if (c.girlId == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final won = _cards.length;
    final total = kRoster.length;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: Stack(children: [
        const Positioned.fill(child: SquadAtmosphere(accent: AppColors.red)),
        SafeArea(
          child: _loading
              ? const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.red)))
              : CustomScrollView(slivers: [
                  SliverToBoxAdapter(child: _head(won, total)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 13,
                        crossAxisSpacing: 13,
                        childAspectRatio: 0.68,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final g = kRoster[i];
                          return _Slot(
                            girl: g,
                            card: _cardFor(g.id),
                            onTap: () => _open(g),
                          )
                              .animate()
                              .fadeIn(delay: (40 * i).ms, duration: 300.ms)
                              .slideY(
                                  begin: 0.08,
                                  end: 0,
                                  curve: Curves.easeOutCubic);
                        },
                        childCount: kRoster.length,
                      ),
                    ),
                  ),
                ]),
        ),
      ]),
    );
  }

  Widget _head(int won, int total) {
    final coldest = _coldest();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textSecondary),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Share',
            onPressed: won == 0
                ? null
                : () => ShareService.shareRizzCard(
                      context: context,
                      data: RizzShareData(
                        kicker: 'THE ROLODEX',
                        hero: '$won',
                        heroSub: 'OF $total NUMBERS',
                        line: 'Every one earned. None of them given.',
                        // The collection is SHOWN, not described — a row
                        // that's mostly silhouette is the whole ask.
                        faces: [
                          for (final g in kRoster)
                            (asset: g.asset, owned: _cardFor(g.id) != null),
                        ],
                        stats: [
                          (label: 'WON', value: '$won'),
                          (label: 'LEFT', value: '${total - won}'),
                        ],
                      ),
                      text: '$won of $total numbers on ImHim Rizz. '
                          'Every one earned.',
                    ),
            icon: const Icon(Icons.ios_share_rounded,
                color: AppColors.textTertiary, size: 20),
          ),
        ]),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('THE ROLODEX',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 32,
                    letterSpacing: -1.4,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 6),
              // The count is the whole screen. Fraction, never a total —
              // "7" is an achievement, "7 of 10" is an unfinished job,
              // and the unfinished job is what brings him back.
              Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                Text('$won',
                    style: GoogleFonts.inter(
                      color: AppColors.red,
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    )),
                Text(' / $total NUMBERS',
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w900,
                    )),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(children: [
                  Container(
                      height: 4, color: Colors.white.withValues(alpha: 0.07)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: won / total),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => FractionallySizedBox(
                      widthFactor: v.clamp(0.0, 1.0),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.red.withValues(alpha: 0.6),
                                blurRadius: 10)
                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
        if (coldest != null) ...[
          const SizedBox(height: 16),
          _ColdNotice(card: coldest),
        ],
      ]),
    );
  }

  /// One woman, never a list. A wall of dying relationships is anxiety,
  /// and anxiety uninstalls apps.
  NumberCard? _coldest() {
    NumberCard? worst;
    for (final c in _cards) {
      if (!c.cooling) continue;
      final w = worst;
      if (w == null || c.warmth < w.warmth) worst = c;
    }
    return worst;
  }

  Future<void> _open(GirlBrief g) async {
    Feel.tick();
    final card = _cardFor(g.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          card == null ? _LockedSheet(girl: g) : _CardSheet(card: card),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  ONE SLOT — won or empty
// ══════════════════════════════════════════════════════════════════════

class _Slot extends StatelessWidget {
  final GirlBrief girl;
  final NumberCard? card;
  final VoidCallback onTap;
  const _Slot({required this.girl, required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Copy to a local before touching it: a nullable field on a widget
    // never promotes, so `card.score` after a null check is a compile
    // error. Bitten by exactly this in b130.
    final c = card;
    final owned = c != null;
    final rarity = rarityOf(girl);
    final tint = rarity.tint;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: owned
                ? tint.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.06),
            width: owned ? 1.4 : 1,
          ),
          boxShadow: owned
              ? [BoxShadow(color: tint.withValues(alpha: 0.16), blurRadius: 20)]
              : null,
        ),
        child: Stack(fit: StackFit.expand, children: [
          // Her face — full colour when won, a pure silhouette when not.
          // The silhouette is doing the work: he knows there's someone
          // there and he cannot see who.
          Positioned.fill(
            child: owned
                ? _portrait(girl)
                : ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                        Color(0xFF101014), BlendMode.srcIn),
                    child: _portrait(girl),
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.94),
                  ],
                  stops: const [0.28, 0.62, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: 9,
            left: 9,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: tint.withValues(alpha: 0.6)),
              ),
              child: Text(rarity.label,
                  style: GoogleFonts.inter(
                    color: tint,
                    fontSize: 7,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w900,
                  )),
            ),
          ),
          if (!owned)
            const Positioned(
              top: 10,
              right: 10,
              child: Icon(Icons.lock_rounded,
                  size: 14, color: AppColors.textMuted),
            ),
          // The warmth hairline — only on cards he owns, only when it
          // has started to matter. Tested against `c` directly rather
          // than through `owned`: promotion via a boolean local is not
          // something to bet a build on, and b130 was exactly this
          // family of mistake.
          if (c != null && c.cooling)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                color: AppColors.signalAmber.withValues(alpha: 0.9),
              ),
            ),
          Positioned(
            left: 11,
            right: 11,
            bottom: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(owned ? girl.name.toUpperCase() : '?????',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: owned ? Colors.white : AppColors.textMuted,
                      fontSize: 14,
                      letterSpacing: owned ? 1.4 : 4,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 3),
                Text(
                    owned
                        ? Rolodex.numberFor(girl.id)
                        : '${rarity.bar} TO WIN HER',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: owned ? tint : AppColors.textMuted,
                      fontSize: 9.5,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _portrait(GirlBrief g) => Image.asset(
        g.asset,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.35),
        errorBuilder: (_, __, ___) => ColoredBox(
          color: AppColors.surface2,
          child: Center(
            child: Icon(Icons.person_rounded,
                size: 42, color: AppColors.textMuted),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════
//  SHEETS
// ══════════════════════════════════════════════════════════════════════

/// A won card, opened. The line he wrote is the hero — not the score.
class _CardSheet extends StatelessWidget {
  final NumberCard card;
  const _CardSheet({required this.card});

  @override
  Widget build(BuildContext context) {
    final g = card.girl;
    final tint = card.rarity.tint;
    final warmth = card.warmth;
    final when = DateTime.fromMillisecondsSinceEpoch(card.wonAtMs);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.base,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 14, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 22),
        Row(children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tint, width: 1.6),
            ),
            child: ClipOval(
              child: Image.asset(g.asset,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.25),
                  errorBuilder: (_, __, ___) => ColoredBox(
                        color: AppColors.surface2,
                        child: Icon(Icons.person_rounded, color: tint),
                      )),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 3),
                Text(Rolodex.numberFor(g.id),
                    style: GoogleFonts.inter(
                      color: tint,
                      fontSize: 13,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${card.score}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w900,
                )),
            Text('SHE HIT',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 7.5,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                )),
          ]),
        ]),
        const SizedBox(height: 22),
        if (card.line.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text('THE LINE THAT DID IT',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 8.5,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                )),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(14),
              border: Border(
                  left: BorderSide(color: tint, width: 3),
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  right:
                      BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  bottom:
                      BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Text('"${card.line}"',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                )),
          ),
          const SizedBox(height: 20),
        ],
        // Warmth, stated plainly. It is a prompt, not a threat — nothing
        // is deleted, and the copy has to say so without saying it.
        Row(children: [
          Text('WARMTH',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 8.5,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (warmth / 100).clamp(0.0, 1.0).toDouble(),
                minHeight: 5,
                backgroundColor: AppColors.surface2,
                valueColor: AlwaysStoppedAnimation(
                    warmth <= 45 ? AppColors.signalAmber : kNeon),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$warmth',
              style: GoogleFonts.inter(
                color: warmth <= 45 ? AppColors.signalAmber : kNeon,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              )),
        ]),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
              warmth <= 45
                  ? 'She\'s going quiet. One message brings her all the way back.'
                  : 'Won ${when.day}/${when.month}/${when.year}.',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              )),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {
              Feel.tick();
              ShareService.shareRizzCard(
                context: context,
                data: RizzShareData(
                  kicker: '${g.name.toUpperCase()} · ${card.rarity.label}',
                  hero: '${card.score}',
                  heroSub: 'SHE HIT',
                  quote: card.line.isEmpty ? null : card.line,
                  line: 'That\'s the line that got her number.',
                  accent: tint,
                  faces: [(asset: g.asset, owned: true)],
                ),
                text: 'Got ${g.name}\'s number on ImHim Rizz — '
                    'she hit ${card.score}.',
              );
            },
            child: Text('SHARE THE CARD',
                style: GoogleFonts.inter(
                  color: tint,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                )),
          ),
        ),
      ]),
    );
  }
}

/// An empty slot, opened. Says exactly what she is and exactly what the
/// bar is — an open loop is only motivating when it's specific.
class _LockedSheet extends StatelessWidget {
  final GirlBrief girl;
  const _LockedSheet({required this.girl});

  @override
  Widget build(BuildContext context) {
    final rarity = rarityOf(girl);
    final tint = rarity.tint;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.base,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
        const SizedBox(height: 24),
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface3, width: 1.4),
          ),
          child: ClipOval(
            child: ColorFiltered(
              colorFilter:
                  const ColorFilter.mode(Color(0xFF16161B), BlendMode.srcIn),
              child: Image.asset(girl.asset,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.25),
                  errorBuilder: (_, __, ___) => const ColoredBox(
                      color: AppColors.surface2, child: SizedBox())),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('NOT YOURS YET',
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 10,
              letterSpacing: 4,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 12),
        Text(girl.type,
            style: GoogleFonts.inter(
              color: tint,
              fontSize: 20,
              letterSpacing: 1,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 10),
        Text(rarity.teaser,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tint.withValues(alpha: 0.35)),
          ),
          child: Column(children: [
            Text('${rarity.bar}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(height: 5),
            Text('GET HER THERE AND SHE\'S YOURS',
                style: GoogleFonts.inter(
                  color: tint,
                  fontSize: 9,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w900,
                )),
          ]),
        ),
        const SizedBox(height: 14),
        Text('Chat her in Practice or take her in a battle.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            )),
      ]),
    );
  }
}

/// The one card that's cooling, surfaced at the top. Never a list.
class _ColdNotice extends StatelessWidget {
  final NumberCard card;
  const _ColdNotice({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.signalAmber.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.signalAmber.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.trending_down_rounded,
            size: 16, color: AppColors.signalAmber),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
              '${card.girl.name} is going quiet. One message and she\'s back.',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              )),
        ),
      ]),
    );
  }
}
