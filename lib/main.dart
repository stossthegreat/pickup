import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/dev_flags.dart';
import 'navigation/app_router.dart';
import 'providers/auralay_app_provider.dart';
import 'services/analytics_service.dart';
import 'services/backend/auth_service.dart';
import 'services/backend/backend_service.dart';
import 'services/backend/squad_live_service.dart';
import 'services/progress_sync.dart';
import 'services/daily_nudge_service.dart';
import 'services/language_service.dart';
import 'services/local_store_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'services/share_intake_service.dart';
import 'services/win_back_service.dart';
import 'theme/app_theme.dart';
import 'widgets/academy/live_toast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialise Firebase + Analytics. Safe to call even before the
  // native config files (GoogleService-Info.plist / google-services
  // .json) are dropped in — the service catches the init error and
  // leaves every event call a silent no-op until config arrives.
  await AnalyticsService.init();
  AnalyticsService.appOpen();

  // Supabase backend (identity, squads, ELO, leaderboards). Fail-soft:
  // offline launch keeps the whole solo experience working. The silent
  // anonymous sign-in is fire-and-forget so it never delays first frame
  // — every user gets a server identity with zero friction, and claims
  // it with Apple later once they have a rank worth keeping.
  await BackendService.init();
  // ignore: discarded_futures
  AuthService.ensureSignedIn()
      // Global squad watcher — a squadmate's move reaches you anywhere
      // in the app, not only while the Squad Room is open. This is the
      // difference between an app you inspect and one that talks.
      // ignore: discarded_futures
      .then((_) => SquadLiveService.start())
      // AND PULL HIS RUN BACK. The claim screen restores on sign-in,
      // but a man who reinstalls and is already claimed never opens it
      // — the session restores silently and he'd land on day zero with
      // no way to ask for his streak back. Self-limiting: it reads one
      // row, finds nothing bigger on the phone he already plays on, and
      // stops. Fire-and-forget so a cold network never delays launch.
      // ignore: discarded_futures
      .then((_) => ProgressSync.restore());

  // Roleplay language — hydrated before any voice session can start so
  // the synchronous cache is always right. English default.
  await LanguageService.hydrate();

  // RevenueCat is DISABLED for this launch (PurchaseConfig.enabled = false).
  // This call stays but no-ops while disabled — the SDK is never configured
  // and no store calls are made. The whole app runs on the kBypassPaywall
  // allowance (everyone gets Pro access + the 15-minute weekly voice cap),
  // exactly as before. To bring billing back for a paid version, flip
  // PurchaseConfig.enabled → true (and kBypassPaywall → false). See
  // lib/config/purchase_config.dart.
  await PurchaseService.init();

  // Initialise local notifications. Permission is NOT requested here —
  // it's deferred to the first protocol start so the prompt has context
  // ("your streak reminder").
  await NotificationService.init();

  // Retention engine — rolling 14-day horizon, morning DREAM pump +
  // evening STREAK nudge, refreshed on every app open. markAppOpened
  // stamps the open time then rebuilds the whole horizon. This is the
  // SINGLE source of truth for retention notifications now; the legacy
  // streak/training/rescan schedulers are no longer wired in (they'd
  // only fight the horizon by competing for the same OS slots).
  //
  // Before the rebuild: stop the win-back ladder if he became a
  // subscriber somewhere this build's paywall screen never saw (a restore
  // on another device, the RevenueCat listener flipping the flag). It has
  // to run FIRST so the horizon's evening slot reads the corrected state.
  await WinBackService.syncOnLaunch();

  // ignore: discarded_futures
  DailyNudgeService.markAppOpened();

  // Dev-flag bypass: force the subscribed flag true so every gate in the
  // app (scan → report, Mirror tab, Progress tab, etc.) reads the user
  // as Pro without any purchase. Safe to leave on for local testing —
  // on a real release build this no-ops because kBypassPaywall is false.
  if (kBypassPaywall) {
    await LocalStoreService.setSubscribed(true);
  }

  // v181 one-shot — clear the stale gameFreeUsed bool that v171..v178
  // dispose() over-eagerly burnt for testers who only briefly held
  // the orb and then tab-switched. After this runs once, the flag
  // only flips at legitimate session-end (60s timer expiry / manual
  // end). See LocalStoreService.migrateGameFreeUsedFlagOnce.
  await LocalStoreService.migrateGameFreeUsedFlagOnce();

  // Share Extension intake — listen for incoming screenshots from
  // the iOS Share Sheet (ios/ImHimShare/ShareViewController.swift).
  // Calling wire() before runApp guarantees we don't miss the cold-
  // start MethodChannel event when the user shares directly into us.
  ShareIntakeService.instance.wire();

  runApp(const MirrorApp());
}

class MirrorApp extends StatefulWidget {
  const MirrorApp({super.key});

  @override
  State<MirrorApp> createState() => _MirrorAppState();
}

class _MirrorAppState extends State<MirrorApp> with WidgetsBindingObserver {
  late final StreamSubscription<SharedScreenshot> _shareSub;

  @override
  void initState() {
    super.initState();
    // App-lifecycle observer — the drop-off detector. Pairs with the
    // AnalyticsRouteObserver wired into appRouter so every backgrounding
    // event carries the screen the user was looking at when they bailed.
    WidgetsBinding.instance.addObserver(this);

    // Listen for incoming shared screenshots from the iOS Share
    // Extension. The intake service was already wired in main() so
    // we don't miss the cold-start event; here we subscribe to the
    // BROADCAST stream and push the navigation as soon as bytes land.
    _shareSub = ShareIntakeService.instance.stream.listen(_onSharedScreenshot);

    // Cold-start sweep — if the app was launched directly via the
    // share extension (URL scheme), the boot sequence has likely
    // already raced past the MethodChannel event. Pull whatever's
    // pending after the first frame so the navigation still happens.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final shot = await ShareIntakeService.instance.pullPending();
      if (shot != null) _onSharedScreenshot(shot);
    });
  }

  void _onSharedScreenshot(SharedScreenshot shot) {
    // Route to /rizz with the screenshot bytes in `extra`. The
    // RizzReplyScreen reads `extra` on init and auto-fires the
    // existing OCR + reply pipeline as if the user had picked the
    // image with the in-app picker.
    appRouter.go('/rizz', extra: SharedScreenshotPayload(bytes: shot.bytes));
  }

  @override
  void dispose() {
    _shareSub.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // ignore: discarded_futures
        AnalyticsService.appPaused();
        break;
      case AppLifecycleState.resumed:
        // ignore: discarded_futures
        AnalyticsService.appResumed();
        // v280 — clear the iOS app-icon badge (red unread-count dot)
        // as soon as the user foregrounds the app. Opening the app
        // IS the "I saw the notification" signal; leaving the dot
        // on after the open looks broken and stops being a useful
        // retention trigger for the NEXT notification.
        // ignore: discarded_futures
        NotificationService.clearIconBadge();
        // Re-check the subscription with the store. Without this the
        // paid app kept working for anyone who cancelled until they
        // next COLD-launched — iOS holds apps in memory for days, so
        // that could be well past the week they actually bought.
        // Throttled to 15 min inside; same on Android and iOS.
        // ignore: discarded_futures
        PurchaseService.refreshOnResume();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        // detached fires on cold-kill and is best-effort: the OS may
        // not give us long enough to flush the event over the wire.
        // We still try.
        // ignore: discarded_futures
        AnalyticsService.appPaused();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ChangeNotifierProvider wraps the app so the Auralay-imported state
    // (Aura score, current day, gaze streak) is reachable from the
    // Progress tab + the Eyes/Game session screens. Mirrorly's own state
    // continues to live in SharedPreferences-backed static services
    // (LocalStoreService, PurchaseService, etc.) — no migration needed.
    return ChangeNotifierProvider(
      create: (_) => AuralayAppProvider()..load(),
      child: MaterialApp.router(
        title: 'Charmr',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: appRouter,
        // Live events land over whatever screen is showing.
        builder: (context, child) =>
            LiveToastHost(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
