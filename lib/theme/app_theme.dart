import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOR PALETTE — Retro Minimal
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceElevated = Color(0xFF181818);
  static const Color border = Color(0xFF1E1E1E);
  static const Color borderMid = Color(0xFF2A2A2A);

  // Warm gold — the signature accent
  static const Color gold = Color(0xFFC8A96E);
  static const Color goldDim = Color(0xFF6B5A38);

  // Typography
  static const Color textPrimary = Color(0xFFE8E4DB); // warm cream
  static const Color textSecondary = Color(0xFF666666);
  static const Color textMuted = Color(0xFF333333);

  // Status colors — muted, not loud
  static const Color statusPending = Color(0xFF555555);
  static const Color statusCalled = Color(0xFF705D32);   // dim gold
  static const Color statusAppointed = Color(0xFF2E5C3E); // dim green

  static const Color statusPendingText = Color(0xFF888888);
  static const Color statusCalledText = Color(0xFFC8A96E);
  static const Color statusAppointedText = Color(0xFF5DB07A);

  static const Color error = Color(0xFF7A3535);
  static const Color errorText = Color(0xFFD07070);
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT STYLES
// ─────────────────────────────────────────────────────────────────────────────
class AppText {
  AppText._();

  static TextStyle mono({
    double size = 14,
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
    double? height,
  }) =>
      GoogleFonts.dmMono(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: height,
      );

  // Preset styles
  static TextStyle get displayLarge => mono(
        size: 32,
        weight: FontWeight.w500,
        letterSpacing: 4,
      );

  static TextStyle get displayMedium => mono(
        size: 22,
        weight: FontWeight.w500,
        letterSpacing: 3,
      );

  static TextStyle get heading => mono(
        size: 16,
        weight: FontWeight.w500,
        letterSpacing: 2.5,
      );

  static TextStyle get label => mono(
        size: 10,
        color: AppColors.textSecondary,
        letterSpacing: 2,
      );

  static TextStyle get body => mono(size: 13, height: 1.6);

  static TextStyle get bodySmall =>
      mono(size: 11, color: AppColors.textSecondary, height: 1.5);

  static TextStyle get caption =>
      mono(size: 10, color: AppColors.textMuted, letterSpacing: 0.5);
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.surface,
          primary: AppColors.gold,
          onPrimary: AppColors.background,
          onSurface: AppColors.textPrimary,
          error: AppColors.errorText,
        ),
        textTheme: GoogleFonts.dmMonoTextTheme(ThemeData.dark().textTheme)
            .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: AppText.heading,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: AppText.label,
          hintStyle: AppText.mono(
            size: 13,
            color: AppColors.textMuted,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: const BorderSide(color: AppColors.gold, width: 1),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          errorStyle: AppText.mono(size: 10, color: AppColors.errorText),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 1,
          space: 0,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.surfaceElevated,
          contentTextStyle: AppText.body,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
            side: BorderSide(color: AppColors.border),
          ),
        ),
      );
}
