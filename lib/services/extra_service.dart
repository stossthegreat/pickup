import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// EXTRA — the voice-minute bank.
///
/// Minutes bought as a one-off consumable, on top of the weekly Pro
/// allowance. They do NOT expire and they do NOT reset with the week:
/// he paid for them, they're his until he speaks them.
///
/// ──────────────────────────────────────────────────────────────────
/// THE THREE WAYS A CONSUMABLE GOES WRONG, AND WHAT STOPS EACH
/// ──────────────────────────────────────────────────────────────────
///
/// 1. HE PAYS AND GETS NOTHING.
///    The single worst outcome — it's a chargeback, a 1-star, and a
///    support thread. The existing `mirrorly_pro_rescue` path in
///    PurchaseService already had this bug: it correctly identified a
///    consumable and correctly declined to flip the subscription flag,
///    and then granted nothing at all, because nothing downstream was
///    ever written. The grant now happens INSIDE PurchaseService the
///    instant the transaction returns, so no call site can forget it.
///
/// 2. HE PAYS ONCE AND GETS CREDITED TWICE.
///    Retries, a resumed app, a re-read of CustomerInfo — any of these
///    can replay a completed purchase. Every grant is therefore keyed
///    by the store transaction identifier and recorded; a repeat of the
///    same id is a no-op that returns false. Free minutes cost real
///    money in OpenAI Realtime spend, so this is not a cosmetic guard.
///
/// 3. THE MINUTES LEAK BACK EVERY WEEK.
///    The tempting implementation is "allowance = weekly + banked".
///    That's wrong: `voiceMsThisWeek` resets on the rolling window, so
///    the bank would silently re-grant itself every seven days forever.
///    The bank is a counter that ONLY DECREMENTS — see
///    LocalStoreService.addVoiceMs, which spends the weekly allowance
///    first and only then draws the bank down.
///
/// CONSUMABLES CANNOT BE RESTORED. Play Billing 8 removed the query for
/// consumed purchases, so there is no way to re-grant these from the
/// store later and the app must never offer to. The grant is local,
/// immediate and permanent — which is exactly why (2) matters.
class ExtraService {
  static const _kBankMs = 'extra.bank_ms.v1';
  static const _kSeenTxns = 'extra.txns.v1';
  static const _kLifetime = 'extra.lifetime_minutes.v1';
  static const _kNudged = 'extra.nudged_ymd.v1';

  /// How many transaction ids to remember. Enough that a replay can
  /// never slip through in practice, bounded so the pref can't grow
  /// without limit on a heavy buyer.
  static const _txnMemory = 60;

  /// Minutes he's got left in the bank.
  static Future<int> bankedMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kBankMs) ?? 0;
  }

  static Future<int> bankedMinutes() async => (await bankedMs()) ~/ 60000;

  static Future<bool> hasBank() async => (await bankedMs()) > 0;

  /// Credit a purchase. Returns false when this transaction has already
  /// been credited — the caller can treat that as success (he owns the
  /// minutes) without adding them a second time.
  ///
  /// [txnId] must be the STORE transaction identifier. A null or empty
  /// id means the store didn't give us one; we still grant, because
  /// failing to credit a real payment is far worse than a theoretical
  /// double-credit, but we log it into the seen-list under a
  /// time-derived key so an immediate retry is still caught.
  static Future<bool> grant({
    required int minutes,
    required String? txnId,
  }) async {
    if (minutes <= 0) return false;
    final prefs = await SharedPreferences.getInstance();

    final key = (txnId == null || txnId.isEmpty)
        ? 'anon:${DateTime.now().millisecondsSinceEpoch ~/ 1000}'
        : txnId;

    final seen = _readTxns(prefs);
    if (seen.contains(key)) return false;

    seen.add(key);
    while (seen.length > _txnMemory) {
      seen.removeAt(0);
    }
    await prefs.setString(_kSeenTxns, jsonEncode(seen));

    final add = minutes * 60000;
    await prefs.setInt(_kBankMs, (prefs.getInt(_kBankMs) ?? 0) + add);
    await prefs.setInt(
        _kLifetime, (prefs.getInt(_kLifetime) ?? 0) + minutes);
    return true;
  }

  /// Draw [ms] out of the bank. Returns how much was actually taken,
  /// which is less than asked for when the bank runs dry mid-session.
  static Future<int> spend(int ms) async {
    if (ms <= 0) return 0;
    final prefs = await SharedPreferences.getInstance();
    final have = prefs.getInt(_kBankMs) ?? 0;
    if (have <= 0) return 0;
    final take = ms > have ? have : ms;
    await prefs.setInt(_kBankMs, have - take);
    return take;
  }

  /// Total minutes ever bought — for the receipt line on the sheet.
  /// Men trust a number that remembers.
  static Future<int> lifetimeMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kLifetime) ?? 0;
  }

  /// The soft nudge is capped at once a day. An offer he sees every
  /// time he taps hold isn't an offer, it's a nag — and a nag poisons
  /// the hard sell at the wall, which is the one that has to land.
  static Future<bool> nudgedToday() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_kNudged) ?? 0) == _today();
  }

  static Future<void> markNudged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNudged, _today());
  }

  static int _today() {
    final n = DateTime.now();
    return n.year * 10000 + n.month * 100 + n.day;
  }

  static List<String> _readTxns(SharedPreferences prefs) {
    final raw = prefs.getString(_kSeenTxns);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return <String>[];
      return [for (final e in list) if (e is String) e];
    } catch (_) {
      return <String>[];
    }
  }
}
