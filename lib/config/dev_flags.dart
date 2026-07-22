// ───────────────────────────────────────────────────────────────────────────
//  DEV FLAGS
//  Single source of truth for dev-only overrides. Flip these back before
//  shipping — every release build should compile with all flags false.
// ───────────────────────────────────────────────────────────────────────────

/// When true:
///   · The app force-sets the local subscribed flag to true at launch, so
///     every in-app gate that reads LocalStoreService.isSubscribed() passes.
///   · The post-scan paywall gate skips straight to /report.
///   · The "Upgrade" chip in the home header is hidden.
///   · The "Upgrade" tile in settings is hidden.
///   · Onboarding ends on /home instead of /paywall.
///   · PaywallScreen, if opened manually, auto-routes back to /home.
///
/// **FLIP THIS TO FALSE BEFORE SHIPPING.**
///
/// v155 — flipped back to FALSE per bro: "add the lock for
/// subscription on it again the whole app as we previously planned."
///
/// v186 — flipped to TRUE per bro: "make it all free right now this
/// is testing." Everything Pro is unlocked across the whole app
/// while we shake the keyboard extension out + verify the new
/// funnels work end-to-end. Flip back to FALSE before the next
/// public TestFlight cycle that gates conversion.
///   · Free-tier scan, render, rizz, lines, chat, freeflow, lucien
///     gates all skip when this is true.
///   · LocalStoreService.setSubscribed(true) runs on app launch in
///     main.dart, so any code reading isSubscribed() returns true.
///
/// v225 — flipped back to FALSE. v224 killed the free roleplay grace
/// window + wired the Weekly subscription tier; both are no-ops while
/// the bypass is on. Every paywall is now live:
///   · Scan       — 1 free, then paywall every attempt
///   · Roleplay   — paywall on every free user's hold (no free 60s)
///   · Lucien     — paywall on step-in for free users
///   · Renders    — Pro-only on every attempt
///   · Rizz       — 1 free screenshot reply, then paywall;
///                  Lines + Chat are Pro-only outright
///   · Lessons    — Pro-only from Day 1
///
/// v353 (Charmr 4-tab build) — flipped back to TRUE. The scan flow
/// routes every non-Pro user to /paywall right after capture, and on a
/// dev / TestFlight build with no live RevenueCat products the paywall
/// has no way forward (BECOME HIM can't complete a purchase), so the
/// whole app was un-reachable behind it. TRUE force-sets the local
/// subscribed flag at launch, auto-bounces the paywall, and lands the
/// user on /home so the Missions / Practice / Texts / Progress tabs are
/// fully usable while testing.
///
/// **FLIP THIS BACK TO FALSE BEFORE SHIPPING A PAID BUILD.**
///
/// v358 — TRUE. PAYWALL OFF for this build (ships FREE), per bro: "take the
/// paywall off for this next build and I'll get you to add it afterwards."
/// Paired with PurchaseConfig.enabled = false so RevenueCat never configures
/// and there is no subscription for App Review to test — a clean free app that
/// sidesteps the 2.1(b) "IAP not submitted" flag while we get approved past the
/// 4.3 strip.
///
/// TO PUT THE PAYWALL BACK (money build): set this to false AND
/// PurchaseConfig.enabled = true. The whole browse-then-pay model is still
/// wired — nothing else changes.
const kBypassPaywall = true;

/// FALSE — real, charging paywall for launch. X only dismisses (back to
/// browsing); the ONLY way past a paid feature is a real subscription. Apple's
/// reviewer gets past it with a Sandbox purchase (the subscription is reviewed
/// together with this first app submission), and real users pay for real once
/// it's live. This is the money paywall.
const kPaywallDemoUnlock = false;

/// TEMPORARY TESTING FLAG. When true, the splash ALWAYS routes to the
/// onboarding story on launch — even if the user has already onboarded — so we
/// can review the onboarding without deleting/reinstalling. Set back to FALSE
/// before shipping, otherwise real users see onboarding on every launch.
const kForceOnboarding = true;

/// Human-readable build tag shown tiny on the paywall so we can instantly
/// tell which build is actually installed on-device (TestFlight lag has
/// repeatedly made us debug a stale build). Bump this with every pubspec
/// build-number bump.
const kBuildTag = 'b371-onb';
