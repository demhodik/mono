import 'package:flutter/material.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Loads lyrics for the current track (cached per track id).
class LyricsLoader extends StatefulWidget {
  final Track track;
  final Widget Function(BuildContext context, Lyrics lyrics) builder;
  final Widget? loading;
  const LyricsLoader({super.key, required this.track, required this.builder, this.loading});

  @override
  State<LyricsLoader> createState() => _LyricsLoaderState();
}

class _LyricsLoaderState extends State<LyricsLoader> {
  late Future<Lyrics> _f = app.api!.lyrics(widget.track.id);

  @override
  void didUpdateWidget(LyricsLoader old) {
    super.didUpdateWidget(old);
    if (old.track.id != widget.track.id) _f = app.api!.lyrics(widget.track.id);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Lyrics>(
        future: _f,
        builder: (context, snap) {
          if (!snap.hasData) return widget.loading ?? const Center(child: GlassSpinner());
          return widget.builder(context, snap.data!);
        },
      );
}

/// Karaoke view: current line big and bright, auto-scrolls smoothly, click to seek.
class LyricsView extends StatelessWidget {
  final Track track;
  const LyricsView({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    return LyricsLoader(
      track: track,
      builder: (context, l) {
        if (l.isEmpty) {
          return const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lyrics_outlined, size: 40, color: C.dim),
              SizedBox(height: 10),
              Text('У этого трека нет текста', style: TextStyle(color: C.sub)),
            ]),
          );
        }
        if (!l.synced) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 60),
            child: Text(l.plain, style: const TextStyle(fontSize: 20, height: 1.7, fontWeight: FontWeight.w600)),
          );
        }
        return _SyncedLyrics(lyrics: l);
      },
    );
  }
}

class _SyncedLyrics extends StatefulWidget {
  final Lyrics lyrics;
  const _SyncedLyrics({required this.lyrics});
  @override
  State<_SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends State<_SyncedLyrics> {
  late final List<GlobalKey> _keys = List.generate(widget.lyrics.lines.length, (_) => GlobalKey());
  int _current = -2;

  @override
  void initState() {
    super.initState();
    app.player.position.addListener(_tick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  @override
  void dispose() {
    app.player.position.removeListener(_tick);
    super.dispose();
  }

  void _tick() {
    // show the line slightly early so it feels in time
    final i = widget.lyrics.indexAt(app.player.position.value + const Duration(milliseconds: 250));
    if (i == _current) return;
    setState(() => _current = i);
    final ctx = (i >= 0 ? _keys[i] : _keys.first).currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: 0.38, duration: const Duration(milliseconds: 650), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.lyrics.lines;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
        stops: [0, 0.14, 0.82, 1],
      ).createShader(r),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 200),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < lines.length; i++)
              _Line(
                key: _keys[i],
                text: lines[i].text.isEmpty ? '♪' : lines[i].text,
                state: i == _current ? 0 : (i < _current ? -1 : 1),
                distance: (i - _current).abs(),
                onTap: () => app.player.seek(lines[i].time),
              ),
          ]),
        ),
      ),
    );
  }
}

class _Line extends StatefulWidget {
  final String text;
  final int state; // -1 past, 0 current, 1 future
  final int distance;
  final VoidCallback onTap;
  const _Line({super.key, required this.text, required this.state, required this.distance, required this.onTap});
  @override
  State<_Line> createState() => _LineState();
}

class _LineState extends State<_Line> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cur = widget.state == 0;
    final opacity = cur ? 1.0 : (_hover ? 0.75 : (widget.state < 0 ? 0.28 : (0.5 - widget.distance * 0.04).clamp(0.22, 0.5)));
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: AnimatedScale(
            scale: cur ? 1.0 : 0.94,
            alignment: Alignment.centerLeft,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: opacity.toDouble(),
              duration: const Duration(milliseconds: 450),
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: 30,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: cur ? [Shadow(color: Colors.white.withValues(alpha: 0.45), blurRadius: 24)] : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact two-line karaoke for the game overlay.
class OverlayLyrics extends StatefulWidget {
  const OverlayLyrics({super.key});
  @override
  State<OverlayLyrics> createState() => _OverlayLyricsState();
}

class _OverlayLyricsState extends State<OverlayLyrics> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app.player,
      builder: (context, _) {
        final t = app.player.current;
        if (t == null) return const _OutlinedText('Mono: ничего не играет', size: 22, dim: true);
        return LyricsLoader(
          key: ValueKey(t.id),
          track: t,
          loading: const SizedBox(),
          builder: (context, l) {
            if (!l.synced) {
              return _OutlinedText(
                l.isEmpty ? '${t.title} — ${t.artists}' : '${t.title} — текст без синхронизации',
                size: 22,
                dim: true,
              );
            }
            return ValueListenableBuilder<Duration>(
              valueListenable: app.player.position,
              builder: (context, pos, _) {
                final i = l.indexAt(pos + const Duration(milliseconds: 250));
                final cur = i >= 0 ? l.lines[i].text : '♪';
                final next = i + 1 < l.lines.length ? l.lines[i + 1].text : '';
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(a),
                        child: c,
                      ),
                    ),
                    child: _OutlinedText(cur.isEmpty ? '♪' : cur, key: ValueKey('c$i'), size: 40),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: _OutlinedText(next, key: ValueKey('n$i'), size: 24, dim: true),
                  ),
                ]);
              },
            );
          },
        );
      },
    );
  }
}

/// White text with a dark outline so it reads over any game.
class _OutlinedText extends StatelessWidget {
  final String text;
  final double size;
  final bool dim;
  const _OutlinedText(this.text, {super.key, required this.size, this.dim = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: size, fontWeight: FontWeight.w800, height: 1.2);
    return Stack(children: [
      Text(text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.16
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black.withValues(alpha: 0.85),
          )),
      Text(text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(
            color: Colors.white.withValues(alpha: dim ? 0.7 : 1),
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 12)],
          )),
    ]);
  }
}
