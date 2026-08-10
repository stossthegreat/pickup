import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../live_events.dart';
import '../roster.dart';
import 'auth_service.dart';
import 'backend_service.dart';
import 'squad_service.dart';

/// WHILE YOU WERE GONE — what the squad did since the user last looked.
///
/// The rule every habit app follows: a returning user must never open
/// to a static screen. If anything happened, it gets shown first, as a
/// stack of cards, before the app settles.
class CatchUpService {
  static const _key = 'catchup_last_seen_ms';

  /// Minimum gap before we bother interrupting — nobody wants a
  /// "while you were gone" after a 30-second tab switch.
  static const _minGap = Duration(hours: 2);

  static Future<DateTime?> _lastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, DateTime.now().millisecondsSinceEpoch);
  }

  static String? _thumb(String? vibe) {
    if (vibe == null) return null;
    for (final g in kRoster) {
      if (g.vibeKey == vibe) return g.asset;
    }
    return null;
  }

  /// Everything worth showing since the last visit. Empty list = don't
  /// interrupt. Never throws — a dead network just means no catch-up.
  static Future<List<LiveEvent>> collect() async {
    if (!BackendService.enabled || AuthService.userId == null) return const [];
    try {
      final since = await _lastSeen();
      // First ever launch: nothing to catch up on, just start the clock.
      if (since == null) {
        await markSeen();
        return const [];
      }
      if (DateTime.now().difference(since) < _minGap) return const [];

      final squad = await SquadService.mySquad();
      if (squad == null) return const [];

      final roster = await SquadService.roster(squad.id);
      final names = {
        for (final m in roster) m.userId: (m.handle ?? 'A squadmate')
      };
      final events = await SquadService.pulse(squad.id, limit: 40);
      final me = AuthService.userId;

      final out = <LiveEvent>[];
      for (final e in events) {
        if (e.createdAt.isBefore(since)) continue;
        if (e.actorId == me) continue; // your own work isn't news
        final who = names[e.actorId] ?? 'A squadmate';
        final thumb = _thumb(e.payload['vibe'] as String?);
        switch (e.kind) {
          case 'completed':
            out.add(LiveEvent(
              title: who,
              subtitle: 'completed ${e.payload['mission'] ?? 'a mission'}',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF2EE87A),
              thumbAsset: thumb,
              stat: e.payload['xp'] != null ? '+${e.payload['xp']}' : null,
            ));
            break;
          case 'committed':
            out.add(LiveEvent(
              title: who,
              subtitle: 'called his shot',
              icon: Icons.campaign_rounded,
              color: const Color(0xFFE8222A),
              thumbAsset: thumb,
            ));
            break;
          case 'scored':
            out.add(LiveEvent(
              title: who,
              subtitle: 'scored on a roleplay',
              icon: Icons.graphic_eq_rounded,
              color: const Color(0xFF38BDF8),
              stat: '${e.payload['score'] ?? ''}',
            ));
            break;
          case 'joined':
            out.add(LiveEvent(
              title: who,
              subtitle: 'joined the squad',
              icon: Icons.bolt_rounded,
              color: const Color(0xFFA8A8B2),
            ));
            break;
        }
        if (out.length >= 5) break;
      }
      await markSeen();
      return out;
    } catch (_) {
      return const [];
    }
  }
}
