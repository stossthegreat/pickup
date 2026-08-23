import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'local_store_service.dart';
import 'notification_service.dart';
import 'retention_service.dart';
import 'streak_service.dart';
import 'rolodex_service.dart';
import 'protocol_service.dart';
import 'win_back_service.dart';
import 'notification_media.dart';
import 'notification_channels.dart';
import 'roster.dart';

/// THE RETENTION ENGINE — a rolling 14-day notification horizon, two
/// beats a day, refreshed on every app open.
///
/// WHY A HORIZON (and not one repeating notification):
/// The old build scheduled ONE nudge with `matchDateTimeComponents.time`,
/// so the OS replayed the SAME frozen line every night until the app was
/// reopened. Two fatal consequences:
///   1. The copy never changed — the user saw one line on loop.
///   2. The STATE never changed — a user who stopped opening the app kept
///      getting the "you're active" line forever and NEVER escalated into
///      the win-back ladder. The comeback system was dead for exactly the
///      users it existed to recover.
///
/// THE FIX: schedule a distinct one-shot notification for every slot over
/// the next [_horizonDays] days. Each day's copy is computed for that day's
/// PROJECTED state (days-since-open keeps growing across the horizon), so
/// the ladder escalates on its own — Active → at-risk → dormant-7d →
/// dormant-14d — even if the user never reopens. Every app open resets the
/// clock and rebuilds the whole horizon from the current state, so the
/// ladder only ever fires when the user actually goes quiet.
///
/// TWO BEATS A DAY, mapped to the brand story "Looks get attention.
/// Game keeps it.":
///   • MORNING (09:00) — the DREAM pump. Aspirational, identity-forward.
///     "Become the guy she notices." Pulls the user toward the version of
///     himself the app builds.
///   • EVENING (19:30) — the STREAK / loss nudge. Powerful, loss-framed,
///     state-aware. "Don't fold on yourself." Drives the daily ritual.
///
/// THE STATE MACHINE — one read, projected forward per day:
///   NO_SCAN            — never scanned
///   POST_SCAN_NO_GAME  — scanned but never opened Free Flow
///   PROTOCOL_ACTIVE    — currently checked in on at least one axis
///   PROTOCOL_BROKEN    — at least one protocol's streak just broke
///   GAME_STALE_3D      — 3-6 days since last Free Flow
///   GAME_STALE_7D      — 7-13 days since last Free Flow
///   DORMANT_7D         — 7-13 days since last app open
///   DORMANT_14D        — 14+ days since last app open
///   DEFAULT            — active user, no specific signal
///
/// THE COPY — friend-warning + every-man's-dream voice. No emojis. No
/// "Hey [name]!". Specific, identity-anchored, never corporate cheer.
class DailyNudgeService {
  // ── Horizon shape ───────────────────────────────────────────────────
  /// How many days ahead we keep notifications queued. Refreshed on every
  /// app open, so this is a worst-case "if you stop now" win-back ladder.
  /// 14 days × 2 slots = 28 pending notifications — comfortably under the
  /// iOS 64-pending cap (rescan reminders add at most 2 more).
  static const _horizonDays = 14;

  /// Morning DREAM pump at 09:00; midday CLIMB tease at 13:00; evening
  /// STREAK nudge at 19:30. Three beats a day × 14 days = 42 pending —
  /// comfortably under the iOS 64-pending cap.
  static const _morningHour   = 9;
  static const _middayHour    = 13;
  static const _eveningHour   = 19;
  static const _eveningMinute = 30;

  /// ID blocks — one stable id per horizon day per slot so a refresh
  /// overwrites the previous horizon cleanly.
  static const _morningBase = 9100; // 9100 .. 9100+_horizonDays-1
  static const _middayBase  = 9300; // 9300 .. 9300+_horizonDays-1
  static const _eveningBase = 9200; // 9200 .. 9200+_horizonDays-1
  /// Legacy single-nudge id (pre-horizon). Cancelled on migrate.
  static const _legacyDailyId = 9001;

  static const _kLastFreeFlowKey = 'nudge.last_freeflow_ms';
  static const _kLastAppOpenKey  = 'nudge.last_app_open_ms';

  static FlutterLocalNotificationsPlugin get _plugin =>
      NotificationService.plugin;

  // ── Event marks — call these wherever the user does the thing. ───────

  static Future<void> markAppOpened() async {
    // Opening the app IS the answer to every push we sent. This zeroes
    // the ignore counter that the trust stop measures, and feeds the
    // histogram that decides what hour we send at.
    // ignore: discarded_futures
    RetentionService.noteOpen();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastAppOpenKey, DateTime.now().millisecondsSinceEpoch);
    await reschedule();
  }

  static Future<void> markFreeFlowSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastFreeFlowKey, DateTime.now().millisecondsSinceEpoch);
    await reschedule();
  }

  /// Wipe every legacy + prior-horizon notification, then queue a fresh
  /// 14-day, two-beats-a-day horizon picked from the current state. Safe
  /// to call repeatedly — every call is a clean rebuild.
  static Future<void> reschedule() async {
    try {
      // 0) Faces on disk before anything is scheduled. Deliberately here
      // and not in main(): iOS bakes the attachment in at SCHEDULE time,
      // so a horizon laid down before the images exist is faceless for
      // the next 14 days, and reschedule() has four call sites — one of
      // them would eventually forget. Guarded internally, so every call
      // after the first costs nothing.
      await NotificationMedia.prime();

      // 1) Clear legacy schedulers (streak/training/rescan) + the old
      // single daily nudge + any previous horizon we laid down.
      await NotificationService.cancelAllProtocolNotifications();
      await NotificationService.cancelTrainingNudge();
      await _plugin.cancel(_legacyDailyId);
      for (var d = 0; d < _horizonDays; d++) {
        await _plugin.cancel(_morningBase + d);
        await _plugin.cancel(_middayBase + d);
        await _plugin.cancel(_eveningBase + d);
      }

      // 2) One state read; projected forward per day inside the loop.
      final sig = await _readSignals();
      // The win-back window, if he's read the paywall and walked. When
      // it's live it TAKES OVER the evening slot rather than adding a
      // fourth beat: the evening beat is already the loss-framed one, and
      // a man who just declined to pay does not need two pushes a night.
      // Costs zero extra pending notifications this way.
      final winBack = await WinBackService.read();
      // HER, NOT US. If a woman in his Rolodex is going cold, the midday
      // slot becomes a message from her instead of another line of our
      // marketing. Every man alive has learned to swipe away "🔥 keep
      // your streak"; nobody has learned to swipe away a name they
      // recognise asking where they've been. Same slot, same cost, and
      // it's the only notification in the app that isn't the app
      // talking about itself.
      final cold = await Rolodex.coldest();

      // ── THE TRUST STOP ──────────────────────────────────────────
      // Duolingo's most copied notification is the passive-aggressive
      // owl. Their most VALUABLE one is the retreat — "these reminders
      // don't seem to be working, we're going to stop" — and almost
      // nobody copies it, because it costs sends. It's what protects
      // the channel: a notification permission is a trust balance,
      // every ignored push is a withdrawal, and an app that keeps
      // shouting past the point of being heard gets switched off at the
      // OS level, which is unrecoverable.
      final retreat = await RetentionService.trustStopDue();
      if (retreat != null) {
        final at = tz.TZDateTime.now(tz.local).add(const Duration(hours: 2));
        await _schedule(
            _eveningBase, retreat.$1, retreat.$2, at, slot: _Slot.streak);
        return; // and NOTHING else for the blackout window
      }
      if (await RetentionService.isQuiet()) return;

      // ── SEND-TIME ───────────────────────────────────────────────
      // Reported ~40% better open rates for sending inside a user's own
      // active window vs a fixed hour for everyone. Null until there's
      // real evidence — a histogram built from three opens is noise,
      // and guessing wrong costs more than not guessing.
      final learned = await RetentionService.bestHour();
      final eveningHour = learned ?? _eveningHour;

      final away = await RetentionService.daysSinceOpen();
      final (streak, _) = await StreakService.refresh();
      final tone =
          await RetentionService.tone(streak: streak, daysAway: away);

      // The next woman he has NOT earned yet — the face on the climb
      // tease. Null once he's unlocked the whole roster, in which case
      // the tease goes out without one rather than showing him someone
      // he already has.
      final ascensionDay = await _ascensionDay();
      final locked = [for (final g in kRoster) if (ascensionDay < g.unlockDay) g]
        ..sort((a, b) => a.unlockDay.compareTo(b.unlockDay));
      final nextLocked = locked.isEmpty ? null : locked.first;

      final now = tz.TZDateTime.now(tz.local);

      // 3) Lay down the horizon. Each slot is a distinct one-shot with its
      // own fireDate + its own pre-baked copy — NO matchDateTimeComponents,
      // because we WANT a different line every day, not a daily clone.
      for (var d = 0; d < _horizonDays; d++) {
        // MORNING — dream / identity pump.
        final morningAt = _slot(now, d, _morningHour, 0);
        if (morningAt.isAfter(now)) {
          final (t, b) = _dreamCopy(sig, d);
          await _schedule(_morningBase + d, t, b, morningAt, slot: _Slot.dream);
        }
        // MIDDAY — the climb / unlock tease. New women unlock as he climbs
        // the 60-day map; this is the retention hook to that loop.
        final middayAt = _slot(now, d, _middayHour, 0);
        if (middayAt.isAfter(now)) {
          // THE FACE IS THE MESSAGE.
          //
          // "Amara — you've gone quiet on me" with her photo is a text
          // from someone he knows. The identical words with no picture
          // are an app pretending to be one, and he can tell in the
          // quarter-second it takes to swipe. This is the whole reason
          // the slot exists, and it was the half that was missing.
          //
          // With nobody cooling, the climb tease carries the face of the
          // next woman he has NOT unlocked — "the ones who test you are
          // further up" lands differently when he can see who.
          final (t, b) = cold != null ? _herCopy(cold, d) : _climbCopy(d);
          final face = cold != null
              ? NotificationMedia.pathForGirl(cold.girlId)
              : (nextLocked == null
                  ? null
                  : NotificationMedia.pathForAsset(nextLocked.asset));
          await _schedule(_middayBase + d, t, b, middayAt,
              slot: cold != null ? _Slot.her : _Slot.dream,
              facePath: face,
              payload: cold != null ? 'her:${cold.girlId}' : 'dream');
        }
        // EVENING — streak / loss, escalating with projected dormancy.
        // Unless he's mid-win-back, in which case the sharper reason wins
        // the slot: he doesn't need telling to keep a streak he's locked
        // out of.
        final eveningAt = _slot(now, d, eveningHour, _eveningMinute);
        if (eveningAt.isAfter(now)) {
          // LUCIEN TAKES THE EVENING when there's no win-back running.
          //
          // Every retention push in this app was the product asking for
          // attention — "New women unlock as you climb", "Keep your
          // streak". Men have been trained for a decade to swipe those
          // away unread, and no amount of copywriting fixes a message
          // whose sender is a piece of software. Lucien is the coach,
          // the man already knows his name, and a notification from a
          // character you have a relationship with is a different
          // object to one from a brand. That's the whole of why the owl
          // works, and the owl is an owl.
          //
          // Tone follows engagement: loss framing on a man with no
          // streak is threatening him with nothing.
          final (t, b) = winBack != null
              ? WinBackService.ladderCopy(winBack, dayOffset: d)
              : Lucien.forTone(tone, d * 7 + tone.index);
          // Lucien's face. He is the one character the man has an
          // actual relationship with, and the coach saying it is a
          // different object to the app saying it.
          await _schedule(_eveningBase + d, t, b, eveningAt,
              slot: _Slot.streak, facePath: NotificationMedia.lucienPath);
        }
      }
      // Tally what we just laid down. The trust stop measures pushes
      // sent since his last open; RetentionService.noteOpen() zeroes it
      // the moment he shows up, so this only ever accumulates while
      // he's ignoring us.
      await RetentionService.noteSent(_horizonDays);
    } catch (e) {
      debugPrint('DailyNudgeService.reschedule failed: $e');
    }
  }

  /// Earned ascension day, or 1 if progress can't be read. Day 1 means
  /// only the starters count as unlocked, so a failure here shows him a
  /// tier-2 face rather than crashing the reschedule.
  static Future<int> _ascensionDay() async {
    try {
      return (await StreakService.progress()).ascensionDay;
    } catch (_) {
      return 1;
    }
  }

  // ── Scheduling helpers ──────────────────────────────────────────────

  static tz.TZDateTime _slot(
      tz.TZDateTime now, int dayOffset, int hour, int minute) {
    final base = now.add(Duration(days: dayOffset));
    return tz.TZDateTime(tz.local, base.year, base.month, base.day, hour, minute);
  }

  static Future<void> _schedule(
    int id,
    String title,
    String body,
    tz.TZDateTime at, {
    required _Slot slot,
    // Absolute path to a face on disk (NotificationMedia). When present
    // the push renders as a MESSAGE FROM A PERSON — her avatar on
    // Android, the attachment thumbnail on iOS — instead of an
    // announcement from an app. Null is always safe: the notification
    // goes out exactly as it did before, copy intact. A face is never
    // worth losing a send over.
    String? facePath,
    // Where the tap should land. Null falls back to the slot's own
    // default, which is what every push here wants; the HER slot passes
    // her id so the route can name her.
    String? payload,
  }) async {
    // Verify on the way in rather than trusting the cache: on Android
    // the file is read at DISPLAY time, up to 14 days from now, and a
    // path pointing at nothing is a broken-image notification. iOS is
    // stricter still — it rejects the whole scheduling call on a bad
    // attachment, which would silently cost us the send.
    String? face = facePath;
    if (face != null && !File(face).existsSync()) face = null;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      at,
      NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          // Red app-icon dot until the user opens the app; cleared by
          // NotificationService.clearIconBadge on foreground.
          badgeNumber: 1,
          attachments: face == null
              ? null
              : <DarwinNotificationAttachment>[
                  DarwinNotificationAttachment(face),
                ],
        ),
        android: AndroidNotificationDetails(
          slot.channelId,
          slot.channelName,
          channelDescription: slot.channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          // The avatar slot — the same place every messaging app puts
          // the sender's photo. Deliberately NOT BigPictureStyle: the
          // art is a square portrait, and Android crops a big picture
          // to a wide banner, which would take her face off. The small
          // round avatar is both safer and the more convincing object.
          largeIcon: face == null ? null : FilePathAndroidBitmap(face),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload ?? slot.name,
    );
  }

  // ── State read + projection ─────────────────────────────────────────

  static Future<_Signals> _readSignals() async {
    final prefs    = await SharedPreferences.getInstance();
    final scan     = await LocalStoreService.latestScan();
    final gameUsed = await LocalStoreService.gameFreeUsed();
    final actives  = await ProtocolService.loadAllActive();

    final now = DateTime.now();
    final lastFreeFlowMs = prefs.getInt(_kLastFreeFlowKey) ?? 0;
    final lastOpenMs =
        prefs.getInt(_kLastAppOpenKey) ?? now.millisecondsSinceEpoch;

    final daysSinceFreeFlow = lastFreeFlowMs == 0
        ? 9999
        : now
            .difference(DateTime.fromMillisecondsSinceEpoch(lastFreeFlowMs))
            .inDays;
    final daysSinceOpen = now
        .difference(DateTime.fromMillisecondsSinceEpoch(lastOpenMs))
        .inDays;

    final broken = actives.values.any(
        (p) => p.completedDays.isNotEmpty && p.effectiveStreak == 0);

    return _Signals(
      hasScan:           scan != null,
      gameUsed:          gameUsed,
      hasActiveProtocol: actives.isNotEmpty,
      hasBrokenProtocol: broken,
      daysSinceFreeFlow: daysSinceFreeFlow,
      daysSinceOpen:     daysSinceOpen,
    );
  }

  /// Project the state [dayOffset] days into the future, assuming the user
  /// does NOT reopen (every real open rebuilds the horizon from scratch).
  /// days-since-open and days-since-free-flow both grow with the offset, so
  /// the dormancy ladder escalates on its own across the queued horizon.
  static _NudgeState _stateFor(_Signals s, int dayOffset) {
    final dso  = s.daysSinceOpen + dayOffset;
    final dsff = s.daysSinceFreeFlow + dayOffset;

    if (dso >= 14)            return _NudgeState.dormant14d;
    if (dso >= 7)             return _NudgeState.dormant7d;
    if (s.hasBrokenProtocol)  return _NudgeState.protocolBroken;
    if (s.hasActiveProtocol)  return _NudgeState.protocolActive;
    if (!s.gameUsed)          return _NudgeState.postScanNoGame;
    if (dsff >= 7)            return _NudgeState.gameStale7d;
    if (dsff >= 3)            return _NudgeState.gameStale3d;
    return _NudgeState.defaultState;
  }

  // ── MORNING: dream / identity pump ──────────────────────────────────
  // The aspirational beat. Pulls the user toward the man the app builds —
  // the guy she notices, the guy whose game means any room is handled.
  // Pre-scan users get the "start the build" variant; everyone else gets
  // the full identity pump. Varied by day so the week never repeats.

  static (String, String) _dreamCopy(_Signals s, int dayOffset) {
    return _dreamPool[dayOffset % _dreamPool.length];
  }

  static const _dreamPool = <(String, String)>[
    ('Become the guy she notices',
     'Confidence is trained, not born. Put in today\'s reps.'),
    ('The room turns for the prepared',
     'Two minutes today on the man it turns for.'),
    ('She remembers the one who knew what to say',
     'Not the loudest. The smoothest. Practise it today.'),
    ('Any room. Any conversation. Handled',
     'That\'s the goal. One rep a day gets you there.'),
    ('60 days to become him',
     'Every rep moves you up the map. Take today\'s.'),
    ('Be the hardest man to ignore',
     'Built daily — practise, approach, repeat. Today counts.'),
    ('The guy with real game never runs dry',
     'Two minutes of roleplay builds him. Start.'),
    ('You weren\'t born smooth. You train it',
     'Today is a rep. Don\'t skip the man you\'re building.'),
    ('Walk in like the room is yours',
     'Because you did the reps they didn\'t. Begin today.'),
    ('Magnetic isn\'t luck',
     'It\'s reps rehearsed until they\'re instinct. Today.'),
    ('The version she chooses',
     'is the one who showed up every day. Be him today.'),
    ('Confidence is a trained skill',
     'Not a gift. Two minutes today. Compounds for life.'),
    ('Never freeze again',
     'The guy who always knows what to say practised until he did. Your turn.'),
    ('Always know your next line',
     'It isn\'t luck. It\'s reps. Take today\'s.'),
    ('Game is a skill you can train',
     'Not a personality you\'re born with. Start today.'),
  ];

  // ── MIDDAY (preferred): a message from a woman he actually won ──────
  //
  // The single highest-value copy change available to us, and it costs
  // one local read. Retention notifications fail because they are
  // transparently the product asking for attention. This one is a name
  // he earned, in her voice, referencing a relationship he built — and
  // the mechanic underneath is honest, because her warmth genuinely is
  // decaying and one message genuinely does restore it.
  //
  // ONE WOMAN, NEVER A LIST. Coldest only. A daily roll-call of dying
  // relationships is anxiety, and anxiety uninstalls apps.
  static (String, String) _herCopy(NumberCard c, int dayOffset) {
    final name = c.girl.name;
    final lines = <(String, String)>[
      (name, 'you\'ve gone quiet on me.'),
      (name, 'did you forget about me or…'),
      (name, 'so we\'re just not talking now?'),
      (name, 'i was starting to like you as well.'),
      (name, 'say something. i\'ll wait.'),
      (name, 'this is the part where you text back.'),
      (name, 'be honest — did you lose my number?'),
    ];
    return lines[dayOffset % lines.length];
  }

  // ── MIDDAY (fallback): the climb / unlock tease ─────────────────────
  // Ties the daily nudge to the app's core loop — new women unlock as he
  // climbs the 60-day map, and the streak is what keeps him climbing.
  // Salted by day so consecutive middays never repeat.

  static (String, String) _climbCopy(int dayOffset) =>
      _climbPool[dayOffset % _climbPool.length];

  static const _climbPool = <(String, String)>[
    ('New women unlock as you climb',
     'Every day on the map opens someone new. Don\'t stall at the start.'),
    ('The ones who test you are further up',
     'Ice queen, high-value, the girls who make you work — they unlock as you climb.'),
    ('Someone new is a few days out',
     'Keep the streak and she opens. Fold and she doesn\'t. Your move.'),
    ('You\'re one rep off the next rung',
     'Two minutes moves you up the map. Skipping moves you nowhere.'),
    ('She noticed you were gone',
     'Your girls remember where you left off. Pick it back up.'),
    ('Day by day, you become him',
     'It\'s a ladder, not a leap. Take today\'s rung.'),
    ('The map only moves if you show',
     'Open the app. One rep. Watch the day tick up.'),
    ('Closer than yesterday',
     'Every real rep drags you toward the man rooms remember. Take one now.'),
    ('Don\'t let the streak decide for you',
     'A quiet day stalls the climb. Two minutes keeps it alive.'),
    ('The best girls aren\'t on Day 1',
     'They\'re up the map, waiting for the version of you that got there.'),
  ];

  // ── EVENING: streak / loss nudge ────────────────────────────────────
  // The daily-ritual beat. Loss-framed, identity-anchored. Same proven
  // state pools as before — picked per horizon day, salted by state +
  // offset so consecutive days never land the same line.

  static (String, String) _streakCopy(_NudgeState s, int dayOffset) {
    final pool = _streakPool[s] ?? _streakPool[_NudgeState.defaultState]!;
    final i = (s.index * 7 + dayOffset) % pool.length;
    return pool[i];
  }

  static const _streakPool = <_NudgeState, List<(String, String)>>{
    _NudgeState.noScan: [
      ('Day one is one tap away',
       'Open the app. Your first rep starts the climb.'),
      ('She decides in 8 seconds',
       'Practise until those 8 seconds go your way.'),
      ('Scared to start?',
       'It\'s not the reps. It\'s staying the guy who freezes.'),
      ('Open the app',
       'One rep. Then we build the version she chooses.'),
      ('Other men are already training',
       'They\'ve been at it for weeks. Where are you?'),
      ('Your first two minutes',
       'One roleplay in. The climb to becoming him begins.'),
      ('Meet the man you\'re building',
       'Two minutes tonight. The version the room remembers.'),
      ('The climb starts tonight',
       'Open the app. Start becoming the guy who owns the room.'),
      ('Become impossible to overlook',
       'Two-minute rep. A 60-day plan. Tonight.'),
    ],
    _NudgeState.postScanNoGame: [
      ('You\'re in. Now prove it',
       'Practice is two minutes. Then you stop being theory.'),
      ('Reading about game isn\'t game',
       'A girl\'s waiting in Practice. Say the first line.'),
      ('She\'d give you 8 seconds',
       'You\'ve never practised the line that wins them.'),
      ('One rep in',
       'Open Practice. Two minutes. Then you\'re not guessing.'),
      ('Tonight she\'ll text someone',
       'Make sure you know how to text her back.'),
      ('Practise roleplay until you\'re the smoothest',
       'Two minutes builds the voice she replays.'),
      ('Become the guy that always knows what to say',
       'Open Practice. Train the line. Show up sharp tomorrow.'),
      ('The voice she replays',
       'Two-minute roleplay tonight. Effortless tomorrow.'),
      ('Theory into instinct',
       'Practice turns what you know into what you do. Tap in.'),
    ],
    _NudgeState.protocolActive: [
      ('Don\'t break the chain',
       'Log today before midnight. Two minutes.'),
      ('You\'re mid-streak',
       'Keep going. The version of you it builds is worth it.'),
      ('She\'s starting to notice',
       'Don\'t go quiet now.'),
      ('Streak alive',
       'Two-minute check-in. Then you can rest.'),
      ('You\'ve done harder things',
       'Two minutes. Today. Lock it in.'),
      ('Stack one more day',
       'Every check-in compounds. You\'re becoming him.'),
      ('Streak is your edge',
       'Log tonight. Wake up sharper than yesterday.'),
      ('Two minutes. Lock the version she chooses',
       'The man at the end of this streak is the one rooms remember.'),
      ('You\'re building him in real time',
       'Tonight\'s log is tomorrow\'s confidence. Tap in.'),
    ],
    _NudgeState.protocolBroken: [
      ('Don\'t fold on yourself',
       'You can still save the streak. Restart tonight.'),
      ('You broke',
       'Get back. Today. One day off is a slip — two becomes the story.'),
      ('He didn\'t break his streak',
       'You did. Decide which guy you want to be by midnight.'),
      ('The version she liked',
       'Is fading. You stopped showing up. Come back.'),
      ('One bad day',
       'Doesn\'t end it. Two does. Open the app.'),
      ('Restart tonight',
       'The version she falls for is one streak away. Begin.'),
      ('Comeback streak hits different',
       'Day one again. Two minutes. Be the guy who returns.'),
      ('The man rooms remember',
       'Is the one who restarted. Log tonight.'),
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
      ('Reload the smooth',
       'Two-minute Free Flow. Tomorrow\'s conversation stays effortless.'),
      ('Sharpen the line tonight',
       'One rep now. Walk into tomorrow ready.'),
      ('Practice until you\'re unflappable',
       'Two minutes. The man she chases is built in reps like this.'),
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
      ('Get back to the smoothest you',
       'Two minutes tonight. The week off becomes a story.'),
      ('Train until you\'re the smoothest',
       'A week\'s rust. One rep clears it. Open Free Flow.'),
      ('The line that wins her',
       'You stopped practicing it. Reload tonight.'),
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
      ('Come back to the version that owns rooms',
       'Two minutes. Right back where you left off.'),
      ('The guy who owns the room',
       'Is still inside. Open the app. Two minutes tonight.'),
      ('Welcome back, future smoothest',
       'Reload one rep. Tomorrow you\'re sharp again.'),
    ],
    _NudgeState.dormant14d: [
      ('Two weeks. He didn\'t pause',
       'Open the app. Last call to keep what you built.'),
      ('You almost made it',
       'Then you stopped. Come back. The reps are still here.'),
      ('She moved on',
       'You didn\'t have to. Open the app.'),
      ('Two weeks dark',
       'Whatever stopped you stops here. Reopen. Two minutes.'),
      ('Restart the climb',
       'One rep. Two minutes. The guy the room remembers, again.'),
      ('The man she chases',
       'Is two minutes back. Open the app. Reload.'),
      ('Come back smoother',
       'Two minutes tonight. Pick up where the streak left you.'),
    ],
    _NudgeState.defaultState: [
      ('Tonight, reload',
       'Two minutes of Free Flow keeps the muscle sharp.'),
      ('Someone just opened your chat',
       'You should be ready. Open the app.'),
      ('Stay sharp',
       'Two minutes. Then sleep.'),
      ('Don\'t go cold',
       'Two-minute rep. Real conversation tomorrow stays effortless.'),
      ('Become the guy that always knows what to say',
       'Two minutes tonight. Walk in smooth tomorrow.'),
      ('Practice until you\'re the smoothest',
       'One rep tonight. The version she replays.'),
      ('Sharpen the smooth',
       'Two minutes. Tomorrow\'s conversation owes you nothing.'),
      ('Build the man she can\'t ignore',
       'One rep. Every night. The compounding is silent.'),
    ],
  };
}

class _Signals {
  final bool hasScan;
  final bool gameUsed;
  final bool hasActiveProtocol;
  final bool hasBrokenProtocol;
  final int  daysSinceFreeFlow;
  final int  daysSinceOpen;
  const _Signals({
    required this.hasScan,
    required this.gameUsed,
    required this.hasActiveProtocol,
    required this.hasBrokenProtocol,
    required this.daysSinceFreeFlow,
    required this.daysSinceOpen,
  });
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

/// Which of the three daily beats a notification belongs to. Carries the
/// Android channel with it so a slot can never be filed under the wrong
/// one — see NotifChannels for why that matters.
enum _Slot {
  /// Morning identity pump, and the midday climb tease. The app's own
  /// voice.
  dream(NotifChannels.dream, 'Daily motivation',
      'Morning push toward the man you\'re building.'),

  /// A woman from his Rolodex, by name and face. Its own channel so it
  /// survives him muting the motivation.
  her(NotifChannels.her, 'Messages',
      'When a woman you\'ve been talking to goes quiet.'),

  /// Evening streak / loss nudge, delivered by Lucien.
  streak(NotifChannels.streak, 'Streak reminders',
      'Evening nudge to keep your streak alive.');

  const _Slot(this.channelId, this.channelName, this.channelDescription);
  final String channelId;
  final String channelName;
  final String channelDescription;
}
