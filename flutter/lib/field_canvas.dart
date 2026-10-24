import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'field_clearance.dart';
import 'glass.dart';
import 'model.dart';
import 'studio_state.dart';

class FieldCanvas extends StatefulWidget {
  final StudioState state;
  const FieldCanvas({super.key, required this.state});
  @override
  State<FieldCanvas> createState() => _FieldCanvasState();
}

class _FieldCanvasState extends State<FieldCanvas> {
  double zoom = 1;
  Offset pan = Offset.zero;
  Size size = Size.zero;
  int seenFit = 0;
  int drag = -1;
  int controlDrag = 0;
  bool headingDrag = false, recorded = false;
  Offset dragOffset = Offset.zero;
  Offset? hover;
  final FocusNode focus = FocusNode();
  StudioState get s => widget.state;
  double get scale =>
      math.max(1, (math.min(size.width, size.height) - 90) / 144) * zoom;
  Offset get center => Offset(size.width / 2, size.height / 2) + pan;
  Offset field(Offset p) =>
      Offset((p.dx - center.dx) / scale, -(p.dy - center.dy) / scale);
  Offset screen(Offset p) =>
      Offset(center.dx + p.dx * scale, center.dy - p.dy * scale);
  Offset headingGrip(Waypoint point) =>
      screen(point.position) +
      Offset(math.cos(point.heading), -math.sin(point.heading)) *
          (s.project.robotLength * scale / 2 + 17);
  int hit(Offset local) {
    for (var i = s.path.points.length - 1; i >= 0; i--) {
      if ((screen(s.path.points[i].position) - local).distance < 15) return i;
    }
    for (var i = s.path.points.length - 1; i >= 0; i--) {
      final point = s.path.points[i];
      final delta = local - screen(point.position);
      final c = math.cos(point.heading), angleSin = math.sin(point.heading);
      final localX = delta.dx * c - delta.dy * angleSin;
      final localY = delta.dx * angleSin + delta.dy * c;
      if (localX.abs() <= s.project.robotLength * scale / 2 + 3 &&
          localY.abs() <= s.project.robotWidth * scale / 2 + 3) {
        return i;
      }
    }
    return -1;
  }

  void changeZoom(double factor, Offset anchor) {
    setState(() {
      final old = zoom;
      zoom = (zoom * factor).clamp(.55, 4.0);
      pan =
          (center - anchor) * (zoom / old) +
          anchor -
          Offset(size.width / 2, size.height / 2);
    });
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (seenFit != s.fitRevision) {
      seenFit = s.fitRevision;
      zoom = 1;
      pan = Offset.zero;
    }
    return LayoutBuilder(
      builder: (context, c) {
        size = c.biggest;
        return Focus(
          focusNode: focus,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.delete) {
              s.deletePoint();
              return KeyEventResult.handled;
            }
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.space) {
              s.togglePlay();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(
                  cursor:
                      s.tool == EditorTool.place || s.tool == EditorTool.route
                      ? SystemMouseCursors.precise
                      : s.tool == EditorTool.pan
                      ? SystemMouseCursors.grab
                      : SystemMouseCursors.basic,
                  onHover: (e) =>
                      setState(() => hover = field(e.localPosition)),
                  onExit: (_) => setState(() => hover = null),
                  child: Listener(
                    onPointerSignal: (e) {
                      if (e is PointerScrollEvent) {
                        changeZoom(
                          math.exp(-e.scrollDelta.dy * .0014),
                          e.localPosition,
                        );
                      }
                    },
                    child: GestureDetector(
                      dragStartBehavior: DragStartBehavior.down,
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) {
                        focus.requestFocus();
                        final p = field(d.localPosition);
                        if (s.tool == EditorTool.route) {
                          s.pickRoutePoint(p.dx, p.dy);
                          return;
                        }
                        final i = hit(d.localPosition);
                        if (i >= 0) {
                          s.selectPoint(i);
                          return;
                        }
                        if (s.tool == EditorTool.place &&
                            p.dx.abs() <= 72 &&
                            p.dy.abs() <= 72) {
                          s.addPoint(p.dx, p.dy);
                        }
                      },
                      onDoubleTapDown: s.tool == EditorTool.select
                          ? (d) {
                              final p = field(d.localPosition);
                              if (hit(d.localPosition) < 0 &&
                                  p.dx.abs() <= 72 &&
                                  p.dy.abs() <= 72) {
                                s.addPoint(p.dx, p.dy);
                              }
                            }
                          : null,
                      onPanStart: (d) {
                        focus.requestFocus();
                        drag =
                            s.tool == EditorTool.pan ||
                                s.tool == EditorTool.route
                            ? -1
                            : hit(d.localPosition);
                        recorded = false;
                        headingDrag = false;
                        controlDrag = 0;
                        if (s.waypoint != null && s.tool != EditorTool.pan) {
                          if (s.showHandles) {
                            final curves = s.generated.curves;
                            if (s.selected < curves.length &&
                                (screen(curves[s.selected].b) - d.localPosition)
                                        .distance <
                                    13) {
                              drag = s.selected;
                              controlDrag = 1;
                            } else if (s.selected > 0 &&
                                (screen(curves[s.selected - 1].c) -
                                            d.localPosition)
                                        .distance <
                                    13) {
                              drag = s.selected;
                              controlDrag = -1;
                            }
                          }
                          final handle = headingGrip(s.waypoint!);
                          if (controlDrag == 0 &&
                              (handle - d.localPosition).distance < 11) {
                            drag = s.selected;
                            headingDrag = true;
                          }
                        }
                        if (drag >= 0) {
                          s.selectPoint(drag);
                          dragOffset =
                              field(d.localPosition) -
                              s.path.points[drag].position;
                        }
                      },
                      onPanUpdate: (d) {
                        if (drag >= 0) {
                          if (!recorded) {
                            s.record();
                            recorded = true;
                          }
                          final p = field(d.localPosition);
                          if (controlDrag != 0) {
                            s.moveHandle(controlDrag == 1, p);
                          } else if (headingDrag) {
                            final w = s.waypoint!;
                            s.updateHeading(math.atan2(p.dy - w.y, p.dx - w.x));
                          } else {
                            final center = p - dragOffset;
                            s.movePoint(center.dx, center.dy);
                          }
                        } else {
                          setState(() => pan += d.delta);
                        }
                      },
                      onPanEnd: (_) {
                        if (recorded) s.persist();
                        drag = -1;
                        controlDrag = 0;
                      },
                      child: RepaintBoundary(
                        child: CustomPaint(painter: FieldPainter(s, zoom, pan)),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 22,
                top: 18,
                child: IgnorePointer(
                  child: Glass(
                    radius: 10,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.crop_square_rounded, size: 13, color: muted),
                        SizedBox(width: 8),
                        Text(
                          'BIOBUZZ FIELD',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          '12 × 12 ft',
                          style: TextStyle(fontSize: 9, color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (s.path.points.isEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_location_alt_outlined,
                            size: 34,
                            color: violet.withValues(alpha: .6),
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'No waypoints yet',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Double-click to place your first waypoint.',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 22,
                bottom: 17,
                child: IgnorePointer(
                  child: Text(
                    hover == null
                        ? 'FIELD CENTER · INCHES'
                        : 'X  ${hover!.dx.toStringAsFixed(1)} in     Y  ${hover!.dy.toStringAsFixed(1)} in',
                    style: const TextStyle(
                      fontSize: 9,
                      color: muted,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 17,
                bottom: 14,
                child: Glass(
                  radius: 11,
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      ToolButton(
                        Icons.remove_rounded,
                        'Zoom out',
                        onTap: () => changeZoom(
                          .85,
                          Offset(size.width / 2, size.height / 2),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${(zoom * 100).round()}%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                      ),
                      ToolButton(
                        Icons.add_rounded,
                        'Zoom in',
                        onTap: () => changeZoom(
                          1.18,
                          Offset(size.width / 2, size.height / 2),
                        ),
                      ),
                      ToolButton(
                        Icons.fit_screen_rounded,
                        'Fit field',
                        onTap: s.fit,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FieldPainter extends CustomPainter {
  final StudioState state;
  final double zoom;
  final Offset pan;
  FieldPainter(this.state, this.zoom, this.pan);
  @override
  void paint(Canvas canvas, Size size) {
    final scale =
        math.max(1, (math.min(size.width, size.height) - 90) / 144) * zoom;
    final center = Offset(size.width / 2, size.height / 2) + pan;
    Offset p(Offset o) =>
        Offset(center.dx + o.dx * scale, center.dy - o.dy * scale);
    final rect = Rect.fromPoints(
      p(const Offset(-72, 72)),
      p(const Offset(72, -72)),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = const Color(0xFF11131E),
    );
    if (state.showGrid) {
      for (var x = -72; x <= 72; x += 6) {
        final major = x % 24 == 0;
        final paint = Paint()
          ..color = Colors.white.withValues(alpha: major ? .075 : .025)
          ..strokeWidth = major ? 1 : .6;
        canvas.drawLine(
          p(Offset(x.toDouble(), -72)),
          p(Offset(x.toDouble(), 72)),
          paint,
        );
        canvas.drawLine(
          p(Offset(-72, x.toDouble())),
          p(Offset(72, x.toDouble())),
          paint,
        );
      }
    }
    // Nominal BIOBUZZ layout; silhouettes are visual references, not collision volumes.
    const red = Color(0xFFC27586), blue = Color(0xFF7E9DDF);
    Rect fieldRect(double x1, double y1, double x2, double y2) =>
        Rect.fromPoints(p(Offset(x1, y1)), p(Offset(x2, y2)));
    void zone(double x1, double y1, double x2, double y2, Color color) {
      canvas.drawRect(
        fieldRect(x1, y1, x2, y2),
        Paint()..color = color.withValues(alpha: .10),
      );
      canvas.drawRect(
        fieldRect(x1, y1, x2, y2),
        Paint()
          ..color = color.withValues(alpha: .55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    zone(-72, 48, -61, 25, red); // Red loading zone.
    zone(61, -25, 72, -48, blue); // Blue loading zone.
    zone(-72, -72, -49, -70, red); // Red garden.
    zone(49, 70, 72, 72, blue); // Blue garden.
    final hive = fieldRect(-24.73, -19.475, 24.73, 19.475);
    canvas.drawRect(hive, Paint()..color = const Color(0xFF191B2B));
    canvas.drawRect(
      hive,
      Paint()
        ..color = muted.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (final x in [-12.0, 12.0]) {
      for (final y in [-10.0, 10.0]) {
        final cell = fieldRect(x - 9, y - 7, x + 9, y + 7);
        final color = x < 0 ? red : blue;
        canvas.drawRect(cell, Paint()..color = color.withValues(alpha: .12));
        canvas.drawRect(
          cell,
          Paint()
            ..color = color.withValues(alpha: .55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
    for (final flower in [
      const Offset(-24, 69),
      const Offset(69, 24),
      const Offset(24, -69),
      const Offset(-69, -24),
    ]) {
      canvas.drawCircle(
        p(flower),
        2.7 * scale,
        Paint()..color = const Color(0xFFD3BB80).withValues(alpha: .25),
      );
      canvas.drawCircle(
        p(flower),
        2.7 * scale,
        Paint()
          ..color = const Color(0xFFD3BB80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF555361)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawLine(
      p(const Offset(0, -72)),
      p(const Offset(0, 72)),
      Paint()..color = Colors.white.withValues(alpha: .08),
    );
    canvas.drawLine(
      p(const Offset(-72, 0)),
      p(const Offset(72, 0)),
      Paint()..color = Colors.white.withValues(alpha: .08),
    );
    void textAt(String t, Offset pos, Color color, {double size = 9}) {
      final painter = TextPainter(
        text: TextSpan(
          text: t,
          style: TextStyle(color: color, fontSize: size, fontFamily: 'Inter'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, pos);
    }

    void poseBox(
      Offset position,
      double heading,
      Color outline, {
      bool selected = false,
      bool live = false,
    }) {
      canvas.save();
      canvas.translate(p(position).dx, p(position).dy);
      canvas.rotate(-heading);
      final footprint = Rect.fromCenter(
        center: Offset.zero,
        width: state.project.robotLength * scale,
        height: state.project.robotWidth * scale,
      );
      final shell = RRect.fromRectAndRadius(
        footprint,
        const Radius.circular(2),
      );
      canvas.drawRRect(
        shell,
        Paint()
          ..color = selected
              ? const Color(0x99212632)
              : const Color(0x66131821),
      );
      final edge = selected
          ? const Color(0xFFBDB6CA)
          : live
          ? const Color(0xFF9AACBD)
          : const Color(0xFF6F7A89);
      canvas.drawRRect(
        shell,
        Paint()
          ..color = edge
          ..strokeWidth = selected || live ? 1.8 : 1.25
          ..style = PaintingStyle.stroke,
      );
      // A short front rail conveys heading without a decorative arrow.
      final frontInset = math.min(3.0, footprint.width * .04);
      final endInset = math.min(9.0, footprint.height * .13);
      canvas.drawLine(
        Offset(footprint.right - frontInset, footprint.top + endInset),
        Offset(footprint.right - frontInset, footprint.bottom - endInset),
        Paint()
          ..color = outline
          ..strokeWidth = selected || live ? 3 : 2.5
          ..strokeCap = StrokeCap.square,
      );
      canvas.drawCircle(
        Offset.zero,
        selected || live ? 3.6 : 3,
        Paint()..color = outline,
      );
      canvas.restore();
    }

    for (var i = -72; i <= 72; i += 24) {
      textAt(
        '$i',
        p(Offset(i.toDouble(), -72)) + const Offset(-7, 9),
        muted.withValues(alpha: .6),
      );
      textAt(
        '$i',
        p(Offset(-72, i.toDouble())) + const Offset(-26, -5),
        muted.withValues(alpha: .6),
      );
    }
    for (var r = 0; r < state.project.paths.length; r++) {
      final active = r == state.project.active;
      final generated = active
          ? state.generated
          : GeneratedPath(state.project.paths[r]);
      if (generated.curves.isEmpty) continue;
      final line = Path()
        ..moveTo(
          p(generated.curves.first.a).dx,
          p(generated.curves.first.a).dy,
        );
      for (final c in generated.curves) {
        final b = p(c.b), c2 = p(c.c), d = p(c.d);
        line.cubicTo(b.dx, b.dy, c2.dx, c2.dy, d.dx, d.dy);
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = active ? const Color(0xFFAE9CCB) : const Color(0xFF454858)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2.3 : 1.2,
      );
      if (active && state.showHandles) {
        final handlePaint = Paint()
          ..color = Colors.white.withValues(alpha: .18)
          ..strokeWidth = 1;
        final selected = state.selected;
        if (selected >= 0 && selected < generated.curves.length) {
          final c = generated.curves[selected];
          canvas.drawLine(p(c.a), p(c.b), handlePaint);
          canvas.drawCircle(p(c.b), 4, Paint()..color = violet);
        }
        if (selected > 0 && selected <= generated.curves.length) {
          final c = generated.curves[selected - 1];
          canvas.drawLine(p(c.c), p(c.d), handlePaint);
          canvas.drawCircle(p(c.c), 4, Paint()..color = violet);
        }
      }
    }
    for (final marker in state.path.markers) {
      final sample = state.generated.at(
        marker.fraction * state.generated.duration,
      );
      final at = p(sample.position);
      final diamond = Path()
        ..addPolygon([
          at + const Offset(0, -6),
          at + const Offset(5, 0),
          at + const Offset(0, 6),
          at + const Offset(-5, 0),
        ], true);
      canvas.drawPath(diamond, Paint()..color = const Color(0xFFF2CF9F));
    }
    for (var i = 0; i < state.path.points.length; i++) {
      final w = state.path.points[i],
          at = p(w.position),
          selected = i == state.selected;
      final color = i == 0
          ? const Color(0xFF8DA6C5)
          : i == state.path.points.length - 1
          ? const Color(0xFFBE9FAA)
          : const Color(0xFFA9A4B8);
      poseBox(w.position, w.heading, color, selected: selected);
      final heading = Offset(math.cos(w.heading), -math.sin(w.heading));
      if (selected) {
        final front = at + heading * (state.project.robotLength * scale / 2);
        final grip =
            at + heading * (state.project.robotLength * scale / 2 + 17);
        canvas.drawLine(
          front,
          grip,
          Paint()
            ..color = color.withValues(alpha: .75)
            ..strokeWidth = 1.2,
        );
        canvas.drawCircle(grip, 4, Paint()..color = color);
      }
      final label =
          '${(i + 1).toString().padLeft(2, '0')}${i == 0
              ? '  START'
              : i == state.path.points.length - 1
              ? '  END'
              : ''}';
      final reach = RobotFootprint.halfExtents(
        w.heading,
        state.project.robotWidth,
        state.project.robotLength,
      );
      textAt(
        label,
        at + Offset(reach.dx * scale + 7, reach.dy * scale - 9),
        color.withValues(alpha: .9),
        size: 8,
      );
    }
    if (state.wallCollision case final collision?) {
      final at = p(collision.position);
      const warning = Color(0xFFFF7F96);
      canvas.drawCircle(
        at,
        12,
        Paint()
          ..color = warning
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      textAt('OUTER WALL', at + const Offset(17, -16), warning, size: 9);
    }
    if (state.showFootprint && state.path.points.isNotEmpty) {
      final sample = state.generated.at(state.playhead);
      final atPose = state.path.points.any(
        (point) =>
            (point.position - sample.position).distance < .01 &&
            wrapAngle(point.heading - sample.heading).abs() < .01,
      );
      final invalid =
          RobotFootprint.wallViolation(
            sample.position,
            sample.heading,
            state.project.robotWidth,
            state.project.robotLength,
          ) >
          1e-5;
      if (!atPose) {
        poseBox(
          sample.position,
          sample.heading,
          invalid ? const Color(0xFFCF8895) : const Color(0xFF9CB2D3),
          live: true,
        );
      }
    }
    if (state.pendingRouteStart case final pending?) {
      final at = p(pending);
      canvas.drawCircle(
        at,
        13,
        Paint()
          ..color = mint
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(at, 3, Paint()..color = mint);
      textAt('START · CLICK GOAL', at + const Offset(18, -20), mint, size: 9);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FieldPainter old) => true;
}

class VelocityPainter extends CustomPainter {
  final GeneratedPath path;
  final double time;
  VelocityPainter(this.path, this.time);
  @override
  void paint(Canvas canvas, Size size) {
    if (path.duration <= 0) return;
    final points = [
      for (var i = 0; i <= 100; i++) path.at(i * path.duration / 100),
    ];
    final maxSpeed = math.max(1, points.map((s) => s.speed).reduce(math.max));
    final curve = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i / 100 * size.width,
          y = size.height - 3 - points[i].speed / maxSpeed * (size.height - 7);
      if (i == 0) {
        curve.moveTo(x, y);
      } else {
        curve.lineTo(x, y);
      }
    }
    final fill = Path.from(curve)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            violet.withValues(alpha: .22),
            violet.withValues(alpha: .01),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      curve,
      Paint()
        ..color = violet.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    final x = time / path.duration * size.width;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = mint.withValues(alpha: .6)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(VelocityPainter old) => true;
}
