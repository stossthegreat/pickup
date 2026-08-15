import 'package:flutter/foundation.dart';

import 'local_store_service.dart';
import 'mission_catalog.dart';
import 'mission_engine.dart';
import 'rewards.dart';
import 'roster.dart';

/// ══════════════════════════════════════════════════════════════════════
///  TWO BIRDS, ONE STONE
/// ══════════════════════════════════════════════════════════════════════
///
/// THE PROBLEM. A man was being asked to hold two voice conversations a
/// day: the AI VOICE MISSION on Home, and the VOICE RIZZ-OFF on the
/// squad screen. Two different women, two separate flows, both counted
/// separately — and he has minutes for ONE. Live voice is the single
/// most expensive thing this app does, so the second one was never going
/// to happen; it just sat there unticked making him feel behind.
///
/// Same story in writing: an AI TEXT mission and a MESSAGE BATTLE, the
/// same activity twice under two names.
///
/// THE FIX. The daily challenge IS the mission. One conversation, and it
/// ticks both — the challenge card on the squad screen and the mission
/// on Home. He does the work once and both systems see it.
///
/// ── WHICH WAY ROUND, AND WHY ─────────────────────────────────────────
///
/// The obvious version is to point the daily challenge at whichever
/// woman his mission names. That breaks the product: the server ASSIGNS
/// today's woman, grades against her, and gives every man on earth the
/// same one — which is the entire basis of the Rizz-Off comparison and
/// the daily leaderboard. Re-pointing the client at a different woman
/// would have the app scoring one conversation against another woman's
/// rubric.
///
/// So it runs the other way. The daily keeps its global woman, and
/// FINISHING IT CREDITS THE MISSION. He has one conversation, the
/// challenge card ticks, and the AI mission on Home ticks with it —
/// which is what he actually wanted, without spending the fairness that
/// makes the Rizz-Off worth running.
///
/// [girlFor] is kept for surfaces that legitimately want the mission's
/// own woman (the mission card itself), and is deliberately NOT used by
/// the challenge cards.
///
abstract final class TodayTargets {
  /// Today's AI voice mission, or null if his five don't include one.
  static Future<MissionSpec?> voice() => _find(MissionKind.aiVoice);

  /// Today's AI text mission — the one the message battle now doubles as.
  static Future<MissionSpec?> chat() => _find(MissionKind.aiText);

  static Future<MissionSpec?> _find(MissionKind kind) async {
    try {
      final today = await MissionEngine.loadToday();
      for (final m in today) {
        if (m.kind == kind && m.girlId != null) return m;
      }
      return null;
    } catch (e) {
      debugPrint('TodayTargets._find: $e');
      return null;
    }
  }

  /// The woman a challenge should land on.
  ///
  /// Falls back to [fallback] when his five don't happen to include one
  /// of that kind — the challenge still runs, it just isn't doubling as
  /// a mission that day. Never returns null, because a challenge card
  /// with no woman on it is a broken screen.
  static Future<GirlBrief> girlFor(
    MissionKind kind, {
    required GirlBrief fallback,
  }) async {
    final m = await _find(kind);
    if (m?.girlId == null) return fallback;
    try {
      return girlById(m!.girlId!);
    } catch (_) {
      return fallback;
    }
  }

  /// Has he already ticked that mission today? Used so a challenge card
  /// can show DONE rather than inviting him to burn minutes twice.
  static Future<bool> alreadyDone(MissionKind kind) async {
    final m = await _find(kind);
    if (m == null) return false;
    return LocalStoreService.isMissionDoneToday(m.id);
  }

  /// THE OTHER HALF OF THE STONE.
  ///
  /// Call when a daily challenge finishes. If his five included a
  /// mission of that kind and it isn't already ticked, it's ticked now
  /// and paid for — so the work shows up on Home without him having to
  /// go and do it again.
  ///
  /// Idempotent: a second call the same day pays nothing, so a screen
  /// that fires this on every completion path can't double-pay.
  static Future<bool> credit(MissionKind kind) async {
    try {
      final m = await _find(kind);
      if (m == null) return false;
      if (await LocalStoreService.isMissionDoneToday(m.id)) return false;
      await LocalStoreService.markMissionDone(m.id);
      await Rewards.mission(m.xp, m.title);
      return true;
    } catch (e) {
      debugPrint('TodayTargets.credit: $e');
      return false;
    }
  }
}
