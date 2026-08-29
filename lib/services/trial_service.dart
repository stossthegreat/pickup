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
  /// THREE, not one. One meant the onboarding voice test — a two-minute
  /// session — got cut off at sixty seconds for exactly the man it has
  /// to convince: the one who just started the trial. Three lets the
  /// test run its full length and leaves him a minute of his own
  /// afterwards, which is the minute that sells the subscription.
  ///
  /// The exposure: a trial user who burns it all and cancels costs
  /// roughly 7p of voice plus pennies of text. A thousand of them is a
  /// pub lunch. One conversion at £19.99 pays for about 260 of them.
  static const trialVoiceMinutes = 3;

  static const _kInTrial = 'trial.active.v1';
  static const _kUsedMs  = 'trial.voice_used_ms.v1';
  static const _kEverHad = 'trial.ever_started.v1';

  static int get trialVoiceMs => trialVoiceMinutes * 60 * 1000;

  /// Cached from RevenueCat's entitlement periodType. Synchronous
  /// reads are not safe here (the voice gate is on a hot path and this
  /// is a network-derived fact), so it is mirrored into prefs by
  /// PurchaseService and read back from there.
  static Future<bool> isTrial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kInTrial) ?? false;
  }

  /// Mirror of the store's truth. Called from the entitlement refresh
  /// and the customer-info listener, so a trial converting to paid
  /// unlocks the full allowance without an app restart.
  static Future<void> setTrial(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kInTrial, active);
    if (active) await prefs.setBool(_kEverHad, true);
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
