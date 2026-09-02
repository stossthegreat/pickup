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

/// ══════════════════════════════════════════════════════════════════════
///  THE BUILD STAMP — so nobody ever debugs the wrong binary again
/// ══════════════════════════════════════════════════════════════════════
///
/// We lost a day to this. A fix went in, the device still showed the old
/// behaviour, and there was no way on the screen to tell whether the
/// build being tested actually contained the fix. Every conversation
/// after that was two people guessing.
///
/// This is shown in Settings. Read it off the phone before reporting
/// anything: if the number is lower than the build a fix landed in, the
/// phone does not have the fix and the report is about old code.
///
/// KEEP IT IN STEP WITH pubspec.yaml `version:`. There is no
/// package_info dependency in this project to derive it automatically,
/// and adding one to solve a two-line problem is not worth the
/// dependency — but it does mean this is hand-maintained, so it is
/// bumped in the same commit as the pubspec, every time.
const String kBuildNumber = '273';
const String kBuildVersion = '1.2.0';
