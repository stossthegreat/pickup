import 'tactics.dart';

/// ══════════════════════════════════════════════════════════════════════
///  ONE COACHING LINE — never five
/// ══════════════════════════════════════════════════════════════════════
///
/// THE GAP. The app graded a man on five axes after every conversation
/// and explained none of them. He saw WIT 4.2 and had no idea what that
/// meant or what to do differently tomorrow. A gym with a scoreboard and
/// no coach.
///
/// THE RULE. ONE unsolicited insight. Not five — five is a report, and a
/// report after a game is homework. The other four axes are there if he
/// taps, and most men never will, which is correct.
///
/// THE SHAPE. Diagnosis → principle → something to say. All three or it
/// isn't coaching:
///
///   · Diagnosis alone is criticism.
///   · Principle alone is a fortune cookie.
///   · An example alone is a script, and a man reciting a script is
///     doing the one thing that definitely doesn't work.
///
/// ── HOW THE AXIS IS CHOSEN ───────────────────────────────────────────
///
/// The lowest one, with one exception: an axis he's already strong on is
/// never picked even if it's technically his lowest that session, because
/// coaching a man on his best quality reads as the app not paying
/// attention. Below 45 is a real weakness; above it, the session gets
/// praise for what worked instead.
///
/// ── AND IT NAMES A TACTIC ────────────────────────────────────────────
///
/// Every coaching line points at a mechanic in tactics.dart, so the
/// advice and the collection are one system. Told what to fix, given the
/// name of the thing that fixes it, and the name is a card he can go and
/// unlock.
abstract final class Coaching {
  /// THE LINE THAT COST HIM, parked for whichever reveal comes next.
  ///
  /// The chat screen scores every message as it goes past and is the only
  /// thing in the app that knows which one hurt. The reveal is a
  /// different screen entirely, so it's stashed here rather than threaded
  /// through four constructors. Consumed on read — a coaching line
  /// replayed on the next session would be worse than none.
  static String? lastWorstLine;

  static String? takeWorstLine() {
    final l = lastWorstLine;
    lastWorstLine = null;
    return (l == null || l.trim().length < 6) ? null : l.trim();
  }

  /// Below this on an axis is worth coaching. Above it, he did fine and
  /// being told to improve it is noise.
  static const weakBar = 45;

  /// At or above this, the axis gets called out as a strength instead.
  static const strongBar = 78;

  /// The single most useful thing to say about this session.
  ///
  /// [rubric] is axis-name → 0..100, exactly as the grader returns it.
  /// Returns null when nothing is worth saying — a clean sheet gets
  /// silence rather than manufactured criticism.
  static Insight? read(Map<String, int> rubric) {
    Skill? worst;
    var worstScore = 1000;
    Skill? best;
    var bestScore = -1;

    for (final a in Skill.values) {
      final v = rubric[a.name];
      if (v == null) continue;
      if (v < worstScore) {
        worstScore = v;
        worst = a;
      }
      if (v > bestScore) {
        bestScore = v;
        best = a;
      }
    }
    if (worst == null) return null;

    // Something genuinely weak — coach it.
    if (worstScore < weakBar) {
      return Insight(
        axis: worst,
        score: worstScore,
        praise: false,
        diagnosis: _diagnosis(worst, worstScore),
        tactic: _cure(worst),
      );
    }

    // Nothing weak. Name what worked instead — a man who did well and is
    // told to improve something learns the app isn't reading him.
    if (best != null && bestScore >= strongBar) {
      return Insight(
        axis: best,
        score: bestScore,
        praise: true,
        diagnosis: _praise(best),
        tactic: null,
      );
    }
    return null;
  }

  /// The diagnosis, banded. A 12 and a 40 on the same axis are different
  /// problems and deserve different sentences.
  static String _diagnosis(Skill a, int score) {
    final bad = score < 25;
    return switch (a) {
      Skill.confidence => bad
          ? 'You hedged nearly everything. Softening a line before you\'ve '
              'even sent it tells her you expect it to land badly.'
          : 'You said it, then took the edge off it. The apology at the end '
              'of a sentence is the bit she hears.',
      Skill.flow => bad
          ? 'You went into interview mode. Question, answer, question — she '
              'ended up doing all the work and there was nowhere for it to go.'
          : 'You answered her, but you gave her nothing to grab onto. Every '
              'reply that closes cleanly makes her restart the conversation.',
      Skill.wit => bad
          ? 'It stayed completely flat. Not unfriendly — just no reason for '
              'her to still be talking to you in ten minutes.'
          : 'Your lines landed but you never risked one. Wit is a bet, not '
              'a joke — the safe version isn\'t funny, it\'s polite.',
      Skill.recovery => bad
          ? 'When it wobbled you went stiff and formal. That\'s the moment '
              'she decides whether you\'re fragile.'
          : 'You recovered by explaining yourself. Explaining a line is '
              'louder than the line was.',
      Skill.close => bad
          ? 'You never asked for anything. A conversation that goes well and '
              'ends with nothing is the most common way this is wasted.'
          : 'You gestured at it — "we should sometime". That puts the work '
              'on her and gives her nothing to say yes to.',
    };
  }

  static String _praise(Skill a) => switch (a) {
        Skill.confidence =>
          'You said what you meant and left it there. That\'s the whole thing.',
        Skill.flow =>
          'She never had to restart it. You kept handing her somewhere to go.',
        Skill.wit => 'You were genuinely fun to talk to. That\'s the hard one.',
        Skill.recovery =>
          'It wobbled and you didn\'t. That\'s worth more than a clean run.',
        Skill.close => 'You actually asked. Most men don\'t.',
      };

  /// The tactic that fixes this axis — the bridge into the collection.
  static Tactic _cure(Skill a) => switch (a) {
        Skill.confidence => Tactics.byId('anchor')!,
        Skill.flow => Tactics.byId('assumption')!,
        Skill.wit => Tactics.byId('tease')!,
        Skill.recovery => Tactics.byId('own')!,
        Skill.close => Tactics.byId('close')!,
      };
}

/// The one thing worth saying about a session.
class Insight {
  final Skill axis;
  final int score;

  /// True when this is naming a strength rather than a weakness.
  final bool praise;

  final String diagnosis;

  /// The mechanic that fixes it. Null on praise — a man doing well
  /// doesn't need homework attached.
  final Tactic? tactic;

  const Insight({
    required this.axis,
    required this.score,
    required this.praise,
    required this.diagnosis,
    required this.tactic,
  });
}
