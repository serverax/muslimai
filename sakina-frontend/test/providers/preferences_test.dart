import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina_frontend/providers/preferences.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });
  tearDown(() => container.dispose());

  AppPreferences read() => container.read(preferencesProvider);
  PreferencesNotifier notifier() => container.read(preferencesProvider.notifier);

  test('defaults are sensible', () {
    final p = read();
    expect(p.themeMode, ThemeMode.system);
    expect(p.highContrast, isFalse);
    expect(p.reduceOrnament, isFalse);
    expect(p.reduceMotion, isFalse);
    expect(p.textScale, 1.0);
    expect(p.locale, isNull);
  });

  test('toggles flip independently', () {
    notifier().toggleReduceOrnament();
    expect(read().reduceOrnament, isTrue);
    expect(read().highContrast, isFalse); // unaffected

    notifier().toggleHighContrast();
    expect(read().highContrast, isTrue);
    expect(read().reduceOrnament, isTrue); // unaffected

    notifier().toggleReduceMotion();
    expect(read().reduceMotion, isTrue);
  });

  test('text scale is clamped to legible bounds', () {
    notifier().setTextScale(5.0);
    expect(read().textScale, AppPreferences.maxTextScale);

    notifier().setTextScale(0.1);
    expect(read().textScale, AppPreferences.minTextScale);

    notifier().setTextScale(1.3);
    expect(read().textScale, 1.3);
  });

  test('locale can be set and cleared back to system (null)', () {
    notifier().setLocale(const Locale('ar'));
    expect(read().locale, const Locale('ar'));

    // copyWith of an unrelated field must NOT wipe the locale.
    notifier().toggleHighContrast();
    expect(read().locale, const Locale('ar'));

    notifier().setLocale(null);
    expect(read().locale, isNull);
  });

  test('value equality holds for copyWith', () {
    const a = AppPreferences();
    final b = a.copyWith(reduceOrnament: true).copyWith(reduceOrnament: false);
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });
}
