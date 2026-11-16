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

/// Living liquid orb for "Моя волна": layered wobbling blobs that move faster
/// and bigger while the wave is playing.
class WaveOrb extends StatefulWidget {
  final double size;
  final bool active;
  const WaveOrb({super.key, required this.size, required this.active});

  @override
  State<WaveOrb> createState() => _WaveOrbState();
}

class _WaveOrbState extends State<WaveOrb> with TickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  late final AnimationController _energy =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900), value: widget.active ? 1 : 0);

  @override
  void didUpdateWidget(WaveOrb old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      widget.active ? _energy.forward() : _energy.reverse();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    _energy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_t, _energy]),
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _OrbPainter(_t.value, Curves.easeInOut.transform(_energy.value)),
          ),
        ),
      );
}

class _OrbPainter extends CustomPainter {
  final double t;
  final double e; // 0..1 energy
  _OrbPainter(this.t, this.e);

  Path _blob(Offset c, double r, double amp, int seed, double speed) {
    final p = Path();
    const n = 120;
    final ph = t * 2 * math.pi * speed;
    for (var i = 0; i <= n; i++) {
      final a = i / n * 2 * math.pi;
      final d = math.sin(a * 3 + ph + seed) * 0.5 +
          math.sin(a * 5 - ph * 1.3 + seed * 2) * 0.3 +
          math.sin(a * 2 + ph * 0.7 + seed * 3) * 0.2;
      final rr = r * (1 + amp * d);
      final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final R = size.shortestSide * 0.30;
    // outer glow
    canvas.drawCircle(
      c,
      R * 1.9,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: 0.10 + 0.10 * e),
          Colors.white.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: R * 1.9)),
    );
    final amp = 0.05 + 0.09 * e;
    final speed = 3 + 5 * e;
    // back layers (rings)
    for (var k = 0; k < 3; k++) {
      canvas.drawPath(
        _blob(c, R * (1.18 + k * 0.14), amp * (1.2 + k * 0.3), k + 3, speed * (0.7 - k * 0.1)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.30 - k * 0.08),
      );
    }
    // body
    final body = _blob(c, R, amp, 1, speed);
    canvas.drawPath(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.0,
          colors: const [Color(0xFFFFFFFF), Color(0xFFBDBDBD), Color(0xFF3A3A3A), Color(0xFF0C0C0C)],
          stops: const [0.0, 0.25, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: R * 1.1)),
    );
    // glass rim + inner highlight
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.save();
    canvas.clipPath(body);
    canvas.drawPath(
      _blob(c + Offset(R * 0.25, R * 0.3), R * 0.75, amp * 1.5, 7, speed * 1.2),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbPainter o) => o.t != t || o.e != e;
}
