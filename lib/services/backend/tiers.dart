/// THE FIVE-WORD LADDER USED TO LIVE HERE. It has been deleted, and
/// that deletion is the fix.
///
/// `kTiers` mapped rizz_elo.rating onto OBSERVER / INITIATE / CONTENDER
/// / DANGEROUS / HIM — the same five words the 60-day ascension ladder
/// uses for something completely different. So a man read INITIATE on
/// Home and OBSERVER on the ascension screen on the same afternoon, and
/// both screens were telling the truth.
///
/// Worse, the number underneath it was being written by two unrelated
/// systems: score-voice drifts it up to ±40 on every solo daily, and
/// battle-action swings it on every duel. Two meanings, one column, five
/// borrowed words.
///
/// Deleting `tierFor` is what makes the fix permanent. A comment saying
/// "don't render this" gets ignored inside a month; a function that no
/// longer exists cannot be called. Everything that used to ask for a
/// tier name now asks division.dart for a DIVISION (BRONZE III → LEGEND
/// I), and identity ranks come from standing.dart, where they are earned
/// in days and nothing else.
///
/// See standing.dart for the full table of which ladder owns which word.
library;

import 'dart:ui';

/// Neon. Kept because half the app's "good" states are painted with it —
/// the summit of the paywall ladder, a winning duel, a strong rubric
/// axis. It's a colour, not a rank.
const kNeon = Color(0xFF2EE87A);
