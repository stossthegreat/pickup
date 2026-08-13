import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'roster.dart';

/// THE ROLODEX — the thing the app never had: an object he owns.
///
/// Every mechanic in here was previously expressed as a number going up.
/// A number going up is information; it is not a possession, it has no
/// story attached to it, and nobody has ever opened an app to look at
/// one. So the reward currency stops being points and becomes the only
/// thing this app has that no other app can offer: a woman's decision
/// about him, kept.
///
/// Win a woman and her card lands here permanently — her face, her name,
/// the exact line that won her, the date, the number. It's a trophy case
/// where he wrote every trophy himself, which is why it's worth more to
/// him than a leaderboard place he can't remember earning.
///
/// Four forces, all free:
///   · COLLECTION — an incomplete set is an open loop. "7 of 10" nags in
///     a way "4,182 points" cannot.
///   · AUTHORSHIP — the winning line is his own words. People
///     overvalue what they built; this is the cheapest version of that
///     effect available to us.
///   · ENDOWED PROGRESS — the set never starts empty (see [seedIfEmpty]).
///     A card set opened at 1/10 gets finished far more often than the
///     identical set opened at 0/10.
///   · SOCIAL PROOF — a Rolodex screenshot is the best organic marketing
///     the app has, and it costs nothing to make shareable.

// ══════════════════════════════════════════════════════════════════════
//  RARITY
// ══════════════════════════════════════════════════════════════════════

/// How hard she is to win — and therefore what her card is worth.
///
/// CRITICAL: rarity is DIFFICULTY, never a paywall. A card you can buy is
/// not a trophy, and men can smell the difference instantly. Every woman
/// in the roster is reachable by anyone; the bar is just higher.
enum Rarity { common, rare, ice }

extension RarityX on Rarity {
  String get label => switch (this) {
        Rarity.common => 'COMMON',
        Rarity.rare => 'RARE',
        Rarity.ice => 'ICE',
      };

  /// Her interest has to reach this for her to give you the number.
  /// Scaled by rarity so an ICE card genuinely means something — the
  /// alternative is ten identical trophies, which is no collection at all.
  int get bar => switch (this) {
        Rarity.common => 70,
        Rarity.rare => 80,
        Rarity.ice => 90,
      };

  /// Below this she's gone. Between this and [bar] she's interested but
  /// not committed — the partial reward, which is the band most runs land
  /// in and the one that has to feel like progress rather than failure.
  int get floor => switch (this) {
        Rarity.common => 45,
        Rarity.rare => 55,
        Rarity.ice => 65,
      };

  Color get tint => switch (this) {
        Rarity.common => const Color(0xFF8E8E9A),
        Rarity.rare => const Color(0xFFC084FC),
        Rarity.ice => const Color(0xFF38BDF8),
      };

  /// What the locked card says about her, before he's earned the right
  /// to know anything else.
  String get teaser => switch (this) {
        Rarity.common => 'She\'ll meet you halfway.',
        Rarity.rare => 'She has options. She\'ll test you.',
        Rarity.ice => 'She is not impressed. She will end it.',
      };
}

Rarity rarityOfTier(int tier) => tier >= 5
    ? Rarity.ice
    : tier >= 3
        ? Rarity.rare
        : Rarity.common;

Rarity rarityOf(GirlBrief g) => rarityOfTier(g.tier);

// ══════════════════════════════════════════════════════════════════════
//  THE CARD
// ══════════════════════════════════════════════════════════════════════

/// One woman, won. Immutable except for warmth, which is derived.
class NumberCard {
  final String girlId;

  /// When she gave you the number.
  final int wonAtMs;

  /// THE LINE. The single message of his that moved her most, captured
  /// at the moment it landed. This is the whole reason the card is worth
  /// keeping — it's not a receipt, it's something he wrote.
  final String line;

  /// Her interest when she folded, 0..100.
  final int score;

  /// Last time he spoke to her. Warmth is computed from this rather than
  /// stored, so it can never drift out of sync with the clock.
  final int lastTouchedMs;

  const NumberCard({
    required this.girlId,
    required this.wonAtMs,
    required this.line,
    required this.score,
    required this.lastTouchedMs,
  });

  GirlBrief get girl => girlById(girlId);
  Rarity get rarity => rarityOf(girl);

  /// WARMTH, 0..100. Falls to nothing over [kColdAfterDays] of silence.
  ///
  /// This is the loss-aversion engine, and it is deliberately the version
  /// of loss aversion that maps onto the actual skill: real conversations
  /// die if you don't maintain them. The mechanic isn't decorating the
  /// lesson, it IS the lesson.
  ///
  /// NOTE ON WHAT THIS DOES *NOT* DO YET. Nothing is deleted at zero. A
  /// card going cold is a prompt, not a punishment, until push
  /// notifications exist to warn him first — taking a trophy off a man
  /// with no warning is how you lose him permanently rather than for a
  /// week. The decay ships now because a collection that can't cool is
  /// static; the removal ships with the notification that precedes it.
  int get warmth {
    final days =
        (DateTime.now().millisecondsSinceEpoch - lastTouchedMs) / 86400000.0;
    final v = 100 - (days / kColdAfterDays) * 100;
    return v.clamp(0, 100).round();
  }

  bool get cooling => warmth <= 45;

  Map<String, dynamic> toJson() => {
        'g': girlId,
        'w': wonAtMs,
        'l': line,
        's': score,
        't': lastTouchedMs,
      };

  static NumberCard? fromJson(Map<String, dynamic> j) {
    final id = j['g'];
    if (id is! String || id.isEmpty) return null;
    final won = (j['w'] as num?)?.toInt() ?? 0;
    return NumberCard(
      girlId: id,
      wonAtMs: won,
      line: (j['l'] as String?) ?? '',
      score: (j['s'] as num?)?.toInt() ?? 0,
      lastTouchedMs: (j['t'] as num?)?.toInt() ?? won,
    );
  }

  NumberCard touched() => NumberCard(
        girlId: girlId,
        wonAtMs: wonAtMs,
        line: line,
        score: score,
        lastTouchedMs: DateTime.now().millisecondsSinceEpoch,
      );
}

/// Ten days of total silence takes a card from hot to cold. Slow on
/// purpose: a man who misses a weekend should not come back to a wall of
/// dying relationships. Anxiety doesn't retain anyone — it uninstalls.
const int kColdAfterDays = 10;

// ══════════════════════════════════════════════════════════════════════
//  THE STORE
// ══════════════════════════════════════════════════════════════════════

class Rolodex {
  static const _k = 'rolodex.v1';
  static const _kSeeded = 'rolodex.seeded.v1';

  static Future<List<NumberCard>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_k);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      final out = <NumberCard>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          final c = NumberCard.fromJson(e);
          if (c != null) out.add(c);
        }
      }
      // Most recent first — the newest trophy is the one he wants to see.
      out.sort((a, b) => b.wonAtMs.compareTo(a.wonAtMs));
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _write(List<NumberCard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _k, jsonEncode([for (final c in cards) c.toJson()]));
  }

  static Future<NumberCard?> cardFor(String girlId) async {
    for (final c in await all()) {
      if (c.girlId == girlId) return c;
    }
    return null;
  }

  static Future<bool> has(String girlId) async =>
      await cardFor(girlId) != null;

  static Future<int> count() async => (await all()).length;

  /// She folded. Returns true only if this is a NEW card — the caller
  /// uses that to decide whether to run the full ceremony or the quiet
  /// version, because the second time she gives you her number it isn't
  /// a moment any more.
  static Future<bool> win({
    required String girlId,
    required String line,
    required int score,
  }) async {
    final cards = await all();
    if (cards.any((c) => c.girlId == girlId)) {
      await touch(girlId);
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    cards.add(NumberCard(
      girlId: girlId,
      wonAtMs: now,
      line: line.trim(),
      score: score.clamp(0, 100),
      lastTouchedMs: now,
    ));
    await _write(cards);
    return true;
  }

  /// He spoke to her — warmth back to full. One message is all it ever
  /// takes, because re-entry has to be the cheapest action in the app.
  static Future<void> touch(String girlId) async {
    final cards = await all();
    var changed = false;
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].girlId == girlId) {
        cards[i] = cards[i].touched();
        changed = true;
      }
    }
    if (changed) await _write(cards);
  }

  /// The coldest card he still owns, or null. This is what a "she's going
  /// cold" nudge should name — one woman, never a list.
  static Future<NumberCard?> coldest() async {
    final cards = await all();
    if (cards.isEmpty) return null;
    cards.sort((a, b) => a.warmth.compareTo(b.warmth));
    final c = cards.first;
    return c.cooling ? c : null;
  }

  /// ENDOWED PROGRESS. The set is never shown at zero.
  ///
  /// Sofia is already a little into him — she's the roster's day-one
  /// warm start — so handing her over costs nothing and changes the
  /// framing of the entire screen from "you have nothing" to "you have
  /// one, and nine are missing". The second framing is the one people
  /// finish. Runs once, ever.
  static Future<void> seedIfEmpty() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kSeeded) == true) return;
    await prefs.setBool(_kSeeded, true);
    if ((await all()).isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _write([
      NumberCard(
        girlId: 'into_you',
        wonAtMs: now,
        line: 'she texted first.',
        score: 72,
        lastTouchedMs: now,
      ),
    ]);
  }

  /// A stable, fake number per woman. Deterministic so it never changes
  /// under him — a trophy that reshuffles its own details isn't one.
  static String numberFor(String girlId) {
    var h = 0;
    for (final c in girlId.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    String d(int seed, int len) {
      final mod = math.pow(10, len).toInt();
      return (seed % mod).toString().padLeft(len, '0');
    }

    return '07${d(h, 2)} ${d(h ~/ 100, 3)} ${d(h ~/ 100000, 3)}';
  }
}
