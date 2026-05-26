/// THE GAZE — Curriculum 1.
///
/// A different shape from rhetoric / rizz lessons. The Gaze is a
/// presence ritual, not a speech drill. Each lesson is structured as
/// six deliberate beats:
///
///   1. STORY      — Lucien sets the tone. Slow framing of what this
///                   move IS and why it matters. Chunked across short
///                   beats so the TTS pauses feel natural.
///   2. DEMO       — Lucien demonstrates. Often just a few words +
///                   silence, where the silence IS the lesson.
///   3. INSTRUCT   — One short sentence handing the floor to the
///                   apprentice. Always ends with the trigger phrase
///                   that starts the timer ("Hold my eyes.", etc.).
///   4. DRILL      — Timer runs. Camera + MediaPipe accumulate
///                   per-frame samples across the six dimensions.
///   5. CORRECTION — Lucien teaches the WHY. Same content whether the
///                   user passed or failed — failure is the point of
///                   the lesson, not an exception.
///   6. SCORE      — Per-lesson score card showing the six dimensions,
///                   the combined Gaze Score, and the improvement
///                   delta vs the user's last attempt at this lesson.
///
/// Lessons can be retried; the highest score is what writes to memory.

enum GazeDimension {
  /// % of drill frames with eyeContactScore > 0.5 — how often gaze
  /// is actually locked on the camera.
  eyeStability,
  /// Inverse of blink rate during the drill window. Some lessons
  /// expect a few controlled blinks (Slow Look), others expect zero
  /// (Stillness). Per-lesson target is in [GazeLesson.targetBlinks].
  blinkControl,
  /// Only meaningful on rhythm lessons (Hold & Release, Slow Look).
  /// Measures the cleanliness of the look → pause → look-away → return
  /// timing. Set to 1.0 for non-rhythm lessons.
  rhythm,
  /// 1 − head-pose variance over the drill window. High score = head
  /// stayed still. Tension = stillness here.
  tension,
  /// 1 − average smile-strength during the drill window. High score =
  /// the apprentice held a neutral / barely-smiling face. Some lessons
  /// expect a small smile, in which case the target is non-zero.
  smileControl,
  /// Composite weighted score across the other five dimensions, with
  /// per-lesson weights from [GazeLesson.weights]. This IS the
  /// headline "magnetic" score.
  magneticPresence,
}

extension GazeDimensionName on GazeDimension {
  String get label => switch (this) {
        GazeDimension.eyeStability     => 'EYE STABILITY',
        GazeDimension.blinkControl     => 'BLINK CONTROL',
        GazeDimension.rhythm           => 'RHYTHM',
        GazeDimension.tension          => 'TENSION',
        GazeDimension.smileControl     => 'SMILE CONTROL',
        GazeDimension.magneticPresence => 'MAGNETIC PRESENCE',
      };
}

/// One Gaze lesson. The chunked narration arrays are the key thing
/// here — they get fed one-by-one to TTS with a long pause between,
/// which is what gives Lucien the ritualistic, deliberate feel the
/// product depends on. Long single-string narrations would just produce
/// a single audio file racing through itself.
class GazeLesson {
  final String id;
  final int    number;
  final String name;
  final String oneLine;       // card subtitle
  final String objective;     // one short imperative sentence

  /// Story beats. Each entry is a short sentence or fragment played
  /// as its own TTS call. Between each, the screen waits
  /// [GazeLesson.beatPauseMs] before the next beat starts.
  ///
  /// Example for STILLNESS:
  ///   ['Most men cannot stay still.',
  ///    'Stillness…',
  ///    '…creates gravity.']
  final List<String> story;

  /// Demo beats. Spoken in Lucien's voice; what he says is what he
  /// is doing on camera (we don't have a Lucien avatar yet — the
  /// effect is in the words + pauses).
  final List<String> demo;

  /// One short instruction sentence handed to the apprentice as the
  /// last beat before the timer starts. Example: "Look directly into
  /// my eyes. Do not smile. Do not move."
  final List<String> instruct;

  /// Drill window in seconds. Camera + MediaPipe accumulate per-frame
  /// samples across the six dimensions during this window.
  final int drillSeconds;

  /// Target blinks during the drill window. Score for blinkControl is
  /// max(0, 1 - actualBlinks / (targetBlinks + 1)). Stillness expects
  /// 0; Slow Look expects 1–2; etc.
  final int targetBlinks;

  /// Per-dimension weights for computing magneticPresence. Must sum
  /// to ~1.0. Each lesson emphasises different dimensions — Stillness
  /// is heavy on tension + eyeStability, Smile Calibration is heavy
  /// on smileControl, etc.
  final Map<GazeDimension, double> weights;

  /// True if this lesson involves rhythm (look-away/return). False
  /// for static-hold lessons; rhythm score is locked to 1.0 in that
  /// case.
  final bool isRhythmLesson;

  /// Lucien's correction beats — played after the drill ends, before
  /// the score card lands. Same content whether the apprentice passed
  /// or failed. The point is the teaching, not the verdict.
  final List<String> correction;

  /// Inter-beat pause in milliseconds. Kept short so Lucien lands
  /// punchy and deadly, not slow-motion. Faster lessons can override.
  final int beatPauseMs;

  /// CINEMATIC SOCIALS lessons only. When non-empty, the drill becomes a
  /// choreographed reel: Lucien CALLS each move out loud, one at a time,
  /// while the camera records — "look away… back… smoulder… down… up…
  /// now smile." Each entry is one spoken cue shown big on screen as the
  /// apprentice performs it. Empty = a normal hold drill.
  final List<String> sequenceCues;

  const GazeLesson({
    required this.id,
    required this.number,
    required this.name,
    required this.oneLine,
    required this.objective,
    required this.story,
    required this.demo,
    required this.instruct,
    required this.drillSeconds,
    required this.targetBlinks,
    required this.weights,
    required this.isRhythmLesson,
    required this.correction,
    this.sequenceCues = const [],
    this.beatPauseMs = 600,
  });
}

/// One per-attempt result, persisted into [LessonProgressStore] so the
/// user can see "+12 this week" on the share card.
class GazeResult {
  final String lessonId;
  final int lessonNumber;
  final String lessonName;
  final Map<GazeDimension, double> dims;  // 0..1 each
  /// Raw measurements surfaced on the score card alongside the %s.
  final int blinks;
  final int drillSeconds;
  final int timestampMs;

  const GazeResult({
    required this.lessonId,
    required this.lessonNumber,
    required this.lessonName,
    required this.dims,
    required this.blinks,
    required this.drillSeconds,
    required this.timestampMs,
  });

  /// Headline number — 0..100.
  int get gazeScore =>
      ((dims[GazeDimension.magneticPresence] ?? 0) * 100).round();

  /// Per-dimension score as an integer 0..100 for display.
  int dimPct(GazeDimension d) => (((dims[d] ?? 0) * 100).round()).clamp(0, 100);

  /// "MAGNETIC" / "STEADY" / "WORK TO DO" — single-word verdict
  /// surfaced on the share card.
  String get badge {
    final s = gazeScore;
    if (s >= 80) return 'MAGNETIC';
    if (s >= 65) return 'STEADY';
    if (s >= 50) return 'EMERGING';
    return 'WORK TO DO';
  }

  Map<String, dynamic> toJson() => {
        'lessonId':     lessonId,
        'lessonNumber': lessonNumber,
        'lessonName':   lessonName,
        'dims':         dims.map((k, v) => MapEntry(k.name, v)),
        'blinks':       blinks,
        'drillSeconds': drillSeconds,
        'timestampMs':  timestampMs,
      };

  factory GazeResult.fromJson(Map<String, dynamic> j) {
    final dimsRaw = (j['dims'] as Map?) ?? {};
    final dims = <GazeDimension, double>{};
    for (final d in GazeDimension.values) {
      final v = dimsRaw[d.name];
      if (v is num) dims[d] = v.toDouble();
    }
    return GazeResult(
      lessonId:     (j['lessonId']     as String?) ?? '',
      lessonNumber: (j['lessonNumber'] as num?)?.toInt() ?? 0,
      lessonName:   (j['lessonName']   as String?) ?? '',
      dims:         dims,
      blinks:       (j['blinks']       as num?)?.toInt() ?? 0,
      drillSeconds: (j['drillSeconds'] as num?)?.toInt() ?? 0,
      timestampMs:  (j['timestampMs']  as num?)?.toInt() ?? 0,
    );
  }
}
