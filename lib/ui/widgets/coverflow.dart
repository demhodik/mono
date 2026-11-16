import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';
import 'glass.dart';

class CoverFlowItem {
  final String image;
  final String title;
  final String subtitle;
  const CoverFlowItem({required this.image, required this.title, required this.subtitle});
}

/// 3D cover-flow carousel with mirror reflections.
/// Wheel / drag / arrows / click to navigate; auto-advances when idle.
class CoverFlow extends StatefulWidget {
  final List<CoverFlowItem> items;
  final void Function(int index) onOpen;
  final void Function(int index)? onPlay;
  final double cardSize;
  const CoverFlow({super.key, required this.items, required this.onOpen, this.onPlay, this.cardSize = 290});

  @override
  State<CoverFlow> createState() => _CoverFlowState();
}

class _CoverFlowState extends State<CoverFlow> with SingleTickerProviderStateMixin {
  late final AnimationController _pos =
      AnimationController.unbounded(vsync: this, value: math.min(2, widget.items.length - 1).toDouble());
  Timer? _auto;
  bool _hover = false;
  double _dragStart = 0;
  double _dragPos = 0;

  int get _index => _pos.value.round().clamp(0, widget.items.length - 1);

  @override
  void initState() {
    super.initState();
    _auto = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_hover && mounted) _go(_index + 1 >= widget.items.length ? 0 : _index + 1);
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _pos.dispose();
    super.dispose();
  }

  void _go(int i) {
    final target = i.clamp(0, widget.items.length - 1).toDouble();
    _pos.animateTo(target, duration: const Duration(milliseconds: 650), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    if (n == 0) return const SizedBox();
    final s = widget.cardSize;
    return MouseRegion(
      onEnter: (_) => _hover = true,
      onExit: (_) => _hover = false,
      child: Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent && e.scrollDelta.dx.abs() > e.scrollDelta.dy.abs()) {
            _go(_index + (e.scrollDelta.dx > 0 ? 1 : -1));
          }
        },
        child: GestureDetector(
          onHorizontalDragStart: (d) {
            _dragStart = d.localPosition.dx;
            _dragPos = _pos.value;
            _pos.stop();
          },
          onHorizontalDragUpdate: (d) {
            _pos.value = (_dragPos - (d.localPosition.dx - _dragStart) / (s * 0.6)).clamp(0, n - 1).toDouble();
          },
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            _go((_pos.value - v / 2500).round());
          },
          child: AnimatedBuilder(
            animation: _pos,
            builder: (context, _) {
              final p = _pos.value;
              final order = List<int>.generate(n, (i) => i)
                ..removeWhere((i) => (i - p).abs() > 4.5)
                ..sort((a, b) => (b - p).abs().compareTo((a - p).abs()));
              final cur = _index;
              return Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
                for (final i in order) _card(i, i - p, s),
                // caption
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a),
                        child: c,
                      ),
                    ),
                    child: Column(key: ValueKey(cur), children: [
                      Text(widget.items[cur].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Unbounded', fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                      const SizedBox(height: 4),
                      Text(widget.items[cur].subtitle, style: const TextStyle(color: C.sub, fontSize: 14)),
                    ]),
                  ),
                ),
                // arrows
                Positioned(
                  left: 0,
                  top: s / 2 - 22,
                  child: GlassButton.icon(Icons.chevron_left_rounded,
                      size: 26, pad: 9, onTap: cur > 0 ? () => _go(cur - 1) : null),
                ),
                Positioned(
                  right: 0,
                  top: s / 2 - 22,
                  child: GlassButton.icon(Icons.chevron_right_rounded,
                      size: 26, pad: 9, onTap: cur < n - 1 ? () => _go(cur + 1) : null),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }

  Widget _card(int i, double d, double s) {
    final ad = d.abs();
    final sign = d.sign;
    // compress spacing for far cards
    final x = sign * (ad <= 1 ? ad * s * 0.78 : s * 0.78 + (ad - 1) * s * 0.36);
    final rot = -d.clamp(-1.0, 1.0) * 0.95;
    final scale = 1 - math.min(ad, 3) * 0.10;
    final z = ad * 120;
    final opacity = (1 - (ad - 3).clamp(0, 1.5) / 1.5).clamp(0.0, 1.0);
    final item = widget.items[i];
    final isCenter = ad < 0.5;

    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0011)
      ..translateByDouble(x, 0, z, 1)
      ..rotateY(rot)
      ..scaleByDouble(scale, scale, 1, 1);

    return Positioned(
      top: 0,
      width: s,
      child: Opacity(
        opacity: opacity.toDouble(),
        child: Transform(
          alignment: Alignment.topCenter,
          transform: m,
          child: GestureDetector(
            onTap: () => isCenter ? widget.onOpen(i) : _go(i),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Stack(children: [
                  Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 40, offset: const Offset(0, 24)),
                    ]),
                    child: Cover(item.image, size: s, radius: 20, fallback: Icons.album_rounded),
                  ),
                  // edge highlight + darkening of side cards
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.10),
                              Colors.black.withValues(alpha: (ad * 0.35).clamp(0, 0.55)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isCenter && widget.onPlay != null)
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: GlassButton.icon(Icons.play_arrow_rounded,
                          size: 30, pad: 12, active: true, onTap: () => widget.onPlay!(i)),
                    ),
                ]),
                // mirror reflection
                SizedBox(
                  height: s * 0.32,
                  child: ClipRect(
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (r) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white.withValues(alpha: 0.28), Colors.transparent],
                      ).createShader(r),
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: s + 6,
                        maxHeight: s + 6,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Transform.flip(
                            flipY: true,
                            child: Cover(item.image, size: s, radius: 20, fallback: Icons.album_rounded),
                          ),
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
    );
  }
}
