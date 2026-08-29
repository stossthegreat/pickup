import 'package:flutter/material.dart';

import '../screens/roleplay/girl_chat_screen.dart';
import '../widgets/academy/rizz_off_reveal.dart';
import 'backend/chat_score_service.dart';
import 'local_store_service.dart';
import 'roster.dart';

/// THE GAME TEST — one scored rep, one number out of 100.
///
/// The score is the product. It is the thing the whole funnel promises,
/// the thing a man comes back to beat, and the thing he tells someone
/// else about. It existed in exactly one place — buried at the end of
/// onboarding, seen once, never again — so this pulls it out into a
/// service both the onboarding rep and the Train screen call.
///
/// ONE CODE PATH, DELIBERATELY. The onboarding version had a hundred
/// lines of hard-won detail in it: waiting on the parked grading future
/// so a slow network does not eat the score, the final rebinding that Dart
/// needs before the closure, the chat axes the reveal would otherwise
/// animate to five zeros. Copying that for a second entry point would
/// mean two of everything and one of them quietly wrong. There is one.
class GameTest {
  /// Runs a five-message rep against Sofia and shows the reveal.
  ///
  /// Returns his score out of 100, or null if he bailed before the end
  /// or the grade never came back. The score is persisted here so every
  /// surface can show it without re-running anything.
  static Future<int?> run(
    BuildContext context, {
    required String surface,
    required String kicker,
  }) async {
    final g = girlById('into_you');

    await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => GirlChatScreen(
          config: GirlChatConfig(
            characterId: g.id,
            vibeKey: g.vibeKey,
            name: g.name,
            archetype: g.archetype,
            portraitAsset: g.asset,
            accent: g.accent,
            opener: g.opener,
            // A REP, NOT A DEMO. taskMode gives the completion bar and
            // the real ending.
            taskMode: true,
            taskGoal: 5,
            scoreSurface: surface,
            // NO COACH IN A TEST. Ask Lucien is off here and only here.
            // A score with a ghostwriter behind it measures nothing, and
            // he would be told he scores what Lucien scores — which is
            // the one number in this app that has to be his. The coach
            // is waiting on the other side of it, in Train.
            coachAllowed: false,
            // This flow owns the ending: the /100 with the five axes,
            // not the girl-verdict ceremony. A man being sold on the
            // score has to actually SEE a score.
            verdictOnFinish: false,
            // THE REP MUST REACH ITS SCORE. Five messages against a
            // three-message allowance meant the paywall landed on
            // message four, mid-conversation — a man interrupted rather
            // than convinced. Exempt at the call site only; the gate
            // itself is untouched, and the caller decides who gets here.
            bypassTextCap: true,
          ),
        ),
      ),
    );
    if (!context.mounted) return null;

    // ── THE NUMBER ────────────────────────────────────────────────────
    //
    // The grade is fired without await from the chat's teardown, so the
    // result is often still in the air the instant we come back. Reading
    // it now and shrugging is how a man who ran the whole rep gets no
    // score at all — the single most valuable moment in the app, lost to
    // a race. So we wait on the parked future, capped, and only then
    // give up.
    var r = ChatScoreService.lastResult;
    if (r == null && ChatScoreService.grading != null) {
      try {
        await ChatScoreService.grading!.timeout(const Duration(seconds: 20));
      } catch (_) {/* slow or dead network — no score this time */}
      r = ChatScoreService.lastResult;
    }
    if (!context.mounted) return null;
    if (r == null) return null;

    ChatScoreService.lastResult = null;
    // A FINAL binding before the closure. `r` is reassignable (the wait
    // above rewrites it), and Dart refuses to null-promote an assigned
    // local inside a closure — so res.score in the pageBuilder would be
    // a compile error, not a runtime one. This exact trap failed an iOS
    // archive earlier.
    final res = r;
    await LocalStoreService.setChatScore(res.score);

    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: false,
      barrierLabel: 'game-test',
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => RizzOffReveal(
        score: res.score,
        // The grade bands are cut against the 0..9999 rubric, so the
        // 0..100 chat score is put back on that band for the LETTER
        // only. The number on screen stays out of 100.
        gradeScore: (res.score * 99.99).round(),
        rubric: res.rubric,
        rankToday: 0,
        worldAvg: res.average,
        girlName: g.name,
        girlAccent: g.accent,
        divisor: 1,
        decimals: 0,
        suffix: '/ 100',
        kicker: kicker,
        // RizzOffReveal defaults to the VOICE axes. This is a TEXT score
        // graded on a different five entirely — without these it looks
        // up confidence/flow/wit/recovery/close, finds none of them, and
        // animates five bars to zero underneath a real number.
        axes: kChatAxes,
        axisLabels: kChatAxisLabels,
      ),
      transitionBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    );
    return res.score;
  }
}
