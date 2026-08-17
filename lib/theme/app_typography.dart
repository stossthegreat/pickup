import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// ImHim typography — one voice. Inter everywhere, tight and heavy for
/// display, regular for body, mono for measurements.
///
/// The italic Playfair serif used to carry every headline in the app.
/// It now survives in exactly ONE place — the ImHim wordmark in the
/// masthead (see widgets/common/imhim_wordmark.dart) — because that's
/// the logo. Everywhere else it read as a different app bolted onto
/// this one. Display styles keep their names so call sites don't move;
/// only the letterforms changed.
abstract final class AppTypography {
  // ── Display (sans, heavy) ────────────────────────────────────────────────

  static TextStyle get displayXL => GoogleFonts.inter(
    fontSize: 60, fontWeight: FontWeight.w900,
    letterSpacing: -3.0, color: AppColors.textPrimary, height: 1.0,
  );

  static TextStyle get display => GoogleFonts.inter(
    fontSize: 44, fontWeight: FontWeight.w900,
    letterSpacing: -2.0, color: AppColors.textPrimary, height: 1.04,
  );

  static TextStyle get h1 => GoogleFonts.inter(
    fontSize: 32, fontWeight: FontWeight.w900,
    letterSpacing: -1.1, color: AppColors.textPrimary, height: 1.1,
  );

  /// Kept for call-site compatibility — no longer italic, just lighter.
  static TextStyle get h1Italic => GoogleFonts.inter(
    fontSize: 32, fontWeight: FontWeight.w700,
    letterSpacing: -0.9, color: AppColors.textPrimary, height: 1.1,
  );

  /// THE TAB MASTHEAD — one object, three tabs.
  ///
  /// This is the old RIZZ BATTLES header at twice the size. That header
  /// was tracked caps at 15pt and it was the best-looking type in the
  /// app; the other two tabs used a lowercase 32pt sentence, so the
  /// three mastheads never read as one product.
  ///
  /// Size is deliberately double the red line that sits under it —
  /// [bodySmall] is 13, this is 26. A masthead needs to beat its own
  /// subtitle by a clear factor or the two argue.
  ///
  /// Tracking drops from 0.2em to 0.1em on the way up. Letterspacing is
  /// optical, not proportional: the value that opens up 15pt caps turns
  /// 26pt caps into a ransom note, and every display face tightens as it
  /// grows for exactly this reason.
  static TextStyle get masthead => GoogleFonts.inter(
    fontSize: 26, fontWeight: FontWeight.w900,
    letterSpacing: 2.6, color: AppColors.textPrimary, height: 1.15,
  );

  // ── Sans (body / UI) — Inter ─────────────────────────────────────────────

  static TextStyle get h2 => GoogleFonts.inter(
    fontSize: 22, fontWeight: FontWeight.w600,
    letterSpacing: -0.5, color: AppColors.textPrimary, height: 1.25,
  );

  static TextStyle get h3 => GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w600,
    letterSpacing: 0.1, color: AppColors.textPrimary, height: 1.3,
  );

  static TextStyle get body => GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w400,
    letterSpacing: -0.05, color: AppColors.textSecondary, height: 1.6,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary, height: 1.55,
  );

  // ── Label / mono ─────────────────────────────────────────────────────────
  // All-caps labels with strong tracking — editorial typography signal.

  static TextStyle get label => GoogleFonts.inter(
    fontSize: 10, fontWeight: FontWeight.w600,
    letterSpacing: 2.4, color: AppColors.textTertiary,
  );

  static TextStyle get labelBold => GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w700,
    letterSpacing: 3.2, color: AppColors.textPrimary,
  );

  static TextStyle get mono => GoogleFonts.spaceGrotesk(
    fontSize: 13, fontWeight: FontWeight.w500,
    letterSpacing: 0.2, color: AppColors.textSecondary,
  );

  static TextStyle get measurement => GoogleFonts.spaceGrotesk(
    fontSize: 11, fontWeight: FontWeight.w600,
    letterSpacing: 0.5, color: AppColors.measure,
  );
}

abstract final class Sp {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;
  static const double xxxl = 72;
}

abstract final class Rd {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double xxl = 28;
}
