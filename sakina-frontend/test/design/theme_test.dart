import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina_frontend/design/a11y.dart';
import 'package:sakina_frontend/design/app_theme.dart';
import 'package:sakina_frontend/design/sakina_luxury.dart';

void main() {
  // Every theme variant we ship, paired with a label for failure messages.
  final variants = <String, ThemeData>{
    'light': SakinaAppTheme.light(),
    'light+highContrast': SakinaAppTheme.light(highContrast: true),
    'light+reduceOrnament': SakinaAppTheme.light(reduceOrnament: true),
    'dark': SakinaAppTheme.dark(),
    'dark+highContrast': SakinaAppTheme.dark(highContrast: true),
    'dark+reduceOrnament': SakinaAppTheme.dark(reduceOrnament: true),
  };

  group('SakinaLuxury extension', () {
    test('is attached to every theme variant', () {
      for (final entry in variants.entries) {
        expect(
          entry.value.extension<SakinaLuxury>(),
          isNotNull,
          reason: '${entry.key} is missing the SakinaLuxury extension',
        );
      }
    });

    test('reduce-ornament disables decoration and patterns', () {
      for (final hc in [false, true]) {
        for (final builder in [SakinaAppTheme.light, SakinaAppTheme.dark]) {
          final lux = builder(highContrast: hc, reduceOrnament: true)
              .extension<SakinaLuxury>()!;
          expect(lux.ornamentsEnabled, isFalse);
          expect(lux.patternOpacity, 0.0);
          expect(lux.showPattern, isFalse);
        }
      }
    });

    test('normal mode enables a subtle (but present) pattern', () {
      final lux = SakinaAppTheme.light().extension<SakinaLuxury>()!;
      expect(lux.ornamentsEnabled, isTrue);
      expect(lux.patternOpacity, greaterThan(0.0));
      expect(lux.showPattern, isTrue);
    });
  });

  group('WCAG AA contrast (>= 4.5:1 for text-bearing color pairs)', () {
    for (final entry in variants.entries) {
      final name = entry.key;
      final s = entry.value.colorScheme;

      test('$name: body, primary, secondary, error pairs meet AA', () {
        void check(Color fg, Color bg, String pair) {
          expect(
            meetsAaNormal(fg, bg),
            isTrue,
            reason: '$name $pair contrast is '
                '${contrastRatio(fg, bg).toStringAsFixed(2)}:1 (< 4.5)',
          );
        }

        check(s.onSurface, s.surface, 'onSurface/surface');
        check(s.onPrimary, s.primary, 'onPrimary/primary');
        check(s.onSecondary, s.secondary, 'onSecondary/secondary');
        check(s.onError, s.error, 'onError/error');
        check(s.onPrimaryContainer, s.primaryContainer,
            'onPrimaryContainer/primaryContainer');
      });
    }
  });
}
