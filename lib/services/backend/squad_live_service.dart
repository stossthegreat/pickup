import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../live_events.dart';
import '../roster.dart';
import 'auth_service.dart';
import 'backend_service.dart';
import 'squad_service.dart';

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
        case 'rankup':
          LiveEvents.milestone(
              who, 'ranked up to ${payload['tier'] ?? ''}',
              route: '/leaderboard');
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
