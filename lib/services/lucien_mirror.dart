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

  /// The move he should have played.
  final Tactic tactic;

  /// One sentence naming what his line did — the diagnosis. Never a
  /// judgement of him, always a description of the line.
  final String read;

  const LucienMirror({
    required this.hisLine,
    required this.tactic,
    required this.read,
  });

  /// Turns since the last mark. Kept on the instance rather than a
  /// static so a second chat screen can't inherit a stale cooldown.
  static const cooldownTurns = 2;

  /// Mark a line, or return null to stay quiet.
  ///
  /// [demonstrated] is what Tactics.detect() found — a non-empty list
  /// means he already played a move and the reveal will handle it, so
  /// the mirror steps back rather than talking over the celebration.
  static LucienMirror? read_({
    required String line,
    required List<String> demonstrated,
    required List<String> herEarlier,
    required int turnIndex,
    required int turnsSinceLastMark,
    required double delta,
  }) {
    final t = line.trim();
    if (t.length < 4) return null;
    if (demonstrated.isNotEmpty) return null;
    if (turnIndex < 1) return null; // the opener is his, untouched
    if (turnsSinceLastMark < cooldownTurns) return null;

    final low = t.toLowerCase();
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final q = t.contains('?');

    // ── THE READS, most specific first ───────────────────────────────
    //
    // Ordered by how badly the mistake costs him, not by how easy it is
    // to detect. The first match wins, so a line that is both an
    // interview question AND flat gets marked as the interview — that's
    // the one killing the conversation.

    // Interviewing. The single most common way a man is boring.
    if (q && words <= 14 && _looksLikeInterview(low)) {
      return LucienMirror(
        hisLine: t,
        tactic: Tactics.byId('assumption')!,
        read: 'That was a question. Questions make her do the work and '
            'give her nothing to push against.',
      );
    }

    // Closed answer — nothing in it for her to grab.
    if (!q && words <= 7) {
      return LucienMirror(
        hisLine: t,
        tactic: Tactics.byId('detail')!,
        read: 'That closes the exchange. She now has to restart the '
            'conversation on her own, and most women just won\'t.',
      );
    }

    // Hedged. He said it and then apologised for saying it.
    if (_hedged(low)) {
      return LucienMirror(
        hisLine: t,
        tactic: Tactics.byId('anchor')!,
        read: 'You softened it before she could react to it. The hedge '
            'is the part she hears.',
      );
    }

    // Agreement with nothing behind it.
    if (_agreeing(low) && words <= 12) {
      return LucienMirror(
        hisLine: t,
        tactic: Tactics.byId('disagree')!,
        read: 'You agreed. Agreement is polite and it is completely '
            'frictionless — there is nothing there for her to feel.',
      );
    }

    // Compliment used as currency.
    if (_complimenting(low)) {
      return LucienMirror(
        hisLine: t,
        tactic: Tactics.byId('tease')!,
        read: 'A compliment early reads as buying her approval. She has '
            'had a hundred of those this week.',
      );
    }

    // It went backwards and he didn't react to it.
    if (delta < -1.5) {
      return LucienMirror(
        hisLine: t,
        tactic: Tactics.byId('reset')!,
        read: 'That one cooled her. The recovery is not explaining it — '
            'it is changing the temperature.',
      );
    }

    // A long line with no story in it — facts where a moment belonged.
    if (words >= 18 && !low.contains('when i') && !low.contains('once')) {
      return LucienMirror(
        hisLine: t,
        tactic: Tactics.byId('story')!,
        read: 'Long, and all information. She will not remember any of '
            'it — length is not the same as presence.',
      );
    }

    return null;
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
