import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'widgets/orb3d.dart';

/// Launch film (~3 s, click to skip):
/// light particles spiral into the dark → the 3D chrome orb is born in the middle →
/// the wordmark rises under it → the darkness lifts, the interface assembles around,
/// and the orb flies to its place in "Моя волна" on the home screen.
class IntroOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const IntroOverlay({super.key, required this.onDone});

  @override
  State<IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<IntroOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3100));
  static const _revealAt = 0.6;
  Rect? _target;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (_c.value >= _revealAt && !app.revealed.value) {
        app.revealed.value = true;
      }
      if (_c.value >= _revealAt) _target = _heroRect() ?? _target;
    });
    _c.forward().whenComplete(_finish);
  }

  Rect? _heroRect() {
    final box = app.heroOrbKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _finish() {
    app.revealed.value = true;
    app.introDone.value = true;
    widget.onDone();
  }

  void _skip() {
    if (_c.value < _revealAt) _c.forward(from: _revealAt);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double a, double b, [Curve c = Curves.easeOutCubic]) =>
      c.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final gather = _seg(0.0, 0.34, Curves.easeInOutCubic);
          final born = _seg(0.14, 0.42, Curves.easeOutBack);
          final word = _seg(0.30, 0.52);
          final lift = _seg(_revealAt, 0.92, Curves.easeInOutCubic); // darkness fades
          final fly = _seg(_revealAt, 1.0, Curves.easeInOutCubic);

          const startSize = 300.0;
          final start = Rect.fromCenter(center: screen.center(Offset.zero).translate(0, -30), width: startSize, height: startSize);
          final target = _target;
          final rect = target == null ? start : Rect.lerp(start, target, fly)!;
          final orbOpacity = target == null ? (1 - fly) : 1.0;

          return IgnorePointer(
            ignoring: _c.value >= _revealAt,
            child: Stack(children: [
              Opacity(
                opacity: 1 - lift,
                child: Stack(fit: StackFit.expand, children: [
                  const ColoredBox(color: Colors.black),
                  CustomPaint(painter: _Particles(gather)),
                ]),
              ),
              // the orb
              Positioned.fromRect(
                rect: rect,
                child: Opacity(
                  opacity: orbOpacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.15 + 0.85 * born,
                    child: Opacity(
                      opacity: born.clamp(0.0, 1.0),
                      child: LayoutBuilder(builder: (context, c) => Orb3D(size: c.maxWidth, active: true)),
                    ),
                  ),
                ),
              ),
              // wordmark
              Positioned(
                left: 0,
                right: 0,
                top: start.bottom + 6,
                child: Opacity(
                  opacity: (word * (1 - lift * 1.8)).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, (1 - word) * 18),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: (1 - word) * 8, sigmaY: (1 - word) * 8),
                      child: Text('Mono',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Unbounded',
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2 + word * 6,
                            color: Colors.white,
                          )),
                    ),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _Particles extends CustomPainter {
  final double gather;
  _Particles(this.gather);

  static final _seeds = List.generate(80, (i) {
    final r = math.Random(i * 7 + 3);
    return [r.nextDouble() * 2 * math.pi, 0.35 + r.nextDouble() * 0.75, 0.6 + r.nextDouble() * 1.8, r.nextDouble()];
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (gather >= 1) return;
    final c = size.center(Offset.zero).translate(0, -30);
    final far = size.longestSide * 0.6;
    final p = Paint()..strokeCap = StrokeCap.round;
    for (final s in _seeds) {
      final local = ((gather - s[3] * 0.25) / 0.75).clamp(0.0, 1.0);
      if (local <= 0) continue;
      Offset at(double q) {
        final e = Curves.easeInCubic.transform(q);
        final ang = s[0] + (1 - e) * 2.2;
        final dist = far * s[1] * (1 - e) + 40 * e;
        return c + Offset(math.cos(ang), math.sin(ang)) * dist;
      }

      p
        ..color = Colors.white.withValues(alpha: math.sin(local * math.pi).clamp(0.0, 1.0) * 0.85)
        ..strokeWidth = s[2];
      canvas.drawLine(at((local - 0.05).clamp(0.0, 1.0)), at(local), p);
    }
  }

  @override
  bool shouldRepaint(_Particles o) => o.gather != gather;
}
