import 'package:flutter/foundation.dart';

import 'backend/backend_service.dart';
import 'language_service.dart';

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
/// There is deliberately NO local fallback. See [mark].
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

    // ── NO FALLBACK. IF HE CAN'T THINK, HE DOESN'T SPEAK. ──────────
    //
    // There used to be a local keyword table here for when the network
    // or the function was missing, and it was worse than useless: it
    // produced the SAME canned card every time, which is precisely the
    // failure the model call exists to fix. A coach who repeats himself
    // is not a degraded coach, he is an irritant — and shipping one as
    // a "graceful degradation" just guarantees most men only ever meet
    // the bad version.
    //
    // Silence is the correct degraded state. Lucien speaks when Lucien
    // has read the conversation, and not otherwise.
    return null;
  }
}
