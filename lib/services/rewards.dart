import 'package:shared_preferences/shared_preferences.dart';

import 'boost_service.dart';
import 'live_events.dart';
import 'local_store_service.dart';
import 'milestone_service.dart';
import 'standing.dart';
import 'streak_service.dart';

/// ══════════════════════════════════════════════════════════════════════
///  REWARDS — the only door XP comes through
/// ══════════════════════════════════════════════════════════════════════
///
/// WHAT THE AUDIT FOUND, and it is the whole answer to "make sure users
/// are always winning":
///
/// EXACTLY ONE PLACE IN THE APP AWARDED XP. `missions_tab_screen`,
/// ticking off one of the five daily missions. That was it. Which meant
/// a man could:
///
///   · run THE DAILY — the flagship event, a live voice conversation
///     with a woman, graded on five axes — and gain NOTHING
///   · win a ranked BATTLE against another human — NOTHING
///   · spend twenty minutes in PRACTICE — NOTHING
///   · press the FEAR BUTTON and walk up to a stranger in real life,
///     the single hardest and most valuable thing the product asks of
///     anyone — NOTHING
///   · complete a SQUAD MISSION and be shown a toast saying "+100 XP"
///     while the app granted him zero. It was lying to him.
///
/// So the progression bar only moved on one screen, and every other
/// screen — including the good ones — was effort with no deposit. That
/// is not a gamification problem you fix with a nicer badge. The economy
/// had one faucet.
///
/// ── THE RULES ────────────────────────────────────────────────────────
///
/// 1. IF IT COSTS HIM SOMETHING, IT PAYS. Effort with no deposit is the
///    fastest way to teach someone a screen isn't worth opening.
///
/// 2. REAL BEATS AI, ALWAYS, BY A LOT. economy.dart rule 3. A real-world
///    approach pays several times an AI conversation, because AI is
///    TRAINING and a real conversation is PROOF, and if the numbers
///    don't say that out loud the product doesn't mean anything.
///
/// 3. PERFORMANCE SCALES IT, BUT SHOWING UP ALWAYS PAYS. A bad daily
///    still pays the floor. Zero for a poor attempt punishes the exact
///    men who need to attempt again, and the whole product is built on
///    them attempting again.
///
/// 4. EVERYTHING FARMABLE HAS A DAILY CEILING. Practice pays, and it
///    pays a capped amount per day, because an economy you can grind
///    infinitely is one where the number stops meaning anything within a
///    week.
///
/// 5. ONE DOOR. Nothing calls LocalStoreService.addXp directly any more.
///    Every grant goes through here so the rates live in one file, the
///    caps can't be forgotten, and the milestone check can't be skipped
///    — a level that isn't detected is a level that doesn't get
///    celebrated, which was the other half of the complaint.
abstract final class Rewards {
  // ── RATES ───────────────────────────────────────────────────────────
  //
  // Anchored to the mission ladder that already existed: an AI mission
  // pays 50–90, a real-world one 165–345. Everything below is priced
  // against that so the app has ONE sense of what an hour is worth.

  /// THE DAILY — floor plus performance. Roughly an AI mission at worst,
  /// better than the best one at 100/100. It's the event of the day and
  /// it should out-pay a tick-box.
  static const dailyFloor = 60;
  static const dailyPerPoint = 0.9; // ×100 → +90

  /// A BATTLE. Paid for FIGHTING, with a win bonus on top. Losing still
  /// pays, and that's deliberate: a ladder where defeat costs you RR
  /// *and* pays nothing is one men stop queueing on after two losses.
  static const battleFought = 70;
  static const battleWon = 60;

  /// PRACTICE. Real value, easily farmed, so it's the smallest rate and
  /// the tightest cap.
  static const practicePerMinute = 8;
  static const practiceDailyCap = 60;

  /// THE FEAR BUTTON — an actual approach, in the actual world.
  ///
  /// The biggest single number in the app on purpose. It is the thing
  /// everything else is practice FOR, it is the hardest thing anyone
  /// here will do all week, and the economy has to say so louder than
  /// any AI conversation can.
  static const approach = 300;
  static const approachDailyCap = 900; // three, then it's a different day

  /// A SQUAD MISSION. Priced at a real mission because that's what it
  /// is — and because the app has been showing a "+100 XP" toast for
  /// this while granting nothing.
  static const squadMission = 150;

  /// A NUMBER WON off a woman in the Rolodex, and a PERFECT LINE. Small
  /// bonuses that ride on top of whatever paid already — they're spice,
  /// not salary.
  static const numberWon = 40;
  static const perfectLine = 25;

  // ══════════════════════════════════════════════════════════════════
  //  THE DOOR
  // ══════════════════════════════════════════════════════════════════

  /// Bank XP, show the toast, and queue any milestone it crossed.
  ///
  /// [cap] and [capKey], when given, enforce a per-day ceiling for that
  /// source — the grant is trimmed to whatever's left rather than
  /// refused outright, because "you've earned 4 of your 60" beats a
  /// silent zero.
  /// The last grant, parked for the payout screen.
  ///
  /// Duolingo's end-of-lesson screen is the single most-copied thing in
  /// mobile and the reason is that it shows FOUR bars moving off ONE
  /// action — XP, streak, league, achievement — in one frame. Ours had
  /// the four systems and no moment where they moved together, so a man
  /// finished a daily and saw a score, then maybe a toast, then nothing.
  ///
  /// This is stashed rather than returned because the reward is granted
  /// deep inside a flow that has no business knowing about a screen, and
  /// the screen is shown at the surface. See payout_screen.dart.
  static Grant? lastGrant;

  static Future<int> grant(
    int amount,
    String label, {
    int? cap,
    String? capKey,
    String? firstKey,
  }) async {
    var pay = amount;

    // ── THE FIRST TIME HE DOES ANYTHING ──────────────────────────────
    //
    // A new man's first five minutes decide whether this app is for
    // him, and the honest way to load that period with wins is to pay
    // properly for FIRSTS rather than to fake progress he hasn't made.
    // His first daily, first duel, first practice session and first
    // approach each pay double, once, forever.
    var first = false;
    if (firstKey != null) {
      first = await _claimFirst(firstKey);
      if (first) pay *= 2;
    }

    // ── THE BOOST ────────────────────────────────────────────────────
    //
    // Applied BEFORE the cap, deliberately. A boosted hour of practice
    // still can't beat an unboosted day's ceiling — the window
    // front-loads what he earns, it doesn't inflate it.
    final boosted = await BoostService.active;
    if (boosted) pay *= BoostService.multiplier;

    if (cap != null && capKey != null) {
      pay = await _trimToCap(pay, cap, capKey);
    }
    if (pay <= 0) return 0;

    final before = await LocalStoreService.xpTotal();
    await LocalStoreService.addXp(pay);
    final after = before + pay;

    // Accumulate within one flow. A battle grants XP for fighting AND
    // the conversation counts — he should see one number, not two
    // payout screens back to back.
    final prev = lastGrant;
    lastGrant = Grant(
      amount: prev == null ? pay : prev.amount + pay,
      label: prev == null ? label : prev.label,
      xpBefore: prev?.xpBefore ?? before,
      xpAfter: after,
      firstTime: first || (prev?.firstTime ?? false),
      boosted: boosted || (prev?.boosted ?? false),
    );

    LiveEvents.xp(pay, label);
    await _settle();
    return pay;
  }

  /// Detect whatever the grant just crossed. Doesn't show anything —
  /// milestone_service queues, and the screen with a context drains.
  static Future<void> _settle() async {
    final xp = await LocalStoreService.xpTotal();
    final snap = await StreakService.progress();
    final days = snap.ascensionDay;
    await MilestoneService.check(
      level: Standing.levelFor(xp),
      rankRung: Standing.rungFor(days),
      rankLabel: Standing.rankFor(days).label,
    );
  }

  /// True exactly once per key, ever.
  static Future<bool> _claimFirst(String key) async {
    final p = await SharedPreferences.getInstance();
    final k = 'rw.first.$key';
    if (p.getBool(k) == true) return false;
    await p.setBool(k, true);
    return true;
  }

  static int _ymd() {
    final n = DateTime.now();
    return n.year * 10000 + n.month * 100 + n.day;
  }

  /// How much of [want] is left under today's ceiling for this source.
  static Future<int> _trimToCap(int want, int cap, String key) async {
    final p = await SharedPreferences.getInstance();
    final dayKey = 'rw.$key.ymd';
    final sumKey = 'rw.$key.sum';
    final today = _ymd();
    final spent = p.getInt(dayKey) == today ? (p.getInt(sumKey) ?? 0) : 0;
    final room = cap - spent;
    if (room <= 0) return 0;
    final pay = want > room ? room : want;
    await p.setInt(dayKey, today);
    await p.setInt(sumKey, spent + pay);
    return pay;
  }

  /// What's left under a source's ceiling today — for a screen that
  /// wants to say so honestly instead of paying zero without comment.
  static Future<int> remainingToday(String capKey, int cap) async {
    final p = await SharedPreferences.getInstance();
    final spent =
        p.getInt('rw.$capKey.ymd') == _ymd() ? (p.getInt('rw.$capKey.sum') ?? 0) : 0;
    final left = cap - spent;
    return left < 0 ? 0 : left;
  }

  // ══════════════════════════════════════════════════════════════════
  //  THE SOURCES
  // ══════════════════════════════════════════════════════════════════

  /// One of the five daily missions.
  static Future<int> mission(int xp, String title) => grant(xp, title);

  /// THE DAILY, voice or chat. [aiScore] is 0–100.
  ///
  /// Floor plus performance, so a rough attempt still deposits. The one
  /// thing this must never do is pay nothing for a bad score — the man
  /// who scored 31 is precisely the man the product needs back tomorrow.
  static Future<int> daily(int aiScore) => grant(
        dailyFloor + (aiScore.clamp(0, 100) * dailyPerPoint).round(),
        'The Daily',
        firstKey: 'daily',
      );

  /// A settled duel.
  static Future<int> battle({required bool won}) => grant(
      battleFought + (won ? battleWon : 0),
      won ? 'Battle won' : 'Battle fought',
      firstKey: 'battle');

  /// Time actually spent in a live practice conversation. Capped.
  static Future<int> practice(Duration spent) {
    final mins = spent.inSeconds ~/ 60;
    if (mins < 1) return Future.value(0);
    return grant(
      mins * practicePerMinute,
      'Practice',
      cap: practiceDailyCap,
      capKey: 'practice',
      firstKey: 'practice',
    );
  }

  /// He walked up to someone. In real life.
  static Future<int> realApproach() => grant(
        approach,
        'YOU APPROACHED',
        cap: approachDailyCap,
        capKey: 'approach',
        firstKey: 'approach',
      );

  static Future<int> squad(String title) => grant(squadMission, title);

  static Future<int> number(String girlName) =>
      grant(numberWon, '$girlName gave you her number', firstKey: 'number');

  static Future<int> line() => grant(perfectLine, 'Perfect line');
}

/// What one flow paid out, from the first grant to the last.
class Grant {
  final int amount;
  final String label;
  final int xpBefore;
  final int xpAfter;

  /// Something in this flow was a first — the payout says so, because
  /// "FIRST ONE · DOUBLE" is the difference between a number and a
  /// moment he remembers.
  final bool firstTime;

  /// The boost window was open. Also printed, because a multiplier he
  /// doesn't notice teaches him nothing about coming back inside the
  /// window next time.
  final bool boosted;

  const Grant({
    required this.amount,
    required this.label,
    required this.xpBefore,
    required this.xpAfter,
    this.firstTime = false,
    this.boosted = false,
  });
}
