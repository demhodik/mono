import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../state/player.dart';
import 'pages/pages.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/glass.dart';

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        const TopBar(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(width: 300, child: Sidebar()),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColoredBox(
                    color: C.panel,
                    child: ListenableBuilder(
                      listenable: app,
                      builder: (context, _) {
                        final r = app.route;
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: KeyedSubtree(key: ObjectKey(r), child: _page(r)),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const PlayerBar(),
      ]),
    );
  }

  Widget _page(AppRoute r) {
    switch (r.kind) {
      case PageKind.home:
        return const HomePage();
      case PageKind.search:
        return const SearchPage();
      case PageKind.likes:
        return const LikesPage();
      case PageKind.wave:
        return const WavePage();
      case PageKind.chart:
        return const ChartPage();
      case PageKind.releases:
        return const ReleasesPage();
      case PageKind.album:
        return AlbumPage(r.arg as Album);
      case PageKind.playlist:
        return PlaylistPage(r.arg as Playlist);
    }
  }
}

// ======================= TOP BAR =======================

class TopBar extends StatefulWidget {
  const TopBar({super.key});
  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(children: [
        const Positioned.fill(child: DragToMoveArea(child: SizedBox.expand())),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(children: [
            const _Logo(),
            const SizedBox(width: 20),
            ListenableBuilder(
              listenable: app,
              builder: (context, _) => Row(children: [
                GlassButton.icon(Icons.chevron_left_rounded, size: 22, pad: 6, tooltip: 'Назад', onTap: app.canBack ? app.back : null),
                const SizedBox(width: 8),
                GlassButton.icon(Icons.chevron_right_rounded,
                    size: 22, pad: 6, tooltip: 'Вперёд', onTap: app.canForward ? app.forward : null),
              ]),
            ),
            const Spacer(),
            ListenableBuilder(
              listenable: app,
              builder: (context, _) => GlassButton.icon(
                app.route.kind == PageKind.home ? Icons.home_rounded : Icons.home_outlined,
                size: 24,
                pad: 10,
                tooltip: 'Главная',
                onTap: () => app.go(PageKind.home),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 440, child: _searchField()),
            const Spacer(),
            const _AccountButton(),
            const SizedBox(width: 12),
            const _WindowButtons(),
          ]),
        ),
      ]),
    );
  }

  Widget _searchField() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        const Icon(Icons.search_rounded, color: C.sub),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _search,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Что хочешь включить?',
              hintStyle: TextStyle(color: C.sub),
              isDense: true,
            ),
            onTap: () => app.search(_search.text),
            onChanged: app.search,
            onSubmitted: app.search,
          ),
        ),
        if (_search.text.isNotEmpty)
          HoverIcon(Icons.close_rounded, onTap: () {
            _search.clear();
            app.search('');
            setState(() {});
          }),
        const SizedBox(width: 8),
      ]),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: const Icon(Icons.graphic_eq_rounded, color: Colors.black, size: 20),
        ),
        const SizedBox(width: 10),
        const Text('Mono', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      ]),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton();
  @override
  Widget build(BuildContext context) {
    final name = app.api?.displayName ?? '?';
    return PopupMenuButton<String>(
      tooltip: name,
      color: C.hover,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (v) {
        if (v == 'logout') app.logout();
        if (v == 'refresh') app.refreshLibrary();
      },
      itemBuilder: (_) => [
        PopupMenuItem(enabled: false, child: Text(name, style: const TextStyle(color: C.sub))),
        const PopupMenuItem(value: 'refresh', child: Text('Обновить медиатеку')),
        const PopupMenuItem(value: 'logout', child: Text('Выйти')),
      ],
      child: GlassButton(
        padding: const EdgeInsets.all(4),
        child: CircleAvatar(
          radius: 15,
          backgroundColor: Colors.white,
          child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

  Widget _btn(IconData icon, VoidCallback onTap, {bool close = false}) {
    return _WinBtn(icon: icon, onTap: onTap, close: close);
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _btn(Icons.remove_rounded, () => windowManager.minimize()),
      _btn(Icons.crop_square_rounded, () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      }),
      _btn(Icons.close_rounded, () => windowManager.close(), close: true),
    ]);
  }
}

class _WinBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool close;
  const _WinBtn({required this.icon, required this.onTap, this.close = false});
  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 64,
          color: _hover ? (widget.close ? const Color(0xFFC42B1C) : C.hover) : Colors.transparent,
          child: Icon(widget.icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

// ======================= SIDEBAR =======================

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: C.panel,
        child: ListenableBuilder(
          listenable: app,
          builder: (context, _) {
            final r = app.route;
            bool sel(PageKind k, [Object? arg]) => r.kind == k && (arg == null || r.arg == arg);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(children: [
                  Icon(Icons.library_music_rounded, color: C.sub),
                  SizedBox(width: 12),
                  Text('Моя медиатека', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ]),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.symmetric(horizontal: 8), children: [
                  _LibTile(
                    title: 'Моя волна',
                    subtitle: 'Персональный поток',
                    icon: Icons.waves_rounded,
                    selected: sel(PageKind.wave),
                    onTap: () => app.go(PageKind.wave),
                  ),
                  _LibTile(
                    title: 'Мне нравится',
                    subtitle: 'Плейлист · ${plural(app.likedIds.length, 'трек', 'трека', 'треков')}',
                    icon: Icons.favorite_rounded,
                    selected: sel(PageKind.likes),
                    onTap: () => app.go(PageKind.likes),
                  ),
                  _LibTile(
                    title: 'Новинки',
                    subtitle: 'Свежие релизы',
                    icon: Icons.new_releases_rounded,
                    selected: sel(PageKind.releases),
                    onTap: () => app.go(PageKind.releases),
                  ),
                  _LibTile(
                    title: 'Чарт',
                    subtitle: 'Популярное сейчас',
                    icon: Icons.trending_up_rounded,
                    selected: sel(PageKind.chart),
                    onTap: () => app.go(PageKind.chart),
                  ),
                  for (final p in app.playlists)
                    _LibTile(
                      title: p.title,
                      subtitle: 'Плейлист · ${plural(p.trackCount, 'трек', 'трека', 'треков')}',
                      image: p.coverOf(100),
                      icon: Icons.queue_music_rounded,
                      selected: r.kind == PageKind.playlist && (r.arg as Playlist?)?.kind == p.kind,
                      onTap: () => app.go(PageKind.playlist, p),
                    ),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _LibTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String image;
  final bool selected;
  final VoidCallback onTap;
  const _LibTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.image = '',
  });

  @override
  State<_LibTile> createState() => _LibTileState();
}

class _LibTileState extends State<_LibTile> {
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
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.selected ? Colors.white.withValues(alpha: 0.1) : (_hover ? C.panelHi : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            widget.image.isNotEmpty
                ? Cover(widget.image, size: 48, radius: 4)
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Color(0xFF6B6B6B)],
                      ),
                    ),
                    child: Icon(widget.icon, color: Colors.black, size: 22),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(widget.subtitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.sub, fontSize: 13)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ======================= PLAYER BAR =======================

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListenableBuilder(
        listenable: Listenable.merge([app, app.player]),
        builder: (context, _) {
          final p = app.player;
          final t = p.current;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              // --- now playing ---
              Expanded(
                flex: 3,
                child: t == null
                    ? const SizedBox()
                    : Row(children: [
                        Cover(t.coverOf(200), size: 58, radius: 6),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                const SizedBox(height: 3),
                                Text(t.artists,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: C.sub, fontSize: 12)),
                              ]),
                        ),
                        const SizedBox(width: 10),
                        HoverIcon(app.isLiked(t) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            active: app.isLiked(t), onTap: () => app.toggleLike(t), tooltip: 'Мне нравится'),
                      ]),
              ),
              // --- controls ---
              Expanded(
                flex: 4,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    HoverIcon(Icons.shuffle_rounded,
                        active: p.shuffle, onTap: p.toggleShuffle, tooltip: 'Перемешать'),
                    const SizedBox(width: 10),
                    GlassButton.icon(Icons.skip_previous_rounded, size: 22, pad: 6, onTap: t == null ? null : p.previous),
                    const SizedBox(width: 12),
                    p.loading
                        ? const SizedBox(
                            width: 44,
                            height: 44,
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            ),
                          )
                        : GlassButton.icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 26, pad: 9, active: true, onTap: t == null ? null : p.toggle),
                    const SizedBox(width: 12),
                    GlassButton.icon(Icons.skip_next_rounded, size: 22, pad: 6, onTap: t == null ? null : p.next),
                    const SizedBox(width: 10),
                    HoverIcon(p.repeat == Repeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                        active: p.repeat != Repeat.off, onTap: p.cycleRepeat, tooltip: 'Повтор'),
                  ]),
                  const SizedBox(height: 6),
                  const _Progress(),
                ]),
              ),
              // --- volume ---
              Expanded(
                flex: 3,
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  HoverIcon(
                    p.volume == 0
                        ? Icons.volume_off_rounded
                        : (p.volume < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                    onTap: p.toggleMute,
                  ),
                  SizedBox(
                    width: 120,
                    child: Slider(value: p.volume, min: 0, max: 100, onChanged: p.setVolume),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _Progress extends StatefulWidget {
  const _Progress();
  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final p = app.player;
    return ValueListenableBuilder<Duration>(
      valueListenable: p.duration,
      builder: (context, dur, _) => ValueListenableBuilder<Duration>(
        valueListenable: p.position,
        builder: (context, pos, _) {
          final max = dur.inMilliseconds.toDouble().clamp(1, double.infinity).toDouble();
          final value = (_drag ?? pos.inMilliseconds.toDouble()).clamp(0, max).toDouble();
          return Row(children: [
            SizedBox(
              width: 44,
              child: Text(fmt(Duration(milliseconds: value.toInt())),
                  textAlign: TextAlign.right, style: const TextStyle(color: C.sub, fontSize: 12)),
            ),
            Expanded(
              child: Slider(
                value: value,
                max: max,
                onChanged: p.current == null ? null : (v) => setState(() => _drag = v),
                onChangeEnd: (v) {
                  p.seek(Duration(milliseconds: v.toInt()));
                  setState(() => _drag = null);
                },
              ),
            ),
            SizedBox(width: 44, child: Text(fmt(dur), style: const TextStyle(color: C.sub, fontSize: 12))),
          ]);
        },
      ),
    );
  }
}
