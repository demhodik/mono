import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';
import '../api/yandex_api.dart';
import 'player.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Global app state (single user, personal app).
late final AppState app;

enum PageKind { home, search, library, likes, wave, chart, releases, album, playlist }

class AppRoute {
  final PageKind kind;
  final Object? arg;
  const AppRoute(this.kind, [this.arg]);
}

class AppState extends ChangeNotifier {
  YandexApi? api;
  late final PlayerController player = PlayerController(this);

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
  bool nowPlaying = false;
  void setNowPlaying(bool v) {
    if (nowPlaying == v) return;
    nowPlaying = v;
    notifyListeners();
  }

  static const _tokenKey = 'ym_token';

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
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
    if (route.kind == kind && route.arg == arg && kind != PageKind.search) {
      if (wasOpen) notifyListeners();
      return;
    }
    _history.removeRange(_pos + 1, _history.length);
    _history.add(AppRoute(kind, arg));
    _pos = _history.length - 1;
    notifyListeners();
  }

  void back() {
    if (canBack) {
      _pos--;
      notifyListeners();
    }
  }

  void forward() {
    if (canForward) {
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

  Future<void> toggleLike(Track t) async {
    final like = !isLiked(t);
    like ? likedIds.add(t.id) : likedIds.remove(t.id);
    notifyListeners();
    try {
      await api!.setLike(t.id, like);
    } catch (e) {
      like ? likedIds.remove(t.id) : likedIds.add(t.id);
      notifyListeners();
      toast('Не получилось: $e');
    }
  }

  // ---------- Моя волна ----------

  Future<void> startWave() async {
    final a = api!;
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

  void onTrackStarted(Track t, String? source) {
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
