/// A roleplay woman. `asset` points at the existing render in
/// assets/characters/women/. `unlockLevel` gates her behind Aura progression.
class Character {
  final String id;
  final String name;
  final String archetype; // one-line card subtitle
  final String asset;
  final String vibe; // longer persona blurb for the intro sheet
  final String opener; // her first line when a scene opens
  final int unlockLevel;
  final int accentValue; // ARGB int for her signature glow

  const Character({
    required this.id,
    required this.name,
    required this.archetype,
    required this.asset,
    required this.vibe,
    required this.opener,
    this.unlockLevel = 1,
    required this.accentValue,
  });
}
