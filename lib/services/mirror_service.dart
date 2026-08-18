import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import 'backend/tiers.dart';

/// THE MIRROR — the one mechanic that works on a timescale of years.
///
/// Points, streaks and collections move weeks. What moves years is
/// IDENTITY: "I'm the kind of man who does this." Every retention
/// mechanic in this app so far pays him for behaviour. This one tells
/// him who he is, using nothing but behaviour he already produced.
///
/// It is COMPUTED, never chosen, and that distinction is the entire
/// feature. A title you pick is decoration — you already knew it. A
/// title the app worked out about you is a mirror, and a mirror that
/// says something specific and flattering is the most re-opened screen
/// you can ship. It also does honest work: it tells him what he's
/// actually good at, which is the thing he came here to find out and the
/// thing no score out of ten has ever told him.
///
/// Every axis is measurable at the moment a line lands, so nothing here
/// needs the conversation to be over, a server, or a migration:
///
///   ICE BREAKER   his opening lines outperform his average
///   THE CLOSER    he's strongest once she's already warm — he can finish
///   UNBOTHERED    he's strongest against the women who give nothing
///   SECOND WIND   his best line is the one right after a bad one
///   SLOW BURN     his conversations run longest
///
/// Recomputed on every read, so it can change — which is what makes it
/// worth checking rather than a badge he was handed once.
enum Trait { iceBreaker, closer, unbothered, secondWind, slowBurn }

extension TraitX on Trait {
  String get title => switch (this) {
        Trait.iceBreaker => 'ICE BREAKER',
        Trait.closer => 'THE CLOSER',
        Trait.unbothered => 'UNBOTHERED',
        Trait.secondWind => 'SECOND WIND',
        Trait.slowBurn => 'SLOW BURN',
      };

  /// Second person, present tense, and specific. "You're good at
  /// openers" is a compliment; "you get further in the first ten seconds
  /// than most men get all night" is a description of him.
  String get blurb => switch (this) {
        Trait.iceBreaker =>
          'You get further in the first line than most men manage all '
              'night. Walking up is the part nobody can teach — and it\'s '
              'the part you already have.',
        Trait.closer =>
          'Most men fold at the end. You don\'t. Once she\'s interested '
              'you keep your nerve, and that\'s the half of this that '
              'actually decides anything.',
        Trait.unbothered =>
          'The women who give nothing away don\'t rattle you. You score '
              'highest against exactly the ones most men go quiet on.',
        Trait.secondWind =>
          'Your best line is the one straight after a bad one. You don\'t '
              'spiral — and not spiralling is rarer than being smooth.',
        Trait.slowBurn =>
          'You stay in it. Your conversations run longer than anyone\'s, '
              'and depth is the thing a good opener can\'t fake.',
      };

  IconData get icon => switch (this) {
        Trait.iceBreaker => Icons.bolt_rounded,
        Trait.closer => Icons.emoji_events_rounded,
        Trait.unbothered => Icons.shield_rounded,
        Trait.secondWind => Icons.restart_alt_rounded,
        Trait.slowBurn => Icons.local_fire_department_rounded,
      };

  Color get tint => switch (this) {
        Trait.iceBreaker => const Color(0xFF38BDF8),
        Trait.closer => const Color(0xFFFFD34D),
        Trait.unbothered => const Color(0xFFC084FC),
        Trait.secondWind => kNeon,
        Trait.slowBurn => AppColors.red,
      };

  String get _key => switch (this) {
        Trait.iceBreaker => 'open',
        Trait.closer => 'close',
        Trait.unbothered => 'ice',
        Trait.secondWind => 'wind',
        Trait.slowBurn => 'burn',
      };
}

/// What the mirror currently says.
class MirrorRead {
  final Trait? trait;

  /// Total scored lines he's ever sent. The gate, and the honest answer
  /// to "why doesn't it say anything yet".
  final int lines;

  /// How far ahead of his own average that axis runs.
  final double lift;

  const MirrorRead({
    required this.trait,
    required this.lines,
    required this.lift,
  });

  bool get ready => trait != null;

  /// Lines still needed before it will commit to a reading.
  int get toGo => (MirrorService.minLines - lines).clamp(0, 9999);
}

class MirrorService {
  /// Below this it stays quiet. A mirror that guesses early is a
  /// horoscope, and once he catches it guessing he never believes it
  /// again — including the reading that would have been true.
  static const minLines = 25;

  /// An axis needs its own evidence too. Four opening lines is not a
  /// pattern in openers.
  static const minPerAxis = 4;

  static const _kLines = 'mirror.lines.v1';
  static const _kSum = 'mirror.sum.v1';
  static const _kConvs = 'mirror.convs.v1';
  static const _kConvTurns = 'mirror.conv_turns.v1';
  static const _kSeenTitle = 'mirror.seen_title.v1';

  static String _n(String axis) => 'mirror.$axis.n.v1';
  static String _s(String axis) => 'mirror.$axis.s.v1';

  // ── Recording ───────────────────────────────────────────────────────

  /// One scored line. Called from the chat the moment the backend hands
  /// back a delta, so every axis is decided by facts available right
  /// then — no axis needs to know how the conversation ends.
  ///
  /// [turnIndex] is 1-based. [heat] is her interest BEFORE this line, so
  /// "closer" means he was strong while she was already warm rather than
  /// being credited for the line that made her warm.
  static Future<void> record({
    required int turnIndex,
    required double delta,
    required double heat,
    required int girlTier,
    required bool afterStumble,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_kLines, (prefs.getInt(_kLines) ?? 0) + 1);
    await prefs.setDouble(_kSum, (prefs.getDouble(_kSum) ?? 0) + delta);

    Future<void> bump(Trait t) async {
      final k = t._key;
      await prefs.setInt(_n(k), (prefs.getInt(_n(k)) ?? 0) + 1);
      await prefs.setDouble(_s(k), (prefs.getDouble(_s(k)) ?? 0) + delta);
    }

    if (turnIndex <= 2) await bump(Trait.iceBreaker);
    if (heat >= 70) await bump(Trait.closer);
    if (girlTier >= 4) await bump(Trait.unbothered);
    if (afterStumble) await bump(Trait.secondWind);
  }

  /// A conversation ended, with [turns] lines from him in it. Length is
  /// the one axis that can only be known at the end.
  static Future<void> endConversation(int turns) async {
    if (turns <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kConvs, (prefs.getInt(_kConvs) ?? 0) + 1);
    await prefs.setInt(
        _kConvTurns, (prefs.getInt(_kConvTurns) ?? 0) + turns);
  }

  // ── Reading ─────────────────────────────────────────────────────────

  static Future<MirrorRead> read() async {
    final prefs = await SharedPreferences.getInstance();
    final lines = prefs.getInt(_kLines) ?? 0;
    if (lines < minLines) {
      return MirrorRead(trait: null, lines: lines, lift: 0);
    }
    final base = (prefs.getDouble(_kSum) ?? 0) / lines;

    Trait? best;
    var bestLift = 0.0;

    for (final t in Trait.values) {
      double lift;
      if (t == Trait.slowBurn) {
        final convs = prefs.getInt(_kConvs) ?? 0;
        if (convs < 3) continue;
        final avg = (prefs.getInt(_kConvTurns) ?? 0) / convs;
        // Scaled onto the same rough band as a delta lift so one axis
        // can't win purely because its units are bigger. Six lines is
        // an ordinary conversation; every line past that is the signal.
        lift = (avg - 6) * 0.45;
      } else {
        final n = prefs.getInt(_n(t._key)) ?? 0;
        if (n < minPerAxis) continue;
        lift = ((prefs.getDouble(_s(t._key)) ?? 0) / n) - base;
      }
      if (lift > bestLift) {
        bestLift = lift;
        best = t;
      }
    }

    // Nothing stands out — he's even across the board, which is a real
    // answer and better than inventing a lean. THE CLOSER is the
    // fallback because finishing is the axis that decides outcomes, and
    // an even man who has sent 25 lines has earned a name.
    best ??= Trait.closer;
    return MirrorRead(trait: best, lines: lines, lift: bestLift);
  }

  /// The reading, if it has CHANGED since he last saw it. Null the rest
  /// of the time.
  ///
  /// This is what makes the mirror worth reopening: it isn't a badge he
  /// was handed once, it's a thing the app keeps working out about him,
  /// and it can move. Fires once per change, on the same
  /// persisted-stamp pattern as the armband.
  static Future<Trait?> takeChange() async {
    final r = await read();
    final t = r.trait;
    if (t == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getString(_kSeenTitle);
    if (seen == t.name) return null;
    await prefs.setString(_kSeenTitle, t.name);
    // The FIRST reading is a moment too — arguably the biggest one,
    // because it's the first time the app has told him something about
    // himself rather than about his score.
    return t;
  }
}
