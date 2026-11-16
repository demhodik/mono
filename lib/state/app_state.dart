import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';
import '../api/yandex_api.dart';
import 'overlay.dart';
import 'player.dart';
import 'vibe.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Global app state (single user, personal app).
late final AppState app;

enum PageKind { home, search, library, likes, wave, chart, releases, album, playlist, artist }

class AppRoute {
  final PageKind kind;
  final Object? arg;
  const AppRoute(this.kind, [this.arg]);
}

class AppState extends ChangeNotifier {
  YandexApi? api;
  late final PlayerController player = PlayerController(this);
  final overlay = GameOverlay();

  /// Flips to true when the launch animation hands over to the UI.
  final revealed = ValueNotifier<bool>(false);
  final searchFocus = FocusNode();

  /// +1 = navigating forward, -1 = back (drives page transition direction).
  int navDir = 1;

  // ----- listening history (local) -----
  List<Track> history = [];

  void _recordHistory(Track t) {
    history.removeWhere((e) => e.id == t.id);
    history.insert(0, t);
    if (history.length > 60) history.removeRange(60, history.length);
    SharedPreferences.getInstance()
        .then((p) => p.setString('history', jsonEncode([for (final h in history) h.toJson()])));
  }

  Timer? _volTimer;
  void volumeChanged() {
    _volTimer?.cancel();
    _volTimer = Timer(const Duration(milliseconds: 600), () async {
      (await SharedPreferences.getInstance()).setDouble('volume', player.volume);
    });
  }

  /// Now Playing right side: true = lyrics, false = queue.
  bool lyricsTab = true;

  /// User-tuned lyrics sync shift in ms (positive = lines appear earlier).
  int lyricsOffset = 0;
  Future<void> shiftLyrics(int deltaMs) async {
    lyricsOffset = (lyricsOffset + deltaMs).clamp(-5000, 5000);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lyrics_offset', lyricsOffset);
  }

  Duration get lyricsTime => player.position.value + Duration(milliseconds: lyricsOffset);
  void setLyricsTab(bool v) {
    lyricsTab = v;
    stageView = v ? 1 : 2;
    notifyListeners();
  }

  bool ready = false;
  bool get loggedIn => api?.uid != null;

  Set<String> likedIds = {};
  List<Playlist> playlists = [];
  WaveSettings waveSettings = WaveSettings();

  // navigation with back/forward like Spotify
  final List<AppRoute> _history = [const AppRoute(PageKind.home)];
  int _pos = 0;
  AppRoute get route => _history[_pos];
  bool get canBack => _pos > 0;
  bool get canForward => _pos < _history.length - 1;
  String searchQuery = '';

  /// Full-screen "now playing" view.
  /// Kept for compatibility: the "now playing" view is the home stage now.
  bool nowPlaying = false;
  void setNowPlaying(bool v) {
    if (v && player.current == null) return;
    if (nowPlaying == v) return;
    nowPlaying = v;
    notifyListeners();
  }

  /// What the stage card on the home screen shows: 0 cover, 1 lyrics, 2 queue.
  int stageView = 0;
  void setStageView(int v) {
    if (player.current == null) return;
    stageView = (nowPlaying && stageView == v) ? 0 : v;
    nowPlaying = true;
    notifyListeners();
  }

  static const _tokenKey = 'ym_token';

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    lyricsOffset = prefs.getInt('lyrics_offset') ?? 0;
    final vol = prefs.getDouble('volume');
    if (vol != null) player.setVolume(vol);
    try {
      final h = jsonDecode(prefs.getString('history') ?? '[]');
      if (h is List) history = h.map(Track.fromJson).whereType<Track>().toList();
    } catch (_) {}
    final token = prefs.getString(_tokenKey);
    if (token != null && token.isNotEmpty) {
      try {
        await _login(token);
      } catch (_) {
        api = null;
      }
    }
    ready = true;
    notifyListeners();
  }

  /// Accepts either a raw token or the whole URL after redirect.
  Future<void> login(String input) async {
    final m = RegExp(r'access_token=([^&\s]+)').firstMatch(input);
    final token = (m?.group(1) ?? input).trim();
    if (token.isEmpty) throw ApiException('Вставь токен или ссылку');
    await _login(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    notifyListeners();
  }

  Future<void> _login(String token) async {
    final a = YandexApi(token);
    await a.init();
    api = a;
    refreshLibrary();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await player.stop();
    nowPlaying = false;
    _history
      ..clear()
      ..add(const AppRoute(PageKind.home));
    _pos = 0;
    _likedArtists = null;
    api = null;
    likedIds = {};
    playlists = [];
    notifyListeners();
  }

  Future<void> refreshLibrary() async {
    final a = api;
    if (a == null) return;
    try {
      likedIds = (await a.likedIds()).toSet();
      notifyListeners();
    } catch (_) {}
    try {
      playlists = await a.playlists();
      notifyListeners();
    } catch (_) {}
  }

  // ---------- navigation ----------

  void go(PageKind kind, [Object? arg]) {
    final wasOpen = nowPlaying;
    nowPlaying = false;
    if (route.kind == kind && route.arg == arg) {
      if (wasOpen) notifyListeners();
      return;
    }
    _history.removeRange(_pos + 1, _history.length);
    _history.add(AppRoute(kind, arg));
    _pos = _history.length - 1;
    navDir = 1;
    notifyListeners();
  }

  void back() {
    if (canBack) {
      navDir = -1;
      nowPlaying = false;
      _pos--;
      notifyListeners();
    }
  }

  void forward() {
    if (canForward) {
      navDir = 1;
      _pos++;
      notifyListeners();
    }
  }

  void search(String q) {
    searchQuery = q;
    if (route.kind != PageKind.search) {
      go(PageKind.search);
    } else {
      notifyListeners();
    }
  }

  // ---------- likes ----------

  bool isLiked(Track t) => likedIds.contains(t.id);

  /// Bumped whenever likes change so the likes page can reload.
  int likesRev = 0;

  Future<void> toggleLike(Track t) async {
    final like = !isLiked(t);
    like ? likedIds.add(t.id) : likedIds.remove(t.id);
    notifyListeners();
    try {
      await api!.setLike(t.id, like);
      likesRev++;
    } catch (e) {
      like ? likedIds.remove(t.id) : likedIds.add(t.id);
      notifyListeners();
      toast('Не получилось: $e');
    }
  }

  // ---------- подбор по вайбу ----------

  String vibeText = '';
  List<String> vibeTags = [];
  bool vibeBusy = false;
  Set<String>? _likedArtists;

  Future<Set<String>> _loadLikedArtists() async {
    if (_likedArtists != null) return _likedArtists!;
    try {
      final ids = (await api!.likedIds()).take(300).toList();
      final tracks = await api!.tracksByIds(ids);
      _likedArtists = {
        for (final t in tracks)
          for (final a in t.artists.toLowerCase().split(', '))
            if (a.isNotEmpty) a,
      };
    } catch (_) {
      _likedArtists = {};
    }
    return _likedArtists!;
  }

  /// Picks music for a free-text vibe and starts playing right away.
  Future<void> vibe(String text) async {
    final q = text.trim();
    if (q.isEmpty) {
      await startWave();
      return;
    }
    if (vibeBusy) return;
    vibeBusy = true;
    vibeText = q;
    final plan = VibeEngine.parse(q);
    vibeTags = plan.tags;
    notifyListeners();
    try {
      final liked = await _loadLikedArtists();
      final tracks = await VibeEngine.build(api!, plan, liked);
      if (tracks.isEmpty) {
        toast('Ничего не нашлось под «$q», попробуй сказать иначе');
      } else {
        final session = VibeSession(api!, plan, liked);
        await player.playList(tracks, 0, source: 'vibe', loadMore: session.more);
      }
    } catch (e) {
      toast('Не получилось подобрать: $e');
    } finally {
      vibeBusy = false;
      notifyListeners();
    }
  }

  // ---------- Моя волна ----------

  /// null = classic "Моя волна"; otherwise an activity station like 'activity:workout'.
  String? waveActivity;

  static const activities = {
    'activity:wake-up': 'Просыпаюсь',
    'activity:road-trip': 'В дороге',
    'activity:work-background': 'Работаю',
    'activity:workout': 'Тренируюсь',
    'activity:fall-asleep': 'Засыпаю',
  };

  void setActivity(String? a) {
    waveActivity = waveActivity == a ? null : a;
    startWave();
  }

  Future<void> startWave() async {
    final a = api!;
    final act = waveActivity;
    notifyListeners();
    if (act != null) {
      try {
        final tracks = await a.waveTracks(station: act);
        if (tracks.isEmpty) throw ApiException('пусто');
        await player.playList(tracks, 0,
            source: 'wave', loadMore: (last) => a.waveTracks(station: act, lastTrackId: last.id));
      } catch (e) {
        toast('Не удалось запустить волну: $e');
      }
      return;
    }
    try {
      await a.setWaveSettings(waveSettings);
    } catch (_) {
      // settings are optional, keep going
    }
    try {
      await a.waveFeedback('radioStarted');
      final tracks = await a.waveTracks();
      if (tracks.isEmpty) {
        toast('Волна ничего не вернула, попробуй другие настройки');
        return;
      }
      await player.playList(tracks, 0,
          source: 'wave', loadMore: (last) => a.waveTracks(lastTrackId: last.id));
    } catch (e) {
      toast('Не удалось запустить волну: $e');
    }
  }

  /// Endless radio built around one track.
  Future<void> startTrackWave(Track t) async {
    final a = api!;
    final st = 'track:${t.id}';
    try {
      final tracks = await a.waveTracks(station: st);
      await player.playList([t, ...tracks.where((x) => x.id != t.id)], 0,
          source: 'radio:${t.id}', loadMore: (last) => a.waveTracks(station: st, lastTrackId: last.id));
    } catch (e) {
      toast('Не удалось запустить волну по треку: $e');
    }
  }

  void openAlbumOf(Track t) {
    if (t.albumId == null) return;
    go(PageKind.album, Album(id: t.albumId!, title: t.albumTitle.isEmpty ? t.title : t.albumTitle, artists: t.artists, cover: t.cover));
  }

  void openArtistOf(Track t) {
    if (t.artistRefs.isEmpty) return;
    go(PageKind.artist, t.artistRefs.first);
  }

  void onTrackStarted(Track t, String? source) {
    _recordHistory(t);
    if (source == 'wave') api?.waveFeedback('trackStarted', track: t);
  }

  void onTrackFinished(Track t, String? source, Duration played) {
    if (source == 'wave') {
      api?.waveFeedback('trackFinished', track: t, playedSeconds: played.inMilliseconds / 1000);
    }
  }

  void onTrackSkipped(Track t, String? source, Duration played) {
    if (source == 'wave') {
      api?.waveFeedback('skip', track: t, playedSeconds: played.inMilliseconds / 1000);
    }
  }

  // ---------- misc ----------

  void toast(String msg) {
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, width: 420));
  }
}
