import 'package:flutter/material.dart';

abstract final class AppColors {
  static const base       = Color(0xFF09090B); // zinc-950
  static const surface1   = Color(0xFF111113); // slightly lifted
  static const surface2   = Color(0xFF18181B); // zinc-900
  static const surface3   = Color(0xFF27272A); // zinc-800

  static const accent     = Color(0xFF818CF8); // indigo-400
  static const accentDeep = Color(0xFF6366F1); // indigo-500
  static const accentBorder = Color(0xFF3730A3); // indigo-800 — subtle border

  static const measure    = Color(0xFF38BDF8); // sky-400 — measurement lines
  static const measureDim = Color(0xFF0EA5E9); // sky-500

  static const textPrimary   = Color(0xFFF4F4F5); // zinc-100
  static const textSecondary = Color(0xFFA1A1AA); // zinc-400
  static const textTertiary  = Color(0xFF71717A); // zinc-500

  static const signalGreen = Color(0xFF4ADE80); // green-400
  static const signalAmber = Color(0xFFFBBF24); // amber-400
  static const signalRed   = Color(0xFFF87171); // red-400

  static const divider = Color(0xFF27272A);
}
