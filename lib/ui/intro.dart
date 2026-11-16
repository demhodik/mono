import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'widgets/background.dart';

/// Launch animation: the icon flips in from edge-on in 3D, the orbit draws itself
/// around it, a glare sweeps across, letters of "MONO" rise in, then everything
/// zooms through the screen into the app. Click to skip.
class IntroOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const IntroOverlay({super.key, required this.onDone});

  @override
  State<IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<IntroOverlay> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));
  late final AnimationController _spark = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(_finish);
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  void _skip() {
    if (_c.value < 0.78) _c.animateTo(1, duration: const Duration(milliseconds: 450), curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _c.dispose();
    _spark.dispose();
    super.dispose();
  }

  double _seg(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _skip,
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, _spark]),
        builder: (context, _) {
          final flip = _seg(0.0, 0.32, Curves.easeOutBack); // icon flips in
          final orbit = _seg(0.18, 0.50); // orbit draws
          final glare = _seg(0.40, 0.62, Curves.easeInOut); // glare sweep
          final text = _seg(0.45, 0.72); // letters
          final out = _seg(0.80, 1.0, Curves.easeInCubic); // zoom out

          final iconSize = 190.0;
          final angle = (1 - flip) * math.pi / 2; // edge-on -> facing

          return Opacity(
            opacity: 1 - out,
            child: Stack(fit: StackFit.expand, children: [
              const ColoredBox(color: Colors.black),
              Center(
                child: Transform.scale(
                  scale: 1 + out * 5,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: out * 12, sigmaY: out * 12),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 520,
                        height: 300,
                        child: Stack(alignment: Alignment.center, children: [
                          // glow
                          Container(
                            width: 360,
                            height: 360,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                Colors.white.withValues(alpha: 0.10 * flip),
                                Colors.white.withValues(alpha: 0),
                              ]),
                            ),
                          ),
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0014)
                              ..rotateY(angle)
                              ..rotateX(angle * 0.25),
                            child: Opacity(
                              opacity: flip.clamp(0, 1),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(iconSize * 0.22),
                                child: Stack(children: [
                                  Image.asset('assets/icon.png', width: iconSize, height: iconSize),
                                  // glare sweep
                                  Positioned.fill(
                                    child: Transform.translate(
                                      offset: Offset((glare * 2 - 1) * iconSize * 1.3, 0),
                                      child: Transform.rotate(
                                        angle: 0.5,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [
                                              Colors.white.withValues(alpha: 0),
                                              Colors.white.withValues(alpha: glare > 0 && glare < 1 ? 0.45 : 0),
                                              Colors.white.withValues(alpha: 0),
                                            ], stops: const [0.35, 0.5, 0.65]),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                          // orbit around the icon
                          IgnorePointer(
                            child: CustomPaint(
                              size: const Size(500, 260),
                              painter: OrbitPainter(_spark.value, reveal: orbit),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      _Letters(progress: text),
                    ]),
                  ),
                ),
              ),
              Positioned(
                bottom: 28,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: text * 0.5,
                  child: const Text('нажми, чтобы пропустить',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _Letters extends StatelessWidget {
  final double progress;
  const _Letters({required this.progress});

  @override
  Widget build(BuildContext context) {
    const word = 'MONO';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < word.length; i++)
        Builder(builder: (context) {
          final p = Curves.easeOutCubic.transform(((progress * 1.6) - i * 0.18).clamp(0.0, 1.0));
          return Opacity(
            opacity: p,
            child: Transform.translate(
              offset: Offset(0, (1 - p) * 30),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: (1 - p) * 8, sigmaY: (1 - p) * 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(word[i],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 54,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 4,
                      )),
                ),
              ),
            ),
          );
        }),
    ]);
  }
}
