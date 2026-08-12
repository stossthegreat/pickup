import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'local_store_service.dart';
import 'notification_service.dart';
import 'streak_service.dart';

/// THE WIN-BACK LADDER — for the man who read the whole paywall and
/// closed it.
///
/// That user is the most valuable one in the funnel and the worst served.
/// He isn't a stranger who needs convincing the product exists — he
/// opened it, got gated on something he actually wanted, read the pitch
/// end to end, and then walked at the last inch. Generic retention copy
/// ("open the app!") is wasted on him, because his problem was never
/// awareness. It was the ten seconds after he'd already decided.
///
/// So this ladder talks to that exact moment. It knows WHAT he was locked
/// out of (the source the gate passed through), HOW MANY TIMES he's now
/// bounced off the same wall, and how far up the 60-day climb he'd got
/// before he stalled.
///
/// It does NOT open by telling him off. At three hours he hasn't refused,
/// he's hesitated, and confrontation turns a hesitation into a decision —
/// which won't be the one we want. So it opens the way every app that
/// does this well opens: still thinking about it? Then it warms, gets
/// funny, and only goes hard once soft has had a fortnight to work.
///
/// SHAPE
///   · HOT BEAT — roughly three hours after he walks, while the decision
///     is still fresh and reversible. One notification, its own id.
///   · THE LADDER — it then takes over the evening slot of the existing
///     14-day horizon (see DailyNudgeService), so it costs ZERO extra
///     pending notifications and never competes with the daily nudge for
///     an OS slot. The evening beat is the loss-framed one anyway; this
///     is the same beat with a sharper reason.
///
/// IT STOPS. At day 30 it fires one honest last message that says it's
/// the last message, and then it is — the ladder disarms itself until he
/// hits a paywall again. A drip that never ends stops being persuasion
/// and becomes a reason to uninstall.
///
/// It disarms instantly on purchase, and [mute] kills it permanently.
class WinBackService {
  /// The one extra pending notification this system costs: the same-day
  /// hit while the decision is still warm. Everything after it rides the
  /// horizon's existing evening slot.
  static const hotId = 9400;

  static const _kWalkedMs = 'winback.walked.ms';
  static const _kRound = 'winback.round'; // how many times he's walked
  static const _kSource = 'winback.source';
  static const _kMuted = 'winback.muted';

  /// After this many days the ladder has said everything it has to say.
  static const _lastDay = 30;

  static FlutterLocalNotificationsPlugin get _plugin =>
      NotificationService.plugin;

  // ── Marks ───────────────────────────────────────────────────────────

  /// He opened the paywall and closed it without buying. [source] is the
  /// gate that sent him there ('mission_voice', 'text_cap', …) — it's what
  /// makes the first message land instead of sounding like a mailshot.
  static Future<void> markPaywallWalked(String source) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kMuted) == true) return;
      if (await LocalStoreService.isSubscribed()) return;

      // A second walk doesn't restart the ladder from the top — it
      // advances the round, which sharpens every line. Being told the
      // same thing again after ignoring it once is how copy stops
      // getting read.
      final round = (prefs.getInt(_kRound) ?? 0) + 1;
      await prefs.setInt(_kRound, round);
      await prefs.setInt(_kWalkedMs, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(_kSource, source);

      await _scheduleHot(source: source, round: round);
    } catch (e) {
      debugPrint('WinBackService.markPaywallWalked failed: $e');
    }
  }

  /// He paid. Everything stops, permanently — nothing reads worse than
  /// being sold something you already bought.
  static Future<void> markConverted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kWalkedMs);
      await prefs.remove(_kSource);
      await prefs.setInt(_kRound, 0);
      await _plugin.cancel(hotId);
    } catch (e) {
      debugPrint('WinBackService.markConverted failed: $e');
    }
  }

  /// Kill the ladder for good. Wired to a settings toggle so "stop
  /// asking me" is always available without turning off every other
  /// notification the app sends.
  static Future<void> mute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kMuted, true);
      await prefs.remove(_kWalkedMs);
      await _plugin.cancel(hotId);
    } catch (e) {
      debugPrint('WinBackService.mute failed: $e');
    }
  }

  /// Boot-time safety net. He can become a subscriber without ever
  /// touching this build's paywall screen — a restore on another device,
  /// or the RevenueCat listener flipping the flag underneath us. Without
  /// this, the already-queued hot notification would still land on a
  /// paying customer.
  static Future<void> syncOnLaunch() async {
    try {
      if (await LocalStoreService.isSubscribed()) await markConverted();
    } catch (e) {
      debugPrint('WinBackService.syncOnLaunch failed: $e');
    }
  }

  static Future<void> unmute() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMuted, false);
  }

  static Future<bool> isMuted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kMuted) == true;
  }

  // ── State ───────────────────────────────────────────────────────────

  /// The live window, or null when the ladder shouldn't speak at all:
  /// he never walked, he's already paying, he muted it, or it's said its
  /// last word.
  static Future<WinBackWindow?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kMuted) == true) return null;
      final ms = prefs.getInt(_kWalkedMs) ?? 0;
      if (ms == 0) return null;
      if (await LocalStoreService.isSubscribed()) return null;

      final days = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ms))
          .inDays;
      if (days > _lastDay) return null;

      final snap = await StreakService.progress();
      return WinBackWindow(
        daysSinceWalk: days,
        round: prefs.getInt(_kRound) ?? 1,
        source: prefs.getString(_kSource) ?? '',
        streak: snap.streak,
        bestStreak: snap.longest,
      );
    } catch (e) {
      debugPrint('WinBackService.read failed: $e');
      return null;
    }
  }

  // ── The hot beat ────────────────────────────────────────────────────

  /// Three hours out, nudged into daylight. A push at 03:00 doesn't read
  /// as urgency, it reads as spam, and it's the one message in the whole
  /// ladder that has to be read.
  static Future<void> _scheduleHot({
    required String source,
    required int round,
  }) async {
    await _plugin.cancel(hotId);
    final now = tz.TZDateTime.now(tz.local);
    var at = now.add(const Duration(hours: 3));
    if (at.hour >= 22 || at.hour < 9) {
      final base = at.hour < 9 ? at : at.add(const Duration(days: 1));
      at = tz.TZDateTime(tz.local, base.year, base.month, base.day, 9, 30);
    }
    if (!at.isAfter(now)) at = now.add(const Duration(minutes: 90));

    final (title, body) = hotCopy(source: source, round: round);
    await _plugin.zonedSchedule(
      hotId,
      title,
      body,
      at,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          badgeNumber: 1,
        ),
        android: AndroidNotificationDetails(
          'winback',
          'Unlock reminders',
          channelDescription:
              'Occasional reminders about the full version, after you\'ve '
              'looked at it. Stops on its own.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  THE COPY
  //
  //  THE HARD CONSTRAINT: a notification is TWO LINES. iOS truncates the
  //  title around 30 characters on a lock screen and the collapsed body
  //  around 90. Anything past that is a paragraph nobody unrolls — which
  //  makes a long, clever line strictly worse than a short blunt one.
  //  Every string below is written to fit inside the glance.
  //
  //  Rules it's written to:
  //   · Open soft. The three-hour message is "still thinking about it?",
  //     not an accusation — the point is to reopen the door, and every
  //     app that does this well does it that way. He hasn't refused, he
  //     hesitated. Confrontation at hour three converts hesitation into
  //     a decision, and it won't be the one we want.
  //   · Sell the OUTCOME, not the feature. Nobody wants "AI roleplay".
  //     They want to not be ignored, and to stop lying in bed replaying
  //     the thing they didn't say.
  //   · Vary the temperature. Funny, then warm, then hard. Six hard ones
  //     in a row is a mute; six soft ones is wallpaper.
  //   · Never an emoji, never a discount, never a countdown. He isn't a
  //     coupon user, he's a man avoiding something.
  //
  //  Each rung is a small pool, picked deterministically off round +
  //  horizon day, so the arc holds but the exact words don't repeat.
  // ══════════════════════════════════════════════════════════════════

  static (String, String) _pick(List<(String, String)> pool, int salt) =>
      pool[salt.abs() % pool.length];

  /// THREE HOURS OUT — the soft return.
  ///
  /// The whole job of this one is to reopen a door he half-closed, so
  /// the title never changes tone: he's still thinking about it, and
  /// we're being relaxed about that. The body is where the knowledge
  /// goes — one short line naming what he actually walked away from.
  static (String, String) hotCopy({
    required String source,
    required int round,
  }) {
    if (round >= 3) {
      return ('Still thinking about it?', 'Third look. Something wants it.');
    }
    if (round == 2) {
      return ('Still on the fence?', 'You came back once already.');
    }

    const title = 'Still thinking about it?';
    if (source.contains('voice') ||
        source.contains('speak') ||
        source.contains('lucien') ||
        source.contains('freeflow')) {
      return (title, 'She was mid-sentence when you left.');
    }
    if (source.contains('chat') ||
        source.contains('text') ||
        source.contains('mission')) {
      return (title, 'You were mid-conversation.');
    }
    if (source.contains('rizz') || source.contains('screenshot')) {
      return (title, 'That screenshot is still unanswered.');
    }
    if (source.contains('streak') ||
        source.contains('potential') ||
        source.contains('lock')) {
      return (title, 'Day 1 is still sitting there.');
    }
    return (title, 'Most men think about it. Then say nothing.');
  }

  /// The ladder. [dayOffset] projects forward so the horizon can queue
  /// the whole arc in advance and it escalates on its own even if he
  /// never reopens the app.
  static (String, String) ladderCopy(WinBackWindow w, {int dayOffset = 0}) {
    final d = w.daysSinceWalk + dayOffset;
    final salt = w.round + dayOffset;

    // DAY 0 — the evening he walked. Still light. Still a door.
    if (d <= 0) return _pick(_day0, salt);

    // DAY 1 — the regret hook. Not the app: the girl he said nothing to.
    // This is the single most-felt line in the whole product and it goes
    // early, while he can still remember closing the paywall.
    if (d == 1) return _pick(_day1, salt);

    // DAYS 2-3 — funny, and the mechanism underneath the joke.
    if (d <= 3) return _pick(_day3, salt);

    // DAYS 4-7 — the outcome he actually wants, spelled out.
    if (d <= 7) {
      // If he built something before he stalled, point at that instead —
      // his own evidence beats our promise every time.
      if (w.bestStreak >= 3) {
        return ('You were on day ${w.bestStreak}', 'That was you. Still is.');
      }
      return _pick(_day7, salt);
    }

    // DAYS 8-14 — the promise. Five a day and the freeze goes.
    if (d <= 14) return _pick(_day14, salt);

    // DAYS 15-29 — now it hits hard. He's had a month of soft.
    if (d < _lastDay) return _pick(_day29, salt);

    // DAY 30 — say it's the last one, and mean it.
    return ('Last one from me', 'You know where it is.');
  }

  static const _day0 = <(String, String)>[
    ('You got to the end', 'Then stopped. Tonight still counts.'),
    ('One tap left', 'That\'s the whole distance.'),
    ('Door\'s still open', 'No rush. It\'s a quiet night either way.'),
  ];

  static const _day1 = <(String, String)>[
    ('The one you said nothing to', 'You still think about it. That\'s the fix.'),
    ('Why didn\'t I say something', 'Everyone\'s asked it. Few do anything.'),
    ('Nothing changes on its own', 'Ask anyone still waiting.'),
  ];

  static const _day3 = <(String, String)>[
    ('She left you on read', 'Practise on someone who has to reply.'),
    ('Ran out of things to say?', 'That\'s a skill, not a personality.'),
    ('She interrupts. She goes cold.', 'Better in here than in front of her.'),
  ];

  static const _day7 = <(String, String)>[
    ('Imagine not overthinking it', 'Two weeks of reps and you just say it.'),
    ('Stop getting ignored', 'It\'s almost always the opener. Fixable.'),
    ('The reply you actually wanted', 'Starts with the line you practised.'),
  ];

  static const _day14 = <(String, String)>[
    ('Freezing is trainable', 'Five a day. That\'s the whole treatment.'),
    ('Five missions. Every day.', 'Nobody who did that still freezes.'),
    ('It stops being a big moment', 'That\'s all confidence is. Reps.'),
  ];

  static const _day29 = <(String, String)>[
    ('A month of the same nights', 'It doesn\'t get easier on its own.'),
    ('Still nothing?', 'Every man it clicked for started on a dull Tuesday.'),
    ('You\'ll remember this year', 'Make it the one it changed.'),
  ];
}

/// A live win-back window — he walked, he hasn't paid, and the ladder
/// still has something to say.
class WinBackWindow {
  /// Whole days since he closed the paywall.
  final int daysSinceWalk;

  /// How many separate times he's walked. Sharpens the copy rather than
  /// repeating it.
  final int round;

  /// The gate that sent him to the paywall ('mission_voice', 'text_cap',
  /// …). Empty when it wasn't recorded.
  final String source;

  /// Current streak and best-ever, so the ladder can point at something
  /// he actually built rather than a generic promise.
  final int streak;
  final int bestStreak;

  const WinBackWindow({
    required this.daysSinceWalk,
    required this.round,
    required this.source,
    required this.streak,
    required this.bestStreak,
  });
}
