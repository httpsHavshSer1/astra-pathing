import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'glass.dart';

class CosmosPainter extends CustomPainter {
  final double phase;
  final bool subtle;
  CosmosPainter({this.phase = 0, this.subtle = false});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ink);
    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(center, radius, [
            color,
            Colors.transparent,
          ]),
      );
    }

    glow(
      Offset(size.width * .74, size.height * .4),
      size.width * .47,
      Color(subtle ? 0x0C1F164D : 0x263E3456),
    );
    glow(
      Offset(size.width * .18, size.height * .12),
      size.width * .5,
      Color(subtle ? 0x071C3254 : 0x141A324E),
    );
    glow(
      Offset(size.width * .62, size.height * .9),
      size.width * .3,
      const Color(0x0C173C41),
    );
    final rng = math.Random(23477);
    for (var i = 0; i < (subtle ? 40 : 90); i++) {
      final p = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      final r = rng.nextDouble() * .85 + .25;
      final alpha =
          (.10 + rng.nextDouble() * .28) *
          (.8 + .2 * math.sin(phase * 2 * math.pi + i));
      canvas.drawCircle(
        p,
        r,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(CosmosPainter old) =>
      phase != old.phase || subtle != old.subtle;
}

/// Faceted quartz geometry, painted directly in Flutter: no remote image dependencies.
class CrystalPainter extends CustomPainter {
  final double phase;
  CrystalPainter({this.phase = 0});
  void polygon(Canvas c, List<Offset> vertices, List<Color> colors) {
    final p = Path()..addPolygon(vertices, true);
    final b = p.getBounds();
    c.drawPath(
      p,
      Paint()..shader = ui.Gradient.linear(b.topLeft, b.bottomRight, colors),
    );
    c.drawPath(
      p,
      Paint()
        ..color = const Color(0x77D5C3FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
  }

  void crystal(
    Canvas c, {
    required Offset center,
    required double width,
    required double height,
    required double angle,
    required List<Color> colors,
  }) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);
    final top = Offset(0, -height * .58),
        left = Offset(-width * .5, -height * .22),
        right = Offset(width * .5, -height * .19);
    final middle = Offset(width * .05, -height * .15),
        bottom = Offset(width * .12, height * .45),
        bl = Offset(-width * .4, height * .19),
        br = Offset(width * .43, height * .22);
    final outline = Path()
      ..addPolygon([top, right, br, bottom, bl, left], true);
    c.drawPath(
      outline,
      Paint()
        ..color = colors[0].withValues(alpha: .08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    polygon(c, [top, left, middle], [colors[0], colors[1]]);
    polygon(c, [top, middle, right], [const Color(0xBBFCF5FF), colors[2]]);
    polygon(
      c,
      [left, bl, bottom, middle],
      [colors[1], const Color(0x883A2064)],
    );
    polygon(
      c,
      [middle, bottom, br, right],
      [colors[2], const Color(0xCC17172B)],
    );
    polygon(
      c,
      [middle, Offset(width * .16, height * .09), bottom],
      [const Color(0x55EAF0FF), const Color(0x22291459)],
    );
    polygon(
      c,
      [left, Offset(-width * .25, -height * .12), bl],
      [const Color(0x88D8B6FF), const Color(0x11332154)],
    );
    final white = Paint()
      ..color = const Color(0xAAEEE3FF)
      ..strokeWidth = 1.3;
    c.drawLine(top, middle, white);
    c.drawLine(middle, bottom, white..color = const Color(0x55B4E1FF));
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height * .51);
    final scale = math.min(size.width / 560, size.height / 550);
    canvas.scale(scale);
    final bob = math.sin(phase * math.pi * 2) * 7;
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.rotate(-.3 + i * .21);
      final rect = Rect.fromCenter(
        center: const Offset(0, 40),
        width: 480 - i * 27,
        height: 145 + i * 50,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..color = Colors.white.withValues(alpha: .045)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
      canvas.restore();
    }
    crystal(
      canvas,
      center: Offset(-103, 30 + bob),
      width: 93,
      height: 275,
      angle: -.40,
      colors: [
        const Color(0xFFE3C8FF),
        const Color(0xBB613F8F),
        const Color(0xCC9A87DC),
      ],
    );
    crystal(
      canvas,
      center: Offset(83, 45 - bob / 2),
      width: 110,
      height: 290,
      angle: .37,
      colors: [
        const Color(0xFFA7DBF1),
        const Color(0x993A5B8A),
        const Color(0xAA7C93BC),
      ],
    );
    crystal(
      canvas,
      center: Offset(-2, bob - 20),
      width: 150,
      height: 430,
      angle: .07,
      colors: [
        const Color(0xFFF3D9FF),
        const Color(0xBB7D4FB7),
        const Color(0xBBABAAF0),
      ],
    );
    crystal(
      canvas,
      center: Offset(164, -164 + bob),
      width: 24,
      height: 61,
      angle: .42,
      colors: [
        const Color(0xFFD9B8FF),
        const Color(0xAA78559E),
        const Color(0x668DADDB),
      ],
    );
    crystal(
      canvas,
      center: Offset(-190, -73 - bob),
      width: 23,
      height: 46,
      angle: -.5,
      colors: [
        const Color(0xFFB7CBF0),
        const Color(0x88639199),
        const Color(0x667783AA),
      ],
    );
    final ring = Rect.fromCenter(
      center: const Offset(0, 45),
      width: 500,
      height: 166,
    );
    canvas.save();
    canvas.rotate(-.17);
    canvas.drawArc(
      ring,
      .04,
      math.pi * .97,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = ui.Gradient.linear(
          ring.centerLeft,
          ring.centerRight,
          [
            Colors.transparent,
            const Color(0xD5C4B5EF),
            const Color(0x5594D5D0),
          ],
          [0.0, 0.5, 1.0],
        ),
    );
    canvas.restore();
    for (final o in [
      const Offset(-190, 135),
      const Offset(169, 116),
      const Offset(106, -223),
    ]) {
      canvas.drawCircle(o, 2, Paint()..color = const Color(0xFFE7D7FE));
      canvas.drawCircle(
        o,
        11,
        Paint()
          ..shader = ui.Gradient.radial(o, 11, [
            const Color(0x88D7BCFF),
            Colors.transparent,
          ]),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CrystalPainter old) => phase != old.phase;
}
