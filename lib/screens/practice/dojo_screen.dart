import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../academy/tactics_screen.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE DOJO — the rules of the game
/// ══════════════════════════════════════════════════════════════════════
///
/// The pill on the Practice masthead opens this. It is NOT a lessons tab
/// (tactics are still discovered by doing, in-play — see tactics.dart);
/// it's the doctrine: the ten laws of seduction the whole app teaches,
/// each with a killer line he could use tonight. A man reads this in
/// three minutes, walks back into Practice, and plays differently.
///
/// The tone is the product: certain, masculine, a little dangerous,
/// never sleazy. Every law is true — it has to survive contact with a
/// real woman on a real Saturday, or it's out.
class DojoScreen extends StatefulWidget {
  const DojoScreen({super.key});

  @override
  State<DojoScreen> createState() => _DojoScreenState();
}

class _DojoScreenState extends State<DojoScreen> {
  /// 0 = the laws, 1 = the playbook. Both bodies stay mounted in an
  /// IndexedStack so switching is instant and the playbook keeps the
  /// collection it already loaded.
  int _tab = 0;

  static const _laws = <({String name, String law, String line})>[
    (
      name: 'SHE FEELS, SHE DOESN\'T AUDIT',
      law: 'Nobody was ever seduced by information. Stop reciting your '
          'CV and start changing how the room feels. She won\'t remember '
          'what you said — she\'ll remember that her pulse moved.',
      line: '"I was going to be charming and normal tonight but you\'ve '
          'ruined it, so now you get the real version."',
    ),
    (
      name: 'DESIRE, STATED, ONCE',
      law: 'Hints are homework you hand her. Say you want her — calm, '
          'plain, zero apology — then go straight back to the banter '
          'like you didn\'t just do that. The contrast is the move.',
      line: '"For the record, I\'m not being friendly. Anyway — you were '
          'saying?"',
    ),
    (
      name: 'TENSION IS THE PRODUCT',
      law: 'Comfort is for friends. The unresolved charge — does he, '
          'doesn\'t he, will they — is the entire chemistry of early '
          'attraction. Your job isn\'t to resolve it. It\'s to hold it '
          'one beat longer than feels safe.',
      line: '"You\'re dangerously my type. God, that\'s inconvenient."',
    ),
    (
      name: 'PLAY, DON\'T PERFORM',
      law: 'Auditioning kills it — she can smell a man trying to be '
          'picked. Tease her, build the bit with her, escalate the '
          'nonsense together. A woman who\'s co-writing the joke has '
          'already stopped judging you.',
      line: '"Pineapple on pizza. Unbelievable. We were doing so well."',
    ),
    (
      name: 'READ HER OUT LOUD',
      law: 'Questions make her work; a read makes her feel SEEN. Guess '
          'who she is and say it. Right is intimacy, wrong is her '
          'correcting you — both are a conversation with heat in it.',
      line: '"You\'ve got the face of someone who starts trouble and '
          'acts innocent when it lands."',
    ),
    (
      name: 'HOLD THE SILENCE',
      law: 'The silence after a bold line is where it lands. Explaining, '
          'softening, joking it away — that\'s you flinching first. Say '
          'it. Then hold. Nerve is the sexiest thing you can transmit.',
      line: '(Say the thing. Then let it sit. She felt it — let her.)',
    ),
    (
      name: 'FLIP THE FRAME',
      law: 'All night men chase her. Accuse HER of chasing YOU — light, '
          'obvious, grinning — and the thought is in her head wearing '
          'your name. Whoever\'s frame is on the table runs the night.',
      line: '"Stop looking at me like that, we\'re in public."',
    ),
    (
      name: 'YOU\'RE CHOOSING TOO',
      law: 'Whoever is proving themselves is the one chasing. Make her '
          'sell it — playfully, once — and the effort she spends '
          'winning you becomes real investment. People fall for what '
          'they worked for.',
      line: '"You\'re gorgeous, sure. Everyone\'s gorgeous. What else '
          'have you got?"',
    ),
    (
      name: 'NOTHING RATTLES YOU',
      law: 'She will test you — the knock, the cold shoulder, the '
          'curveball. Defending yourself proves it landed. Agree and '
          'raise. A man who turns her jab into his material, smiling, '
          'is a man she can\'t shake off.',
      line: '"Guilty. And I\'d do it again, slower, while you watched."',
    ),
    (
      name: 'CLOSE LIKE YOU MEAN IT',
      law: 'All the tension you build is a bill that comes due at the '
          'ask — and "we should hang out sometime" refunds it. Name '
          'the plan, the day, and that it\'s a date. Specific gets the '
          'girl. Vague gets a nice memory.',
      line: '"Thursday. That wine bar. Wear something you\'d want to be '
          'seen in — it\'s a date."',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── ONE back button for both tabs, always to Practice ──────
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 20, 0),
              child: Row(children: [
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.whatshot_rounded,
                    color: AppColors.red, size: 18),
              ]),
            ),
            // ── THE TOGGLE — two peers, not a buried link ──────────────
            // The playbook used to be a card at the BOTTOM of the laws,
            // which made it feel like a footnote to the Dojo rather than
            // the other half of it. Two rectangles at the top say what
            // this screen actually is: doctrine on one side, your
            // collection on the other.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Row(children: [
                Expanded(
                  child: _TabCard(
                    label: 'THE DOJO',
                    active: _tab == 0,
                    onTap: () {
                      if (_tab == 0) return;
                      HapticFeedback.selectionClick();
                      setState(() => _tab = 0);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TabCard(
                    label: 'THE PLAYBOOK',
                    active: _tab == 1,
                    onTap: () {
                      if (_tab == 1) return;
                      HapticFeedback.selectionClick();
                      setState(() => _tab = 1);
                    },
                  ),
                ),
              ]),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                sizing: StackFit.expand,
                children: [
                  _lawsBody(),
                  const TacticsScreen(embedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The ten laws. No masthead — the toggle above already names it.
  Widget _lawsBody() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      itemCount: _laws.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
                'Ten laws. Every conversation in this app is a rep on one '
                'of them. Learn them here — earn them in the room.',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                )),
          );
        }
        final k = i - 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _LawCard(index: k + 1, law: _laws[k])
              .animate()
              .fadeIn(delay: (40 * k).ms, duration: 280.ms)
              .slideY(begin: 0.05, curve: Curves.easeOut),
        );
      },
    );
  }
}

/// One half of the toggle. Red fill when it's the tab you're on, quiet
/// surface when it isn't — the same red the rest of the app uses for
/// "this is the live one".
class _TabCard extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabCard({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.red : AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.red : AppColors.divider,
              width: active ? 2 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: AppColors.red.withValues(alpha: 0.35),
                        blurRadius: 16),
                  ]
                : null,
          ),
          child: Text(label,
              style: GoogleFonts.inter(
                color: active ? Colors.white : AppColors.textSecondary,
                fontSize: 12.5,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w900,
              )),
        ),
      ),
    );
  }
}

class _LawCard extends StatelessWidget {
  final int index;
  final ({String name, String law, String line}) law;
  const _LawCard({required this.index, required this.law});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surface3, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(index.toString().padLeft(2, '0'),
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(law.name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14.5,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                      )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(law.law,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: const Border(
                  left: BorderSide(color: AppColors.red, width: 3)),
            ),
            child: Text(law.line,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
  }
}
