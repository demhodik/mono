import 'dart:ui';

import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import 'glass.dart';

const greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

class Cover extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  final IconData fallback;
  const Cover(this.url, {super.key, this.size = 48, this.radius = 4, this.fallback = Icons.music_note});

  @override
  Widget build(BuildContext context) {
    final ph = Container(
      width: size,
      height: size,
      color: C.hover,
      child: Icon(fallback, color: C.sub, size: size * 0.45),
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
              errorBuilder: (_, __, ___) => ph,
              frameBuilder: (_, child, frame, sync) =>
                  sync || frame != null ? child : ph,
            ),
    );
  }
}

/// Loads data once (and on retry), shows spinner / error.
class Loader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;
  /// When true, spinner/error are wrapped so the Loader can live in a CustomScrollView.
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
              GlassButton(
                onTap: () => setState(() => _future = widget.load()),
                child: const Text('Повторить'),
              ),
            ]),
          ));
        }
        if (!snap.hasData) {
          return _wrap(const Center(
            child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
          ));
        }
        return widget.builder(context, snap.data as T);
      },
    );
  }

  Widget _wrap(Widget w) =>
      widget.sliver ? SliverToBoxAdapter(child: SizedBox(height: 160, child: w)) : w;
}

/// Scrollable page body with a header and slivers below.
class MonoPage extends StatelessWidget {
  final Widget header;
  final List<Widget> slivers;
  const MonoPage({super.key, required this.header, this.slivers = const []});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

class PageHeader extends StatelessWidget {
  final String overline;
  final String title;
  final String? subtitle;
  final String image;
  final IconData icon;
  const PageHeader({
    super.key,
    required this.overline,
    required this.title,
    this.subtitle,
    this.image = '',
    this.icon = Icons.music_note,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(fit: StackFit.expand, children: [
        // blurred greyscale cover as backdrop
        if (image.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: ColorFiltered(
              colorFilter: greyscale,
              child: Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: image.isNotEmpty
                  ? [Colors.black.withValues(alpha: 0.15), C.panel]
                  : [const Color(0xFF4A4A4A), C.panel],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 60, 28, 24),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              decoration: BoxDecoration(boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40, offset: const Offset(0, 8)),
              ]),
              child: image.isNotEmpty
                  ? Cover(image, size: 200, radius: 6)
                  : Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFFFFF), Color(0xFF6B6B6B)],
                        ),
                      ),
                      child: Icon(icon, size: 84, color: Colors.black),
                    ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(overline, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: title.length > 24 ? 44 : 72,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      letterSpacing: -2,
                    )),
                if (subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(subtitle!, style: const TextStyle(color: C.sub, fontSize: 14)),
                ],
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Row of actions under the header: big play + shuffle.
class PlayActions extends StatelessWidget {
  final List<Track> tracks;
  final String source;
  final List<Widget> extra;
  const PlayActions({super.key, required this.tracks, required this.source, this.extra = const []});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app.player,
      builder: (context, _) {
        final p = app.player;
        final isThis = p.source == source && p.current != null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
          child: Row(children: [
            GlassButton.icon(
              isThis && p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 34,
              pad: 12,
              active: true,
              tooltip: 'Слушать',
              onTap: tracks.isEmpty
                  ? null
                  : () => isThis ? p.toggle() : p.playList(tracks, 0, source: source),
            ),
            const SizedBox(width: 16),
            GlassButton.icon(Icons.shuffle_rounded,
                tooltip: 'Перемешать',
                size: 22,
                pad: 11,
                onTap: tracks.isEmpty ? null : () => p.playAll(tracks, source: source, shuffled: true)),
            ...extra,
          ]),
        );
      },
    );
  }
}

class TrackListHeader extends StatelessWidget {
  const TrackListHeader({super.key});
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(28, 0, 28, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            SizedBox(width: 32, child: Text('#', style: TextStyle(color: C.sub))),
            Expanded(child: Text('Название', style: TextStyle(color: C.sub, fontSize: 13))),
            SizedBox(width: 40),
            SizedBox(width: 56, child: Icon(Icons.schedule_rounded, size: 18, color: C.sub)),
          ]),
        ),
      ),
    );
  }
}

/// Sliver list of tracks, Spotify style.
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
      padding: const EdgeInsets.symmetric(horizontal: 28),
      sliver: SliverList.builder(
        itemCount: tracks.length,
        itemBuilder: (context, i) => TrackRow(tracks: tracks, index: i, source: source),
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
        if (_hover) {
          lead = Icon(current && p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 20);
        } else if (current) {
          lead = Icon(p.playing ? Icons.graphic_eq_rounded : Icons.volume_up_rounded, size: 18);
        } else {
          lead = Text('${widget.index + 1}', style: const TextStyle(color: C.sub, fontSize: 15));
        }
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (current) {
                p.toggle();
              } else {
                p.playList(widget.tracks, widget.index, source: widget.source);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _hover ? C.hover : (current ? Colors.white.withValues(alpha: 0.06) : Colors.transparent),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Opacity(
                opacity: t.available ? 1 : 0.4,
                child: Row(children: [
                  SizedBox(width: 32, child: lead),
                  Cover(t.coverOf(100), size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: current ? FontWeight.w800 : FontWeight.w500,
                            decoration: current ? TextDecoration.underline : null,
                            decorationColor: Colors.white,
                          )),
                      const SizedBox(height: 2),
                      Text(t.artists,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _hover ? Colors.white : C.sub, fontSize: 13)),
                    ]),
                  ),
                  SizedBox(
                    width: 40,
                    child: (liked || _hover)
                        ? HoverIcon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 18, active: liked, onTap: () => app.toggleLike(t))
                        : null,
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(fmt(t.duration), style: const TextStyle(color: C.sub, fontSize: 13)),
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
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
        if (onMore != null)
          GlassButton(
            onTap: onMore,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: const Text('Показать все', style: TextStyle(fontSize: 13)),
          ),
      ]),
    );
  }
}

/// Square card (album / playlist) with a glass play button on hover.
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hover ? C.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, c) => Stack(children: [
                  Cover(widget.image, size: c.maxWidth, radius: 6, fallback: widget.fallback),
                  if (widget.onPlay != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: AnimatedOpacity(
                        opacity: _hover ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: AnimatedSlide(
                          offset: _hover ? Offset.zero : const Offset(0, 0.25),
                          duration: const Duration(milliseconds: 150),
                          child: GlassButton.icon(Icons.play_arrow_rounded,
                              size: 28, pad: 10, active: true, onTap: widget.onPlay),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Text(widget.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(widget.subtitle,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.sub, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

/// Responsive grid of cards as a sliver.
class CardGrid extends StatelessWidget {
  final int count;
  final Widget Function(int i) item;
  const CardGrid({super.key, required this.count, required this.item});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 290,
        ),
        itemCount: count,
        itemBuilder: (_, i) => item(i),
      ),
    );
  }
}
