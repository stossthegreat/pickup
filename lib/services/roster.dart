import 'package:flutter/material.dart';

/// The 10 AI women — one source of truth, shared by Missions, Practice and
/// the relationship/memory layer. `id` = backend /v1/date characterId AND
/// the relationship-memory key. `vibeKey` = the FreeFlow voice persona.
/// `name` is her real first name (shown as the card title); `type` is her
/// short character chip (ICE QUEEN, SOCIAL MAGNET…). `tier` = how hard she
/// is to win (1 easy → 5 brutal), used to escalate which girl a mission
/// throws at you as you level up. `unlockDay` = the ascension day she opens
/// on — the roster is gated so the 60-day journey actually gates who you can
/// talk to (3 starters on Day 1, the rest unlock at the map's nodes).
class GirlBrief {
  final String id;
  final String vibeKey;
  final String name;
  final String type;
  final String archetype;
  final String opener;
  final String asset;
  final Color accent;
  final int tier;
  final int unlockDay;
  const GirlBrief({
    required this.id,
    required this.vibeKey,
    required this.name,
    required this.type,
    required this.archetype,
    required this.opener,
    required this.asset,
    required this.accent,
    required this.tier,
    this.unlockDay = 1,
  });
}

// New girls lead the roster (Practice shows them first). Order here does
// not affect the mission engine, which selects by tier.
const kRoster = <GirlBrief>[
  GirlBrief(
    id: 'amara', vibeKey: 'amara', name: 'Amara', type: 'SOCIAL MAGNET',
    archetype: 'Everyone wants her. Stand out or blend in.',
    opener: 'okay you actually came over. bold. i respect bold.',
    asset: 'assets/characters/women/amara.png', accent: Color(0xFFFB7185), tier: 2, unlockDay: 10),
  GirlBrief(
    id: 'daisy', vibeKey: 'daisy', name: 'Daisy', type: 'THE DITSY ONE',
    archetype: 'Bubbly and scattered. Keep it fun, not deep.',
    opener: 'omg hi — wait okay i totally forgot what i was gonna say. hi.',
    asset: 'assets/characters/women/daisy.png', accent: Color(0xFFFDBA74), tier: 1, unlockDay: 1),
  GirlBrief(
    id: 'valentina', vibeKey: 'valentina', name: 'Valentina', type: 'THE REAL ONE',
    archetype: 'Grounded and dry. Flexing kills it.',
    opener: 'hey. quick warning — i can smell a rehearsed line from here.',
    asset: 'assets/characters/women/valentina.png', accent: Color(0xFF34D399), tier: 3, unlockDay: 20),
  GirlBrief(
    id: 'simone', vibeKey: 'simone', name: 'Simone', type: 'HIGH VALUE',
    archetype: 'High bar, short patience. Bring substance.',
    opener: 'i\'ll give you thirty seconds. make them interesting.',
    asset: 'assets/characters/women/simone.png', accent: Color(0xFFA855F7), tier: 4, unlockDay: 40),
  GirlBrief(
    id: 'ice_queen', vibeKey: 'cold', name: 'Seraphina', type: 'ICE QUEEN',
    archetype: 'Selective. Gives you nothing. Earn every inch.',
    opener: 'let me guess. you practised that in the mirror.',
    asset: 'assets/characters/women/ice_queen.png', accent: Color(0xFF38BDF8), tier: 5, unlockDay: 30),
  GirlBrief(
    id: 'into_you', vibeKey: 'into_you', name: 'Sofia', type: 'INTO YOU',
    archetype: 'Already a little into you. Don\'t get needy.',
    opener: 'oh, it\'s you. i was kind of hoping you\'d text.',
    asset: 'assets/characters/women/arena.png', accent: Color(0xFFF472B6), tier: 1, unlockDay: 1),
  GirlBrief(
    id: 'chaos', vibeKey: 'chaos', name: 'Lexi', type: 'CHAOS',
    archetype: 'Fast, loud, jumps topics. Keep up.',
    opener: 'you look like a bad decision. i love bad decisions.',
    asset: 'assets/characters/women/chaos_girl.png', accent: Color(0xFFE8222A), tier: 2, unlockDay: 10),
  GirlBrief(
    id: 'intellectual', vibeKey: 'testing', name: 'Elise', type: 'TESTING YOU',
    archetype: 'Smart. Testing you constantly. Don\'t fold.',
    opener: 'say something interesting. i\'ll wait.',
    asset: 'assets/characters/women/intellectual.png', accent: Color(0xFF8B94F5), tier: 3, unlockDay: 20),
  GirlBrief(
    id: 'socialite', vibeKey: 'ice_then_fire', name: 'Camila', type: 'ICE THEN FIRE',
    archetype: 'Starts ice cold. Warms only if you hold.',
    opener: 'everyone here wants something from me. what do you want?',
    asset: 'assets/characters/women/socialite.png', accent: Color(0xFFFBBF24), tier: 4, unlockDay: 40),
  GirlBrief(
    id: 'shy', vibeKey: 'sweet', name: 'Mara', type: 'SWEET',
    archetype: 'Warm and genuine. Kill the arrogance.',
    opener: 'oh — hi. i didn\'t think you\'d actually text first.',
    asset: 'assets/characters/women/shy_girl.png', accent: Color(0xFF4ADE80), tier: 1, unlockDay: 1),
  ];

/// The five relationship stages a girl moves through (index 1..5).
const kRelationshipStages = <String>[
  '', // 0 unused
  'Matched', 'Talking', 'First Date', 'Second Date', 'Together',
];

GirlBrief girlById(String id) =>
    kRoster.firstWhere((g) => g.id == id, orElse: () => kRoster.first);

/// Ascension day a FreeFlow vibe persona unlocks on (defaults to 1 if the
/// vibe isn't a roster girl). Used to gate the Free Flow picker the same way
/// Practice gates the grid.
int unlockDayForVibe(String vibeKey) {
  for (final g in kRoster) {
    if (g.vibeKey == vibeKey) return g.unlockDay;
  }
  return 1;
}
