import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astra_path_studio/field_clearance.dart';
import 'package:astra_path_studio/model.dart';
import 'package:astra_path_studio/route_planner.dart';
import 'package:astra_path_studio/studio_state.dart';

void main() {
  test('two poses generate a straight route across the passable hive', () {
    final route = RoutePlanner.optimize(
      source: StudioPath(),
      anchors: [Waypoint(-50, 0, 0), Waypoint(50, 0, 0)],
      robotWidth: 18,
      robotLength: 18,
    );
    expect(route.waypoints.length, 2);
    expect(route.length, closeTo(100, 1e-5));
    final path = GeneratedPath(StudioPath(points: route.waypoints));
    expect(path.length, closeTo(100, 1e-6));
    expect(path.at(path.duration / 2).position.dx, closeTo(0, 1e-6));
    expect(path.at(path.duration / 2).position.dy, closeTo(0, 1e-6));
  });

  test('optimized curves keep moving through ordinary interior poses', () {
    final anchors = [
      Waypoint(-45, -20, 0),
      Waypoint(-15, 10, .4),
      Waypoint(15, 10, .8),
      Waypoint(45, -20, 1.2),
    ];
    final plan = RoutePlanner.optimize(
      source: StudioPath(),
      anchors: anchors,
      robotWidth: 18,
      robotLength: 18,
    );
    final generated = GeneratedPath(StudioPath(points: plan.waypoints));
    for (var i = 1; i < plan.waypoints.length - 1; i++) {
      final left = generated.curves[i - 1], right = generated.curves[i];
      expect(
        (left.derivative(1) - right.derivative(0)).distance,
        lessThan(1e-8),
      );
      expect(
        left.derivative(1).distance,
        greaterThanOrEqualTo(
          CurveSegment.minimumThroughTangent(plan.waypoints, i) - 1e-8,
        ),
      );
      expect(
        left.headingDerivative(1),
        closeTo(right.headingDerivative(0), 1e-8),
      );
    }
  });

  test('invalid pose is adjusted inside the outer perimeter', () {
    final plan = RoutePlanner.optimize(
      source: StudioPath(),
      anchors: [Waypoint(65, 0), Waypoint(0, 0)],
      robotWidth: 18,
      robotLength: 18,
    );
    expect(plan.waypoints.first.x, closeTo(62.5, 1e-9));
    expect(plan.adjustedPoses, 1);
    expect(
      RobotFootprint.firstWallCollision(
        GeneratedPath(StudioPath(points: plan.waypoints)),
        18,
        18,
      ),
      isNull,
    );
    expect(
      () => RoutePlanner.optimize(
        source: StudioPath(),
        anchors: [Waypoint(0, 0), Waypoint(0, 0)],
        robotWidth: 18,
        robotLength: 18,
      ),
      throwsFormatException,
    );
  });

  test('two-click route adjusts both endpoint poses near the wall', () async {
    SharedPreferences.setMockInitialValues({});
    final state = StudioState();
    await state.initialize();
    state.newPath();
    state.beginRouteSelection();
    state.pickRoutePoint(-70, 0);
    state.pickRoutePoint(70, 0);
    expect(state.path.points.first.x, closeTo(-62.5, 1e-9));
    expect(state.path.points.last.x, closeTo(62.5, 1e-9));
    expect(state.status, contains('Adjusted 2 poses'));
    expect(state.wallCollision, isNull);
    state.dispose();
  });

  test('crowded nine-pose generation keeps the full box inside', () {
    final source = StudioPath();
    final anchors = [
      Waypoint(-10, -58),
      Waypoint(-35, -57),
      Waypoint(-57, -57),
      Waypoint(-48, -45),
      Waypoint(-51, -23),
      Waypoint(-59, -23),
      Waypoint(-43, -58),
      Waypoint(12, -58),
      Waypoint(60, -35),
    ];
    final plan = RoutePlanner.optimize(
      source: source,
      anchors: anchors,
      robotWidth: 18,
      robotLength: 18,
    );
    expect(plan.waypoints.length, anchors.length);
    final generated = GeneratedPath(StudioPath(points: plan.waypoints));
    expect(RobotFootprint.firstWallCollision(generated, 18, 18), isNull);
    expect(generated.at(.25).speed, greaterThan(1));
  });

  test(
    'generation preserves every pose and undo restores original curves',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = StudioState();
      await state.initialize();
      final original = state.path.points.map((p) => p.toJson()).toList();
      final baseline = state.generated.duration;
      state.generateRoute();
      expect(state.path.points.length, original.length);
      for (var i = 0; i < original.length; i++) {
        expect(state.path.points[i].x, original[i]['x']);
        expect(state.path.points[i].y, original[i]['y']);
        expect(state.path.points[i].heading, original[i]['heading']);
      }
      expect(state.generated.duration, lessThan(baseline));
      expect(state.path.points[1].outgoing, isNotNull);
      for (final sample in state.generated.timedSamples) {
        expect(sample.speed, lessThanOrEqualTo(state.path.maxSpeed + 1e-6));
        expect(
          math.sqrt(sample.ax * sample.ax + sample.ay * sample.ay),
          lessThanOrEqualTo(state.path.maxAcceleration + 1e-6),
        );
        expect(
          sample.omega.abs(),
          lessThanOrEqualTo(state.path.maxOmega * math.pi / 180 + 1e-6),
        );
        expect(
          sample.alpha.abs(),
          lessThanOrEqualTo(state.path.maxAlpha * math.pi / 180 + 1e-6),
        );
      }
      state.undo();
      expect(state.path.points.map((p) => p.toJson()).toList(), original);
      state.dispose();
    },
  );

  test(
    'two clicks create a route and fast motion reduces travel time',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = StudioState();
      await state.initialize();
      state.newPath();
      state.generateRoute();
      expect(state.tool, EditorTool.route);
      state.pickRoutePoint(-45, -40);
      expect(state.pendingRouteStart, isNotNull);
      state.pickRoutePoint(45, 40);
      expect(state.path.points.length, 2);
      expect(state.tool, EditorTool.select);
      expect(
        state.path.points.first.heading,
        closeTo(math.atan2(80, 90), 1e-9),
      );
      state.path.maxSpeed = 32;
      state.path.maxAcceleration = 48;
      state.path.maxOmega = 150;
      state.path.maxAlpha = 240;
      state.generated = GeneratedPath(state.path);
      final slowDuration = state.generated.duration;
      state.applyFastMotion();
      expect(state.path.maxSpeed, 60);
      expect(state.path.maxAcceleration, 100);
      expect(state.generated.duration, lessThan(slowDuration));
      state.dispose();
    },
  );
}
