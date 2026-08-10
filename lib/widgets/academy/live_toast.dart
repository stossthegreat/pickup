import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../navigation/app_router.dart';
import '../../services/live_events.dart';
import '../../theme/app_colors.dart';
import 'game_button.dart';

/// THE TOAST HOST — wraps the whole app so a live event can land on any
/// screen. Queued (never stacked into a mess), spring entrance, haptic,
/// swipe-up to dismiss, tap to jump to the thing that happened.
///
/// This is what makes the app feel alive instead of inspected.
class LiveToastHost extends StatefulWidget {
  final Widget child;
  const LiveToastHost({super.key, required this.child});

  @override
  State<LiveToastHost> createState() => _LiveToastHostState();
}

class _LiveToastHostState extends State<LiveToastHost> {
  final List<LiveEvent> _queue = [];
  LiveEvent? _current;
  StreamSubscription<LiveEvent>? _sub;
  Timer? _dismiss;

  @override
  void initState() {
    super.initState();
    _sub = LiveEvents.stream.listen(_enqueue);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dismiss?.cancel();
    super.dispose();
  }

  void _enqueue(LiveEvent e) {
    _queue.add(e);
    if (_current == null) _next();
  }

  void _next() {
    _dismiss?.cancel();
    if (_queue.isEmpty) {
      if (mounted) setState(() => _current = null);
      return;
    }
    final e = _queue.removeAt(0);
    if (!mounted) return;
    setState(() => _current = e);
    e.big ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
    _dismiss = Timer(
        Duration(milliseconds: e.big ? 4200 : 3200), _next);
  }

  void _hide() {
    _dismiss?.cancel();
    _next();
  }

  @override
  Widget build(BuildContext context) {
    final e = _current;
    return Stack(children: [
      widget.child,
      if (e != null)
        Positioned(
          top: MediaQuery.of(context).padding.top + 6,
          left: 12,
          right: 12,
          child: _Toast(
            key: ValueKey(e),
            event: e,
            onDismiss: _hide,
          ),
        ),
    ]);
  }
}

class _Toast extends StatelessWidget {
  final LiveEvent event;
  final VoidCallback onDismiss;
  const _Toast({super.key, required this.event, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Dismissible(
      key: ValueKey(e.hashCode),
      direction: DismissDirection.up,
      onDismissed: (_) => onDismiss(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.selectionClick();
            onDismiss();
            if (e.route != null) appRouter.push(e.route!);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(AppColors.surface2, e.color, 0.16)!,
                  AppColors.surface1,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: e.color.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 10)),
                BoxShadow(
                    color: e.color.withValues(alpha: e.big ? 0.36 : 0.20),
                    blurRadius: 30),
              ],
            ),
            child: Row(children: [
              // Portrait if we have one, else the icon disc.
              if (e.thumbAsset != null)
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: e.color.withValues(alpha: 0.7), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(e.thumbAsset!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(e.icon, color: e.color, size: 20)),
                  ),
                )
              else
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: e.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: e.color.withValues(alpha: 0.5)),
                  ),
                  child: Icon(e.icon, color: e.color, size: 21),
                )
                    .animate(
                        onPlay: (c) => e.big ? c.repeat(reverse: true) : null)
                    .scaleXY(begin: 1, end: e.big ? 1.08 : 1, duration: 700.ms),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12.5,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w900,
                        )),
                    if (e.subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(e.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ],
                ),
              ),
              if (e.stat != null) ...[
                const SizedBox(width: 10),
                Text(e.stat!,
                    style: GoogleFonts.inter(
                      color: e.color,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                            color: e.color.withValues(alpha: 0.5),
                            blurRadius: 14)
                      ],
                    )).animate().scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1, 1),
                    delay: 120.ms,
                    duration: 420.ms,
                    curve: Curves.elasticOut),
              ],
            ]),
          ),
        ),
      ),
    )
        .animate()
        .slideY(
            begin: -1.4,
            end: 0,
            duration: 520.ms,
            curve: Curves.easeOutBack)
        .fadeIn(duration: 220.ms);
  }
}

/// "WHILE YOU WERE GONE" — the catch-up card stack shown on app open
/// when things happened since last time. Duolingo/Strava's trick: never
/// let a return visit start with a blank screen.
class CatchUpSheet extends StatelessWidget {
  final List<LiveEvent> events;
  const CatchUpSheet({super.key, required this.events});

  static Future<void> show(BuildContext context, List<LiveEvent> events) {
    if (events.isEmpty) return Future.value();
    HapticFeedback.mediumImpact();
    return showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'catch up',
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, __, ___) => CatchUpSheet(events: events),
      transitionBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('WHILE YOU WERE GONE',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 11,
                  letterSpacing: 3.2,
                  fontWeight: FontWeight.w900,
                )).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 18),
            for (final (i, e) in events.take(5).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(AppColors.surface2, e.color, 0.14)!,
                        AppColors.surface1,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: e.color.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    Icon(e.icon, size: 19, color: e.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.title.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w900,
                              )),
                          if (e.subtitle != null)
                            Text(e.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                )),
                        ],
                      ),
                    ),
                    if (e.stat != null)
                      Text(e.stat!,
                          style: GoogleFonts.inter(
                            color: e.color,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          )),
                  ]),
                ),
              )
                  .animate()
                  .fadeIn(delay: (140 + i * 110).ms, duration: 300.ms)
                  .slideX(begin: 0.12, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 14),
            SizedBox(
              width: 220,
              child: GameButton(
                label: 'GET BACK IN',
                pulse: true,
                onTap: () => Navigator.of(context).pop(),
              ),
            ).animate().fadeIn(delay: 700.ms),
          ]),
        ),
      ),
    );
  }
}
