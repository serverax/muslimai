/// Accessibility helpers for the design system.
///
/// Contrast is computed per WCAG 2.1 using relative luminance. We use these in
/// both the running app (to pick legible pairings) and in tests (to *assert*
/// the palette actually meets AA), so the "accessible" claim is enforced, not
/// aspirational.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// WCAG 2.1 contrast ratio between two colors, in the range 1.0–21.0.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// WCAG AA for normal body text (>= 4.5:1).
bool meetsAaNormal(Color fg, Color bg) => contrastRatio(fg, bg) >= 4.5;

/// WCAG AA for large text / UI components and graphical objects (>= 3.0:1).
bool meetsAaLarge(Color fg, Color bg) => contrastRatio(fg, bg) >= 3.0;
