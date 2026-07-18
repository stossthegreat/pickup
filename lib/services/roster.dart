import 'package:flutter/material.dart';

/// The 10 AI women — one source of truth, shared by Missions, Practice and
/// the relationship/memory layer. `id` = backend /v1/date characterId AND
/// the relationship-memory key. `vibeKey` = the FreeFlow voice persona.
/// `tier` = how hard she is to win (1 easy → 5 brutal), used to escalate
/// which girl a mission throws at you as you level up.
class GirlBrief {
  final String id;
  final String vibeKey;
  final String name;
  final String archetype;
  final String opener;
  final String asset;
  final Color accent;
  final int tier;
  const GirlBrief({
    required this.id,
    required this.vibeKey,
    required this.name,
    required this.archetype,
    required this.opener,
    required this.asset,
    required this.accent,
    required this.tier,
  });
}

const kRoster = <GirlBrief>[
  GirlBrief(
    id: 'daisy', vibeKey: 'daisy', name: 'Daisy',
    archetype: 'Bubbly and scattered. Keep it fun, not deep.',
    opener: 'omg hi — wait okay i totally forgot what i was gonna say. hi.',
    asset: 'assets/characters/women/daisy.png', accent: Color(0xFFFDBA74), tier: 1),
  GirlBrief(
    id: 'into_you', vibeKey: 'into_you', name: 'Into You',
    archetype: 'Already a little into you. Don\'t get needy.',
    opener: 'oh, it\'s you. i was kind of hoping you\'d text.',
    asset: 'assets/characters/women/arena.png', accent: Color(0xFFF472B6), tier: 1),
  GirlBrief(
    id: 'shy', vibeKey: 'sweet', name: 'Sweet',
    archetype: 'Warm and genuine. Kill the arrogance.',
    opener: 'oh — hi. i didn\'t think you\'d actually text first.',
    asset: 'assets/characters/women/shy_girl.png', accent: Color(0xFF4ADE80), tier: 1),
  GirlBrief(
    id: 'amara', vibeKey: 'amara', name: 'Amara',
    archetype: 'Everyone wants her. Stand out or blend in.',
    opener: 'okay you actually came over. bold. i respect bold.',
    asset: 'assets/characters/women/amara.png', accent: Color(0xFFFB7185), tier: 2),
  GirlBrief(
    id: 'chaos', vibeKey: 'chaos', name: 'Chaos',
    archetype: 'Fast, loud, jumps topics. Keep up.',
    opener: 'you look like a bad decision. i love bad decisions.',
    asset: 'assets/characters/women/chaos_girl.png', accent: Color(0xFFE8222A), tier: 2),
  GirlBrief(
    id: 'valentina', vibeKey: 'valentina', name: 'Valentina',
    archetype: 'Grounded and dry. Flexing kills it.',
    opener: 'hey. quick warning — i can smell a rehearsed line from here.',
    asset: 'assets/characters/women/valentina.png', accent: Color(0xFF34D399), tier: 3),
  GirlBrief(
    id: 'intellectual', vibeKey: 'testing', name: 'Testing You',
    archetype: 'Smart. Testing you constantly. Don\'t fold.',
    opener: 'say something interesting. i\'ll wait.',
    asset: 'assets/characters/women/intellectual.png', accent: Color(0xFF8B94F5), tier: 3),
  GirlBrief(
    id: 'socialite', vibeKey: 'ice_then_fire', name: 'Ice Then Fire',
    archetype: 'Starts ice cold. Warms only if you hold.',
    opener: 'everyone here wants something from me. what do you want?',
    asset: 'assets/characters/women/socialite.png', accent: Color(0xFFFBBF24), tier: 4),
  GirlBrief(
    id: 'simone', vibeKey: 'simone', name: 'Simone',
    archetype: 'High bar, short patience. Bring substance.',
    opener: 'i\'ll give you thirty seconds. make them interesting.',
    asset: 'assets/characters/women/simone.png', accent: Color(0xFFA855F7), tier: 4),
  GirlBrief(
    id: 'ice_queen', vibeKey: 'cold', name: 'Ice Queen',
    archetype: 'Selective. Gives you nothing. Earn every inch.',
    opener: 'let me guess. you practised that in the mirror.',
    asset: 'assets/characters/women/ice_queen.png', accent: Color(0xFF38BDF8), tier: 5),
  ];

/// The five relationship stages a girl moves through (index 1..5).
const kRelationshipStages = <String>[
  '', // 0 unused
  'Matched', 'Talking', 'First Date', 'Second Date', 'Together',
];

GirlBrief girlById(String id) =>
    kRoster.firstWhere((g) => g.id == id, orElse: () => kRoster.first);
