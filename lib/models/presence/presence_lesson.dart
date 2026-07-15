/// PRESENCE — Curriculum 2 of the Presence Classroom.
///
/// Where The Gaze trained the eyes alone, Presence trains delivery —
/// voice + body together. Same six-beat ritual; same Lucien-narrated
/// chunked story / demo / instruct / correction. The drill phase
/// records the apprentice delivering ONE target line while the
/// camera tracks the gaze in parallel, then the backend transcribes
/// and scores his voice across the four voice-side dimensions.
///
/// Seven dimensions total:
///   Voice Authority  (backend) — how grounded, weighted, decisive
///                                his voice was
///   Pace             (backend) — words-per-minute against the
///                                lesson target band
///   Confidence       (backend) — absence of hedges, fillers,
///                                upward inflection on declarations
///   Eye Contact      (local)   — % of recording frames where
///                                MediaPipe reported lock
///   Warmth           (backend) — was there a smile in the voice
///                                when the lesson called for one
///   Tension          (local)   — average headStability during the
///                                recording window
///   Charisma         (composite) — weighted average across the
///                                  other six; the headline number
///
/// Each lesson pins per-dimension weights so Slow Down loads on
/// Pace, Sentence Endings loads on Confidence, Voice Gravity loads
/// on Voice Authority, etc.

enum PresenceDimension {
  voiceAuthority,
  pace,
  confidence,
  eyeContact,
  warmth,
  tension,
  charisma,        // composite headline
}

extension PresenceDimensionName on PresenceDimension {
  String get label => switch (this) {
        PresenceDimension.voiceAuthority => 'VOICE AUTHORITY',
        PresenceDimension.pace           => 'PACE',
        PresenceDimension.confidence     => 'CONFIDENCE',
        PresenceDimension.eyeContact     => 'EYE CONTACT',
        PresenceDimension.warmth         => 'WARMTH',
        PresenceDimension.tension        => 'TENSION',
        PresenceDimension.charisma       => 'CHARISMA',
      };

  /// Which side computes this dimension. The backend scorer fills the
  /// voice-side dims; the screen fills eyeContact + tension locally;
  /// charisma is the weighted composite.
  bool get isBackend => switch (this) {
        PresenceDimension.voiceAuthority => true,
        PresenceDimension.pace           => true,
        PresenceDimension.confidence     => true,
        PresenceDimension.warmth         => true,
        PresenceDimension.eyeContact     => false,
        PresenceDimension.tension        => false,
        PresenceDimension.charisma       => false, // composite
      };
}

class PresenceLesson {
  final String id;
  final int    number;
  final String name;
  final String oneLine;
  final String objective;

  /// Same chunked-narration shape as GazeLesson. Each entry is a
  /// short sentence; the screen plays them one at a time with
  /// [beatPauseMs] between them so Lucien feels deliberate.
  final List<String> story;
  final List<String> demo;
  final List<String> instruct;

  /// The verbatim line the apprentice must deliver. Shown on screen
  /// during the drill.
  final String targetLine;

  /// ONE delivery cue surfaced under the target line.
  final String deliveryCue;

  /// How many seconds the recording window lasts. Defaults to 10s —
  /// enough for one full line + a beat. Longer lessons (Mystery,
  /// Magnetic Conversation Test) get more.
  final int drillSeconds;

  /// Per-dimension weights for the composite charisma score. Lessons
  /// emphasise different axes — Slow Down loads on Pace, Sentence
  /// Endings loads on Confidence, etc. Charisma's own weight is
  /// excluded (it IS the composite).
  final Map<PresenceDimension, double> weights;

  /// The "right" pace band for THIS line, in words-per-minute. The
  /// backend scorer rewards being inside the band and penalises both
  /// rushing AND drawling. Slow Down has [80, 130]; rapid-fire lines
  /// have [160, 220]; etc.
  final int targetWpmLow;
  final int targetWpmHigh;

  /// Whether this lesson EXPECTS a smile in the voice. Drives the
  /// backend warmth scoring direction. Most lessons want a neutral
  /// or grave delivery; Playfulness + Curiosity want warmth.
  final bool warmthExpected;

  final List<String> correction;

  final int beatPauseMs;

  const PresenceLesson({
    required this.id,
    required this.number,
    required this.name,
    required this.oneLine,
    required this.objective,
    required this.story,
    required this.demo,
    required this.instruct,
    required this.targetLine,
    required this.deliveryCue,
    required this.drillSeconds,
    required this.weights,
    required this.targetWpmLow,
    required this.targetWpmHigh,
    required this.warmthExpected,
    required this.correction,
    this.beatPauseMs = 600,
  });
}

/// One per-attempt presence result. Stored in [PresenceProgressStore]
/// so the share card can surface improvement deltas.
class PresenceResult {
  final String lessonId;
  final int    lessonNumber;
  final String lessonName;

  /// 0..1 per dimension. Includes the charisma composite.
  final Map<PresenceDimension, double> dims;

  /// What Whisper heard. Surfaced on the share card so the apprentice
  /// can see what was transcribed.
  final String transcript;

  /// The one fatal-flaw line the backend coined for this attempt.
  /// Pre-flight in Lucien's voice, kept short, stamped on the card.
  final String fatalFlaw;

  /// Computed words-per-minute for this take. Surfaced as a sub-stat.
  final int wpm;

  final int timestampMs;

  const PresenceResult({
    required this.lessonId,
    required this.lessonNumber,
    required this.lessonName,
    required this.dims,
    required this.transcript,
    required this.fatalFlaw,
    required this.wpm,
    required this.timestampMs,
  });

  int get charisma =>
      ((dims[PresenceDimension.charisma] ?? 0) * 100).round();

  int dimPct(PresenceDimension d) =>
      (((dims[d] ?? 0) * 100).round()).clamp(0, 100);

  /// "IMPOSSIBLE TO IGNORE" / "DECIDED" / "STILL ASKING" / "INVISIBLE"
  /// — single-phrase verdict surfaced on the share card.
  String get badge {
    final s = charisma;
    if (s >= 82) return 'IMPOSSIBLE TO IGNORE';
    if (s >= 66) return 'DECIDED';
    if (s >= 50) return 'STILL ASKING';
    return 'INVISIBLE';
  }

  Map<String, dynamic> toJson() => {
        'lessonId':     lessonId,
        'lessonNumber': lessonNumber,
        'lessonName':   lessonName,
        'dims':         dims.map((k, v) => MapEntry(k.name, v)),
        'transcript':   transcript,
        'fatalFlaw':    fatalFlaw,
        'wpm':          wpm,
        'timestampMs':  timestampMs,
      };

  factory PresenceResult.fromJson(Map<String, dynamic> j) {
    final dimsRaw = (j['dims'] as Map?) ?? {};
    final dims = <PresenceDimension, double>{};
    for (final d in PresenceDimension.values) {
      final v = dimsRaw[d.name];
      if (v is num) dims[d] = v.toDouble();
    }
    return PresenceResult(
      lessonId:     (j['lessonId']     as String?) ?? '',
      lessonNumber: (j['lessonNumber'] as num?)?.toInt() ?? 0,
      lessonName:   (j['lessonName']   as String?) ?? '',
      dims:         dims,
      transcript:   (j['transcript']   as String?) ?? '',
      fatalFlaw:    (j['fatalFlaw']    as String?) ?? '',
      wpm:          (j['wpm']          as num?)?.toInt() ?? 0,
      timestampMs:  (j['timestampMs']  as num?)?.toInt() ?? 0,
    );
  }
}
