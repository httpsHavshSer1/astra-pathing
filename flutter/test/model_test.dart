import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astra_path_studio/model.dart';
import 'package:astra_path_studio/studio_state.dart';

void main() {
  test('Curve interpolates waypoints and shares tangents', () {
    final path = StudioPath.example(), g = GeneratedPath(StudioPath.example());
    for (var i = 0; i < g.curves.length; i++) {
      expect(
        (g.curves[i].position(0) - path.points[i].position).distance,
        lessThan(1e-8),
      );
      expect(
        (g.curves[i].position(1) - path.points[i + 1].position).distance,
        lessThan(1e-8),
      );
      if (i > 0) {
        expect(
          (g.curves[i - 1].derivative(1) - g.curves[i].derivative(0)).distance,
          lessThan(1e-8),
        );
      }
    }
    expect(g.at(0).speed, 0);
    expect(g.at(g.duration).speed, closeTo(0, 1e-8));
  });
  test('Legacy handles carry translation and heading through a waypoint', () {
    final path = StudioPath(
      samplePeriod: .01,
      points: [
        Waypoint(-45, 0, 0, null, const Offset(-30, 0)),
        Waypoint(0, 0, .6, const Offset(-2, 0), Offset.zero),
        Waypoint(45, 0, 1.2, const Offset(30, 0)),
      ],
    );
    final generated = GeneratedPath(path);
    final left = generated.curves.first, right = generated.curves.last;
    expect((left.derivative(1) - right.derivative(0)).distance, lessThan(1e-8));
    expect(left.derivative(1).distance, greaterThan(10));
    expect(left.heading(1), closeTo(right.heading(0), 1e-9));
    expect(
      left.headingDerivative(1),
      closeTo(right.headingDerivative(0), 1e-9),
    );
    expect(left.headingDerivative(1), greaterThan(0));

    var lower = 0.0, upper = generated.duration;
    for (var i = 0; i < 60; i++) {
      final middle = (lower + upper) / 2;
      if (generated.at(middle).x < 0) {
        lower = middle;
      } else {
        upper = middle;
      }
    }
    final jointTime = (lower + upper) / 2;
    final joint = generated.at(jointTime);
    expect(joint.position.dx, closeTo(0, 1e-6));
    expect(joint.speed, greaterThan(1));
    expect(joint.omega, greaterThan(0));
    final before = generated.at(jointTime - 1e-5);
    final after = generated.at(jointTime + 1e-5);
    expect((before.position - after.position).distance, lessThan(.01));
    expect((before.vx - after.vx).abs(), lessThan(.01));
    expect((before.omega - after.omega).abs(), lessThan(.01));
    final exported = (generated.robotJson()['sampled_points'] as List)
        .cast<Map<String, dynamic>>();
    final nearJoin = exported.reduce((a, b) {
      final ax = ((a['x'] as double) - 72 * .0254).abs();
      final bx = ((b['x'] as double) - 72 * .0254).abs();
      return ax < bx ? a : b;
    });
    expect(nearJoin['x_velocity'], greaterThan(.01));
  });
  test('Dragging one control keeps both sides of a pose tangent', () {
    final state = StudioState();
    state.project = StudioProject(
      paths: [
        StudioPath(points: [Waypoint(-30, 0), Waypoint(0, 0), Waypoint(30, 0)]),
      ],
    );
    state.selected = 1;
    state.moveHandle(true, const Offset(10, 5));
    expect(state.waypoint!.incoming, const Offset(-10, -5));
    final left = state.generated.curves.first;
    final right = state.generated.curves.last;
    expect((left.derivative(1) - right.derivative(0)).distance, lessThan(1e-8));
    state.dispose();
  });
  test('Explicit Bézier controls survive a midpoint insertion', () {
    SharedPreferences.setMockInitialValues({});
    final s = StudioState();
    s.project = StudioProject(
      paths: [
        StudioPath(
          points: [
            Waypoint(-40, -40, 0, null, const Offset(-35, 20)),
            Waypoint(40, 40, 0, const Offset(10, 50)),
          ],
        ),
      ],
    );
    s.generated = GeneratedPath(s.path);
    s.selected = 0;
    final original = s.generated.curves.single;
    s.insertPoint();
    expect(s.generated.curves.length, 2);
    for (var i = 0; i <= 20; i++) {
      final t = i / 20;
      final half = t <= .5 ? s.generated.curves.first : s.generated.curves.last;
      final local = t <= .5 ? 2 * t : 2 * t - 1;
      expect(
        (half.position(local) - original.position(t)).distance,
        lessThan(1e-8),
      );
    }
    final restored = importDocument(jsonEncode(s.project.toJson()));
    expect(restored.path.points[1].incoming, s.path.points[1].incoming);
    expect(restored.path.points[1].outgoing, s.path.points[1].outgoing);
    s.dispose();
  });
  test('Imports the former web project without dropping handles', () {
    final doc = {
      'schemaVersion': 1,
      'units': 'in',
      'angleUnits': 'rad',
      'coordinateFrame': 'center-x-right-y-up',
      'name': 'Web project',
      'pathName': 'Opening',
      'robot': {'width': 16, 'length': 18},
      'nodes': [
        {
          'position': {'x': -30, 'y': -20},
          'heading': 0,
          'incoming': {'x': -35, 'y': -20},
          'outgoing': {'x': -20, 'y': -10},
        },
        {
          'position': {'x': 30, 'y': 20},
          'heading': 1,
          'incoming': {'x': 20, 'y': 10},
          'outgoing': {'x': 35, 'y': 20},
        },
      ],
    };
    final imported = importDocument(jsonEncode(doc));
    expect(imported.name, 'Web project');
    expect(imported.path.points.first.outgoing, const Offset(-20, -10));
    expect(imported.path.points.last.incoming, const Offset(20, 10));
  });
  test('Timing respects linear and angular limits over random paths', () {
    final rng = math.Random(23477);
    for (var trial = 0; trial < 12; trial++) {
      final p = StudioPath(
        points: [
          for (var i = 0; i < 5; i++)
            Waypoint(
              rng.nextDouble() * 130 - 65,
              rng.nextDouble() * 130 - 65,
              rng.nextDouble() * 6 - 3,
            ),
        ],
      );
      final g = GeneratedPath(p);
      for (var i = 0; i < 700; i++) {
        final s = g.at(g.duration * i / 699);
        expect(s.speed, lessThanOrEqualTo(p.maxSpeed * 1.00001));
        expect(
          math.sqrt(s.ax * s.ax + s.ay * s.ay),
          lessThanOrEqualTo(p.maxAcceleration * 1.00001),
        );
        expect(
          s.omega.abs(),
          lessThanOrEqualTo(p.maxOmega * math.pi / 180 * 1.00001),
        );
        expect(
          s.alpha.abs(),
          lessThanOrEqualTo(p.maxAlpha * math.pi / 180 * 1.00001),
        );
      }
    }
  });
  test('Long paths begin moving promptly with bounded acceleration', () {
    final path = StudioPath(
      points: [
        Waypoint(-50, -40),
        Waypoint(-30, -20),
        Waypoint(-5, 5),
        Waypoint(25, 25),
        Waypoint(45, 40),
        Waypoint(30, 55),
        Waypoint(10, 40),
        Waypoint(-15, 25),
        Waypoint(-40, 5),
      ],
    );
    final generated = GeneratedPath(path);
    expect(generated.at(0).speed, 0);
    expect(
      (generated.at(.25).position - path.points.first.position).distance,
      greaterThan(.5),
    );
    expect(generated.at(.25).speed, greaterThan(1));
    expect(
      generated.at(generated.duration).position,
      path.points.last.position,
    );
  });
  test('Export matches Polar keys and converts inches to corner meters', () {
    final p = StudioPath(
      name: 'Conversion test',
      points: [Waypoint(-72, -72, 0), Waypoint(0, 0, math.pi / 2)],
    );
    final g = GeneratedPath(p), j = g.robotJson();
    final samples = j['sampled_points'] as List;
    expect(samples.first['x'], 0);
    expect(samples.first['y'], 0);
    expect(samples.last['x'], closeTo(1.8288, 1e-9));
    expect(samples.last['y'], closeTo(1.8288, 1e-9));
    expect(samples.last['angle'], closeTo(math.pi / 2, 1e-9));
    expect(samples.last['time'], g.duration);
    for (var i = 1; i < samples.length; i++) {
      expect(samples[i]['time'], greaterThan(samples[i - 1]['time']));
    }
    for (final key in [
      'time',
      'x',
      'y',
      'angle',
      'x_velocity',
      'y_velocity',
      'angular_velocity',
      'x_acceleration',
      'y_acceleration',
      'angular_acceleration',
    ]) {
      expect(samples.first.containsKey(key), isTrue);
    }
  });
  test('Each marker exports once, including endpoint', () {
    final p = StudioPath.example()
      ..markers = [
        EventMarker('intake', 0),
        EventMarker('shoot', .5),
        EventMarker('stop', 1),
      ];
    final j = GeneratedPath(p).robotJson();
    final commands = [
      for (final s in j['sampled_points']) ...?(s['commands'] as List?),
    ];
    expect(commands.map((c) => c['command']), ['intake', 'shoot', 'stop']);
  });
  test('Heading crosses pi on shortest arc', () {
    final p = StudioPath(
      points: [
        Waypoint(0, 0, 179 * math.pi / 180),
        Waypoint(20, 0, -179 * math.pi / 180),
      ],
    );
    final g = GeneratedPath(p);
    expect(g.curves.first.dh, closeTo(2 * math.pi / 180, 1e-9));
    expect(g.at(g.duration / 2).heading, closeTo(math.pi, 1e-9));
  });
  test('Wrapped headings remain numerically continuous across joins', () {
    final path = StudioPath(
      points: [
        Waypoint(-30, 0, 170 * math.pi / 180),
        Waypoint(0, 0, -170 * math.pi / 180),
        Waypoint(30, 0, -150 * math.pi / 180),
      ],
    );
    final generated = GeneratedPath(path);
    expect(
      generated.curves.first.heading(1),
      closeTo(generated.curves.last.heading(0), 1e-9),
    );
    final keyPoints = generated.robotJson()['key_points'] as List;
    expect(
      (keyPoints[1]['angle'] as double) - (keyPoints[0]['angle'] as double),
      closeTo(20 * math.pi / 180, 1e-9),
    );
  });
  test(
    'Project and robot exports restore editable data and reject bad inputs',
    () {
      final p = StudioProject.example();
      p.paths.add(StudioPath(name: 'Second'));
      p.path.markers.add(EventMarker('intake', .4));
      expect(importDocument(jsonEncode(p.toJson())).toJson(), p.toJson());
      expect(
        importDocument(
          jsonEncode(GeneratedPath(p.path).robotJson()),
        ).path.toJson(),
        p.path.toJson(),
      );
      expect(
        () => importDocument('{"format":"astrapath.project","version":99}'),
        throwsFormatException,
      );
      expect(
        () => GeneratedPath(StudioPath()).robotJson(),
        throwsFormatException,
      );
      final invalid = p.toJson();
      invalid['robotWidth'] = -1;
      expect(() => StudioProject.fromJson(invalid), throwsFormatException);
    },
  );
  test('Undo, redo, multiple paths, playback, and local recovery', () async {
    SharedPreferences.setMockInitialValues({});
    final s = StudioState();
    await s.initialize();
    s.enter(fresh: true);
    s.addPoint(0, 0);
    s.addPoint(20, 20);
    s.undo();
    expect(s.path.points.length, 1);
    s.redo();
    expect(s.path.points.length, 2);
    s.duplicatePath();
    expect(s.project.paths.length, 2);
    s.deletePath();
    expect(s.project.paths.length, 1);
    s.togglePlay();
    s.tick(.5);
    expect(s.playhead, .5);
    s.seek(s.generated.duration);
    s.togglePlay();
    expect(s.playhead, 0);
    await s.persist();
    final restored = StudioState();
    await restored.initialize();
    expect(restored.project.toJson(), s.project.toJson());
    expect(restored.hasRecovery, true);
    s.dispose();
    restored.dispose();
  });
  test('Generate actual robot compatibility fixture', () async {
    final dir = Directory(
      Platform.environment['ASTRA_ARTIFACTS'] ?? 'build/review',
    );
    await dir.create(recursive: true);
    final p = StudioProject.example();
    await File('${dir.path}/Starlight-cycle.json').writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(GeneratedPath(p.path).robotJson()),
    );
    await File(
      '${dir.path}/Into-the-starlight.astra',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(p.toJson()));
  });
}
