import 'package:shared_preferences/shared_preferences.dart';

import 'division.dart';

/// A man's ranked standing, on his own phone.
///
/// WHY LOCAL. Everything here — his win streak, his record, whether a
/// settled duel has been shown to him yet — could live in Postgres, and
/// one day should. But `battle-action` is the Edge Function that has
/// never been deployed, migrations 0009–0011 have never been run, and a
/// feature that needs a deploy before it does anything is a feature that
/// ships in a month. This needs nothing. The rating itself still comes
/// from the server (rizz_elo, service-role writes only), so the number
/// that matters can't be edited from a phone; what's stored here is the
/// STORY around it, and nobody cheats their way to a fake win streak
/// they can only see themselves.
///
/// The one thing this does that a server can't do better: it remembers
/// what he has already been SHOWN. A duel settling while he's asleep is
/// the best notification-free retention moment the app has — he opens
/// it and a fight he'd forgotten about resolves in his face — and that
/// only works if the app knows it hasn't played that moment yet.
class BattleMeta {
  static const _kStreak = 'bat.streak.v1';
  static const _kBest = 'bat.best_streak.v1';
  static const _kWon = 'bat.won.v1';
  static const _kLost = 'bat.lost.v1';
  static const _kDrawn = 'bat.drawn.v1';

  /// The rating we last saw. RR movement is MEASURED against this rather
  /// than predicted, because the Elo settlement happens server-side and
  /// a client that guesses the K-factor will eventually print a number
  /// that disagrees with the ladder. Measuring can be silent; guessing
  /// can be wrong, and wrong is worse.
  static const _kRating = 'bat.rating.v1';

  /// The rung (0–20) he was on last time we looked — promotion is a
  /// comparison against this.
  static const _kRung = 'bat.rung.v1';

  /// Battle ids whose verdict has already been played to him.
  static const _kSeen = 'bat.seen_settled.v1';

  // ══════════════════════════════════════════════════════════════════
  //  THE RECORD
  // ══════════════════════════════════════════════════════════════════

  /// One score ceremony per duel, EVER, atomically.
  ///
  /// The reveal used to be guarded by "is there a parked result", and
  /// the result is parked by a fire-and-forget submit — so a grade that
  /// landed late sat there and fired the ceremony again on the NEXT
  /// visit, for a conversation from twenty minutes ago. Check-and-set
  /// in one call, keyed on the battle id, ends it: the second caller —
  /// same visit or next week — reads a stamp the first already wrote.
  static const _kRevealed = 'bat.revealed.v1';

  static Future<bool> claimReveal(String battleId) async {
    final p = await SharedPreferences.getInstance();
    final done = p.getStringList(_kRevealed) ?? const [];
    if (done.contains(battleId)) return false;
    // Capped so ten years of duels can't grow the pref forever —
    // dropping from the FRONT, because the old ids are the ones whose
    // ceremonies can no longer replay anyway.
    final kept =
        done.length > 199 ? done.sublist(done.length - 199) : done;
    await p.setStringList(_kRevealed, [...kept, battleId]);
    return true;
  }

  static Future<Standing> standing() async {
    final p = await SharedPreferences.getInstance();
    return Standing(
      streak: p.getInt(_kStreak) ?? 0,
      best: p.getInt(_kBest) ?? 0,
      won: p.getInt(_kWon) ?? 0,
      lost: p.getInt(_kLost) ?? 0,
      drawn: p.getInt(_kDrawn) ?? 0,
    );
  }

  /// Bank one settled duel. Returns the standing AFTER it.
  ///
  /// A draw does not break the streak and does not extend it. Breaking a
  /// seven-win run on a tie would feel like a bug to the man it happened
  /// to, and the mechanic only works while it feels fair.
  static Future<Standing> record({required bool won, required bool tie}) async {
    final p = await SharedPreferences.getInstance();
    var streak = p.getInt(_kStreak) ?? 0;
    var best = p.getInt(_kBest) ?? 0;

    if (tie) {
      await p.setInt(_kDrawn, (p.getInt(_kDrawn) ?? 0) + 1);
    } else if (won) {
      streak += 1;
      if (streak > best) best = streak;
      await p.setInt(_kWon, (p.getInt(_kWon) ?? 0) + 1);
    } else {
      streak = 0;
      await p.setInt(_kLost, (p.getInt(_kLost) ?? 0) + 1);
    }

    await p.setInt(_kStreak, streak);
    await p.setInt(_kBest, best);
    return standing();
  }

  /// FIRST RUN ON A PHONE THAT ALREADY HAS HISTORY.
  ///
  /// A man who has fought twelve duels before this build existed should
  /// not be shown 0–0. His record is reconstructed once from the duels
  /// the server can still see, and never again — [played] going above
  /// zero is the lock.
  static Future<void> seedFromHistory({
    required int won,
    required int lost,
    required int drawn,
    required int streak,
  }) async {
    final p = await SharedPreferences.getInstance();
    final already = (p.getInt(_kWon) ?? 0) +
        (p.getInt(_kLost) ?? 0) +
        (p.getInt(_kDrawn) ?? 0);
    if (already > 0) return;
    await p.setInt(_kWon, won);
    await p.setInt(_kLost, lost);
    await p.setInt(_kDrawn, drawn);
    await p.setInt(_kStreak, streak);
    if ((p.getInt(_kBest) ?? 0) < streak) await p.setInt(_kBest, streak);
  }

  // ══════════════════════════════════════════════════════════════════
  //  RR MOVEMENT, MEASURED
  // ══════════════════════════════════════════════════════════════════

  /// Store the rating we can currently see. Call on every load.
  static Future<void> seedRating(int rating) async {
    final p = await SharedPreferences.getInstance();
    if (p.getInt(_kRating) == null) await p.setInt(_kRating, rating);
    if (p.getInt(_kRung) == null) await p.setInt(_kRung, Rank.of(rating).rung);
  }

  /// The change since we last looked, and the new standing. Returns null
  /// for delta when there's nothing to compare against yet — a first
  /// install should not claim he just gained 1,200 RR.
  static Future<Move> noteRating(int rating) async {
    final p = await SharedPreferences.getInstance();
    final before = p.getInt(_kRating);
    final beforeRung = p.getInt(_kRung);
    final now = Rank.of(rating);

    await p.setInt(_kRating, rating);
    await p.setInt(_kRung, now.rung);

    return Move(
      rank: now,
      delta: before == null ? null : rating - before,
      promoted: beforeRung != null && now.rung > beforeRung,
      demoted: beforeRung != null && now.rung < beforeRung,
      from: before == null ? null : Rank.of(before),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  WHAT HE HAS ALREADY BEEN SHOWN
  // ══════════════════════════════════════════════════════════════════

  static Future<Set<String>> _seen(SharedPreferences p) =>
      Future.value((p.getStringList(_kSeen) ?? const <String>[]).toSet());

  /// Of these settled duels, which has he not seen the verdict for?
  static Future<List<String>> unseen(List<String> settledIds) async {
    final p = await SharedPreferences.getInstance();
    final seen = await _seen(p);
    return [
      for (final id in settledIds)
        if (!seen.contains(id)) id
    ];
  }

  /// Mark verdicts played. Trimmed to the last 60 so the list can't grow
  /// without limit on a man who fights every day for two years.
  static Future<void> markSeen(Iterable<String> ids) async {
    final p = await SharedPreferences.getInstance();
    final seen = (await _seen(p)).toList()..addAll(ids);
    final trimmed =
        seen.length <= 60 ? seen : seen.sublist(seen.length - 60);
    await p.setStringList(_kSeen, trimmed);
  }

  /// First run with existing history: swallow every current verdict so a
  /// man updating the app isn't ambushed by nine old duels in a row.
  static Future<void> swallow(List<String> settledIds) => markSeen(settledIds);
}

/// His ranked record.
class Standing {
  final int streak;
  final int best;
  final int won;
  final int lost;
  final int drawn;
  const Standing({
    required this.streak,
    required this.best,
    required this.won,
    required this.lost,
    required this.drawn,
  });

  int get played => won + lost + drawn;

  /// "12–4" — the line every fighter knows how to read. Draws are only
  /// printed once there are any, because "12–4–0" is a spreadsheet.
  String get line => drawn == 0 ? '$won–$lost' : '$won–$lost–$drawn';

  /// Win rate as a whole percentage, or null before it means anything.
  /// Three duels is not a win rate, it's an anecdote.
  int? get winRate =>
      played < 5 ? null : ((won / played) * 100).round();
}

/// What one look at the rating told us.
class Move {
  final Rank rank;

  /// RR gained or lost since we last checked. Null on a first look.
  final int? delta;
  final bool promoted;
  final bool demoted;
  final Rank? from;
  const Move({
    required this.rank,
    required this.delta,
    required this.promoted,
    required this.demoted,
    required this.from,
  });
}
