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
  static const productIds = (
    weekly:  'imhim_pro_weekly',   // ImHim weekly sub (primary)
    // NEW — the annual tier. Matched on this EXACT id and nothing else.
    // The stores still carry the legacy `mirrorly_pro_yearly`, which
    // long-standing subscribers keep access through but which must
    // never be sold again; a `contains('year')` match would pick it up
    // and charge someone for the wrong product, so the matcher in
    // PurchaseService compares the whole string.
    // THE TRIAL LIVES ON MONTHLY, NOT WEEKLY. A 3-day free trial in
    // front of a WEEKLY sub gives away nearly half the first billing
    // period; in front of a monthly it is a tenth of it. It is also the
    // tier we actually want him on — 34% cheaper per week than weekly,
    // and it survives the first Sunday he forgets to open the app.
    monthly: 'imhim_pro_monthly',
    annual:  'imhim_pro_annual',
    yearly:  'mirrorly_pro_yearly',
    rescue:  'mirrorly_pro_rescue',
    extra10: 'imhim_extra_10',     // 10 voice minutes, consumable
    extra20: 'imhim_extra_20',     // 20 voice minutes, consumable
    extra60: 'imhim_extra_60',     // 60 voice minutes, consumable
  );

  // ── EXTRA — voice-minute packs ──────────────────────────────────────
  //
  // MATCHED BY EXACT PRODUCT ID, NEVER BY SUBSTRING. The weekly matcher
  // above uses lenient `contains` checks because it has to survive an
  // offering where the package slot was named inconsistently, and it
  // needs three separate dead-SKU guards to stop it selling the wrong
  // thing. That's a pattern to contain, not to copy: a fuzzy match on a
  // paid product is a bug that charges people. These are exact.
  //
  // The map IS the source of truth for how many minutes a purchase
  // grants, so no call site can decide that for itself and get it
  // wrong. PurchaseService reads it directly and grants inside the
  // transaction handler.
  //
  // `mirrorly_pro_rescue` is the legacy Android-only consumable — it's
  // already approved on Play, so it stays recognised and maps to 20
  // minutes. iOS has no approved consumable yet; until the two new ones
  // are created in App Store Connect the packs simply don't appear and
  // the sheet says so rather than showing a dead button.
  static const extraMinutes = <String, int>{
    'imhim_extra_10': 10,
    'imhim_extra_20': 20,
    // The pack for the man who has already run out twice. He is the
    // highest-intent buyer the app will ever have and 20 minutes was
    // the ceiling on what he could give us.
    'imhim_extra_60': 60,
    'mirrorly_pro_rescue': 20,
  };

  /// Minutes a product grants, or 0 if it isn't an EXTRA pack.
  static int minutesFor(String productId) =>
      extraMinutes[productId.toLowerCase()] ?? 0;

  static bool isExtra(String productId) => minutesFor(productId) > 0;

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
    extra10Package: 'extra10',
    extra20Package: 'extra20',
    extra60Package: 'extra60',
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
