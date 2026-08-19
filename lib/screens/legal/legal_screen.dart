import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

// App Store guideline 2.3.10 — strip cross-platform billing
// references from the iOS binary. These small helpers keep the
// legal copy below readable while still rendering only the
// platform-relevant phrasing on each build.
String get _storeAccount       => Platform.isIOS ? 'App Store account'
                                                 : 'Google Play account';
String get _appleOrGoogleId    => Platform.isIOS ? 'Apple ID'
                                                 : 'Google Play account';
String get _storeName          => Platform.isIOS ? 'App Store'
                                                 : 'Google Play';
String get _platformAppleStore => Platform.isIOS ? 'Apple'
                                                 : 'Google';

/// Legal screens — Terms of Use + Privacy Policy. Rendered in-app so
/// Apple App Review can reach them directly from the paywall and the
/// settings menu without touching a web link.
///
/// Content is intentionally plain-English and comprehensive. Apple's
/// review team penalises walls of unreadable legalese; the important
/// clauses (subscription auto-renewal, cancellation path, exactly what
/// data we collect and where it goes) are surfaced in their own headed
/// sections so a reviewer can tick them off.
class LegalScreen extends StatelessWidget {
  final LegalDoc doc;
  const LegalScreen({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                children: [
                  for (final b in doc.sections) ...[
                    Text(b.title,
                      style: GoogleFonts.inter(
                        color: AppColors.red,
                        fontSize: 11, letterSpacing: 2.6,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(b.body,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 14, height: 1.55,
                        fontWeight: FontWeight.w400)),
                    const SizedBox(height: 22),
                  ],
                  const SizedBox(height: 12),
                  Text(doc.lastUpdatedLine,
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 11, letterSpacing: 1.4,
                      fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 16),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                context.pop();
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface1, shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider, width: 0.8),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 14, color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.title,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 24, height: 1,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(doc.subtitle,
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 9, letterSpacing: 2.4,
                    fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CONTENT
//
//  These documents are kept in source because (a) the app has no live
//  backend doc-fetching, (b) Apple reviewers need to find the same text
//  every time they check, (c) content changes ship with app updates
//  anyway. Plain English. No jargon. Auto-renewal + cancellation are
//  called out in dedicated sections so App Review ticks the box on
//  first pass.
//
//  ImHim is an AI roleplay + dating-coach app (OpenAI voice + text
//  roleplay, plus rizz coaching). There is NO face scanning, no photo
//  analysis, and no biometric processing — these documents describe the
//  AI-conversation product only.
// ═══════════════════════════════════════════════════════════════════════════

class LegalSection {
  final String title;
  final String body;
  const LegalSection(this.title, this.body);
}

class LegalDoc {
  final String title;
  final String subtitle;
  final String lastUpdatedLine;
  final List<LegalSection> sections;
  const LegalDoc({
    required this.title,
    required this.subtitle,
    required this.lastUpdatedLine,
    required this.sections,
  });
}

LegalDoc get termsDoc => LegalDoc(
  title: 'Terms of Use',
  subtitle: 'IMHIM · THE AGREEMENT',
  lastUpdatedLine: 'Last updated 19 August 2026.',
  sections: [
    const LegalSection('SUMMARY — THE WHOLE THING IN TEN LINES',
      'This summary is for convenience only. The full sections below '
      'govern, and you should read them.\n\n'
      '• ImHim is an AI practice app for social confidence and dating '
      'conversation. Everything the characters and the coach say is '
      'generated by AI. They are not real people.\n'
      '• You must be 17 or over. Creator Mode is 18+.\n'
      '• ImHim Pro is an auto-renewing weekly subscription. It renews '
      'until you cancel it in your store settings. Deleting the app '
      'does not cancel it.\n'
      '• You can play anonymously. If you sign in with Apple or '
      'Google, that creates a durable account you can delete from '
      'inside the app at any time.\n'
      '• Squads, duels and leaderboards show your chosen call-sign and '
      'your scores to other users. Choose a call-sign accordingly.\n'
      '• Harassment, abuse and objectionable content are not tolerated. '
      'Report it in-app or by email and we act within 24 hours.\n'
      '• ImHim is entertainment and self-improvement. It is not '
      'therapy, medical advice, or a licence to ignore anybody\'s '
      'boundaries in the real world.\n'
      '• Nothing you earn in the app — XP, streaks, rank, badges — has '
      'any cash value.'),

    // TOP-OF-TERMS subscription disclosure. Carries every detail Apple
    // 3.1.2 requires (plain-English summary, price, renewal, cancel
    // path, what's unlocked) so the paywall itself can stay clean while
    // all required specifics remain one tap away at the very top.
    LegalSection('IMHIM PRO — WHAT YOU GET, PRICE & AUTO-RENEWAL',
      'ImHim Pro is a single auto-renewing weekly subscription. This '
      'section is the full disclosure of what you pay, how billing '
      'renews, how to cancel, and exactly what the subscription unlocks '
      '— the same details presented at the point of purchase.\n\n'
      'PRICE & BILLING\n\n'
      '• ImHim Pro — \$6.99 USD per week (or the local-currency '
      'equivalent shown on the paywall), billed weekly.\n'
      '• Payment is charged to your $_appleOrGoogleId at confirmation '
      'of purchase.\n'
      '• The subscription automatically renews for one more week at the '
      'same price unless you cancel at least 24 hours before the '
      'current week ends.\n'
      '• Your account is charged for the renewal within 24 hours of the '
      'period ending.\n'
      '• You can manage or cancel the subscription at any time in your '
      '$_appleOrGoogleId settings. Uninstalling the app does NOT '
      'cancel the subscription.\n\n'
      'WHAT THE SUBSCRIPTION UNLOCKS\n\n'
      'An active ImHim Pro subscription unlocks the full app:\n\n'
      '• 14 minutes of live AI voice roleplay every week — about seven '
      '2-minute sessions — with any character.\n'
      '• Unlimited AI text roleplay with every character.\n'
      '• Unlimited rizz coaching — dating-screenshot breakdowns, the AI '
      'chat coach, and generated openers / pickup lines.\n'
      '• All daily missions, streaks, and progress tracking.\n'
      '• Squads, duels, the daily challenge and the leaderboards.\n\n'
      'Cancel anytime in your $_storeName settings; access continues '
      'until the end of the paid week. No refund is issued for the '
      'unused portion of the current period.'),

    LegalSection('EXTRA VOICE MINUTES — ONE-OFF PURCHASES',
      'Separately from the subscription, ImHim may offer one-off '
      'purchases of additional live voice minutes (for example a '
      '10-minute or 20-minute top-up) at the price shown at the point '
      'of purchase.\n\n'
      '• These are CONSUMABLE purchases. They are used up as you spend '
      'the minutes and are not restored if you reinstall the app or '
      'move to a new device, because there is nothing left to restore '
      'once the minutes are spent.\n'
      '• They do not renew and they are not a subscription. Buying one '
      'does not change or extend your ImHim Pro billing in any way.\n'
      '• Purchased minutes are added to your available balance and are '
      'spent only when you are actually in a live voice session.\n'
      '• Unspent minutes do not expire on a timer, but they have no '
      'cash value, cannot be transferred to another person or account, '
      'and cannot be exchanged for money.\n'
      '• Payment is charged to your $_appleOrGoogleId at confirmation '
      'of purchase. Refunds, where offered, are handled by '
      '$_platformAppleStore directly, not by ImHim.'),

    const LegalSection('ABOUT IMHIM',
      'ImHim is an AI-powered social-skills and dating-confidence '
      'coach. You practise real conversations with fictional AI '
      'characters — out loud using your microphone (live voice roleplay '
      'powered by the OpenAI Realtime API), or by text (AI text '
      'roleplay powered by OpenAI). A coaching layer gives you feedback '
      'and the exact lines to try next. The Texts / Rizz surface helps '
      'you with real dating-app conversations: paste a screenshot for a '
      'breakdown, ask the AI chat coach anything, or generate an opener. '
      'Daily missions turn the practice into a habit.\n\n'
      'ImHim also has a social layer. You can join a small squad of '
      'other users, take the same daily challenge they take, and enter '
      'duels against other users in which you both talk to the same AI '
      'character and the better conversation wins. Scores appear on '
      'leaderboards.\n\n'
      'ImHim is an entertainment and self-improvement tool. It is not '
      'therapy, not medical or psychological advice, and not a '
      'substitute for professional guidance. The AI characters are '
      'fictional — they are not real people and their replies are '
      'AI-generated. ImHim does not scan your face, analyse your '
      'appearance, or process any biometric data.'),

    const LegalSection('WHO CAN USE THIS APP',
      'You must be at least 17 years old to use ImHim. The app contains '
      'mature themes (flirting, dating, and suggestive conversation). '
      'By using ImHim you confirm you meet this age requirement. '
      'Creator Mode (see below) is intended for adults (18+).\n\n'
      'You also confirm that:\n\n'
      '• You have the legal capacity to enter into this agreement, or '
      'you have the consent of a parent or guardian where your local '
      'law requires it.\n'
      '• You are not barred from using the app under the laws of your '
      'country or under any applicable sanctions or export rules (see '
      'EXPORT CONTROL below).\n'
      '• You have not previously had an ImHim account terminated for '
      'abuse of other users.\n\n'
      'One person, one account. Do not share your account, sell it, or '
      'let another person use it to enter squads or duels as you.'),

    const LegalSection('YOUR ACCOUNT',
      'ImHim gives you an account automatically the first time you open '
      'it, without asking for anything. That first account is '
      'ANONYMOUS: it holds no name, no email and no phone number, only '
      'a random identifier, so the app can save your progress and put '
      'you in a squad.\n\n'
      'CLAIMING IT\n\n'
      'You may optionally claim that account using Sign in with Apple '
      'or Sign in with Google. Claiming is what makes your progress '
      'survive a lost or replaced phone. When you claim an account, the '
      'sign-in provider gives us an email address associated with it. '
      'You can use Apple\'s Hide My Email if you would rather we never '
      'see your real one — the app works identically either way.\n\n'
      'YOUR CALL-SIGN\n\n'
      'Your account carries a short call-sign (for example WOLF-482) '
      'which is generated for you and which you can change. Your '
      'call-sign is VISIBLE TO OTHER USERS on leaderboards, in squads '
      'and in duels. Do not put your real name, contact details, or '
      'anything you would not want a stranger to read into it, and do '
      'not choose one that impersonates somebody else or breaks the '
      'community rules below.\n\n'
      'YOU ARE RESPONSIBLE FOR YOUR ACCOUNT\n\n'
      'Keep control of the Apple or Google account you signed in with. '
      'Anything done through your ImHim account is treated as done by '
      'you. Tell us at info@m2mb.co.uk if you believe someone else has '
      'access to it.'),

    LegalSection('DELETING YOUR ACCOUNT',
      'You can delete your account and its data from inside the app at '
      'any time. There is no form to fill in, no email to send, and no '
      'retention period you have to wait out.\n\n'
      'HOW\n\n'
      'Settings → Delete my account. You will be asked to confirm, '
      'because it cannot be undone.\n\n'
      'WHAT IS DELETED\n\n'
      '• Your account record and the identifier behind it.\n'
      '• Your profile, including your call-sign, and the email address '
      'associated with the sign-in if you claimed the account.\n'
      '• Your on-device progress, streaks, mission state, saved '
      'conversations and settings.\n'
      '• Your membership of any squad, and your rows on the score '
      'tables and leaderboards.\n\n'
      'WHAT MAY REMAIN, AND WHY\n\n'
      '• Records of a completed duel may retain the fact that a duel '
      'happened and its result, with your identity removed, because '
      'the other player has a legitimate interest in their own match '
      'history remaining intact.\n'
      '• Purchase and billing records held by '
      '$_platformAppleStore are held by them, not by us, and are '
      'governed by their terms. Deleting your ImHim account does NOT '
      'cancel an active subscription — cancel that separately in your '
      '$_appleOrGoogleId settings.\n'
      '• Anonymised, aggregated statistics that cannot be linked back '
      'to you may be retained.\n\n'
      'Deleting the app WITHOUT deleting your account removes the '
      'on-device data but leaves the account itself in place, so that '
      'you can sign back in and recover your run. If you want it gone, '
      'delete the account first, then delete the app.'),

    const LegalSection('AI-GENERATED CONTENT — NATURE & LIMITS',
      'Every character reply, coach note, suggested line, pickup '
      'opener, and score in ImHim is generated by artificial '
      'intelligence. AI output can be inaccurate, inappropriate for '
      'your situation, biased, or repetitive, and it does not represent '
      'the views of ImHim. You are responsible for how you use it.\n\n'
      'IN PARTICULAR\n\n'
      '• The characters are FICTIONAL. They are not people, they have '
      'no feelings, and nothing that works on them is guaranteed to '
      'work on a person.\n'
      '• Scores are an AI\'s opinion of one conversation. They are for '
      'practice and comparison inside the app. They are not a '
      'measurement of your worth, your attractiveness, or your ability.\n'
      '• Do not rely on ImHim output for legal, medical, psychological, '
      'financial, or safety decisions.\n'
      '• Real people are under no obligation to respond the way an AI '
      'character does. Always use judgement and respect other people\'s '
      'boundaries and consent in the real world.\n\n'
      'If the AI ever produces something you believe is genuinely '
      'harmful or breaches the rules below, report it — see REPORTING '
      'AND ENFORCEMENT.'),

    LegalSection('SUBSCRIPTIONS & AUTO-RENEWAL',
      'ImHim offers an auto-renewing subscription:\n\n'
      '• ImHim Pro Weekly — \$6.99 USD per week (or local equivalent), '
      'billed weekly until cancelled.\n\n'
      'This subscription unlocks every ImHim Pro feature — 14 minutes of AI '
      'voice roleplay per week (about seven 2-minute sessions), unlimited AI '
      'text roleplay, unlimited rizz coaching, and all missions and progress '
      'tracking.\n\n'
      'Subscription terms:\n\n'
      '• Payment is charged to your $_appleOrGoogleId at confirmation '
      'of purchase.\n'
      '• Your subscription automatically renews for the same term at '
      'the same price unless you cancel at least 24 hours before the '
      'current period ends.\n'
      '• Your account is charged for renewal within 24 hours of the '
      'period ending.\n'
      '• You can manage or cancel subscriptions in your '
      '$_appleOrGoogleId settings at any time. Uninstalling the app '
      'does NOT cancel the subscription.\n'
      '• Any unused portion of a free trial period, if one is offered, '
      'is forfeited when you purchase a subscription.\n'
      '• No refund is issued for the unused portion of the current '
      'period. Refunds, where offered, are handled by '
      '$_platformAppleStore directly, not by ImHim.\n'
      '• If we change the price, you will be told before it takes '
      'effect and it will not apply to the period you have already '
      'paid for. Continuing after that is acceptance of the new price; '
      'if you do not accept it, cancel before the next renewal.'),

    const LegalSection('PROGRESS HAS NO CASH VALUE',
      'XP, streaks, rank, divisions, badges, trophies, leaderboard '
      'positions, win records and voice minutes are features of the '
      'app, not property and not currency.\n\n'
      '• They have no monetary value and cannot be exchanged for money, '
      'goods or services outside ImHim.\n'
      '• They cannot be sold, traded, gifted or transferred to another '
      'person or account, and any attempt to do so may result in '
      'termination.\n'
      '• We may adjust, reset or recalculate them where it is necessary '
      'to fix a bug, correct an exploit, or keep competition fair. '
      'Where a change is significant and not the result of cheating, we '
      'will say so in the app.\n'
      '• Purchased voice minutes are the one thing you paid real money '
      'for. Those are only ever removed by you spending them, or by '
      'termination for a serious breach of these terms.'),

    const LegalSection('OTHER USERS — SQUADS, DUELS & LEADERBOARDS',
      'ImHim is partly a social app, and this section tells you exactly '
      'what other people see.\n\n'
      'WHAT OTHERS CAN SEE\n\n'
      '• Your call-sign.\n'
      '• Your scores, your streak, your daily results, and your '
      'win/loss record.\n'
      '• Whether you completed or skipped today\'s missions, if you are '
      'in a squad. That is the entire point of a squad — going quiet is '
      'meant to be visible to the people holding you to it.\n\n'
      'WHAT OTHERS NEVER SEE\n\n'
      '• Your real name, your email address, or your phone number.\n'
      '• The content of your roleplay conversations, your coach '
      'messages, or any screenshot you upload.\n'
      '• Anything from Creator Mode.\n\n'
      'DUELS AGAINST STRANGERS\n\n'
      'You can enter a duel against another user by sharing a code, or '
      'by joining an open queue that pairs you with someone you do not '
      'know. In a duel you each talk to the same AI character '
      'separately; you are not put into direct contact with each other, '
      'and neither of you sees the other\'s conversation. Only the '
      'result is shared.\n\n'
      'LEAVING\n\n'
      'You can leave a squad at any time from inside the app. Leaving '
      'removes you from that squad\'s board.'),

    const LegalSection('COMMUNITY RULES — ZERO TOLERANCE',
      'ImHim has ZERO TOLERANCE for objectionable content and for '
      'abusive users. This applies to anything another user can see — '
      'principally your call-sign and your squad name — and to your '
      'conduct toward other users.\n\n'
      'THE FOLLOWING ARE PROHIBITED OUTRIGHT\n\n'
      '• Harassment, bullying, threats, intimidation or stalking of '
      'any person.\n'
      '• Hate speech, slurs, or content attacking or demeaning people '
      'on the basis of race, ethnicity, national origin, religion, '
      'caste, sex, gender, gender identity, sexual orientation, '
      'disability, age or serious disease.\n'
      '• Anything that sexualises a minor, in any form, in any part of '
      'the app, including in a call-sign, a squad name, or an attempt '
      'to steer an AI character. This results in immediate and '
      'permanent termination and, where required by law, a report to '
      'the relevant authorities.\n'
      '• Sexually explicit or pornographic call-signs, squad names or '
      'display content.\n'
      '• Content promoting or instructing self-harm, suicide, eating '
      'disorders, or real-world violence.\n'
      '• Content promoting or instructing coercion, sexual assault, '
      'drugging, non-consensual acts, or the circumvention of another '
      'person\'s refusal.\n'
      '• Impersonating another person, a real public figure, or ImHim '
      'staff.\n'
      '• Doxxing — publishing anyone\'s real name, address, workplace, '
      'phone number, or other private information.\n'
      '• Spam, advertising, scams, phishing, or links to any of them.\n'
      '• Illegal content or content promoting illegal activity.\n\n'
      'THIS IS NOT A NEGOTIATION\n\n'
      'By using ImHim you agree to these rules, and you agree that we '
      'may remove content and remove users who break them, without '
      'notice and without refund.'),

    const LegalSection('REPORTING & ENFORCEMENT',
      'HOW TO REPORT\n\n'
      'If you see a call-sign, a squad name, an AI output, or the '
      'behaviour of another user that breaks the rules above:\n\n'
      '• Email info@m2mb.co.uk with the word REPORT in the subject '
      'line, and tell us what you saw and where. A screenshot helps.\n'
      '• If it concerns someone in your squad, you can also simply '
      'leave the squad immediately — you do not need our permission '
      'and you do not need to explain yourself to anyone.\n\n'
      'WHAT WE DO, AND HOW FAST\n\n'
      '• We aim to acknowledge every report within 24 hours.\n'
      '• We remove content that breaks the rules and we remove the '
      'users responsible. Objectionable call-signs and squad names are '
      'removed as soon as they are found.\n'
      '• Content that sexualises minors is actioned immediately on '
      'discovery, results in permanent termination, and is reported to '
      'the relevant authorities where the law requires it.\n'
      '• We may act on our own initiative, without a report, where we '
      'become aware of a breach.\n\n'
      'BLOCKING AND LEAVING\n\n'
      'ImHim deliberately does not provide direct messaging between '
      'users, so there is no channel through which one user can send '
      'you anything. Where you no longer wish to be grouped with '
      'someone, leaving the squad removes the connection entirely and '
      'takes effect at once. If a specific user is targeting you '
      'across squads or duels, email us and we will block them from '
      'being matched with you.\n\n'
      'APPEALS\n\n'
      'If you believe enforcement action against you was a mistake, '
      'email info@m2mb.co.uk and we will review it. We do not reinstate '
      'accounts terminated for content involving minors.'),

    const LegalSection('CONSENT & REAL-WORLD CONDUCT',
      'This section is not boilerplate. Read it.\n\n'
      'ImHim exists to help you become someone who can hold a '
      'conversation, handle rejection, and approach people without '
      'falling apart. It does not exist to help you get past somebody\'s '
      '"no", and it will not be used that way.\n\n'
      '• Consent is required, it must be freely given, and it can be '
      'withdrawn at any moment for any reason or none. A person who has '
      'stopped responding, changed the subject, walked away, or said no '
      'has communicated their answer.\n'
      '• Persistence is not a technique. Nothing in this app authorises '
      'you to pressure, wear down, follow, repeatedly contact, or '
      'manipulate any person who has indicated they are not interested.\n'
      '• Do not use anything you learn here to deceive someone about '
      'who you are, your intentions, your relationship status, or '
      'anything else material to their decision.\n'
      '• The AI characters are written to respond to practice. They '
      'have no boundaries to violate. Real people do, and the '
      'difference is the entire point of the exercise.\n\n'
      'Using ImHim in connection with harassment, stalking, coercion or '
      'any sexual offence is a fundamental breach of these terms and '
      'will result in immediate permanent termination. Nothing in this '
      'agreement limits your liability under the criminal law of your '
      'country.'),

    const LegalSection('NO PROFESSIONAL ADVICE',
      'ImHim is a coaching-style entertainment product. It does not '
      'provide medical, psychological, therapeutic, legal, or '
      'relationship-counselling advice, and nothing in the app creates '
      'a professional relationship.\n\n'
      'The app is deliberately built around streaks, daily targets and '
      'social accountability, because that is what makes practice '
      'stick. It is not built to be a source of self-worth. If using it '
      'is making you feel worse rather than more capable, stop using '
      'it.\n\n'
      'If you are struggling with your mental health, please contact a '
      'qualified professional. If you are in crisis or thinking about '
      'harming yourself, contact your local emergency services or a '
      'crisis line in your country immediately — in the US and Canada '
      'call or text 988, in the UK and Ireland call 116 123 '
      '(Samaritans), and elsewhere see findahelpline.com. ImHim is not '
      'a crisis service and cannot help you in an emergency.'),

    const LegalSection('YOUR CONTENT',
      'You keep all rights to the messages you type and the screenshots '
      'you choose to upload. By sending them in the app you grant ImHim '
      'a limited, revocable, royalty-free licence to process that '
      'content — on your device and by transmitting it to our AI '
      'provider (OpenAI) — solely to produce the coaching, roleplay '
      'replies, and suggestions you asked for. That licence ends when '
      'the processing does. We do not sell your content and we do not '
      'train AI models on it.\n\n'
      'AI OUTPUT\n\n'
      'As between you and ImHim, you may use the lines, breakdowns and '
      'suggestions the AI produces for you freely, including in your '
      'own real conversations. We make no claim of ownership over them '
      'and we give no warranty that they are original, accurate or '
      'suitable — AI output can resemble output given to another user '
      'from a similar prompt.'),

    const LegalSection('AI DATA PERMISSION',
      'Before any of your content (voice, text, or a screenshot) is '
      'sent to our AI provider, ImHim asks for your permission through '
      'an in-app consent dialog that explains what is sent and to whom. '
      'You must agree for the feature to work; declining keeps your '
      'content on your device and the AI feature stays off. You can '
      'revoke this permission at any time in Settings → Revoke AI '
      'permission.'),

    const LegalSection('ACCEPTABLE USE',
      'You agree to use ImHim lawfully and respectfully. In addition to '
      'the COMMUNITY RULES above:\n\n'
      '• Only upload screenshots of conversations you are personally '
      'part of. Do not submit other people\'s private messages, images, '
      'or personal information that you have no right to share.\n'
      '• Do not use ImHim, or any line it generates, to harass, stalk, '
      'threaten, deceive, defame, or abuse any person.\n'
      '• Do not attempt to make the AI produce content that sexualises '
      'minors, promotes real-world violence or self-harm, or otherwise '
      'violates the law or the App Store / Google Play content '
      'policies.\n'
      '• Do not attempt to reverse-engineer, decompile, scrape, resell, '
      'automate, or overload the service, and do not use bots, '
      'emulators or modified clients against other users.\n'
      '• Do not cheat. That includes falsifying scores, manipulating '
      'streaks or leaderboards, farming duels with accounts you '
      'control, and exploiting bugs instead of reporting them.\n'
      '• Do not use ImHim to build, train, or benchmark another AI '
      'product.\n'
      '• Do not use the app where doing so would break the law where '
      'you are.'),

    const LegalSection('CREATOR MODE',
      'Settings → CREATOR is a password-gated, off-by-default switch '
      'that swaps the AI characters and the coach into a sharper, less '
      'filtered persona. It is intended for adult users (18+) who want '
      'a blunter tone.\n\n'
      'Even when CREATOR is ON, the underlying OpenAI content-policy '
      'guardrails are enforced by the provider: no sexually explicit '
      'content involving minors, no instructions for real-world '
      'harassment, coercion, or harm, and no targeting of protected '
      'groups. Output stays within OpenAI\'s and the App Store / Google '
      'Play content policies. CREATOR is OFF until you explicitly enter '
      'the password, only affects the device you enable it on, and can '
      'be re-locked at any time by turning it off or deleting the app.\n\n'
      'Creator Mode changes tone. It does not change the COMMUNITY '
      'RULES, the CONSENT section, or anything else in this agreement, '
      'and it is not a defence to a breach of them.'),

    LegalSection('TERMINATION',
      'BY YOU\n\n'
      'You may stop using ImHim at any time. Delete your account in '
      'Settings → Delete my account, and cancel any subscription '
      'separately in your store settings.\n\n'
      'BY US\n\n'
      'We may suspend or terminate your access, with or without notice '
      'depending on severity, if you breach these terms, harm or '
      'endanger another user, or use the app unlawfully. For serious '
      'breaches — content involving minors, harassment, threats, or '
      'using the app in connection with a sexual offence — termination '
      'is immediate and permanent.\n\n'
      'WHAT HAPPENS TO WHAT YOU PAID\n\n'
      'Termination for a breach of these terms does not entitle you to '
      'a refund of a subscription period or of purchased voice minutes. '
      'If we discontinue the app or terminate your access for reasons '
      'that are not your fault, we will not charge you again and you '
      'may seek a refund of an unused period through '
      '$_platformAppleStore.\n\n'
      'Sections which by their nature should survive termination — '
      'including YOUR CONTENT, DISCLAIMERS & LIABILITY, INDEMNITY, and '
      'GOVERNING LAW — survive it.'),

    const LegalSection('SERVICE AVAILABILITY & CHANGES',
      'ImHim depends on third-party services, principally OpenAI, and '
      'on your own network. We do not guarantee that the app will be '
      'available without interruption or free of errors.\n\n'
      '• Features may change, and features may be added or removed. '
      'Where we remove something material that your paid subscription '
      'relied on, we will tell you inside the app before the change '
      'takes effect.\n'
      '• Live voice roleplay in particular can be interrupted by your '
      'connection or by our provider. Where a session fails through no '
      'fault of yours, we aim not to charge the minutes against your '
      'balance, but we cannot guarantee it in every case.\n'
      '• We may impose reasonable limits to prevent abuse or to keep '
      'the service running for everyone.'),

    const LegalSection('DISCLAIMERS & LIABILITY',
      'ImHim is provided "as is" and "as available" without warranty of '
      'any kind, express or implied, including any implied warranty of '
      'merchantability, fitness for a particular purpose, '
      'non-infringement, or any warranty that AI output will be '
      'accurate, appropriate, original, or effective, or that using the '
      'app will improve your social life or your results with any '
      'person.\n\n'
      'To the maximum extent permitted by law:\n\n'
      '• ImHim is not liable for indirect, incidental, special, '
      'consequential or punitive damages, or for lost profits, lost '
      'data, or loss of goodwill.\n'
      '• ImHim is not liable for the conduct of any other user, or for '
      'what any real person does or does not do in response to '
      'something you said.\n'
      '• ImHim\'s total aggregate liability for any and all claims is '
      'limited to the greater of the amount you paid ImHim in the '
      'twelve months preceding the claim, or ten US dollars.\n\n'
      'Some jurisdictions do not allow the exclusion of certain '
      'warranties or the limitation of certain damages. Where that is '
      'the case, the exclusions and limits above apply only to the '
      'extent permitted, and nothing in these terms excludes liability '
      'for death or personal injury caused by negligence, for fraud, or '
      'for anything else that cannot lawfully be excluded. If you are a '
      'consumer, you keep the statutory rights your local law gives '
      'you, and nothing here overrides them.'),

    const LegalSection('INDEMNITY',
      'You agree to indemnify and hold harmless ImHim, its operator and '
      'its personnel from any claim, demand, loss or expense (including '
      'reasonable legal fees) arising out of your breach of these '
      'terms, your misuse of the app, content you uploaded that you had '
      'no right to upload, or your conduct toward any other person in '
      'connection with the app. This does not apply to the extent the '
      'claim arises from our own breach or negligence, and it does not '
      'apply where your local consumer law prohibits it.'),

    const LegalSection('GOVERNING LAW & DISPUTES',
      'These terms are governed by the laws of England and Wales, '
      'without regard to conflict-of-law rules, and the courts of '
      'England and Wales have jurisdiction.\n\n'
      'IF YOU ARE A CONSUMER\n\n'
      'Nothing in this section deprives you of the protection of the '
      'mandatory consumer law of the country where you live, or of your '
      'right to bring proceedings in your local courts where your law '
      'gives you that right.\n\n'
      'TALK TO US FIRST\n\n'
      'Most problems are a bug or a misunderstanding. Before starting '
      'any formal proceedings, email info@m2mb.co.uk describing the '
      'issue and what you want done about it, and give us 30 days to '
      'resolve it. This is a request, not a bar to your legal rights.\n\n'
      'Claims must be brought individually. You and ImHim each agree '
      'not to bring a class or representative action, to the extent '
      'your local law permits that agreement.'),

    const LegalSection('APPLE & GOOGLE — REQUIRED TERMS',
      'The following applies where you obtained ImHim from the Apple '
      'App Store, and the equivalent applies to Google Play.\n\n'
      '• This agreement is between YOU and IMHIM ONLY, not with Apple. '
      'Apple is not responsible for the app or its content.\n'
      '• Your licence to use ImHim is a non-transferable licence to use '
      'it on any Apple-branded device you own or control, as permitted '
      'by the App Store Terms of Service.\n'
      '• Apple has NO obligation whatsoever to furnish any maintenance '
      'or support services for ImHim.\n'
      '• If ImHim fails to conform to any applicable warranty, you may '
      'notify Apple, and Apple will refund the purchase price. To the '
      'maximum extent permitted by law, Apple has no other warranty '
      'obligation of any kind with respect to ImHim.\n'
      '• ImHim, not Apple, is responsible for addressing any claim by '
      'you or a third party relating to the app, including product '
      'liability claims, any claim that the app fails to conform to a '
      'legal or regulatory requirement, and claims arising under '
      'consumer protection or privacy law.\n'
      '• ImHim, not Apple, is solely responsible for the investigation, '
      'defence, settlement and discharge of any third-party claim that '
      'the app infringes that third party\'s intellectual property '
      'rights.\n'
      '• You represent that you are not located in a country subject to '
      'a US Government embargo or designated as a "terrorist '
      'supporting" country, and that you are not on any US Government '
      'list of prohibited or restricted parties.\n'
      '• Apple and Apple\'s subsidiaries are THIRD-PARTY BENEFICIARIES '
      'of this agreement, and upon your acceptance of it Apple has the '
      'right (and is deemed to have accepted the right) to enforce it '
      'against you as a third-party beneficiary.\n'
      '• ImHim\'s contact details for any question, complaint or claim '
      'relating to the app are set out under CONTACT below.'),

    const LegalSection('EXPORT CONTROL',
      'ImHim may be subject to export control and sanctions laws, '
      'including those of the United States, the United Kingdom and the '
      'European Union. You may not use, export, or re-export the app '
      'where doing so would breach those laws, and you confirm you are '
      'not located in, or ordinarily resident in, a country or region '
      'subject to comprehensive sanctions, and are not a person or '
      'entity designated on an applicable restricted-party list.'),

    LegalSection('CHANGES TO THESE TERMS',
      'We may update these terms. Material changes will be surfaced '
      'inside the app before they take effect, and the date at the top '
      'of this document will change. Continued use after an update '
      'constitutes acceptance. If you do not accept a change, stop '
      'using the app and delete your account; where the change '
      'materially reduces what your paid subscription gives you, you '
      'may seek a refund of the unused period through '
      '$_platformAppleStore.'),

    const LegalSection('GENERAL',
      '• ENTIRE AGREEMENT. These terms, together with the Privacy '
      'Policy and the in-app consent dialogs, are the whole agreement '
      'between you and ImHim about the app.\n'
      '• SEVERABILITY. If any provision is held unenforceable, it is '
      'severed or limited to the minimum extent necessary and the rest '
      'stays in force.\n'
      '• NO WAIVER. If we do not enforce a provision on one occasion, '
      'that is not a waiver of it.\n'
      '• ASSIGNMENT. You may not assign or transfer these terms or your '
      'account. We may assign them to a successor in connection with a '
      'merger, acquisition or sale of assets, on notice to you.\n'
      '• NO AGENCY. Nothing here creates a partnership, employment or '
      'agency relationship between you and ImHim.\n'
      '• LANGUAGE. The English version of these terms governs.'),

    LegalSection('CONTACT',
      'ImHim is operated by M2MB.\n\n'
      'General questions, complaints, data requests, and appeals: '
      'info@m2mb.co.uk.\n\n'
      'To report objectionable content or an abusive user, put REPORT '
      'in the subject line. We aim to acknowledge reports within 24 '
      'hours.\n\n'
      'Billing questions about a charge on your account are handled by '
      '$_platformAppleStore, not by us — but if you are stuck, write to '
      'us anyway and we will point you at the right place.'),
  ],
);

LegalDoc get privacyDoc => LegalDoc(
  title: 'Privacy Policy',
  subtitle: 'WHAT WE COLLECT · WHERE IT GOES',
  lastUpdatedLine: 'Last updated 19 August 2026.',
  sections: [
    const LegalSection('THE SHORT VERSION',
      'ImHim is an AI roleplay and dating-coach app with a small social '
      'layer. Here is the whole picture in one place.\n\n'
      'WHAT LEAVES YOUR DEVICE, AND ONLY WHEN YOU ACT\n\n'
      '• VOICE — when you hold the talk button in a live voice '
      'roleplay, your microphone audio streams to OpenAI so the '
      'character can hear you and reply.\n'
      '• TEXT — when you send a message in a text roleplay or to the '
      'coach, that text is sent to OpenAI to generate the reply.\n'
      '• SCREENSHOTS — when you upload a dating-app screenshot for a '
      'breakdown, it is read on your device first, then sent to OpenAI '
      'to draft your replies.\n\n'
      'WHAT WE KEEP ON A SERVER\n\n'
      'An account identifier, your chosen call-sign, the age and gender '
      'you gave at setup, and your SCORES — the numbers your practice '
      'produces, so squads, duels and leaderboards can work. We do NOT '
      'keep your conversations, your voice, or your screenshots.\n\n'
      'WHAT OTHER USERS SEE\n\n'
      'Your call-sign and your scores. Never your name, your email, or '
      'a single word of anything you said to a character or the coach.\n\n'
      'THE PROMISES\n\n'
      'Everything is sent over encrypted HTTPS / TLS. We do not sell '
      'your data and we do not train AI on it. ImHim does not scan or '
      'store your face. You can revoke AI permission, and you can '
      'delete your account and everything attached to it, from inside '
      'the app in Settings.'),

    const LegalSection('WHO WE ARE',
      'ImHim is operated by M2MB, which is the data controller for the '
      'purposes of the UK GDPR and the EU GDPR.\n\n'
      'For any privacy question, access request, or deletion request, '
      'email info@m2mb.co.uk. We aim to respond within 30 days, and '
      'usually much sooner.'),

    const LegalSection('YOUR ACCOUNT & IDENTITY',
      'This section replaces an earlier version of this policy which '
      'said ImHim had no accounts. It does now, and this is exactly '
      'what that means.\n\n'
      'THE ANONYMOUS ACCOUNT\n\n'
      'The first time you open ImHim, an anonymous account is created '
      'for you automatically. It contains a randomly generated '
      'identifier and nothing else — no name, no email, no phone '
      'number. Its only job is to hold your progress and let you join a '
      'squad.\n\n'
      'IF YOU CLAIM IT\n\n'
      'You may optionally sign in with Apple or with Google so your '
      'progress survives a lost phone. When you do, the provider gives '
      'us an EMAIL ADDRESS for your account. That email is stored by '
      'our authentication provider (Supabase), is used only to '
      'recognise you when you sign in again, and is never shown to '
      'other users, never used for marketing, and never sold. If you '
      'use Apple\'s Hide My Email, we receive only the relay address '
      'and never your real one.\n\n'
      'YOUR PROFILE\n\n'
      'Your profile row holds your call-sign, and the age and gender '
      'you entered during setup — which are used to pick appropriate '
      'practice scenarios. Any signed-in user of ImHim can read profile '
      'rows, which is how call-signs appear on leaderboards; treat your '
      'call-sign as public.\n\n'
      'DELETING IT\n\n'
      'Settings → Delete my account removes the account, the profile, '
      'the email associated with the sign-in, your squad membership and '
      'your leaderboard rows. See DATA RETENTION below for the small '
      'number of things that survive and why.'),

    const LegalSection('WHAT WE COLLECT',
      'ON YOUR DEVICE\n\n'
      'Your progress, XP, streaks, mission state, current-session chat '
      'history, settings, purchased voice-minute balance, and your '
      'purchase receipt. This stays on your device unless a section '
      'below says otherwise.\n\n'
      'ON OUR SERVERS (SUPABASE)\n\n'
      '• Your account identifier, and the email address from Apple or '
      'Google if you claimed the account.\n'
      '• Your profile: call-sign, age, gender, and whether you have '
      'given AI consent.\n'
      '• Your SCORES and the AI\'s rubric breakdown for each scored '
      'session — voice sessions, text attempts, daily challenges and '
      'duels. These are numbers and short category labels. The '
      'conversation itself is NOT stored.\n'
      '• Your squad membership, and the structured squad events that '
      'make the board work (you joined, you committed to a mission, you '
      'completed it, you were nudged).\n'
      '• Your duel records: who played whom, in which scenario, the two '
      'scores, and the result.\n'
      '• A backup copy of your XP and streak, so a new phone can '
      'restore your run.\n\n'
      'SENT TO OUR AI PROVIDER, TRANSIENTLY, ONLY WHEN YOU ACT\n\n'
      '• The microphone audio from a live voice-roleplay turn.\n'
      '• The text messages you type in a roleplay or to the coach.\n'
      '• A dating-app screenshot you choose to upload (and the text '
      'read from it on your device).\n\n'
      'Each of these is processed for the single request or live '
      'session that produces your reply, and is then gone.'),

    const LegalSection('WHAT OTHER USERS CAN SEE',
      'Because ImHim has squads, duels and leaderboards, some of what '
      'you do is visible to other people. This is the complete list.\n\n'
      'VISIBLE\n\n'
      '• Your call-sign.\n'
      '• Your scores, your streak, your rank, your win/loss record, and '
      'your position on the leaderboards.\n'
      '• Within your squad: whether you completed or skipped each of '
      'today\'s missions, and your score on today\'s shared challenge. '
      'That visibility is the purpose of a squad.\n\n'
      'NEVER VISIBLE\n\n'
      '• Your real name, your email address, your phone number.\n'
      '• Your age or your gender.\n'
      '• A single word of any roleplay conversation, coach message, or '
      'uploaded screenshot.\n'
      '• Anything at all from Creator Mode.\n\n'
      'IN A DUEL you and your opponent each talk to the same AI '
      'character SEPARATELY. Neither of you sees the other\'s '
      'conversation and there is no direct messaging between users '
      'anywhere in ImHim. Only the two scores and the result are '
      'shared.'),

    const LegalSection('VOICE ROLEPLAY DATA',
      'WHEN AUDIO IS CAPTURED\n\n'
      'Only when you explicitly hold the talk / record button inside a '
      'live voice roleplay. ImHim does NOT listen passively, NOT in the '
      'background, and NOT outside an active session. Microphone '
      'permission is requested by the operating system the first time '
      'you start a voice session; you may deny it and the rest of the '
      'app still works.\n\n'
      'EXACTLY WHAT IS SENT\n\n'
      'A live audio stream of what you say during the turn, plus the '
      'character / scenario id needed to shape the reply. NOT sent: '
      'name, email, phone, location, contacts, or advertising IDs.\n\n'
      'EXACT ROUTE\n\n'
      'Your device requests a short-lived ephemeral token from ImHim\'s '
      'backend (over HTTPS / TLS), then opens a TLS-encrypted WebSocket '
      'DIRECTLY to OpenAI\'s Realtime API (api.openai.com). Your live '
      'audio streams to OpenAI and the character\'s reply streams back. '
      'In this live mode the audio does NOT pass through ImHim\'s '
      'servers.\n\n'
      'RETENTION\n\n'
      '• On your phone: audio is streamed live and not saved.\n'
      '• In flight: TLS encrypted.\n'
      '• OpenAI: processed for the duration of the live session; '
      'excluded from model training and long-term retention under '
      'OpenAI\'s standard API terms.\n'
      '• On our servers: the audio is never stored. What IS stored '
      'afterwards is the SCORE the session produced and its rubric '
      'breakdown — numbers, not words.\n\n'
      'WHY\n\n'
      'Sole purpose: let the AI character hear you and reply in real '
      'time, and score your delivery. Never used for voice-print '
      'biometrics, speaker identification, advertising, profiling, AI '
      'model training, or resale.'),

    const LegalSection('TEXT ROLEPLAY & COACH DATA',
      'WHEN TEXT IS SENT\n\n'
      'Only when you send a message in a text roleplay or to the AI '
      'coach. Nothing is sent while you are just reading.\n\n'
      'EXACTLY WHAT IS SENT\n\n'
      'The message you typed, the recent messages in that conversation '
      '(so the reply has context), and the character / scenario id. NOT '
      'sent: name, email, phone, location, contacts, or advertising '
      'IDs.\n\n'
      'EXACT ROUTE\n\n'
      'Your device → an ImHim server function (Supabase Edge Functions, '
      'and for some legacy roleplay features a service hosted on '
      'Railway, both in the United States) over HTTPS / TLS → forwarded '
      'in-memory to OpenAI → the reply returns to your phone. Our '
      'servers do NOT persist your messages; only timestamps and HTTP '
      'status codes are logged for diagnostics, auto-expiring after 30 '
      'days.\n\n'
      'RETENTION\n\n'
      '• On your phone: kept for the current conversation; cleared when '
      'you leave or via Settings → Delete my account.\n'
      '• ImHim backend: your message text is not persisted (transient '
      'routing only). The resulting SCORE and rubric are stored against '
      'your account.\n'
      '• OpenAI: processed for the single request; excluded from '
      'training and long-term retention.\n\n'
      'WHY\n\n'
      'Sole purpose: generate the character\'s reply or the coach\'s '
      'answer, and grade the conversation. Never used for advertising, '
      'profiling, AI training, or resale.'),

    const LegalSection('RIZZ — READING YOUR DATING SCREENSHOTS',
      'The Texts / Rizz surface helps you reply to real dating-app '
      'conversations.\n\n'
      'WHEN DATA IS SENT\n\n'
      'Only when you act: when you tap to analyse a screenshot, send a '
      'message to the chat coach, or request a pickup line. Nothing is '
      'sent while you are just browsing.\n\n'
      'EXACTLY WHAT IS SENT\n\n'
      'A screenshot you upload is first read ON YOUR DEVICE by Google '
      'ML Kit text recognition (OCR); no bytes leave the phone during '
      'that step, and that OCR runs entirely offline. When you ask for '
      'a breakdown, the extracted conversation text is sent so the '
      'model can write replies, and for harder images the screenshot '
      'itself (JPEG) may be sent so OpenAI\'s vision model can read it '
      'directly. We do NOT read your camera roll — only the single '
      'screenshot you explicitly pick.\n\n'
      'ABOUT THE OTHER PERSON IN THE SCREENSHOT\n\n'
      'A dating-app screenshot may contain another person\'s messages, '
      'name, or photo. It is processed for the SOLE purpose of drafting '
      'your reply — never used for facial recognition, identity '
      'matching, profiling, advertising, AI training, or resale, and '
      'never stored on our servers. You are responsible for the content '
      'you upload; only share screenshots of conversations you are part '
      'of, and be aware that in some places sharing another person\'s '
      'private messages may itself be unlawful.\n\n'
      'EXACT ROUTE\n\n'
      'Your device → an ImHim server function (United States) over '
      'HTTPS / TLS → forwarded in-memory to OpenAI → suggested replies '
      'return to your phone. The backend does NOT persist your '
      'screenshot, its text, or your chat messages; only timestamps and '
      'HTTP status codes are logged, auto-expiring after 30 days.'),

    const LegalSection('SCORES, SQUADS & LEADERBOARDS',
      'This is the data that makes the social layer work, and it is the '
      'one category we deliberately DO keep.\n\n'
      'WHAT IS STORED\n\n'
      '• For each scored session: a score out of 100 (or a raw rubric '
      'total), the AI\'s category breakdown, the scenario id, and a '
      'timestamp. No transcript.\n'
      '• Running totals: your voice points, chat points, rating, '
      'streak, XP and best streak.\n'
      '• Squad: which squad you are in, and structured events (joined, '
      'committed to a mission, completed a mission, nudged another '
      'member). A nudge records who nudged whom — it is designed to be '
      'seen by the squad.\n'
      '• Duels: the two players, the scenario, both scores, the winner.\n\n'
      'WHY WE KEEP IT\n\n'
      'A leaderboard that forgets is not a leaderboard, and a squad '
      'cannot hold anyone accountable for a day it cannot see. This is '
      'processed on the basis of performing our contract with you — it '
      'is the feature you signed up for.\n\n'
      'HOW LONG\n\n'
      'Detailed session rows are pruned automatically on a rolling '
      'basis; running totals persist while your account does. Deleting '
      'your account removes all of it.'),

    const LegalSection('ANALYTICS & CRASH DATA',
      'ImHim uses Google Firebase Analytics to understand which screens '
      'are used and where the app fails.\n\n'
      'WHAT IT COLLECTS\n\n'
      'Anonymous, aggregated app-usage events — screens opened, '
      'features used, errors — together with a Firebase-generated '
      'instance identifier, your device model, operating-system '
      'version, and country-level location derived from your IP '
      'address.\n\n'
      'WHAT IT DOES NOT COLLECT\n\n'
      'Your name, your email, your call-sign, your precise location, '
      'your contacts, or the content of any conversation, message or '
      'screenshot. ImHim does not use the advertising identifier, does '
      'not track you across other apps or websites, and does not run '
      'ads.\n\n'
      'You can reset the Firebase instance identifier at any time by '
      'reinstalling the app.'),

    LegalSection('PURCHASES',
      'Billing is handled by $_platformAppleStore ($_storeName). ImHim '
      'never sees your card number, your billing address, or your full '
      '$_storeAccount details.\n\n'
      'We use RevenueCat, Inc. (United States) to check whether your '
      'subscription or purchase is valid. RevenueCat receives an '
      'anonymous app-user identifier and the purchase receipt issued by '
      'the store, and returns whether your entitlement is active. It '
      'does not receive your name, your email, or any of your '
      'conversation content.'),

    LegalSection('WHO PROCESSES YOUR DATA',
      'The complete list of third parties that receive any of your '
      'data, and what each one gets:\n\n'
      '• OpenAI, L.L.C. (San Francisco, CA, USA) — your voice audio '
      '(live roleplay), your text messages (text roleplay and coach), '
      'and your dating-screenshot text or image, each for the single '
      'request or live session that produces your reply. Models used '
      'include the OpenAI Realtime models (live voice), GPT-4o / GPT-4o '
      'mini (text and vision), and Whisper (speech-to-text).\n\n'
      '• Supabase, Inc. (USA) — hosts our database, our authentication, '
      'and our server functions. Holds your account identifier, your '
      'sign-in email if you claimed the account, your profile, your '
      'scores, your squad membership and your duel records. Does NOT '
      'hold your conversations.\n\n'
      '• Google LLC / Firebase (USA) — anonymous analytics and crash '
      'reporting, and the on-device ML Kit text recognition used to '
      'read screenshots (which runs offline and sends Google nothing). '
      'If you use Sign in with Google, Google also handles that '
      'sign-in.\n\n'
      '• Apple Inc. — if you use Sign in with Apple, Apple handles that '
      'sign-in and gives us an email or a private relay address.\n\n'
      '• RevenueCat, Inc. (USA) — purchase receipt validation and '
      'entitlement status. See PURCHASES above.\n\n'
      '• Railway Corp. (USA) — hosts a legacy backend service used by '
      'some roleplay features as a transient router to OpenAI. Does not '
      'persist your content.\n\n'
      'No other party receives your data. No advertisers, no data '
      'brokers, no analytics resellers, no social-media pixels.'),

    const LegalSection('INTERNATIONAL TRANSFERS',
      'ImHim\'s processors are located primarily in the United States, '
      'so if you are in the UK, the EEA or Switzerland your data is '
      'transferred outside your country.\n\n'
      'Those transfers are made under the UK International Data '
      'Transfer Addendum and the European Commission\'s Standard '
      'Contractual Clauses, or under an applicable adequacy decision '
      'such as the EU-US and UK-US Data Privacy Framework where the '
      'processor is certified. You may request a copy of the relevant '
      'safeguards by emailing info@m2mb.co.uk.'),

    const LegalSection('WHY WE ARE ALLOWED TO PROCESS IT',
      'For users in the UK and the EEA, our legal bases under Article 6 '
      'GDPR are:\n\n'
      '• PERFORMANCE OF A CONTRACT — your account, your progress, your '
      'scores, squads, duels and leaderboards. These are the service '
      'you asked for.\n'
      '• CONSENT — sending your voice, your messages or your '
      'screenshots to our AI provider. You give this through the in-app '
      'AI permission dialog and you can withdraw it at any time in '
      'Settings → Revoke AI permission. Withdrawal does not affect '
      'processing that already happened.\n'
      '• LEGITIMATE INTERESTS — keeping the service secure, preventing '
      'abuse and cheating, and anonymous analytics used to fix and '
      'improve the app. We have balanced these against your rights and '
      'kept the data minimal.\n'
      '• LEGAL OBLIGATION — where we must retain or disclose something '
      'to comply with the law.\n\n'
      'We do not carry out automated decision-making that produces '
      'legal or similarly significant effects on you. Your scores are '
      'generated by AI, but they affect only your position inside a '
      'game.'),

    const LegalSection('THIRD-PARTY PROTECTION PARITY',
      'Per App Store guideline 5.1.2(i), any third party that receives '
      'ImHim user data must provide the same or equal privacy '
      'protection as ImHim itself. Our processors meet this bar:\n\n'
      '• OpenAI — under the standard API terms, customer inputs are '
      'excluded from model training, encrypted in transit (TLS) and at '
      'rest, processed transiently for the single request or live '
      'session, and not used for advertising, profiling, or sale to '
      'third parties.\n'
      '• Supabase — data encrypted in transit and at rest, row-level '
      'security so one user cannot read another\'s private rows, and no '
      'use of customer data for advertising or resale.\n'
      '• Firebase — configured for analytics only, with advertising '
      'features and cross-app tracking off, and no sale of data.\n'
      '• RevenueCat — receives only an anonymous identifier and a store '
      'receipt, and does not sell data.\n\n'
      'Each is engaged under a written data-processing agreement that '
      'binds it to process data only on our instructions.'),

    const LegalSection('WHAT WE DO NOT COLLECT',
      'No real name. No phone number. No precise or background '
      'location. No social contacts or address book. No camera-roll '
      'access beyond the single screenshot you pick. No tracking across '
      'other apps or websites. No advertising identifier for profiling. '
      'No advertising of any kind. No voice-print biometrics. No '
      'speaker identification. No facial recognition or biometric '
      'template. ImHim does not scan, analyse, or store your face.\n\n'
      'The one identifier we may hold that identifies you personally is '
      'the email address your sign-in provider gives us IF you choose '
      'to claim your account — see YOUR ACCOUNT & IDENTITY above. '
      'Play anonymously and we never have it.\n\n'
      'We do not sell or share personal information as those terms are '
      'defined under the California Consumer Privacy Act, and we have '
      'not done so in the preceding twelve months.'),

    const LegalSection('CREATOR MODE',
      'Settings → CREATOR is a password-gated, off-by-default switch '
      'that swaps the AI characters and coach into a less filtered, '
      'adult (18+) tone. Even when it is ON, OpenAI\'s content-policy '
      'guardrails are enforced by the provider. CREATOR is OFF by '
      'default, must be explicitly unlocked with a password, applies '
      'only on the device you enable it on, and can be re-locked at any '
      'time.\n\n'
      'Whether Creator Mode is on is stored on your device only. It is '
      'never sent to our servers and never visible to another user.'),

    const LegalSection('DATA RETENTION — SUMMARY',
      '• ON YOUR DEVICE: progress, streaks, settings, minute balance '
      'and current-session chat, until you delete them (Settings → '
      'Delete my account) or uninstall.\n'
      '• IN FLIGHT: encrypted with TLS.\n'
      '• ON OUR SERVERS — CONTENT: your conversations, voice audio and '
      'screenshots are never persisted. Only timestamps and HTTP status '
      'codes are logged, auto-expiring after 30 days.\n'
      '• ON OUR SERVERS — SCORES: individual session rows are pruned '
      'automatically on a rolling basis by a scheduled job. Running '
      'totals, your profile and your squad membership persist for as '
      'long as your account does.\n'
      '• ON OPENAI: processed for the single request or live session, '
      'then excluded from training and long-term retention under the '
      'standard API terms.\n\n'
      'AFTER YOU DELETE YOUR ACCOUNT\n\n'
      'Everything above that is linked to you is removed. Two things '
      'may remain: the record of a completed duel, with your identity '
      'removed, because your former opponent has a legitimate interest '
      'in their own match history; and anonymised aggregate statistics '
      'that cannot be linked back to you. Backups are overwritten on '
      'their normal cycle, within 30 days.'),

    const LegalSection('CHILDREN',
      'ImHim is intended for users aged 17 and over and is not directed '
      'to children. We do not knowingly collect data from children '
      'under 13, and we do not knowingly permit under-17s to use the '
      'app at all.\n\n'
      'If you are a parent or guardian and believe a child has used the '
      'app, email info@m2mb.co.uk. We will delete the account and any '
      'records associated with it, and we will do so without requiring '
      'you to prove anything beyond a plausible account of the '
      'circumstances.'),

    LegalSection('YOUR RIGHTS',
      'Wherever you live, you can:\n\n'
      '• ACCESS what we hold — most of it is visible in the app; email '
      'us for the rest.\n'
      '• DELETE all of it — Settings → Delete my account, immediately '
      'and without asking us.\n'
      '• REVOKE AI PERMISSION — Settings → Revoke AI permission stops '
      'any further content being sent to the AI provider.\n'
      '• OPT OUT OF AUTO-RENEWAL — $_storeName account settings.\n\n'
      'IF YOU ARE IN THE UK OR THE EEA you additionally have the right '
      'to rectification, to restriction of processing, to object to '
      'processing based on legitimate interests, and to data '
      'portability (a machine-readable copy of the data you gave us). '
      'Email info@m2mb.co.uk and we will respond within 30 days. You '
      'also have the right to complain to your supervisory authority — '
      'in the UK that is the Information Commissioner\'s Office '
      '(ico.org.uk), and in the EEA it is the authority in your member '
      'state.\n\n'
      'IF YOU ARE IN CALIFORNIA you have the right to know what '
      'personal information we collect and why, the right to delete it, '
      'the right to correct it, and the right not to be discriminated '
      'against for exercising any of them. We do not sell or share '
      'personal information, so there is nothing to opt out of. Use the '
      'same email address; we will not ask you for more information '
      'than we need to verify the request.\n\n'
      'We will never charge you for exercising a right, and we will '
      'never degrade the app because you did.'),

    const LegalSection('SECURITY',
      'All content sent to our servers or to OpenAI travels over '
      'HTTPS / TLS. Data at rest in our database is encrypted, and '
      'row-level security rules mean one user cannot read another '
      'user\'s private rows even if they tried. Anything that affects a '
      'score or a rank is written only by our server functions, never '
      'by the app on your phone, so a modified client cannot award '
      'itself points. On your device, app data is stored in the '
      'operating system\'s sandboxed storage and is removed when you '
      'delete the app.\n\n'
      'No system is perfectly secure. If we become aware of a breach '
      'affecting your personal data, we will notify the relevant '
      'supervisory authority within 72 hours where the law requires it, '
      'and we will tell affected users in the app and by email where '
      'the breach is likely to present a high risk to them.'),

    const LegalSection('CHANGES',
      'We may update this policy. Material changes will be surfaced '
      'inside the app before they take effect, and the date at the top '
      'will change. Where a change requires your consent under '
      'applicable law, we will ask for it rather than assume it.'),

    const LegalSection('CONTACT',
      'ImHim is operated by M2MB.\n\n'
      'Privacy questions, access requests, deletion requests, and '
      'complaints: info@m2mb.co.uk.\n\n'
      'To report objectionable content or an abusive user, put REPORT '
      'in the subject line — see the Terms of Use for how that process '
      'works and how fast we act.'),
  ],
);
