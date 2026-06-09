import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'local_store_service.dart';
import 'notification_service.dart';
import 'protocol_service.dart';

/// THE DAILY NUDGE — one notification per day, 7:30pm local, picked
/// from a state-aware copy pool that hits the actual wound.
///
/// Replaces the three legacy schedulers (streakNudge + trainingNudge
/// + rescan reminders) which were firing too often and sounded like
/// marketing. Cancel all of those once at app boot; from then on only
/// this one notification ID (`_kNotifId`) lives in the queue.
///
/// THE STATE MACHINE — read once, pick exactly one line:
///   NO_SCAN          — never scanned
///   POST_SCAN_NO_GAME— scanned but never opened Free Flow
///   PROTOCOL_ACTIVE  — currently checked in on at least one axis
///   PROTOCOL_BROKEN  — at least one protocol's streak just broke
///   GAME_STALE_3D    — 3-6 days since last Free Flow
///   GAME_STALE_7D    — 7-13 days since last Free Flow
///   DORMANT_7D       — 7-13 days since last app open
///   DORMANT_14D      — 14+ days since last app open
///   DEFAULT          — fallback (active user, no specific signal)
///
/// THE COPY — every line is the friend-warning voice. No emojis.
/// No "Hey [name]!". Specific. Loss-framed. Friend telling you you're
/// slipping. Each state has 6-10 lines; we hash by date so the same
/// state on consecutive days doesn't repeat.
class DailyNudgeService {
  static const _kNotifId        = 9001;
  static const _kLastFreeFlowKey = 'nudge.last_freeflow_ms';
  static const _kLastAppOpenKey  = 'nudge.last_app_open_ms';

  // ── Event marks — call these wherever the user does the thing.

  static Future<void> markAppOpened() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastAppOpenKey, DateTime.now().millisecondsSinceEpoch);
    await reschedule();
  }

  static Future<void> markFreeFlowSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastFreeFlowKey, DateTime.now().millisecondsSinceEpoch);
    await reschedule();
  }

  /// Cancel every legacy notification and any prior daily nudge,
  /// then schedule today's (or tomorrow's, if 7:30pm passed). Safe
  /// to call repeatedly — every call is a fresh-state read.
  static Future<void> reschedule() async {
    try {
      // 1) Wipe the legacy schedule. The old service queued
      // streak/training/rescan notifications; cancelAll guarantees
      // only THIS nudge lives in the OS queue.
      await NotificationService.cancelAllProtocolNotifications();
      await NotificationService.cancelTrainingNudge();
      await _plugin.cancel(_kNotifId);

      final state = await _readState();
      final (title, body) = _copyForState(state);
      final fireAt = _next730pm();

      await _plugin.zonedSchedule(
        _kNotifId,
        title,
        body,
        fireAt,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
          android: AndroidNotificationDetails(
            'daily_nudge',
            'Daily nudge',
            channelDescription:
                'One notification per day — the friend warning that you\'re slipping.',
            importance: Importance.high,
            priority:   Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('DailyNudgeService.reschedule failed: $e');
    }
  }

  // ── Internals ───────────────────────────────────────────────────────

  static FlutterLocalNotificationsPlugin get _plugin =>
      NotificationService.plugin;

  static tz.TZDateTime _next730pm() {
    final now    = tz.TZDateTime.now(tz.local);
    var target   = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, 19, 30);
    if (now.isAfter(target)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  static Future<_NudgeState> _readState() async {
    final prefs = await SharedPreferences.getInstance();
    final scan  = await LocalStoreService.latestScan();
    final gameUsed = await LocalStoreService.gameFreeUsed();
    final actives  = await ProtocolService.loadAllActive();

    final now = DateTime.now();
    final lastFreeFlowMs = prefs.getInt(_kLastFreeFlowKey) ?? 0;
    final lastOpenMs     = prefs.getInt(_kLastAppOpenKey) ?? now.millisecondsSinceEpoch;

    final daysSinceFreeFlow = lastFreeFlowMs == 0
        ? 9999
        : now.difference(DateTime.fromMillisecondsSinceEpoch(lastFreeFlowMs)).inDays;
    final daysSinceOpen = now.difference(
        DateTime.fromMillisecondsSinceEpoch(lastOpenMs)).inDays;

    if (scan == null) return _NudgeState.noScan;
    if (daysSinceOpen >= 14) return _NudgeState.dormant14d;
    if (daysSinceOpen >= 7)  return _NudgeState.dormant7d;

    // Protocol-broken trumps everything else for daily focus.
    final broken = actives.values.any((p) {
      // A protocol counts as "broken" if it has at least one logged
      // day but the streak fell to zero.
      return p.completedDays.isNotEmpty && p.effectiveStreak == 0;
    });
    if (broken) return _NudgeState.protocolBroken;

    if (actives.isNotEmpty) return _NudgeState.protocolActive;

    if (!gameUsed) return _NudgeState.postScanNoGame;

    if (daysSinceFreeFlow >= 7) return _NudgeState.gameStale7d;
    if (daysSinceFreeFlow >= 3) return _NudgeState.gameStale3d;

    return _NudgeState.defaultState;
  }

  // ── COPY POOL ───────────────────────────────────────────────────────
  // 6-10 lines per state. (title, body). No emojis. Specific. Loss-
  // framed. Friend warning voice.
  //
  // The picker hashes by today's date so consecutive days inside the
  // same state never repeat.

  static const _copyPool = <_NudgeState, List<(String, String)>>{
    _NudgeState.noScan: [
      ('Still unscanned',
       '30 seconds tells you what she actually sees.'),
      ('She decides in 8 seconds',
       'You don\'t even know your starting number.'),
      ('Scared of the score?',
       'It\'s not the number. It\'s not knowing.'),
      ('Open the app',
       'Scan once. Then we work on the version she chooses.'),
      ('Other men know theirs',
       'They\'ve been improving for weeks. Where are you?'),
    ],
    _NudgeState.postScanNoGame: [
      ('Looks opened the door',
       'Game closes it. You\'re halfway. Open Free Flow.'),
      ('You scanned. Now what?',
       'A face she notices is useless if you freeze when she talks.'),
      ('She\'d give you 8 seconds',
       'You\'ve never practiced the line that wins them.'),
      ('Halfway',
       'Free Flow is two minutes. Then you stop being theory.'),
      ('Tonight she\'ll text someone',
       'Make sure you know how to text her back.'),
    ],
    _NudgeState.protocolActive: [
      ('Don\'t break the spell',
       'Log today before midnight. Two minutes.'),
      ('You\'re mid-streak',
       'Keep going. The version of you it builds is worth it.'),
      ('She\'s starting to notice',
       'Don\'t go quiet now.'),
      ('Streak alive',
       'Two-minute check-in. Then you can rest.'),
      ('You\'ve done harder things',
       'Two minutes. Today. Lock it in.'),
    ],
    _NudgeState.protocolBroken: [
      ('Two days off',
       'You can still save the streak. Restart tonight.'),
      ('You broke',
       'Get back. Today. One day off is a slip — two becomes the story.'),
      ('He didn\'t break his streak',
       'You did. Decide which guy you want to be by midnight.'),
      ('The version she liked',
       'Is fading. You stopped showing up. Come back.'),
      ('One bad day',
       'Doesn\'t end it. Two does. Open the app.'),
    ],
    _NudgeState.gameStale3d: [
      ('Conversation going foreign',
       '3 days dry. The line you\'d send tonight is worse than last week\'s.'),
      ('Your voice rusted',
       '3 days. Open Free Flow. Even the AI is waiting.'),
      ('Reps don\'t wait',
       '3 days off and you\'re already slower. Two-minute rep tonight.'),
      ('She\'d feel the difference',
       '3 days off. You\'re going in cold next time. Don\'t.'),
      ('The muscle softens fast',
       '3 days. Reload one rep tonight.'),
    ],
    _NudgeState.gameStale7d: [
      ('A week of silence',
       'You used to know what to say. Open Free Flow. Reload.'),
      ('Right now he\'s better',
       'A week ago you were even. He kept training. You stopped.'),
      ('You went quiet',
       'A week. The next conversation will show it. Train tonight.'),
      ('She\'d send first',
       'A week ago you\'d have a line ready. Now you\'d freeze.'),
      ('Frame fading',
       'A full week. Two minutes tonight saves what you built.'),
    ],
    _NudgeState.dormant7d: [
      ('You went quiet',
       'She didn\'t.'),
      ('A week away',
       'The version you were building is rusting. Two minutes back.'),
      ('Other men didn\'t pause',
       'You did. Open the app before it stops mattering.'),
      ('Where did you go',
       'The work you started doesn\'t finish on its own.'),
    ],
    _NudgeState.dormant14d: [
      ('Three weeks. He didn\'t pause',
       'Open the app. Last call to keep what you built.'),
      ('You almost made it',
       'Then you stopped. Come back. The reps are still here.'),
      ('She moved on',
       'You didn\'t have to. Open the app.'),
      ('Two weeks dark',
       'Whatever stopped you stops here. Reopen. Two minutes.'),
    ],
    _NudgeState.defaultState: [
      ('Tonight, reload',
       'Two minutes of Free Flow keeps the muscle sharp.'),
      ('She\'s on her phone',
       'You should be ready. Open the app.'),
      ('Stay sharp',
       'Two minutes. Then sleep.'),
      ('Don\'t go cold',
       'Two-minute rep. Real conversation tomorrow stays effortless.'),
    ],
  };

  static (String, String) _copyForState(_NudgeState s) {
    final pool = _copyPool[s] ?? _copyPool[_NudgeState.defaultState]!;
    // Hash by today's date so the same state on consecutive days
    // never picks the same line. Two users on the same day with the
    // same state will see the same line — that's fine, it's daily,
    // not personalised.
    final now = DateTime.now();
    final dayKey = now.year * 10000 + now.month * 100 + now.day;
    final i = (dayKey + s.index) % pool.length;
    return pool[i];
  }
}

enum _NudgeState {
  noScan,
  postScanNoGame,
  protocolActive,
  protocolBroken,
  gameStale3d,
  gameStale7d,
  dormant7d,
  dormant14d,
  defaultState,
}
