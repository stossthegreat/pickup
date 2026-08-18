import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/backend_config.dart';
import '../../config/dev_flags.dart';
import '../../services/backend/auth_service.dart';
import '../../services/backend/backend_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/game_button.dart';

/// BACKEND DIAGNOSTIC — stop guessing why a surface says "needs a
/// connection". Runs the exact same calls the app makes and prints the
/// raw result of each one, in order, so the first red line IS the bug.
class BackendDebugScreen extends StatefulWidget {
  const BackendDebugScreen({super.key});

  @override
  State<BackendDebugScreen> createState() => _BackendDebugScreenState();
}

class _BackendDebugScreenState extends State<BackendDebugScreen> {
  final List<(String, bool, String)> _lines = []; // label, ok, detail
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _add(String label, bool ok, String detail) {
    if (!mounted) return;
    setState(() => _lines.add((label, ok, detail)));
  }

  /// CALL AN EDGE FUNCTION AND GET ITS ERROR STRING BACK, however it
  /// arrives.
  ///
  /// ── THE BUG THIS EXISTS TO KILL ──────────────────────────────────
  ///
  /// Every probe here works by sending a deliberately invalid payload
  /// and checking for the specific complaint a LIVE function would make
  /// — "transcript too short" proves the thing is deployed, reachable
  /// and authenticated us, without grading anything or writing a row.
  ///
  /// That was written as `res.data['error']`, which assumes the function
  /// answers 200 with an error in the body. It doesn't. It answers
  /// **400**, and the Supabase Dart client turns any non-2xx into a
  /// thrown FunctionException — so the happy path never ran, every probe
  /// fell into its catch block, and two perfectly healthy functions were
  /// reported as NOT DEPLOYED. The proof was printed on screen the whole
  /// time: the "failure" detail contained the exact string the check was
  /// looking for.
  ///
  /// So this reads both channels. Returned body first; failing that, the
  /// text of the exception, which carries the same `details` map. Match
  /// on substring rather than equality, because the thrown form arrives
  /// wrapped in FunctionException(status:…, details:{…}).
  Future<({String? error, String raw})> _probe(
    String fn,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await BackendService.client.functions.invoke(fn, body: body);
      final d = res.data;
      final err = d is Map ? d['error']?.toString() : null;
      return (error: err, raw: '$d');
    } catch (e) {
      return (error: '$e', raw: '$e');
    }
  }

  /// True when the function answered with the complaint we provoked —
  /// whichever channel it came back on.
  bool _said(({String? error, String raw}) r, String want) =>
      (r.error ?? '').contains(want);

  Future<void> _run() async {
    setState(() {
      _lines.clear();
      _running = true;
    });

    // 1 — is the SDK even initialised?
    _add('Supabase initialised', BackendService.enabled,
        BackendService.enabled ? BackendConfig.url : 'init failed at launch');
    if (!BackendService.enabled) {
      setState(() => _running = false);
      return;
    }

    // 2 — do we have an identity? This is the usual culprit: without
    //     Anonymous sign-ins enabled in the dashboard, there is no JWT
    //     and every function call comes back 401.
    try {
      await AuthService.ensureSignedIn();
    } catch (e) {
      _add('Sign-in threw', false, '$e');
    }
    final uid = AuthService.userId;
    _add(
      'Signed in',
      uid != null,
      uid ?? 'NO USER — enable Authentication > Providers > '
          'Anonymous sign-ins in the Supabase dashboard',
    );

    // 3 — can we read a plain table? (proves RLS + connectivity)
    try {
      final rows = await BackendService.client
          .from('missions')
          .select('id')
          .limit(1);
      _add('Read missions table', true, '${rows.length} row(s)');
    } catch (e) {
      _add('Read missions table', false, '$e');
    }

    // 4 — do the new tables exist? (proves migrations 0005/0006 ran)
    try {
      await BackendService.client.from('leagues').select('id').limit(1);
      _add('Leagues table exists', true, 'migration 0005 applied');
    } catch (e) {
      _add('Leagues table exists', false, '$e');
    }

    // 5 — THE function the Daily needs.
    try {
      final res = await BackendService.client.functions
          .invoke('daily-game', body: {'action': 'status'});
      final ok = res.data is Map && (res.data as Map)['error'] == null;
      _add('daily-game function', ok,
          ok ? 'OK — ${(res.data as Map)['scenarioKey']}' : '${res.data}');
    } catch (e) {
      _add('daily-game function', false, '$e');
    }

    // 6 — the scoring function (a deliberate short transcript: we only
    //     want to know whether it's reachable and keyed, not to score).
    {
      final r = await _probe(
          'score-voice', {'scenario': 'diagnostic', 'transcript': 'x'});
      // "transcript too short" is the CORRECT answer here — it means the
      // function is live and authenticated. It comes back as a 400, so
      // it arrives as a throw. See _probe.
      final reachable = _said(r, 'transcript too short');
      _add('score-voice function', reachable,
          reachable ? 'live + authenticated' : r.raw);
    }

    // 7 — THE CHAT LADDER, link by link.
    //
    // "The chat score still isn't saving" has been reported three times
    // and every answer has been "deploy the migrations", which is useless
    // if it's already been done. This walks the actual chain and names
    // the first broken link instead of guessing:
    //
    //   chat_attempts table  →  migration 0009 has run
    //   chat_score.points    →  migration 0010 has run
    //   chat_leaderboard     →  the view exists and is readable
    //   score-chat function  →  deployed AND has an OPENAI_API_KEY
    //
    // Whichever line reads FAIL first is the thing to fix. Nothing below
    // it can work until it does.
    try {
      await BackendService.client.from('chat_attempts').select('id').limit(1);
      _add('chat_attempts table', true, 'migration 0009 has run');
    } catch (e) {
      _add('chat_attempts table', false,
          'MISSING — run migration 0009. Nothing text-scored can save '
          'until this exists. ($e)');
    }

    try {
      await BackendService.client.from('chat_score').select('points').limit(1);
      _add('chat_score.points', true, 'migration 0010 has run');
    } catch (e) {
      _add('chat_score.points', false,
          'MISSING — run migration 0010 (Rizz Points). ($e)');
    }

    try {
      final rows = await BackendService.client
          .from('chat_leaderboard')
          .select()
          .limit(3);
      _add('chat_leaderboard view', true,
          '${rows.length} row(s) — the board reads fine');
    } catch (e) {
      _add('chat_leaderboard view', false, 'MISSING or unreadable. ($e)');
    }

    {
      final r =
          await _probe('score-chat', {'transcript': 'x', 'surface': 'diagnostic'});
      // Same trick as score-voice: "too short" is the RIGHT answer — it
      // proves the function is deployed and authenticated us.
      final live = _said(r, 'transcript too short');
      _add('score-chat function', live,
          live
              ? 'live + authenticated'
              : 'NOT DEPLOYED, or it rejected us. Deploy score-chat AND '
                  'battle-action together — they share roll-chat.ts. '
                  'Response: ${r.raw}');
    }

    // 7b — BATTLE-ACTION, AND WHICH VERSION OF IT.
    //
    // Deployed-but-stale is the failure nothing else here can see, and
    // it's the one that matters: the cancel action and the RR columns
    // both shipped in the same change, so an old copy answers every
    // call happily while the X on a challenge silently does nothing.
    //
    // `cancel` with no battle_id is the probe. It costs nothing and
    // never touches a row — it fails at the first argument check — but
    // WHICH complaint comes back names the version:
    //
    //   "battle_id required"  → current build, cancel + RR are live
    //   "unknown action"      → deployed, but before the cancel case
    {
      final r = await _probe('battle-action', {'action': 'cancel'});
      final current = _said(r, 'battle_id required');
      final stale = _said(r, 'unknown action');
      _add(
          'battle-action function',
          current,
          current
              ? 'live + current (cancel and RR are deployed)'
              : stale
                  ? 'DEPLOYED BUT STALE — this copy predates the cancel '
                      'action, so deleting a challenge does nothing and '
                      'battle_rating never gets written. Redeploy: '
                      'supabase functions deploy battle-action'
                  : 'NOT DEPLOYED, or it rejected us. Response: ${r.raw}');
    }

    // 8 — the grader's key. A deployed function with no OPENAI_API_KEY
    //     returns 503 and records nothing, which looks EXACTLY like "the
    //     score isn't saving" from the app side.
    // A missing key answers 503 "grader unavailable", which — like every
    // other non-2xx here — arrives as a throw rather than a body. Named
    // explicitly so the one condition this check exists to detect
    // doesn't get reported as a generic exception.
    try {
      final res = await BackendService.client.functions.invoke(
        'score-chat',
        body: {
          'transcript': 'YOU: hey what are you up to tonight\n'
              'HER: not much, you?\nYOU: deciding if you are worth '
              'the effort',
          'surface': 'diagnostic',
        },
      );
      final d = res.data;
      final scored = d is Map && d['score'] != null;
      _add('grader (OPENAI_API_KEY)', scored,
          scored
              ? 'scored ${(d as Map)['score']} — the whole chain works'
              : 'no score came back. If the function is live above, the '
                  'key is missing: supabase secrets set OPENAI_API_KEY=… '
                  'Response: $d');
    } catch (e) {
      final noKey = '$e'.contains('grader unavailable');
      _add('grader (OPENAI_API_KEY)', false,
          noKey
              ? 'NO KEY. The function is live but has no OPENAI_API_KEY, '
                  'so it grades nothing and records nothing — which looks '
                  'exactly like "the score isn\'t saving" from the app. '
                  'Fix: supabase secrets set OPENAI_API_KEY=sk-…'
              : '$e');
    }

    if (mounted) setState(() => _running = false);
  }

  void _copy() {
    // The build tag leads the paste for the same reason it's in the
    // header — a pasted report with no version can be read against the
    // wrong code, and has been.
    final text = [
      'build: $kBuildTag',
      ..._lines.map((l) => '${l.$2 ? "OK  " : "FAIL"}  ${l.$1}: ${l.$3}'),
    ].join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Copied — paste it into chat.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Column(children: [
          Row(children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.white),
            ),
            Text('BACKEND CHECK',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  letterSpacing: 2.6,
                  fontWeight: FontWeight.w900,
                )),
            const Spacer(),
            // WHICH BUILD PRODUCED THIS REPORT.
            //
            // A diagnostic screen with no version on it is a trap. A
            // fix landed in the probe logic, TestFlight took its time,
            // and the same two false reds got read as a live backend
            // failure — twice — because nothing on screen said the
            // report was coming from the old code. The tag is on the
            // paywall and in Settings; the one screen people actually
            // debug from was the one screen without it.
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(kBuildTag,
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                  )),
            ),
            if (_running)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.red)),
              ),
          ]),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              children: [
                for (final (label, ok, detail) in _lines)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: (ok ? kOk : AppColors.red)
                              .withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
                            size: 17, color: ok ? kOk : AppColors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  )),
                              const SizedBox(height: 3),
                              SelectableText(detail,
                                  style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Row(children: [
              Expanded(
                child: GameButton(
                  label: 'RUN AGAIN',
                  color: AppColors.surface2,
                  onTap: _running ? null : _run,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GameButton(label: 'COPY RESULT', onTap: _copy),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

const kOk = Color(0xFF2EE87A);
