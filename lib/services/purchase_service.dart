import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/purchase_config.dart';
import 'analytics_service.dart';
import 'extra_service.dart';
import 'local_store_service.dart' show LocalStoreService, ProTier;
import 'trial_service.dart';

/// Single front-door for all billing operations.
///
/// Owns three things:
///   1. Initialising the RevenueCat SDK at app start with the right
///      platform key.
///   2. Loading the current Offering and surfacing localized prices +
///      the Package objects the paywall needs to call purchase().
///   3. Mirroring RevenueCat's entitlement state into our local
///      subscribed flag (LocalStoreService.setSubscribed) so the rest
///      of the app can keep using its existing synchronous check
///      points without awaiting a network round-trip.
///
/// RevenueCat is the source of truth — LocalStore is just a cache the
/// non-billing code reads. On every launch we refresh the cache from
/// the RC customer info, so a subscription cancelled from App Store
/// settings will correctly drop the user out of pro on next launch.
class PurchaseService {
  static bool _initialized = false;
  static PurchaseOfferings? _cached;

  /// Most recent purchase / restore failure, in human-readable form.
  /// Surfaced by the paywall as a toast so users (and reviewers, and us)
  /// know whether Android Play Billing said "product unavailable",
  /// "billing service disconnected", "item already owned", etc., instead
  /// of the old generic "Purchase could not complete" message that hid
  /// every Android-side cause.
  static String? lastErrorMessage;

  /// Diagnostic snapshot of the last RevenueCat fetch. Populated by
  /// loadOfferings() and surfaced via diagnose() so the paywall can show
  /// *exactly* what RC returned on this device — useful when "it works
  /// on iOS but not Android" and the user can't read adb logcat.
  static String? lastDiagnostic;

  /// Walk RevenueCat end-to-end and produce a one-paragraph summary of
  /// the SDK state on this device. Safe to call any time. The output
  /// is intentionally short so it fits in a snackbar.
  static Future<String> diagnose() async {
    final lines = <String>[];
    lines.add('Platform: ${Platform.isIOS ? "iOS" : "Android"}');
    lines.add('Configured: ${PurchaseConfig.isConfigured}');
    lines.add('Initialised: $_initialized');
    // WHICH KEY IS IN THIS BINARY. The Android sub was dead for a full
    // release because the goog_ key still pointed at the previous
    // RevenueCat project while iOS had already moved — and nothing
    // on-device said so. Fingerprint (never the whole key) so a
    // wrong-project build is identifiable from a screenshot.
    final key = Platform.isIOS
        ? PurchaseConfig.iosApiKey
        : PurchaseConfig.androidApiKey;
    lines.add('SDK key: ${key.length < 12
        ? (key.isEmpty ? "(empty)" : "(malformed, len ${key.length})")
        : "${key.substring(0, 5)}…${key.substring(key.length - 6)} "
            "(len ${key.length})"}');
    if (!_initialized) {
      lines.add('→ Init never ran. Check API key in purchase_config.dart.');
      return lines.join('\n');
    }
    try {
      final offerings = await Purchases.getOfferings();
      final cur = offerings.current;
      lines.add('Offerings.all keys: ${offerings.all.keys.toList()}');
      if (cur == null) {
        lines.add('→ No CURRENT offering. Publish a Default Offering in '
                  'RevenueCat dashboard and mark it Current.');
      } else {
        lines.add('Current offering: "${cur.identifier}"');
        lines.add('Packages: ${cur.availablePackages.length}');
        for (final p in cur.availablePackages) {
          lines.add('  · pkg "${p.identifier}" → '
                    '${p.storeProduct.identifier} '
                    '(${p.storeProduct.priceString})');
        }
        if (cur.availablePackages.isEmpty) {
          lines.add('→ Offering exists but has 0 packages. Attach products '
                    'in dashboard → Offerings → Default Offering.');
        }
        // WHAT THE APP IS LOOKING FOR, printed next to what it got.
        // A subscription that "isn't showing" is nearly always one
        // character out, or attached to an offering that isn't Current —
        // and neither is visible without seeing both lists side by side.
        lines.add('');
        lines.add('App expects (exact match, case-sensitive):');
        lines.add('  monthly → ${PurchaseConfig.productIds.monthly}');
        lines.add('  weekly  → ${PurchaseConfig.productIds.weekly}');
        lines.add('  annual  → ${PurchaseConfig.productIds.annual}');
        final ids =
            cur.availablePackages.map((p) => p.storeProduct.identifier);
        if (!ids.contains(PurchaseConfig.productIds.monthly)) {
          lines.add('→ MONTHLY NOT IN THIS OFFERING. Either the product id '
                    'differs from the line above, or it is not attached to '
                    'the CURRENT offering as a package, or the store has '
                    'not released it yet (App Store Connect must show it '
                    '"Ready to Submit" or better, and the Paid Apps '
                    'agreement must be active).');
        }
      }
    } catch (err) {
      lines.add('getOfferings threw: $err');
    }
    try {
      final info = await Purchases.getCustomerInfo();
      lines.add('Active entitlements: '
                '${info.entitlements.active.keys.toList()}');
      lines.add('Active subscriptions: ${info.activeSubscriptions.toList()}');
      lines.add('All purchased products: '
                '${info.allPurchasedProductIdentifiers.toList()}');
      lines.add('App user id: ${info.originalAppUserId}');
      final pro = info.entitlements.all[PurchaseConfig.proEntitlementId];
      lines.add('"pro" entitlement: '
                '${pro == null ? "NOT FOUND" : "active=${pro.isActive}, "
                    "product=${pro.productIdentifier}"}');
    } catch (err) {
      lines.add('getCustomerInfo threw: $err');
    }
    final out = lines.join('\n');
    lastDiagnostic = out;
    return out;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  INITIALISATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Call once at app start (main.dart). Safe to call even when no
  /// RevenueCat keys are configured yet — in that case this is a
  /// no-op and the rest of the app works as a dev stub.
  static Future<void> init() async {
    if (_initialized) return;
    if (!PurchaseConfig.isConfigured) return;

    final apiKey = Platform.isIOS
        ? PurchaseConfig.iosApiKey
        : PurchaseConfig.androidApiKey;
    if (apiKey.isEmpty) return;

    // Verbose logging in debug builds + on Android specifically. Android
    // Play Billing has a long list of failure modes (product not in any
    // active offering, sideloaded APK, test account not licensed, etc.)
    // and the only way to find out which one fired is the RC log line
    // tagged "[Purchases]" in adb logcat. iOS StoreKit fails much more
    // cleanly — keep its log noise low.
    final verbose = kDebugMode || Platform.isAndroid;
    await Purchases.setLogLevel(verbose ? LogLevel.debug : LogLevel.error);
    await Purchases.configure(PurchasesConfiguration(apiKey));
    _initialized = true;

    // v285 SAFETY NET — the TestFlight "sheet said Done but nothing
    // unlocked" bug. The StoreKit sheet can complete while the Flutter
    // purchasePackage() future hangs or resolves as cancelled (seen on
    // TestFlight builds where the sheet is presented by TestFlight
    // itself, not the app). When that happens the success path in
    // purchase() never runs, so the unlock flag never flips — silently.
    // RevenueCat still learns about the transaction out-of-band and
    // fires this listener, so mirror it into the local flag here.
    //
    // UNLOCK-ONLY on purpose: this listener never writes `false`.
    // Right after a purchase RC can briefly report no active
    // entitlement (propagation lag) and a false write here would
    // re-lock a user who just paid. Lock-downs stay where they are —
    // _refreshEntitlementCache() on launch + isProLive() reads.
    Purchases.addCustomerInfoUpdateListener((info) {
      final active = info.entitlements.active.isNotEmpty ||
          info.activeSubscriptions.isNotEmpty;
      if (active) {
        // ignore: discarded_futures
        LocalStoreService.setSubscribed(true);
      }
      // Mirror trial state on every push too, not just at launch. This
      // listener is what fires the moment a trial converts to paid, and
      // without it a man who converted kept the one-minute trial cap
      // until he next cold-started the app.
      // ignore: discarded_futures
      TrialService.setTrial(_isTrialFrom(info));
    });

    // Mirror current entitlement state into the local cache so a
    // cancellation-from-App-Store-settings correctly flips the app to
    // locked the next time it opens.
    await _refreshEntitlementCache();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  OFFERINGS (prices + packages)
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch the current RevenueCat Offering. By default re-hits RC every
  /// call so dashboard changes (newly published Offering, package
  /// added, product attached) show up the next time the paywall opens
  /// without needing an app restart. Pass `useCache: true` only when
  /// you've genuinely got a fresh load and want to skip the network.
  ///
  /// When the SDK isn't configured or the fetch fails, returns empty
  /// nulls for every slot so the paywall falls back to placeholder
  /// prices (real RC prices replace them whenever a real Offering
  /// arrives).
  static Future<PurchaseOfferings> loadOfferings({bool useCache = false}) async {
    if (useCache && _cached != null) return _cached!;
    if (!_initialized) return PurchaseOfferings.empty();

    try {
      final offerings = await Purchases.getOfferings();
      // Prefer the dashboard-marked Current offering. If nothing is
      // marked Current (common when the project has a single
      // non-default offering like the Android-only "Month/Apk"
      // offering visible in the RC dashboard), fall back to the
      // first offering in `offerings.all` so the paywall still gets
      // packages instead of leaving every price as "—".
      final current = offerings.current
          ?? (offerings.all.isNotEmpty ? offerings.all.values.first : null);
      if (current == null) {
        // Don't cache "no offerings at all" — let the next open retry.
        _cached = null;
        return PurchaseOfferings.empty();
      }

      Package? weekly;
      Package? monthly;
      Package? annual;
      Package? rescue;
      // A LIST, NOT TWO SLOTS. The old code bucketed packs as
      // `mins <= 10 → extra10` / `mins > 10 → extra20`, first one wins.
      // Adding a third pack meant 20 and 60 minutes fought for the same
      // slot and whichever the store listed first silently won. The
      // packs are now collected and sorted by size, so any number of
      // them can exist.
      final extras = <Package>[];

      // v285 — WEEKLY ONLY. The app sells exactly ONE subscription:
      // mirrorly_pro_weekly. The legacy monthly/yearly SKUs still
      // exist in the stores (long-standing subscribers keep their
      // access via restore/isProLive), but the paywall must NEVER
      // select or sell them. The v284 "leftovers" fallback is gone —
      // it could silently claim the monthly/yearly package as
      // "weekly" and sell the wrong product under a per-week label.
      // If the weekly package is genuinely missing from the current
      // offering, the paywall now shows "—" and the CTA surfaces the
      // diagnose() dialog instead of selling a dead SKU.
      for (final pkg in current.availablePackages) {
        final pkgId = pkg.identifier.toLowerCase();
        final prodId = pkg.storeProduct.identifier.toLowerCase();

        final isRescue =
               pkgId == PurchaseConfig.offering.rescuePackage.toLowerCase()
            || pkgId.contains('rescue')
            || prodId.contains('rescue');

        // Dead SKUs — monthly/yearly must never be matched, even by
        // the lenient weekly aliases below.
        final isDeadSku =
               pkgId.contains('month')  || prodId.contains('month')
            || pkgId.contains('annual') || prodId.contains('annual')
            || pkgId.contains('year')   || prodId.contains('year');

        final isWeekly = !isRescue && !isDeadSku && (
               pkgId == r'$rc_weekly'
            || prodId == PurchaseConfig.productIds.weekly
            || pkgId.contains('week')
            || prodId.contains('week')
            || prodId.contains('7day')
            || prodId.contains('7d'));

        // EXTRA packs — matched on the EXACT product identifier, never
        // a substring. `contains` matching is fine for choosing which
        // label to draw; it is not fine for choosing what to charge
        // someone for.
        final rawProd = pkg.storeProduct.identifier;
        if (PurchaseConfig.isExtra(rawProd)) {
          extras.add(pkg);
          continue;
        }

        // MONTHLY — whole product id only. The dead-SKU guard above
        // rejects anything containing "month" because the legacy
        // mirrorly monthly is still live for old subscribers; an exact
        // comparison is the only way to sell the new one without ever
        // being able to sell the old one by accident.
        if (monthly == null && rawProd == PurchaseConfig.productIds.monthly) {
          monthly = pkg;
          continue;
        }

        // ANNUAL — matched on the WHOLE product id, never a substring.
        // The dead-SKU guard above deliberately rejects anything with
        // "year"/"annual" in it because the legacy mirrorly_pro_yearly
        // is still live in both stores for existing subscribers. An
        // exact comparison is the only way to sell the new tier without
        // ever being able to sell the old one by accident.
        if (annual == null && rawProd == PurchaseConfig.productIds.annual) {
          annual = pkg;
          continue;
        }

        if (isRescue && rescue == null) {
          rescue = pkg;
        } else if (isWeekly && weekly == null) {
          weekly = pkg;
        }
        // Everything else (monthly, yearly, unknown) is deliberately
        // dropped on the floor.
      }

      extras.sort((a, b) => PurchaseConfig.minutesFor(a.storeProduct.identifier)
          .compareTo(PurchaseConfig.minutesFor(b.storeProduct.identifier)));
      _cached = PurchaseOfferings(
        weekly: weekly,
        monthly: monthly,
        annual: annual,
        rescue: rescue,
        extras: extras,
      );
      return _cached!;
    } catch (err) {
      // ignore: avoid_print
      print('[PurchaseService] loadOfferings failed: $err');
      _cached = null;
      return PurchaseOfferings.empty();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PURCHASE / RESTORE
  // ─────────────────────────────────────────────────────────────────────────

  /// Kick off the platform purchase sheet. Returns [PurchaseOutcome] —
  /// the caller translates that into UI feedback (success → route
  /// forward, cancelled → nothing, error → toast).
  ///
  /// On error, [lastErrorMessage] is set with a human-readable cause so
  /// the paywall can show it. Vital for Android — Play Billing has many
  /// failure modes (sideloaded APK, product not in any active offering,
  /// test account not licensed, item already owned, billing service
  /// disconnected) and the user / reviewer needs to see which one.
  static Future<PurchaseOutcome> purchase(Package pkg) async {
    lastErrorMessage = null;
    if (!_initialized) {
      lastErrorMessage = 'Store not configured.';
      return PurchaseOutcome.notConfigured;
    }
    // v285 HARD BLOCK — monthly/yearly are dead SKUs. loadOfferings()
    // already never surfaces them, but this is the last line of
    // defence: no code path may ever charge a user for them again.
    final blockPkg  = pkg.identifier.toLowerCase();
    final blockProd = pkg.storeProduct.identifier.toLowerCase();
    // THE LIVE ANNUAL IS NOT A DEAD SKU. This guard matches on the
    // substring "annual", so the new `imhim_pro_annual` tripped it and
    // came back "This plan is no longer available" — a product that
    // could be listed, selected and never bought. The exemption is an
    // EXACT id comparison, so the legacy mirrorly_pro_yearly it was
    // written to stop is still stopped.
    final isLiveAnnual =
        pkg.storeProduct.identifier == PurchaseConfig.productIds.annual ||
        pkg.storeProduct.identifier == PurchaseConfig.productIds.monthly;
    final isDeadSku = !isLiveAnnual && (
           blockPkg.contains('month')  || blockProd.contains('month')
        || blockPkg.contains('annual') || blockProd.contains('annual')
        || blockPkg.contains('year')   || blockProd.contains('year'));
    if (isDeadSku) {
      lastErrorMessage = 'This plan is no longer available.';
      AnalyticsService.purchaseFailed(pkg.identifier, 'dead_sku_blocked');
      return PurchaseOutcome.error;
    }
    AnalyticsService.purchaseStarted(pkg.identifier);
    try {
      // Purchases.purchasePackage ONLY returns without throwing when the
      // StoreKit transaction actually completed — cancellation, failure,
      // and pending-approval all throw (caught below). So a clean return
      // here IS a paying user. We must NOT gate the unlock on the `pro`
      // entitlement being active in THIS immediate CustomerInfo: in
      // sandbox / TestFlight (and occasionally prod) the entitlement
      // propagates a beat AFTER the transaction, so the strict check was
      // failing a completed purchase and unlocking nothing. Trust the
      // completed transaction; the ongoing isProLive()/cache reconcile
      // the true entitlement state on every subsequent read.
      final result = await Purchases.purchasePackage(pkg);

      // ── EXTRA: GRANT THE MINUTES HERE AND NOWHERE ELSE ──────────────
      //
      // This is the line the old rescue path was missing. It correctly
      // identified a consumable, correctly declined to flip the
      // subscription flag — and then credited nothing, so a man could
      // pay and receive literally nothing. Putting the grant inside the
      // transaction handler means no call site can forget it and no
      // future screen can get the minute count wrong: the amount comes
      // from PurchaseConfig.extraMinutes, which is the single source of
      // truth.
      //
      // Keyed by the store transaction id so a retry, a resumed app or
      // a replayed CustomerInfo can never credit the same payment
      // twice. Free minutes are real OpenAI spend.
      //
      // Note it grants BEFORE any entitlement read below: a consumable
      // grants no entitlement at all, and consumables cannot be
      // restored under Play Billing 8, so this local write is the only
      // record that will ever exist. It has to happen first.
      final extraMinutes =
          PurchaseConfig.minutesFor(pkg.storeProduct.identifier);
      if (extraMinutes > 0) {
        // VERIFY-ON-FIRST-BUILD: `storeTransaction.transactionIdentifier`
        // is the only symbol in this change that couldn't be checked
        // against the SDK offline. If it's named differently in
        // purchases_flutter 10.8, this is a COMPILE error — loud, cheap,
        // and one line to fix. It can never fail silently, and
        // ExtraService.grant() still credits correctly with a null id.
        await ExtraService.grant(
          minutes: extraMinutes,
          txnId: result.storeTransaction.transactionIdentifier,
        );
        AnalyticsService.purchaseCompleted(pkg.identifier);
        return PurchaseOutcome.success;
      }

      // The rescue product is a one-time consumable, not a subscription —
      // don't flip the "subscribed" flag for it (it grants credits only).
      final isRescue =
             pkg.identifier.toLowerCase() ==
                 PurchaseConfig.offering.rescuePackage.toLowerCase()
          || pkg.identifier.toLowerCase().contains('rescue')
          || pkg.storeProduct.identifier.toLowerCase().contains('rescue');
      if (!isRescue) {
        await LocalStoreService.setSubscribed(true);
        // Start the lag grace. RevenueCat can take a beat to publish the
        // entitlement after a completed transaction (routine in sandbox,
        // seen in prod), and the resume refresh below must not read that
        // gap as "cancelled" and re-lock a man who just paid.
        _paidAt = DateTime.now();
      }
      // Keep the entitlement read purely for telemetry — never to gate.
      //
      // purchases_flutter 9.0.0 changed purchasePackage's return type from
      // CustomerInfo to PurchaseResult, which wraps the CustomerInfo
      // alongside the StoreTransaction. This is the ONLY call site in the
      // app the Billing 8 upgrade actually breaks.
      final entActive = result
          .customerInfo.entitlements.all[PurchaseConfig.proEntitlementId]
          ?.isActive ?? false;
      AnalyticsService.purchaseCompleted(pkg.identifier);
      if (!entActive && !isRescue) {
        // Completed transaction but entitlement not yet visible — expected
        // sandbox lag. Logged (not surfaced) so we can watch prod for it.
        AnalyticsService.purchaseFailed(pkg.identifier, 'entitlement_lag_ok');
      }
      return PurchaseOutcome.success;
    } on PlatformException catch (err) {
      // purchases_flutter throws PlatformException with the underlying
      // RevenueCat error code attached as `details`. Surface both the
      // user-friendly message and the code so we can grep logs.
      final code = PurchasesErrorHelper.getErrorCode(err);
      // ignore: avoid_print
      print('[PurchaseService] purchase failed: code=$code msg=${err.message}');
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        lastErrorMessage = null;
        AnalyticsService.purchaseCancelled(pkg.identifier);
        return PurchaseOutcome.cancelled;
      }
      // SAFETY NET: the purchase threw (product already owned, receipt
      // still validating, StoreKit hiccup) — but the user may ALREADY
      // have an active subscription. Extremely common in sandbox when
      // re-testing weekly on the same Apple ID: buying again throws
      // "already purchased" even though the sub is live. Check for an
      // active entitlement/subscription and, if found, unlock — they've
      // paid.
      if (await _hasActiveSubNow()) {
        await LocalStoreService.setSubscribed(true);
        AnalyticsService.purchaseCompleted(pkg.identifier);
        return PurchaseOutcome.success;
      }
      // KEEP THE STORE'S OWN WORDS. _humanise() returns one fixed
      // sentence per error code, which threw away the single most
      // useful string in the whole failure: Play's DebugMessage. On
      // Android a DEVELOPER_ERROR can mean "Please ensure the app is
      // signed correctly", "Expired Product details", or a handful of
      // other things — same code, completely different fixes. Without
      // the raw text you cannot tell them apart, which is exactly the
      // hole we spent a release falling into.
      lastErrorMessage = _withRaw(_humanise(code, err.message), code, err);
      AnalyticsService.purchaseFailed(pkg.identifier, code?.name ?? 'unknown');
      return PurchaseOutcome.error;
    } catch (err) {
      // ignore: avoid_print
      print('[PurchaseService] purchase failed (unknown): $err');
      if (await _hasActiveSubNow()) {
        await LocalStoreService.setSubscribed(true);
        AnalyticsService.purchaseCompleted(pkg.identifier);
        return PurchaseOutcome.success;
      }
      lastErrorMessage = err.toString();
      AnalyticsService.purchaseFailed(pkg.identifier, 'exception');
      return PurchaseOutcome.error;
    }
  }

  /// True when RevenueCat currently reports ANY active entitlement or
  /// subscription for this user. Used as the post-throw safety net so a
  /// "product already owned" error on an actually-active sub still
  /// unlocks. Best-effort with a short timeout.
  static Future<bool> _hasActiveSubNow() async {
    try {
      final info = await Purchases.getCustomerInfo()
          .timeout(const Duration(seconds: 3));
      return info.entitlements.active.isNotEmpty ||
          info.activeSubscriptions.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Restore previously-purchased entitlements. Required by App Store
  /// review. Same return type as [purchase].
  static Future<PurchaseOutcome> restore() async {
    if (!_initialized) return PurchaseOutcome.notConfigured;
    try {
      final info = await Purchases.restorePurchases();
      // Entitlement OR any active subscription — same resilience as
      // purchase()/isProLive() so a weekly SKU that isn't mapped to the
      // `pro` entitlement still restores.
      final entActive = info.entitlements.all[PurchaseConfig.proEntitlementId]
          ?.isActive ?? false;
      final isPro = entActive ||
          info.entitlements.active.isNotEmpty ||
          info.activeSubscriptions.isNotEmpty;
      await LocalStoreService.setSubscribed(isPro);
      AnalyticsService.restoreCompleted(isPro);
      return isPro ? PurchaseOutcome.success : PurchaseOutcome.noPriorPurchases;
    } catch (_) {
      return PurchaseOutcome.error;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  INTERNAL
  // ─────────────────────────────────────────────────────────────────────────

  /// When the last completed transaction landed. Guards the window in
  /// which RevenueCat may not yet be reporting the entitlement.
  static DateTime? _paidAt;

  /// Throttle for [refreshOnResume] — a man tabbing in and out shouldn't
  /// fire a store round-trip every time.
  static DateTime? _lastResumeRefresh;

  /// How long after a completed purchase we refuse to write `false`.
  static const _lagGrace = Duration(minutes: 10);

  /// Re-check entitlements when the app comes back to the foreground.
  ///
  /// THE LEAK THIS CLOSES: [PaywallGate.isPro] is cache-first, and the
  /// cache was only ever repainted `false` by [_refreshEntitlementCache],
  /// which only runs inside [init] — i.e. on a COLD launch. iOS keeps apps
  /// resident for days, so a man who cancelled (or whose card failed) kept
  /// the full paid app until he happened to fully restart it. That is the
  /// one real way this app could hand out more than the week Apple sold.
  ///
  /// Throttled to 15 minutes and identical on both platforms — Play and
  /// StoreKit lapse the same way and neither told us about it.
  static Future<void> refreshOnResume() async {
    if (!_initialized) return;
    final now = DateTime.now();
    if (_lastResumeRefresh != null &&
        now.difference(_lastResumeRefresh!) < const Duration(minutes: 15)) {
      return;
    }
    _lastResumeRefresh = now;
    await _refreshEntitlementCache();
  }

  /// Is the `pro` entitlement currently running as a free trial?
  ///
  /// The store gives one bit for access — active or not — so this is
  /// the only way to tell a trial apart from a paid week. PeriodType
  /// comes straight off RevenueCat: `trial` for a free trial, `intro`
  /// for a discounted introductory period (which IS paid, so it gets
  /// the full allowance), `normal` for an ordinary renewal.
  static bool _isTrialFrom(CustomerInfo info) {
    final ent = info.entitlements.all[PurchaseConfig.proEntitlementId];
    if (ent == null || !ent.isActive) return false;
    return ent.periodType == PeriodType.trial;
  }

  static Future<void> _refreshEntitlementCache() async {
    try {
      final info = await Purchases.getCustomerInfo();
      // Entitlement OR active subscription (see purchase()/isProLive()).
      final entActive = info.entitlements.all[PurchaseConfig.proEntitlementId]
          ?.isActive ?? false;
      final isPro = entActive ||
          info.entitlements.active.isNotEmpty ||
          info.activeSubscriptions.isNotEmpty;
      // Unlocking is always safe. Re-LOCKING inside the post-purchase lag
      // window is not — that's the "I just paid and it locked me out" bug,
      // and running this on every resume would have made it far easier to
      // hit than it was on cold launch alone.
      if (!isPro && _paidAt != null &&
          DateTime.now().difference(_paidAt!) < _lagGrace) {
        return;
      }
      await LocalStoreService.setSubscribed(isPro);
      await TrialService.setTrial(isPro && _isTrialFrom(info));
    } catch (_) {
      // Network fail on launch is not fatal — the cached flag stands.
    }
  }

  /// Hit RevenueCat live for the *current* entitlement state. The
  /// cached `LocalStoreService.isSubscribed` flag exists for fast
  /// synchronous reads, but it can lag behind RevenueCat — sandbox /
  /// TestFlight purchases sometimes flip the entitlement only after a
  /// retry, and a paid user who opens the app on a cold network goes
  /// through the catch path in init(). Bro: "I've got a sub and it's
  /// locking me out." This call queries RC directly and as a side
  /// effect repaints the local cache so subsequent synchronous reads
  /// agree.
  ///
  /// v279 — currently-active subscription tier. Used by the cap logic
  /// so annual subscribers get a 30-day rolling reset window while
  /// weekly subscribers get the standard 7-day window. Cached locally
  /// after each RevenueCat hit so cap reads stay synchronous.
  static Future<ProTier> liveTier() async {
    if (!_initialized) return ProTier.none;
    try {
      final info = await Purchases.getCustomerInfo()
          .timeout(const Duration(seconds: 2));
      // The `activeSubscriptions` set contains store product
      // identifiers — match by canonical RC slot name first, then by
      // contains() on the legacy `mirrorly_pro_yearly` / similar.
      for (final sub in info.activeSubscriptions) {
        final lower = sub.toLowerCase();
        if (lower.contains('annual') ||
            lower.contains('yearly') ||
            lower.contains('year')) {
          await LocalStoreService.setCachedTier(ProTier.annual);
          return ProTier.annual;
        }
        // MONTHLY WAS MISSING, AND IT IS THE MAIN SKU NOW.
        // imhim_pro_monthly matched neither branch, fell out of the
        // loop, and got cached as ProTier.none — "no subscription" —
        // for a man who is paying us every month. It happened to behave
        // (none takes the 7-day window, which is what monthly should
        // have) but it was false on disk and one `if (tier == none)`
        // away from locking a paying customer out.
        if (lower.contains('monthly') || lower.contains('month')) {
          await LocalStoreService.setCachedTier(ProTier.monthly);
          return ProTier.monthly;
        }
        if (lower.contains('weekly') || lower.contains('week')) {
          await LocalStoreService.setCachedTier(ProTier.weekly);
          return ProTier.weekly;
        }
      }
      await LocalStoreService.setCachedTier(ProTier.none);
      return ProTier.none;
    } catch (_) {
      return ProTier.none;
    }
  }

  /// Returns null when RC isn't initialised or the call failed — the
  /// caller falls back to the cached flag in that case.
  static Future<bool?> isProLive() async {
    if (!_initialized) return null;
    try {
      final info = await Purchases.getCustomerInfo();
      // Same resilience as purchase(): treat an active subscription as
      // pro even when the `pro` entitlement hasn't flipped (weekly SKU
      // not mapped to the entitlement, or RC lag). An active sub = a
      // paying user, so the whole app must unlock.
      final entActive = info.entitlements.all[PurchaseConfig.proEntitlementId]
          ?.isActive ?? false;
      final isPro = entActive ||
          info.entitlements.active.isNotEmpty ||
          info.activeSubscriptions.isNotEmpty;
      await LocalStoreService.setSubscribed(isPro);
      // v279 — also detect tier (weekly vs annual) and cache it so
      // the cap window helpers can read it synchronously without
      // hitting RC. Both calls share the same RC payload so it's a
      // single network round-trip.
      ProTier tier = ProTier.none;
      if (isPro) {
        for (final sub in info.activeSubscriptions) {
          final lower = sub.toLowerCase();
          if (lower.contains('annual') ||
              lower.contains('yearly') ||
              lower.contains('year')) {
            tier = ProTier.annual;
            break;
          }
          if (lower.contains('monthly') || lower.contains('month')) {
            tier = ProTier.monthly;
            break;
          }
          if (lower.contains('weekly') || lower.contains('week')) {
            tier = ProTier.weekly;
            break;
          }
        }
      }
      await LocalStoreService.setCachedTier(tier);
      return isPro;
    } catch (_) {
      return null;
    }
  }

  /// Append the store's verbatim reason under the friendly sentence.
  ///
  /// The friendly line is what a real user should read; everything after
  /// the rule is for us. `err.message` is RevenueCat's message and
  /// `err.details` carries the underlying store payload — on Android
  /// that's where Play's own DebugMessage ends up, and it names the
  /// actual cause instead of leaving us to guess between several very
  /// different fixes that share one error code.
  static String _withRaw(
      String friendly, PurchasesErrorCode? code, PlatformException err) {
    final bits = <String>[
      if (code != null) 'code: ${code.name}',
      if (err.code.isNotEmpty) 'platform: ${err.code}',
      if (err.message != null && err.message!.isNotEmpty)
        'message: ${err.message}',
      if (err.details != null) 'details: ${err.details}',
    ];
    if (bits.isEmpty) return friendly;
    return '$friendly\n\n── store said ──\n${bits.join('\n')}';
  }

  /// Map a RevenueCat error code + raw message into something a user
  /// (and a reviewer, and us) can read. Store names are
  /// platform-gated — Apple rejects copy that names "Google Play"
  /// and vice versa, even in error toasts.
  static String _humanise(PurchasesErrorCode? code, String? raw) {
    final store      = Platform.isIOS ? 'App Store'         : 'Play Store';
    final account    = Platform.isIOS ? 'Apple ID'          : 'Google account';
    final sideloadFix = Platform.isIOS
        ? 'install via TestFlight.'
        : 'install via Play Store internal testing track.';
    switch (code) {
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return 'Product not available in your store. The offering may '
               'not be live yet.';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'You already own this. Try Restore Purchases.';
      case PurchasesErrorCode.storeProblemError:
        return 'The $store reported a problem. Try again.';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are blocked on this device — check parental '
               'controls or sign in to a $account that has IAP enabled.';
      case PurchasesErrorCode.purchaseInvalidError:
        return 'The store rejected the purchase as invalid.';
      case PurchasesErrorCode.networkError:
        return 'Network error. Check your connection and try again.';
      // CODE 17 — the App Store Connect In-App Purchase Key (.p8) has
      // never been uploaded to RevenueCat, so Apple refuses the purchase
      // at the server-validation step. Nothing about it is the user's
      // fault or the user's problem, so he gets a plain apology and we
      // keep the full diagnostic behind the developer sheet.
      case PurchasesErrorCode.invalidAppleSubscriptionKeyError:
        return 'Subscriptions aren\'t available right now — this one\'s on '
            'us, not you. Nothing was charged. Try again shortly.';
      case PurchasesErrorCode.invalidCredentialsError:
        return 'The store rejected our credentials. Nothing was charged — '
            'we\'re on it.';
      case PurchasesErrorCode.configurationError:
        return 'Billing not configured on this build — $sideloadFix';
      case PurchasesErrorCode.unsupportedError:
        return 'Billing isn\'t supported on this device or build.';
      case PurchasesErrorCode.invalidReceiptError:
        return 'The store returned an invalid receipt.';
      case PurchasesErrorCode.invalidAppUserIdError:
        return 'Invalid app user ID.';
      default:
        return raw ?? 'Purchase failed (${code?.name ?? "unknown"}).';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DTOs
// ═══════════════════════════════════════════════════════════════════════════

enum PurchaseOutcome { success, cancelled, error, noPriorPurchases, notConfigured }

/// Snapshot of the three products the paywall needs:
///   weekly / annual subscriptions + the rescue one-time IAP.
/// Nulls = package isn't in the current offering yet; the paywall
/// shows a dash for that slot until RC delivers it.
class PurchaseOfferings {
  final Package? weekly;
  final Package? monthly;
  final Package? annual;
  final Package? rescue;

  /// EXTRA voice-minute packs, smallest first. Empty when the store
  /// hasn't published them — on iOS that's the normal state until the
  /// consumables are created in App Store Connect, and every surface
  /// must say so rather than render a button that can't transact.
  final List<Package> extras;

  const PurchaseOfferings({
    required this.weekly,
    this.monthly,
    required this.annual,
    required this.rescue,
    this.extras = const [],
  });

  factory PurchaseOfferings.empty() => const PurchaseOfferings(
    weekly: null, annual: null, rescue: null,
  );

  /// Back-compat accessors for the two-pack surfaces written before
  /// there could be three. Smallest and largest, so they keep meaning
  /// "the cheap one" and "the good-value one" however many exist.
  Package? get extra10 => extras.isEmpty ? null : extras.first;
  Package? get extra20 => extras.length < 2 ? null : extras.last;

  /// True when at least one pack can actually be bought right now.
  bool get hasExtra => extras.isNotEmpty;
}
