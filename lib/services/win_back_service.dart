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
/// before he stalled. The copy is written to sound like someone who
/// watched it happen — because functionally, it did.
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
  //  Rules it's written to:
  //   · Speak from the moment he walked, not from the product.
  //   · Never "Hey!", never an emoji, never a discount, never a
  //     countdown timer. He isn't a coupon user, he's a man avoiding
  //     something.
  //   · Name the thing he was locked out of. Specificity is the whole
  //     difference between "we noticed you" and "we mailed everyone".
  //   · Be honest enough that it stings slightly. The product's entire
  //     premise is that avoidance is the problem.
  // ══════════════════════════════════════════════════════════════════

  /// The same-day hit. Keyed to the gate he bounced off, because at three
  /// hours out he still remembers exactly what he was doing.
  static (String, String) hotCopy({
    required String source,
    required int round,
  }) {
    // He's bounced off this wall more than once. Stop re-pitching and
    // name the pattern — it's the more interesting thing at this point.
    if (round >= 3) {
      return (
        'Third time at this door',
        'You keep opening this and closing it. At some point the reading '
            'isn\'t the part that\'s stopping you.',
      );
    }
    if (round == 2) {
      return (
        'You walked again',
        'Same wall, same decision, same ten seconds. Nothing about it gets '
            'easier by doing it a third time.',
      );
    }

    if (source.contains('voice') ||
        source.contains('speak') ||
        source.contains('lucien') ||
        source.contains('freeflow')) {
      return (
        'She was mid-sentence',
        'You had a live voice waiting and backed out to a menu. That exact '
            'move is the thing you\'re here to stop making.',
      );
    }
    if (source.contains('chat') ||
        source.contains('text') ||
        source.contains('mission')) {
      return (
        'You stopped mid-conversation',
        'You were in it and you walked. She\'d have replied. So would the '
            'next one, and the real one after that.',
      );
    }
    if (source.contains('rizz') || source.contains('screenshot')) {
      return (
        'You had the screenshot open',
        'One line away from sending something that actually lands. You '
            'closed it and sent nothing instead.',
      );
    }
    if (source.contains('streak') ||
        source.contains('potential') ||
        source.contains('lock')) {
      return (
        'You looked at the whole climb',
        'Sixty days, laid out in front of you, and you shut it. It\'s sixty '
            'days whether you start them or not.',
      );
    }
    return (
      'You were one tap off',
      'You read all of it and then closed it. Nothing about you changed in '
          'those ten seconds — you just didn\'t do it.',
    );
  }

  /// The ladder. [daysSince] is the projected days since he walked, so
  /// the horizon can queue the whole arc in advance and it escalates on
  /// its own even if he never reopens the app.
  static (String, String) ladderCopy(WinBackWindow w, {int dayOffset = 0}) {
    final d = w.daysSinceWalk + dayOffset;
    final hard = w.round >= 2;

    // DAY 0 — the evening of the day he walked.
    if (d <= 0) {
      return hard
          ? (
              'Twice now',
              'You\'ve stood at that page twice and left twice. The page '
                  'isn\'t the problem and you know it.',
            )
          : (
              'You closed it',
              'You got all the way to the end and stopped. That\'s not a '
                  'money decision, that\'s the flinch.',
            );
    }

    // DAY 1 — the parachute. Nothing is coming.
    if (d == 1) {
      return hard
          ? (
              'Nobody is coming',
              'No parachute, no moment it suddenly clicks. Just reps you '
                  'either did or didn\'t. Today counts either way.',
            )
          : (
              'Still waiting on the parachute?',
              'Nobody drops game into your garden. It gets built, in reps, '
                  'by men who decided to do them.',
            );
    }

    // DAYS 2-3 — what he's actually turning down: voices that fight back.
    if (d <= 3) {
      return d == 2
          ? (
              'She interrupts. She goes cold.',
              'Live voice that actually tests you — loses interest, calls '
                  'you out, makes you recover. Practise until none of it '
                  'moves you.',
            )
          : (
              'Practise on her, not on her',
              'Every rep you take in here is one you don\'t fumble in front '
                  'of someone real. That\'s the entire trade.',
            );
    }

    // DAYS 4-7 — the arithmetic. A 2 gets to an 8 on volume, not vibes.
    if (d <= 7) {
      if (w.bestStreak >= 3) {
        return (
          'You were on day ${w.bestStreak}',
          'You built that yourself. Rebuilding it from zero costs more than '
              'keeping it ever did.',
        );
      }
      return d <= 5
          ? (
              'A 2 gets to an 8 on reps',
              'Not on confidence quotes, not on a haircut. Five real '
                  'conversations a day and the difference is audible inside '
                  'a fortnight.',
            )
          : (
              'Consistent beats gifted',
              'The men who are good at this were bad at it for a while, out '
                  'loud, on purpose. That part is the skill.',
            );
    }

    // DAYS 8-14 — the promise: five a day and the freeze goes.
    if (d <= 14) {
      return d <= 11
          ? (
              'Five a day. Never freeze again.',
              'Freezing isn\'t your personality — it\'s an untrained '
                  'response, and trained responses don\'t freeze. Five '
                  'missions a day is the whole treatment.',
            )
          : (
              'The freeze is trainable',
              'Everyone who stopped freezing did the same boring thing: '
                  'reps, daily, until the moment stopped being new.',
            );
    }

    // DAYS 15-29 — a month of the same nights.
    if (d < _lastDay) {
      return (
        'Same nights, still',
        'Nothing got easier on its own — it never does. Every man it got '
            'easier for did something on a Tuesday he didn\'t feel like '
            'doing.',
      );
    }

    // DAY 30 — say it's the last one, and mean it.
    return (
      'Last one from me',
      'You\'ve had a month of these. Either the version of you that doesn\'t '
          'freeze is worth a week\'s coffee or he isn\'t. I won\'t ask again.',
    );
  }
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
