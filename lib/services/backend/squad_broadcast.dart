import 'package:flutter/foundation.dart';

import '../roster.dart';
import 'squad_service.dart';

/// Pushes what the user is DOING to his squad, so the room shows real
/// activity instead of only finished work.
///
/// The difference this makes: "MARCUS is on Daisy's post right now" is
/// a far stronger pull than only ever hearing "Marcus completed a
/// mission". Live beats reported.
///
/// Every call is fire-and-forget and no-ops without a squad — the solo
/// experience never pays for the social layer.
class SquadBroadcast {
  static String? _cachedSquadId;
  static DateTime? _cachedAt;

  /// Cheap squad lookup — the id is stable, so cache it for a few
  /// minutes rather than round-tripping on every mission tap.
  static Future<String?> _squadId() async {
    final now = DateTime.now();
    if (_cachedSquadId != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < const Duration(minutes: 5)) {
      return _cachedSquadId;
    }
    final squad = await SquadService.mySquad();
    _cachedSquadId = squad?.id;
    _cachedAt = now;
    return _cachedSquadId;
  }

  /// Forget the cached squad (after joining/leaving).
  static void invalidate() {
    _cachedSquadId = null;
    _cachedAt = null;
  }

  static String? _vibeOf(String? girlId) {
    if (girlId == null) return null;
    try {
      return girlById(girlId).vibeKey;
    } catch (_) {
      return null;
    }
  }

  /// He just opened a mission — the squad sees him working, live.
  static Future<void> started(String title, {String? girlId}) async {
    try {
      final id = await _squadId();
      if (id == null) return;
      await SquadService.postEvent(id, 'started', {
        'mission': title,
        if (_vibeOf(girlId) != null) 'vibe': _vibeOf(girlId),
      });
    } catch (e) {
      debugPrint('SquadBroadcast.started: $e');
    }
  }

  /// He finished it — with the XP so the toast can carry a number.
  static Future<void> completed(String title,
      {int? xp, String? girlId}) async {
    try {
      final id = await _squadId();
      if (id == null) return;
      await SquadService.postEvent(id, 'completed', {
        'mission': title,
        if (xp != null) 'xp': xp,
        if (_vibeOf(girlId) != null) 'vibe': _vibeOf(girlId),
      });
    } catch (e) {
      debugPrint('SquadBroadcast.completed: $e');
    }
  }
}
