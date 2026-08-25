import 'mission_engine.dart';
import 'local_store_service.dart';

/// HOW MANY OF TODAY'S MOVES THIS PHONE HAS SEEN HIM MAKE.
///
/// THE PROBLEM THIS EXISTS FOR — two mission systems that never meet.
///
/// Home runs [MissionEngine]: ids like `aiPost:amara`, generated on the
/// device from his unlocked roster, ticked into SharedPreferences. The
/// squad board runs [MissionService]: rows out of the Supabase `missions`
/// table, ids are row UUIDs, completion written server-side. The two
/// share not one id — `MissionService.complete('aiPost:amara')` matches
/// no row and silently updates nothing.
///
/// So a man who finished all five missions on Home walked into the squad
/// room and read "nobody has moved yet", 0/15, gauge at zero. His own
/// work, invisible on the one screen built to show it.
///
/// [SquadDay] already knows how to reconcile this: hand it `myMoves` and
/// it takes the HIGHER of what the server saw and what the phone knows,
/// for that man only. It was already being passed on Squad home — and
/// nowhere else, which is why the room and the home strip still read
/// zero. This is that count, in one place, so a fourth screen can't be
/// added without it.
///
/// LIMIT, STATED PLAINLY: this fixes what HE sees. His squadmates still
/// cannot see missions he does on Home, because nothing about them ever
/// leaves the device. Closing that needs a server write path for
/// locally-generated missions — a schema change, not a display fix.
abstract final class MyMoves {
  /// Completed missions on today's local board, 0..5. Never throws —
  /// a failure here must not cost the screen its other numbers, and 0
  /// is exactly the behaviour that existed before the bridge.
  static Future<int> today() async {
    try {
      final missions = await MissionEngine.loadToday();
      var n = 0;
      for (final m in missions) {
        if (await LocalStoreService.isMissionDoneToday(m.id)) n++;
      }
      return n;
    } catch (_) {
      return 0;
    }
  }
}
