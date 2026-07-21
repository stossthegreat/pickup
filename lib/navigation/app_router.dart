import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';
import '../screens/legal/legal_screen.dart';
import '../screens/onboarding/age_name_screen.dart';
import '../screens/onboarding/ai_consent_screen.dart';
import '../screens/onboarding/gender_pick_screen.dart';
import '../screens/onboarding/onboarding_story_screen.dart';
import '../screens/onboarding/intro_reel_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/paywall/paywall_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../services/analytics_route_observer.dart';
import '../screens/game/pickup_line/pickup_line_screen.dart';
import '../screens/game/rizz/rizz_reply_screen.dart';
import '../screens/rizz/rizz_chat_screen.dart';
import '../screens/rizz/rizz_tab_screen.dart' show RizzCardAction;
import '../services/share_intake_service.dart' show SharedScreenshotPayload;

final appRouter = GoRouter(
  initialLocation: '/',
  // Every navigator push/pop/replace fires screen_view through
  // AnalyticsRouteObserver, which also updates
  // AnalyticsService.currentScreen so the app-lifecycle hook in
  // main.dart tags "where did the user quit from".
  observers: [AnalyticsRouteObserver()],
  routes: [
    GoRoute(path: '/',           builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/intro',      builder: (_, __) => const IntroReelScreen()),
    // The emotional onboarding funnel (first launch lands here).
    GoRoute(path: '/onboarding/story', builder: (_, __) => const OnboardingStoryScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(
      path: '/onboarding/gender',
      builder: (context, state) {
        final extra = state.extra is Map<String, dynamic>
            ? state.extra as Map<String, dynamic>
            : const <String, dynamic>{};
        return GenderPickScreen(
          fromSettings: extra['fromSettings'] == true,
        );
      },
    ),
    // Name + age band — feeds the AI (his name in scenes, register by
    // age). Also re-openable from Settings with extra {fromSettings:true}.
    GoRoute(
      path: '/onboarding/profile',
      builder: (context, state) {
        final extra = state.extra is Map<String, dynamic>
            ? state.extra as Map<String, dynamic>
            : const <String, dynamic>{};
        return AgeNameScreen(fromSettings: extra['fromSettings'] == true);
      },
    ),
    // AI-data consent — every new user grants permission before any data
    // reaches a third-party AI service (App Store 5.1.1(i) / 5.1.2(i)).
    GoRoute(
      path: '/onboarding/consent',
      builder: (_, __) => const AiConsentScreen(),
    ),
    GoRoute(
      path: '/paywall',
      builder: (context, state) {
        final extra = state.extra;
        return PaywallScreen(
          context: extra is Map<String, dynamic> ? extra : null,
        );
      },
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) {
        final extra = state.extra is Map<String, dynamic>
            ? state.extra as Map<String, dynamic>
            : const <String, dynamic>{};
        return HomeScreen(initialTab: (extra['initialTab'] as int?));
      },
    ),
    GoRoute(path: '/lines',    builder: (_, __) => const PickupLineScreen()),
    GoRoute(
      path: '/rizz',
      builder: (_, state) {
        final extra = state.extra;
        final launchUpload = extra is RizzCardAction && extra.launchUpload;
        // The iOS Share Extension routes here with the screenshot bytes
        // already loaded. The screen auto-fires the OCR + reply pipeline
        // as if the user had picked the image from Photos.
        final preloaded = extra is SharedScreenshotPayload ? extra.bytes : null;
        return RizzReplyScreen(
          launchUpload:        launchUpload,
          preloadedScreenshot: preloaded,
        );
      },
    ),
    GoRoute(
      path: '/rizz-chat',
      builder: (_, __) => const RizzChatScreen(),
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/terms',    builder: (_, __) => LegalScreen(doc: termsDoc)),
    GoRoute(path: '/privacy',  builder: (_, __) => LegalScreen(doc: privacyDoc)),
  ],
);
