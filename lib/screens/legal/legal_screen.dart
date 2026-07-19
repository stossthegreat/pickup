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
                  style: GoogleFonts.playfairDisplay(
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
  lastUpdatedLine: 'Last updated 17 July 2026.',
  sections: [
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
      '• All daily missions, streaks, and progress tracking.\n\n'
      'Cancel anytime in your $_storeName settings; access continues '
      'until the end of the paid week. No refund is issued for the '
      'unused portion of the current period.'),

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
      'Creator Mode (see below) is intended for adults (18+).'),

    const LegalSection('AI-GENERATED CONTENT — NATURE & LIMITS',
      'Every character reply, coach note, suggested line, and pickup '
      'opener in ImHim is generated by artificial intelligence. AI '
      'output can be inaccurate, inappropriate for your situation, or '
      'repetitive, and it does not represent the views of ImHim. You '
      'are responsible for how you use it. Do not rely on ImHim output '
      'for legal, medical, psychological, financial, or safety '
      'decisions. Real people are under no obligation to respond the '
      'way an AI character does; always use judgement and respect other '
      'people\'s boundaries and consent in the real world.'),

    LegalSection('ACCOUNTS',
      'ImHim does not require an account. Your progress, streaks, and '
      'settings live on your device and are tied to your '
      '$_storeAccount for billing purposes only.'),

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
      '$_platformAppleStore directly, not by ImHim.'),

    const LegalSection('NO PROFESSIONAL ADVICE',
      'ImHim is a coaching-style entertainment product. It does not '
      'provide medical, psychological, therapeutic, legal, or '
      'relationship-counselling advice, and nothing in the app creates '
      'a professional relationship. If you are struggling with your '
      'mental health or a relationship, please seek help from a '
      'qualified professional.'),

    const LegalSection('YOUR CONTENT',
      'You keep all rights to the messages you type and the screenshots '
      'you choose to upload. By sending them in the app you grant ImHim '
      'a limited, revocable, royalty-free licence to process that '
      'content — on your device and by transmitting it to our AI '
      'provider (OpenAI) — solely to produce the coaching, roleplay '
      'replies, and suggestions you asked for. We do not sell your '
      'content and we do not train AI models on it.'),

    const LegalSection('AI DATA PERMISSION',
      'Before any of your content (voice, text, or a screenshot) is '
      'sent to our AI provider, ImHim asks for your permission through '
      'an in-app consent dialog that explains what is sent and to whom. '
      'You must agree for the feature to work; declining keeps your '
      'content on your device and the AI feature stays off. You can '
      'revoke this permission at any time in Settings → Revoke AI '
      'permission.'),

    const LegalSection('ACCEPTABLE USE',
      'You agree to use ImHim lawfully and respectfully. In '
      'particular:\n\n'
      '• Only upload screenshots of conversations you are personally '
      'part of. Do not submit other people\'s private messages, images, '
      'or personal information that you have no right to share.\n'
      '• Do not use ImHim, or any line it generates, to harass, stalk, '
      'threaten, deceive, defame, or abuse any person.\n'
      '• Do not attempt to make the AI produce content that sexualises '
      'minors, promotes real-world violence or self-harm, or otherwise '
      'violates the law or the App Store / Google Play content '
      'policies.\n'
      '• Do not attempt to reverse-engineer, scrape, resell, or '
      'overload the service.'),

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
      'be re-locked at any time by turning it off or deleting the app.'),

    const LegalSection('TERMINATION',
      'We may suspend or terminate access for conduct that violates '
      'these terms, harms other users, or violates applicable law. You '
      'may stop using the app at any time by deleting it.'),

    const LegalSection('DISCLAIMERS & LIABILITY',
      'ImHim is provided "as is" and "as available" without warranty of '
      'any kind, express or implied, including any warranty that AI '
      'output will be accurate, appropriate, or effective. To the '
      'maximum extent permitted by law, ImHim\'s total liability for '
      'any claim is limited to the amount you paid ImHim in the twelve '
      'months preceding the claim.'),

    const LegalSection('CHANGES TO THESE TERMS',
      'We may update these terms. Material changes will be surfaced '
      'inside the app before they take effect. Continued use after an '
      'update constitutes acceptance.'),

    const LegalSection('CONTACT',
      'Questions? Email info@m2mb.co.uk.'),
  ],
);

LegalDoc get privacyDoc => LegalDoc(
  title: 'Privacy Policy',
  subtitle: 'WHAT WE COLLECT · WHERE IT GOES',
  lastUpdatedLine: 'Last updated 17 July 2026.',
  sections: [
    const LegalSection('THE SHORT VERSION',
      'ImHim is an AI roleplay and dating-coach app. To make the AI '
      'work, three kinds of content can leave your device — but only '
      'when you take an action that clearly sends it:\n\n'
      '• VOICE — when you hold the talk button in a live voice '
      'roleplay, your microphone audio streams to OpenAI so the '
      'character can hear you and reply.\n'
      '• TEXT — when you send a message in a text roleplay or to the '
      'coach, that text is sent to OpenAI to generate the reply.\n'
      '• SCREENSHOTS — when you upload a dating-app screenshot for a '
      'breakdown, it is read on your device first, then sent to OpenAI '
      'to draft your replies.\n\n'
      'Everything is sent over encrypted HTTPS / TLS. We do not sell '
      'your data, we do not train AI on it, and we do not require an '
      'account. ImHim does not scan or store your face. You can revoke '
      'AI permission and delete your on-device data at any time in '
      'Settings.'),

    const LegalSection('WHAT WE COLLECT',
      'ON YOUR DEVICE\n\n'
      'Your progress, streaks, mission state, current-session chat '
      'history, settings, and your purchase receipt. This stays on '
      'your device.\n\n'
      'SENT TO OUR AI PROVIDER, TRANSIENTLY, ONLY WHEN YOU ACT\n\n'
      '• The microphone audio from a live voice-roleplay turn.\n'
      '• The text messages you type in a roleplay or to the coach.\n'
      '• A dating-app screenshot you choose to upload (and the text '
      'read from it on your device).\n\n'
      'Each of these is processed for the single request or live '
      'session that produces your reply, and is not attached to a '
      'persistent account, because there is no account.'),

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
      'OpenAI\'s standard API terms.\n\n'
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
      'Your device → ImHim\'s backend servers (hosted on Railway, in '
      'the United States) over HTTPS / TLS 1.3 → forwarded in-memory to '
      'OpenAI → the reply returns to your phone. The backend does NOT '
      'persist your messages; only timestamps and HTTP status codes are '
      'logged for diagnostics, auto-expiring after 30 days.\n\n'
      'RETENTION\n\n'
      '• On your phone: kept for the current conversation; cleared when '
      'you leave or via Settings → Delete all data.\n'
      '• ImHim backend: not persisted (transient routing only).\n'
      '• OpenAI: processed for the single request; excluded from '
      'training and long-term retention.\n\n'
      'WHY\n\n'
      'Sole purpose: generate the character\'s reply or the coach\'s '
      'answer. Never used for advertising, profiling, AI training, or '
      'resale.'),

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
      'that step. When you ask for a breakdown, the extracted '
      'conversation text is sent so the model can write replies, and '
      'for harder images the screenshot itself (JPEG) may be sent so '
      'OpenAI\'s vision model can read it directly. We do NOT read your '
      'camera roll — only the single screenshot you explicitly pick.\n\n'
      'ABOUT THE OTHER PERSON IN THE SCREENSHOT\n\n'
      'A dating-app screenshot may contain another person\'s messages, '
      'name, or photo. It is processed for the SOLE purpose of drafting '
      'your reply — never used for facial recognition, identity '
      'matching, profiling, advertising, AI training, or resale, and '
      'never stored on our servers. You are responsible for the content '
      'you upload; only share screenshots of conversations you are part '
      'of.\n\n'
      'EXACT ROUTE\n\n'
      'Your device → ImHim\'s backend (Railway, USA) over HTTPS / TLS '
      '1.3 → forwarded in-memory to OpenAI → suggested replies return '
      'to your phone. The backend does NOT persist your screenshot, its '
      'text, or your chat messages; only timestamps + HTTP status codes '
      'are logged, auto-expiring after 30 days.'),

    const LegalSection('WHO PROCESSES YOUR DATA',
      'ImHim uses ONE third-party AI provider:\n\n'
      '• OpenAI, L.L.C. (San Francisco, CA, USA) — receives your voice '
      'audio (live roleplay), your text messages (text roleplay and '
      'coach), and your dating-screenshot text / image (rizz), each for '
      'the single request or live session that produces your reply. '
      'Models used include the OpenAI Realtime models (live voice), '
      'GPT-4o / GPT-4o mini (text and vision), and Whisper '
      '(speech-to-text).\n\n'
      'ImHim\'s own backend servers (hosted on Railway, in the United '
      'States) act only as a transient router and to mint short-lived '
      'Realtime tokens. No other party receives your content — no '
      'advertisers, data brokers, analytics resellers, or social-login '
      'partners.'),

    const LegalSection('THIRD-PARTY PROTECTION PARITY',
      'Per App Store guideline 5.1.2(i), any third party that receives '
      'ImHim user data must provide the same or equal privacy '
      'protection as ImHim itself. Our AI provider meets this bar:\n\n'
      '• OpenAI — under the standard API terms, customer inputs are '
      'excluded from model training, encrypted in transit (TLS) and at '
      'rest, processed transiently for the single request or live '
      'session, and not used for advertising, profiling, or sale to '
      'third parties.\n\n'
      'ImHim does not transmit your content to any other third party.'),

    const LegalSection('WHAT WE DO NOT COLLECT',
      'No name. No email. No phone number. No location. No social '
      'contacts. No camera-roll access beyond the single screenshot '
      'you pick. No tracking across other apps. No advertising '
      'identifier for profiling. No voice-print biometrics. No speaker '
      'identification. No facial recognition or biometric template. '
      'ImHim does not scan, analyse, or store your face.'),

    const LegalSection('CREATOR MODE',
      'Settings → CREATOR is a password-gated, off-by-default switch '
      'that swaps the AI characters and coach into a less filtered, '
      'adult (18+) tone. Even when it is ON, OpenAI\'s content-policy '
      'guardrails are enforced by the provider. CREATOR is OFF by '
      'default, must be explicitly unlocked with a password, applies '
      'only on the device you enable it on, and can be re-locked at any '
      'time.'),

    const LegalSection('DATA RETENTION — SUMMARY',
      '• On your device: progress, streaks, settings, and '
      'current-session chat, until you delete them (Settings → Delete '
      'all data) or uninstall.\n'
      '• In flight: encrypted with TLS.\n'
      '• On ImHim\'s backend: your content is not persisted; only '
      'timestamps and HTTP status codes are logged and auto-expire '
      'after 30 days.\n'
      '• On OpenAI: processed for the single request or live session, '
      'then excluded from training and long-term retention under the '
      'standard API terms.'),

    const LegalSection('CHILDREN',
      'ImHim is intended for users aged 17 and over and is not directed '
      'to children. We do not knowingly collect data from children '
      'under 13. If you believe a child has used the app, email '
      'info@m2mb.co.uk and we will delete any records associated with '
      'the submission.'),

    LegalSection('YOUR RIGHTS',
      'Access: your personal data lives on your device; you can review '
      'it in the app and in your device settings.\n'
      'Deletion: use Settings → Delete all data, or delete the app, to '
      'erase on-device data; the transient server-side request data '
      'auto-expires.\n'
      'Revoke AI permission: Settings → Revoke AI permission stops any '
      'further content being sent to the AI provider.\n'
      'Opt-out of auto-renewal: $_storeName account settings.'),

    LegalSection('PURCHASES',
      'Billing is handled by $_platformAppleStore ($_storeName). ImHim '
      'never sees your card number. We see only a receipt that confirms '
      'whether your subscription is active.'),

    const LegalSection('SECURITY',
      'All content sent to our servers or to OpenAI travels over '
      'HTTPS / TLS. On your device, app data is stored in the operating '
      'system\'s sandboxed storage and is removed when you delete the '
      'app.'),

    const LegalSection('CHANGES',
      'We may update this policy. Material changes will be surfaced '
      'inside the app before they take effect.'),

    const LegalSection('CONTACT',
      'Questions or data requests? Email info@m2mb.co.uk.'),
  ],
);
