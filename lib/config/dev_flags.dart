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
/// v357 — SUBMISSION BUILD. FALSE. This is the real App Store paywall.
///
/// The model, exactly as intended:
///   1. The user lands straight in the app after onboarding (never walled at
///      the door) — no paywall blocks entry, so nobody can get "stuck".
///   2. Every paid ACTION they press — opening a girl, a mission, a voice call,
///      a rizz screenshot — opens the paywall.
///   3. The paywall is DISMISSIBLE: the X (and the system back gesture) closes
///      it and drops them back where they were to keep browsing. They just
///      can't use the paid feature until they subscribe.
///   4. On a real purchase, RevenueCat activates the `pro` entitlement and the
///      whole app unlocks; the gate the user tapped opens immediately.
///
/// For the purchase to COMPLETE the product must be fetchable from App Store
/// Connect (Paid Apps agreement signed, imhim_pro_weekly "Ready to Submit"),
/// else RevenueCat returns error 23 — an App Store Connect fix, not a code fix.
const kBypassPaywall = false;

/// FALSE — real, charging paywall for launch. X only dismisses (back to
/// browsing); the ONLY way past a paid feature is a real subscription. Apple's
/// reviewer gets past it with a Sandbox purchase (the subscription is reviewed
/// together with this first app submission), and real users pay for real once
/// it's live. This is the money paywall.
const kPaywallDemoUnlock = false;

/// Human-readable build tag shown tiny on the paywall so we can instantly
/// tell which build is actually installed on-device (TestFlight lag has
/// repeatedly made us debug a stale build). Bump this with every pubspec
/// build-number bump.
const kBuildTag = 'b362-store';
