import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

double wrapAngle(double a) =>
    a >= -math.pi && a < math.pi ? a : (a + math.pi) % (2 * math.pi) - math.pi;
double number(Object? v, String name, double min, double max) {
  if (v is! num || !v.isFinite || v < min || v > max) {
    throw FormatException('$name must be between $min and $max.');
  }
  return v.toDouble();
}

class Waypoint {
  double x, y, heading;
  Offset? incoming, outgoing;
  Waypoint(this.x, this.y, [this.heading = 0, this.incoming, this.outgoing]);
  Offset get position => Offset(x, y);
  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'heading': heading,
    if (incoming != null) 'incoming': {'x': incoming!.dx, 'y': incoming!.dy},
    if (outgoing != null) 'outgoing': {'x': outgoing!.dx, 'y': outgoing!.dy},
  };
  static Offset? _control(Object? value, String name) {
    if (value == null) return null;
    if (value is! Map) throw FormatException('Invalid $name control.');
    return Offset(
      number(value['x'], '$name X', -1000, 1000),
      number(value['y'], '$name Y', -1000, 1000),
    );
  }

  factory Waypoint.fromJson(Map<String, dynamic> j) => Waypoint(
    number(j['x'], 'X', -72, 72),
    number(j['y'], 'Y', -72, 72),
    wrapAngle(number(j['heading'], 'Heading', -100, 100)),
    _control(j['incoming'], 'Incoming'),
    _control(j['outgoing'], 'Outgoing'),
  );
}

class EventMarker {
  String name;
  double fraction;
  EventMarker(this.name, this.fraction);
  Map<String, dynamic> toJson() => {'name': name, 'fraction': fraction};
}

class StudioPath {
  String name;
  List<Waypoint> points;
  List<EventMarker> markers;
  double smoothing, maxSpeed, maxAcceleration, maxOmega, maxAlpha, samplePeriod;
  StudioPath({
    this.name = 'Untitled path',
    List<Waypoint>? points,
    List<EventMarker>? markers,
    this.smoothing = .72,
    this.maxSpeed = 60,
    this.maxAcceleration = 100,
    this.maxOmega = 240,
    this.maxAlpha = 360,
    this.samplePeriod = .05,
  }) : points = points ?? [],
       markers = markers ?? [];
  StudioPath copy() => StudioPath.fromJson(toJson());
  Map<String, dynamic> toJson() => {
    'name': name,
    'waypoints': points.map((p) => p.toJson()).toList(),
    'markers': markers.map((m) => m.toJson()).toList(),
    'smoothing': smoothing,
    'maxSpeed': maxSpeed,
    'maxAcceleration': maxAcceleration,
    'maxOmega': maxOmega,
    'maxAlpha': maxAlpha,
    'samplePeriod': samplePeriod,
  };
  factory StudioPath.fromJson(Map<String, dynamic> j) {
    final list = j['waypoints'];
    if (list is! List || list.length > 150) {
      throw const FormatException('Maximum 150 waypoints per path.');
    }
    final name = j['name'];
    if (name is! String || name.length > 80) {
      throw const FormatException('Invalid path name.');
    }
    final result = StudioPath(
      name: name,
      points: list
          .map((p) => Waypoint.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      smoothing: number(j['smoothing'] ?? .72, 'Smoothing', 0, 1),
      maxSpeed: number(j['maxSpeed'] ?? 60, 'Max speed', 1, 120),
      maxAcceleration: number(
        j['maxAcceleration'] ?? 100,
        'Max acceleration',
        1,
        200,
      ),
      maxOmega: number(j['maxOmega'] ?? 240, 'Max angular speed', 5, 720),
      maxAlpha: number(
        j['maxAlpha'] ?? 360,
        'Max angular acceleration',
        5,
        1440,
      ),
      samplePeriod: number(j['samplePeriod'] ?? .05, 'Sample period', .01, .2),
    );
    final markers = j['markers'] ?? [];
    if (markers is! List || markers.length > 100) {
      throw const FormatException('Maximum 100 event markers.');
    }
    for (final m in markers) {
      if (m['name'] is! String || (m['name'] as String).length > 80) {
        throw const FormatException('Invalid marker name.');
      }
      result.markers.add(
        EventMarker(
          m['name'] as String,
          number(m['fraction'], 'Marker position', 0, 1),
        ),
      );
    }
    return result;
  }
  static StudioPath example() => StudioPath(
    name: 'Sample path',
    points: [
      Waypoint(-48, -43, math.pi / 2),
      Waypoint(-41, 17, .5),
      Waypoint(4, 41, -.35),
      Waypoint(43, 15, -math.pi / 2),
      Waypoint(31, -35, -math.pi),
    ],
    markers: [],
  );
}

class StudioProject {
  String name;
  List<StudioPath> paths;
  int active;
  double robotWidth, robotLength;
  StudioProject({
    this.name = 'Untitled project',
    List<StudioPath>? paths,
    this.active = 0,
    this.robotWidth = 18,
    this.robotLength = 18,
  }) : paths = paths ?? [StudioPath()];
  StudioPath get path => paths[active];
  Map<String, dynamic> toJson() => {
    'format': 'astrapath.project',
    'version': 2,
    'name': name,
    'active': active,
    'robotWidth': robotWidth,
    'robotLength': robotLength,
    'paths': paths.map((p) => p.toJson()).toList(),
  };
  StudioProject copy() => StudioProject.fromJson(toJson());
  factory StudioProject.fromJson(Map<String, dynamic> j) {
    if (j['format'] != 'astrapath.project' || j['version'] != 2) {
      throw const FormatException('Unsupported project version.');
    }
    if (j['name'] is! String || (j['name'] as String).length > 80) {
      throw const FormatException('Invalid project name.');
    }
    final paths = j['paths'];
    if (paths is! List || paths.isEmpty || paths.length > 30) {
      throw const FormatException('A project needs 1–30 paths.');
    }
    return StudioProject(
      name: j['name'] as String,
      paths: paths
          .map((p) => StudioPath.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      active: number(j['active'], 'Active path', 0, paths.length - 1).toInt(),
      robotWidth: number(j['robotWidth'], 'Robot width', 1, 30),
      robotLength: number(j['robotLength'], 'Robot length', 1, 30),
    );
  }
  static StudioProject example() =>
      StudioProject(name: 'Example project', paths: [StudioPath.example()]);
}

class CurveSegment {
  final Offset a, b, c, d;
  final double h, dh, headingStartRate, headingEndRate;
  CurveSegment(
    this.a,
    this.b,
    this.c,
    this.d,
    this.h,
    this.dh, [
    this.headingStartRate = 0,
    this.headingEndRate = 0,
  ]);
  Offset position(double t) {
    final u = 1 - t;
    return a * (u * u * u) +
        b * (3 * u * u * t) +
        c * (3 * u * t * t) +
        d * (t * t * t);
  }

  Offset derivative(double t) =>
      (b - a) * (3 * (1 - t) * (1 - t)) +
      (c - b) * (6 * (1 - t) * t) +
      (d - c) * (3 * t * t);
  Offset second(double t) =>
      (c - b * 2 + a) * (6 * (1 - t)) + (d - c * 2 + b) * (6 * t);
  double get _headingA => 3 * dh - 2 * headingStartRate - headingEndRate;
  double get _headingB => headingStartRate + headingEndRate - 2 * dh;
  double heading(double t) =>
      h + headingStartRate * t + _headingA * t * t + _headingB * t * t * t;
  double headingDerivative(double t) =>
      headingStartRate + 2 * _headingA * t + 3 * _headingB * t * t;
  double headingSecond(double t) => 2 * _headingA + 6 * _headingB * t;
  double get maxHeadingDerivative {
    var result = math.max(headingStartRate.abs(), headingEndRate.abs());
    if (_headingB.abs() > 1e-9) {
      final vertex = -_headingA / (3 * _headingB);
      if (vertex > 0 && vertex < 1) {
        result = math.max(result, headingDerivative(vertex).abs());
      }
    }
    return result;
  }

  double get maxHeadingSecond =>
      math.max(headingSecond(0).abs(), headingSecond(1).abs());

  static (List<double>, List<double>) headingPlan(List<Waypoint> points) {
    final headings = <double>[points.first.heading];
    final changes = <double>[];
    for (var i = 1; i < points.length; i++) {
      final delta = wrapAngle(points[i].heading - points[i - 1].heading);
      changes.add(delta);
      headings.add(headings.last + delta);
    }
    final rates = List<double>.filled(points.length, 0);
    if (changes.isNotEmpty) {
      rates[0] = changes.first;
      rates[rates.length - 1] = changes.last;
    }
    for (var i = 1; i < points.length - 1; i++) {
      final before = changes[i - 1], after = changes[i];
      if (before * after > 0) {
        rates[i] = 2 * before * after / (before + after);
      }
    }
    return (headings, rates);
  }

  static double minimumThroughTangent(List<Waypoint> points, int index) {
    if (index <= 0 || index >= points.length - 1) return 0;
    final before =
        (points[index].position - points[index - 1].position).distance;
    final after =
        (points[index + 1].position - points[index].position).distance;
    return math.min(before, after) * .3;
  }

  static Offset keepMovingThrough(
    List<Waypoint> points,
    int index,
    Offset tangent,
  ) {
    final minimum = minimumThroughTangent(points, index);
    if (minimum == 0 || tangent.distance >= minimum) return tangent;
    var direction = tangent;
    if (direction.distance < 1e-6) {
      direction = points[index + 1].position - points[index - 1].position;
    }
    if (direction.distance < 1e-6) {
      direction = points[index + 1].position - points[index].position;
    }
    return direction.distance < 1e-6
        ? tangent
        : direction * (minimum / direction.distance);
  }
}

class MotionSample {
  final double time, x, y, heading, vx, vy, omega, ax, ay, alpha;
  const MotionSample(
    this.time,
    this.x,
    this.y,
    this.heading,
    this.vx,
    this.vy,
    this.omega,
    this.ax,
    this.ay,
    this.alpha,
  );
  Offset get position => Offset(x, y);
  double get speed => math.sqrt(vx * vx + vy * vy);
}

/// C1 cubic pose geometry with an acceleration-limited global progress law.
/// Global derivative bounds keep linear and angular motion within the chosen
/// limits without the long near-stationary lead-in of a quintic time law.
class GeneratedPath {
  final StudioPath source;
  final List<CurveSegment> curves = [];
  final List<Offset> polyline = [];
  double duration = 0, length = 0;
  _ProgressProfile? _profile;

  static double estimatedDurationForBounds(
    StudioPath source,
    int segmentCount,
    double maxFirst,
    double maxSecond,
    double maxHeadingFirst,
    double maxHeadingSecond,
  ) => _ProgressProfile.fromBounds(
    source,
    segmentCount,
    maxFirst,
    maxSecond,
    maxHeadingFirst,
    maxHeadingSecond,
  ).duration;

  GeneratedPath(this.source) {
    final p = source.points;
    if (p.length < 2) return;
    final (headings, headingRates) = CurveSegment.headingPlan(p);
    final tangents = <Offset>[];
    for (var i = 0; i < p.length; i++) {
      final point = p[i];
      final before = i > 0 && point.incoming != null
          ? (point.position - point.incoming!) * 3
          : null;
      final after = i < p.length - 1 && point.outgoing != null
          ? (point.outgoing! - point.position) * 3
          : null;
      final automatic = i == 0
          ? (p[1].position - point.position) * source.smoothing
          : i == p.length - 1
          ? (point.position - p[i - 1].position) * source.smoothing
          : (p[i + 1].position - p[i - 1].position) * (source.smoothing / 2);
      final tangent = before != null && after != null
          ? (before + after) / 2
          : before ?? after ?? automatic;
      tangents.add(CurveSegment.keepMovingThrough(p, i, tangent));
    }
    double m1 = 0, m2 = 0, h1 = 0, h2 = 0;
    for (var i = 0; i < p.length - 1; i++) {
      final a = p[i], d = p[i + 1];
      final c = CurveSegment(
        a.position,
        a.position + tangents[i] / 3,
        d.position - tangents[i + 1] / 3,
        d.position,
        headings[i],
        headings[i + 1] - headings[i],
        headingRates[i],
        headingRates[i + 1],
      );
      curves.add(c);
      for (final v in [(c.b - c.a) * 3, (c.c - c.b) * 3, (c.d - c.c) * 3]) {
        m1 = math.max(m1, v.distance);
      }
      for (final v in [(c.c - c.b * 2 + c.a) * 6, (c.d - c.c * 2 + c.b) * 6]) {
        m2 = math.max(m2, v.distance);
      }
      h1 = math.max(h1, c.maxHeadingDerivative);
      h2 = math.max(h2, c.maxHeadingSecond);
      for (var k = 0; k <= 80; k++) {
        if (i > 0 && k == 0) continue;
        final v = c.position(k / 80);
        if (polyline.isNotEmpty) length += (v - polyline.last).distance;
        polyline.add(v);
      }
    }
    _profile = _ProgressProfile.fromBounds(
      source,
      curves.length,
      m1,
      m2,
      h1,
      h2,
    );
    duration = _profile!.duration;
  }
  MotionSample at(double seconds) {
    if (curves.isEmpty) {
      final p = source.points.isEmpty ? Waypoint(0, 0) : source.points.first;
      return MotionSample(0, p.x, p.y, p.heading, 0, 0, 0, 0, 0, 0);
    }
    final progress = _profile!.at(seconds);
    final param = progress.$1;
    final i = math.min(curves.length - 1, param.floor());
    final t = (param - i).clamp(0.0, 1.0);
    final c = curves[i],
        p = c.position(t),
        v = c.derivative(t),
        a = c.second(t);
    final rate = progress.$2;
    final accel = progress.$3;
    return MotionSample(
      seconds.clamp(0, duration).toDouble(),
      p.dx,
      p.dy,
      c.heading(t),
      v.dx * rate,
      v.dy * rate,
      c.headingDerivative(t) * rate,
      a.dx * rate * rate + v.dx * accel,
      a.dy * rate * rate + v.dy * accel,
      c.headingSecond(t) * rate * rate + c.headingDerivative(t) * accel,
    );
  }

  List<MotionSample> get timedSamples {
    if (curves.isEmpty) return [];
    final count = (duration / source.samplePeriod).ceil();
    if (count > 60000) {
      throw const FormatException(
        'Too many samples. Increase sample period or split the path.',
      );
    }
    return [
      for (var i = 0; i < count; i++) at(i * source.samplePeriod),
      at(duration),
    ];
  }

  Map<String, dynamic> robotJson() {
    if (curves.isEmpty || length < .01) {
      throw const FormatException(
        'Add two distinct waypoints before exporting.',
      );
    }
    const m = .0254;
    final samples = timedSamples;
    final keyHeadings = CurveSegment.headingPlan(source.points).$1;
    final pending = List<EventMarker>.from(source.markers)
      ..sort((a, b) => a.fraction.compareTo(b.fraction));
    final points = <Map<String, dynamic>>[];
    for (final s in samples) {
      final commands = <Map<String, dynamic>>[];
      while (pending.isNotEmpty &&
          pending.first.fraction * duration <= s.time + 1e-8) {
        commands.add({'command': pending.removeAt(0).name});
      }
      points.add({
        'time': s.time,
        'x': (s.x + 72) * m,
        'y': (s.y + 72) * m,
        'angle': s.heading,
        'x_velocity': s.vx * m,
        'y_velocity': s.vy * m,
        'angular_velocity': s.omega,
        'x_acceleration': s.ax * m,
        'y_acceleration': s.ay * m,
        'angular_acceleration': s.alpha,
        if (commands.isNotEmpty) 'commands': commands,
      });
    }
    return {
      'meta_data': {
        'path_name': source.name,
        'sample_rate': source.samplePeriod,
        'robot_name': 'FTC 23477',
        'field_name': 'FTC 144 inch field',
        'generator': 'AstraPathing Flutter 2.9',
        'distance_unit': 'meters',
        'angle_unit': 'radians',
        'origin': 'bottom_left',
        'x_positive': 'right',
        'y_positive': 'up',
        'heading_zero': 'positive_x',
        'heading_positive': 'counterclockwise',
        'duration': duration,
        'length_meters': length * m,
      },
      'commands': source.markers.map((e) => e.name).toSet().toList(),
      'key_points': [
        for (var i = 0; i < source.points.length; i++)
          {
            'x': (source.points[i].x + 72) * m,
            'y': (source.points[i].y + 72) * m,
            'angle': keyHeadings[i],
          },
      ],
      'sampled_points': points,
      'astra_editor': source.toJson(),
    };
  }
}

class _ProgressProfile {
  final double total, acceleration, peakRate, rampTime, cruiseTime;
  final double rampDistance, duration;
  const _ProgressProfile(
    this.total,
    this.acceleration,
    this.peakRate,
    this.rampTime,
    this.cruiseTime,
    this.rampDistance,
    this.duration,
  );

  factory _ProgressProfile.fromBounds(
    StudioPath source,
    int segmentCount,
    double first,
    double second,
    double headingFirst,
    double headingSecond,
  ) {
    final omega = source.maxOmega * math.pi / 180;
    final alpha = source.maxAlpha * math.pi / 180;
    // Half the acceleration budget is reserved for curvature, half for
    // speeding up or slowing down along the curve.
    final topRate = [
      100.0,
      source.maxSpeed / math.max(first, 1e-8),
      omega / math.max(headingFirst, 1e-8),
      math.sqrt(source.maxAcceleration * .5 / math.max(second, 1e-8)),
      math.sqrt(alpha * .5 / math.max(headingSecond, 1e-8)),
    ].reduce(math.min);
    final acceleration = [
      100.0,
      source.maxAcceleration * .5 / math.max(first, 1e-8),
      alpha * .5 / math.max(headingFirst, 1e-8),
    ].reduce(math.min);
    final total = segmentCount.toDouble();
    final peak = math.min(topRate, math.sqrt(total * acceleration));
    final rampTime = peak / acceleration;
    final rampDistance = peak * peak / (2 * acceleration);
    final cruiseTime = math.max(0, total - 2 * rampDistance) / peak;
    return _ProgressProfile(
      total,
      acceleration,
      peak,
      rampTime,
      cruiseTime,
      rampDistance,
      2 * rampTime + cruiseTime,
    );
  }

  (double, double, double) at(double seconds) {
    if (seconds <= 0) return (0, 0, acceleration);
    if (seconds >= duration) return (total, 0, 0);
    if (seconds < rampTime) {
      return (
        .5 * acceleration * seconds * seconds,
        acceleration * seconds,
        acceleration,
      );
    }
    if (seconds < rampTime + cruiseTime) {
      final elapsed = seconds - rampTime;
      return (rampDistance + peakRate * elapsed, peakRate, 0);
    }
    final remaining = duration - seconds;
    return (
      total - .5 * acceleration * remaining * remaining,
      acceleration * remaining,
      -acceleration,
    );
  }
}

StudioProject importDocument(String text) {
  if (text.length > 16 * 1024 * 1024) {
    throw const FormatException('File exceeds 16 MB.');
  }
  final j = jsonDecode(text);
  if (j is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object.');
  }
  if (j['format'] == 'astrapath.project') return StudioProject.fromJson(j);
  if (j['schemaVersion'] == 1 &&
      j['units'] == 'in' &&
      j['angleUnits'] == 'rad' &&
      j['coordinateFrame'] == 'center-x-right-y-up') {
    final nodes = j['nodes'];
    if (nodes is! List || nodes.length < 2 || nodes.length > 100) {
      throw const FormatException('Expected 2–100 Moonlanders waypoints.');
    }
    final points = <Waypoint>[];
    for (final item in nodes) {
      if (item is! Map) throw const FormatException('Invalid waypoint.');
      final node = Map<String, dynamic>.from(item);
      final position = node['position'];
      if (position is! Map) {
        throw const FormatException('Invalid waypoint position.');
      }
      final p = Map<String, dynamic>.from(position);
      points.add(
        Waypoint.fromJson({
          'x': p['x'],
          'y': p['y'],
          'heading': node['heading'],
          'incoming': node['incoming'],
          'outgoing': node['outgoing'],
        }),
      );
    }
    final projectName = j['name'];
    final pathName = j['pathName'];
    if (projectName is! String ||
        projectName.length > 80 ||
        pathName is! String ||
        pathName.length > 80) {
      throw const FormatException('Invalid Moonlanders project name.');
    }
    final robot = j['robot'];
    if (robot is! Map) throw const FormatException('Missing robot dimensions.');
    return StudioProject(
      name: projectName,
      paths: [StudioPath(name: pathName, points: points)],
      robotWidth: number(robot['width'], 'Robot width', 1, 30),
      robotLength: number(robot['length'], 'Robot length', 1, 30),
    );
  }
  if (j['astra_editor'] is Map<String, dynamic>) {
    return StudioProject(paths: [StudioPath.fromJson(j['astra_editor'])]);
  }
  if (j['format'] == 'astrapath.path' && j['version'] == 1) {
    if (j['units']?['distance'] != 'inches' ||
        j['coordinates']?['origin'] != 'field_center') {
      throw const FormatException('Unsupported AstraPath coordinate frame.');
    }
    final p = StudioPath.fromJson({
      'name': j['name'] ?? 'Imported path',
      'waypoints': j['waypoints'],
      'smoothing': j['generator']?['smoothing'] ?? .72,
    });
    return StudioProject(name: p.name, paths: [p]);
  }
  if (j['sampled_points'] is List && j['key_points'] is List) {
    final p = StudioPath(
      name: (j['meta_data']?['path_name'] ?? 'Imported Polar path').toString(),
    );
    final keys = j['key_points'] as List;
    if (keys.length > 150) {
      throw const FormatException('Maximum 150 waypoints.');
    }
    for (final k in keys) {
      p.points.add(
        Waypoint(
          number(k['x'], 'X meters', 0, 3.6576) / .0254 - 72,
          number(k['y'], 'Y meters', 0, 3.6576) / .0254 - 72,
          wrapAngle(number(k['angle'], 'Angle', -100, 100)),
        ),
      );
    }
    return StudioProject(name: p.name, paths: [p]);
  }
  throw const FormatException(
    'Open an Astra project, AstraPath JSON, or Polar path file.',
  );
}
