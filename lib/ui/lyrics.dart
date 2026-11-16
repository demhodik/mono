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
  late Future<Lyrics> _f = app.api!.lyrics(widget.track);

  @override
  void didUpdateWidget(LyricsLoader old) {
    super.didUpdateWidget(old);
    if (old.track.id != widget.track.id) _f = app.api!.lyrics(widget.track);
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
    app.addListener(_tick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  @override
  void dispose() {
    app.player.position.removeListener(_tick);
    app.removeListener(_tick);
    super.dispose();
  }

  void _tick() {
    // show the line slightly early so it feels in time
    final i = widget.lyrics.indexAt(app.lyricsTime);
    if (i == _current) return;
    setState(() => _current = i);
    final ctx = (i >= 0 ? _keys[i] : _keys.first).currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: 0.38, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
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
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: opacity.toDouble(),
              duration: const Duration(milliseconds: 220),
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

/// Game overlay: dark glass capsule at the top, current line fills white like karaoke.
class OverlayLyrics extends StatelessWidget {
  const OverlayLyrics({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app.player,
      builder: (context, _) {
        final t = app.player.current;
        return Container(
          constraints: const BoxConstraints(minWidth: 420, maxWidth: 1060),
          padding: const EdgeInsets.fromLTRB(30, 14, 30, 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: t == null
              ? const Text('Mono · ничего не играет', style: TextStyle(color: Colors.white70, fontSize: 18))
              : LyricsLoader(
                  key: ValueKey(t.id),
                  track: t,
                  loading: const _OverlayHeader(text: 'Ищу текст…'),
                  builder: (context, l) {
                    if (!l.synced) {
                      return _OverlayHeader(
                          text: l.isEmpty ? '${t.title} — ${t.artists} · текста нет' : '${t.title} — текст без тайминга');
                    }
                    return ListenableBuilder(
                      listenable: Listenable.merge([app.player.position, app]),
                      builder: (context, _) {
                        final now = app.lyricsTime;
                        final i = l.indexAt(now);
                        final cur = i >= 0 ? l.lines[i] : null;
                        final next = i + 1 < l.lines.length ? l.lines[i + 1] : null;
                        double fill = 0;
                        if (cur != null) {
                          final end = next?.time ?? cur.time + const Duration(seconds: 4);
                          final span = (end - cur.time).inMilliseconds.clamp(300, 20000);
                          // fill over ~85% of the gap so it finishes before the next line
                          fill = ((now - cur.time).inMilliseconds / (span * 0.85)).clamp(0.0, 1.0);
                        }
                        final curText = (cur == null || cur.text.isEmpty) ? '♪' : cur.text;
                        return Column(mainAxisSize: MainAxisSize.min, children: [
                          _OverlayHeader(text: '${t.title} — ${t.artists}'),
                          const SizedBox(height: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (c, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                                child: c,
                              ),
                            ),
                            child: ShaderMask(
                              key: ValueKey('c$i'),
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (r) => LinearGradient(
                                colors: const [Colors.white, Colors.white, Color(0x73FFFFFF), Color(0x73FFFFFF)],
                                stops: [0, fill, fill, 1],
                              ).createShader(r),
                              child: Text(curText,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.2)),
                            ),
                          ),
                          if (next != null && next.text.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(next.text,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5))),
                          ],
                        ]);
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}

class _OverlayHeader extends StatelessWidget {
  final String text;
  const _OverlayHeader({required this.text});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.graphic_eq_rounded, size: 14, color: Colors.white.withValues(alpha: 0.55)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600)),
        ),
      ]);
}

/// Small control to nudge lyrics timing.
class LyricsSyncControl extends StatelessWidget {
  const LyricsSyncControl({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final v = app.lyricsOffset / 1000;
        final label = v == 0 ? 'синхрон' : '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)} с';
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Tooltip(message: 'Текст позже', child: _Nudge(icon: Icons.remove_rounded, onTap: () => app.shiftLyrics(-250))),
          GestureDetector(
            onDoubleTap: () => app.shiftLyrics(-app.lyricsOffset),
            child: SizedBox(
              width: 70,
              child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: C.sub, fontSize: 12)),
            ),
          ),
          Tooltip(message: 'Текст раньше', child: _Nudge(icon: Icons.add_rounded, onTap: () => app.shiftLyrics(250))),
        ]);
      },
    );
  }
}

class _Nudge extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Nudge({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Icon(icon, size: 16),
          ),
        ),
      );
}
