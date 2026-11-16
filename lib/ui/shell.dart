import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../state/player.dart';
import 'pages/pages.dart';
import 'theme.dart';
import 'widgets/background.dart';
import 'widgets/common.dart';
import 'widgets/glass.dart';
import 'widgets/motion.dart';

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        LiquidBackground(
          child: Column(children: [
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Entrance(from: Offset(-120, 0), child: Sidebar()),
                Expanded(
                  child: Column(children: [
                    const Entrance(from: Offset(0, -40), delayMs: 80, child: TopBar()),
                    Expanded(
                      child: Entrance(
                        from: const Offset(0, 40),
                        delayMs: 160,
                        child: ListenableBuilder(
                          listenable: app,
                          builder: (context, _) {
                            final r = app.route;
                            final dir = app.navDir.toDouble();
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 420),
                              reverseDuration: const Duration(milliseconds: 200),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, anim) {
                                final incoming = child.key == ObjectKey(r);
                                return FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: Offset(0, incoming ? 0.025 * dir : -0.025 * dir),
                                      end: Offset.zero,
                                    ).animate(anim),
                                    child: child,
                                  ),
                                );
                              },
                              child: KeyedSubtree(key: ObjectKey(r), child: RepaintBoundary(child: _page(r))),
                            );
                          },
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            const Entrance(from: Offset(0, 90), delayMs: 240, child: PlayerBar()),
          ]),
        ),
        // fullscreen "now playing" (cover · lyrics · queue)
        ListenableBuilder(
          listenable: app,
          builder: (context, _) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 520),
            reverseDuration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: app.nowPlaying && app.player.current != null
                ? const NowPlayingOverlay(key: ValueKey('np'))
                : const SizedBox.shrink(key: ValueKey('none')),
          ),
        ),
      ]),
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
      case PageKind.artist:
        return ArtistPage(r.arg as ArtistRef);
    }
  }
}

// ======================= SIDEBAR (tabs, like Yandex Music) =======================

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  static const main = <(PageKind, IconData, String)>[
    (PageKind.home, Icons.home_rounded, 'Главная'),
    (PageKind.search, Icons.search_rounded, 'Поиск'),
    (PageKind.releases, Icons.auto_awesome_rounded, 'Новинки'),
    (PageKind.chart, Icons.trending_up_rounded, 'Чарт'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final r = app.route;
          bool sel(PageKind k, [Object? arg]) => r.kind == k && (arg == null || r.arg == arg);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const DragToMoveArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 22, 16, 18),
                child: Row(children: [
                  _Logo(),
                  SizedBox(width: 10),
                  Text('Mono', style: TextStyle(fontFamily: 'Unbounded', fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                ]),
              ),
            ),
            for (final m in main)
              _SideTab(icon: m.$2, label: m.$3, active: sel(m.$1), onTap: () => app.go(m.$1)),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 16, 8),
              child: Text('КОЛЛЕКЦИЯ', style: TextStyle(fontSize: 11, letterSpacing: 2.5, color: C.dim, fontWeight: FontWeight.w700)),
            ),
            _SideTab(
                icon: Icons.favorite_rounded, label: 'Мне нравится', active: sel(PageKind.likes), onTap: () => app.go(PageKind.likes)),
            _SideTab(
                icon: Icons.library_music_rounded,
                label: 'Коллекция',
                active: sel(PageKind.library),
                onTap: () => app.go(PageKind.library)),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(padding: const EdgeInsets.only(bottom: 10), children: [
                for (final p in app.playlists)
                  _SideTab(
                    image: p.coverOf(80),
                    label: p.title,
                    active: r.kind == PageKind.playlist && r.arg == p,
                    onTap: () => app.go(PageKind.playlist, p),
                  ),
              ]),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 14), child: _AccountButton()),
          ]);
        },
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) =>
      ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.asset('assets/icon.png', width: 32, height: 32));
}

class _SideTab extends StatefulWidget {
  final IconData? icon;
  final String? image;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SideTab({this.icon, this.image, required this.label, required this.active, required this.onTap});
  @override
  State<_SideTab> createState() => _SideTabState();
}

class _SideTabState extends State<_SideTab> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: widget.image != null ? 6 : 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: a
                ? LinearGradient(colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.06)])
                : null,
            color: a ? null : Colors.white.withValues(alpha: _hover ? 0.06 : 0),
            border: Border.all(color: Colors.white.withValues(alpha: a ? 0.18 : 0)),
          ),
          child: Row(children: [
            if (widget.image != null)
              Cover(widget.image!, size: 32, radius: 8, fallback: Icons.queue_music_rounded)
            else
              AnimatedScale(
                scale: _hover && !a ? 1.12 : 1,
                duration: const Duration(milliseconds: 200),
                child: Icon(widget.icon, size: 21, color: a || _hover ? Colors.white : const Color(0xFF9A9A9A)),
              ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: a ? FontWeight.w800 : FontWeight.w600,
                    color: a || _hover ? Colors.white : const Color(0xFFBDBDBD),
                  )),
            ),
          ]),
        ),
      ),
    );
  }
}

// ======================= PLAYER BAR (full width, like Yandex) =======================

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.player]),
      builder: (context, _) {
        final p = app.player;
        final t = p.current;
        return Stack(children: [
          Container(
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withValues(alpha: 0.07), Colors.white.withValues(alpha: 0.03)],
            ),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(children: [
            // ---- track ----
            SizedBox(
              width: 330,
              child: t == null
                  ? const Text('Ничего не играет', style: TextStyle(color: C.sub))
                  : Row(children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => app.setNowPlaying(true),
                          child: Tooltip(
                            message: 'Открыть плеер',
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: Container(
                                key: ValueKey(t.id),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 6)),
                                ]),
                                child: Cover(t.coverOf(200), size: 56, radius: 10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Flexible(
                        child: GestureDetector(
                          onSecondaryTapUp: (d) => showTrackMenu(context, d.globalPosition, t),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 360),
                            transitionBuilder: (c, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(a),
                                child: c,
                              ),
                            ),
                            child: Column(
                              key: ValueKey(t.id),
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.title,
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                const SizedBox(height: 3),
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => app.openArtistOf(t),
                                    child: Text(t.artists,
                                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.sub, fontSize: 12.5)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      LikeButton(track: t, size: 20),
                    ]),
            ),
            // ---- controls + progress ----
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  HoverIcon(Icons.shuffle_rounded, size: 19, active: p.shuffle, onTap: p.toggleShuffle, tooltip: 'Перемешать'),
                  const SizedBox(width: 10),
                  GlassButton.icon(Icons.skip_previous_rounded, size: 20, pad: 7, onTap: t == null ? null : p.previous),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: p.loading
                            ? const GlassSpinner(key: ValueKey('l'), size: 22)
                            : GlassButton(
                                key: const ValueKey('b'),
                                active: true,
                                padding: const EdgeInsets.all(10),
                                iconSize: 26,
                                onTap: t == null ? app.startWave : p.toggle,
                                child: PlayPauseIcon(playing: p.playing),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GlassButton.icon(Icons.skip_next_rounded, size: 20, pad: 7, onTap: t == null ? null : p.next),
                  const SizedBox(width: 10),
                  HoverIcon(p.repeat == Repeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                      size: 19, active: p.repeat != Repeat.off, onTap: p.cycleRepeat, tooltip: 'Повтор'),
                  const SizedBox(width: 14),
                  if (t != null)
                    ValueListenableBuilder<Duration>(
                      valueListenable: p.position,
                      builder: (context, pos, _) => Text('${fmt(pos)} / ${fmt(p.duration.value)}',
                          style: const TextStyle(color: C.sub, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
                    ),
                ]),
              ]),
            ),
            // ---- extras ----
            SizedBox(
              width: 330,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                HoverIcon(Icons.lyrics_rounded, size: 20, tooltip: 'Текст', onTap: () => app.setStageView(1)),
                HoverIcon(Icons.queue_music_rounded, size: 20, tooltip: 'Очередь', onTap: () => app.setStageView(2)),
                HoverIcon(Icons.subtitles_rounded, size: 20, tooltip: 'Текст поверх игр (Ctrl+Shift+L)', onTap: app.overlay.enter),
                const SizedBox(width: 6),
                HoverIcon(
                  p.volume == 0 ? Icons.volume_off_rounded : (p.volume < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                  size: 20,
                  onTap: p.toggleMute,
                ),
                SizedBox(
                  width: 100,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 3),
                    child: Slider(value: p.volume, min: 0, max: 100, onChanged: p.setVolume),
                  ),
                ),
                HoverIcon(Icons.open_in_full_rounded, size: 18, tooltip: 'Полный экран (F)', onTap: () => app.setNowPlaying(true)),
              ]),
            ),
          ]),
          ),
          if (t != null) const Positioned(left: 0, right: 0, top: 0, child: _TopSeek()),
        ]);
      },
    );
  }
}

/// Full-width seek line on the top edge of the player bar (Yandex-style).
class _TopSeek extends StatefulWidget {
  const _TopSeek();
  @override
  State<_TopSeek> createState() => _TopSeekState();
}

class _TopSeekState extends State<_TopSeek> {
  double? _hoverX;
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final p = app.player;
    return LayoutBuilder(builder: (context, c) {
      Duration at(double x) => p.duration.value * (x / c.maxWidth).clamp(0.0, 1.0);
      final hover = _hoverX != null || _drag != null;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onHover: (e) => setState(() => _hoverX = e.localPosition.dx),
        onExit: (_) => setState(() => _hoverX = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (e) => p.seek(at(e.localPosition.dx)),
          onHorizontalDragUpdate: (e) => setState(() => _drag = e.localPosition.dx.clamp(0, c.maxWidth)),
          onHorizontalDragEnd: (_) {
            if (_drag != null) p.seek(at(_drag!));
            setState(() => _drag = null);
          },
          child: SizedBox(
            height: 12,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: ValueListenableBuilder<Duration>(
                  valueListenable: p.position,
                  builder: (context, pos, _) {
                    final d = p.duration.value.inMilliseconds;
                    final f = _drag != null
                        ? _drag! / c.maxWidth
                        : (d == 0 ? 0.0 : (pos.inMilliseconds / d).clamp(0.0, 1.0));
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      height: hover ? 5 : 2,
                      color: Colors.white.withValues(alpha: 0.10),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: f,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white, boxShadow: [
                            BoxShadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 10),
                          ]),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_hoverX != null || _drag != null)
                Positioned(
                  left: ((_drag ?? _hoverX!) - 24).clamp(0.0, c.maxWidth - 48),
                  top: 10,
                  child: IgnorePointer(
                    child: Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Text(fmt(at(_drag ?? _hoverX!)),
                          style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
    });
  }
}

class _BarProgress extends StatefulWidget {
  const _BarProgress();
  @override
  State<_BarProgress> createState() => _BarProgressState();
}

class _BarProgressState extends State<_BarProgress> {
  double? _drag;
  bool _hover = false;

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
          return MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: Row(children: [
              SizedBox(
                width: 40,
                child: Text(fmt(Duration(milliseconds: value.toInt())),
                    textAlign: TextAlign.right, style: const TextStyle(color: C.sub, fontSize: 11)),
              ),
              Expanded(
                child: SizedBox(
                  height: 18,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: _hover ? 4 : 3,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: _hover || _drag != null ? 6 : 0),
                    ),
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
                ),
              ),
              SizedBox(width: 40, child: Text(fmt(dur), style: const TextStyle(color: C.sub, fontSize: 11))),
            ]),
          );
        },
      ),
    );
  }
}

// ======================= FULLSCREEN PLAYER =======================

class NowPlayingOverlay extends StatelessWidget {
  const NowPlayingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return StageBackground(
      child: Stack(children: [
        const Positioned(left: 0, right: 0, top: 0, height: 56, child: DragToMoveArea(child: SizedBox.expand())),
        Positioned(
          top: 16,
          left: 20,
          child: GlassButton.icon(Icons.keyboard_arrow_down_rounded,
              size: 28, pad: 8, tooltip: 'Свернуть (Esc)', onTap: () => app.setNowPlaying(false)),
        ),
        const Positioned(top: 4, right: 0, child: _WindowButtons()),
        const Padding(padding: EdgeInsets.fromLTRB(60, 70, 60, 50), child: Stage()),
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
      color: const Color(0xFF1C1C1C),
      offset: const Offset(0, 44),
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
        width: 34,
        height: 34,
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
  FocusNode get _focus => app.searchFocus;
  void _onFocus() => setState(() {});

  void _syncText() {
    if (!_focus.hasFocus && _search.text != app.searchQuery) {
      _search.text = app.searchQuery;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    app.addListener(_syncText);
  }

  @override
  void dispose() {
    app.removeListener(_syncText);
    _focus.removeListener(_onFocus);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return SizedBox(
      height: 58,
      child: Stack(children: [
        const Positioned.fill(child: DragToMoveArea(child: SizedBox.expand())),
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 4),
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
              width: focused ? 480 : 340,
              height: 40,
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

class UpNextRow extends StatefulWidget {
  final Track track;
  final int index;
  const UpNextRow({super.key, required this.track, required this.index});
  @override
  State<UpNextRow> createState() => UpNextRowState();
}

class UpNextRowState extends State<UpNextRow> {
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
            AnimatedOpacity(
              opacity: _hover ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: HoverIcon(Icons.close_rounded,
                  size: 16, tooltip: 'Убрать из очереди', onTap: () => app.player.removeAt(widget.index)),
            ),
          ]),
        ),
      ),
    );
  }
}

class StageProgress extends StatefulWidget {
  const StageProgress();
  @override
  State<StageProgress> createState() => StageProgressState();
}

class StageProgressState extends State<StageProgress> {
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
