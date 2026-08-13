/// RevenueCat public SDK keys + product/entitlement identifiers.
///
/// ──────────────────────────────────────────────────────────────────────
/// WHAT YOU NEED TO DO BEFORE PAYMENT WORKS
/// ──────────────────────────────────────────────────────────────────────
/// 1. Log in to https://app.revenuecat.com
/// 2. Create a project "Mirrorly" if you haven't already.
/// 3. Project Settings → API Keys — copy:
///      - "Public SDK Key" for the iOS app  (starts with  appl_…)
///      - "Public SDK Key" for the Android app (starts with  goog_…)
///    Paste them into the two consts below.
/// 4. In RevenueCat: Products → Add each App Store / Play product by
///    the exact identifier strings in [PurchaseConfig.productIds].
/// 5. Entitlements → Create `pro` → attach both the weekly and the
///    annual subscription products to it. (The 20-credit pack does
///    NOT entitle `pro` — it's a consumable credit grant, handled
///    separately.)
/// 6. Offerings → Default Offering → attach all three products as
///    packages with identifiers that match the `packageId` values
///    in [PurchaseConfig.offering].
/// 7. Publish the offering. Rebuild the Flutter app.
///
/// Until keys are filled in the app still runs — the paywall just
/// shows "—" for prices and the CTA is disabled. No hardcoded prices
/// ever ship to the store.
/// ──────────────────────────────────────────────────────────────────────
class PurchaseConfig {
  /// ── MASTER SWITCH — RevenueCat billing ──────────────────────────────────
  /// TRUE = RevenueCat configures at launch and sells the weekly subscription.
  /// This is a PAID app: the paywall is live (kBypassPaywall = false in
  /// dev_flags.dart), users browse freely, and any paid action opens the
  /// paywall to purchase `imhim_pro_weekly`.
  ///
  /// IMPORTANT — for the purchase to complete, the product must be fetchable
  /// from App Store Connect. If you saw "CONFIGURATION_ERROR (23)" it means the
  /// product isn't live on Apple's side yet (Paid Apps agreement unsigned, or
  /// the subscription not "Ready to Submit"). That is an App Store Connect
  /// setup issue, NOT a code issue — fix it there and error 23 disappears.
  static const bool enabled = true;

  /// RevenueCat public SDK key for iOS. Starts with `appl_`.
  static const iosApiKey     = 'appl_qLSVUdcrgjVeLZqNkuoOgaBCtOv';

  /// RevenueCat public SDK key for Android. Starts with `goog_`.
  ///
  /// THE ANDROID BILLING BUG (fixed here): when the app moved to the new
  /// RevenueCat project, only the iOS `appl_` key was swapped. This one
  /// still pointed at the OLD project — so on Android the SDK configured
  /// fine, `getOfferings()` succeeded, and came back with the old
  /// project's offerings, which contain no `imhim_pro_weekly` and no
  /// products registered against the `com.imhim.app` package. Zero
  /// packages survived, `_offerings.weekly` stayed null, and the paywall
  /// bailed at its `pkg == null` branch with "Subscription isn't
  /// available right now" WITHOUT ever calling purchasePackage(). iOS
  /// worked the whole time because its key was already correct.
  ///
  /// Both keys must come from the SAME RevenueCat project — the one that
  /// owns `imhim_pro_weekly`. These are publishable SDK keys (safe to
  /// ship); the secret key never belongs in the app.
  static const androidApiKey = 'goog_pvyTRZSUsrXkGWCDBCtnUXEBDkk';

  /// The entitlement identifier that grants Mirrorly Pro. Configured
  /// in RevenueCat dashboard → Entitlements. Both weekly and annual
  /// subscriptions attach to this entitlement.
  static const proEntitlementId = 'pro';

  /// Product identifiers — MUST match exactly what's in App Store
  /// Connect and Google Play Console.
  ///
  ///   mirrorly_pro_weekly    →  Weekly subscription ($6.99/wk)
  ///   mirrorly_pro_yearly    →  Annual subscription ($139.99/yr,
  ///                             Play Console registered the yearly
  ///                             base plan as `mirrorly_pro_yearly`,
  ///                             not `_annual`)
  ///   mirrorly_pro_rescue    →  Rescue one-time IAP (Android only;
  ///                             iOS rescue product is not yet
  ///                             approved on App Store Connect)
  /// THREE PRODUCTS, EACH WITH A DIFFERENT JOB.
  ///
  ///   weekly   impulse. The man who wants to try it this week.
  ///   monthly  the real one. This is a 60-DAY product — selling a
  ///            sixty-day transformation on a seven-day plan asks a man
  ///            to re-decide eight times during the thing you told him
  ///            takes two months, and weekly plans churn hardest at
  ///            exactly the point the habit hasn't formed yet. The term
  ///            should match the promise.
  ///   pack     bought voice minutes. NOT a tier and never a way past
  ///            the one-shot — see [voiceMinutesPerPack].
  static const productIds = (
    weekly:  'imhim_pro_weekly',
    monthly: 'imhim_pro_monthly',
    yearly:  'mirrorly_pro_yearly',   // retired; kept so old receipts parse
    rescue:  'mirrorly_pro_rescue',   // the voice-minute pack
  );

  /// How many extra voice minutes one pack grants.
  ///
  /// Voice is the ONLY thing in the app with a real marginal cost, so
  /// this pack exists for unit economics: a heavy user should fund his
  /// own usage. Sized against the 14-minute weekly allowance so a pack
  /// is a meaningful top-up rather than a token.
  ///
  /// IT BUYS PRACTICE MINUTES AND NOTHING ELSE. It can never buy another
  /// attempt at the Daily, a battle re-run, or any ranked surface. The
  /// entire worth of a score on this app's boards is that everyone got
  /// exactly one shot at the same woman on the same day — the moment a
  /// number can be bought, every number becomes worthless, including the
  /// honest ones. Selling practice is selling the thing that costs us
  /// money. Selling a retry would be selling the leaderboard.
  static const int voiceMinutesPerPack = 30;

  /// RevenueCat package identifiers inside the current Offering.
  /// RevenueCat has built-in slot names (\$rc_weekly, \$rc_annual)
  /// for the two subscriptions — those are what we attach products
  /// to in the dashboard. The rescue one-time IAP is a custom
  /// package slot named `rescue` (see RC dashboard: the Play Store
  /// row shows `mirrorly_pro_rescue:rescue`).
  static const offering = (
    weeklyPackage:  '\$rc_weekly',
    monthlyPackage: '\$rc_monthly',
    annualPackage:  '\$rc_annual',
    rescuePackage:  'rescue',
  );

  /// Convenience — true only when RevenueCat is [enabled] AND keys are
  /// present. Every billing path (init, offerings, purchase, restore,
  /// entitlement checks) is already guarded on this, so flipping [enabled]
  /// to false makes the entire RevenueCat SDK go dormant: `init()` returns
  /// early, nothing is ever configured, and no store calls are made. The
  /// app then runs purely on the kBypassPaywall allowance.
  static bool get isConfigured =>
      enabled && (iosApiKey.isNotEmpty || androidApiKey.isNotEmpty);
}
