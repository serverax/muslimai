/// Sakina design tokens — the single source of truth for the "Islamic luxury"
/// visual language (rich green, gold, cream).
///
/// Layering rule: widgets must NOT reference [SakinaPalette] directly. Go
/// through the semantic [ColorScheme] or the [SakinaLuxury] theme extension so
/// that light / dark / high-contrast / RTL variants all stay derived from one
/// place. The raw palette below exists only so the theme builders can compose
/// those semantic roles.
library;

import 'package:flutter/widgets.dart';

/// Context-free brand palette. Composed into semantic roles by the theme.
abstract final class SakinaPalette {
  // --- Greens (the anchor of the brand) ---
  static const Color emerald = Color(0xFF1B6B5E); // primary (brand green)
  static const Color emeraldDeep = Color(0xFF0F4A40); // emphasis / HC primary
  static const Color emeraldLight = Color(0xFF2E8B7A); // primary on dark
  static const Color sage = Color(0xFFE3EFE9); // soft green tint / container

  // --- Golds (accents, borders, chrome — NEVER body text on cream) ---
  static const Color gold = Color(0xFFC9A227); // decorative accent (non-text)
  static const Color goldDeep = Color(0xFF9C7C16); // AA with black text
  static const Color goldDark = Color(0xFF6E5510); // AA with WHITE text (buttons)
  static const Color goldSoft = Color(0xFFE8D6A0); // hairline borders / glow

  // --- Creams / parchment (warm surfaces) ---
  static const Color cream = Color(0xFFFBF7EC); // primary light surface
  static const Color creamDeep = Color(0xFFF3EAD3); // sunken / variant surface
  static const Color parchment = Color(0xFFF7F0DE); // card / lesson surface

  // --- Ink (text on light) ---
  static const Color ink = Color(0xFF1C1A17); // body text on cream
  static const Color inkMuted = Color(0xFF5A5345); // secondary text / outline

  // --- Dark surfaces ---
  static const Color night = Color(0xFF12150F); // app background (dark)
  static const Color nightSurface = Color(0xFF1B211A); // surface (dark)
  static const Color nightCard = Color(0xFF222A20); // parchment-equiv on dark
  static const Color nightCream = Color(0xFFEDE7D6); // body text on dark

  // --- Status ---
  static const Color error = Color(0xFFB3261E);
  static const Color errorOnDark = Color(0xFFF2B8B5);
  static const Color success = Color(0xFF2E7D52);

  // --- Pure extremes for high-contrast mode ---
  static const Color pureBlack = Color(0xFF000000);
  static const Color pureWhite = Color(0xFFFFFFFF);
}

/// 8pt spacing scale (with two half-steps for fine alignment).
abstract final class SakinaSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radii. [lg] suits parchment-style cards; [pill] for chips/badges.
abstract final class SakinaRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 22;
  static const double pill = 999;
}
