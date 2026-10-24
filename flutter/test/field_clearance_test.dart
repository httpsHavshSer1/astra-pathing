import 'dart:math' as math;

import 'package:astra_path_studio/field_clearance.dart';
import 'package:astra_path_studio/model.dart';
import 'package:astra_path_studio/studio_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Full rotated robot box determines wall clearance', () {
    expect(RobotFootprint.wallViolation(const Offset(60, 0), 0, 18, 18), 0);
    expect(
      RobotFootprint.wallViolation(const Offset(64, 0), 0, 18, 18),
      greaterThan(0),
    );
    final reach = RobotFootprint.halfExtents(math.pi / 4, 18, 30);
    expect(reach.dx, greaterThan(15));
    expect(reach.dy, greaterThan(15));
    final fitted = RobotFootprint.clampCenter(
      const Offset(70, -70),
      math.pi / 4,
      18,
      30,
    );
    expect(RobotFootprint.wallViolation(fitted, math.pi / 4, 18, 30), 0);
  });

  test('Swept robot box detects a curve that crosses the outer wall', () {
    final path = GeneratedPath(
      StudioPath(
        points: [
          Waypoint(40, 40, 0, null, const Offset(90, 40)),
          Waypoint(40, -40, 0, const Offset(90, -40)),
        ],
      ),
    );
    expect(RobotFootprint.firstWallCollision(path, 18, 18), isNotNull);
  });

  test('Dragging keeps the full robot inside the wall', () async {
    SharedPreferences.setMockInitialValues({});
    final state = StudioState();
    await state.initialize();
    state.movePoint(71, -71);
    expect(state.waypoint!.x, lessThanOrEqualTo(62.5));
    expect(state.waypoint!.y, greaterThanOrEqualTo(-62.5));
    expect(state.wallCollision, isNull);
    state.dispose();
  });

  test('Heading change moves the pose and handles inside the wall', () async {
    SharedPreferences.setMockInitialValues({});
    final state = StudioState();
    await state.initialize();
    state.newPath();
    state.edit(() {
      state.project.robotWidth = 10;
      state.project.robotLength = 30;
    });
    state.addPoint(55, 0);
    state.setHeading(math.pi / 2);
    state.movePoint(60, 0);
    state.edit(() {
      state.waypoint!.incoming = const Offset(54, -4);
      state.waypoint!.outgoing = const Offset(66, 4);
    });
    state.setHeading(0);
    expect(state.waypoint!.heading, 0);
    expect(state.waypoint!.x, closeTo(56.5, 1e-9));
    expect(state.waypoint!.incoming!.dx, closeTo(50.5, 1e-9));
    expect(state.waypoint!.outgoing!.dx, closeTo(62.5, 1e-9));
    expect(state.status, contains('outer wall'));
    expect(state.wallCollision, isNull);
    state.undo();
    expect(state.waypoint!.heading, math.pi / 2);
    expect(state.waypoint!.x, closeTo(60, 1e-9));
    expect(state.waypoint!.incoming!.dx, closeTo(54, 1e-9));
    state.dispose();
  });

  test('Increasing robot size moves existing poses inside the wall', () async {
    SharedPreferences.setMockInitialValues({});
    final state = StudioState();
    await state.initialize();
    state.newPath();
    state.addPoint(65, 0);
    expect(state.waypoint!.x, 62.5);
    state.setRobotSize(length: 30);
    expect(state.waypoint!.x, 56.5);
    expect(state.wallCollision, isNull);
    state.dispose();
  });

  test('Export rejects a path that sweeps the box across the wall', () async {
    SharedPreferences.setMockInitialValues({});
    final state = StudioState();
    await state.initialize();
    state.newPath();
    state.addPoint(40, 40);
    state.addPoint(40, -40);
    state.selectPoint(0);
    state.moveHandle(true, const Offset(90, 40));
    state.selectPoint(1);
    state.moveHandle(false, const Offset(90, -40));
    expect(state.wallCollision, isNotNull);
    await state.exportRobot();
    expect(state.status, contains('outer wall'));
    state.dispose();
  });
}
