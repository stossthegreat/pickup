import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// THE RETENTION BRAIN — when to send, and when to shut up.
///
/// Research this is built on, and what each finding changed:
///
/// ── DUOLINGO ─────────────────────────────────────────────────────────
/// Roughly a billion notifications a year. Their single most famous one
/// is not a reminder, it's a RETREAT:
///
///     "Hi, this is Duo. These reminders don't seem to be working.
///      We're going to stop sending them for now."
///
/// Everyone copies the passive-aggressive owl. Almost nobody copies the
/// part that makes it work — they stop escalating after repeated
/// ignores, which is what protects the channel. A man who has ignored
/// eleven pushes doesn't need a twelfth; he needs the app to prove it
/// isn't desperate. That's [trustStopDue] below, and it is the most
/// important function in this file.
///
/// Their other three moves, all implemented here:
///   · a single HABIT ANCHOR (one lesson a day) rather than nagging
///     about everything the product can do
///   · EARLY RISK DETECTION — notice when he misses his usual window,
///     not when he's already a week gone
///   · TONE VARIED BY ENGAGEMENT — the same line to a day-40 man and a
///     day-2 man is wrong for at least one of them
///
/// ── CAL AI ($30M+ ARR in under two years) ────────────────────────────
///   · Notification permission is asked as a BENEFIT, in-app, BEFORE the
///     iOS prompt fires. The system dialog is one-shot forever; spending
///     it cold is the most expensive mistake in mobile onboarding.
///   · The rating ask goes BEFORE the paywall, while he's still excited.
///   · Paywalls run at abandonment, feature gates and win-back, wired to
///     push — not just once at the start.
///
/// ── TRIAL→PAID CONSENSUS ─────────────────────────────────────────────
///   · Three touchpoints beats a countdown drip.
///   · Name the SPECIFIC thing he loses, never "your trial ends".
///   · Send inside his own active window: reported up to ~40% better
///     open rates than a fixed hour for everyone.
///
/// Everything here is on-device. No new table, no deploy.
class RetentionService {
  // ── When he actually uses the app ───────────────────────────────────
  static const _kHours = 'ret.open_hours.v1';
  static const _kLastOpen = 'ret.last_open.v1';

  // ── Whether the channel is still trusted ────────────────────────────
  static const _kSentSince = 'ret.sent_since_open.v1';
  static const _kQuietUntil = 'ret.quiet_until.v1';
  static const _kToldHim = 'ret.told_him.v1';

  /// Consecutive scheduled pushes with no app open in between, before we
  /// stop. Eleven ignored pushes is not a man who needs a twelfth.
  static const ignoreLimit = 8;

  /// How long the app goes quiet once it has said so. Long enough that
  /// the retreat is real and not a sales tactic — if it were three days
  /// it would just be another beat in the ladder.
  static const quietDays = 10;

  // ══════════════════════════════════════════════════════════════════
  //  SEND-TIME LEARNING
  // ══════════════════════════════════════════════════════════════════

  /// Called on every app open. Builds a 24-bucket histogram of when he
  /// actually shows up.
  static Future<void> noteOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final h = DateTime.now().hour;
    final hist = _readHist(prefs);
    hist[h] = hist[h] + 1;
    await prefs.setString(_kHours, jsonEncode(hist));
    await prefs.setInt(_kLastOpen, DateTime.now().millisecondsSinceEpoch);
    // Opening the app IS the answer to every notification we sent. The
    // channel is trusted again.
    await prefs.setInt(_kSentSince, 0);
  }

  /// The hour he's most likely to be holding the phone, or null until
  /// there's enough evidence to beat a sensible default.
  ///
  /// Requires real signal before it overrides the fixed schedule — a
  /// histogram built from three opens is noise, and guessing wrong here
  /// costs more than not guessing.
  static Future<int?> bestHour({int fallback = 20}) async {
    final prefs = await SharedPreferences.getInstance();
    final hist = _readHist(prefs);
    var total = 0;
    for (final n in hist) {
      total += n;
    }
    if (total < 8) return null;

    // Smooth across ±1 hour. A man who opens at 19:58 and 20:03 has one
    // habit, not two, and an unsmoothed peak would split it.
    var bestH = fallback, bestScore = -1;
    for (var h = 0; h < 24; h++) {
      final score =
          hist[(h + 23) % 24] + hist[h] * 2 + hist[(h + 1) % 24];
      if (score > bestScore) {
        bestScore = score;
        bestH = h;
      }
    }
    // Never schedule into the middle of the night even if that's
    // genuinely when he uses it — a 3am push is indistinguishable from
    // spam to everyone except the one man it's right for.
    if (bestH < 8 || bestH > 22) return null;
    return bestH;
  }

  /// Days since he last opened. 0 if never recorded.
  static Future<int> daysSinceOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastOpen) ?? 0;
    if (last == 0) return 0;
    return (DateTime.now().millisecondsSinceEpoch - last) ~/ 86400000;
  }

  // ══════════════════════════════════════════════════════════════════
  //  THE TRUST STOP  — the part nobody copies
  // ══════════════════════════════════════════════════════════════════

  /// Count a push we're about to lay down. Called by the scheduler.
  static Future<void> noteSent([int n = 1]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSentSince, (prefs.getInt(_kSentSince) ?? 0) + n);
  }

  /// True while the app has voluntarily gone quiet. The scheduler must
  /// lay down NOTHING in this window.
  static Future<bool> isQuiet() async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_kQuietUntil) ?? 0;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  /// Has he ignored enough that we should say so and stop?
  ///
  /// Returns the retreat copy exactly once, then puts the app in a
  /// [quietDays] blackout. This costs sends in the short run and is the
  /// highest-value thing in the file: a notification channel is a trust
  /// balance, every ignored push is a withdrawal, and an app that keeps
  /// shouting past the point of being heard gets its permission revoked
  /// at the OS level — which is unrecoverable.
  static Future<(String, String)?> trustStopDue() async {
    final prefs = await SharedPreferences.getInstance();
    if (await isQuiet()) return null;
    final sent = prefs.getInt(_kSentSince) ?? 0;
    if (sent < ignoreLimit) return null;
    if (prefs.getBool(_kToldHim) == true) {
      // Already retreated once and he came back and drifted again.
      // Go quiet without the speech — saying it twice makes it a tactic.
      await _goQuiet(prefs);
      return null;
    }
    await prefs.setBool(_kToldHim, true);
    await _goQuiet(prefs);
    return (
      'Alright, message received 🫡',
      'We\'ve been shouting and you\'ve been busy. We\'ll stop for a bit. '
          'Your streak, your squad and your women are all still here.',
    );
  }

  static Future<void> _goQuiet(SharedPreferences prefs) async {
    await prefs.setInt(
        _kQuietUntil,
        DateTime.now()
            .add(const Duration(days: quietDays))
            .millisecondsSinceEpoch);
    await prefs.setInt(_kSentSince, 0);
  }

  // ══════════════════════════════════════════════════════════════════
  //  TONE BY ENGAGEMENT
  // ══════════════════════════════════════════════════════════════════

  /// Duolingo's third move: the same line to a day-40 man and a day-2
  /// man is wrong for at least one of them.
  ///
  ///   fresh   — under a week in. Nothing to lose yet, so sell the
  ///             OUTCOME. Loss framing on a man with no streak is
  ///             threatening him with nothing.
  ///   locked  — a live streak or squad. He HAS something, so name it.
  ///             This is the only band where loss aversion works.
  ///   slipping— one to three days gone. Early risk. Warm, not cross.
  ///   gone    — over three days. Every word must lower the cost of
  ///             coming back, never raise it.
  static Future<Tone> tone({required int streak, required int daysAway}) async {
    if (daysAway >= 4) return Tone.gone;
    if (daysAway >= 1) return Tone.slipping;
    if (streak >= 3) return Tone.locked;
    return Tone.fresh;
  }

  static List<int> _readHist(SharedPreferences prefs) {
    final raw = prefs.getString(_kHours);
    if (raw == null) return List<int>.filled(24, 0);
    try {
      final list = jsonDecode(raw);
      if (list is! List || list.length != 24) return List<int>.filled(24, 0);
      return [for (final e in list) (e is num) ? e.toInt() : 0];
    } catch (_) {
      return List<int>.filled(24, 0);
    }
  }
}

enum Tone { fresh, locked, slipping, gone }

/// ══════════════════════════════════════════════════════════════════════
///  LUCIEN — the one voice that isn't the app talking about itself
/// ══════════════════════════════════════════════════════════════════════
///
/// Every retention notification in this app was the product asking for
/// attention: "New women unlock as you climb", "Keep your streak". Men
/// have been trained since about 2014 to swipe those away without
/// reading them, and no amount of copywriting fixes a message whose
/// sender is a piece of software.
///
/// Lucien is the coach. He already exists in the product, the man
/// already knows his name, and he's allowed to be short with him in a
/// way the app never can be. A notification from a character you have a
/// relationship with is a different object to a notification from a
/// brand — that's the whole of why Duo works, and Duo is an owl.
///
/// RULES:
///  · He notices, he doesn't nag. One observation, no instruction.
///  · He's never insulting. "You think you'll get game like that" is
///    funny once and corrosive by the fourth time — men leave apps that
///    make them feel small, and this one is already about a sore spot.
///  · One emoji at most, and only where it earns the glance. Research is
///    consistent that emoji lift open rates by standing out in the
///    tray; a wall of them reads as a marketing blast.
abstract final class Lucien {
  static const name = 'Lucien';

  /// Nothing done today, streak alive. He's got something to lose.
  static const locked = <(String, String)>[
    ('Lucien 🥃', 'Streak\'s still standing. Barely. Two minutes fixes it.'),
    ('Lucien', 'You\'ve not said a word to anyone today. I noticed.'),
    ('Lucien 🥃',
        'Every man who got good at this did it on the days he didn\'t feel like it.'),
    ('Lucien', 'One conversation. Then the day counts. Your call.'),
  ];

  /// Early days. Sell the outcome — he has no streak to threaten.
  static const fresh = <(String, String)>[
    ('Lucien 🥃', 'Two minutes tonight and you\'ll open your mouth quicker on Saturday.'),
    ('Lucien', 'Nobody is naturally good at this. That\'s the good news.'),
    ('Lucien 🥃', 'She\'s waiting. She has no idea who you are yet.'),
    ('Lucien', 'The first week is the only hard one. You\'re in it.'),
  ];

  /// One to three days gone. Early risk — warm, never cross.
  static const slipping = <(String, String)>[
    ('Lucien 🥃', 'Two days. Not a problem yet. Tonight it isn\'t one at all.'),
    ('Lucien', 'You went quiet. Happens. Door\'s open.'),
    ('Lucien 🥃', 'Come back before it becomes a thing you have to come back from.'),
  ];

  /// Properly gone. Every word lowers the cost of returning.
  static const gone = <(String, String)>[
    ('Lucien 🥃', 'No lecture. Two minutes and you\'re back in it.'),
    ('Lucien', 'Your women are still there. So is your best score.'),
    ('Lucien 🥃', 'Start again isn\'t the same as start from nothing. You kept everything.'),
  ];

  static (String, String) forTone(Tone t, int salt) {
    final pool = switch (t) {
      Tone.fresh => fresh,
      Tone.locked => locked,
      Tone.slipping => slipping,
      Tone.gone => gone,
    };
    return pool[salt.abs() % pool.length];
  }
}
