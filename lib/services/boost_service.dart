import 'package:shared_preferences/shared_preferences.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE BOOST — a trap at the exit
/// ══════════════════════════════════════════════════════════════════════
///
/// Duolingo's sharpest move is not the streak. It's that finishing a
/// lesson sometimes hands you a time-limited XP multiplier — which
/// arrives at the precise moment you were about to put the phone down.
///
/// That timing is the entire mechanic. A double-XP offer on the home
/// screen is a promotion. The same offer in the two seconds after a
/// session ends is a REASON NOT TO LEAVE, delivered at the one moment
/// the app was about to lose him. Session-end is the single biggest
/// churn point in any app, and this converts it into the start of the
/// next session instead.
///
/// ── WHY IT IS NOT RANDOM ─────────────────────────────────────────────
///
/// Variable-ratio rewards are the strongest schedule there is and the
/// app already has one — The Roll (boon_service.dart), a wheel that
/// only ever gives. Making this one random too would mean the man who
/// most needs a reason to stay is the one it skips. The boost fires
/// EVERY time, and its scarcity comes from the clock instead: fifteen
/// minutes, then it's gone.
///
/// ── WHY IT CAN'T BE FARMED ───────────────────────────────────────────
///
/// It doubles what an action already pays, and everything genuinely
/// farmable — practice, approaches — is under its own daily ceiling in
/// rewards.dart, which the multiplier is applied BEFORE. So a boosted
/// hour of practice still can't earn more than an unboosted day's cap.
/// The boost front-loads a man's earnings; it doesn't inflate them.
///
/// ── AND IT IS NEVER SOLD ─────────────────────────────────────────────
///
/// Nothing here is purchasable. The instant a multiplier has a price it
/// stops being a reason to keep playing and becomes a reason to feel
/// mugged, and this app already asks for money in the one place it
/// should — voice minutes.
class BoostService {
  static const _kUntil = 'boost.until.v1';

  /// How long the window stays open. Long enough to run another daily
  /// or a duel, short enough that it can't be slept on.
  static const minutes = 15;

  /// What it multiplies by. Two. A 1.5× is a rounding error he won't
  /// feel and a 3× makes the unboosted rest of the day feel broken.
  static const multiplier = 2;

  static Future<void> start() async {
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final until = p.getInt(_kUntil) ?? 0;
    // Never stack. A man who finishes three things in a row gets his
    // window RESET, not extended to forty-five minutes — the pressure
    // is the product and an hour of double XP has none.
    final from = until > now ? now : now;
    await p.setInt(
        _kUntil, from + const Duration(minutes: minutes).inMilliseconds);
  }

  static Future<bool> get active async {
    final p = await SharedPreferences.getInstance();
    return DateTime.now().millisecondsSinceEpoch < (p.getInt(_kUntil) ?? 0);
  }

  /// Seconds left, or 0. For the countdown on the payout card and the
  /// pill that follows him around while it's live.
  static Future<int> remaining() async {
    final p = await SharedPreferences.getInstance();
    final left =
        (p.getInt(_kUntil) ?? 0) - DateTime.now().millisecondsSinceEpoch;
    return left <= 0 ? 0 : left ~/ 1000;
  }

  static String clock(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Burn it — used when a boosted action is claimed and the design
  /// wants one-shot behaviour. Currently unused: the window is a window,
  /// and letting him get two things done inside it is the point.
  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUntil);
  }
}
