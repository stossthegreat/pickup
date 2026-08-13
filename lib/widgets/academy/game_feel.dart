import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/roster.dart';
import '../../theme/app_colors.dart';

/// GAME FEEL — the two things that make a screen feel like a machine
/// instead of a form: a haptic vocabulary, and a reel.
///
/// Everything in the app fired mediumImpact for everything, which is the
/// haptic equivalent of one sound effect. A phone in a pocket can tell
/// four or five distinct patterns apart easily, and once it can, the
/// device itself starts carrying meaning — you know you beat your best
/// before you've looked.

// ══════════════════════════════════════════════════════════════════════
//  THE HAPTIC VOCABULARY
// ══════════════════════════════════════════════════════════════════════

/// Named patterns, so a completion can never accidentally feel like a
/// win and a loss can never feel like nothing.
abstract final class Feel {
  /// A tap that did something. The floor.
  static void tick() => HapticFeedback.selectionClick();

  /// One rep banked. Single confident thud.
  static void banked() => HapticFeedback.mediumImpact();

  /// The reel passing a face. Deliberately the lightest thing we have —
  /// it fires dozens of times and must never become noise.
  static void reel() => HapticFeedback.selectionClick();

  /// The number landing. Heavy, single, final.
  static void land() => HapticFeedback.heavyImpact();

  /// PERSONAL BEST — two heavy hits, a beat apart. The pattern people
  /// learn first because it's the one they want.
  static Future<void> best() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 110));
    HapticFeedback.heavyImpact();
  }

  /// A win — three rising hits. Unmistakable through denim.
  static Future<void> win() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 90));
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 90));
    HapticFeedback.heavyImpact();
  }

  /// A near miss. One heavy, one light — the shape of almost. It should
  /// feel like a stumble, not a defeat, because the point is that he
  /// runs it back.
  static Future<void> nearMiss() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 70));
    HapticFeedback.lightImpact();
  }

  /// Something was lost — a streak, a day. Two heavy, slow. The only
  /// pattern in the app that's meant to feel bad.
  static Future<void> lost() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 220));
    HapticFeedback.heavyImpact();
  }
}

// ══════════════════════════════════════════════════════════════════════
//  THE REEL
// ══════════════════════════════════════════════════════════════════════

/// A slot reel of faces that spins and decelerates onto today's woman.
///
/// It is NOT a gamble and it must never pretend to be. Today's woman is
/// fixed — the same one for the whole world, chosen by the date — so the
/// reel always lands where it was always going to land. What it buys is
/// the thing a slot machine actually sells, which isn't chance: it's the
/// gap between committing and knowing. Two and a half seconds of faces
/// going past, decelerating, ticking under your thumb, and then her.
///
/// Rigging a reel that claims to be random would be a lie and men would
/// smell it. Dressing a shared daily unveiling as an event is just good
/// theatre — every man in the app is watching the same reel land on the
/// same face today.
class SlotReel extends StatefulWidget {
  final List<GirlBrief> pool;

  /// Index in [pool] the reel comes to rest on.
  final int target;
  final double height;
  final Color accent;

  /// Fires the instant she lands, so the caller can slam a title in.
  final VoidCallback? onLanded;

  const SlotReel({
    super.key,
    required this.pool,
    required this.target,
    required this.accent,
    this.height = 320,
    this.onLanded,
  });

  @override
  State<SlotReel> createState() => _SlotReelState();
}

class _SlotReelState extends State<SlotReel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  /// How many faces go past before it settles. Enough that you can't
  /// count them, few enough that it never outstays the moment.
  static const _loops = 4;

  int _lastTick = -1;
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onFrame);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_landed) {
        _landed = true;
        Feel.land();
        widget.onLanded?.call();
      }
    });
    _c.forward();
  }

  void _onFrame() {
    // One light tick per face that passes the window. Decelerating
    // haptics are most of why a physical reel feels alive.
    final idx = _offset.floor();
    if (idx != _lastTick) {
      _lastTick = idx;
      if (_c.value < 0.985) Feel.reel();
    }
    setState(() {});
  }

  /// Total distance travelled in "faces", eased hard out so it sprints
  /// then crawls the last half-face.
  double get _offset {
    final n = widget.pool.length;
    final total = _loops * n + widget.target;
    return Curves.easeOutQuart.transform(_c.value) * total;
  }

  @override
  void dispose() {
    _c.removeListener(_onFrame);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.pool.length;
    final off = _offset;
    final base = off.floor();
    final frac = off - base;
    final settling = _c.value > 0.86;

    return ClipRect(
      child: SizedBox(
        height: widget.height,
        child: Stack(children: [
          // Two frames sliding up: the one leaving and the one arriving.
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, -frac * widget.height),
              child: Column(children: [
                _face(widget.pool[base % n]),
                _face(widget.pool[(base + 1) % n]),
              ]),
            ),
          ),
          // Motion blur, thinning as it slows. This is what sells speed
          // more than the movement itself does.
          if (!settling)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // The window's own edges — a machine, not a carousel.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: widget.accent.withValues(
                          alpha: settling ? 0.9 : 0.35),
                      width: 2,
                    ),
                  ),
                  boxShadow: settling
                      ? [
                          BoxShadow(
                              color: widget.accent.withValues(alpha: 0.5),
                              blurRadius: 34)
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _face(GirlBrief g) => SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Image.asset(
          g.asset,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.1),
          errorBuilder: (_, __, ___) => ColoredBox(
            color: AppColors.surface2,
            child: Center(
              child: Text(g.name.characters.first.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: widget.accent,
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                  )),
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════
//  THE NEAR MISS
// ══════════════════════════════════════════════════════════════════════

/// The most potent line in the whole app, and it costs nothing to say.
///
/// A score on its own is information. A score with the gap to the man
/// above it is a grudge — and a grudge is what brings someone back
/// tomorrow. Gambling machines spend enormous effort manufacturing near
/// misses; you get yours honestly, because there really is someone 0.2
/// ahead of you.
///
/// Returns null when there's nothing close enough to be worth naming.
/// A near miss you have to squint at isn't one, and crying "so close"
/// over a four-point gap is how a screen loses its credibility.
String? nearMissLine({
  required double mine,
  required double above,
  required String aboveName,
  required double closeWithin,
}) {
  final gap = above - mine;
  if (gap <= 0 || gap > closeWithin) return null;
  final g = gap < 1 ? gap.toStringAsFixed(1) : gap.round().toString();
  return '$g off $aboveName.';
}

/// The same idea against the grade boundary above you — "one point off a
/// B" stings in a way "you got a C" never will.
String? nextGradeLine({
  required int score,
  required int nextThreshold,
  required String nextLabel,
  required double divisor,
  required int decimals,
}) {
  final gap = nextThreshold - score;
  if (gap <= 0) return null;
  final shown = gap / divisor;
  // Only worth saying when it's genuinely within touching distance —
  // roughly a tenth of the way up the scale.
  if (shown > (100 / divisor) * 0.08) return null;
  final g = shown.toStringAsFixed(decimals);
  return '$g off $nextLabel.';
}

/// A shake that reads as impact rather than error. Used on the near
/// miss, where the screen should flinch.
class Flinch extends StatefulWidget {
  final Widget child;
  final bool active;
  const Flinch({super.key, required this.child, required this.active});

  @override
  State<Flinch> createState() => FlinchState();
}

class FlinchState extends State<Flinch> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.forward();
  }

  @override
  void didUpdateWidget(covariant Flinch old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = _c.value;
          // Decaying oscillation — hard first swing, gone in half a
          // second. A shake that keeps going reads as a broken form.
          final d = math.sin(t * math.pi * 7) * (1 - t) * 9;
          return Transform.translate(offset: Offset(d, 0), child: child);
        },
        child: widget.child,
      );
}
