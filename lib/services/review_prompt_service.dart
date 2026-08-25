import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../navigation/app_router.dart';
import '../widgets/review_prompt_dialog.dart';
import 'analytics_service.dart';

/// THE REVIEW LADDER — ask repeatedly, at peaks, until he acts.
///
/// WHAT WAS WRONG. Two things, and the second one made the first
/// invisible:
///
///   1. ONE PROMPT PER DEVICE, EVER. A single `review.prompted` bool,
///      set by whichever aha moment came first, and that was the app's
///      entire lifetime allowance. A man who hit Not Now while walking
///      down the street was never asked again.
///   2. On iOS the button did nothing. kAppStoreId was empty, so
///      "Write a Review" fell through to the native StoreKit sheet,
///      which Apple silently draws as NOTHING past ~3 prompts a year.
///      Fixed in app_store_config.dart — read the note there.
///
/// So the real ask rate was: once, and the once often did nothing.
///
/// WHAT THIS DOES NOW. Every peak moment is a chance to ask, up to
/// [_maxAsks] times, with a cooldown that grows between them. He is
/// asked at his best moments, more than once, for as long as he keeps
/// not acting.
///
/// WHAT IT DELIBERATELY DOES NOT DO. Neither platform will tell an app
/// whether a review was actually left — there is no API, on purpose.
/// The closest signal we have is that he tapped through to the store,
/// and once he has, hammering him is how an app collects one-star
/// reviews about being hammered. So the store tap buys near-silence:
/// one last ask, three weeks out, and then never again.
///
/// It also never asks for a SPECIFIC rating and never trades anything
/// for one — App Store Review Guideline 1.1.7 and Play policy both
/// forbid it, and it is the fastest way to lose the listing this is all
/// meant to feed.
class ReviewPromptService {
  // ── Milestone marks (no UI) ────────────────────────────────────────
  static const _kScanDone     = 'review.scan_done';
  static const _kFreeFlowDone = 'review.freeflow_done';
  static const _kEyesDone     = 'review.eyes_done';

  // ── Ladder state ───────────────────────────────────────────────────
  /// How many times the card has been shown on this device.
  static const _kAsks = 'review.asks';
  /// When it was last shown, ms since epoch.
  static const _kLastAsk = 'review.last_ask_ms';
  /// He tapped through to the store. The closest thing to "he reviewed"
  /// that either platform will give us.
  static const _kSent = 'review.sent';
  /// Legacy one-shot flag. Read once on migrate so a man who was already
  /// asked under the old system doesn't get the whole ladder at once.
  static const _kLegacyPrompted = 'review.prompted';

  /// Total asks before we stop. Five over a lifetime is aggressive by
  /// the standards of most apps and still far short of the point where
  /// a man reaches for the store to complain about it.
  static const _maxAsks = 5;

  /// Days to wait after ask N before ask N+1. The first two are close
  /// together on purpose — a man who says Not Now in a queue is not the
  /// same man as one who says it after a rep that went well.
  static const _cooldownDays = <int>[0, 1, 3, 7, 21];

  /// After he has tapped through to the store, exactly one more ask,
  /// this far out — then silence for good.
  static const _afterSentDays = 21;

  static Future<void> markScanDone()     => _setFlag(_kScanDone);
  static Future<void> markFreeFlowDone() => _setFlag(_kFreeFlowDone);
  static Future<void> markEyesDone()     => _setFlag(_kEyesDone);

  /// Called by the dialog the moment it opens the store. Public because
  /// the dialog owns the tap and this service owns the schedule.
  static Future<void> markSentToStore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSent, true);
    // Burn the remaining rungs down to one. Without this the flag only
    // stretched the COOLDOWN and a man who tapped through on his first
    // ask still got three more over the next two months — the exact
    // behaviour this was supposed to prevent. He acted; he gets one
    // reminder, a long way out, and that is the end of it.
    final asks = prefs.getInt(_kAsks) ?? 0;
    if (asks < _maxAsks - 1) await prefs.setInt(_kAsks, _maxAsks - 1);
    // ignore: discarded_futures
    AnalyticsService.reviewNativeOpened();
  }

  /// Is an ask allowed right now? The whole schedule, one function, so
  /// every trigger below is identical apart from its analytics label.
  static Future<bool> _due(SharedPreferences prefs) async {
    var asks = prefs.getInt(_kAsks) ?? 0;
    // MIGRATION. Anyone already asked under the one-shot system counts
    // as having had ask #1, so upgrading doesn't restart him at zero and
    // fire the next two asks back to back.
    if (asks == 0 && (prefs.getBool(_kLegacyPrompted) ?? false)) {
      asks = 1;
      await prefs.setInt(_kAsks, asks);
      if (prefs.getInt(_kLastAsk) == null) {
        await prefs.setInt(_kLastAsk, DateTime.now().millisecondsSinceEpoch);
      }
    }
    if (asks >= _maxAsks) return false;

    final lastMs = prefs.getInt(_kLastAsk) ?? 0;
    final sent = prefs.getBool(_kSent) ?? false;

    // He went to the store. markSentToStore() has already burned the
    // counter down to _maxAsks - 1, so the cap above allows exactly ONE
    // more — this only holds it back until the long cooldown is up.
    if (sent) return _daysSince(lastMs) >= _afterSentDays;
    if (asks == 0) return true;
    final wait = _cooldownDays[asks.clamp(0, _cooldownDays.length - 1)];
    return _daysSince(lastMs) >= wait;
  }

  static int _daysSince(int ms) {
    if (ms == 0) return 1 << 20; // never asked — infinitely overdue
    return DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ms))
        .inDays;
  }

  /// Show the card, count the ask, stamp the clock.
  static Future<void> _show(BuildContext? context, String source) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await _due(prefs)) return;
    final ctx = (context != null && context.mounted)
        ? context
        : appRouter.routerDelegate.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    final asks = (prefs.getInt(_kAsks) ?? 0) + 1;
    await prefs.setInt(_kAsks, asks);
    await prefs.setInt(_kLastAsk, DateTime.now().millisecondsSinceEpoch);
    // ignore: discarded_futures
    AnalyticsService.reviewPromptShown(source);
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      // The copy sharpens with each ask — see ReviewPromptDialog.
      builder: (_) => ReviewPromptDialog(ask: asks),
    );
  }

  /// Home-screen trigger. Fires once any pillar has been used.
  static Future<void> maybePrompt(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final any = (prefs.getBool(_kScanDone)     ?? false)
             || (prefs.getBool(_kFreeFlowDone) ?? false)
             || (prefs.getBool(_kEyesDone)     ?? false);
    if (!any) return;
    if (!context.mounted) return;
    await Future.delayed(const Duration(milliseconds: 600));
    if (!context.mounted) return;
    await _show(context, 'milestone');
  }

  /// After a successful purchase. The paywall navigates BEFORE calling
  /// this, so its own context is dead by the time the delay ends — the
  /// root navigator context is resolved after the wait instead.
  static Future<void> maybePromptAfterPurchase(BuildContext _) async {
    await Future.delayed(const Duration(milliseconds: 1400));
    await _show(null, 'post_purchase');
  }

  /// After the scan report renders its score — the first emotional peak.
  static Future<void> maybePromptAfterReport(BuildContext context) async {
    if (!context.mounted) return;
    await Future.delayed(const Duration(milliseconds: 1800));
    await _show(context, 'post_report');
  }

  /// After a Game result — Lucien's score and verdict card.
  static Future<void> maybePromptAfterGame(BuildContext context) async {
    if (!context.mounted) return;
    await Future.delayed(const Duration(milliseconds: 1800));
    await _show(context, 'post_game');
  }

  /// After a high-scoring rep. THE best moment there is to ask: he has
  /// just been told, by the app, that he did well. Call it with the
  /// score so a bad rep never triggers it — asking a man to rate you
  /// ninety seconds after you graded him 41 is how you get a 41 back.
  static Future<void> maybePromptAfterScore(
      BuildContext context, int score) async {
    if (score < 70) return;
    if (!context.mounted) return;
    await Future.delayed(const Duration(milliseconds: 1200));
    await _show(context, 'post_score');
  }

  static Future<void> _setFlag(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }
}
