import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/auralay_dev_flags.dart';
import 'local_store_service.dart';

/// OpenAI Realtime API session — sub-second turn-taking voice
/// conversation with Diablo. Architecture:
///
///   1. Frontend hits  POST /v1/realtime/session  on our Railway backend.
///   2. Backend mints an ephemeral OpenAI session token + persona config.
///   3. Frontend opens a WebSocket to wss://api.openai.com/v1/realtime
///      using that ephemeral token. Backend never touches audio bytes.
///   4. Frontend streams PCM16 mic chunks → OpenAI; receives PCM16 audio
///      chunks back → plays through speaker.
///
/// This class owns steps 1–3 + the JSON event protocol. Audio I/O
/// (PCM streaming in + streaming playback) is plugged in via the
/// [onAudioDelta] / [sendAudioChunk] callbacks — the actual mic capture
/// and PCM playback live in the screen that owns this session (push 12).
///
/// Lifecycle:
///   final session = RealtimeSession();
///   await session.connect(mode: 'thirst');
///   session.events.listen((e) { ... });
///   // start streaming audio in via session.sendAudioChunk(bytes)
///   // listen for session.events of type 'response.audio.delta'
///   await session.close();
class RealtimeSession {
  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _sub;

  final _eventCtrl = StreamController<RealtimeEvent>.broadcast();

  /// Stream of typed events arriving from OpenAI. Subscribe in the UI
  /// to react to user transcripts, model audio deltas, response done,
  /// errors, etc.
  Stream<RealtimeEvent> get events => _eventCtrl.stream;

  bool _connected = false;
  bool get isConnected => _connected;

  String? _sessionId;
  String? get sessionId => _sessionId;

  // ─── Connect ───────────────────────────────────────────────────────────

  /// Open a Realtime session. Pass [body] verbatim — it goes to our
  /// backend's POST /v1/realtime/session, where the teacher persona +
  /// lesson syllabus get baked into the OpenAI instructions block.
  ///
  /// Lesson body shape:
  ///   { teacherId, mode: "lesson", topic, lessonName, targetLines: [{line,cue}] }
  /// Practice body shape:
  ///   { teacherId, mode: "practice", topic }
  Future<void> connect({required Map<String, dynamic> body}) async {
    // AI consent backstop (App Store 5.1.2(i)) — never open a voice
    // session to OpenAI without permission. Every voice surface (roleplay,
    // gaze drills, etc.) funnels through here, so this one check guarantees
    // no live audio path can start unconsented. The one-time launch prompt
    // means this only ever blocks a user who explicitly declined.
    if (!await LocalStoreService.hasAiConsent()) {
      throw const RealtimeError('consent_required',
          'AI permission is required for voice features. Enable it in '
          'Settings to continue.');
    }
    if (!AuralayDevFlags.hasBackend) {
      throw const RealtimeError('backend_not_configured',
          'AURALAY_API not set at build time — realtime needs Railway.');
    }

    // 1) Mint ephemeral token + persona-configured session via our backend.
    final sessionConfig = await _mintSession(body: body);
    final ephemeralKey = (sessionConfig['client_secret']
            as Map<String, dynamic>?)?['value'] as String?;
    _sessionId = sessionConfig['id'] as String?;
    if (ephemeralKey == null || ephemeralKey.isEmpty) {
      throw const RealtimeError('no_client_secret',
          'Backend did not return a client_secret. Check the realtime route.');
    }

    // ── THE MODEL GATE — NORMAL MODE NEVER OPENS THE FULL MODEL ────────
    //
    // Both voice paths in the app land here: the woman (mode freeflow)
    // and Lucien's step-in (mode lucien). Whatever else changes, this
    // is the single place a billable socket gets opened, so it is the
    // only place the rule can actually be enforced.
    //
    // THE HOLE THIS CLOSES. The model came straight from the backend's
    // mint response with `?? 'gpt-realtime'` behind it — the FULL model
    // as the fallback. So any response that omitted the field (a deploy,
    // a config change, an error path, an older route) silently put every
    // ordinary user on a model costing roughly three times mini, with no
    // error, no log, and nothing visible until an invoice weeks later.
    // The app also simply trusted the value: a backend bug returning the
    // full model for a normal session would have been obeyed.
    //
    // Trust is now gone. A non-creator session must come back on a mini
    // model or it does not connect at all. Bro's instruction was exact:
    // it can never use the full model, even if that means voice goes
    // down. A refused session costs nothing and shows a clear error; a
    // wrong session costs money on every user who ever calls.
    //
    // MATCHED BY SHAPE, NOT BY EXACT ID. The check is "does the name say
    // mini", not a hardcoded id, because the backend owns the id and it
    // will change — gpt-realtime-mini, gpt-4o-mini-realtime-preview, and
    // whatever replaces them all pass, while every full model fails.
    // Pinning one string here would break voice the day OpenAI renames
    // it, which is the failure that gets "fixed" by deleting the guard.
    //
    // CREATOR MODE IS UNTOUCHED. It is the one mode that is SUPPOSED to
    // run the full model, it is switched on by hand behind a password,
    // and bro controls who has it. It keeps the old behaviour exactly,
    // including the historical fallback.
    final creator = body['creator'] == true;
    var model = _modelIdFrom(sessionConfig);
    final tier = _tierFrom(sessionConfig);

    // A tier label that says anything other than mini is a server
    // regression the app can catch even when no model id is echoed.
    if (!creator && tier.isNotEmpty && !_isMini(tier)) {
      throw RealtimeError(
        'model_not_mini',
        'Refusing to open a voice session: the backend reported '
        'modelTier "$tier" for a normal session. Check what '
        '/v1/realtime/session returns for creator=false.',
      );
    }

    if (creator) {
      // Untouched. Creator is the one mode meant to run the full model.
      if (model.isEmpty) model = 'gpt-realtime';
    } else if (model.isEmpty) {
      // COULD NOT VERIFY — so ASK FOR MINI, never full.
      //
      // The backend picks the tier itself (its logs show
      // modelTier: mini for creator=false) and the ephemeral key binds
      // the session to that choice before this socket opens, so a model
      // in the URL is a request, not a decision. The old code put
      // 'gpt-realtime' here, which meant the app's own fallback was
      // asking for the expensive model. Naming mini instead means the
      // app can never be the thing that requests full.
      //
      // Refusing outright would be the stricter reading, but it would
      // take voice down over a field the backend simply might not echo
      // — punishing a server that is doing the right thing. Asking for
      // mini satisfies the rule with none of that risk.
      model = _kMiniModel;
    } else if (!_isMini(model)) {
      // VERIFIED WRONG. The backend named a model and it is not a mini
      // one. That is a real regression on the server, and the only safe
      // answer is not to open the socket: a refused session costs
      // nothing, a wrong one costs money on every user who calls.
      throw RealtimeError(
        'model_not_mini',
        'Refusing to open a voice session: normal mode must use a mini '
        'realtime model and the backend returned "$model". Check what '
        '/v1/realtime/session returns for creator=false.',
      );
    }

    // 2) Open WebSocket to OpenAI with the ephemeral token.
    final uri = Uri.parse(
      'wss://api.openai.com/v1/realtime?model=$model',
    );
    // GA Realtime API no longer requires the OpenAI-Beta header — the
    // ephemeral key in the bearer token is enough. Sending the legacy
    // header is harmless but we drop it for cleanliness.
    final ws = IOWebSocketChannel.connect(
      uri,
      headers: {
        'Authorization': 'Bearer $ephemeralKey',
      },
    );
    _ws = ws;
    _connected = true;

    // 3) Wire the event stream — every JSON line OpenAI sends becomes a
    //    typed [RealtimeEvent] flowing through [events].
    _sub = ws.stream.listen(
      _onWsMessage,
      onError: (e, s) => _eventCtrl.add(RealtimeEvent.error(
        'ws_error', e.toString(),
      )),
      onDone: () {
        _connected = false;
        _eventCtrl.add(const RealtimeEvent.closed());
      },
      cancelOnError: false,
    );
  }

  /// The model the app asks for when it cannot read one from the mint
  /// response. Never a full model — see the gate in [connect].
  static const _kMiniModel = 'gpt-realtime-mini';

  /// Mini by SHAPE, not by exact id. The backend owns the id and it will
  /// change; gpt-realtime-mini, gpt-4o-mini-realtime-preview and
  /// whatever replaces them all pass, while every full model fails.
  /// Pinning one string here would break voice the day OpenAI renames
  /// it — and that is the failure people "fix" by deleting the guard.
  static bool _isMini(String m) => m.toLowerCase().contains('mini');

  /// The model ID from the mint response — an ID ONLY, never a tier.
  ///
  /// Two known shapes, because the app must not depend on a single field
  /// name it does not own: a top-level `model`, and the `session` object
  /// OpenAI returns from client_secret create, which carries the model
  /// the session was actually bound to. Empty means "no id given".
  ///
  /// `modelTier` is deliberately NOT read here. It is a tier label, not
  /// an id — sending `?model=mini` to OpenAI would be nonsense, and an
  /// earlier draft of this did exactly that. It is read separately by
  /// [_tierFrom] and used only to VERIFY.
  static String _modelIdFrom(Map<String, dynamic> cfg) {
    final direct = (cfg['model'] as String?)?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final session = cfg['session'];
    if (session is Map) {
      final nested = (session['model'] as String?)?.trim();
      if (nested != null && nested.isNotEmpty) return nested;
    }
    return '';
  }

  /// The backend's own tier label, if it sends one — its logs carry
  /// `modelTier: mini` beside the model. Verification signal only.
  static String _tierFrom(Map<String, dynamic> cfg) =>
      (cfg['modelTier'] as String?)?.trim() ?? '';

  Future<Map<String, dynamic>> _mintSession({
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('${AuralayDevFlags.apiBaseUrl}/v1/realtime/session');
    final resp = await http.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      // Surface the full backend response — it already wraps the
      // upstream OpenAI status + response body. We keep up to 1800
      // chars so the debug panel + clipboard report capture the
      // openAIResponse + requestSent fields without truncating.
      throw RealtimeError(
        'http_${resp.statusCode}',
        resp.body.length > 1800
            ? '${resp.body.substring(0, 1800)}…(${resp.body.length} chars total)'
            : resp.body,
      );
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // ─── Send: audio chunk (PCM16 LE @ 24kHz, base64) ──────────────────────

  /// Push one chunk of captured mic audio into the session. Caller is
  /// responsible for converting raw bytes to PCM16 little-endian @ 24kHz
  /// — the mic capture layer (push 12) handles that.
  void sendAudioChunk(Uint8List pcm16leBytes) {
    if (!_connected || _ws == null) return;
    _sendEvent({
      'type': 'input_audio_buffer.append',
      'audio': base64Encode(pcm16leBytes),
    });
  }

  /// Tells OpenAI the user has stopped speaking (only needed when
  /// server-side VAD is disabled — by default the session config uses
  /// `turn_detection: { type: server_vad }` so this is a no-op).
  void commitInputAudio() {
    _sendEvent({'type': 'input_audio_buffer.commit'});
  }

  /// Ask the model to generate a response now. Push-to-talk mode (server
  /// VAD off) commits the held audio then calls this to trigger her reply.
  void requestResponse() {
    _sendEvent({'type': 'response.create'});
  }

  /// Interrupt Diablo mid-sentence (e.g. user starts talking over her).
  void cancelResponse() {
    _sendEvent({'type': 'response.cancel'});
  }

  /// Send a text-only message into the conversation — useful for debug
  /// (e.g. "test, can you hear me") or for typed-input fallback.
  void sendTextMessage(String text) {
    _sendEvent({
      'type': 'conversation.item.create',
      'item': {
        'type': 'message',
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': text},
        ],
      },
    });
    _sendEvent({'type': 'response.create'});
  }

  /// Override session-level config after connect — instructions, voice,
  /// turn_detection, tools, modalities, temperature. Lets a single
  /// realtime persona on the backend be reshaped per-lesson client-side
  /// without a backend redeploy. Pass only the keys you want to change;
  /// the OpenAI session keeps the rest.
  ///
  /// Example for the Selene live gaze lesson:
  ///   updateSession({
  ///     'instructions': SeleneGaze.theLockPrompt,
  ///     'voice': 'shimmer',
  ///     'tools': SeleneGaze.tools,
  ///     'turn_detection': {'type': 'server_vad', 'create_response': false},
  ///   });
  void updateSession(Map<String, dynamic> sessionPatch) {
    _sendEvent({
      'type': 'session.update',
      'session': sessionPatch,
    });
  }

  /// Reply to a model-issued tool call with its result. The Realtime API
  /// requires two events: a `function_call_output` conversation item
  /// carrying the JSON output keyed by [callId], then a `response.create`
  /// so the model continues with the new information.
  void sendFunctionCallOutput({
    required String callId,
    required String output,
  }) {
    _sendEvent({
      'type': 'conversation.item.create',
      'item': {
        'type': 'function_call_output',
        'call_id': callId,
        'output': output,
      },
    });
    _sendEvent({'type': 'response.create'});
  }

  void _sendEvent(Map<String, dynamic> ev) {
    _ws?.sink.add(jsonEncode(ev));
  }

  // ─── Receive: parse OpenAI Realtime event types ────────────────────────

  void _onWsMessage(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      // Audio output — base64 PCM16 chunk. The GA `gpt-realtime` model
      // renamed these to `output_audio`; we accept both the new and the
      // legacy names so a model rename never silently drops her voice.
      case 'response.output_audio.delta':
      case 'response.audio.delta':
        final b64 = data['delta'] as String?;
        if (b64 != null) {
          try {
            final bytes = base64Decode(b64);
            _eventCtrl.add(RealtimeEvent.audioDelta(bytes));
          } catch (_) {}
        }
        break;

      // Her reply text streaming in — live caption as she speaks.
      case 'response.output_audio_transcript.delta':
      case 'response.audio_transcript.delta':
        final delta = data['delta'] as String?;
        if (delta != null) {
          _eventCtrl.add(RealtimeEvent.diabloTranscriptDelta(delta));
        }
        break;
      case 'response.output_audio_transcript.done':
      case 'response.audio_transcript.done':
        final transcript = data['transcript'] as String?;
        if (transcript != null) {
          _eventCtrl.add(RealtimeEvent.diabloTranscriptDone(transcript));
        }
        break;

      // The user's transcribed speech (Whisper inside the realtime model).
      case 'conversation.item.input_audio_transcription.completed':
        final transcript = data['transcript'] as String?;
        if (transcript != null) {
          _eventCtrl.add(RealtimeEvent.userTranscript(transcript));
        }
        break;

      // Response lifecycle.
      case 'response.created':
        _eventCtrl.add(const RealtimeEvent.responseStarted());
        break;
      case 'response.done':
        _eventCtrl.add(const RealtimeEvent.responseDone());
        break;

      // Server VAD detected the user started speaking — good signal to
      // duck Diablo's voice or stop her mid-sentence.
      case 'input_audio_buffer.speech_started':
        _eventCtrl.add(const RealtimeEvent.userSpeechStarted());
        break;
      case 'input_audio_buffer.speech_stopped':
        _eventCtrl.add(const RealtimeEvent.userSpeechStopped());
        break;

      // Tool-call from the model. The Realtime API streams the JSON
      // argument string in `response.function_call_arguments.delta`
      // and signals completion via `…done`. We surface only the
      // completed call so the UI can synchronously look up live
      // metrics + reply with `sendFunctionCallOutput`.
      case 'response.function_call_arguments.done':
        final name   = data['name']    as String?;
        final callId = data['call_id'] as String?;
        final args   = (data['arguments'] as String?) ?? '{}';
        if (name != null && callId != null) {
          _eventCtrl.add(RealtimeEvent.functionCall(name, callId, args));
        }
        break;

      // Errors from OpenAI.
      case 'error':
        final err = data['error'] as Map<String, dynamic>?;
        _eventCtrl.add(RealtimeEvent.error(
          (err?['code'] as String?) ?? 'unknown',
          (err?['message'] as String?) ?? raw,
        ));
        break;

      // Everything else (session.created, session.updated, …) — broadcast
      // raw for any future handling.
      default:
        _eventCtrl.add(RealtimeEvent.raw(type, data));
    }
  }

  // ─── Close ─────────────────────────────────────────────────────────────

  Future<void> close() async {
    _connected = false;
    await _sub?.cancel();
    await _ws?.sink.close();
    await _eventCtrl.close();
    _ws = null;
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  Typed events the UI consumes
// ──────────────────────────────────────────────────────────────────────────

sealed class RealtimeEvent {
  const RealtimeEvent();
  const factory RealtimeEvent.audioDelta(Uint8List pcm16leBytes) = AudioDelta;
  const factory RealtimeEvent.diabloTranscriptDelta(String delta) =
      DiabloTranscriptDelta;
  const factory RealtimeEvent.diabloTranscriptDone(String transcript) =
      DiabloTranscriptDone;
  const factory RealtimeEvent.userTranscript(String text) = UserTranscript;
  const factory RealtimeEvent.userSpeechStarted() = UserSpeechStarted;
  const factory RealtimeEvent.userSpeechStopped() = UserSpeechStopped;
  const factory RealtimeEvent.responseStarted() = ResponseStarted;
  const factory RealtimeEvent.responseDone() = ResponseDone;
  const factory RealtimeEvent.error(String code, String message) =
      RealtimeErrorEvent;
  const factory RealtimeEvent.closed() = SessionClosed;
  const factory RealtimeEvent.functionCall(
    String name,
    String callId,
    String argumentsJson,
  ) = FunctionCallRequested;
  const factory RealtimeEvent.raw(String type, Map<String, dynamic> data) =
      RawEvent;
}

class FunctionCallRequested extends RealtimeEvent {
  final String name;
  final String callId;
  final String argumentsJson;
  const FunctionCallRequested(this.name, this.callId, this.argumentsJson);
}

class AudioDelta extends RealtimeEvent {
  final Uint8List pcm16leBytes;
  const AudioDelta(this.pcm16leBytes);
}

class DiabloTranscriptDelta extends RealtimeEvent {
  final String delta;
  const DiabloTranscriptDelta(this.delta);
}

class DiabloTranscriptDone extends RealtimeEvent {
  final String transcript;
  const DiabloTranscriptDone(this.transcript);
}

class UserTranscript extends RealtimeEvent {
  final String text;
  const UserTranscript(this.text);
}

class UserSpeechStarted extends RealtimeEvent {
  const UserSpeechStarted();
}

class UserSpeechStopped extends RealtimeEvent {
  const UserSpeechStopped();
}

class ResponseStarted extends RealtimeEvent {
  const ResponseStarted();
}

class ResponseDone extends RealtimeEvent {
  const ResponseDone();
}

class RealtimeErrorEvent extends RealtimeEvent {
  final String code;
  final String message;
  const RealtimeErrorEvent(this.code, this.message);
}

class SessionClosed extends RealtimeEvent {
  const SessionClosed();
}

class RawEvent extends RealtimeEvent {
  final String type;
  final Map<String, dynamic> data;
  const RawEvent(this.type, this.data);
}

class RealtimeError implements Exception {
  final String code;
  final String message;
  const RealtimeError(this.code, this.message);
  @override
  String toString() => 'RealtimeError($code): $message';
}
