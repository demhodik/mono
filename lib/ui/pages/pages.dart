import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/background.dart';
import '../widgets/common.dart';
import '../widgets/coverflow.dart';
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
    return SmoothScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: FadeSlideIn(child: VibeBox(greeting: '$_greeting${api.displayName != null ? ', ${api.displayName}' : ''}')),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 34, 32, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: const FadeSlideIn(delay: Duration(milliseconds: 150), child: WaveSection()),
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 140)),
    ]);
  }
}

/// The main thing on the home screen: describe a vibe -> music starts.
class VibeBox extends StatefulWidget {
  final String greeting;
  const VibeBox({super.key, required this.greeting});
  @override
  State<VibeBox> createState() => _VibeBoxState();
}

class _VibeBoxState extends State<VibeBox> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _hint = 0;

  static const _examples = [
    'вайбовые песни для игры ночью',
    'спокойный фокус для учёбы',
    'жёсткий фонк в машину',
    'грустное под дождь',
    'энергичное для тренировки',
    'чилл на русском',
  ];
  static const _chips = ['Ночная игра', 'Фокус', 'Тренировка', 'В дорогу', 'Под дождь', 'Вечеринка'];

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _timer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (mounted && _ctrl.text.isEmpty) setState(() => _hint = (_hint + 1) % _examples.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _go([String? text]) {
    final t = text ?? _ctrl.text;
    if (text != null) _ctrl.text = text;
    app.vibe(t);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.player]),
      builder: (context, _) {
        final p = app.player;
        final playingVibe = p.source == 'vibe' && p.current != null;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.greeting, style: const TextStyle(color: C.sub, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          const Text('Какой сегодня вайб?',
              style: TextStyle(fontFamily: 'Unbounded', fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1, height: 1.1)),
          const SizedBox(height: 26),
          // input capsule
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(38),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: focused ? 0.13 : 0.08),
                  Colors.white.withValues(alpha: focused ? 0.06 : 0.03),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: focused ? 0.45 : 0.16)),
              boxShadow: [
                BoxShadow(color: Colors.white.withValues(alpha: focused ? 0.10 : 0.0), blurRadius: 50, spreadRadius: 2),
                BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 14)),
              ],
            ),
            padding: const EdgeInsets.only(left: 26, right: 10),
            child: Row(children: [
              Icon(Icons.auto_awesome_rounded, color: focused ? Colors.white : C.sub),
              const SizedBox(width: 16),
              Expanded(
                child: Stack(alignment: Alignment.centerLeft, children: [
                  if (_ctrl.text.isEmpty)
                    IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(a),
                            child: c,
                          ),
                        ),
                        child: Text('например, ${_examples[_hint]}',
                            key: ValueKey(_hint), style: const TextStyle(color: C.dim, fontSize: 18)),
                      ),
                    ),
                  TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _go(),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              app.vibeBusy
                  ? const Padding(padding: EdgeInsets.all(14), child: GlassSpinner(size: 28))
                  : GlassButton(
                      active: true,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                      onTap: () => _go(),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Подобрать', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ]),
                    ),
            ]),
          ),
          const SizedBox(height: 18),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in _chips)
              GlassButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                onTap: () => _go(c),
                child: Text(c),
              ),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: playingVibe && app.vibeText.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: Row(children: [
                      EqBars(playing: p.playing, size: 16),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text('Играет подбор «${app.vibeText}»',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      for (final t in app.vibeTags.take(4))
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Text(t, style: const TextStyle(fontSize: 12, color: C.sub)),
                        ),
                    ]),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]);
      },
    );
  }
}

/// "Моя волна" on the home screen: a living orb + controls, no card.
class WaveSection extends StatelessWidget {
  const WaveSection({super.key});

  static const _moods = {'all': 'Любое', 'active': 'Бодрое', 'fun': 'Весёлое', 'calm': 'Спокойное', 'sad': 'Грустное'};

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.player]),
      builder: (context, _) {
        final p = app.player;
        final onWave = p.source == 'wave' && p.current != null;
        final playing = onWave && p.playing;
        return Row(children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onWave ? p.toggle : app.startWave,
              child: Stack(alignment: Alignment.center, children: [
                WaveOrb(size: 330, active: playing),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    key: ValueKey(playing),
                    size: 54,
                    color: Colors.black.withValues(alpha: 0.85),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 30),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('МОЯ ВОЛНА',
                  style: TextStyle(fontSize: 12, letterSpacing: 3, color: C.sub, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: onWave
                    ? Column(
                        key: ValueKey(p.current!.id),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.current!.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Unbounded', fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
                          const SizedBox(height: 6),
                          Text(p.current!.artists, style: const TextStyle(color: C.sub, fontSize: 16)),
                        ],
                      )
                    : const Text('Бесконечный поток\nпод твой вкус',
                        key: ValueKey('idle'),
                        style: TextStyle(fontFamily: 'Unbounded', fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.15)),
              ),
              const SizedBox(height: 22),
              Row(children: [
                GlassButton(
                  active: true,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  iconSize: 24,
                  onTap: onWave ? p.toggle : app.startWave,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    const SizedBox(width: 8),
                    Text(onWave ? (playing ? 'Пауза' : 'Продолжить') : 'Слушать'),
                  ]),
                ),
                if (onWave) ...[
                  const SizedBox(width: 10),
                  GlassButton.icon(Icons.skip_next_rounded, size: 22, pad: 12, tooltip: 'Дальше', onTap: p.next),
                ],
              ]),
              const SizedBox(height: 22),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in _moods.entries)
                  GlassButton(
                    active: app.waveSettings.mood == e.key,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    onTap: () {
                      app.waveSettings.mood = e.key;
                      app.startWave();
                    },
                    child: Text(e.value, style: const TextStyle(fontSize: 13)),
                  ),
              ]),
            ]),
          ),
        ]);
      },
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
      builder: (context, _) => SmoothScrollView(slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(32, 18, 32, 8),
            child: FadeSlideIn(
              child: Text('Медиатека', style: TextStyle(fontFamily: 'Unbounded', fontSize: 34.0, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
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
      builder: (context, albums) => SmoothScrollView(slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(32, 18, 32, 4),
            child: FadeSlideIn(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Новинки', style: TextStyle(fontFamily: 'Unbounded', fontSize: 34.0, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
                SizedBox(height: 4),
                Text('Свежие релизы подтягиваются сами', style: TextStyle(color: C.sub)),
              ]),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 300 + 300 * 0.32 + 80,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
              child: CoverFlow(
                cardSize: 300,
                items: [
                  for (final a in albums.take(20)) CoverFlowItem(image: a.coverOf(400), title: a.title, subtitle: a.artists),
                ],
                onOpen: (i) => app.go(PageKind.album, albums[i]),
                onPlay: (i) async {
                  try {
                    final t = await app.api!.albumTracks(albums[i].id);
                    app.player.playList(t, 0, source: 'album:${albums[i].id}');
                  } catch (e) {
                    app.toast('$e');
                  }
                },
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SectionTitle('Все новинки')),
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
            Text('Найди что угодно', style: TextStyle(fontFamily: 'Unbounded', fontSize: 22.2, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
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
        return SmoothScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 18, 32, 12),
              child: Text('«$_query»', style: const TextStyle(fontFamily: 'Unbounded', fontSize: 25.2, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
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
        return SmoothScrollView(slivers: [
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
                  const Text('Моя волна', style: TextStyle(fontFamily: 'Unbounded', fontSize: 41.4, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
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
