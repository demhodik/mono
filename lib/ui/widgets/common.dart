import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import 'glass.dart';
import 'motion.dart';
import 'vinyl.dart';

class Cover extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  final IconData fallback;
  const Cover(this.url, {super.key, this.size = 48, this.radius = 8, this.fallback = Icons.music_note_rounded});

  @override
  Widget build(BuildContext context) {
    final ph = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF111111)],
        ),
      ),
      child: Icon(fallback, color: C.sub, size: size * 0.42),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty
          ? ph
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => ph,
              frameBuilder: (_, child, frame, sync) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: sync || frame != null ? child : ph,
              ),
            ),
    );
  }
}

/// Loads data once (and on retry), shows spinner / error.
class Loader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;
  final bool sliver;
  const Loader({super.key, required this.load, required this.builder, this.sliver = false});

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return _wrap(Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off_rounded, color: C.sub, size: 40),
              const SizedBox(height: 12),
              Text('${snap.error}', style: const TextStyle(color: C.sub), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              GlassButton(onTap: () => setState(() => _future = widget.load()), child: const Text('Повторить')),
            ]),
          ));
        }
        if (!snap.hasData) {
          return _wrap(const Center(child: GlassSpinner()));
        }
        return widget.builder(context, snap.data as T);
      },
    );
  }

  Widget _wrap(Widget w) => widget.sliver ? SliverToBoxAdapter(child: SizedBox(height: 180, child: w)) : w;
}

class GlassSpinner extends StatelessWidget {
  final double size;
  const GlassSpinner({super.key, this.size = 34});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white, strokeCap: StrokeCap.round),
      );
}

/// Scrollable page body.
class MonoPage extends StatelessWidget {
  final Widget header;
  final List<Widget> slivers;
  const MonoPage({super.key, required this.header, this.slivers = const []});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: header),
      ...slivers,
      const SliverToBoxAdapter(child: SizedBox(height: 140)),
    ]);
  }
}

/// Header: tilting cover with a vinyl sliding out of it + big title.
class PageHeader extends StatelessWidget {
  final String overline;
  final String title;
  final String? subtitle;
  final String image;
  final IconData icon;
  final String source;
  const PageHeader({
    super.key,
    required this.overline,
    required this.title,
    this.subtitle,
    this.image = '',
    this.icon = Icons.music_note_rounded,
    this.source = '',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        FadeSlideIn(
          child: SizedBox(
            width: 310,
            height: 220,
            child: ListenableBuilder(
              listenable: app.player,
              builder: (context, _) {
                final playing = app.player.source == source && app.player.playing;
                return Stack(children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutBack,
                    left: playing ? 100 : 60,
                    top: 10,
                    child: Vinyl(cover: image, size: 200, spinning: playing),
                  ),
                  Tilt3D(
                    radius: 18,
                    child: Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40, offset: const Offset(0, 18)),
                      ]),
                      child: image.isNotEmpty ? Cover(image, size: 220, radius: 18) : IconArt(icon: icon, size: 220),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ),
        const SizedBox(width: 28),
        Expanded(
          child: FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(overline.toUpperCase(),
                  style: const TextStyle(fontSize: 12, letterSpacing: 3, color: C.sub, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Unbounded', 
                    fontSize: (title.length > 22 ? 40 : 64) * 0.74,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -0.6,
                  )),
              if (subtitle != null) ...[
                const SizedBox(height: 14),
                Text(subtitle!, style: const TextStyle(color: C.sub, fontSize: 14)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class IconArt extends StatelessWidget {
  final IconData icon;
  final double size;
  final double radius;
  const IconArt({super.key, required this.icon, required this.size, this.radius = 18});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A3A3A), Color(0xFF0E0E0E)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, size: size * 0.42, color: Colors.white),
    );
  }
}

/// Big play + shuffle.
class PlayActions extends StatelessWidget {
  final List<Track> tracks;
  final String source;
  const PlayActions({super.key, required this.tracks, required this.source});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app.player,
      builder: (context, _) {
        final p = app.player;
        final isThis = p.source == source && p.current != null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(32, 4, 32, 18),
          child: Row(children: [
            GlassButton(
              active: true,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              iconSize: 26,
              onTap: tracks.isEmpty ? null : () => isThis ? p.toggle() : p.playList(tracks, 0, source: source),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isThis && p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                const SizedBox(width: 8),
                Text(isThis && p.playing ? 'Пауза' : 'Слушать', style: const TextStyle(fontSize: 15)),
              ]),
            ),
            const SizedBox(width: 12),
            GlassButton(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              onTap: tracks.isEmpty ? null : () => p.playAll(tracks, source: source, shuffled: true),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.shuffle_rounded),
                SizedBox(width: 8),
                Text('Вперемешку'),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

/// Track list.
class TrackSliver extends StatelessWidget {
  final List<Track> tracks;
  final String source;
  const TrackSliver({super.key, required this.tracks, required this.source});

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: Text('Здесь пока пусто', style: TextStyle(color: C.sub))),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList.builder(
        itemCount: tracks.length,
        itemBuilder: (context, i) {
          final row = TrackRow(tracks: tracks, index: i, source: source);
          return i < 16 ? FadeSlideIn.index(i, dy: 16, child: row) : row;
        },
      ),
    );
  }
}

class TrackRow extends StatefulWidget {
  final List<Track> tracks;
  final int index;
  final String source;
  const TrackRow({super.key, required this.tracks, required this.index, required this.source});

  @override
  State<TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<TrackRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tracks[widget.index];
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.player]),
      builder: (context, _) {
        final p = app.player;
        final current = p.isCurrent(t);
        final liked = app.isLiked(t);
        Widget lead;
        if (current) {
          lead = EqBars(playing: p.playing);
        } else if (_hover) {
          lead = const Icon(Icons.play_arrow_rounded, size: 20);
        } else {
          lead = Text('${widget.index + 1}', style: const TextStyle(color: C.dim, fontSize: 14));
        }
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => current ? p.toggle() : p.playList(widget.tracks, widget.index, source: widget.source),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 62,
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              transform: Matrix4.translationValues(_hover ? 4 : 0, 0, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: current
                    ? Colors.white.withValues(alpha: 0.10)
                    : (_hover ? Colors.white.withValues(alpha: 0.06) : Colors.transparent),
                border: Border.all(color: Colors.white.withValues(alpha: current ? 0.16 : (_hover ? 0.08 : 0))),
              ),
              child: Opacity(
                opacity: t.available ? 1 : 0.4,
                child: Row(children: [
                  SizedBox(width: 30, child: Center(child: lead)),
                  const SizedBox(width: 8),
                  AnimatedScale(
                    scale: _hover ? 1.06 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: Cover(t.coverOf(100), size: 44, radius: 10),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, fontWeight: current ? FontWeight.w800 : FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(t.artists,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: C.sub, fontSize: 13)),
                        ]),
                  ),
                  SizedBox(
                    width: 40,
                    child: AnimatedOpacity(
                      opacity: (liked || _hover) ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: HoverIcon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 18, active: liked, onTap: () => app.toggleLike(t)),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(fmt(t.duration),
                        textAlign: TextAlign.right, style: const TextStyle(color: C.sub, fontSize: 13)),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  const SectionTitle(this.title, {super.key, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 14),
      child: Row(children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontFamily: 'Unbounded', fontSize: 19.2, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
        ),
        if (onMore != null)
          GlassButton(
            onTap: onMore,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Все', style: TextStyle(fontSize: 13)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 16),
            ]),
          ),
      ]),
    );
  }
}

/// Square card that tilts in 3D on hover, with a glass play button.
class MediaCard extends StatefulWidget {
  final String image;
  final String title;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;
  final IconData fallback;
  const MediaCard({
    super.key,
    required this.image,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    this.onPlay,
    this.fallback = Icons.album_rounded,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, c) => Tilt3D(
                  radius: 16,
                  child: Stack(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: _hover ? 0.7 : 0.4),
                          blurRadius: _hover ? 30 : 16,
                          offset: Offset(0, _hover ? 16 : 8),
                        ),
                      ]),
                      child: widget.image.isEmpty
                          ? IconArt(icon: widget.fallback, size: c.maxWidth, radius: 16)
                          : Cover(widget.image, size: c.maxWidth, radius: 16, fallback: widget.fallback),
                    ),
                    if (widget.onPlay != null)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: AnimatedOpacity(
                          opacity: _hover ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: AnimatedSlide(
                            offset: _hover ? Offset.zero : const Offset(0, 0.3),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            child: GlassButton.icon(Icons.play_arrow_rounded,
                                size: 26, pad: 11, active: true, onTap: widget.onPlay),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(widget.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(widget.subtitle,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.sub, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class CardGrid extends StatelessWidget {
  final int count;
  final Widget Function(int i) item;
  const CardGrid({super.key, required this.count, required this.item});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 230, mainAxisExtent: 290),
        itemCount: count,
        itemBuilder: (_, i) => FadeSlideIn.index(i, child: item(i)),
      ),
    );
  }
}
