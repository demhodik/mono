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
import '../widgets/orb3d.dart';
import '../../state/player.dart';
import '../lyrics.dart';
import '../shell.dart' show StageProgress, UpNextRow;

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

// ======================= HOME · СЦЕНА =======================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = app.api!;
    return LayoutBuilder(builder: (context, c) {
      final heroH = (c.maxHeight * 0.74).clamp(420.0, 620.0);
      return SmoothScrollView(slivers: [
        SliverToBoxAdapter(child: SizedBox(height: heroH, child: const WaveHero())),
        if (app.history.isNotEmpty)
          SliverToBoxAdapter(
            child: Shelf(
              title: 'Вы недавно слушали',
              height: 76,
              itemWidth: 250,
              count: app.history.length.clamp(0, 30),
              item: (i) => _RecentChip(track: app.history[i]),
            ),
          ),
        SliverToBoxAdapter(
          child: Loader<List<Album>>(
            load: api.newReleases,
            builder: (context, albums) => Shelf(
              title: 'Новые релизы',
              onMore: () => app.go(PageKind.releases),
              count: albums.length.clamp(0, 30),
              item: (i) => _albumCard(albums[i]),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Loader<List<Track>>(
            load: api.chart,
            builder: (context, tracks) => Shelf(
              title: 'Чарт',
              onMore: () => app.go(PageKind.chart),
              count: tracks.length.clamp(0, 30),
              item: (i) => MediaCard(
                image: tracks[i].coverOf(300),
                title: '${i + 1}. ${tracks[i].title}',
                subtitle: tracks[i].artists,
                fallback: Icons.music_note_rounded,
                onOpen: () => app.player.playList(tracks, i, source: 'chart'),
                onPlay: () => app.player.playList(tracks, i, source: 'chart'),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ]);
    });
  }
}

/// "Моя волна" — Yandex-style: the 3D blob across the block, title + play + "Настроить" over it.
class WaveHero extends StatelessWidget {
  const WaveHero({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.player]),
      builder: (context, _) {
        final p = app.player;
        final onWave = (p.source == 'wave' || p.source == 'vibe') && p.current != null;
        final playing = onWave && p.playing;
        final label = p.source == 'vibe' && onWave
            ? 'Подбор: ${app.vibeText}'
            : (app.waveActivity != null ? 'Моя волна · ${AppState.activities[app.waveActivity]}' : 'Моя волна');
        return LayoutBuilder(builder: (context, c) {
          final orb = (c.maxHeight - 120).clamp(260.0, 520.0);
          return Column(children: [
            Expanded(
              child: Stack(alignment: Alignment.center, children: [
                ValueListenableBuilder<bool>(
                  valueListenable: app.introDone,
                  builder: (context, done, child) =>
                      AnimatedOpacity(opacity: done ? 1 : 0, duration: const Duration(milliseconds: 160), child: child),
                  child: KeyedSubtree(key: app.heroOrbKey, child: Orb3D(size: orb, active: playing)),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Unbounded',
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                        shadows: [Shadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 30)],
                      )),
                  const SizedBox(height: 16),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    GlassButton(
                      active: true,
                      padding: const EdgeInsets.all(16),
                      iconSize: 34,
                      tooltip: playing ? 'Пауза' : 'Слушать',
                      onTap: onWave ? p.toggle : app.startWave,
                      child: PlayPauseIcon(playing: playing),
                    ),
                    const SizedBox(width: 12),
                    GlassButton(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      onTap: () => showWaveSettings(context),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.tune_rounded, size: 19),
                        SizedBox(width: 8),
                        Text('Настроить'),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: onWave
                        ? Text('${p.current!.title} — ${p.current!.artists}',
                            key: ValueKey(p.current!.id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: const Color(0xFFDADADA),
                                fontSize: 14,
                                shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 14)]))
                        : const SizedBox(height: 18),
                  ),
                ]),
              ]),
            ),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: const VibeBox()),
            const SizedBox(height: 10),
          ]);
        });
      },
    );
  }
}

/// Wave settings sheet (like Yandex): Занятие · Характер · Настроение · Язык.
Future<void> showWaveSettings(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, _, _) => const Center(child: _WaveSettingsPanel()),
    transitionBuilder: (_, a, _, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      return FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(c), child: child));
    },
  );
}

class _WaveSettingsPanel extends StatelessWidget {
  const _WaveSettingsPanel();

  static const _div = {'favorite': 'Любимое', 'discover': 'Незнакомое', 'popular': 'Популярное'};
  static const _mood = {'active': 'Бодрое', 'fun': 'Весёлое', 'calm': 'Спокойное', 'sad': 'Грустное'};
  static const _lang = {'russian': 'Русский', 'not-russian': 'Иностранный', 'without-words': 'Без слов'};

  Widget _group(String title, Map<String, String> m, String? value, void Function(String) pick) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, color: C.sub, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in m.entries)
            GlassButton(
              active: value == e.key,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              onTap: () => pick(e.key),
              child: Text(e.value),
            ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 560,
        decoration: BoxDecoration(
          color: const Color(0xF0141414),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 60)],
        ),
        child: GlassPanel(
          radius: 30,
          opacity: 0.05,
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 6),
          child: ListenableBuilder(
            listenable: app,
            builder: (context, _) {
              final s = app.waveSettings;
              void apply(void Function() f) {
                f();
                app.waveActivity = null;
                app.startWave();
              }

              return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(
                    child: Text('Настроить волну', style: TextStyle(fontFamily: 'Unbounded', fontSize: 22, fontWeight: FontWeight.w700)),
                  ),
                  HoverIcon(Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
                ]),
                const SizedBox(height: 20),
                _group('Под занятие', AppState.activities, app.waveActivity, (v) => app.setActivity(v)),
                _group('По характеру', _div, s.diversity, (v) => apply(() => s.diversity = s.diversity == v ? 'default' : v)),
                _group('Под настроение', _mood, s.mood, (v) => apply(() => s.mood = s.mood == v ? 'all' : v)),
                _group('По языку', _lang, s.language, (v) => apply(() => s.language = s.language == v ? 'any' : v)),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class _RecentChip extends StatefulWidget {
  final Track track;
  const _RecentChip({required this.track});
  @override
  State<_RecentChip> createState() => _RecentChipState();
}

class _RecentChipState extends State<_RecentChip> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => app.player.playList(app.history.toList(), app.history.indexOf(t), source: 'history'),
        onSecondaryTapUp: (d) => showTrackMenu(context, d.globalPosition, t),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 230,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.all(7),
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: _hover ? 0.12 : 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: _hover ? 0.3 : 0.12)),
          ),
          child: Row(children: [
            Cover(t.coverOf(100), size: 46, radius: 12),
            const SizedBox(width: 10),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(t.artists, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.sub, fontSize: 12)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The scene: big type on the left, a 3D card on the right (cover ⇄ lyrics ⇄ queue).
/// With nothing playing it becomes "Моя волна".
class Stage extends StatelessWidget {
  const Stage({super.key});

  static const _moods = {'all': 'Любое', 'active': 'Бодрое', 'fun': 'Весёлое', 'calm': 'Спокойное', 'sad': 'Грустное'};
  static const _div = {'default': 'Обычно', 'favorite': 'Любимое', 'discover': 'Незнакомое', 'popular': 'Популярное'};

  String _overline(String? src) {
    if (src == null) return 'ИГРАЕТ СЕЙЧАС';
    if (src == 'wave') return 'МОЯ ВОЛНА';
    if (src == 'vibe') return 'ПОДБОР · ${app.vibeText.toUpperCase()}';
    if (src.startsWith('radio:')) return 'ВОЛНА ПО ТРЕКУ';
    if (src == 'likes') return 'МНЕ НРАВИТСЯ';
    if (src == 'chart') return 'ЧАРТ';
    if (src.startsWith('album:')) return 'АЛЬБОМ';
    if (src.startsWith('playlist:')) return 'ПЛЕЙЛИСТ';
    return 'ИГРАЕТ СЕЙЧАС';
  }

  Widget _chips(Map<String, String> m, String value, void Function(String) pick) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final e in m.entries)
          GlassButton(
            active: e.key == value,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            onTap: () => pick(e.key),
            child: Text(e.value, style: const TextStyle(fontSize: 12.5)),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.player]),
      builder: (context, _) {
        final p = app.player;
        final t = p.current;
        final onWave = p.source == 'wave';
        final s = app.waveSettings;
        void setMood(String v) {
          s.mood = v;
          app.startWave();
        }

        void setDiv(String v) {
          s.diversity = v;
          app.startWave();
        }

        final left = t == null
            ? Column(key: const ValueKey('idle'), mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('МОЯ ВОЛНА', style: TextStyle(fontSize: 12, letterSpacing: 3.5, color: C.sub, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                const Text('Музыка,\nкоторая\nне кончается',
                    style: TextStyle(fontFamily: 'Unbounded', fontSize: 54, fontWeight: FontWeight.w700, height: 1.02, letterSpacing: -1.6)),
                const SizedBox(height: 16),
                const Text('Подстраивается под каждый лайк и пропуск', style: TextStyle(color: C.sub, fontSize: 15)),
                const SizedBox(height: 26),
                GlassButton(
                  active: true,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
                  iconSize: 26,
                  onTap: app.startWave,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_arrow_rounded),
                    SizedBox(width: 8),
                    Text('Запустить волну', style: TextStyle(fontSize: 15)),
                  ]),
                ),
                const SizedBox(height: 22),
                _chips(_moods, s.mood, setMood),
                const SizedBox(height: 8),
                _chips(_div, s.diversity, setDiv),
              ])
            : Column(key: const ValueKey('play'), mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  EqBars(playing: p.playing, size: 14),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(_overline(p.source),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, letterSpacing: 3.5, color: C.sub, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 520),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(a),
                      child: c,
                    ),
                  ),
                  layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, if (cur != null) cur]),
                  child: Column(
                    key: ValueKey(t.id),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Unbounded',
                              fontSize: t.title.length > 34 ? 34 : (t.title.length > 18 ? 44 : 56),
                              fontWeight: FontWeight.w700,
                              height: 1.04,
                              letterSpacing: -1.4)),
                      const SizedBox(height: 12),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => app.openArtistOf(t),
                          child: Text(t.artists, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, color: Color(0xFFCFCFCF))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const StageProgress(),
                const SizedBox(height: 8),
                Row(children: [
                  HoverIcon(Icons.shuffle_rounded, size: 22, active: p.shuffle, onTap: p.toggleShuffle, tooltip: 'Перемешать'),
                  const SizedBox(width: 10),
                  GlassButton.icon(Icons.skip_previous_rounded, size: 26, pad: 11, onTap: p.previous),
                  const SizedBox(width: 12),
                  GlassButton(active: true, padding: const EdgeInsets.all(17), iconSize: 36, onTap: p.toggle, child: PlayPauseIcon(playing: p.playing)),
                  const SizedBox(width: 12),
                  GlassButton.icon(Icons.skip_next_rounded, size: 26, pad: 11, onTap: p.next),
                  const SizedBox(width: 10),
                  HoverIcon(p.repeat == Repeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                      size: 22, active: p.repeat != Repeat.off, onTap: p.cycleRepeat, tooltip: 'Повтор'),
                  const SizedBox(width: 10),
                  LikeButton(track: t, size: 24),
                  HoverIcon(Icons.more_horiz_rounded, size: 22, tooltip: 'Ещё', onTap: () {
                    final box = context.findRenderObject() as RenderBox;
                    showTrackMenu(context, box.localToGlobal(Offset(120, box.size.height - 60)), t);
                  }),
                ]),
                const SizedBox(height: 18),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  LyricsLoader(
                    key: ValueKey('lb${t.id}'),
                    track: t,
                    loading: const SizedBox.shrink(),
                    builder: (context, l) => l.isEmpty
                        ? const SizedBox.shrink()
                        : GlassButton(
                            active: app.stageView == 1,
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                            onTap: () => app.setStageView(1),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lyrics_rounded, size: 17), SizedBox(width: 7), Text('Текст')]),
                          ),
                  ),
                  GlassButton(
                    active: app.stageView == 2,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    onTap: () => app.setStageView(2),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.queue_music_rounded, size: 17), SizedBox(width: 7), Text('Далее')]),
                  ),
                  GlassButton(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    onTap: () => app.startTrackWave(t),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.waves_rounded, size: 17), SizedBox(width: 7), Text('Волна по треку')]),
                  ),
                  GlassButton(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    tooltip: 'Текст поверх игры. Выход: Ctrl+Shift+L',
                    onTap: app.overlay.enter,
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.subtitles_rounded, size: 17), SizedBox(width: 7), Text('Поверх игры')]),
                  ),
                  _SleepButton(),
                ]),
                if (onWave) ...[
                  const SizedBox(height: 10),
                  _chips(_moods, s.mood, setMood),
                ],
              ]);

        return Row(children: [
          Expanded(
            flex: 6,
            child: FadeSlideIn(
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: left),
            ),
          ),
          const SizedBox(width: 30),
          Expanded(
            flex: 5,
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              dy: 40,
              child: LayoutBuilder(builder: (context, c) {
                final side = (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight) - 20;
                return Center(child: SizedBox(width: side, height: side, child: _StageCard(track: t, size: side)));
              }),
            ),
          ),
        ]);
      },
    );
  }
}

class _SleepButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = app.player;
    final at = p.sleepAt;
    final label = at == null ? 'Сон' : '${at.difference(DateTime.now()).inMinutes + 1} мин';
    return PopupMenuButton<int>(
      tooltip: 'Остановить музыку через…',
      offset: const Offset(0, 42),
      onSelected: (m) => p.setSleep(m == 0 ? null : Duration(minutes: m)),
      itemBuilder: (_) => [
        for (final m in const [15, 30, 45, 60, 90]) PopupMenuItem(value: m, height: 40, child: Text('Через $m минут')),
        if (at != null) const PopupMenuItem(value: 0, height: 40, child: Text('Выключить таймер')),
      ],
      child: IgnorePointer(
        child: GlassButton(
          active: at != null,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          onTap: () {},
          child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.bedtime_rounded, size: 17), const SizedBox(width: 7), Text(label)]),
        ),
      ),
    );
  }
}

/// Right side of the stage. Flips in 3D between cover / lyrics / queue.
class _StageCard extends StatelessWidget {
  final Track? track;
  final double size;
  const _StageCard({required this.track, required this.size});

  @override
  Widget build(BuildContext context) {
    final t = track;
    final view = t == null ? -1 : app.stageView;
    Widget child;
    if (t == null) {
      child = GlassPanel(
        key: const ValueKey('orb'),
        radius: 36,
        opacity: 0.06,
        child: Center(child: WaveOrb(size: size * 0.82, active: false)),
      );
    } else if (view == 1) {
      child = GlassPanel(
        key: ValueKey('ly${t.id}'),
        radius: 36,
        opacity: 0.08,
        blur: 30,
        padding: const EdgeInsets.fromLTRB(28, 0, 20, 0),
        child: LyricsLoader(
          track: t,
          builder: (context, l) {
            if (l.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (app.stageView == 1) app.setStageView(0);
              });
            }
            return LyricsView(track: t);
          },
        ),
      );
    } else if (view == 2) {
      final up = app.player.queue.skip(app.player.index + 1).take(40).toList();
      child = GlassPanel(
        key: const ValueKey('queue'),
        radius: 36,
        opacity: 0.08,
        blur: 30,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text('ДАЛЕЕ', style: TextStyle(fontSize: 12, letterSpacing: 3.5, color: C.sub, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: up.isEmpty
                ? const Center(child: Text('Очередь пуста', style: TextStyle(color: C.sub)))
                : ListView(children: [
                    for (var i = 0; i < up.length; i++)
                      UpNextRow(key: ValueKey(up[i].id), track: up[i], index: app.player.index + 1 + i),
                  ]),
          ),
        ]),
      );
    } else {
      child = KeyedSubtree(
        key: const ValueKey('cover'),
        child: Tilt3D(
          maxAngle: 0.26,
          radius: 36,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: c)),
            child: Container(
              key: ValueKey(t.id),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.05)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 60, offset: const Offset(0, 30))],
              ),
              child: Cover(t.coverOf(600), size: size - 22, radius: 27),
            ),
          ),
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 620),
      switchInCurve: const Interval(0.5, 1, curve: Curves.easeOutCubic),
      switchOutCurve: const Interval(0.5, 1, curve: Curves.easeInCubic),
      layoutBuilder: (cur, prev) => Stack(children: [...prev, if (cur != null) cur]),
      transitionBuilder: (c, a) => AnimatedBuilder(
        animation: a,
        child: c,
        builder: (context, w) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY((1 - a.value) * 1.5708),
          child: Opacity(opacity: a.value < 0.02 ? 0 : 1, child: w),
        ),
      ),
      child: SizedBox(key: child.key, width: size, height: size, child: child),
    );
  }
}

/// Compact vibe input: write a mood, music starts.
class VibeBox extends StatefulWidget {
  const VibeBox({super.key});
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
    if (t.trim().isEmpty) return;
    app.vibe(t);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Row(children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
                Colors.white.withValues(alpha: focused ? 0.15 : 0.09),
                Colors.white.withValues(alpha: focused ? 0.06 : 0.03),
              ]),
              border: Border.all(color: Colors.white.withValues(alpha: focused ? 0.5 : 0.18)),
              boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: focused ? 0.10 : 0), blurRadius: 40)],
            ),
            padding: const EdgeInsets.only(left: 20, right: 6),
            child: Row(children: [
              Icon(Icons.auto_awesome_rounded, size: 20, color: focused ? Colors.white : C.sub),
              const SizedBox(width: 12),
              Expanded(
                child: Stack(alignment: Alignment.centerLeft, children: [
                  if (_ctrl.text.isEmpty)
                    IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(position: Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(a), child: c),
                        ),
                        child: Text('Или опиши вайб: ${_examples[_hint]}',
                            key: ValueKey(_hint), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.dim, fontSize: 15)),
                      ),
                    ),
                  TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _go(),
                  ),
                ]),
              ),
              app.vibeBusy
                  ? const Padding(padding: EdgeInsets.all(12), child: GlassSpinner(size: 22))
                  : GlassButton(
                      active: true,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      onTap: () => _go(),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Подобрать'),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ]),
                    ),
            ]),
          ),
        ),
      ]),
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

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int _tab = 0;
  static const _tabs = ['Треки', 'Альбомы', 'Исполнители', 'Плейлисты', 'История'];

  Widget _body() {
    final api = app.api!;
    switch (_tab) {
      case 0:
        return Loader<List<Track>>(
          key: const ValueKey('t'),
          sliver: true,
          load: api.likedTracks,
          builder: (context, t) => TrackSliver(tracks: t, source: 'likes'),
        );
      case 1:
        return Loader<List<Album>>(
          key: const ValueKey('a'),
          sliver: true,
          load: api.likedAlbums,
          builder: (context, a) => CardGrid(count: a.length, item: (i) => _albumCard(a[i])),
        );
      case 2:
        return Loader<List<Artist>>(
          key: const ValueKey('ar'),
          sliver: true,
          load: api.likedArtists,
          builder: (context, a) => SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, mainAxisExtent: 196),
              itemCount: a.length,
              itemBuilder: (_, i) => FadeSlideIn.index(i, child: ArtistBubble(artist: a[i])),
            ),
          ),
        );
      case 3:
        return CardGrid(
          key: const ValueKey('p'),
          count: app.playlists.length + 1,
          item: (i) => i == 0
              ? MediaCard(
                  image: '',
                  fallback: Icons.favorite_rounded,
                  title: 'Мне нравится',
                  subtitle: plural(app.likedIds.length, 'трек', 'трека', 'треков'),
                  onOpen: () => app.go(PageKind.likes),
                )
              : _playlistCard(app.playlists[i - 1]),
        );
      default:
        return TrackSliver(key: const ValueKey('h'), tracks: app.history, source: 'history');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SmoothScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 14, 32, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FadeSlideIn(
              child: Text('Коллекция', style: TextStyle(fontFamily: 'Unbounded', fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
            ),
            const SizedBox(height: 16),
            _Tabs(tabs: _tabs, index: _tab, onPick: (i) => setState(() => _tab = i)),
          ]),
        ),
      ),
      _body(),
      const SliverToBoxAdapter(child: SizedBox(height: 40)),
    ]);
  }
}

/// Underlined text tabs with a sliding indicator.
class _Tabs extends StatelessWidget {
  final List<String> tabs;
  final int index;
  final void Function(int) onPick;
  const _Tabs({required this.tabs, required this.index, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, children: [
      for (var i = 0; i < tabs.length; i++)
        GlassButton(
          active: i == index,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          onTap: () => onPick(i),
          child: Text(tabs[i]),
        ),
    ]);
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
  Future<SearchResult>? _future;

  @override
  void initState() {
    super.initState();
    app.addListener(_onApp);
    _onApp();
  }

  void _onApp() {
    if (app.searchQuery == _query) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() {
        _query = app.searchQuery;
        _future = _query.trim().isEmpty ? null : app.api!.searchAll(_query.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    app.removeListener(_onApp);
    super.dispose();
  }

  Widget _row(double height, int count, Widget Function(int) item, double width) => SliverToBoxAdapter(
        child: SizedBox(
          height: height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: count,
            itemBuilder: (_, i) => SizedBox(width: width, child: FadeSlideIn.index(i, child: item(i))),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_future == null) {
      const genres = ['Фонк', 'Рэп', 'Рок', 'Lo-fi', 'Электроника', 'Инди', 'Поп', 'Джаз', 'Синтвейв', 'Метал'];
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FadeSlideIn(
              child: Text('Поиск',
                  style: TextStyle(fontFamily: 'Unbounded', fontSize: 52, fontWeight: FontWeight.w700, letterSpacing: -1.5)),
            ),
            const SizedBox(height: 8),
            const FadeSlideIn(
              delay: Duration(milliseconds: 80),
              child: Text('Треки, артисты, альбомы и плейлисты. Или начни с жанра:',
                  style: TextStyle(color: C.sub, fontSize: 16)),
            ),
            const SizedBox(height: 24),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (var i = 0; i < genres.length; i++)
                FadeSlideIn.index(
                  i + 2,
                  dy: 14,
                  child: GlassButton(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    onTap: () => app.search(genres[i]),
                    child: Text(genres[i], style: const TextStyle(fontSize: 15)),
                  ),
                ),
            ]),
          ]),
        ),
      );
    }
    return FutureBuilder<SearchResult>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}', style: const TextStyle(color: C.sub)));
        if (!snap.hasData) return const Center(child: GlassSpinner());
        final r = snap.data!;
        if (r.isEmpty) {
          return Center(child: Text('По запросу «$_query» ничего не нашлось', style: const TextStyle(color: C.sub)));
        }
        return SmoothScrollView(key: ValueKey(_query), slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 18, 32, 0),
              child: Text('«$_query»',
                  style: const TextStyle(fontFamily: 'Unbounded', fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
            ),
          ),
          if (r.artists.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionTitle('Артисты')),
            _row(196, r.artists.length.clamp(0, 12), (i) => ArtistBubble(artist: r.artists[i]), 160),
          ],
          if (r.tracks.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionTitle('Треки')),
            TrackSliver(tracks: r.tracks.take(8).toList(), source: 'search:$_query'),
          ],
          if (r.albums.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionTitle('Альбомы')),
            _row(290, r.albums.length.clamp(0, 14), (i) => _albumCard(r.albums[i]), 210),
          ],
          if (r.playlists.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionTitle('Плейлисты')),
            _row(290, r.playlists.length.clamp(0, 14), (i) => _playlistCard(r.playlists[i]), 210),
          ],
          if (r.tracks.length > 8) ...[
            const SliverToBoxAdapter(child: SectionTitle('Ещё треки')),
            TrackSliver(tracks: r.tracks.skip(8).toList(), source: 'search2:$_query'),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ]);
      },
    );
  }
}

Widget _playlistCard(Playlist p) => MediaCard(
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

/// Round artist avatar with a name.
class ArtistBubble extends StatefulWidget {
  final Artist artist;
  const ArtistBubble({super.key, required this.artist});
  @override
  State<ArtistBubble> createState() => _ArtistBubbleState();
}

class _ArtistBubbleState extends State<ArtistBubble> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.artist;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => app.go(PageKind.artist, ArtistRef(a.id, a.name)),
        child: Column(children: [
          const SizedBox(height: 8),
          AnimatedScale(
            scale: _hover ? 1.07 : 1,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: _hover ? 0.7 : 0.14), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: _hover ? 0.18 : 0), blurRadius: 26)],
              ),
              child: Cover(a.coverOf(200), size: 124, radius: 999, fallback: Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ======================= ARTIST =======================

class ArtistPage extends StatelessWidget {
  final ArtistRef ref;
  const ArtistPage(this.ref, {super.key});

  @override
  Widget build(BuildContext context) {
    final source = 'artist:${ref.id}';
    return Loader<ArtistInfo>(
      load: () => app.api!.artist(ref.id),
      builder: (context, info) {
        final name = info.artist.name.isEmpty ? ref.name : info.artist.name;
        return SmoothScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 20),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                FadeSlideIn(
                  child: Tilt3D(
                    radius: 999,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40, offset: const Offset(0, 18)),
                        ],
                      ),
                      child: Cover(info.artist.coverOf(400), size: 210, radius: 999, fallback: Icons.person_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 30),
                Expanded(
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 120),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('АРТИСТ',
                          style: TextStyle(fontSize: 12, letterSpacing: 3, color: C.sub, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Unbounded',
                              fontSize: name.length > 18 ? 34 : 50,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                              height: 1.05)),
                      const SizedBox(height: 12),
                      Text(
                          '${plural(info.albums.length, 'релиз', 'релиза', 'релизов')} · популярное: ${plural(info.popular.length, 'трек', 'трека', 'треков')}',
                          style: const TextStyle(color: C.sub)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(child: PlayActions(tracks: info.popular, source: source)),
          if (info.popular.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionTitle('Популярное')),
            TrackSliver(tracks: info.popular.take(10).toList(), source: source),
          ],
          if (info.albums.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionTitle('Альбомы и синглы')),
            CardGrid(count: info.albums.length, item: (i) => _albumCard(info.albums[i])),
          ],
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
