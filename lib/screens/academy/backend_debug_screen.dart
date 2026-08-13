import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/backend_config.dart';
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
    try {
      final res = await BackendService.client.functions.invoke(
        'score-voice',
        body: {'scenario': 'diagnostic', 'transcript': 'x'},
      );
      final err = res.data is Map ? (res.data as Map)['error'] : null;
      // "transcript too short" is the CORRECT answer here — it means the
      // function is live and authenticated.
      final reachable = err == 'transcript too short';
      _add('score-voice function', reachable,
          reachable ? 'live + authenticated' : '${res.data}');
    } catch (e) {
      _add('score-voice function', false, '$e');
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

    try {
      final res = await BackendService.client.functions.invoke(
        'score-chat',
        body: {'transcript': 'x', 'surface': 'diagnostic'},
      );
      final err = res.data is Map ? (res.data as Map)['error'] : null;
      // Same trick as score-voice: "too short" is the RIGHT answer — it
      // proves the function is deployed and authenticated us.
      final live = err == 'transcript too short';
      _add('score-chat function', live,
          live
              ? 'live + authenticated'
              : 'NOT DEPLOYED, or it rejected us. Deploy score-chat AND '
                  'battle-action together — they share roll-chat.ts. '
                  'Response: ${res.data}');
    } catch (e) {
      _add('score-chat function', false,
          'NOT DEPLOYED — supabase functions deploy score-chat ($e)');
    }

    // 8 — the grader's key. A deployed function with no OPENAI_API_KEY
    //     returns 503 and records nothing, which looks EXACTLY like "the
    //     score isn't saving" from the app side.
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
      _add('grader (OPENAI_API_KEY)', false, '$e');
    }

    if (mounted) setState(() => _running = false);
  }

  void _copy() {
    final text = _lines
        .map((l) => '${l.$2 ? "OK  " : "FAIL"}  ${l.$1}: ${l.$3}')
        .join('\n');
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
