import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina_frontend/design/app_theme.dart';
import 'package:sakina_frontend/design/patterns/girih_pattern.dart';

void main() {
  group('GirihPainter', () {
    test('shouldRepaint reflects config changes', () {
      const base = GirihPainter(color: Color(0xFF1B6B5E), cell: 48);
      expect(base.shouldRepaint(base), isFalse);
      expect(
        base.shouldRepaint(const GirihPainter(color: Color(0xFF1B6B5E), cell: 64)),
        isTrue,
      );
      expect(
        base.shouldRepaint(const GirihPainter(color: Color(0xFFC9A227), cell: 48)),
        isTrue,
      );
    });

    test('paints without throwing (incl. degenerate cell size)', () {
      void paintOnce(GirihPainter p) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        p.paint(canvas, const Size(200, 200));
        recorder.endRecording().dispose();
      }

      paintOnce(const GirihPainter(color: Color(0xFF1B6B5E), cell: 32));
      paintOnce(const GirihPainter(color: Color(0xFF1B6B5E), cell: 0)); // no-op
    });
  });

  group('IslamicPatternBackground', () {
    Future<bool> hasGirih(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: IslamicPatternBackground(child: Text('content')),
          ),
        ),
      );
      expect(find.text('content'), findsOneWidget); // child always rendered
      return tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .any((w) => w.painter is GirihPainter);
    }

    testWidgets('paints the pattern in normal mode', (tester) async {
      expect(await hasGirih(tester, SakinaAppTheme.light()), isTrue);
    });

    testWidgets('paints nothing in reduce-ornament mode', (tester) async {
      expect(
        await hasGirih(tester, SakinaAppTheme.light(reduceOrnament: true)),
        isFalse,
      );
    });
  });
}
