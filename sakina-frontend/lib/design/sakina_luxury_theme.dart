import 'package:flutter/material.dart';

import 'sakina_colors.dart';

/// Premium Islamic mobile theme.
class SakinaLuxuryTheme {
  SakinaLuxuryTheme._();

  static ThemeData build(bool isArabic) {
    final font = isArabic ? 'Amiri' : 'Inter';
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: font,
      scaffoldBackgroundColor: SakinaColors.cream,
      colorScheme: const ColorScheme.light(
        primary: SakinaColors.emerald,
        onPrimary: Colors.white,
        secondary: SakinaColors.gold,
        onSecondary: SakinaColors.navy,
        surface: SakinaColors.creamSurface,
        onSurface: SakinaColors.textPrimary,
        error: SakinaColors.error,
      ),
      cardTheme: CardThemeData(
        color: SakinaColors.creamSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: SakinaColors.divider),
        ),
        margin: const EdgeInsets.only(bottom: 10),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SakinaColors.navy,
        foregroundColor: SakinaColors.textOnDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: SakinaColors.textOnDark,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SakinaColors.emerald,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SakinaColors.emerald,
          side: const BorderSide(color: SakinaColors.emerald),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SakinaColors.cream,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dividerTheme: const DividerThemeData(color: SakinaColors.divider),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: SakinaColors.textPrimary,
        displayColor: SakinaColors.textPrimary,
        fontFamily: font,
      ),
    );
  }
}
