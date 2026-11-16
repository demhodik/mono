import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../state/player.dart';
import 'lyrics.dart';
import 'pages/pages.dart';
import 'theme.dart';
import 'widgets/background.dart';
import 'widgets/common.dart';
import 'widgets/glass.dart';
import 'widgets/motion.dart';
import 'widgets/vinyl.dart';

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LiquidBackground(
        child: Stack(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.fromLTRB(14, 14, 0, 14), child: Dock()),
            Expanded(
              child: Column(children: [
                const TopBar(),
                Expanded(
                  child: ListenableBuilder(
                    listenable: app,
                    builder: (context, _) {
                      final r = app.route;
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(anim), child: child),
                        ),
                        child: KeyedSubtree(key: ObjectKey(r), child: _page(r)),
                      );
                    },
                  ),
                ),
              ]),
            ),
          ]),
          const Positioned(left: 100, right: 14, bottom: 16, child: Center(child: PlayerIsland())),
          ListenableBuilder(
            listenable: app,
            builder: (context, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 520),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: app.nowPlaying && app.player.current != null
                  ? const NowPlayingView(key: ValueKey('np'))
                  : const SizedBox.shrink(key: ValueKey('none')),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _page(AppRoute r) {
    switch (r.kind) {
      case PageKind.home:
        return const HomePage();
      case PageKind.search:
        return const SearchPage();
      case PageKind.library:
        return const LibraryPage();
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

// ======================= DOCK =======================

class Dock extends StatelessWidget {
  const Dock({super.key});

  static const items = <(PageKind, IconData, String)>[
    (PageKind.home, Icons.home_rounded, 'Главная'),
    (PageKind.wave, Icons.waves_rounded, 'Моя волна'),
    (PageKind.search, Icons.search_rounded, 'Поиск'),
    (PageKind.library, Icons.library_music_rounded, 'Медиатека'),
    (PageKind.likes, Icons.favorite_rounded, 'Мне нравится'),
    (PageKind.releases, Icons.auto_awesome_rounded, 'Новинки'),
    (PageKind.chart, Icons.trending_up_rounded, 'Чарт'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      child: GlassPanel(
        radius: 37,
        opacity: 0.05,
        child: ListenableBuilder(
          listenable: app,
          builder: (context, _) {
            final kind = app.route.kind;
            var sel = items.indexWhere((e) => e.$1 == kind);
            if (kind == PageKind.playlist || kind == PageKind.album) sel = 3;
            const itemH = 58.0;
            return Column(children: [
              const SizedBox(height: 16),
              Tooltip(
                message: 'Mono',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/icon.png', width: 46, height: 46),
                ),
              ),
              const SizedBox(height: 18),
              Container(width: 28, height: 1, color: Colors.white.withValues(alpha: 0.12)),
              const SizedBox(height: 14),
              SizedBox(
                height: itemH * items.length,
                child: Stack(children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    top: sel < 0 ? -itemH : sel * itemH + 3,
                    left: 11,
                    child: AnimatedOpacity(
                      opacity: sel < 0 ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xF5FFFFFF), Color(0xD0CFCFCF)],
                          ),
                          boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.25), blurRadius: 22)],
                        ),
                      ),
                    ),
                  ),
                  Column(children: [
                    for (var i = 0; i < items.length; i++)
                      _DockItem(icon: items[i].$2, label: items[i].$3, active: i == sel, onTap: () => app.go(items[i].$1)),
                  ]),
                ]),
              ),
              const Spacer(),
              const _AccountButton(),
              const SizedBox(height: 16),
            ]);
          },
        ),
      ),
    );
  }
}

class _DockItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DockItem({required this.icon, required this.label, required this.active, required this.onTap});
  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            height: 58,
            width: 74,
            child: Center(
              child: AnimatedScale(
                scale: _hover && !widget.active ? 1.18 : 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(
                  widget.icon,
                  size: 24,
                  color: widget.active ? Colors.black : (_hover ? Colors.white : const Color(0xFF8E8E8E)),
                ),
              ),
            ),
          ),
        ),
      ),
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
      color: const Color(0xFF1C1C1C),
      offset: const Offset(70, -60),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      onSelected: (v) {
        if (v == 'logout') app.logout();
        if (v == 'refresh') app.refreshLibrary();
      },
      itemBuilder: (_) => [
        PopupMenuItem(enabled: false, child: Text(name, style: const TextStyle(color: C.sub))),
        const PopupMenuItem(value: 'refresh', child: Text('Обновить медиатеку')),
        const PopupMenuItem(value: 'logout', child: Text('Выйти')),
      ],
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [Colors.white, Color(0xFFBDBDBD)]),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
        ),
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    );
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
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return SizedBox(
      height: 72,
      child: Stack(children: [
        const Positioned.fill(child: DragToMoveArea(child: SizedBox.expand())),
        Padding(
          padding: const EdgeInsets.only(left: 24, top: 6),
          child: Row(children: [
            ListenableBuilder(
              listenable: app,
              builder: (context, _) => Row(children: [
                GlassButton.icon(Icons.chevron_left_rounded,
                    size: 24, pad: 7, tooltip: 'Назад', onTap: app.canBack ? app.back : null),
                const SizedBox(width: 8),
                GlassButton.icon(Icons.chevron_right_rounded,
                    size: 24, pad: 7, tooltip: 'Вперёд', onTap: app.canForward ? app.forward : null),
              ]),
            ),
            const SizedBox(width: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              width: focused ? 520 : 380,
              height: 46,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: focused ? 0.12 : 0.06),
                      border: Border.all(color: Colors.white.withValues(alpha: focused ? 0.4 : 0.14)),
                    ),
                    child: Row(children: [
                      const SizedBox(width: 16),
                      Icon(Icons.search_rounded, color: focused ? Colors.white : C.sub),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          focusNode: _focus,
                          style: const TextStyle(fontSize: 15),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Трек, артист, альбом…',
                            hintStyle: TextStyle(color: C.sub),
                            isDense: true,
                          ),
                          onTap: () => app.search(_search.text),
                          onChanged: (v) {
                            setState(() {});
                            app.search(v);
                          },
                          onSubmitted: app.search,
                        ),
                      ),
                      if (_search.text.isNotEmpty)
                        HoverIcon(Icons.close_rounded, size: 18, onTap: () {
                          _search.clear();
                          app.search('');
                          setState(() {});
                        }),
                      const SizedBox(width: 10),
                    ]),
                  ),
                ),
              ),
            ),
            const Spacer(),
            const _WindowButtons(),
          ]),
        ),
      ]),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(children: [
        _WinBtn(icon: Icons.remove_rounded, onTap: () => windowManager.minimize()),
        const SizedBox(width: 8),
        _WinBtn(
          icon: Icons.crop_square_rounded,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
        ),
        const SizedBox(width: 8),
        _WinBtn(icon: Icons.close_rounded, onTap: () => windowManager.close(), close: true),
      ]),
    );
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
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover
                ? (widget.close ? const Color(0xFFE5484D) : Colors.white.withValues(alpha: 0.16))
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(widget.icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

// ======================= PLAYER ISLAND =======================

class PlayerIsland extends StatelessWidget {
  const PlayerIsland({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.player]),
      builder: (context, _) {
        final p = app.player;
        final t = p.current;
        final has = t != null;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutBack,
          width: has ? 940 : 340,
          height: 80,
          child: GlassPanel(
            radius: 40,
            opacity: 0.09,
            blur: 24,
            child: Stack(children: [
              if (!has)
                const Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.graphic_eq_rounded, color: C.sub, size: 20),
                    SizedBox(width: 10),
                    Text('Выбери, что послушать', style: TextStyle(color: C.sub)),
                  ]),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 18, 0),
                  child: Row(children: [
                    Expanded(
                      flex: 5,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => app.setNowPlaying(true),
                          child: Row(children: [
                            Vinyl(cover: t.coverOf(200), size: 58, spinning: p.playing),
                            const SizedBox(width: 12),
                            Flexible(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (c, a) => FadeTransition(
                                  opacity: a,
                                  child: SlideTransition(
                                    position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
                                    child: c,
                                  ),
                                ),
                                child: Column(
                                  key: ValueKey(t.id),
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
                                  ],
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                    HoverIcon(p.repeat == Repeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                        active: p.repeat != Repeat.off, onTap: p.cycleRepeat, tooltip: 'Повтор'),
                    const SizedBox(width: 10),
                    HoverIcon(Icons.shuffle_rounded, active: p.shuffle, onTap: p.toggleShuffle, tooltip: 'Перемешать'),
                    const SizedBox(width: 6),
                    GlassButton.icon(Icons.skip_previous_rounded, size: 22, pad: 8, onTap: p.previous),
                    const SizedBox(width: 10),
                    p.loading
                        ? const SizedBox(width: 50, height: 50, child: Center(child: GlassSpinner(size: 26)))
                        : GlassButton.icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 28, pad: 11, active: true, onTap: p.toggle),
                    const SizedBox(width: 10),
                    GlassButton.icon(Icons.skip_next_rounded, size: 22, pad: 8, onTap: p.next),
                    const SizedBox(width: 6),
                    HoverIcon(app.isLiked(t) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        active: app.isLiked(t), onTap: () => app.toggleLike(t), tooltip: 'Мне нравится'),
                    const SizedBox(width: 14),
                    HoverIcon(
                      p.volume == 0
                          ? Icons.volume_off_rounded
                          : (p.volume < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                      onTap: p.toggleMute,
                    ),
                    SizedBox(
                      width: 96,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(trackHeight: 3),
                        child: Slider(value: p.volume, min: 0, max: 100, onChanged: p.setVolume),
                      ),
                    ),
                    HoverIcon(Icons.lyrics_rounded, size: 20, tooltip: 'Текст', onTap: () {
                      app.setLyricsTab(true);
                      app.setNowPlaying(true);
                    }),
                    HoverIcon(Icons.subtitles_rounded,
                        size: 20, tooltip: 'Текст поверх игр (Ctrl+Shift+L)', onTap: app.overlay.enter),
                    HoverIcon(Icons.open_in_full_rounded,
                        size: 18, onTap: () => app.setNowPlaying(true), tooltip: 'Развернуть'),
                  ]),
                ),
              if (has) const Positioned(left: 40, right: 40, bottom: 0, child: _IslandProgress()),
            ]),
          ),
        );
      },
    );
  }
}

class _IslandProgress extends StatelessWidget {
  const _IslandProgress();

  @override
  Widget build(BuildContext context) {
    final p = app.player;
    return LayoutBuilder(builder: (context, c) {
      void seekTo(double x) {
        final d = p.duration.value;
        if (d == Duration.zero) return;
        p.seek(d * (x / c.maxWidth).clamp(0.0, 1.0));
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (e) => seekTo(e.localPosition.dx),
        onHorizontalDragUpdate: (e) => seekTo(e.localPosition.dx),
        child: SizedBox(
          height: 10,
          child: ValueListenableBuilder<Duration>(
            valueListenable: p.position,
            builder: (context, pos, _) {
              final d = p.duration.value.inMilliseconds;
              final f = d == 0 ? 0.0 : (pos.inMilliseconds / d).clamp(0.0, 1.0);
              return Align(
                alignment: Alignment.bottomLeft,
                child: Stack(children: [
                  Container(height: 2, color: Colors.white.withValues(alpha: 0.12)),
                  Container(
                    height: 2,
                    width: c.maxWidth * f,
                    decoration: BoxDecoration(color: Colors.white, boxShadow: [
                      BoxShadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 8),
                    ]),
                  ),
                ]),
              );
            },
          ),
        ),
      );
    });
  }
}

// ======================= NOW PLAYING =======================

class NowPlayingView extends StatelessWidget {
  const NowPlayingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.player]),
      builder: (context, _) {
        final p = app.player;
        final t = p.current;
        if (t == null) return const SizedBox.shrink();
        final upNext = p.queue.skip(p.index + 1).take(30).toList();
        return Stack(fit: StackFit.expand, children: [
          ColoredBox(
            color: Colors.black,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child: ImageFiltered(
                key: ValueKey(t.id),
                imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    0.2126, 0.7152, 0.0722, 0, 0, //
                    0.2126, 0.7152, 0.0722, 0, 0, //
                    0.2126, 0.7152, 0.0722, 0, 0, //
                    0, 0, 0, 0.55, 0,
                  ]),
                  child: t.cover == null
                      ? const SizedBox()
                      : Image.network(t.coverOf(400), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
                ),
              ),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.35)),
          const Positioned(left: 0, right: 0, top: 0, height: 60, child: DragToMoveArea(child: SizedBox.expand())),
          Positioned(
            top: 18,
            left: 24,
            child: GlassButton.icon(Icons.keyboard_arrow_down_rounded,
                size: 28, pad: 8, tooltip: 'Свернуть', onTap: () => app.setNowPlaying(false)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(70, 70, 70, 40),
            child: Row(children: [
              Expanded(
                flex: 5,
                child: Center(
                  child: Tilt3D(
                    maxAngle: 0.35,
                    radius: 999,
                    glare: false,
                    child: Stack(alignment: Alignment.center, children: [
                      Container(
                        width: 440,
                        height: 440,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            Colors.white.withValues(alpha: p.playing ? 0.14 : 0.06),
                            Colors.white.withValues(alpha: 0),
                          ]),
                        ),
                      ),
                      Vinyl(cover: t.coverOf(400), size: 380, spinning: p.playing),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 40),
              Expanded(
                flex: 6,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('СЕЙЧАС ИГРАЕТ',
                      style: TextStyle(fontSize: 11, letterSpacing: 3, color: C.sub, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Column(
                      key: ValueKey(t.id),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Unbounded', fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.1)),
                        const SizedBox(height: 8),
                        Text(t.artists, style: const TextStyle(fontSize: 17, color: C.sub)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _BigProgress(),
                  const SizedBox(height: 10),
                  Row(children: [
                    HoverIcon(Icons.shuffle_rounded, size: 24, active: p.shuffle, onTap: p.toggleShuffle),
                    const SizedBox(width: 14),
                    GlassButton.icon(Icons.skip_previous_rounded, size: 28, pad: 11, onTap: p.previous),
                    const SizedBox(width: 14),
                    GlassButton.icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 36, pad: 16, active: true, onTap: p.toggle),
                    const SizedBox(width: 14),
                    GlassButton.icon(Icons.skip_next_rounded, size: 28, pad: 11, onTap: p.next),
                    const SizedBox(width: 14),
                    HoverIcon(p.repeat == Repeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                        size: 24, active: p.repeat != Repeat.off, onTap: p.cycleRepeat),
                    const Spacer(),
                    GlassButton.icon(app.isLiked(t) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 22, pad: 11, onTap: () => app.toggleLike(t)),
                  ]),
                  const SizedBox(height: 22),
                  Row(children: [
                    GlassButton(
                      active: app.lyricsTab,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      onTap: () => app.setLyricsTab(true),
                      child: const Text('Текст'),
                    ),
                    const SizedBox(width: 8),
                    GlassButton(
                      active: !app.lyricsTab,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      onTap: () => app.setLyricsTab(false),
                      child: const Text('Далее'),
                    ),
                    const Spacer(),
                    if (app.lyricsTab) ...[const LyricsSyncControl(), const SizedBox(width: 12)],
                    GlassButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      tooltip: 'Прозрачный текст поверх игры. Выход: Ctrl+Shift+L',
                      onTap: app.overlay.enter,
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.subtitles_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Поверх игры'),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: app.lyricsTab
                          ? LyricsView(key: ValueKey('ly${t.id}'), track: t)
                          : ListView(key: const ValueKey('queue'), children: [
                              for (var i = 0; i < upNext.length; i++)
                                FadeSlideIn.index(
                                  i,
                                  key: ValueKey('${upNext[i].id}$i'),
                                  child: _UpNextRow(track: upNext[i], index: p.index + 1 + i),
                                ),
                            ]),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]);
      },
    );
  }
}

class _UpNextRow extends StatefulWidget {
  final Track track;
  final int index;
  const _UpNextRow({required this.track, required this.index});
  @override
  State<_UpNextRow> createState() => _UpNextRowState();
}

class _UpNextRowState extends State<_UpNextRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => app.player.playAt(widget.index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _hover ? 0.08 : 0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Cover(t.coverOf(100), size: 38, radius: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${t.title} — ${t.artists}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
            ),
            Text(fmt(t.duration), style: const TextStyle(color: C.sub, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class _BigProgress extends StatefulWidget {
  const _BigProgress();
  @override
  State<_BigProgress> createState() => _BigProgressState();
}

class _BigProgressState extends State<_BigProgress> {
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
          return Column(children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: value,
                max: max,
                onChanged: (v) => setState(() => _drag = v),
                onChangeEnd: (v) {
                  p.seek(Duration(milliseconds: v.toInt()));
                  setState(() => _drag = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                Text(fmt(Duration(milliseconds: value.toInt())), style: const TextStyle(color: C.sub, fontSize: 12)),
                const Spacer(),
                Text(fmt(dur), style: const TextStyle(color: C.sub, fontSize: 12)),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
