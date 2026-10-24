import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astra_path_studio/main.dart';
import 'package:astra_path_studio/field_canvas.dart';
import 'package:astra_path_studio/studio_state.dart';
import 'package:astra_path_studio/glass.dart';

Future<void> fonts() async {
  final loader = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('app-screenshot')),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory(
    Platform.environment['ASTRA_ARTIFACTS'] ?? 'build/review',
  );
  await dir.create(recursive: true);
  await File('${dir.path}/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

Finder tool(String tip) => find.byWidgetPredicate(
  (widget) => widget is ToolButton && widget.tip == tip,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Editor, paths, undo, inspector, responsive layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await fonts();
    final state = StudioState();
    await state.initialize();
    await tester.pumpWidget(AstraApp(state: state, animate: false));
    await tester.pumpAndSettle();
    expect(find.text('Sample path'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Waypoint 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => capture(tester, 'editor'));
    await tester.tap(tool('Play / pause'));
    await tester.pump();
    expect(state.playing, isTrue);
    await tester.tap(tool('Play / pause'));
    await tester.pump();
    expect(state.playing, isFalse);
    final leftBefore = tester
        .getSize(find.byKey(const Key('paths-sidebar')))
        .width;
    final rightBefore = tester
        .getSize(find.byKey(const Key('inspector-sidebar')))
        .width;
    await tester.drag(
      find.byKey(const Key('left-sidebar-resize')),
      const Offset(52, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('paths-sidebar'))).width,
      greaterThan(leftBefore),
    );
    await tester.drag(
      find.byKey(const Key('right-sidebar-resize')),
      const Offset(-48, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('inspector-sidebar'))).width,
      greaterThan(rightBefore),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getDouble('leftSidebarWidth'), greaterThan(leftBefore));
    expect(
      preferences.getDouble('rightSidebarWidth'),
      greaterThan(rightBefore),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is PopupMenuButton<String> &&
            widget.tooltip == 'Waypoint actions',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply heading to all waypoints'));
    await tester.pumpAndSettle();
    expect(
      state.path.points.every(
        (point) => point.heading == state.path.points.first.heading,
      ),
      isTrue,
    );
    state.edit(() {
      state.path.maxSpeed = 20;
      state.path.maxAcceleration = 20;
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Motion settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use 60 in/s preset'));
    await tester.pumpAndSettle();
    expect(state.path.maxSpeed, greaterThanOrEqualTo(60));
    expect(state.path.maxAcceleration, greaterThanOrEqualTo(100));
    await tester.tap(tool('New path'));
    await tester.pumpAndSettle();
    expect(state.project.paths.length, 2);
    state.addPoint(0, 0);
    state.addPoint(24, 20);
    await tester.pumpAndSettle();
    expect(state.path.points.length, 2);
    await tester.tap(tool('Delete waypoint'));
    await tester.pumpAndSettle();
    expect(state.path.points.length, 1);
    await tester.tap(tool('Undo · Ctrl Z'));
    await tester.pumpAndSettle();
    expect(state.path.points.length, 2);
    state.selectPath(0);
    await tester.pumpAndSettle();
    final field = find.widgetWithText(NumericField, 'Position X');
    await tester.enterText(
      find.descendant(of: field, matching: find.byType(TextField)),
      '-36',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(state.waypoint!.x, -36);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is PopupMenuButton<String> &&
            widget.tooltip == 'View and path options',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mirror path'));
    await tester.pumpAndSettle();
    expect(state.waypoint!.x, 36);
    state.seek(state.generated.duration);
    await tester.pumpAndSettle();
    expect(state.generated.at(state.playhead).x, state.path.points.last.x);
    tester.view.physicalSize = const Size(1080, 720);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tool('Path inspector'), findsOneWidget);
    await tester.tap(tool('Path inspector'));
    await tester.pumpAndSettle();
    expect(find.text('Motion settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();
    state.home();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    await tester.runAsync(() => capture(tester, 'home'));
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  testWidgets('Field plotting and drag gestures change geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = StudioState()..enter(fresh: true);
    await tester.pumpWidget(AstraApp(state: state, animate: false));
    await tester.pumpAndSettle();
    await tester.tap(tool('Plot points'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(650, 400));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(800, 450));
    await tester.pumpAndSettle();
    expect(state.path.points.length, 2);
    final x = state.path.points.last.x;
    final fieldSize = tester.getSize(find.byType(FieldCanvas));
    final fieldScale = math.max(
      1.0,
      (math.min(fieldSize.width, fieldSize.height) - 90) / 144,
    );
    // Drag from inside the robot box, away from its center and heading grip.
    await tester.dragFrom(const Offset(820, 450), const Offset(30, -30));
    await tester.pumpAndSettle();
    expect(state.path.points.last.x, closeTo(x + 30 / fieldScale, .5));
    state.undo();
    await tester.pumpAndSettle();
    expect(state.path.points.last.x, closeTo(x, 1e-8));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  testWidgets('Generate path and two-click route work from the editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = StudioState();
    await tester.pumpWidget(AstraApp(state: state, animate: false));
    await tester.pumpAndSettle();

    final before = state.path.points.length;
    await tester.tap(find.text('Generate path'));
    await tester.pumpAndSettle();
    expect(state.path.points.length, before);
    expect(state.canUndo, isTrue);
    await tester.runAsync(() => capture(tester, 'generated'));

    await tester.tap(tool('Pick start and goal for new route'));
    await tester.pumpAndSettle();
    expect(state.tool, EditorTool.route);
    await tester.tapAt(const Offset(600, 300));
    await tester.pumpAndSettle();
    expect(state.pendingRouteStart, isNotNull);
    await tester.tapAt(const Offset(850, 600));
    await tester.pumpAndSettle();
    expect(state.path.points.length, 2);
    expect(state.tool, EditorTool.select);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
