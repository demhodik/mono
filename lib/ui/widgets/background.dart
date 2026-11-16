import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Slowly drifting monochrome "liquid" light behind all glass,
/// plus a soft light that follows the mouse.
class LiquidBackground extends StatefulWidget {
  final Widget child;
  const LiquidBackground({super.key, required this.child});

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();
  final _mouse = ValueNotifier<Offset?>(null);

  @override
  void dispose() {
    _c.dispose();
    _mouse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      hitTestBehavior: HitTestBehavior.translucent,
      onHover: (e) => _mouse.value = e.localPosition,
      onExit: (_) => _mouse.value = null,
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Color(0xFF040404)),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_c, _mouse]),
            builder: (context, _) => CustomPaint(painter: _BlobPainter(_c.value, _mouse.value)),
          ),
        ),
        widget.child,
      ]),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final double t;
  final Offset? mouse;
  _BlobPainter(this.t, this.mouse);

  void _blob(Canvas c, Size s, double cx, double cy, double r, double a) {
    final center = Offset(cx * s.width, cy * s.height);
    final rad = r * s.shortestSide;
    c.drawCircle(
      center,
      rad,
      Paint()
        ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: a), Colors.white.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: center, radius: rad)),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = t * 2 * math.pi;
    _blob(canvas, size, 0.20 + 0.10 * math.sin(w), 0.25 + 0.12 * math.cos(w * 2), 0.75, 0.10);
    _blob(canvas, size, 0.80 + 0.08 * math.cos(w * 3), 0.30 + 0.15 * math.sin(w), 0.60, 0.07);
    _blob(canvas, size, 0.55 + 0.20 * math.sin(w * 2 + 1), 0.85 + 0.06 * math.cos(w), 0.70, 0.08);
    _blob(canvas, size, 0.35 + 0.15 * math.cos(w + 2), 0.60 + 0.10 * math.sin(w * 3), 0.35, 0.06);
    if (mouse != null) {
      final rad = size.shortestSide * 0.45;
      canvas.drawCircle(
        mouse!,
        rad,
        Paint()
          ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: mouse!, radius: rad)),
      );
    }
    // vignette
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.0,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
          stops: const [0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BlobPainter o) => o.t != t || o.mouse != mouse;
}

/// 3D orbit ring (from the app icon): tilted ellipse rotating, with a running sparkle.
class OrbitPainter extends CustomPainter {
  final double t; // 0..1 loop
  final double reveal; // 0..1 draw-in progress
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

    // ring body: brighter on the front (bottom) half
    for (var i = 0; i < 3; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = [9.0, 4.0, 1.4][i]
        ..color = Colors.white.withValues(alpha: [0.05, 0.12, 0.75][i]);
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * reveal, false, paint);
    }
    // front highlight arc
    canvas.drawArc(
      rect,
      0.15,
      2.6 * reveal,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..shader = SweepGradient(colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0),
        ]).createShader(rect),
    );

    // sparkle running along the ring
    if (reveal >= 1) {
      final a = t * 2 * math.pi;
      final p = Offset(rx * math.cos(a), ry * math.sin(a));
      final front = math.sin(a) > 0;
      final s = front ? 1.0 : 0.45;
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

/// Self-animating orbit widget.
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
