/// Builds the four Sakina [ThemeData] variants (light/dark × normal/high-
/// contrast) plus the reduce-ornament axis, all composed from [SakinaPalette]
/// and carrying a [SakinaLuxury] extension.
///
/// Accessibility axes are explicit parameters rather than separate themes so
/// the choice stays a single source of truth driven by user preferences.
library;

import 'package:flutter/material.dart';

import 'sakina_luxury.dart';
import 'tokens.dart';

abstract final class SakinaAppTheme {
  static ThemeData light({
    bool highContrast = false,
    bool reduceOrnament = false,
  }) {
    final scheme = highContrast ? _lightHcScheme : _lightScheme;
    final luxury = _luxury(
      dark: false,
      highContrast: highContrast,
      reduceOrnament: reduceOrnament,
    );
    return _build(scheme, luxury);
  }

  static ThemeData dark({
    bool highContrast = false,
    bool reduceOrnament = false,
  }) {
    final scheme = highContrast ? _darkHcScheme : _darkScheme;
    final luxury = _luxury(
      dark: true,
      highContrast: highContrast,
      reduceOrnament: reduceOrnament,
    );
    return _build(scheme, luxury);
  }

  // --- Color schemes ------------------------------------------------------

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: SakinaPalette.emerald,
    onPrimary: SakinaPalette.pureWhite,
    primaryContainer: SakinaPalette.sage,
    onPrimaryContainer: SakinaPalette.emeraldDeep,
    secondary: SakinaPalette.goldDark, // dark gold so white text meets AA
    onSecondary: SakinaPalette.pureWhite,
    tertiary: SakinaPalette.emeraldDeep,
    onTertiary: SakinaPalette.pureWhite,
    error: SakinaPalette.error,
    onError: SakinaPalette.pureWhite,
    surface: SakinaPalette.cream,
    onSurface: SakinaPalette.ink,
    surfaceContainerHighest: SakinaPalette.creamDeep,
    onSurfaceVariant: SakinaPalette.inkMuted,
    outline: SakinaPalette.inkMuted,
    outlineVariant: SakinaPalette.goldSoft,
  );

  static const ColorScheme _lightHcScheme = ColorScheme(
    brightness: Brightness.light,
    primary: SakinaPalette.emeraldDeep,
    onPrimary: SakinaPalette.pureWhite,
    primaryContainer: SakinaPalette.sage,
    onPrimaryContainer: SakinaPalette.pureBlack,
    secondary: SakinaPalette.goldDeep,
    onSecondary: SakinaPalette.pureBlack,
    tertiary: SakinaPalette.emeraldDeep,
    onTertiary: SakinaPalette.pureWhite,
    error: SakinaPalette.error,
    onError: SakinaPalette.pureWhite,
    surface: SakinaPalette.pureWhite,
    onSurface: SakinaPalette.pureBlack,
    surfaceContainerHighest: SakinaPalette.creamDeep,
    onSurfaceVariant: SakinaPalette.pureBlack,
    outline: SakinaPalette.pureBlack,
    outlineVariant: SakinaPalette.ink,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: SakinaPalette.emeraldLight,
    onPrimary: SakinaPalette.pureBlack, // black clears AA on light-green primary
    primaryContainer: SakinaPalette.emeraldDeep,
    onPrimaryContainer: SakinaPalette.nightCream,
    secondary: SakinaPalette.gold,
    onSecondary: SakinaPalette.night,
    tertiary: SakinaPalette.goldSoft,
    onTertiary: SakinaPalette.night,
    error: SakinaPalette.errorOnDark,
    onError: SakinaPalette.night,
    surface: SakinaPalette.nightSurface,
    onSurface: SakinaPalette.nightCream,
    surfaceContainerHighest: SakinaPalette.nightCard,
    onSurfaceVariant: SakinaPalette.goldSoft,
    outline: SakinaPalette.goldSoft,
    outlineVariant: SakinaPalette.inkMuted,
  );

  static const ColorScheme _darkHcScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: SakinaPalette.emeraldLight,
    onPrimary: SakinaPalette.pureBlack,
    primaryContainer: SakinaPalette.emeraldDeep,
    onPrimaryContainer: SakinaPalette.pureWhite,
    secondary: SakinaPalette.gold,
    onSecondary: SakinaPalette.pureBlack,
    tertiary: SakinaPalette.goldSoft,
    onTertiary: SakinaPalette.pureBlack,
    error: SakinaPalette.errorOnDark,
    onError: SakinaPalette.pureBlack,
    surface: SakinaPalette.pureBlack,
    onSurface: SakinaPalette.pureWhite,
    surfaceContainerHighest: SakinaPalette.nightCard,
    onSurfaceVariant: SakinaPalette.pureWhite,
    outline: SakinaPalette.pureWhite,
    outlineVariant: SakinaPalette.goldSoft,
  );

  // --- Luxury extension ---------------------------------------------------

  static SakinaLuxury _luxury({
    required bool dark,
    required bool highContrast,
    required bool reduceOrnament,
  }) {
    // Reduce-ornament fully disables decoration; high-contrast keeps strong
    // borders but drops busy textures behind content.
    final double opacity = reduceOrnament
        ? 0.0
        : highContrast
            ? 0.0
            : (dark ? 0.05 : 0.06);
    final bool ornaments = !reduceOrnament;

    if (dark) {
      return SakinaLuxury(
        gold: SakinaPalette.gold,
        goldSoft: SakinaPalette.goldSoft,
        cardSurface: SakinaPalette.nightCard,
        parchment: SakinaPalette.nightSurface,
        calligraphyInk: SakinaPalette.goldSoft,
        patternColor: SakinaPalette.emeraldLight,
        patternOpacity: opacity,
        ornamentsEnabled: ornaments,
      );
    }
    return SakinaLuxury(
      gold: highContrast ? SakinaPalette.goldDeep : SakinaPalette.gold,
      goldSoft: SakinaPalette.goldSoft,
      cardSurface: SakinaPalette.parchment,
      parchment: SakinaPalette.creamDeep,
      calligraphyInk: SakinaPalette.emeraldDeep,
      patternColor: SakinaPalette.emerald,
      patternOpacity: opacity,
      ornamentsEnabled: ornaments,
    );
  }

  // --- Assembly -----------------------------------------------------------

  static ThemeData _build(ColorScheme scheme, SakinaLuxury luxury) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: <ThemeExtension<dynamic>>[luxury],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: luxury.cardSurface,
        elevation: luxury.ornamentsEnabled ? 1 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SakinaRadius.lg),
          side: luxury.ornamentsEnabled
              ? BorderSide(color: luxury.goldSoft)
              : BorderSide.none,
        ),
      ),
    );
  }
}
