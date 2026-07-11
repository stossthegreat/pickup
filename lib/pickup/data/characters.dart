import '../models/character.dart';

/// Roster mapped onto the renders that already ship in
/// assets/characters/women/. These mirror the backend2 villain personas.
abstract final class Roster {
  static const women = <Character>[
    Character(
      id: 'ice_queen',
      name: 'Seraphina',
      archetype: 'The Ice Queen · thinks she\'s above you',
      asset: 'assets/characters/women/ice_queen.png',
      vibe:
          'Cold, composed, gives you nothing for free. She\'s heard every '
          'line. Melt the frost without trying too hard and she respects you. '
          'Chase and she freezes you out.',
      opener: 'Let me guess. You practised that in the mirror.',
      unlockLevel: 1,
      accentValue: 0xFF38BDF8,
    ),
    Character(
      id: 'chaos',
      name: 'Nyx',
      archetype: 'The Chaos Girl · wild, unpredictable',
      asset: 'assets/characters/women/chaos_girl.png',
      vibe:
          'Fast, teasing, changes the subject to keep you off balance. She '
          'rewards the man who plays back and punishes the one who plays safe.',
      opener: 'You look like a bad decision. I like bad decisions.',
      unlockLevel: 1,
      accentValue: 0xFFE8222A,
    ),
    Character(
      id: 'intellectual',
      name: 'Elise',
      archetype: 'The Intellectual · punishes posturing',
      asset: 'assets/characters/women/intellectual.png',
      vibe:
          'Sharp and dry. She smells a fake from across the room. Name-drop '
          'or pretend a depth you don\'t have and she\'ll dismantle you. Be '
          'real and curious and she opens.',
      opener: 'Say something interesting. I\'ll wait.',
      unlockLevel: 4,
      accentValue: 0xFF8B94F5,
    ),
    Character(
      id: 'socialite',
      name: 'Camila',
      archetype: 'The Hot Girl · knows exactly what she is',
      asset: 'assets/characters/women/socialite.png',
      vibe:
          'Used to attention, bored of it. Compliments bounce off her. The '
          'only thing that lands is a man who isn\'t impressed.',
      opener: 'Everyone here wants something from me. What do you want?',
      unlockLevel: 8,
      accentValue: 0xFFFBBF24,
    ),
    Character(
      id: 'shy',
      name: 'Mara',
      archetype: 'The Shy Girl · warm, needs you to lead',
      asset: 'assets/characters/women/shy_girl.png',
      vibe:
          'Sweet and a little nervous. She won\'t carry the conversation — '
          'you have to make it safe and lead. Warmth and patience win. '
          'Intensity scares her off.',
      opener: 'Oh — hi. Sorry, I didn\'t think you\'d actually come over.',
      unlockLevel: 12,
      accentValue: 0xFF4ADE80,
    ),
  ];

  static Character byId(String id) =>
      women.firstWhere((c) => c.id == id, orElse: () => women.first);
}
