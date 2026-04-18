import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  static TextStyle get display => GoogleFonts.inter(
    fontSize: 48, fontWeight: FontWeight.w700,
    letterSpacing: -2.0, color: AppColors.textPrimary, height: 1.1,
  );

  static TextStyle get h1 => GoogleFonts.inter(
    fontSize: 32, fontWeight: FontWeight.w700,
    letterSpacing: -1.2, color: AppColors.textPrimary, height: 1.15,
  );

  static TextStyle get h2 => GoogleFonts.inter(
    fontSize: 22, fontWeight: FontWeight.w600,
    letterSpacing: -0.6, color: AppColors.textPrimary, height: 1.25,
  );

  static TextStyle get h3 => GoogleFonts.inter(
    fontSize: 17, fontWeight: FontWeight.w600,
    letterSpacing: -0.3, color: AppColors.textPrimary, height: 1.3,
  );

  static TextStyle get body => GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w400,
    letterSpacing: -0.1, color: AppColors.textSecondary, height: 1.6,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary, height: 1.55,
  );

  static TextStyle get label => GoogleFonts.inter(
    fontSize: 10, fontWeight: FontWeight.w600,
    letterSpacing: 1.6, color: AppColors.textTertiary,
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
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class Rd {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
}
