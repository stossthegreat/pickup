import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One thing that just happened, worth interrupting the user for.
class LiveEvent {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;

  /// Portrait to show instead of the icon (squad mate / AI woman).
  final String? thumbAsset;

  /// Big number on the right — XP, points, score.
  final String? stat;

  /// Where tapping it takes you.
  final String? route;

  /// Heavier entrance + confetti for genuine milestones.
  final bool big;

  const LiveEvent({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.thumbAsset,
    this.stat,
    this.route,
    this.big = false,
  });
}

/// THE LIVE LAYER — the app's nervous system.
///
/// Anything worth knowing fires through here and lands on screen as a
/// toast, wherever the user is. Without this the app is a set of pages
/// you have to go and inspect; with it, the app talks to you.
///
///   LiveEvents.xp(50, 'Comment landed');
///   LiveEvents.squad('MARCUS', 'completed The Compliment');
///   LiveEvents.milestone('PROMOTED', 'You climbed to SAVAGE LEAGUE');
class LiveEvents {
  static final _ctrl = StreamController<LiveEvent>.broadcast();
  static Stream<LiveEvent> get stream => _ctrl.stream;

  static void fire(LiveEvent e) => _ctrl.add(e);

  // ── Shorthands for the events we fire most ────────────────────────

  /// The user earned something.
  static void xp(int amount, String reason) => fire(LiveEvent(
        title: reason,
        subtitle: 'Nice.',
        icon: Icons.bolt_rounded,
        color: AppColors.accent,
        stat: '+$amount XP',
      ));

  /// A squad mate did something — the social ping that pulls people back.
  static void squad(String who, String what,
          {String? thumbAsset, String? stat}) =>
      fire(LiveEvent(
        title: who,
        subtitle: what,
        icon: Icons.shield_rounded,
        color: AppColors.red,
        thumbAsset: thumbAsset,
        stat: stat,
        route: '/squad',
      ));

  /// You just scored something.
  static void scored(int score, String scenario) => fire(LiveEvent(
        title: 'Session scored',
        subtitle: scenario,
        icon: Icons.graphic_eq_rounded,
        color: AppColors.measure,
        stat: '$score',
      ));

  /// A real milestone — promotion, rank up, streak, crown.
  static void milestone(String title, String subtitle,
          {Color color = const Color(0xFF2EE87A), String? route}) =>
      fire(LiveEvent(
        title: title,
        subtitle: subtitle,
        icon: Icons.emoji_events_rounded,
        color: color,
        route: route,
        big: true,
      ));

  /// Someone passed you / you passed someone.
  static void rank(String title, String subtitle, {bool good = true}) =>
      fire(LiveEvent(
        title: title,
        subtitle: subtitle,
        icon: good
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded,
        color: good ? const Color(0xFF2EE87A) : AppColors.red,
        route: '/leaderboard',
      ));
}
