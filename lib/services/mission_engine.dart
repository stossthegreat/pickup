import 'package:shared_preferences/shared_preferences.dart';

import 'local_store_service.dart';
import 'mission_catalog.dart';
import 'roster.dart';
import 'streak_service.dart';

/// Generates the day's missions: 3 AI + 2 real, chosen by the user's LEVEL
/// so they escalate and hit the deep end fast. The set is frozen for the
/// calendar day (stored as a list of ids) and rolls fresh tomorrow.
class MissionEngine {
  static const _kYmd = 'imhim.today.ymd.v1';
  static const _kIds = 'imhim.today.ids.v1';

  static int _ymd(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  /// Effective difficulty: self-rated start level + how far into the
  /// 60-day ascension they are. Beginners still get pushed up fast.
  static Future<int> effectiveTier() async {
    final level = await LocalStoreService.userLevel();     // 0..3
    final snap = await StreakService.progress();
    final boost = (snap.ascensionDay ~/ 12);               // +1 every ~12 days
    return (1 + level + boost).clamp(1, 5);
  }

  static Future<List<MissionSpec>> loadToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _ymd(DateTime.now());
    List<String> ids;
    if (prefs.getInt(_kYmd) == today &&
        (prefs.getStringList(_kIds)?.isNotEmpty ?? false)) {
      ids = prefs.getStringList(_kIds)!;
    } else {
      ids = await _generate(today);
      await prefs.setInt(_kYmd, today);
      await prefs.setStringList(_kIds, ids);
    }
    return [for (final id in ids) specFromId(id)].whereType<MissionSpec>().toList();
  }

  static Future<List<String>> _generate(int today) async {
    final level = await LocalStoreService.userLevel();
    final snap = await StreakService.progress();
    final day = snap.ascensionDay;
    final eff = (1 + level + (day ~/ 12)).clamp(1, 5);
    final ids = <String>[];

    // Only ever hand out missions for girls he's actually UNLOCKED on the
    // 60-day journey — a mission can never target a locked girl. At least the
    // three Day-1 starters are always available.
    final roster = kRoster.where((g) => g.unlockDay <= day).toList();
    final pool = roster.isNotEmpty ? roster : kRoster.take(3).toList();

    // ── DAY 1 — deliberately gentle + crystal clear ─────────────────────────
    // No matter how confident he rated himself, day one is an easy win, not a
    // street approach. Two in-app "comment on her post" tasks, his FIRST voice
    // roleplay (the big hook — hearing her reply out loud is what sells the
    // app), and the two softest real-world steps (reply to a story, hold eye
    // contact + smile). Rose-light so the first impression — and the App Review
    // recording — is welcoming, then it escalates hard from day two.
    if (day <= 1) {
      final gs = pool.length >= 3 ? pool : kRoster;
      return [
        aiPostMission(gs[0]).id,   // comment on one girl's post
        aiPostMission(gs[1]).id,   // comment on a second girl's post
        aiVoiceMission(gs[2]).id,  // first voice roleplay — the big one
        'real:story',              // reply to a story (coach helps craft it)
        'real:eye',                // hold eye contact + smile
      ];
    }

    // ── 3 AI missions ──
    // 1) accessible entry: comment on an easy girl's post (never scary).
    final easy = pool.where((g) => g.tier <= (eff - 1).clamp(1, 5)).toList();
    final entryPool = easy.isNotEmpty ? easy : pool;
    final entry = entryPool[today % entryPool.length];
    ids.add(aiPostMission(entry).id);

    // 2) + 3) voice and text with girls around the effective tier (escalating).
    final band = pool
        .where((g) => g.tier >= (eff - 1).clamp(1, 5) && g.tier <= (eff + 1).clamp(1, 5))
        .toList();
    final bandPool = band.isNotEmpty ? band : pool;
    final voiceGirl = bandPool[(today + 1) % bandPool.length];
    ids.add(aiVoiceMission(voiceGirl).id);
    final textGirl = bandPool[(today + 3) % bandPool.length];
    // avoid the exact same girl+kind duplicate id
    ids.add(aiTextMission(textGirl.id == voiceGirl.id
        ? bandPool[(today + 4) % bandPool.length]
        : textGirl).id);

    // ── 2 real missions: one at tier, one a stretch above (deep end) ──
    final atTier = realLadderForTier(eff);
    ids.add(atTier[today % atTier.length].id);
    final stretch = realLadderForTier((eff + 1).clamp(1, 5));
    var pick = stretch[(today + 2) % stretch.length];
    if (pick.id == ids.last) pick = stretch[(today + 3) % stretch.length];
    ids.add(pick.id);

    return ids;
  }

  /// Force a fresh roll (e.g. after a big level change). Rare.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kYmd);
    await prefs.remove(_kIds);
  }
}
