import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
// Design direction: deep soil tones with a sharp harvest-green accent.
// Feels grounded and purposeful — not a generic dark chat UI.

class AppColors {
  // Backgrounds
  static const surface = Color(0xFF0F1410);       // deep earth black-green
  static const surfaceElevated = Color(0xFF1A2019); // slightly lifted
  static const surfaceCard = Color(0xFF1F2820);    // card level

  // Accent — harvest green, sharp and recognisable
  static const accent = Color(0xFF5DBB6A);
  static const accentDim = Color(0xFF2D5C35);
  static const accentSurface = Color(0xFF162419);

  // Text
  static const textPrimary = Color(0xFFE8EDE8);
  static const textSecondary = Color(0xFF8A9E8A);
  static const textMuted = Color(0xFF4A5E4A);

  // Semantic
  static const error = Color(0xFFE06C75);
  static const warning = Color(0xFFD4A857);
  static const info = Color(0xFF61AFEF);

  // Chat bubbles
  static const userBubble = Color(0xFF1E3A24);
  static const assistantBubble = Color(0xFF1A2019);

  // SQL chip
  static const sqlChip = Color(0xFF0D1F26);
  static const sqlText = Color(0xFF61AFEF);
}

// ── Typography ────────────────────────────────────────────────────────────────

class AppTextStyles {
  static TextStyle get displayLarge => GoogleFonts.dmSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get heading => GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.55,
      );

  static TextStyle get bodySecondary => GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get caption => GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
        letterSpacing: 0.3,
      );

  // Monospaced for SQL display
  static TextStyle get mono => const TextStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: 12,
        color: AppColors.sqlText,
        height: 1.6,
      );

  static TextStyle get label => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      );
}

// ── Theme ─────────────────────────────────────────────────────────────────────

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.surface,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.accent,
      secondary: AppColors.accentDim,
      error: AppColors.error,
      onSurface: AppColors.textPrimary,
      onPrimary: Colors.black,
    ),
    textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    iconTheme: const IconThemeData(color: AppColors.textSecondary),
    dividerColor: AppColors.textMuted.withOpacity(0.2),
  );
}
