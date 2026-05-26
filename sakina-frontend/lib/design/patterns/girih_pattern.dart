/// Vector Islamic geometric patterns drawn with [CustomPainter] — no raster
/// assets, so they're crisp at any density and cheap on low-end devices.
///
/// [GirihPainter] tiles an eight-pointed star (khatim) motif: two overlapping
/// squares inscribed in each grid cell. It is generative (parametrised by cell
/// size / stroke), so the same code yields backgrounds, dividers, and card
/// flourishes at different scales.
///
/// Decoration discipline: this is always painted *behind* content at low
/// opacity, and the [IslamicPatternBackground] widget refuses to paint at all
/// when the theme is in reduce-ornament mode — so a pattern can never sit
/// behind body text in the accessible mode.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../sakina_luxury.dart';

/// Paints a tessellation of eight-pointed stars across the canvas.
class GirihPainter extends CustomPainter {
  const GirihPainter({
    required this.color,
    this.cell = 48,
    this.strokeWidth = 1.2,
  });

  /// Fully-resolved stroke color (caller applies opacity).
  final Color color;

  /// Side length of one repeating tile, in logical pixels.
  final double cell;

  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (cell <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    final radius = cell / 2;
    // Overscan by one cell so the motif bleeds to the edges seamlessly.
    for (double cy = 0; cy <= size.height + cell; cy += cell) {
      for (double cx = 0; cx <= size.width + cell; cx += cell) {
        canvas.drawPath(_star(Offset(cx, cy), radius), paint);
      }
    }
  }

  /// Eight-pointed star = two squares (0° and 45°) inscribed in [radius].
  Path _star(Offset center, double radius) {
    final path = Path();
    for (final rotation in const [0.0, math.pi / 4]) {
      for (var i = 0; i < 4; i++) {
        final angle = rotation + i * math.pi / 2;
        final point = center +
            Offset(math.cos(angle), math.sin(angle)) * radius;
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
    }
    return path;
  }

  @override
  bool shouldRepaint(GirihPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.cell != cell ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Wraps [child] with a subtle girih pattern behind it, honoring the theme's
/// [SakinaLuxury] tokens. Paints nothing in reduce-ornament mode.
class IslamicPatternBackground extends StatelessWidget {
  const IslamicPatternBackground({super.key, this.child, this.cell = 48});

  final Widget? child;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final luxury = Theme.of(context).extension<SakinaLuxury>()!;
    if (!luxury.showPattern) {
      return child ?? const SizedBox.shrink();
    }
    return CustomPaint(
      painter: GirihPainter(
        color: luxury.patternColor.withValues(alpha: luxury.patternOpacity),
        cell: cell,
      ),
      child: child,
    );
  }
}
