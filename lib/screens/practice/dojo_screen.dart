import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

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
class DojoScreen extends StatelessWidget {
  const DojoScreen({super.key});

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
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
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
                    const SizedBox(height: 6),
                    Text('THE DOJO',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 34,
                          height: 1,
                          letterSpacing: -0.5,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(height: 8),
                    Text(
                        'Ten laws. Every conversation in this app is a rep '
                        'on one of them. Learn them here — earn them in '
                        'the room.',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LawCard(index: i + 1, law: _laws[i])
                        .animate()
                        .fadeIn(delay: (60 * i).ms, duration: 300.ms)
                        .slideY(begin: 0.05, curve: Curves.easeOut),
                  ),
                  childCount: _laws.length,
                ),
              ),
            ),
            // The arsenal — every named tactic he's discovered (and the
            // silhouettes of the ones he hasn't) lives in the playbook.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                child: Material(
                  color: AppColors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/playbook');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.red.withValues(alpha: 0.45)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.style_rounded,
                            color: AppColors.red, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('THE ARSENAL',
                                  style: GoogleFonts.inter(
                                    color: AppColors.red,
                                    fontSize: 12,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w900,
                                  )),
                              const SizedBox(height: 3),
                              Text(
                                  'Every named tactic — the ones you\'ve '
                                  'earned, and the ones still waiting.',
                                  style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  )),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded,
                            color: AppColors.red, size: 18),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One law: number, name, the doctrine, and the line — the example set
/// like ammunition, tinted bar on the left, impossible to skim past.
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
