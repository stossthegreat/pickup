import 'package:shared_preferences/shared_preferences.dart';

import 'rolodex_service.dart';

/// THE COMEBACK — the moment nobody designs for, and the one where
/// retention is actually won or lost.
///
/// Every app pours its effort into the first session and the daily loop.
/// Almost none of them design the fifth day back, which is where the
/// user actually is when he decides whether this thing is part of his
/// life. He opens it, sees a dead streak, a benched badge and a board
/// he's fallen off, concludes he's already lost, and never opens it
/// again. Every mechanic we built to motivate him becomes, at that exact
/// moment, a reason to leave.
///
/// Three rules, and they invert the usual instinct:
///
///  1. NOTHING IS EVER FULLY GONE. The Rolodex keeps its cards, warmth
///     restores from one message, the chain shows a BEST to beat.
///
///  2. SHE MESSAGES FIRST. He shouldn't have to decide to start — that
///     decision is the entire barrier. When he opens the app after a
///     lapse, a woman he already won has already sent something, and all
///     that's left is replying. It converts "start a new conversation
///     with an AI" into "answer a text", which is a fraction of the
///     activation energy and is also just... what happens with someone
///     you know.
///
///  3. THE FIRST RUN BACK IS REWARDED, NOT PUNISHED. Anything that makes
///     coming back feel like a penalty guarantees he leaves again.
///
/// Every trigger here is honest: she IS cooling, and replying DOES
/// restore her. We're surfacing a real state at the useful moment, not
/// manufacturing an emergency.
class ComebackService {
  static const _kLastOpen = 'comeback.last_open_ms.v1';
  static const _kOffered = 'comeback.offered_ms.v1';

  /// Days away before she reaches out. Two, not one — a man who missed
  /// a single evening hasn't lapsed, and a woman who texts because you
  /// were busy for a day is a different character than the one we wrote.
  static const lapseDays = 2;

  /// Don't run the same play twice in a week even if he keeps lapsing.
  /// Re-entry theatre stops working the moment it becomes the norm.
  static const cooldownDays = 6;

  static Future<void> markOpen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _kLastOpen, DateTime.now().millisecondsSinceEpoch);
  }

  /// How long he's been gone, in whole days.
  static Future<int> daysAway() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastOpen) ?? 0;
    if (last == 0) return 0; // first ever launch is not a lapse
    final ms = DateTime.now().millisecondsSinceEpoch - last;
    return ms ~/ 86400000;
  }

  /// The offer, if there is one. Consumes it — call once per open.
  ///
  /// Returns null when he hasn't lapsed, when he owns nobody to hear
  /// from, or when he's already had this recently.
  static Future<ComebackOffer?> take() async {
    final away = await daysAway();
    // Stamp the open BEFORE deciding, so a crash between the two can't
    // leave him getting the same message every launch.
    await markOpen();
    if (away < lapseDays) return null;

    final prefs = await SharedPreferences.getInstance();
    final lastOffer = prefs.getInt(_kOffered) ?? 0;
    final since = DateTime.now().millisecondsSinceEpoch - lastOffer;
    if (lastOffer != 0 && since < cooldownDays * 86400000) return null;

    // She has to be someone he actually won. A stranger messaging him
    // out of nowhere is a notification; a woman whose number he has is
    // a relationship, and only one of those is worth coming back to.
    final cards = await Rolodex.all();
    if (cards.isEmpty) return null;
    cards.sort((a, b) => a.warmth.compareTo(b.warmth));
    final her = cards.first;

    await prefs.setInt(_kOffered, DateTime.now().millisecondsSinceEpoch);
    return ComebackOffer(
      card: her,
      away: away,
      opener: _opener(her.girlId, away),
    );
  }

  /// Her first line. Written to sound like someone who noticed, not like
  /// a system reminder wearing a name — no "it's been 4 days since your
  /// last session", because she wouldn't say that and he'd hear the
  /// machine underneath it instantly.
  static String _opener(String girlId, int away) {
    final pool = away >= 7
        ? const [
            'so you\'re alive then.',
            'i\'d honestly written you off.',
            'a whole week. bold move.',
            'thought you\'d lost my number.',
          ]
        : const [
            'you went quiet on me.',
            'hey stranger.',
            'was starting to think that was it.',
            'you\'re bad at texting back. noted.',
          ];
    // Stable per woman + per lapse length, so it can't reshuffle under
    // him if the sheet rebuilds.
    var h = away;
    for (final c in girlId.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return pool[h % pool.length];
  }
}

class ComebackOffer {
  final NumberCard card;
  final int away;
  final String opener;
  const ComebackOffer({
    required this.card,
    required this.away,
    required this.opener,
  });
}
