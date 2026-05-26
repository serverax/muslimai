/// App-wide user preferences: theme mode plus the accessibility and locale
/// axes that drive the design system. Hand-written Riverpod [Notifier] (no
/// codegen) so the dependency tree stays on stable, conflict-free packages.
///
/// These are kept in-memory here; persistence (shared_preferences/secure
/// storage) is a later step and slots in behind [PreferencesNotifier].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sentinel so [AppPreferences.copyWith] can distinguish "leave locale alone"
/// from "set locale to null (follow system)".
class _Unset {
  const _Unset();
}

const _Unset _unset = _Unset();

@immutable
class AppPreferences {
  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.highContrast = false,
    this.reduceOrnament = false,
    this.reduceMotion = false,
    this.textScale = 1.0,
    this.locale,
  });

  final ThemeMode themeMode;
  final bool highContrast;

  /// Streamlined visual mode: disables decorative patterns/borders/motifs.
  final bool reduceOrnament;

  /// Disables non-essential animations (e.g. the qibla compass spin).
  final bool reduceMotion;

  /// User text-scale multiplier, clamped to a legible-but-bounded range.
  final double textScale;

  /// `null` means follow the system/device locale.
  final Locale? locale;

  static const double minTextScale = 0.8;
  static const double maxTextScale = 2.0;

  AppPreferences copyWith({
    ThemeMode? themeMode,
    bool? highContrast,
    bool? reduceOrnament,
    bool? reduceMotion,
    double? textScale,
    Object? locale = _unset,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      highContrast: highContrast ?? this.highContrast,
      reduceOrnament: reduceOrnament ?? this.reduceOrnament,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      textScale: textScale ?? this.textScale,
      locale: identical(locale, _unset) ? this.locale : locale as Locale?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.themeMode == themeMode &&
      other.highContrast == highContrast &&
      other.reduceOrnament == reduceOrnament &&
      other.reduceMotion == reduceMotion &&
      other.textScale == textScale &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(
        themeMode,
        highContrast,
        reduceOrnament,
        reduceMotion,
        textScale,
        locale,
      );
}

class PreferencesNotifier extends Notifier<AppPreferences> {
  @override
  AppPreferences build() => const AppPreferences();

  void setThemeMode(ThemeMode mode) =>
      state = state.copyWith(themeMode: mode);

  void setHighContrast(bool value) =>
      state = state.copyWith(highContrast: value);

  void toggleHighContrast() =>
      state = state.copyWith(highContrast: !state.highContrast);

  void setReduceOrnament(bool value) =>
      state = state.copyWith(reduceOrnament: value);

  void toggleReduceOrnament() =>
      state = state.copyWith(reduceOrnament: !state.reduceOrnament);

  void setReduceMotion(bool value) =>
      state = state.copyWith(reduceMotion: value);

  void toggleReduceMotion() =>
      state = state.copyWith(reduceMotion: !state.reduceMotion);

  /// Clamps to [AppPreferences.minTextScale]..[AppPreferences.maxTextScale].
  void setTextScale(double value) => state = state.copyWith(
        textScale: value.clamp(
          AppPreferences.minTextScale,
          AppPreferences.maxTextScale,
        ),
      );

  /// Pass `null` to follow the system locale.
  void setLocale(Locale? locale) => state = state.copyWith(locale: locale);
}

final preferencesProvider =
    NotifierProvider<PreferencesNotifier, AppPreferences>(
  PreferencesNotifier.new,
);
