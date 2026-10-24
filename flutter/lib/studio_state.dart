import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'field_clearance.dart';
import 'model.dart';
import 'route_planner.dart';

enum EditorTool { select, place, route, pan }

class StudioState extends ChangeNotifier {
  StudioState() {
    _rebuildGenerated();
  }

  StudioProject project = StudioProject.example();
  late GeneratedPath generated;
  WallCollision? wallCollision;
  bool inEditor = true,
      snap = false,
      showHandles = true,
      showFootprint = true,
      showGrid = true;
  bool playing = false, reducedMotion = false, dirty = false, busy = false;
  bool hasRecovery = false;
  double playhead = 0;
  double leftSidebarWidth = 247, rightSidebarWidth = 254;
  int selected = 0;
  EditorTool tool = EditorTool.select;
  Offset? pendingRouteStart;
  String status = '', lastSaved = '', projectFile = '';
  SharedPreferences? _prefs;
  final List<String> _undo = [], _redo = [];
  int fitRevision = 0;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  StudioPath get path => project.path;
  Waypoint? get waypoint => selected >= 0 && selected < path.points.length
      ? path.points[selected]
      : null;

  void _rebuildGenerated() {
    generated = GeneratedPath(path);
    wallCollision = RobotFootprint.firstWallCollision(
      generated,
      project.robotWidth,
      project.robotLength,
    );
  }

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      reducedMotion = _prefs!.getBool('reducedMotion') ?? false;
      leftSidebarWidth = (_prefs!.getDouble('leftSidebarWidth') ?? 247).clamp(
        190.0,
        360.0,
      );
      rightSidebarWidth = (_prefs!.getDouble('rightSidebarWidth') ?? 254).clamp(
        220.0,
        360.0,
      );
      final saved = _prefs!.getString('recovery');
      if (saved != null) {
        project = importDocument(saved);
        if (project.name == 'Into the starlight') {
          project.name = 'Example project';
        }
        for (final route in project.paths) {
          if (route.name == 'Starlight cycle') route.name = 'Sample path';
        }
        _rebuildGenerated();
        hasRecovery = true;
      }
    } catch (e) {
      status = 'Recovery could not be loaded. Your saved files are unaffected.';
    }
    notifyListeners();
  }

  String snapshot() => jsonEncode(project.toJson());
  void record() {
    _undo.add(snapshot());
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  void edit(VoidCallback change) {
    record();
    change();
    refresh();
  }

  void refresh() {
    _rebuildGenerated();
    playing = false;
    playhead = playhead.clamp(0, generated.duration).toDouble();
    selected = selected.clamp(-1, path.points.length - 1).toInt();
    dirty = true;
    hasRecovery = true;
    notifyListeners();
    persist();
  }

  Future<void> persist() async {
    try {
      await _prefs?.setString('recovery', snapshot());
    } catch (e) {
      status = 'Autosave unavailable. Use Save project to keep a copy.';
      notifyListeners();
    }
  }

  Future<void> saveSidebarWidths(double left, double right) async {
    leftSidebarWidth = left.clamp(190.0, 360.0);
    rightSidebarWidth = right.clamp(220.0, 360.0);
    try {
      await _prefs?.setDouble('leftSidebarWidth', leftSidebarWidth);
      await _prefs?.setDouble('rightSidebarWidth', rightSidebarWidth);
    } catch (_) {
      // Layout remains adjustable for this session if preferences are unavailable.
    }
  }

  void enter({bool fresh = false}) {
    if (fresh) {
      record();
      project = StudioProject(name: 'Untitled project');
      selected = -1;
      projectFile = '';
      refresh();
    }
    inEditor = true;
    status = '';
    notifyListeners();
  }

  void home() {
    inEditor = false;
    playing = false;
    pendingRouteStart = null;
    tool = EditorTool.select;
    notifyListeners();
  }

  void toggleMotion() {
    reducedMotion = !reducedMotion;
    _prefs?.setBool('reducedMotion', reducedMotion);
    notifyListeners();
  }

  void selectPoint(int index) {
    selected = index;
    notifyListeners();
  }

  void setTool(EditorTool value) {
    tool = value;
    if (value != EditorTool.route) pendingRouteStart = null;
    notifyListeners();
  }

  void beginRouteSelection() {
    tool = EditorTool.route;
    pendingRouteStart = null;
    message(
      'Click a start point, then a goal. Hive and interior lines are passable.',
    );
  }

  void cancelRouteSelection() {
    if (tool != EditorTool.route) return;
    tool = EditorTool.select;
    pendingRouteStart = null;
    message('Route selection canceled.');
  }

  void generateRoute() {
    if (path.points.length < 2) {
      beginRouteSelection();
      return;
    }
    _applyRoute(path.points);
  }

  void pickRoutePoint(double x, double y) {
    if (tool != EditorTool.route) return;
    if (x.abs() > 72 || y.abs() > 72) {
      message('Pick a point inside the outer field perimeter.');
      return;
    }
    final start = pendingRouteStart;
    if (start == null) {
      pendingRouteStart = Offset(x, y);
      message('Start chosen. Click the goal point.');
      return;
    }
    final heading = math.atan2(y - start.dy, x - start.dx);
    _applyRoute([
      Waypoint(start.dx, start.dy, heading),
      Waypoint(x, y, heading),
    ]);
  }

  void _applyRoute(List<Waypoint> anchors) {
    RoutePlan plan;
    try {
      plan = RoutePlanner.optimize(
        source: path,
        anchors: anchors,
        robotWidth: project.robotWidth,
        robotLength: project.robotLength,
      );
    } on FormatException catch (error) {
      message(error.message);
      return;
    }
    edit(() {
      path.points = plan.waypoints;
      selected = 0;
      playhead = 0;
      tool = EditorTool.select;
      pendingRouteStart = null;
    });
    message(
      'Optimized through all ${plan.waypoints.length} poses: '
      '${plan.length.toStringAsFixed(1)} in, '
      '${plan.duration.toStringAsFixed(2)} s.'
      '${plan.adjustedPoses == 0 ? '' : ' Adjusted ${plan.adjustedPoses} pose${plan.adjustedPoses == 1 ? '' : 's'} inside the outer wall.'}'
      ' Check your robot limits.',
    );
  }

  void applyFastMotion() {
    edit(() {
      path.maxSpeed = math.max(path.maxSpeed, 60.0);
      path.maxAcceleration = math.max(path.maxAcceleration, 100.0);
      path.maxOmega = math.max(path.maxOmega, 240.0);
      path.maxAlpha = math.max(path.maxAlpha, 360.0);
    });
    message('60 in/s preset applied. Check the limits for your robot.');
  }

  void toggle(String flag) {
    switch (flag) {
      case 'snap':
        snap = !snap;
      case 'grid':
        showGrid = !showGrid;
      case 'handles':
        showHandles = !showHandles;
      case 'robot':
        showFootprint = !showFootprint;
    }
    notifyListeners();
  }

  void fit() {
    fitRevision++;
    notifyListeners();
  }

  void addPoint(double x, double y) {
    if (path.points.length >= 150) {
      message('A path can contain up to 150 waypoints.');
      return;
    }
    if (snap) {
      x = (x / 6).round() * 6;
      y = (y / 6).round() * 6;
    }
    final heading = waypoint?.heading ?? 0;
    final fitted = RobotFootprint.clampCenter(
      Offset(x, y),
      heading,
      project.robotWidth,
      project.robotLength,
    );
    x = fitted.dx;
    y = fitted.dy;
    if (path.points.isNotEmpty &&
        (path.points.last.position - Offset(x, y)).distance < .1) {
      return;
    }
    edit(() {
      path.points.add(Waypoint(x, y, heading));
      selected = path.points.length - 1;
    });
    status = 'Waypoint ${selected + 1} added.';
  }

  void movePoint(double x, double y) {
    if (waypoint == null) return;
    if (snap) {
      x = (x / 6).round() * 6;
      y = (y / 6).round() * 6;
    }
    final fitted = RobotFootprint.clampCenter(
      Offset(x, y),
      waypoint!.heading,
      project.robotWidth,
      project.robotLength,
    );
    final nextX = fitted.dx;
    final nextY = fitted.dy;
    final delta = Offset(nextX - waypoint!.x, nextY - waypoint!.y);
    waypoint!.x = nextX;
    waypoint!.y = nextY;
    if (waypoint!.incoming != null) {
      waypoint!.incoming = waypoint!.incoming! + delta;
    }
    if (waypoint!.outgoing != null) {
      waypoint!.outgoing = waypoint!.outgoing! + delta;
    }
    _rebuildGenerated();
    dirty = true;
    playing = false;
    notifyListeners();
  }

  void setPosition({double? x, double? y}) {
    if (waypoint == null) return;
    record();
    movePoint(x ?? waypoint!.x, y ?? waypoint!.y);
    persist();
  }

  void moveHandle(bool outgoing, Offset point) {
    if (waypoint == null) return;
    if (outgoing) {
      waypoint!.outgoing = point;
      if (selected > 0) {
        waypoint!.incoming = waypoint!.position * 2 - point;
      }
    } else {
      waypoint!.incoming = point;
      if (selected < path.points.length - 1) {
        waypoint!.outgoing = waypoint!.position * 2 - point;
      }
    }
    _rebuildGenerated();
    dirty = true;
    playing = false;
    notifyListeners();
  }

  void updateSmoothing(double value) {
    path.smoothing = value;
    _rebuildGenerated();
    dirty = true;
    playing = false;
    notifyListeners();
  }

  bool _fitWaypoint(Waypoint point) {
    final fitted = RobotFootprint.clampCenter(
      point.position,
      point.heading,
      project.robotWidth,
      project.robotLength,
    );
    final delta = fitted - point.position;
    if (delta.distance <= 1e-5) return false;
    point.x = fitted.dx;
    point.y = fitted.dy;
    if (point.incoming != null) point.incoming = point.incoming! + delta;
    if (point.outgoing != null) point.outgoing = point.outgoing! + delta;
    return true;
  }

  void setHeading(double value) {
    if (waypoint == null || !value.isFinite) return;
    record();
    updateHeading(value);
    persist();
  }

  void updateHeading(double value) {
    if (waypoint == null || !value.isFinite) return;
    waypoint!.heading = value;
    final shifted = _fitWaypoint(waypoint!);
    _rebuildGenerated();
    dirty = true;
    playing = false;
    if (shifted) {
      status = 'Waypoint ${selected + 1} moved inside the outer wall.';
    }
    notifyListeners();
  }

  void setRobotSize({double? width, double? length}) {
    if (width == null && length == null) return;
    if ((width != null && (!width.isFinite || width < 1 || width > 30)) ||
        (length != null && (!length.isFinite || length < 1 || length > 30))) {
      return;
    }
    var shifted = 0;
    edit(() {
      if (width != null) project.robotWidth = width;
      if (length != null) project.robotLength = length;
      for (final route in project.paths) {
        for (final point in route.points) {
          if (_fitWaypoint(point)) shifted++;
        }
      }
    });
    if (shifted > 0) {
      message(
        'Moved $shifted pose${shifted == 1 ? '' : 's'} inside the outer wall.',
      );
    }
  }

  void deletePoint() {
    if (waypoint == null) return;
    edit(() => path.points.removeAt(selected));
  }

  void insertPoint() {
    if (waypoint == null || path.points.length >= 150) return;
    final i = selected;
    final curve = i < generated.curves.length ? generated.curves[i] : null;
    final pos = curve?.position(.5) ?? waypoint!.position + const Offset(6, 0);
    edit(() {
      Offset? incoming, outgoing;
      if (curve != null) {
        final ab = (curve.a + curve.b) / 2;
        final bc = (curve.b + curve.c) / 2;
        final cd = (curve.c + curve.d) / 2;
        incoming = (ab + bc) / 2;
        outgoing = (bc + cd) / 2;
        path.points[i].outgoing = ab;
        path.points[i + 1].incoming = cd;
      }
      path.points.insert(
        i + 1,
        Waypoint(pos.dx, pos.dy, waypoint!.heading, incoming, outgoing),
      );
      _fitWaypoint(path.points[i + 1]);
      selected = i + 1;
    });
  }

  void reorderPoint(int step) {
    final i = selected + step;
    if (waypoint == null || i < 0 || i >= path.points.length) return;
    edit(() {
      final p = path.points.removeAt(selected);
      path.points.insert(i, p);
      selected = i;
    });
  }

  void mirror() {
    edit(() {
      for (final p in path.points) {
        p.x = -p.x;
        p.heading = wrapAngle(math.pi - p.heading);
        if (p.incoming != null) {
          p.incoming = Offset(-p.incoming!.dx, p.incoming!.dy);
        }
        if (p.outgoing != null) {
          p.outgoing = Offset(-p.outgoing!.dx, p.outgoing!.dy);
        }
      }
    });
  }

  void holdHeading() {
    if (waypoint == null) return;
    final h = waypoint!.heading;
    edit(() {
      for (final p in path.points) {
        p.heading = h;
        _fitWaypoint(p);
      }
    });
  }

  void newPath() {
    if (project.paths.length >= 30) {
      message('Maximum 30 paths per project.');
      return;
    }
    edit(() {
      project.paths.add(StudioPath(name: 'Path ${project.paths.length + 1}'));
      project.active = project.paths.length - 1;
      selected = -1;
      playhead = 0;
      pendingRouteStart = null;
      tool = EditorTool.select;
    });
  }

  void duplicatePath() {
    if (project.paths.length >= 30) return;
    edit(() {
      final p = path.copy();
      p.name = '${p.name.length > 75 ? p.name.substring(0, 75) : p.name} copy';
      project.paths.add(p);
      project.active = project.paths.length - 1;
    });
  }

  void deletePath() {
    if (project.paths.length == 1) {
      message('Keep at least one path in the project.');
      return;
    }
    edit(() {
      project.paths.removeAt(project.active);
      project.active = math.min(project.active, project.paths.length - 1);
      selected = -1;
    });
  }

  void selectPath(int index) {
    project.active = index;
    selected = path.points.isEmpty ? -1 : 0;
    _rebuildGenerated();
    playhead = 0;
    playing = false;
    pendingRouteStart = null;
    tool = EditorTool.select;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(snapshot());
    project = importDocument(_undo.removeLast());
    pendingRouteStart = null;
    tool = EditorTool.select;
    refresh();
    status = 'Edit undone.';
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(snapshot());
    project = importDocument(_redo.removeLast());
    pendingRouteStart = null;
    tool = EditorTool.select;
    refresh();
    status = 'Edit restored.';
  }

  void togglePlay() {
    if (generated.duration == 0) return;
    if (playhead >= generated.duration) playhead = 0;
    playing = !playing;
    notifyListeners();
  }

  void seek(double seconds) {
    playhead = seconds.clamp(0, generated.duration).toDouble();
    playing = false;
    notifyListeners();
  }

  void tick(double dt) {
    if (!playing) return;
    playhead = math.min(generated.duration, playhead + dt);
    if (playhead >= generated.duration) playing = false;
    notifyListeners();
  }

  void message(String value) {
    status = value;
    notifyListeners();
  }

  Future<void> open() async {
    if (busy) return;
    busy = true;
    try {
      final f = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Astra projects and paths',
            extensions: ['astra', 'json', 'polarpath'],
          ),
        ],
      );
      if (f == null) return;
      if (await f.length() > 16 * 1024 * 1024) {
        throw const FormatException('File exceeds 16 MB.');
      }
      final loaded = importDocument(await f.readAsString());
      record();
      project = loaded;
      projectFile = f.path.endsWith('.astra') ? f.path : '';
      selected = path.points.isEmpty ? -1 : 0;
      inEditor = true;
      playhead = 0;
      refresh();
      dirty = false;
      status =
          'Opened ${f.name}. Imported geometry is regenerated using current constraints.';
    } catch (e) {
      status = 'Could not open: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> saveProject({bool saveAs = false}) async {
    if (busy) return;
    busy = true;
    try {
      var file = projectFile;
      if (file.isEmpty || saveAs) {
        final chosen = await getSaveLocation(
          suggestedName: '${safeName(project.name)}.astra',
          acceptedTypeGroups: [
            const XTypeGroup(label: 'Astra project', extensions: ['astra']),
          ],
        );
        if (chosen == null) return;
        file = chosen.path;
        if (!file.toLowerCase().endsWith('.astra')) file += '.astra';
      }
      await atomicWrite(
        file,
        const JsonEncoder.withIndent('  ').convert(project.toJson()),
      );
      projectFile = file;
      dirty = false;
      lastSaved = DateTime.now().toIso8601String();
      status = 'Project saved. All paths and markers are included.';
    } catch (e) {
      status = 'Save failed: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> exportRobot() async {
    if (busy) return;
    busy = true;
    try {
      if (wallCollision case final collision?) {
        throw FormatException(
          'Robot crosses the outer wall near segment ${collision.segment + 1}.',
        );
      }
      final data = generated.robotJson();
      final chosen = await getSaveLocation(
        suggestedName: '${safeName(path.name)}.json',
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'FTC 23477 path JSON',
            extensions: ['json', 'polarpath'],
          ),
        ],
      );
      if (chosen == null) return;
      var file = chosen.path;
      if (!file.endsWith('.json') && !file.endsWith('.polarpath')) {
        file += '.json';
      }
      await atomicWrite(file, const JsonEncoder.withIndent('  ').convert(data));
      status = 'Exported ${path.name}.';
    } catch (e) {
      status = 'Export failed: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  static String safeName(String name) {
    final result = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return result.isEmpty ? 'path' : result;
  }

  static Future<void> atomicWrite(String path, String data) async {
    final target = File(path);
    final temporary = File(
      '$path.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString(data, flush: true);
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
