import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../api/models.dart';
import '../state/app_state.dart';
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
      body: StageBackground(
        child: Stack(children: [
          Column(children: [
            const Entrance(from: Offset(0, -50), child: TopBar()),
            Expanded(
              child: Entrance(
                from: const Offset(0, 40),
                delayMs: 120,
                child: ListenableBuilder(
                  listenable: app,
                  builder: (context, _) {
                    final r = app.route;
                    final dir = app.navDir.toDouble();
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 480),
                      reverseDuration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) {
                        final incoming = child.key == ObjectKey(r);
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(incoming ? 0.04 * dir : -0.04 * dir, 0),
                              end: Offset.zero,
                            ).animate(anim),
                            child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(anim), child: child),
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
          const Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Center(
              child: Entrance(from: Offset(0, 110), delayMs: 260, curve: Curves.easeOutBack, child: BottomBar()),
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
      case PageKind.artist:
        return ArtistPage(r.arg as ArtistRef);
    }
  }
}

// ======================= BOTTOM GLASS CAPSULE =======================

/// One floating glass capsule: mini player · navigation · like + volume.
class BottomBar extends StatelessWidget {
  const BottomBar({super.key});

  static const tabs = <(PageKind, IconData, String)>[
    (PageKind.home, Icons.graphic_eq_rounded, 'Сцена'),
    (PageKind.search, Icons.search_rounded, 'Поиск'),
    (PageKind.library, Icons.library_music_rounded, 'Медиатека'),
    (PageKind.likes, Icons.favorite_rounded, 'Любимое'),
    (PageKind.releases, Icons.auto_awesome_rounded, 'Новинки'),
    (PageKind.chart, Icons.trending_up_rounded, 'Чарт'),
    (PageKind.wave, Icons.tune_rounded, 'Волна'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.player]),
      builder: (context, _) {
        final p = app.player;
        final t = p.current;
        final w = MediaQuery.sizeOf(context).width;
        final wide = w > 1700;
        var kind = app.route.kind;
        if (kind == PageKind.playlist || kind == PageKind.album || kind == PageKind.artist) kind = PageKind.library;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(33),
            ),
            child: GlassPanel(
              radius: 33,
              opacity: 0.10,
              blur: 30,
              child: Stack(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  child: Row(children: [
                    // ---- mini player ----
                    SizedBox(
                      width: w > 1300 ? 270 : 210,
                      child: t == null
                          ? const Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Text('Включи что-нибудь',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.sub, fontSize: 13)),
                            )
                          : MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => app.go(PageKind.home),
                                onSecondaryTapUp: (d) => showTrackMenu(context, d.globalPosition, t),
                                child: Row(children: [
                                  Vinyl(cover: t.coverOf(200), size: 48, spinning: p.playing),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 380),
                                      transitionBuilder: (c, a) => FadeTransition(
                                        opacity: a,
                                        child: SlideTransition(
                                          position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(a),
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
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                          const SizedBox(height: 2),
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
                    const SizedBox(width: 6),
                    GlassButton.icon(Icons.skip_previous_rounded, size: 20, pad: 8, onTap: t == null ? null : p.previous),
                    const SizedBox(width: 6),
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
                    const SizedBox(width: 6),
                    GlassButton.icon(Icons.skip_next_rounded, size: 20, pad: 8, onTap: t == null ? null : p.next),
                    if (t != null) LikeButton(track: t, size: 19),
                    _sep(),
                    // ---- navigation ----
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            for (final tab in tabs)
                              _NavTab(
                                icon: tab.$2,
                                label: tab.$3,
                                active: kind == tab.$1,
                                showLabel: wide || kind == tab.$1,
                                onTap: () => app.go(tab.$1),
                              ),
                          ]),
                        ),
                      ),
                    ),
                    _sep(),
                    // ---- volume ----
                    HoverIcon(
                      p.volume == 0
                          ? Icons.volume_off_rounded
                          : (p.volume < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                      size: 19,
                      onTap: p.toggleMute,
                    ),
                    SizedBox(
                      width: 86,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(trackHeight: 3),
                        child: Slider(value: p.volume, min: 0, max: 100, onChanged: p.setVolume),
                      ),
                    ),
                  ]),
                ),
                if (t != null) const Positioned(left: 34, right: 34, top: 0, child: _CapsuleProgress()),
              ]),
            ),
          ),
        );
      },
    );
  }

  static Widget _sep() => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: Colors.white.withValues(alpha: 0.12),
      );
}

class _NavTab extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool showLabel;
  final VoidCallback onTap;
  const _NavTab(
      {required this.icon, required this.label, required this.active, required this.showLabel, required this.onTap});
  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.active;
    final fg = a ? Colors.black : (_hover ? Colors.white : const Color(0xFFB0B0B0));
    return Tooltip(
      message: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: EdgeInsets.symmetric(horizontal: widget.showLabel ? 14 : 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: a
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xF7FFFFFF), Color(0xD9D6D6D6)],
                    )
                  : null,
              color: a ? null : Colors.white.withValues(alpha: _hover ? 0.08 : 0),
              boxShadow: a ? [BoxShadow(color: Colors.white.withValues(alpha: 0.22), blurRadius: 18)] : null,
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.icon, size: 20, color: fg),
                if (widget.showLabel) ...[
                  const SizedBox(width: 8),
                  Text(widget.label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Seek line along the top edge of the capsule; thickens and shows a time bubble on hover.
class _CapsuleProgress extends StatefulWidget {
  const _CapsuleProgress();
  @override
  State<_CapsuleProgress> createState() => _CapsuleProgressState();
}

class _CapsuleProgressState extends State<_CapsuleProgress> {
  double? _hoverX;

  @override
  Widget build(BuildContext context) {
    final p = app.player;
    return LayoutBuilder(builder: (context, c) {
      Duration at(double x) => p.duration.value * (x / c.maxWidth).clamp(0.0, 1.0);
      final hover = _hoverX != null;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onHover: (e) => setState(() => _hoverX = e.localPosition.dx),
        onExit: (_) => setState(() => _hoverX = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (e) => p.seek(at(e.localPosition.dx)),
          onHorizontalDragUpdate: (e) => p.seek(at(e.localPosition.dx)),
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
                    final f = d == 0 ? 0.0 : (pos.inMilliseconds / d).clamp(0.0, 1.0);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: hover ? 4 : 2,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: f,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 8)],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (hover)
                Positioned(
                  left: (_hoverX! - 24).clamp(0.0, c.maxWidth - 48),
                  bottom: 14,
                  child: IgnorePointer(
                    child: Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Text(fmt(at(_hoverX!)),
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
          padding: const EdgeInsets.only(left: 18, top: 4),
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
            const _AccountButton(),
            const SizedBox(width: 14),
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
