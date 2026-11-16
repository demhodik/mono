import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

// ======================= HOME =======================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return 'Доброй ночи';
    if (h < 12) return 'Доброе утро';
    if (h < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  @override
  Widget build(BuildContext context) {
    final api = app.api!;
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A3A3A), C.panel],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_greeting, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            ListenableBuilder(
              listenable: app,
              builder: (context, _) {
                final tiles = <Widget>[
                  _QuickTile(
                    title: 'Моя волна',
                    icon: Icons.waves_rounded,
                    onTap: () => app.go(PageKind.wave),
                    onPlay: app.startWave,
                  ),
                  _QuickTile(
                    title: 'Мне нравится',
                    icon: Icons.favorite_rounded,
                    onTap: () => app.go(PageKind.likes),
                  ),
                  _QuickTile(title: 'Чарт', icon: Icons.trending_up_rounded, onTap: () => app.go(PageKind.chart)),
                  _QuickTile(title: 'Новинки', icon: Icons.new_releases_rounded, onTap: () => app.go(PageKind.releases)),
                  for (final p in app.playlists.take(4))
                    _QuickTile(
                      title: p.title,
                      image: p.coverOf(100),
                      icon: Icons.queue_music_rounded,
                      onTap: () => app.go(PageKind.playlist, p),
                    ),
                ];
                return LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth > 1000 ? 4 : (c.maxWidth > 640 ? 2 : 1);
                  final w = (c.maxWidth - (cols - 1) * 10) / cols;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [for (final t in tiles) SizedBox(width: w, child: t)],
                  );
                });
              },
            ),
          ]),
        ),
      ),
      SliverToBoxAdapter(
        child: SectionTitle('Новые релизы', onMore: () => app.go(PageKind.releases)),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 290,
          child: Loader<List<Album>>(
            load: api.newReleases,
            builder: (context, albums) => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: math.min(albums.length, 20),
              itemBuilder: (_, i) => SizedBox(width: 200, child: _albumCard(albums[i])),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(child: SectionTitle('Чарт', onMore: () => app.go(PageKind.chart))),
      Loader<List<Track>>(
        sliver: true,
        load: api.chart,
        builder: (context, tracks) => TrackSliver(tracks: tracks.take(10).toList(), source: 'chart'),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 40)),
    ]);
  }
}

Widget _albumCard(Album a) => MediaCard(
      image: a.coverOf(300),
      title: a.title,
      subtitle: a.artists,
      onOpen: () => app.go(PageKind.album, a),
      onPlay: () async {
        try {
          final t = await app.api!.albumTracks(a.id);
          app.player.playList(t, 0, source: 'album:${a.id}');
        } catch (e) {
          app.toast('$e');
        }
      },
    );

class _QuickTile extends StatefulWidget {
  final String title;
  final IconData icon;
  final String image;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  const _QuickTile({required this.title, required this.icon, required this.onTap, this.image = '', this.onPlay});

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _hover ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(children: [
            widget.image.isNotEmpty
                ? Cover(widget.image, size: 64, radius: 0)
                : Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Color(0xFF7A7A7A)],
                      ),
                    ),
                    child: Icon(widget.icon, color: Colors.black, size: 28),
                  ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(widget.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (widget.onPlay != null)
              AnimatedOpacity(
                opacity: _hover ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GlassButton.icon(Icons.play_arrow_rounded, size: 22, pad: 7, active: true, onTap: widget.onPlay),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ======================= TRACK LIST PAGES =======================

/// Generic page: header + play actions + track list, loaded asynchronously.
class TrackListPage extends StatelessWidget {
  final Future<List<Track>> Function() load;
  final String source;
  final String overline;
  final String title;
  final String image;
  final IconData icon;
  final String Function(List<Track>)? subtitle;
  const TrackListPage({
    super.key,
    required this.load,
    required this.source,
    required this.overline,
    required this.title,
    this.image = '',
    this.icon = Icons.music_note,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Loader<List<Track>>(
      load: load,
      builder: (context, tracks) {
        final total = tracks.fold<Duration>(Duration.zero, (s, t) => s + t.duration);
        return MonoPage(
          header: PageHeader(
            overline: overline,
            title: title,
            image: image,
            icon: icon,
            subtitle: subtitle?.call(tracks) ??
                '${plural(tracks.length, 'трек', 'трека', 'треков')} · ${fmt(total)}',
          ),
          slivers: [
            SliverToBoxAdapter(child: PlayActions(tracks: tracks, source: source)),
            const SliverToBoxAdapter(child: TrackListHeader()),
            TrackSliver(tracks: tracks, source: source),
          ],
        );
      },
    );
  }
}

class LikesPage extends StatelessWidget {
  const LikesPage({super.key});
  @override
  Widget build(BuildContext context) => TrackListPage(
        load: app.api!.likedTracks,
        source: 'likes',
        overline: 'Плейлист',
        title: 'Мне нравится',
        icon: Icons.favorite_rounded,
        subtitle: (t) => '${app.api!.displayName ?? ''} · ${plural(t.length, 'трек', 'трека', 'треков')}',
      );
}

class ChartPage extends StatelessWidget {
  const ChartPage({super.key});
  @override
  Widget build(BuildContext context) => TrackListPage(
        load: app.api!.chart,
        source: 'chart',
        overline: 'Подборка',
        title: 'Чарт',
        icon: Icons.trending_up_rounded,
        subtitle: (_) => 'Самое популярное прямо сейчас · обновляется каждый день',
      );
}

class AlbumPage extends StatelessWidget {
  final Album album;
  const AlbumPage(this.album, {super.key});
  @override
  Widget build(BuildContext context) => TrackListPage(
        load: () => app.api!.albumTracks(album.id),
        source: 'album:${album.id}',
        overline: 'Альбом',
        title: album.title,
        image: album.coverOf(400),
        icon: Icons.album_rounded,
        subtitle: (t) => [
          album.artists,
          if (album.year != null) '${album.year}',
          plural(t.length, 'трек', 'трека', 'треков'),
        ].join(' · '),
      );
}

class PlaylistPage extends StatelessWidget {
  final Playlist playlist;
  const PlaylistPage(this.playlist, {super.key});
  @override
  Widget build(BuildContext context) => TrackListPage(
        load: () => app.api!.playlistTracks(playlist),
        source: 'playlist:${playlist.kind}',
        overline: 'Плейлист',
        title: playlist.title,
        image: playlist.coverOf(400),
        icon: Icons.queue_music_rounded,
      );
}

// ======================= NEW RELEASES =======================

class ReleasesPage extends StatelessWidget {
  const ReleasesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Loader<List<Album>>(
      load: app.api!.newReleases,
      builder: (context, albums) => MonoPage(
        header: const PageHeader(
          overline: 'Подборка',
          title: 'Новинки',
          icon: Icons.new_releases_rounded,
          subtitle: 'Свежие релизы — подтягиваются сами каждый раз',
        ),
        slivers: [CardGrid(count: albums.length, item: (i) => _albumCard(albums[i]))],
      ),
    );
  }
}

// ======================= SEARCH =======================

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  Timer? _debounce;
  String _query = '';
  Future<List<Track>>? _future;

  @override
  void initState() {
    super.initState();
    app.addListener(_onApp);
    _onApp();
  }

  void _onApp() {
    if (app.searchQuery == _query) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _query = app.searchQuery;
        _future = _query.trim().isEmpty ? null : app.api!.search(_query.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    app.removeListener(_onApp);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_rounded, size: 64, color: C.dim),
          SizedBox(height: 12),
          Text('Что хочешь послушать?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text('Пиши в строке поиска сверху', style: TextStyle(color: C.sub)),
        ]),
      );
    }
    return FutureBuilder<List<Track>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('${snap.error}', style: const TextStyle(color: C.sub)));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5));
        }
        final tracks = snap.data!;
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
              child: Text('Треки по запросу «$_query»',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
          ),
          TrackSliver(tracks: tracks, source: 'search:$_query'),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ]);
      },
    );
  }
}

// ======================= МОЯ ВОЛНА =======================

class WavePage extends StatefulWidget {
  const WavePage({super.key});
  @override
  State<WavePage> createState() => _WavePageState();
}

class _WavePageState extends State<WavePage> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  static const moods = {'all': 'Любое', 'active': 'Бодрое', 'fun': 'Весёлое', 'calm': 'Спокойное', 'sad': 'Грустное'};
  static const diversity = {
    'default': 'По умолчанию',
    'favorite': 'Любимое',
    'discover': 'Незнакомое',
    'popular': 'Популярное'
  };
  static const langs = {'any': 'Любой', 'russian': 'Русский', 'not-russian': 'Иностранный'};

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Widget _chips(String label, Map<String, String> options, String value, void Function(String) onPick) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: C.sub, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in options.entries)
            GlassButton(
              active: e.key == value,
              onTap: () => setState(() => onPick(e.key)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(e.value),
            ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = app.waveSettings;
    return ListenableBuilder(
      listenable: app.player,
      builder: (context, _) {
        final p = app.player;
        final onWave = p.source == 'wave' && p.current != null;
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2E2E2E), C.panel],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 20),
              child: Column(children: [
                SizedBox(
                  height: 240,
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => CustomPaint(
                      size: const Size(240, 240),
                      painter: _WavePainter(_anim.value, active: onWave && p.playing),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Моя волна', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
                const SizedBox(height: 6),
                const Text('Бесконечный поток под твой вкус', style: TextStyle(color: C.sub)),
                const SizedBox(height: 20),
                GlassButton(
                  active: true,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  iconSize: 26,
                  onTap: onWave ? p.toggle : app.startWave,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(onWave && p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    const SizedBox(width: 8),
                    Text(onWave ? (p.playing ? 'Пауза' : 'Продолжить') : 'Запустить волну',
                        style: const TextStyle(fontSize: 16)),
                  ]),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Настроить волну', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                _chips('Настроение', moods, s.mood, (v) => s.mood = v),
                _chips('Характер', diversity, s.diversity, (v) => s.diversity = v),
                _chips('Язык', langs, s.language, (v) => s.language = v),
                GlassButton(
                  onTap: app.startWave,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('Применить и перезапустить'),
                  ]),
                ),
              ]),
            ),
          ),
          if (onWave) ...[
            const SliverToBoxAdapter(child: SectionTitle('Сейчас в волне')),
            TrackSliver(tracks: p.queue, source: 'wave'),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ]);
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  final bool active;
  _WavePainter(this.t, {required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.shortestSide * 0.28;
    for (var ring = 0; ring < 4; ring++) {
      final path = Path();
      final amp = (active ? 10.0 : 4.0) * (1 + ring * 0.4);
      final r = base + ring * 18;
      for (var i = 0; i <= 120; i++) {
        final a = i / 120 * 2 * math.pi;
        final wobble = math.sin(a * (3 + ring) + t * 2 * math.pi * (ring.isEven ? 1 : -1)) * amp;
        final p = c + Offset(math.cos(a), math.sin(a)) * (r + wobble);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.85 - ring * 0.18),
      );
    }
    canvas.drawCircle(
      c,
      base * 0.55,
      Paint()
        ..shader = const RadialGradient(colors: [Colors.white, Color(0x00FFFFFF)])
            .createShader(Rect.fromCircle(center: c, radius: base * 0.55)),
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t || old.active != active;
}
