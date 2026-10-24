import 'package:flutter/material.dart';

/// A route drawn as an A, with its start and finish marked as field poses.
class RouteLogo extends StatelessWidget {
  final double size;
  const RouteLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const RouteLogoPainter());
}

class RouteLogoPainter extends CustomPainter {
  const RouteLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFF262A35),
    );

    final route = Path()
      ..moveTo(21, 76)
      ..lineTo(50, 22)
      ..lineTo(79, 76);
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xFFF0EDF7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawLine(
      const Offset(38, 56),
      const Offset(62, 56),
      Paint()
        ..color = const Color(0xFFB29ED4)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    final endpoint = Paint()..color = const Color(0xFFB29ED4);
    canvas.drawCircle(const Offset(21, 76), 6, endpoint);
    canvas.drawCircle(const Offset(79, 76), 6, endpoint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RouteLogoPainter oldDelegate) => false;
}
