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
  static const bool enabled = false;

  /// RevenueCat public SDK key for iOS. Starts with `appl_`.
  static const iosApiKey     = 'appl_qLSVUdcrgjVeLZqNkuoOgaBCtOv';

  /// RevenueCat public SDK key for Android. Starts with `goog_`.
  static const androidApiKey = 'goog_cdoFAjjiwMkzsxNjPBwoKalEwkF';

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
    yearly:  'mirrorly_pro_yearly',
    rescue:  'mirrorly_pro_rescue',
  );

  /// RevenueCat package identifiers inside the current Offering.
  /// RevenueCat has built-in slot names (\$rc_weekly, \$rc_annual)
  /// for the two subscriptions — those are what we attach products
  /// to in the dashboard. The rescue one-time IAP is a custom
  /// package slot named `rescue` (see RC dashboard: the Play Store
  /// row shows `mirrorly_pro_rescue:rescue`).
  static const offering = (
    weeklyPackage:  '\$rc_weekly',
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
