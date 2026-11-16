import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fades + slides a child in once, after an optional delay (for staggered lists).
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double dy;
  final Duration duration;
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.dy = 24,
    this.duration = const Duration(milliseconds: 560),
  });

  /// Stagger helper: delay grows with index but is capped.
  factory FadeSlideIn.index(int i, {Key? key, required Widget child, int stepMs = 45, double dy = 24}) =>
      FadeSlideIn(key: key, delay: Duration(milliseconds: math.min(i, 14) * stepMs), dy: dy, child: child);

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(
          offset: Offset(0, (1 - a.value) * widget.dy),
          child: Transform.scale(scale: 0.97 + 0.03 * a.value, child: child),
        ),
      ),
      child: widget.child,
    );
  }
}

/// Tilts its child in 3D toward the mouse, with a moving glare.
class Tilt3D extends StatefulWidget {
  final Widget child;
  final double maxAngle; // radians
  final double radius;
  final bool glare;
  final double depth;
  const Tilt3D({super.key, required this.child, this.maxAngle = 0.22, this.radius = 16, this.glare = true, this.depth = 0.0012});

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> {
  Offset _target = Offset.zero; // -1..1
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _target = Offset.zero;
      }),
      onHover: (e) {
        final s = context.size;
        if (s == null || s.isEmpty) return;
        setState(() => _target = Offset(e.localPosition.dx / s.width * 2 - 1, e.localPosition.dy / s.height * 2 - 1));
      },
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(end: _target),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, o, child) {
          final m = Matrix4.identity()
            ..setEntry(3, 2, widget.depth)
            ..rotateX(-o.dy * widget.maxAngle)
            ..rotateY(o.dx * widget.maxAngle);
          return Transform(
            alignment: Alignment.center,
            transform: m,
            child: Stack(children: [
              child!,
              if (widget.glare)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _hover ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(widget.radius),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment(o.dx, o.dy),
                              radius: 1.1,
                              colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Little animated equalizer used to mark the playing track.
class EqBars extends StatefulWidget {
  final bool playing;
  final double size;
  final Color color;
  const EqBars({super.key, required this.playing, this.size = 16, this.color = Colors.white});

  @override
  State<EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<EqBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(EqBars old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) _c.repeat();
    if (!widget.playing) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _EqPainter(_c.value, widget.color, widget.playing)),
      ),
    );
  }
}

class _EqPainter extends CustomPainter {
  final double t;
  final Color color;
  final bool playing;
  _EqPainter(this.t, this.color, this.playing);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const n = 4;
    final w = size.width / (n * 1.7);
    for (var i = 0; i < n; i++) {
      final ph = t * 2 * math.pi + i * 1.7;
      final h = playing ? (0.3 + 0.7 * (0.5 + 0.5 * math.sin(ph * (1 + i * 0.3)))) : 0.3;
      final x = i * w * 1.7;
      canvas.drawRRect(
        RRect.fromLTRBR(x, size.height * (1 - h), x + w, size.height, Radius.circular(w / 2)),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_EqPainter o) => o.t != t || o.playing != playing;
}
