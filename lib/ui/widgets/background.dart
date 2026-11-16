import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pure black with one soft beam of light from the top. Static = zero cost.
class LiquidBackground extends StatelessWidget {
  final Widget child;
  const LiquidBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Colors.black),
      const IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _LightPainter()))),
      child,
    ]);
  }
}

class _LightPainter extends CustomPainter {
  const _LightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = Offset(w * 0.55, -h * 0.25);
    final r1 = h * 1.05;
    canvas.drawCircle(
      top,
      r1,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: 0.13),
          Colors.white.withValues(alpha: 0.045),
          Colors.white.withValues(alpha: 0),
        ], stops: const [0, 0.45, 1]).createShader(Rect.fromCircle(center: top, radius: r1)),
    );
    final r2 = h * 0.45;
    canvas.drawCircle(
      top,
      r2,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: top, radius: r2)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3D orbit ring (from the app icon): tilted ellipse with a running sparkle.
class OrbitPainter extends CustomPainter {
  final double t;
  final double reveal;
  final double tilt;
  OrbitPainter(this.t, {this.reveal = 1, this.tilt = -0.32});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    final rx = size.width * 0.48;
    final ry = size.height * 0.16;
    final rect = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * reveal,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = [9.0, 4.0, 1.4][i]
          ..color = Colors.white.withValues(alpha: [0.05, 0.12, 0.75][i]),
      );
    }
    if (reveal >= 1) {
      final a = t * 2 * math.pi;
      final p = Offset(rx * math.cos(a), ry * math.sin(a));
      final s = math.sin(a) > 0 ? 1.0 : 0.45;
      canvas.drawCircle(
        p,
        22 * s,
        Paint()
          ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.9 * s), Colors.white.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: p, radius: 22 * s)),
      );
      final star = Paint()
        ..color = Colors.white.withValues(alpha: s)
        ..strokeWidth = 1.4;
      canvas.drawLine(p - Offset(26 * s, 0), p + Offset(26 * s, 0), star);
      canvas.drawLine(p - Offset(0, 14 * s), p + Offset(0, 14 * s), star);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(OrbitPainter o) => o.t != t || o.reveal != reveal;
}

/// Self-animating orbit.
class Orbit extends StatefulWidget {
  final double width;
  final double height;
  final Duration period;
  const Orbit({super.key, required this.width, required this.height, this.period = const Duration(seconds: 4)});

  @override
  State<Orbit> createState() => _OrbitState();
}

class _OrbitState extends State<Orbit> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) =>
              CustomPaint(size: Size(widget.width, widget.height), painter: OrbitPainter(_c.value)),
        ),
      );
}
