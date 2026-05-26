class AuralayAppState {
  final bool hasSeenOnboarding;
  final bool isSubscribed;
  final int streakDays;
  final int currentDay;
  final int auraScore;
  final String currentTechnique;

  const AuralayAppState({
    this.hasSeenOnboarding = false,
    this.isSubscribed = false,
    this.streakDays = 0,
    this.currentDay = 1,
    this.auraScore = 0,
    this.currentTechnique = 'Delayed Smile',
  });

  AuralayAppState copyWith({
    bool? hasSeenOnboarding,
    bool? isSubscribed,
    int? streakDays,
    int? currentDay,
    int? auraScore,
    String? currentTechnique,
  }) {
    return AuralayAppState(
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      isSubscribed:      isSubscribed      ?? this.isSubscribed,
      streakDays:        streakDays        ?? this.streakDays,
      currentDay:        currentDay        ?? this.currentDay,
      auraScore:         auraScore         ?? this.auraScore,
      currentTechnique:  currentTechnique  ?? this.currentTechnique,
    );
  }
}
