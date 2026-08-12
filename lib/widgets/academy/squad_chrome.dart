import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

/// THE SQUAD ROOM'S CHROME.
///
/// The room had the right information and the wrong presence — a stack
/// of flat grey boxes on a black page. Everything else in the app earns
/// its weight with atmosphere: a poster hero, a scrim, type that
/// commits. This file gives the squad the same vocabulary so it stops
/// looking like a settings screen and starts looking like a place.
///
/// Four pieces, used everywhere:
///   SquadAtmosphere — the ambient wash behind the masthead
///   SquadCrest      — the squad's own mark, generated from its name
///   ChapterMark     — section headings as chapters, not labels
///   Panel           — the house card: gradient, hairline, real shadow
///   InviteTicket    — the code, as a torn ticket you want to hand over

// ══════════════════════════════════════════════════════════════════════
//  ATMOSPHERE — the light behind the instrument
// ══════════════════════════════════════════════════════════════════════

/// A slow bloom of the squad's colour behind the masthead, dissolving
/// into the page. It drifts rather than pulses — movement you feel
/// without noticing, which is the difference between expensive and
/// noisy.
class SquadAtmosphere extends StatefulWidget {
  final Color accent;
  const SquadAtmosphere({super.key, required this.accent});

  @override
  State<SquadAtmosphere> createState() => _SquadAtmosphereState();
}

class _SquadAtmosphereState extends State<SquadAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _AtmospherePainter(
            accent: widget.accent,
            t: Curves.easeInOut.transform(_c.value),
          ),
        ),
      ),
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  final Color accent;
  final double t; // 0..1, eased
  const _AtmospherePainter({required this.accent, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final drift = 0.05 * t;

    // 1 · the squad's colour, bleeding out from behind the dial.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0, -0.35 + drift),
          radius: 1.05,
          colors: [
            accent.withValues(alpha: 0.22 + 0.07 * t),
            accent.withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(rect),
    );

    // 2 · a cold key light top-left, so the band has a direction.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.85 + 0.12 * t, -0.95),
          radius: 0.95,
          colors: [
            Colors.white.withValues(alpha: 0.055),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    // 3 · dissolve into the page — no hard seam where the band ends.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, AppColors.base],
          stops: [0.52, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_AtmospherePainter old) =>
      old.t != t || old.accent != accent;
}

// ══════════════════════════════════════════════════════════════════════
//  CREST — every squad gets a mark, free
// ══════════════════════════════════════════════════════════════════════

/// A hexagonal crest carrying the squad's initials. Generated, so a
/// squad has an identity the second it's founded — no upload, no
/// picker, nothing to fill in. Naming your squad is the only cost and
/// you get a badge for it.
class SquadCrest extends StatelessWidget {
  final String name;
  final Color accent;
  final double size;
  const SquadCrest({
    super.key,
    required this.name,
    required this.accent,
    this.size = 54,
  });

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '—';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(child: CustomPaint(painter: _CrestPainter(accent))),
        Text(_initials,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: size * 0.32,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w900,
            )),
      ]),
    );
  }
}

class _CrestPainter extends CustomPainter {
  final Color accent;
  const _CrestPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 1.5;

    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final p = centre + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.34),
            accent.withValues(alpha: 0.08),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = accent.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_CrestPainter old) => old.accent != accent;
}

// ══════════════════════════════════════════════════════════════════════
//  CHAPTER MARK — sections as chapters
// ══════════════════════════════════════════════════════════════════════

/// A numbered chapter heading with a rule that runs out into the page.
/// The room reads as a sequence you move down rather than a pile of
/// unrelated widgets.
class ChapterMark extends StatelessWidget {
  final String index; // '01'
  final String title;
  final String sub;
  final Color accent;
  final Widget? trailing;

  const ChapterMark({
    super.key,
    required this.index,
    required this.title,
    required this.sub,
    this.accent = AppColors.red,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.38)),
            ),
            child: Text(index,
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                )),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w900,
                )),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.white.withValues(alpha: 0.16),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ]),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(sub,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              )),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  PANEL — the house card
// ══════════════════════════════════════════════════════════════════════

/// One card shape for the whole room: a gradient tinted by the accent,
/// a hairline border, and a real dropped shadow so it sits ON the page
/// instead of being painted onto it.
class Panel extends StatelessWidget {
  final Widget child;
  final Color accent;
  final bool hot;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const Panel({
    super.key,
    required this.child,
    this.accent = AppColors.red,
    this.hot = false,
    this.padding = const EdgeInsets.fromLTRB(16, 15, 16, 15),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
                accent.withValues(alpha: hot ? 0.12 : 0.045), AppColors.surface2),
            AppColors.surface1,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: accent.withValues(alpha: hot ? 0.5 : 0.18)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 10)),
          if (hot)
            BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 28),
        ],
      ),
      child: child,
    );
    if (onTap == null) return body;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: body,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  INVITE TICKET — the code, as something you hand over
// ══════════════════════════════════════════════════════════════════════

/// The squad code was a grey strip with two icons on it. It's the single
/// most important object in the whole social layer — it's the only way
/// anyone gets in — so it's now a torn ticket: notched, perforated, and
/// obviously meant to be given to someone.
class InviteTicket extends StatelessWidget {
  final String code;
  final int openSeats;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final Color accent;

  const InviteTicket({
    super.key,
    required this.code,
    required this.openSeats,
    required this.onCopy,
    required this.onShare,
    this.accent = AppColors.red,
  });

  @override
  Widget build(BuildContext context) {
    final full = openSeats <= 0;
    return CustomPaint(
      painter: _TicketPainter(accent: accent),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
        child: Row(children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCopy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.confirmation_number_rounded,
                        size: 11, color: accent),
                    const SizedBox(width: 5),
                    Text('SQUAD CODE',
                        style: GoogleFonts.inter(
                          color: accent,
                          fontSize: 8.5,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                        )),
                  ]),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(code,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 26,
                          height: 1.05,
                          letterSpacing: 7,
                          fontWeight: FontWeight.w900,
                        )),
                  ),
                  const SizedBox(height: 5),
                  Text(
                      full
                          ? 'Squad is full — five is the most.'
                          : openSeats == 1
                              ? 'One seat left. Send it to him.'
                              : '$openSeats seats left. Send it to them.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(width: 22),
          Column(mainAxisSize: MainAxisSize.min, children: [
            _TicketAction(
                icon: Icons.ios_share_rounded,
                label: 'SEND',
                accent: accent,
                filled: true,
                onTap: onShare),
            const SizedBox(height: 8),
            _TicketAction(
                icon: Icons.copy_rounded,
                label: 'COPY',
                accent: accent,
                onTap: onCopy),
          ]),
        ]),
      ),
    );
  }
}

class _TicketAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool filled;
  final VoidCallback onTap;
  const _TicketAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: filled
              ? accent.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: filled
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.12)),
          boxShadow: filled
              ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 14)]
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 13,
              color: filled ? Colors.white : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                color: filled ? Colors.white : AppColors.textSecondary,
                fontSize: 9.5,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w900,
              )),
        ]),
      ),
    );
  }
}

class _TicketPainter extends CustomPainter {
  final Color accent;
  const _TicketPainter({required this.accent});

  /// Where the stub tears off — the notches and the perforation.
  static const _split = 0.685;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    var path = Path()
      ..addRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(20)));

    final x = size.width * _split;
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: 8))
      ..addOval(Rect.fromCircle(center: Offset(x, size.height), radius: 8));
    path = Path.combine(PathOperation.difference, path, notches);

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
                accent.withValues(alpha: 0.13), AppColors.surface2),
            AppColors.surface1,
          ],
        ).createShader(rect),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: 0.45),
    );

    final dash = Paint()
      ..color = accent.withValues(alpha: 0.30)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var y = 14.0; y < size.height - 12; y += 8) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 4), dash);
    }
  }

  @override
  bool shouldRepaint(_TicketPainter old) => old.accent != accent;
}
