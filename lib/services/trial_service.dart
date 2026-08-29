import 'package:shared_preferences/shared_preferences.dart';

/// THE FREE TRIAL — full access to everything except the expensive part.
///
/// WHAT THE STORE DOES AND WHAT THE APP HAS TO DO.
///
/// The trial itself is an Introductory Offer configured in App Store
/// Connect / Play Console and surfaced by RevenueCat. During it the
/// `pro` entitlement is ACTIVE — the store gives you one bit, on or
/// off, and no way to say "active, but less". So every trial-only limit
/// has to be enforced here.
///
/// THE SHAPE: unlimited texting, ONE minute of live voice.
///
/// That split is not arbitrary. Texting costs fractions of a penny a
/// turn and is where a man works out whether the women are any good —
/// capping it would be capping the thing that sells the product. Live
/// voice is the entire cost base (~$0.02–0.03/min on realtime-mini) and
/// is also the thing he most wants, so one minute is a taste that
/// cannot be farmed. A trial that hands out the weekly 14 minutes is a
/// free week of the only expensive feature, taken by everyone who never
/// intends to pay.
///
/// WHY THE BUDGET IS A LIFETIME COUNTER, NOT THE WEEKLY BUCKET.
/// The weekly allowance resets on a rolling 7-day window. A 3-day trial
/// that happened to straddle a reset would silently hand out two
/// minutes instead of one, and a 7-day trial would hand out two every
/// time. This counter only ever goes up, so the trial minute is spent
/// exactly once no matter when it falls.
///
/// PAID MINUTES STILL WORK. If a man in trial buys an EXTRA pack, those
/// minutes are his — the bank is checked alongside this. Selling
/// someone minutes and then refusing to let him speak them would be the
/// single worst bug this feature could ship with.
///
/// ON CONVERSION nothing needs migrating: the weekly bucket is keyed by
/// time window and has simply never been touched during the trial, so
/// his first paid week starts at a full 14 minutes.
abstract final class TrialService {
  /// Live voice minutes for the whole trial. Not per week — per trial.
  ///
  /// THIS NUMBER IS THE COST DIAL. It is the only place a man who never
  /// intends to pay can spend money we do not get back, so it is worth
  /// stating exactly what it buys.
  ///
  /// Voice runs on gpt-realtime-mini (routes/realtime.js — the full
  /// model is creator-only and stays that way). Working from OpenAI's
  /// own per-minute approximations for the realtime family, a minute of
  /// two-way conversation on mini lands around 2-3 cents once the
  /// session prompt and the end-of-call grade are counted in. Check it
  /// against the first real bill rather than trusting this comment.
  ///
  /// TWO — EXACTLY ONE TEST, AND NOT A SECOND MORE.
  ///
  /// This is deliberately the length of one session
  /// (_FreeFlowScreenState._sessionSeconds) and not a minute over. The
  /// trial buys him the demonstration and nothing else: he takes the
  /// two-minute test, gets his number, and the next time he reaches for
  /// the orb he is told — plainly, not sold at — that the full weekly
  /// allowance starts when the trial converts.
  ///
  /// One was worse than two, not cheaper: the test itself was cut off
  /// at sixty seconds and he was scored on half a conversation. Three
  /// was worse than two the other way: a spare minute is a second demo,
  /// and the man who has had two demos has less reason to pay for the
  /// third than the man left standing at the end of his first.
  ///
  /// The exposure: a trial user who burns it and cancels costs roughly
  /// 5p of voice plus pennies of text. One conversion at £19.99 covers
  /// about four hundred of them.
  static const trialVoiceMinutes = 2;

  static const _kInTrial = 'trial.active.v1'; // legacy bool
  /// Tri-state: 'paid', 'trial', or absent (= never resolved).
  static const _kTrialState = 'trial.state.v2';
  static const _paid = 'paid';
  static const _trial = 'trial';
  static const _kUsedMs  = 'trial.voice_used_ms.v1';
  static const _kEverHad = 'trial.ever_started.v1';

  static int get trialVoiceMs => trialVoiceMinutes * 60 * 1000;

  /// Cached from RevenueCat's entitlement periodType. Synchronous
  /// reads are not safe here (the voice gate is on a hot path and this
  /// is a network-derived fact), so it is mirrored into prefs by
  /// PurchaseService and read back from there.
  static Future<bool> isTrial() async {
    final prefs = await SharedPreferences.getInstance();

    // ── FAIL CLOSED. THIS DEFAULTED TO FALSE AND IT COST US ───────────
    //
    // `?? false` meant "we have not heard from the store yet, so give
    // him the FULL PAID ALLOWANCE." A man who had just started the
    // trial reached the orb before RevenueCat's listener had written
    // anything, read as a full subscriber, and spent the paid weekly
    // fourteen minutes. That is the leak that was reported, and it is
    // the single most expensive default in the app.
    //
    // The state is a tri-state now: 'paid', 'trial', or ABSENT. Absent
    // means we do not know, and not knowing must resolve to the
    // restrictive answer. Only a positively confirmed NORMAL period
    // opens the full allowance.
    //
    // Cost of being wrong each way, which is the whole argument: a real
    // subscriber briefly capped at two minutes sees the wall for a few
    // seconds until the next store refresh corrects it. A trial user
    // wrongly read as paid costs real money and cannot be taken back.
    final state = prefs.getString(_kTrialState);
    if (state != null) return state != _paid;

    // ── THE LEGACY BOOL IS ONLY TRUSTED IN ONE DIRECTION ──────────────
    //
    // A `true` on the old key means the old code positively identified
    // a trial, and that is still true. Carry it.
    //
    // A `false` CANNOT BE TRUSTED, and migrating it to `paid` was about
    // to make this whole fix useless. The old code wrote `false` for
    // every trial user it failed to recognise — which was all of them
    // on an introductory offer — so the leaked devices are carrying
    // exactly that value. Honouring it would stamp them "confirmed
    // payer" permanently and hand them the fourteen minutes again, on
    // the build that was supposed to stop it.
    //
    // So a legacy false is treated as UNRESOLVED: restrictive until the
    // store says otherwise. A genuine subscriber is capped for the few
    // seconds it takes _refreshEntitlementCache to run on that same
    // launch, then gets everything back. A leaked device is caught.
    if (prefs.getBool(_kInTrial) == true) {
      await prefs.setString(_kTrialState, _trial);
      return true;
    }
    return true; // unresolved, or an untrustworthy legacy false
  }

  /// Mirror of the store's truth. Called from the entitlement refresh
  /// and the customer-info listener, so a trial converting to paid
  /// unlocks the full allowance without an app restart.
  static Future<void> setTrial(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTrialState, active ? _trial : _paid);
    await prefs.setBool(_kInTrial, active); // legacy mirror
    if (active) await prefs.setBool(_kEverHad, true);
  }

  /// Wipe the resolved state so the next read falls back to the
  /// restrictive default. Used when the store says the man is not Pro
  /// at all — a lapsed or cancelled account must not keep a stale
  /// "confirmed paid" stamp sitting on disk.
  static Future<void> clearResolved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTrialState);
    await prefs.remove(_kInTrial);
  }

  /// Has this device ever been in a trial? Used only for copy — the
  /// store owns actual eligibility and will refuse a second one.
  static Future<bool> everStarted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEverHad) ?? false;
  }

  static Future<int> usedMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kUsedMs) ?? 0;
  }

  /// TEST ONLY — reset the lifetime counter so the trial rig can run
  /// the cap again without a reinstall. Reachable only from the
  /// creator-mode tile in Settings, which takes the creator password.
  static Future<void> resetUsedForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUsedMs, 0);
  }

  /// Trial voice left, in ms. Never negative.
  static Future<int> remainingMs() async {
    final used = await usedMs();
    final left = trialVoiceMs - used;
    return left < 0 ? 0 : left;
  }

  /// Spend against the trial budget. Returns what could NOT be covered,
  /// so the caller can draw the remainder from paid minutes rather than
  /// silently swallowing it.
  static Future<int> spend(int deltaMs) async {
    if (deltaMs <= 0) return 0;
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_kUsedMs) ?? 0;
    final left = (trialVoiceMs - used).clamp(0, trialVoiceMs);
    final take = deltaMs > left ? left : deltaMs;
    if (take > 0) await prefs.setInt(_kUsedMs, used + take);
    return deltaMs - take;
  }
}
