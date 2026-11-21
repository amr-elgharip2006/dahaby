import 'package:flutter/material.dart';

import 'theme.dart';

/// The Dahaby mark: three gold bars and a sparkle, on gold.
///
/// Same geometry as docs/brand/logo.svg, drawn on a 512 grid.
class DahabyLogo extends StatelessWidget {
  const DahabyLogo({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'دهبي',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: const _LogoPainter(),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  // Each bar is a trapezoid: centre x and top y.
  static const _bars = [Offset(256, 206), Offset(170, 312), Offset(342, 312)];
  static const _round = 12.0;
  static const _halfBase = 152 / 2 - _round;
  static const _halfTop = 100 / 2 - _round;
  static const _height = 88.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 512);
    const box = Rect.fromLTWH(0, 0, 512, 512);

    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(116)),
      Paint()..shader = Brand.goldGradient.createShader(box),
    );

    // Fill plus a round-joined stroke of the same colour rounds the corners.
    final fill = Paint()..color = Brand.ink;
    final edge = Paint()
      ..color = Brand.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _round * 2
      ..strokeJoin = StrokeJoin.round;
    for (final bar in _bars) {
      final top = bar.dy + _round;
      final bottom = bar.dy + _height - _round;
      final path = Path()
        ..moveTo(bar.dx - _halfBase, bottom)
        ..lineTo(bar.dx + _halfBase, bottom)
        ..lineTo(bar.dx + _halfTop, top)
        ..lineTo(bar.dx - _halfTop, top)
        ..close();
      canvas
        ..drawPath(path, fill)
        ..drawPath(path, edge);
    }

    const cx = 388.0, cy = 150.0, s = 52.0, w = s * 0.22;
    final sparkle = Path()
      ..moveTo(cx, cy - s)
      ..lineTo(cx + w, cy - w)
      ..lineTo(cx + s, cy)
      ..lineTo(cx + w, cy + w)
      ..lineTo(cx, cy + s)
      ..lineTo(cx - w, cy + w)
      ..lineTo(cx - s, cy)
      ..lineTo(cx - w, cy - w)
      ..close();
    canvas.drawPath(sparkle, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}
