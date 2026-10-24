import 'dart:math' as math;
import 'dart:ui';

import 'field_clearance.dart';
import 'model.dart';

/// A locally optimized cubic route through every requested pose waypoint.
/// Interior field markings are passable; only the outer perimeter is checked.
class RoutePlan {
  final List<Waypoint> waypoints;
  final double length, duration;
  final int adjustedPoses;
  const RoutePlan(
    this.waypoints,
    this.length,
    this.duration,
    this.adjustedPoses,
  );
}

class RoutePlanner {
  static const double fieldHalfWidth = 72;
  static const double wallMargin = .5;

  static RoutePlan optimize({
    required StudioPath source,
    required List<Waypoint> anchors,
    required double robotWidth,
    required double robotLength,
  }) {
    if (anchors.length < 2) {
      throw const FormatException('Add at least two pose waypoints.');
    }
    if (!robotWidth.isFinite ||
        !robotLength.isFinite ||
        robotWidth <= 0 ||
        robotLength <= 0) {
      throw const FormatException('Robot size must be valid.');
    }
    // A requested pose may place part of the robot past the wall. Move only
    // that pose to the nearest valid center before shaping the route.
    final fittedAnchors = <Waypoint>[];
    var adjustedPoses = 0;
    for (var i = 0; i < anchors.length; i++) {
      final w = anchors[i];
      if (!w.x.isFinite || !w.y.isFinite || !w.heading.isFinite) {
        throw const FormatException('Waypoint poses must be valid.');
      }
      final fitted = RobotFootprint.clampCenter(
        w.position,
        w.heading,
        robotWidth,
        robotLength,
      );
      if ((fitted - w.position).distance > 1e-5) adjustedPoses++;
      fittedAnchors.add(Waypoint(fitted.dx, fitted.dy, w.heading));
    }
    anchors = fittedAnchors;
    final positions = anchors.map((w) => w.position).toList();
    final spans = <double>[];
    for (var i = 0; i < anchors.length; i++) {
      final before = i > 0
          ? (positions[i] - positions[i - 1]).distance
          : double.infinity;
      final after = i + 1 < anchors.length
          ? (positions[i + 1] - positions[i]).distance
          : double.infinity;
      if (after < .1) {
        throw FormatException(
          'Waypoints ${i + 1} and ${i + 2} need different positions.',
        );
      }
      spans.add(math.min(before, after));
    }

    // Shared tangents keep translation velocity continuous at the waypoints.
    final tangents = <Offset>[];
    for (var i = 0; i < anchors.length; i++) {
      final tangent = i == 0
          ? (positions[1] - positions[0]) * source.smoothing
          : i == anchors.length - 1
          ? (positions[i] - positions[i - 1]) * source.smoothing
          : (positions[i + 1] - positions[i - 1]) * (source.smoothing / 2);
      tangents.add(
        CurveSegment.keepMovingThrough(
          anchors,
          i,
          _limit(tangent, spans[i] * 1.5),
        ),
      );
    }

    var best = _measure(anchors, tangents, source, robotWidth, robotLength);
    // Coordinate descent minimizes the travel time used by GeneratedPath.
    // A small length term breaks ties between equal-time paths.
    final scales = anchors.length > 40
        ? [.35, .12, .04]
        : [.4, .2, .1, .05, .025];
    final passes = anchors.length > 40 ? 1 : 2;
    for (final scale in scales) {
      for (var pass = 0; pass < passes; pass++) {
        var improved = false;
        for (var i = 0; i < tangents.length; i++) {
          final step = spans[i] * scale;
          for (var axis = 0; axis < 2; axis++) {
            for (final sign in [-1.0, 1.0]) {
              final current = tangents[i];
              final trial = axis == 0
                  ? Offset(current.dx + sign * step, current.dy)
                  : Offset(current.dx, current.dy + sign * step);
              if (trial.distance > spans[i] * 1.5 ||
                  trial.distance <
                      CurveSegment.minimumThroughTangent(anchors, i)) {
                continue;
              }
              tangents[i] = trial;
              final measured = _measure(
                anchors,
                tangents,
                source,
                robotWidth,
                robotLength,
              );
              if (measured.score < best.score - 1e-6) {
                best = measured;
                improved = true;
              } else {
                tangents[i] = current;
              }
            }
          }
        }
        if (!improved) break;
      }
    }

    final optimized = _withHandles(anchors, tangents);
    final generated = GeneratedPath(
      StudioPath(
        points: optimized,
        maxSpeed: source.maxSpeed,
        maxAcceleration: source.maxAcceleration,
        maxOmega: source.maxOmega,
        maxAlpha: source.maxAlpha,
        samplePeriod: source.samplePeriod,
      ),
    );
    if (RobotFootprint.firstWallCollision(generated, robotWidth, robotLength) !=
        null) {
      throw const FormatException(
        'No route through these poses keeps the robot inside the outer wall.',
      );
    }
    return RoutePlan(
      optimized,
      generated.length,
      generated.duration,
      adjustedPoses,
    );
  }

  static Offset _limit(Offset tangent, double maximum) {
    final magnitude = tangent.distance;
    return magnitude > maximum ? tangent * (maximum / magnitude) : tangent;
  }

  static List<Waypoint> _withHandles(
    List<Waypoint> anchors,
    List<Offset> tangents,
  ) => [
    for (var i = 0; i < anchors.length; i++)
      Waypoint(
        anchors[i].x,
        anchors[i].y,
        anchors[i].heading,
        i == 0 ? null : anchors[i].position - tangents[i] / 3,
        i == anchors.length - 1 ? null : anchors[i].position + tangents[i] / 3,
      ),
  ];

  static _RouteMetric _measure(
    List<Waypoint> anchors,
    List<Offset> tangents,
    StudioPath source,
    double robotWidth,
    double robotLength,
  ) {
    var m1 = 0.0, m2 = 0.0, h1 = 0.0, h2 = 0.0;
    var length = 0.0, wall = 0.0, loop = 0.0;
    final (headings, headingRates) = CurveSegment.headingPlan(anchors);
    for (var i = 0; i < anchors.length - 1; i++) {
      final a = anchors[i], b = anchors[i + 1];
      final p0 = a.position, p3 = b.position;
      final curve = CurveSegment(
        p0,
        p0 + tangents[i] / 3,
        p3 - tangents[i + 1] / 3,
        p3,
        headings[i],
        headings[i + 1] - headings[i],
        headingRates[i],
        headingRates[i + 1],
      );
      for (final v in [
        (curve.b - curve.a) * 3,
        (curve.c - curve.b) * 3,
        (curve.d - curve.c) * 3,
      ]) {
        m1 = math.max(m1, v.distance);
      }
      for (final v in [
        (curve.c - curve.b * 2 + curve.a) * 6,
        (curve.d - curve.c * 2 + curve.b) * 6,
      ]) {
        m2 = math.max(m2, v.distance);
      }
      h1 = math.max(h1, curve.maxHeadingDerivative);
      h2 = math.max(h2, curve.maxHeadingSecond);
      var previous = p0;
      final chord = p3 - p0;
      for (var k = 0; k <= 16; k++) {
        final t = k / 16;
        final point = curve.position(t);
        if (k > 0) length += (point - previous).distance;
        previous = point;
        final violation = _wallViolation(
          point,
          curve.heading(t),
          robotWidth,
          robotLength,
        );
        wall += violation * violation;
        final backward =
            -(curve.derivative(t).dx * chord.dx +
                curve.derivative(t).dy * chord.dy);
        if (backward > 0) {
          loop += backward / (chord.distanceSquared + 1);
        }
      }
    }
    final duration = GeneratedPath.estimatedDurationForBounds(
      source,
      anchors.length - 1,
      m1,
      m2,
      h1,
      h2,
    );
    return _RouteMetric(duration + length * .002 + wall * 1000 + loop * 10);
  }

  static double _wallViolation(
    Offset center,
    double heading,
    double width,
    double length,
  ) {
    return RobotFootprint.wallViolation(center, heading, width, length);
  }
}

class _RouteMetric {
  final double score;
  const _RouteMetric(this.score);
}
