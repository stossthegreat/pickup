/// The app's numeric App Store ID (Apple's "Apple ID" for the app record).
///
/// From the live listing URL:
///   https://apps.apple.com/gb/app/imhim-rizz-master-rizz/id6798386010
///
/// WHY THIS BEING EMPTY COST EVERY iOS REVIEW.
///
/// With no ID, both review paths fell back to `requestReview()` — the
/// NATIVE StoreKit sheet. Apple rate-limits that to roughly three
/// prompts per user per YEAR and, past the cap, it does not fail, throw
/// or return anything: it silently draws nothing. So a man tapped five
/// stars, tapped "Write a Review", and the card just closed. It looked
/// like a working button and it was a no-op.
///
/// With the ID set, `openStoreListing(appStoreId:)` deep-links straight
/// to the listing's review composer. That path is NOT rate-limited —
/// it is just a URL — so the button does what it says every single time.
const String kAppStoreId = '6798386010';
