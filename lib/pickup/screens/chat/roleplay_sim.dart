import '../../models/character.dart';
import '../../models/metrics.dart';

/// Local stand-in for backend2 `/v1/villain/scene`. Heuristic, deterministic
/// enough to feel alive in a demo. Replace `evaluate`/`herReply`/`hint` with
/// real API calls; the chat screen never changes.
class Coach {
  final String move; // technique name Bro announces
  final String line; // "what I'd have said"
  const Coach(this.move, this.line);
}

class Eval {
  final double delta; // change to the focus meter (-8..+14)
  final bool strong;
  final Coach? coach; // non-null when Bro decides to cut in
  final String? coachNote; // Bro's short read on your move
  const Eval(this.delta, this.strong, {this.coach, this.coachNote});
}

class RoleplaySim {
  final Character c;
  final Metric focus;
  int _turn = 0;
  RoleplaySim(this.c, this.focus);

  static const _weakOpeners = ['hey', 'hi', 'hello', 'yo', 'sup', 'hey there'];
  static const _needy = ['please', 'sorry', 'i think you', 'you\'re so pretty',
    'you\'re beautiful', 'can i', 'would you', 'do you like me'];

  Eval evaluate(String raw) {
    _turn++;
    final t = raw.toLowerCase().trim();
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    var strong = true;
    var delta = 6.0;

    final startsWeak = _weakOpeners.any((w) => t == w || t.startsWith('$w '));
    final isNeedy = _needy.any((n) => t.contains(n));
    final isQuestion = t.endsWith('?');
    final tooShort = words <= 2;
    final teasing = RegExp(r'trouble|bet|prove|hardly|cute|sure you|typical|is that|liar')
        .hasMatch(t);

    if (startsWeak || tooShort) {
      strong = false;
      delta = -4;
    } else if (isNeedy) {
      strong = false;
      delta = -6;
    } else if (isQuestion && !teasing) {
      strong = false;
      delta = 1;
    } else if (teasing) {
      strong = true;
      delta = 12;
    }

    // Bro cuts in on weak moves, or every 3rd turn to keep teaching.
    Coach? coach;
    String? note;
    if (!strong) {
      coach = _fix(t, startsWeak, isNeedy, isQuestion);
      note = isNeedy
          ? 'You handed her the frame. Never chase — make her earn it.'
          : startsWeak || tooShort
              ? 'Dead on arrival. She\'s heard "$raw" a thousand times.'
              : 'Boring question. Lead with a read, not an interview.';
    } else if (_turn % 3 == 0) {
      coach = const Coach('Push-Pull',
          'Good. Now pull back — tease her right after she warms up.');
      note = 'Solid. Here\'s how to press the advantage:';
    }

    return Eval(delta, strong, coach: coach, coachNote: note);
  }

  Coach _fix(String t, bool weakOpen, bool needy, bool question) {
    if (needy) {
      return const Coach('Hold Frame',
          'You\'ve got about three seconds before I get bored. Impress me.');
    }
    if (weakOpen) {
      return const Coach('The Cold Open',
          'You look like you know exactly how much trouble you are.');
    }
    if (question) {
      return const Coach('The Statement',
          'Let me guess — you\'re the one your friends have to keep an eye on.');
    }
    return const Coach('Playful Tease',
        'That was almost smooth. Almost.');
  }

  String herReply(String raw, Eval e) {
    final pool = e.strong ? _warm : _cold;
    return pool[(_turn + raw.length) % pool.length];
  }

  Hint hint(String lastHer) => Hint(
        'She just said "${_short(lastHer)}". Flip it — agree and exaggerate, '
        'then tease.',
        'The Reframe',
        _closers[(lastHer.length) % _closers.length],
      );

  String _short(String s) => s.length > 34 ? '${s.substring(0, 34)}…' : s;

  // Character-flavoured reply pools (stand-in for persona prompts).
  List<String> get _warm => switch (c.id) {
        'ice_queen' => const [
            'Hm. That was almost clever.',
            'Okay. You have my attention. For now.',
            'Bold. I\'ll allow it.',
          ],
        'chaos' => const [
            'Ha! Okay I did NOT expect that.',
            'You\'re dangerous. I like it.',
            'Stop it — you\'re making me laugh.',
          ],
        _ => const [
            'Okay, that was good. Keep going.',
            'Mm. You\'re not like the others.',
            'I\'ll admit — that landed.',
          ],
      };

  List<String> get _cold => switch (c.id) {
        'ice_queen' => const [
            'That\'s it? I expected more.',
            'Try again. Better this time.',
            '*checks phone* You were saying?',
          ],
        'chaos' => const [
            'Booooring. Next.',
            'Aw, did you rehearse that one?',
            'You\'re gonna have to do better than that.',
          ],
        _ => const [
            'Oh. Um. Okay.',
            'That\'s… a lot. Slow down.',
            'I\'m not sure what to say to that.',
          ],
      };

  static const _closers = [
    'You\'re trouble. I\'m into it — give me your number before I change my mind.',
    'This was fun. Don\'t make me regret giving you my attention.',
    'Okay, you win this round. Coffee, Thursday. Don\'t be late.',
  ];
}

class Hint {
  final String note;
  final String move;
  final String line;
  const Hint(this.note, this.move, this.line);
}
