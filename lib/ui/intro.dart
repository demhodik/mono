import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'widgets/background.dart';

/// Launch film (~2.8 s, click to skip):
/// light particles spiral into the centre → the icon condenses out of blur and
/// tips up in 3D → the orbit draws itself with a running spark → the wordmark
/// resolves letter by letter → an iris opens from the icon and the interface
/// flies in piece by piece behind it.
class IntroOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const IntroOverlay({super.key, required this.onDone});

  @override
  State<IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<IntroOverlay> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  late final AnimationController _spark = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
    ..repeat();
  static const _revealAt = 0.78;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (_c.value >= _revealAt && !app.revealed.value) app.revealed.value = true;
    });
    _c.forward().whenComplete(() {
      app.revealed.value = true;
      widget.onDone();
    });
  }

  void _skip() {
    if (_c.value < _revealAt) _c.forward(from: _revealAt);
  }

  @override
  void dispose() {
    _c.dispose();
    _spark.dispose();
    super.dispose();
  }

  double _seg(double a, double b, [Curve c = Curves.easeOutCubic]) =>
      c.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, _spark]),
        builder: (context, _) {
          final gather = _seg(0.0, 0.36, Curves.easeInOutCubic);
          final icon = _seg(0.20, 0.52, Curves.easeOutBack);
          final sharp = _seg(0.20, 0.46);
          final orbit = _seg(0.34, 0.66, Curves.easeInOutCubic);
          final word = _seg(0.46, 0.74);
          final out = _seg(_revealAt, 1.0, Curves.easeInOutCubic);

          return IgnorePointer(
            ignoring: out > 0,
            child: ClipPath(
              clipper: _IrisClipper(out),
              child: Stack(fit: StackFit.expand, children: [
                const ColoredBox(color: Colors.black),
                CustomPaint(painter: _FxPainter(gather: gather, glow: icon, out: out)),
                Center(
                  child: Transform.scale(
                    scale: 1 + out * 0.5,
                    child: Opacity(
                      opacity: (1 - out * 1.6).clamp(0.0, 1.0),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                          width: 460,
                          height: 240,
                          child: Stack(alignment: Alignment.center, children: [
                            Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0016)
                                ..rotateX((1 - icon) * 1.15)
                                ..rotateZ((1 - icon) * -0.25)
                                ..scaleByDouble(0.5 + 0.5 * icon, 0.5 + 0.5 * icon, 1, 1),
                              child: Opacity(
                                opacity: sharp,
                                child: ImageFiltered(
                                  imageFilter: ImageFilter.blur(sigmaX: (1 - sharp) * 22, sigmaY: (1 - sharp) * 22),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(36),
                                      boxShadow: [
                                        BoxShadow(color: Colors.white.withValues(alpha: 0.22 * sharp), blurRadius: 70),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(36),
                                      child: Image.asset('assets/icon.png', width: 156, height: 156),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (orbit > 0)
                              IgnorePointer(
                                child: CustomPaint(
                                  size: const Size(440, 230),
                                  painter: OrbitPainter(_spark.value, reveal: orbit),
                                ),
                              ),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        _Wordmark(progress: word),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// Black sheet with a circular hole growing from the centre.
class _IrisClipper extends CustomClipper<Path> {
  final double t;
  _IrisClipper(this.t);

  @override
  Path getClip(Size size) {
    final full = Path()..addRect(Offset.zero & size);
    if (t <= 0) return full;
    final r = t * size.bottomRight(Offset.zero).distance * 0.56;
    return full
      ..addOval(Rect.fromCircle(center: size.center(Offset.zero), radius: r))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(_IrisClipper old) => old.t != t;
}

class _FxPainter extends CustomPainter {
  final double gather; // particles 0..1
  final double glow;
  final double out;
  _FxPainter({required this.gather, required this.glow, required this.out});

  static final _seeds = List.generate(70, (i) {
    final r = math.Random(i * 7 + 3);
    return [r.nextDouble() * 2 * math.pi, 0.35 + r.nextDouble() * 0.75, 0.6 + r.nextDouble() * 1.8, r.nextDouble()];
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final far = size.longestSide * 0.6;

    // soft halo behind the icon
    if (glow > 0) {
      final rad = 260 + 40 * glow;
      canvas.drawCircle(
        c,
        rad,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: 0.10 * glow.clamp(0.0, 1.0)),
            Colors.white.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c, radius: rad)),
      );
    }

    // particles spiralling in, leaving short trails
    if (gather < 1) {
      final p = Paint()..strokeCap = StrokeCap.round;
      for (final s in _seeds) {
        final local = ((gather - s[3] * 0.25) / 0.75).clamp(0.0, 1.0);
        if (local <= 0) continue;
        Offset at(double q) {
          final e = Curves.easeInCubic.transform(q);
          final ang = s[0] + (1 - e) * 2.2;
          final dist = far * s[1] * (1 - e) + 46 * e;
          return c + Offset(math.cos(ang), math.sin(ang)) * dist;
        }

        final a = math.sin(local * math.pi).clamp(0.0, 1.0);
        p
          ..color = Colors.white.withValues(alpha: a * 0.85)
          ..strokeWidth = s[2];
        canvas.drawLine(at((local - 0.05).clamp(0.0, 1.0)), at(local), p);
      }
    }

    // shockwave when the iris opens
    if (out > 0 && out < 1) {
      canvas.drawCircle(
        c,
        out * size.bottomRight(Offset.zero).distance * 0.56 + 10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - out) + 0.5
          ..color = Colors.white.withValues(alpha: (1 - out) * 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(_FxPainter o) => o.gather != gather || o.glow != glow || o.out != out;
}

class _Wordmark extends StatelessWidget {
  final double progress;
  const _Wordmark({required this.progress});

  @override
  Widget build(BuildContext context) {
    const word = 'MONO';
    return SizedBox(
      height: 44,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < word.length; i++)
          Builder(builder: (context) {
            final p = Curves.easeOutCubic.transform(((progress * 1.7) - i * 0.22).clamp(0.0, 1.0));
            if (p <= 0) return const SizedBox(width: 44);
            return SizedBox(
              width: 44,
              child: Opacity(
                opacity: p,
                child: Transform.translate(
                  offset: Offset(0, (1 - p) * 18),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: (1 - p) * 7, sigmaY: (1 - p) * 7),
                    child: Text(word[i],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'Unbounded', fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            );
          }),
      ]),
    );
  }
}
