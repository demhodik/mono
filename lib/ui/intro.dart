import 'dart:ui';

import 'package:flutter/material.dart';

/// Short, quiet launch: icon emerges from blur, one light sweep, wordmark, dissolve.
class IntroOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const IntroOverlay({super.key, required this.onDone});

  @override
  State<IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<IntroOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double a, double b, [Curve c = Curves.easeOutCubic]) => c.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _c.animateTo(1, duration: const Duration(milliseconds: 250)),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final appear = _seg(0.0, 0.45);
          final sweep = _seg(0.30, 0.65, Curves.easeInOut);
          final word = _seg(0.35, 0.70);
          final out = _seg(0.78, 1.0, Curves.easeInCubic);
          return IgnorePointer(
            ignoring: out > 0.5,
            child: Opacity(
              opacity: 1 - out,
              child: ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: (1 - appear) * 18, sigmaY: (1 - appear) * 18),
                      child: Opacity(
                        opacity: appear,
                        child: Transform.scale(
                          scale: 0.9 + 0.1 * appear + out * 0.06,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(34),
                            child: Stack(children: [
                              Image.asset('assets/icon.png', width: 150, height: 150),
                              Positioned.fill(
                                child: FractionalTranslation(
                                  translation: Offset(sweep * 2.4 - 1.2, 0),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.white.withValues(alpha: 0),
                                          Colors.white.withValues(alpha: sweep > 0 && sweep < 1 ? 0.35 : 0),
                                          Colors.white.withValues(alpha: 0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Opacity(
                      opacity: word,
                      child: Transform.translate(
                        offset: Offset(0, (1 - word) * 10),
                        child: Text('MONO',
                            style: TextStyle(
                              fontFamily: 'Unbounded',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 6 + word * 6,
                              color: Colors.white.withValues(alpha: 0.85),
                            )),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
