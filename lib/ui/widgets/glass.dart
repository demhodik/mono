import 'dart:ui';

import 'package:flutter/material.dart';

/// Liquid-glass button: frosted blur, gradient body, top rim highlight,
/// a specular light spot that follows the cursor and a springy press.
/// `active` = solid milky-white glass with dark content.
class GlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;
  final bool active;
  final String? tooltip;
  final double iconSize;

  const GlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    this.radius = 999,
    this.active = false,
    this.tooltip,
    this.iconSize = 20,
  });

  factory GlassButton.icon(IconData icon,
      {Key? key, VoidCallback? onTap, String? tooltip, double size = 20, double pad = 10, bool active = false}) {
    return GlassButton(
      key: key,
      onTap: onTap,
      tooltip: tooltip,
      iconSize: size,
      active: active,
      padding: EdgeInsets.all(pad),
      child: Icon(icon),
    );
  }

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> with SingleTickerProviderStateMixin {
  bool _hover = false;
  Offset _light = const Offset(0.3, 0.2); // normalized cursor position
  late final AnimationController _press =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420), value: 0);

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _down() => _press.animateTo(1, duration: const Duration(milliseconds: 90), curve: Curves.easeOut);
  void _up() => _press.animateTo(0, duration: const Duration(milliseconds: 520), curve: Curves.elasticOut);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final active = widget.active;
    final r = BorderRadius.circular(widget.radius);
    final fg = active ? const Color(0xFF0A0A0A) : Colors.white;

    final body = Builder(builder: (context) {
      return MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) {
          setState(() => _hover = false);
          _up();
        },
        onHover: (e) {
          final s = context.size;
          if (s != null && s.width > 0) {
            setState(() => _light = Offset(e.localPosition.dx / s.width, e.localPosition.dy / s.height));
          }
        },
        child: GestureDetector(
          onTapDown: enabled ? (_) => _down() : null,
          onTapUp: enabled ? (_) => _up() : null,
          onTapCancel: _up,
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _press,
            builder: (context, child) => Transform.scale(scale: 1 - _press.value * 0.07, child: child),
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.35,
              duration: const Duration(milliseconds: 200),
              child: DecoratedBox(
                decoration: BoxDecoration(borderRadius: r, boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: _hover ? 22 : 14,
                    offset: Offset(0, _hover ? 8 : 5),
                  ),
                  if (active)
                    BoxShadow(color: Colors.white.withValues(alpha: _hover ? 0.28 : 0.16), blurRadius: 24, spreadRadius: -2),
                ]),
                child: ClipRRect(
                  borderRadius: r,
                  child: _MaybeBlur(
                    sigma: 0,
                    child: CustomPaint(
                      foregroundPainter: _GlassPainter(
                        radius: widget.radius,
                        light: _light,
                        hover: _hover && enabled,
                        active: active,
                        rimOnly: true,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: widget.padding,
                        decoration: BoxDecoration(
                          borderRadius: r,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: active
                                ? [const Color(0xF2FFFFFF), const Color(0xD9D8D8D8)]
                                : [
                                    Colors.white.withValues(alpha: _hover ? 0.22 : 0.13),
                                    Colors.white.withValues(alpha: _hover ? 0.08 : 0.035),
                                  ],
                          ),
                        ),
                        child: IconTheme.merge(
                          data: IconThemeData(color: fg, size: widget.iconSize),
                          child: DefaultTextStyle.merge(
                            style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.1),
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });

    return widget.tooltip == null ? body : Tooltip(message: widget.tooltip!, child: body);
  }
}

/// Paints glass rim (bright top edge fading down) and specular spot.
class _GlassPainter extends CustomPainter {
  final double radius;
  final Offset light;
  final bool hover;
  final bool active;
  final bool rimOnly;
  _GlassPainter(
      {required this.radius, required this.light, required this.hover, required this.active, this.rimOnly = false});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(radius.clamp(0, size.shortestSide / 2)));

    // rim: gradient stroke, brighter on top
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: active ? 0.95 : (hover ? 0.7 : 0.5)),
          Colors.white.withValues(alpha: active ? 0.4 : 0.06),
          Colors.white.withValues(alpha: active ? 0.6 : (hover ? 0.25 : 0.14)),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRRect(rr, rim);

    // specular spot following the cursor (subtle so content stays crisp)
    if (hover && !active) {
      canvas.save();
      canvas.clipRRect(rr);
      final c = Offset(light.dx * size.width, light.dy * size.height);
      final rad = size.longestSide * 0.9;
      canvas.drawCircle(
        c,
        rad,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: rimOnly ? 0.10 : 0.28),
            Colors.white.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c, radius: rad)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GlassPainter o) =>
      o.light != light || o.hover != hover || o.active != active || o.radius != radius;
}

/// Frosted glass surface for cards / panels.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final double opacity;
  final double blur;
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
    this.opacity = 0.06,
    this.blur = 0,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 16)),
      ]),
      child: ClipRRect(
        borderRadius: r,
        child: _MaybeBlur(
          sigma: blur,
          child: CustomPaint(
            foregroundPainter: _GlassPainter(radius: radius, light: Offset.zero, hover: false, active: false),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: r,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white.withValues(alpha: opacity + 0.04), Colors.white.withValues(alpha: opacity * 0.4)],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Flat icon that brightens on hover (for dense rows).
class HoverIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool active;
  final String? tooltip;
  const HoverIcon(this.icon, {super.key, this.onTap, this.size = 20, this.active = false, this.tooltip});

  @override
  State<HoverIcon> createState() => _HoverIconState();
}

class _HoverIconState extends State<HoverIcon> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    Widget w = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.12 : 1,
          duration: const Duration(milliseconds: 150),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(widget.icon,
                size: widget.size, color: widget.active || _hover ? Colors.white : const Color(0xFF9A9A9A)),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) w = Tooltip(message: widget.tooltip!, child: w);
    return w;
  }
}

class _MaybeBlur extends StatelessWidget {
  final double sigma;
  final Widget child;
  const _MaybeBlur({required this.sigma, required this.child});
  @override
  Widget build(BuildContext context) =>
      sigma <= 0 ? child : BackdropFilter(filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: child);
}
