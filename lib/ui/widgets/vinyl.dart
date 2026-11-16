import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'common.dart';

/// Glossy vinyl record with the cover as its label. Spins while [spinning].
class Vinyl extends StatefulWidget {
  final String cover;
  final double size;
  final bool spinning;
  const Vinyl({super.key, required this.cover, required this.size, this.spinning = false});

  @override
  State<Vinyl> createState() => _VinylState();
}

class _VinylState extends State<Vinyl> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _c.repeat();
  }

  @override
  void didUpdateWidget(Vinyl old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_c.isAnimating) _c.repeat();
    if (!widget.spinning && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(alignment: Alignment.center, children: [
        // shadow
        Container(
          width: s,
          height: s,
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: s * 0.12, offset: Offset(0, s * 0.05)),
          ]),
        ),
        RotationTransition(
          turns: _c,
          child: RepaintBoundary(child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: Size(s, s), painter: _DiscPainter()),
            ClipOval(child: Cover(widget.cover, size: s * 0.38, radius: 0)),
            Container(
              width: s * 0.035,
              height: s * 0.035,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0A0A0A)),
            ),
          ])),
        ),
        // static light reflection (does not rotate)
        IgnorePointer(child: CustomPaint(size: Size(s, s), painter: _SheenPainter())),
      ]),
    );
  }
}

class _DiscPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFF1C1C1C), Color(0xFF070707)], stops: [0.3, 1])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (var rr = r * 0.22; rr < r * 0.97; rr += 2.2) {
      groove.color = Colors.white.withValues(alpha: 0.025 + 0.02 * math.sin(rr * 0.7).abs());
      canvas.drawCircle(c, rr, groove);
    }
    // edge rim
    canvas.drawCircle(
      c,
      r - 0.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SheenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final ring = Path()
      ..addOval(rect)
      ..addOval(Rect.fromCircle(center: c, radius: r * 0.2))
      ..fillType = PathFillType.evenOdd;
    canvas.save();
    canvas.clipPath(ring);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.02, 0.10, 0.20, 0.52, 0.60, 0.70],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Turntable tonearm that swings onto the record while playing.
class Tonearm extends StatelessWidget {
  final double length;
  final bool playing;
  const Tonearm({super.key, required this.length, required this.playing});

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: playing ? 0.075 : 0.0,
      alignment: Alignment.topRight,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
      child: CustomPaint(size: Size(length * 0.42, length), painter: _ArmPainter()),
    );
  }
}

class _ArmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width - 14, 14);
    final elbow = Offset(size.width - 14, size.height * 0.62);
    final head = Offset(size.width * 0.18, size.height * 0.93);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final arm = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFF2F2F2), Color(0xFF8C8C8C)])
          .createShader(Offset.zero & size)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(head.dx, head.dy);
    canvas.drawPath(path.shift(const Offset(3, 5)), shadow);
    canvas.drawPath(path, arm);
    // pivot base
    canvas.drawCircle(pivot, 13, Paint()..color = const Color(0xFF1B1B1B));
    canvas.drawCircle(
        pivot,
        13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.35));
    canvas.drawCircle(pivot, 5, Paint()..color = const Color(0xFFDADADA));
    // headshell
    canvas.save();
    canvas.translate(head.dx, head.dy);
    canvas.rotate(0.62);
    final r = RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -6, 18, 26), const Radius.circular(4));
    canvas.drawRRect(r, Paint()..color = const Color(0xFFEDEDED));
    canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.black.withValues(alpha: 0.4));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
