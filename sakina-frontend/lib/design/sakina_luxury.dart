/// [SakinaLuxury] — a [ThemeExtension] carrying the decorative tokens that
/// Material's [ColorScheme] has no slot for: gold accents, parchment surfaces,
/// calligraphy ink, and the geometric-pattern controls.
///
/// Crucially, this is where the accessible "reduce ornamentation" mode lives:
/// [ornamentsEnabled] gates borders/textures/motifs, and [patternOpacity] is
/// driven to 0 so decoration can never sit behind body text. Widgets read these
/// via `Theme.of(context).extension<SakinaLuxury>()!`.
library;

import 'package:flutter/material.dart';

@immutable
class SakinaLuxury extends ThemeExtension<SakinaLuxury> {
  const SakinaLuxury({
    required this.gold,
    required this.goldSoft,
    required this.cardSurface,
    required this.parchment,
    required this.calligraphyInk,
    required this.patternColor,
    required this.patternOpacity,
    required this.ornamentsEnabled,
  });

  /// Decorative gold for accents, dividers, and chrome (never body text).
  final Color gold;

  /// Pale gold for hairline borders and soft glows.
  final Color goldSoft;

  /// Surface for parchment-style cards (lessons, verses).
  final Color cardSurface;

  /// Deeper parchment for sunken/variant surfaces.
  final Color parchment;

  /// Color for calligraphic headings and Quranic verse display.
  final Color calligraphyInk;

  /// Base color for geometric [CustomPainter] backgrounds.
  final Color patternColor;

  /// Opacity for geometric patterns. Driven to 0 in reduce-ornament mode so
  /// decoration is never rendered behind text.
  final double patternOpacity;

  /// Master gate for decorative elements (borders, textures, motifs).
  /// `false` in reduce-ornament mode.
  final bool ornamentsEnabled;

  /// Whether a decorative geometric pattern should actually be painted.
  bool get showPattern => ornamentsEnabled && patternOpacity > 0;

  @override
  SakinaLuxury copyWith({
    Color? gold,
    Color? goldSoft,
    Color? cardSurface,
    Color? parchment,
    Color? calligraphyInk,
    Color? patternColor,
    double? patternOpacity,
    bool? ornamentsEnabled,
  }) {
    return SakinaLuxury(
      gold: gold ?? this.gold,
      goldSoft: goldSoft ?? this.goldSoft,
      cardSurface: cardSurface ?? this.cardSurface,
      parchment: parchment ?? this.parchment,
      calligraphyInk: calligraphyInk ?? this.calligraphyInk,
      patternColor: patternColor ?? this.patternColor,
      patternOpacity: patternOpacity ?? this.patternOpacity,
      ornamentsEnabled: ornamentsEnabled ?? this.ornamentsEnabled,
    );
  }

  @override
  SakinaLuxury lerp(SakinaLuxury? other, double t) {
    if (other is! SakinaLuxury) return this;
    return SakinaLuxury(
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      parchment: Color.lerp(parchment, other.parchment, t)!,
      calligraphyInk: Color.lerp(calligraphyInk, other.calligraphyInk, t)!,
      patternColor: Color.lerp(patternColor, other.patternColor, t)!,
      patternOpacity: _lerpDouble(patternOpacity, other.patternOpacity, t),
      // Booleans don't interpolate; snap at the midpoint.
      ornamentsEnabled: t < 0.5 ? ornamentsEnabled : other.ornamentsEnabled,
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
