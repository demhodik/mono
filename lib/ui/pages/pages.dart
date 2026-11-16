import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/background.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 18, 32, 0),
          child: FadeSlideIn(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_greeting${api.displayName != null ? ', ${api.displayName}' : ''}',
                  style: const TextStyle(fontSize: 15, color: C.sub, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              const Text('Что включим?',
                  style: TextStyle(fontSize: 46, fontWeight: FontWeight.w800, letterSpacing: -1.8, height: 1.1)),
            ]),
          ),
        ),
      ),
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(32, 24, 32, 0),
          child: FadeSlideIn(delay: Duration(milliseconds: 120), child: WaveHero()),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 18, 32, 0),
          child: ListenableBuilder(
            listenable: app,
            builder: (context, _) {
              final tiles = <Widget>[
                _QuickTile(title: 'Мне нравится', icon: Icons.favorite_rounded, onTap: () => app.go(PageKind.likes)),
                _QuickTile(title: 'Чарт', icon: Icons.trending_up_rounded, onTap: () => app.go(PageKind.chart)),
                _QuickTile(title: 'Новинки', icon: Icons.auto_awesome_rounded, onTap: () => app.go(PageKind.releases)),
                for (final p in app.playlists.take(5))
                  _QuickTile(
                    title: p.title,
                    image: p.coverOf(100),
                    icon: Icons.queue_music_rounded,
                    onTap: () => app.go(PageKind.playlist, p),
                  ),
              ];
              return LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 1100 ? 4 : (c.maxWidth > 700 ? 3 : 2);
                final w = (c.maxWidth - (cols - 1) * 12) / cols;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  for (var i = 0; i < tiles.length; i++)
                    SizedBox(width: w, child: FadeSlideIn.index(i + 3, child: tiles[i])),
                ]);
              });
            },
          ),
        ),
      ),
      SliverToBoxAdapter(child: SectionTitle('Новые релизы', onMore: () => app.go(PageKind.releases))),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 300,
          child: Loader<List<Album>>(
            load: api.newReleases,
            builder: (context, albums) => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: math.min(albums.length, 24),
              itemBuilder: (_, i) => SizedBox(width: 210, child: FadeSlideIn.index(i, child: _albumCard(albums[i]))),
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
      const SliverToBoxAdapter(child: SizedBox(height: 140)),
    ]);
  }
}

/// Big glass card for "Моя волна" with the orbit animation.
class WaveHero extends StatelessWidget {
  const WaveHero({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: GlassPanel(
        radius: 30,
        child: ListenableBuilder(
          listenable: app.player,
          builder: (context, _) {
            final p = app.player;
            final onWave = p.source == 'wave' && p.current != null;
            return Stack(children: [
              Positioned(
                right: -40,
                top: -10,
                bottom: -10,
                width: 520,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        Colors.white.withValues(alpha: onWave && p.playing ? 0.22 : 0.12),
                        Colors.white.withValues(alpha: 0),
                      ]),
                    ),
                  ),
                  const Orbit(width: 460, height: 230),
                  Transform.rotate(
                    angle: -0.32,
                    child: const Orbit(width: 300, height: 150, period: Duration(milliseconds: 2600)),
                  ),
                  EqBars(playing: onWave && p.playing, size: 46),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ПЕРСОНАЛЬНЫЙ ПОТОК',
                      style: TextStyle(fontSize: 11, letterSpacing: 3, color: C.sub, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Моя волна', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1.5)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 360,
                    child: Text(
                      onWave && p.current != null
                          ? 'Сейчас: ${p.current!.title} — ${p.current!.artists}'
                          : 'Бесконечная музыка под тебя. Подстраивается под каждый лайк и пропуск.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: C.sub, height: 1.4),
                    ),
                  ),
                  const Spacer(),
                  Row(children: [
                    GlassButton(
                      active: true,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                      iconSize: 24,
                      onTap: onWave ? p.toggle : app.startWave,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(onWave && p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        const SizedBox(width: 8),
                        Text(onWave ? (p.playing ? 'Пауза' : 'Продолжить') : 'Запустить'),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    GlassButton(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      onTap: () => app.go(PageKind.wave),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.tune_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Настроить'),
                      ]),
                    ),
                  ]),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _QuickTile extends StatefulWidget {
  final String title;
  final IconData icon;
  final String image;
  final VoidCallback onTap;
  const _QuickTile({required this.title, required this.icon, required this.onTap, this.image = ''});

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
          duration: const Duration(milliseconds: 200),
          height: 64,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _hover ? 0.11 : 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: _hover ? 0.22 : 0.09)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: _hover ? 0.5 : 0.2), blurRadius: _hover ? 24 : 10),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            widget.image.isNotEmpty
                ? Cover(widget.image, size: 48, radius: 12)
                : IconArt(icon: widget.icon, size: 48, radius: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Text(widget.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            AnimatedOpacity(
              opacity: _hover ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.arrow_forward_rounded, size: 18),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ======================= TRACK LIST PAGES =======================

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
    this.icon = Icons.music_note_rounded,
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
            image: image.isNotEmpty ? image : (tracks.isNotEmpty ? tracks.first.coverOf(400) : ''),
            icon: icon,
            source: source,
            subtitle: subtitle?.call(tracks) ?? '${plural(tracks.length, 'трек', 'трека', 'треков')} · ${fmt(total)}',
          ),
          slivers: [
            SliverToBoxAdapter(child: PlayActions(tracks: tracks, source: source)),
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
        overline: 'Коллекция',
        title: 'Мне нравится',
        icon: Icons.favorite_rounded,
        subtitle: (t) => plural(t.length, 'трек', 'трека', 'треков'),
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

// ======================= LIBRARY =======================

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => CustomScrollView(slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(32, 18, 32, 8),
            child: FadeSlideIn(
              child: Text('Медиатека', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w800, letterSpacing: -1.8)),
            ),
          ),
        ),
        CardGrid(
          count: app.playlists.length + 1,
          item: (i) {
            if (i == 0) {
              return MediaCard(
                image: '',
                fallback: Icons.favorite_rounded,
                title: 'Мне нравится',
                subtitle: plural(app.likedIds.length, 'трек', 'трека', 'треков'),
                onOpen: () => app.go(PageKind.likes),
              );
            }
            final p = app.playlists[i - 1];
            return MediaCard(
              image: p.coverOf(300),
              fallback: Icons.queue_music_rounded,
              title: p.title,
              subtitle: plural(p.trackCount, 'трек', 'трека', 'треков'),
              onOpen: () => app.go(PageKind.playlist, p),
              onPlay: () async {
                try {
                  final t = await app.api!.playlistTracks(p);
                  app.player.playList(t, 0, source: 'playlist:${p.kind}');
                } catch (e) {
                  app.toast('$e');
                }
              },
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ]),
    );
  }
}

// ======================= NEW RELEASES =======================

class ReleasesPage extends StatelessWidget {
  const ReleasesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Loader<List<Album>>(
      load: app.api!.newReleases,
      builder: (context, albums) => CustomScrollView(slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(32, 18, 32, 4),
            child: FadeSlideIn(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Новинки', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w800, letterSpacing: -1.8)),
                SizedBox(height: 4),
                Text('Свежие релизы подтягиваются сами', style: TextStyle(color: C.sub)),
              ]),
            ),
          ),
        ),
        CardGrid(count: albums.length, item: (i) => _albumCard(albums[i])),
        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ]),
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
        child: FadeSlideIn(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Orbit(width: 260, height: 130),
            SizedBox(height: 12),
            Text('Найди что угодно', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1)),
            SizedBox(height: 6),
            Text('Пиши в строке поиска сверху', style: TextStyle(color: C.sub)),
          ]),
        ),
      );
    }
    return FutureBuilder<List<Track>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}', style: const TextStyle(color: C.sub)));
        if (!snap.hasData) return const Center(child: GlassSpinner());
        final tracks = snap.data!;
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 18, 32, 12),
              child: Text('«$_query»', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1)),
            ),
          ),
          TrackSliver(key: ValueKey(_query), tracks: tracks, source: 'search:$_query'),
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
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

class _WavePageState extends State<WavePage> {
  static const moods = {'all': 'Любое', 'active': 'Бодрое', 'fun': 'Весёлое', 'calm': 'Спокойное', 'sad': 'Грустное'};
  static const diversity = {
    'default': 'По умолчанию',
    'favorite': 'Любимое',
    'discover': 'Незнакомое',
    'popular': 'Популярное',
  };
  static const langs = {'any': 'Любой', 'russian': 'Русский', 'not-russian': 'Иностранный'};

  Widget _chips(String label, Map<String, String> options, String value, void Function(String) onPick, int i) {
    return FadeSlideIn.index(i + 2,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
                style: const TextStyle(color: C.sub, fontSize: 11, letterSpacing: 2.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in options.entries)
                GlassButton(
                  active: e.key == value,
                  onTap: () => setState(() => onPick(e.key)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  child: Text(e.value),
                ),
            ]),
          ]),
        ));
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
            child: SizedBox(
              height: 310,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Colors.white.withValues(alpha: onWave && p.playing ? 0.18 : 0.08),
                      Colors.white.withValues(alpha: 0),
                    ]),
                  ),
                ),
                const Orbit(width: 620, height: 300, period: Duration(seconds: 5)),
                Transform.rotate(angle: 0.6, child: const Orbit(width: 420, height: 200, period: Duration(seconds: 3))),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Моя волна', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800, letterSpacing: -2)),
                  const SizedBox(height: 14),
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
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
              child: GlassPanel(
                radius: 28,
                padding: const EdgeInsets.fromLTRB(28, 26, 28, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _chips('Настроение', moods, s.mood, (v) => s.mood = v, 0),
                  _chips('Характер', diversity, s.diversity, (v) => s.diversity = v, 1),
                  _chips('Язык', langs, s.language, (v) => s.language = v, 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: GlassButton(
                      onTap: app.startWave,
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.refresh_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Применить и перезапустить'),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          if (onWave) ...[
            const SliverToBoxAdapter(child: SectionTitle('Сейчас в волне')),
            TrackSliver(tracks: p.queue, source: 'wave'),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ]);
      },
    );
  }
}
