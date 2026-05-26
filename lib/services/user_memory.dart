import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// User memory — fed into the system prompt of every Diabla / Lucien
/// session so the teacher remembers what they last drilled, what the
/// apprentice bombed, and what's queued next.
///
/// Storage shape (one SharedPreferences key, JSON encoded):
///   {
///     "lastSessions": [
///       { "topic": "rhetoric", "lessonName": "Conviction", "score": 42,
///         "notes": "hedged on 'right' twice", "ts": 1737245... }
///     ],
///     "weakestDimension": "conviction",
///     "totalLessonsCompleted": 7,
///   }
///
/// Only the last 6 sessions are kept — feeding more into the system
/// prompt costs tokens and the model doesn't benefit from much further.
class UserMemory {
  static const _key = 'aura_user_memory_v1';
  static const _maxSessions = 6;

  static Future<_MemoryState> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return _MemoryState.empty();
    try {
      return _MemoryState.fromJson(
        json.decode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return _MemoryState.empty();
    }
  }

  static Future<void> _write(_MemoryState m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(m.toJson()));
  }

  /// Record one completed session — call from any lesson runner when the
  /// session ends.
  static Future<void> recordSession({
    required String topic,            // "rhetoric" | "rizz" | "eyes"
    required String lessonName,
    required int score,               // 0..60
    required String notes,            // 1-line summary in Diabla's voice
    String? weakestDimension,
  }) async {
    final m = await _read();
    final sessions = [
      _Session(
        topic: topic,
        lessonName: lessonName,
        score: score,
        notes: notes,
        ts: DateTime.now().millisecondsSinceEpoch,
      ),
      ...m.lastSessions,
    ].take(_maxSessions).toList();
    final next = _MemoryState(
      lastSessions: sessions,
      weakestDimension: weakestDimension ?? m.weakestDimension,
      totalLessonsCompleted: m.totalLessonsCompleted + 1,
    );
    await _write(next);
  }

  /// Build a block of text the backend can paste straight into the
  /// teacher's system prompt. Empty string if the user is fresh.
  static Future<String> buildSystemPromptBlock({
    String? filterTopic,             // restrict to "rhetoric" / "rizz" / "eyes"
  }) async {
    final m = await _read();
    final sessions = filterTopic == null
        ? m.lastSessions
        : m.lastSessions.where((s) => s.topic == filterTopic).toList();

    if (sessions.isEmpty) return '';

    final buf = StringBuffer();
    buf.writeln('# WHAT YOU REMEMBER ABOUT THIS APPRENTICE');
    buf.writeln();
    buf.writeln(
      'You have taught this apprentice ${m.totalLessonsCompleted} '
      'session${m.totalLessonsCompleted == 1 ? "" : "s"} before. '
      'Acknowledge it in your opening — by name of move, not by number. '
      'Build on what you saw.',
    );
    buf.writeln();
    if (m.weakestDimension != null && m.weakestDimension!.isNotEmpty) {
      buf.writeln(
        'His weakest dimension across every session has been: '
        '${m.weakestDimension}. Pressure-test it tonight.',
      );
      buf.writeln();
    }
    buf.writeln('Recent sessions, most recent first:');
    for (final s in sessions) {
      buf.writeln('  - ${s.lessonName} (${s.topic}) — '
                  'scored ${s.score}/60. Note: ${s.notes}');
    }
    return buf.toString();
  }

  /// Wipes everything — for "reset all data" in Settings.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

// ─── Internal types ──────────────────────────────────────────────────────

class _Session {
  final String topic;
  final String lessonName;
  final int score;
  final String notes;
  final int ts;
  _Session({
    required this.topic,
    required this.lessonName,
    required this.score,
    required this.notes,
    required this.ts,
  });
  Map<String, dynamic> toJson() => {
        'topic': topic,
        'lessonName': lessonName,
        'score': score,
        'notes': notes,
        'ts': ts,
      };
  factory _Session.fromJson(Map<String, dynamic> j) => _Session(
        topic:      j['topic']      as String? ?? '',
        lessonName: j['lessonName'] as String? ?? '',
        score:      (j['score']     as num?)?.toInt() ?? 0,
        notes:      j['notes']      as String? ?? '',
        ts:         (j['ts']        as num?)?.toInt() ?? 0,
      );
}

class _MemoryState {
  final List<_Session> lastSessions;
  final String? weakestDimension;
  final int totalLessonsCompleted;
  _MemoryState({
    required this.lastSessions,
    required this.weakestDimension,
    required this.totalLessonsCompleted,
  });
  factory _MemoryState.empty() => _MemoryState(
        lastSessions: const [],
        weakestDimension: null,
        totalLessonsCompleted: 0,
      );
  Map<String, dynamic> toJson() => {
        'lastSessions':
            lastSessions.map((s) => s.toJson()).toList(),
        'weakestDimension':       weakestDimension,
        'totalLessonsCompleted':  totalLessonsCompleted,
      };
  factory _MemoryState.fromJson(Map<String, dynamic> j) => _MemoryState(
        lastSessions: ((j['lastSessions'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(_Session.fromJson)
            .toList(),
        weakestDimension: j['weakestDimension'] as String?,
        totalLessonsCompleted:
            (j['totalLessonsCompleted'] as num?)?.toInt() ?? 0,
      );
}
