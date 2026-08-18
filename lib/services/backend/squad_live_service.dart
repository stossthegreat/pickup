import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../live_events.dart';
import '../roster.dart';
import 'auth_service.dart';
import 'backend_service.dart';
import 'squad_service.dart';
import '../../widgets/academy/callout.dart';
import '../../theme/app_colors.dart';

/// GLOBAL SQUAD WATCHER — started once at launch and never stopped.
///
/// The Squad Room already repaints while it's open, but that's not what
/// makes an app feel alive. This listens app-wide: your mate calls his
/// shot while you're mid-roleplay and a toast slides down over whatever
/// you're doing. That's the ping that pulls men back.
class SquadLiveService {
  static RealtimeChannel? _channel;
  static String? _squadId;
  static Map<String, String> _names = const {};

  static bool get running => _channel != null;

  /// Safe to call repeatedly (app launch, after joining a squad).
  static Future<void> start() async {
    if (!BackendService.enabled || AuthService.userId == null) return;
    final squad = await SquadService.mySquad();
    if (squad == null) return;
    if (_squadId == squad.id && _channel != null) return; // already live

    await stop();
    _squadId = squad.id;

    // Cache handles so a toast can say a name, not a uuid.
    final roster = await SquadService.roster(squad.id);
    _names = {
      for (final m in roster) m.userId: (m.handle ?? 'A squadmate'),
    };

    _channel = SquadService.watchPulseEvents(squad.id, _onEvent);
  }

  static Future<void> stop() async {
    final c = _channel;
    _channel = null;
    _squadId = null;
    if (c != null) SquadService.unwatch(c);
  }

  static void _onEvent(Map<String, dynamic> row) {
    try {
      final actor = row['actor'] as String?;
      if (actor == null || actor == AuthService.userId) return; // not your own
      final kind = row['kind'] as String? ?? '';
      final payload =
          (row['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
      final who = _names[actor] ?? 'A squadmate';

      final thumb = thumbFor(payload['vibe'] as String?);

      switch (kind) {
        case 'started':
          LiveEvents.fire(LiveEvent(
            title: who,
            subtitle: 'is on ${payload['mission'] ?? 'a mission'} right now',
            icon: Icons.play_circle_fill_rounded,
            color: const Color(0xFF8B94F5),
            thumbAsset: thumb,
            route: '/squad',
          ));
          break;
        case 'committed':
          LiveEvents.squad(who,
              'called their shot — ${payload['mission'] ?? 'today\'s mission'}');
          break;
        case 'completed':
          LiveEvents.fire(LiveEvent(
            title: who,
            subtitle:
                'completed ${payload['mission'] ?? 'the mission'}',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF2EE87A),
            thumbAsset: thumb,
            route: '/squad',
            stat: payload['xp'] != null ? '+${payload['xp']}' : '+100',
          ));
          break;
        case 'scored':
          LiveEvents.squad(who, 'scored on a roleplay',
              stat: '${payload['score'] ?? ''}');
          break;
        case 'joined':
          LiveEvents.squad(who, 'joined the squad');
          break;
        case 'nudge':
          // THE ONE EVENT WITH A NAMED TARGET. Aimed at me → park the
          // full-screen callout for the next screen with a context (the
          // missions tab drains it) and fire a toast so it also lands
          // right now if he's mid-session. Aimed at someone else → the
          // squad sees the callout happen, which is half the pressure.
          if (payload['target'] == AuthService.userId) {
            Callout.pending = who;
            LiveEvents.fire(LiveEvent(
              title: who,
              subtitle: 'called YOU out. The squad saw it.',
              icon: Icons.campaign_rounded,
              color: AppColors.red,
              route: '/squad',
            ));
          } else {
            LiveEvents.squad(
                who, 'called out ${payload['handle'] ?? 'a squadmate'}');
          }
          break;
        case 'rankup':
          // The payload used to carry a `tier` string written by
          // score-voice — one of the five identity words, derived from a
          // rating that moves on every solo practice run. Broadcasting
          // it told four other men he'd "ranked up to INITIATE" on the
          // back of a good daily. See standing.dart: the identity ladder
          // is earned in days and is announced by the ascend ceremony,
          // not by a toast off someone else's voice score.
          LiveEvents.milestone(who, 'levelled up', route: '/leaderboard');
          break;
      }
    } catch (e) {
      debugPrint('SquadLiveService._onEvent: $e');
    }
  }

  /// The AI woman a squad event referenced, for a portrait in the toast.
  static String? thumbFor(String? vibeKey) {
    if (vibeKey == null) return null;
    for (final g in kRoster) {
      if (g.vibeKey == vibeKey) return g.asset;
    }
    return null;
  }
}
