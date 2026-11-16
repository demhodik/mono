import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'background.dart';

/// Real 3D liquid-chrome blob (raymarched in a fragment shader).
/// Breathes slowly when idle, moves faster and wilder while [active]; the light follows the mouse.
class Orb3D extends StatefulWidget {
  final double size;
  final bool active;
  const Orb3D({super.key, required this.size, required this.active});

  static ui.FragmentProgram? _program;
  static Future<void>? _loading;
  static Future<void> preload() => _loading ??= ui.FragmentProgram.fromAsset('shaders/orb.frag').then((p) {
        _program = p;
      }).catchError((_) {});

  @override
  State<Orb3D> createState() => _Orb3DState();
}

class _Orb3DState extends State<Orb3D> with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _energy =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200), value: widget.active ? 1 : 0);
  final _time = ValueNotifier<double>(0);
  Offset _mouse = Offset.zero;
  Offset _mouseSmooth = Offset.zero;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      _mouseSmooth = Offset.lerp(_mouseSmooth, _mouse, 0.08)!;
      _time.value = d.inMicroseconds / 1e6;
    })
      ..start();
    if (Orb3D._program != null) {
      _shader = Orb3D._program!.fragmentShader();
    } else {
      Orb3D.preload().then((_) {
        if (mounted && Orb3D._program != null) setState(() => _shader = Orb3D._program!.fragmentShader());
      });
    }
  }

  @override
  void didUpdateWidget(Orb3D old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) widget.active ? _energy.forward() : _energy.reverse();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _energy.dispose();
    _time.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    if (_shader == null) return WaveOrb(size: s, active: widget.active);
    return MouseRegion(
      onHover: (e) => _mouse = Offset(e.localPosition.dx / s * 2 - 1, e.localPosition.dy / s * 2 - 1),
      onExit: (_) => _mouse = Offset.zero,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(s),
          painter: _OrbShaderPainter(_shader!, _time, _energy, () => _mouseSmooth),
        ),
      ),
    );
  }
}

class _OrbShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ValueNotifier<double> time;
  final Animation<double> energy;
  final Offset Function() mouse;
  _OrbShaderPainter(this.shader, this.time, this.energy, this.mouse) : super(repaint: Listenable.merge([time, energy]));

  @override
  void paint(Canvas canvas, Size size) {
    final m = mouse();
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time.value)
      ..setFloat(3, Curves.easeInOut.transform(energy.value))
      ..setFloat(4, m.dx)
      ..setFloat(5, m.dy);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _OrbShaderPainter old) => false;
}
