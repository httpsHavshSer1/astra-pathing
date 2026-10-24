import 'dart:math' as math;
import 'dart:ui';

import 'model.dart';

class WallCollision {
  final int segment;
  final double fraction;
  final Offset position;
  final double heading;
  const WallCollision(this.segment, this.fraction, this.position, this.heading);
}

/// Uses the full, rotated robot rectangle against the outer 12 ft perimeter.
/// Field art and interior markings intentionally remain passable.
class RobotFootprint {
  static const double halfField = 72;
  static const double margin = .5;

  static Offset halfExtents(double heading, double width, double length) {
    final c = math.cos(heading).abs();
    final s = math.sin(heading).abs();
    return Offset((c * length + s * width) / 2, (s * length + c * width) / 2);
  }

  static double wallViolation(
    Offset center,
    double heading,
    double width,
    double length,
  ) {
    final reach = halfExtents(heading, width, length);
    final limit = halfField - margin;
    return math.max(0, center.dx.abs() + reach.dx - limit) +
        math.max(0, center.dy.abs() + reach.dy - limit);
  }

  static Offset clampCenter(
    Offset center,
    double heading,
    double width,
    double length,
  ) {
    final reach = halfExtents(heading, width, length);
    final limit = halfField - margin;
    return Offset(
      center.dx.clamp(-limit + reach.dx, limit - reach.dx).toDouble(),
      center.dy.clamp(-limit + reach.dy, limit - reach.dy).toDouble(),
    );
  }

  static WallCollision? firstWallCollision(
    GeneratedPath path,
    double width,
    double length,
  ) {
    if (path.curves.isEmpty) {
      if (path.source.points.isEmpty) return null;
      final point = path.source.points.first;
      return wallViolation(point.position, point.heading, width, length) > 1e-5
          ? WallCollision(0, 0, point.position, point.heading)
          : null;
    }
    for (var i = 0; i < path.curves.length; i++) {
      final curve = path.curves[i];
      for (var k = 0; k <= 120; k++) {
        final t = k / 120;
        final position = curve.position(t);
        final heading = curve.heading(t);
        if (wallViolation(position, heading, width, length) > 1e-5) {
          return WallCollision(i, t, position, heading);
        }
      }
    }
    return null;
  }
}
