import 'package:flutter/foundation.dart';

import 'backend/backend_service.dart';
import 'language_service.dart';
import 'tactics.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE MIRROR — Lucien marks the line AFTER it's sent
/// ══════════════════════════════════════════════════════════════════════
///
/// THE OLD COACH WAS A GHOSTWRITER. Tap a button, get a line, send it.
/// It made a man better at that one conversation and taught him nothing,
/// and because the line was sendable it was cheating — which is exactly
/// why help had to be stripped from every graded surface. The crutch was
/// the reason the teaching could not reach anybody.
///
/// This is the opposite machine. He commits his line first. THEN Lucien
/// tells him what a man who is actually good at this would have said,
/// and names the move. He cannot use it to win tonight — the line is
/// already gone. He can only use it to be better tomorrow.
///
/// That one property is what lets the mirror live on EVERY surface,
/// graded or not. Nothing here can raise the score of the conversation
/// it is commenting on.
///
/// ── LUCIEN IS A MODEL CALL, NOT A LOOKUP TABLE ──────────────────────
///
/// The first version of this matched keywords and returned canned
/// strings, so he said the identical sentence every time a man asked a
/// question. A coach who repeats himself is not a coach, he is a
/// tooltip — and seduction is entirely contextual, so the read has to
/// come from something that actually read the exchange. [mark] calls
/// the lucien-mirror Edge Function, which sees the transcript, her last
/// line and her current interest, and answers about THAT.
///
/// The rules below survive only as the offline fallback — when the
/// network is gone or the function isn't deployed, a rotating local
/// read is better than silence. They are explicitly the cheap version.
///
/// ── IT ONLY SPEAKS WHEN IT HAS SOMETHING ────────────────────────────
///
/// A coach who comments on every line is noise a man turns off in four
/// messages. This returns null far more often than not:
///
///   · it stays silent when he did something right (the tactic reveal
///     already celebrates that — two systems on one line is a mess)
///   · it stays silent on openers and on anything under four words
///   · it stays silent if it spoke within the last two turns
///
/// ── AND IT NEVER SAYS "THAT WAS BAD" ────────────────────────────────
///
/// Every verdict is: here is the move, here is why it works on a human,
/// here are two lines you could have said. The diagnosis exists to
/// motivate the weapon, never to score a point off him. A man being
/// marked on a conversation he is losing will quit an app in one
/// session if the marking has contempt in it.
class LucienMirror {
  /// What he actually said.
  final String hisLine;

  /// One sentence naming what his line did. Never a judgement of him,
  /// always a description of the line.
  final String read;

  /// The name of the move, in caps.
  final String move;

  /// Why it works on an actual human being.
  final String why;

  /// Two lines he could have sent instead. From the model these are
  /// written against what SHE actually said; from the fallback they're
  /// the tactic's stock examples.
  final List<String> lines;

  const LucienMirror({
    required this.hisLine,
    required this.read,
    required this.move,
    required this.why,
    required this.lines,
  });

  /// Turns that must pass before he speaks again.
  static const cooldownTurns = 2;

  /// ASK LUCIEN TO MARK THE LINE.
  ///
  /// Returns null for silence, which is the common case. The gates are
  /// checked locally BEFORE the network call so a quiet turn costs
  /// nothing — at scale this function is the only per-message API spend
  /// in the app and it must not fire on every line.
  static Future<LucienMirror?> mark({
    required String line,
    required List<String> demonstrated,
    required String transcript,
    required String herLast,
    required String girl,
    required double heat,
    required int turnIndex,
    required int turnsSinceLastMark,
    required double delta,
  }) async {
    final t = line.trim();
    if (t.length < 4) return null;
    if (demonstrated.isNotEmpty) return null; // the reveal owns that moment
    if (turnIndex < 1) return null;           // his opener is his own
    if (turnsSinceLastMark < cooldownTurns) return null;

    if (BackendService.enabled) {
      try {
        final res = await BackendService.client.functions.invoke(
          'lucien-mirror',
          body: {
            'transcript': transcript,
            'hisLine': t,
            'herLast': herLast,
            'girl': girl,
            'heat': heat,
            'language': LanguageService.cachedCode,
          },
        ).timeout(const Duration(seconds: 12));
        final d = res.data;
        if (d is Map && d['skip'] != true && d['read'] != null) {
          final raw = (d['lines'] as List?) ?? const [];
          final lines = [for (final l in raw) l.toString()]
              .where((l) => l.trim().length > 3)
              .toList();
          if (lines.isNotEmpty) {
            return LucienMirror(
              hisLine: t,
              read: d['read'].toString(),
              move: d['move']?.toString() ?? 'THE MOVE',
              why: d['why']?.toString() ?? '',
              lines: lines,
            );
          }
        }
        // A deliberate skip from Lucien is silence, not a reason to
        // fall back — he looked and decided the line was fine.
        if (d is Map && d['skip'] == true) return null;
      } catch (e) {
        debugPrint('LucienMirror.mark: $e'); // fall through to local
      }
    }

    return _offline(t, delta);
  }

  /// THE CHEAP VERSION. Network down, or the function not deployed yet.
  /// Rotates its wording off the line itself so even the fallback isn't
  /// word-for-word identical twice running.
  static LucienMirror? _offline(String t, double delta) {
    final low = t.toLowerCase();
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final q = t.contains('?');
    final spin = t.length; // stable per line, varied across lines

    ({Tactic tactic, List<String> reads})? pick;

    if (q && words <= 14 && _looksLikeInterview(low)) {
      pick = (tactic: Tactics.byId('assumption')!, reads: [
        'That was a question. Questions make her do the work and give '
            'her nothing to push against.',
        'You interviewed her. She can answer that in four words and '
            'feel nothing doing it.',
        'A question hands the conversation back to her. Hand her an '
            'opinion instead.',
      ]);
    } else if (!q && words <= 7) {
      pick = (tactic: Tactics.byId('detail')!, reads: [
        'That closes the exchange. She now has to restart it on her '
            'own, and most women just won\'t.',
        'Nothing in that for her to grab. A closed answer is a door '
            'shutting politely.',
        'Short and finished. Leave her something odd to pick up.',
      ]);
    } else if (_hedged(low)) {
      pick = (tactic: Tactics.byId('anchor')!, reads: [
        'You softened it before she could react to it. The hedge is '
            'the part she hears.',
        'You apologised for your own line mid-sentence. Say it and '
            'leave it standing.',
        'The qualifier undid the sentence in front of it.',
      ]);
    } else if (_agreeing(low) && words <= 12) {
      pick = (tactic: Tactics.byId('disagree')!, reads: [
        'You agreed. Agreement is polite and completely frictionless — '
            'nothing there for her to feel.',
        'Pure agreement is a dead end. Take the other side for sport.',
        'You matched her instead of meeting her.',
      ]);
    } else if (_complimenting(low)) {
      pick = (tactic: Tactics.byId('tease')!, reads: [
        'A compliment early reads as buying her approval. She\'s had a '
            'hundred of those this week.',
        'You paid for attention you could have earned in one line.',
        'Praise is cheap from a stranger. Make her want it first.',
      ]);
    } else if (delta < -1.5) {
      pick = (tactic: Tactics.byId('reset')!, reads: [
        'That one cooled her. The recovery is not explaining it — it '
            'is changing the temperature.',
        'She went quiet on that. Drop it cleanly, open something else.',
        'You lost a degree there. Don\'t chase it, change it.',
      ]);
    } else if (words >= 18 && !low.contains('when i') && !low.contains('once')) {
      pick = (tactic: Tactics.byId('story')!, reads: [
        'Long, and all information. Length is not the same as presence.',
        'That was a paragraph of facts. She\'ll remember none of it.',
        'You explained where you could have shown her a moment.',
      ]);
    }

    if (pick == null) return null;
    final p = pick;
    return LucienMirror(
      hisLine: t,
      read: p.reads[spin % p.reads.length],
      move: p.tactic.name.toUpperCase(),
      why: p.tactic.why,
      lines: [p.tactic.example, p.tactic.example2],
    );
  }

  static bool _looksLikeInterview(String s) {
    const openers = [
      'what do you', 'what are you', 'where are you', 'where do you',
      'how was', 'how is', 'how are', 'do you like', 'have you ever',
      'what kind of', 'so what', 'and you', 'what about you', 'how old',
      'where you from', 'what you do', 'do you work',
    ];
    for (final o in openers) {
      if (s.contains(o)) return true;
    }
    return false;
  }

  static bool _hedged(String s) {
    const hedges = [
      'sorry if', 'i guess', 'maybe im', 'maybe i\'m', 'no worries if',
      'if that\'s ok', 'if thats ok', 'just wondering', 'i mean idk',
      'probably not but', 'don\'t have to', 'dont have to', 'no pressure',
      'lol sorry', 'haha sorry',
    ];
    for (final h in hedges) {
      if (s.contains(h)) return true;
    }
    return false;
  }

  static bool _agreeing(String s) {
    const yes = [
      'yeah same', 'same here', 'me too', 'totally', 'i agree',
      'exactly', 'so true', 'for sure', 'definitely', 'yeah true',
    ];
    for (final y in yes) {
      if (s.startsWith(y) || s.contains(y)) return true;
    }
    return false;
  }

  static bool _complimenting(String s) {
    const c = [
      'you\'re gorgeous', 'youre gorgeous', 'you look amazing',
      'you\'re beautiful', 'youre beautiful', 'so pretty', 'you\'re stunning',
      'youre stunning', 'you\'re perfect', 'youre perfect', 'so hot',
    ];
    for (final x in c) {
      if (s.contains(x)) return true;
    }
    return false;
  }
}
