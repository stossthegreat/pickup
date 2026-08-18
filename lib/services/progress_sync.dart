import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backend/auth_service.dart';
import 'backend/backend_service.dart';
import 'local_store_service.dart';
import 'streak_service.dart';

/// ══════════════════════════════════════════════════════════════════════
///  PROGRESS SYNC — so a lost phone doesn't take the run with it
/// ══════════════════════════════════════════════════════════════════════
///
/// THE PROMISE THAT WASN'T TRUE. The account screen tells every user, in
/// two places, that claiming makes his rank and streak survive a lost
/// phone. The squad survived, because squad_members is a table. The
/// boards survived, because rizz_elo and chat_score are tables. XP and
/// the streak lived in SharedPreferences and died with the handset no
/// matter what he signed in with.
///
/// It matters more here than it would in most apps. The whole retention
/// engine is loss aversion — shields, rescues, DAY WON, "63 days on the
/// line". A machine built to make a man afraid of losing his run, that
/// then lets a new phone take it for free, produces exactly one outcome.
///
/// ── LOCAL STAYS THE SOURCE OF TRUTH ─────────────────────────────────
///
/// This is a mirror, not a database. XP and streak are read from prefs
/// on every frame — they're on the masthead, they gate the roster, they
/// have to work on a plane — and none of that changes. The server copy
/// is written after the fact and read exactly once, at sign-in.
///
/// ── EVERY MERGE TAKES THE MAX ───────────────────────────────────────
///
/// Restore never overwrites, it raises. A man who played offline on the
/// new handset before signing in keeps that work; a man whose device
/// somehow holds MORE than the server keeps that too. There is no
/// conflict resolution to get wrong because there is no case where the
/// smaller number is the right answer.
///
/// ── AND IT RANKS HIM AGAINST NOBODY ─────────────────────────────────
///
/// Deliberately no leaderboard reads this. It's client-written — see the
/// RLS note in migration 0014 — so a tampered row could only ever give
/// its owner a bigger number on his own phone, which he could already do
/// by editing his own prefs. Everything competitive stays in rizz_elo
/// and chat_score, which only the service role can write.
abstract final class ProgressSync {
  static const _table = 'user_progress';

  /// Coalesces the writes. Rewards._settle() fires on every grant, and a
  /// man finishing five missions in a minute should cost one round-trip,
  /// not five. Nothing waits on this — the push is fire-and-forget.
  static Timer? _debounce;

  /// Set once a restore has run this launch. Sign-in can be reached from
  /// onboarding AND from settings, and pulling twice is wasted work.
  static bool _restored = false;

  /// MIRROR THE CURRENT STATE UP. Safe to call as often as you like.
  ///
  /// Silent by design: this is a backup, and a backup that interrupts
  /// the app to complain has cost more than it protects. Anonymous
  /// users are skipped — there is no durable identity to hang the row
  /// on, and the moment they claim one, [restore] runs and [push]
  /// starts working.
  static void schedulePush() {
    if (!BackendService.enabled || AuthService.userId == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), () {
      // ignore: discarded_futures
      _push();
    });
  }

  static Future<void> _push() async {
    final uid = AuthService.userId;
    if (!BackendService.enabled || uid == null) return;
    try {
      final xp = await LocalStoreService.xpTotal();
      final snap = await StreakService.progress();
      await BackendService.client.from(_table).upsert({
        'user_id': uid,
        'xp': xp,
        'streak': snap.streak,
        'best_streak': snap.longest,
        'earned_days': snap.ascensionDay,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('ProgressSync.push: $e');
    }
  }

  /// PULL IT BACK DOWN after a claim. Returns true when something was
  /// actually restored, so the caller can say so.
  ///
  /// Call this on every successful Apple / Google sign-in. On the phone
  /// he already plays on it finds nothing bigger and does nothing, which
  /// is the common case and costs one read.
  static Future<bool> restore({bool force = false}) async {
    final uid = AuthService.userId;
    if (!BackendService.enabled || uid == null) return false;
    if (_restored && !force) return false;
    _restored = true;

    try {
      final row = await BackendService.client
          .from(_table)
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) {
        // First claim on a device that has been played — seed the
        // mirror from it rather than leaving the row absent, so the
        // NEXT phone has something to come back to.
        await _push();
        return false;
      }

      final serverXp = (row['xp'] as int?) ?? 0;
      final serverStreak = (row['streak'] as int?) ?? 0;
      final serverBest = (row['best_streak'] as int?) ?? 0;

      final localXp = await LocalStoreService.xpTotal();
      final (localStreak, localBest) = await StreakService.refresh();

      var moved = false;

      // XP is a running total, so the merge is a top-up to the server's
      // figure — never a subtraction, and never a sum, which would
      // double a man's total every time he signed in on a device that
      // was already in sync.
      if (serverXp > localXp) {
        await LocalStoreService.addXp(serverXp - localXp);
        moved = true;
      }

      if (serverStreak > localStreak || serverBest > localBest) {
        await StreakService.restoreRun(
          days: serverStreak > localStreak ? serverStreak : 0,
          longest: serverBest,
        );
        moved = true;
      }

      // Whatever the merge produced is now the truth on both sides.
      if (moved) await _push();
      return moved;
    } catch (e) {
      debugPrint('ProgressSync.restore: $e');
      return false;
    }
  }
}
