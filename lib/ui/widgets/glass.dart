import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted-glass button: blurred, translucent, with a thin light border.
/// `active` turns it into a solid white "pressed" state with black content.
class GlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;
  final bool active;
  final String? tooltip;
  final double iconSize;
  final double blur;

  const GlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    this.radius = 999,
    this.active = false,
    this.tooltip,
    this.iconSize = 20,
    this.blur = 14,
  });

  /// Round icon-only glass button.
  factory GlassButton.icon(IconData icon,
      {Key? key, VoidCallback? onTap, String? tooltip, double size = 20, double pad = 9, bool active = false}) {
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

class _GlassButtonState extends State<GlassButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final r = BorderRadius.circular(widget.radius);
    final active = widget.active;
    final fg = active ? Colors.black : Colors.white;
    final base = active ? 0.92 : (_hover && enabled ? 0.17 : 0.09);

    Widget content = IconTheme.merge(
      data: IconThemeData(color: fg, size: widget.iconSize),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14),
        child: widget.child,
      ),
    );

    Widget btn = ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: r,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: (base + 0.08).clamp(0, 1)),
                Colors.white.withValues(alpha: base * 0.55),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: active ? 0.9 : (_hover ? 0.35 : 0.18)),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: content,
        ),
      ),
    );

    btn = AnimatedScale(
      scale: _down ? 0.95 : 1,
      duration: const Duration(milliseconds: 90),
      child: AnimatedOpacity(opacity: enabled ? 1 : 0.35, duration: const Duration(milliseconds: 150), child: btn),
    );

    btn = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: btn,
      ),
    );

    if (widget.tooltip != null) btn = Tooltip(message: widget.tooltip!, child: btn);
    return btn;
  }
}

/// Plain flat icon that brightens on hover (for dense rows where blur would be too heavy).
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
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(widget.icon,
              size: widget.size,
              color: widget.active || _hover ? Colors.white : const Color(0xFFA7A7A7)),
        ),
      ),
    );
    if (widget.tooltip != null) w = Tooltip(message: widget.tooltip!, child: w);
    return w;
  }
}
