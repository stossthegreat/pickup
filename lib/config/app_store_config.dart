/// The app's numeric App Store ID (Apple's "Apple ID" for the app record).
///
/// Find it once the ImHim app exists in App Store Connect:
///   App Store Connect → your app → App Information → "Apple ID"
///   (a number like 6712345678). It's assigned the moment you create the
///   app record — you do NOT have to wait for the app to go live.
///
/// Fill this in and BOTH review paths — Settings → "Rate us" and the 5-star
/// review prompt — deep-link straight to the real ImHim listing's review tab.
///
/// While it's EMPTY (as now), both paths fall back to the NATIVE in-app review
/// prompt, which StoreKit auto-targets to whatever app is actually installed —
/// so it can never send a user to the wrong (old Mirrorly) app. The old
/// hard-coded ID (6762532788) has been removed. The whole review system stays
/// wired and ready; this is the only value to update when you have the ID.
const String kAppStoreId = '';
