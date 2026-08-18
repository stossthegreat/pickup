import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/squad_service.dart';
import '../../services/backend/tiers.dart';
import '../../services/economy.dart';
import '../../theme/app_colors.dart';

/// THE PULSE — everything the squad did, behind one icon.
///
/// It used to be section 07, a list running down the bottom of the squad
/// screen. It's the least urgent thing on there and it was taking the
/// most vertical space, competing with the challenges for attention and
/// winning by sheer length. As a badged icon it says the same thing in
/// twenty square points and opens on demand.
///
/// TWO FIXES ON THE WAY IN:
///
///  · SCORES ARE ON THE ONE SCALE. The feed was printing "YOU scored
///    2590" and "ANON scored 6629" — the raw 0–9999 storage band,
///    leaking straight onto a screen while every other surface in the
///    app says 26 and 66. See economy.dart rule 2; the feed was the last
///    place it was getting out.
///
///  · TIMES ARE RELATIVE. "23:54" tells a man nothing — he has to work
///    out whether that was tonight or a week ago. "2h" and "yesterday"
///    are what he's actually asking.
class PulseSheet {
  static Future<void> show(
    BuildContext context, {
    required List<SquadEvent> events,
    required List<SquadMember> roster,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PulseSheet(events: events, roster: roster),
    );
  }
}

class _PulseSheet extends StatelessWidget {
  final List<SquadEvent> events;
  final List<SquadMember> roster;
  const _PulseSheet({required this.events, required this.roster});

  String _who(String id) {
    if (id == AuthService.userId) return 'YOU';
    for (final m in roster) {
      if (m.userId == id) return (m.handle ?? 'ANON').toUpperCase();
    }
    return 'ANON';
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(maxHeight: h * 0.82),
      decoration: const BoxDecoration(
        color: AppColors.base,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 14),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 20),
        Text('THE PULSE',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              letterSpacing: 4.4,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 4),
        Text('Everything the squad did.',
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 18),
        Flexible(
          child: events.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
                  child: Text('Silence. Be the first name on today.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppColors.textTertiary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      )),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                      20, 0, 20, 24 + MediaQuery.of(context).padding.bottom),
                  itemCount: events.length,
                  itemBuilder: (_, i) => _Row(
                    event: events[i],
                    who: _who(events[i].actorId),
                    first: i == 0,
                    last: i == events.length - 1,
                  ).animate().fadeIn(
                      delay: (24 * (i > 10 ? 10 : i)).ms, duration: 220.ms),
                ),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final SquadEvent event;
  final String who;
  final bool first;
  final bool last;
  const _Row(
      {required this.event,
      required this.who,
      required this.first,
      required this.last});

  /// Icon and tone by kind, so the feed is scannable by colour before
  /// it's read.
  ({IconData icon, Color tone}) get _look => switch (event.kind) {
        'scored' => (icon: Icons.graphic_eq_rounded, tone: kNeon),
        'completed' => (
            icon: Icons.check_circle_rounded,
            tone: AppColors.signalGreen
          ),
        'committed' => (
            icon: Icons.radio_button_checked_rounded,
            tone: AppColors.red
          ),
        'daily_started' => (
            icon: Icons.graphic_eq_rounded,
            tone: AppColors.red
          ),
        'nudge' => (icon: Icons.campaign_rounded, tone: AppColors.signalAmber),
        'joined' => (icon: Icons.bolt_rounded, tone: AppColors.accent),
        _ => (icon: Icons.circle, tone: AppColors.textMuted),
      };

  String get _line {
    final p = event.payload;
    final title = (p['title'] as String?) ?? (p['mission'] as String?);
    switch (event.kind) {
      case 'scored':
        // THE LEAK. This printed the raw 0–9999 grade — "YOU scored
        // 2590" — while every other surface said 26. One scale, and
        // this was the last place it was getting out.
        final raw = (p['score'] as num?)?.toInt();
        if (raw == null) return '$who was scored';
        final shown = raw > 100 ? Economy.aiScoreFromVoice(raw) : raw;
        return '$who scored $shown';
      case 'completed':
        return title == null ? '$who completed a mission' : '$who completed $title';
      case 'committed':
        return title == null
            ? '$who called their shot'
            : '$who called their shot — $title';
      case 'daily_started':
        return '$who stepped into the rizz-off';
      case 'nudge':
        final target = (p['handle'] as String?)?.toUpperCase();
        return target == null
            ? '$who nudged someone'
            : '$who nudged $target';
      case 'joined':
        return '$who joined the squad';
      default:
        return '$who made a move';
    }
  }

  /// Relative, never a clock face. "23:54" makes a man do arithmetic to
  /// find out whether it was tonight.
  String get _when {
    final d = DateTime.now().difference(event.createdAt);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays == 1) return 'yesterday';
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final look = _look;
    final mine = event.actorId == AuthService.userId;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // The spine.
        Column(children: [
          Container(width: 1.5, height: first ? 0 : 10, color: AppColors.divider),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: look.tone.withValues(alpha: 0.14),
              border: Border.all(color: look.tone.withValues(alpha: 0.55)),
            ),
            child: Icon(look.icon, size: 12, color: look.tone),
          ),
          if (!last)
            Expanded(child: Container(width: 1.5, color: AppColors.divider)),
        ]),
        const SizedBox(width: 13),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: first ? 2 : 12, bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_line,
                    style: GoogleFonts.inter(
                      color: mine ? Colors.white : AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 3),
                Text(_when,
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
