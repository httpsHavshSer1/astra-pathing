import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astra_path_studio/route_logo.dart';

void main() {
  testWidgets('Render route logo for native app icon', (tester) async {
    tester.view.physicalSize = const Size(256, 256);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('icon'),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: const RouteLogo(size: 256),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(const Key('icon')))
          .toImage();
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      final header = ByteData(22)
        ..setUint16(2, 1, Endian.little)
        ..setUint16(4, 1, Endian.little)
        ..setUint16(10, 1, Endian.little)
        ..setUint16(12, 32, Endian.little)
        ..setUint32(14, bytes.length, Endian.little)
        ..setUint32(18, 22, Endian.little);
      final dir = Directory(
        Platform.environment['ASTRA_ARTIFACTS'] ?? 'build/review',
      );
      await dir.create(recursive: true);
      await File(
        '${dir.path}/app_icon.ico',
      ).writeAsBytes([...header.buffer.asUint8List(), ...bytes]);
      await File('${dir.path}/app_icon.png').writeAsBytes(bytes);
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
