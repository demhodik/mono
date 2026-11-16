import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' hide Track;

import '../api/models.dart';
import 'app_state.dart';

enum Repeat { off, all, one }

typedef LoadMore = Future<List<Track>> Function(Track last);

class PlayerController extends ChangeNotifier {
  final AppState app;
  final Player _player = Player();

  PlayerController(this.app) {
    _subs.addAll([
      _player.stream.playing.listen((v) {
        playing = v;
        notifyListeners();
      }),
      _player.stream.position.listen((p) {
        position.value = p;
        // fallback end detection: some files never emit `completed`
        final d = duration.value;
        if (playing && !loading && _realDuration && d > const Duration(seconds: 2) && p >= d - const Duration(milliseconds: 250)) {
          _onEnded();
        }
      }),
      _player.stream.duration.listen((d) {
        if (d > Duration.zero) {
          duration.value = d;
          _realDuration = true;
        }
      }),
      _player.stream.completed.listen((done) {
        if (done && !loading) _onEnded();
      }),
      _player.stream.error.listen((e) {
        if (e.isNotEmpty) debugPrint('player error: $e');
      }),
    ]);
    _player.setVolume(volume);
  }

  final _subs = <StreamSubscription>[];

  List<Track> queue = [];
  List<Track> _ordered = [];
  int index = -1;
  bool playing = false;
  bool loading = false;
  bool shuffle = false;
  Repeat repeat = Repeat.off;
  double volume = 70;
  double _volumeBeforeMute = 70;

  /// Identifies what is playing (e.g. "likes", "wave", "playlist:3").
  String? source;
  LoadMore? _loadMore;
  int _request = 0;
  int _failsInRow = 0;

  final position = ValueNotifier<Duration>(Duration.zero);
  final duration = ValueNotifier<Duration>(Duration.zero);

  Track? get current => (index >= 0 && index < queue.length) ? queue[index] : null;
  bool isCurrent(Track t) => current?.id == t.id;

  Future<void> playList(List<Track> tracks, int start, {String? source, LoadMore? loadMore}) async {
    if (tracks.isEmpty) return;
    this.source = source;
    _loadMore = loadMore;
    _ordered = List.of(tracks);
    queue = List.of(tracks);
    index = start.clamp(0, queue.length - 1);
    if (shuffle) _shuffleRest();
    await _playIndex(index);
  }

  /// Plays a whole list (optionally shuffled) from the beginning.
  Future<void> playAll(List<Track> tracks, {String? source, bool shuffled = false}) async {
    if (tracks.isEmpty) return;
    if (shuffled) {
      shuffle = true;
      final list = List.of(tracks)..shuffle();
      _ordered = List.of(tracks);
      this.source = source;
      _loadMore = null;
      queue = list;
      index = 0;
      await _playIndex(0);
    } else {
      await playList(tracks, 0, source: source);
    }
  }

  Future<void> _playIndex(int i) async {
    if (i < 0 || i >= queue.length) return;
    index = i;
    final track = queue[i];
    final req = ++_request;
    loading = true;
    _realDuration = false;
    position.value = Duration.zero;
    duration.value = track.duration;
    notifyListeners();
    app.onTrackStarted(track, source);
    try {
      final url = await app.api!.streamUrl(track.id);
      if (req != _request) return;
      await _player.open(Media(url), play: true);
      _failsInRow = 0;
    } catch (e) {
      if (req != _request) return;
      _failsInRow++;
      app.toast('«${track.title}»: $e');
      if (_failsInRow < 5) {
        loading = false;
        await next(auto: true);
        return;
      }
    }
    if (req == _request) {
      loading = false;
      notifyListeners();
    }
  }

  int _endedFor = -1;
  bool _realDuration = false;

  void _onEnded() {
    if (_endedFor == _request) return; // already handled for this track
    _endedFor = _request;
    final t = current;
    if (t != null) app.onTrackFinished(t, source, duration.value);
    if (repeat == Repeat.one) {
      _endedFor = -1;
      _player.seek(Duration.zero);
      _player.play();
      return;
    }
    next(auto: true);
  }

  Future<void> next({bool auto = false}) async {
    final t = current;
    if (!auto && t != null) app.onTrackSkipped(t, source, position.value);
    if (index + 1 < queue.length) {
      await _playIndex(index + 1);
      return;
    }
    if (_loadMore != null && t != null) {
      loading = true;
      notifyListeners();
      try {
        final more = await _loadMore!(t);
        final known = queue.map((e) => e.id).toSet();
        final fresh = more.where((e) => !known.contains(e.id)).toList();
        if (fresh.isNotEmpty) {
          queue.addAll(fresh);
          _ordered.addAll(fresh);
          await _playIndex(index + 1);
          return;
        }
      } catch (e) {
        app.toast('Не удалось загрузить продолжение: $e');
      }
      loading = false;
    }
    if (repeat == Repeat.all && queue.isNotEmpty) {
      await _playIndex(0);
      return;
    }
    await _player.pause();
    notifyListeners();
  }

  Future<void> previous() async {
    if (position.value > const Duration(seconds: 3) || index <= 0) {
      await _player.seek(Duration.zero);
      return;
    }
    await _playIndex(index - 1);
  }

  Future<void> playAt(int i) => _playIndex(i);

  Future<void> stop() async {
    _request++;
    await _player.stop();
    queue = [];
    _ordered = [];
    index = -1;
    loading = false;
    source = null;
    _loadMore = null;
    position.value = Duration.zero;
    duration.value = Duration.zero;
    notifyListeners();
  }

  /// Inserts a track right after the current one.
  void playNext(Track t) {
    if (current == null) {
      playList([t], 0, source: 'single');
      return;
    }
    queue.removeWhere((e) => e.id == t.id && e.id != current!.id);
    index = queue.indexWhere((e) => e.id == current!.id).clamp(0, queue.length - 1);
    queue.insert(index + 1, t);
    _ordered.removeWhere((e) => e.id == t.id);
    final oi = _ordered.indexWhere((e) => e.id == current!.id);
    _ordered.insert(oi < 0 ? _ordered.length : oi + 1, t);
    notifyListeners();
  }

  void enqueue(Track t) {
    if (current == null) {
      playList([t], 0, source: 'single');
      return;
    }
    if (queue.any((e) => e.id == t.id)) return;
    queue.add(t);
    _ordered.add(t);
    notifyListeners();
  }

  void removeAt(int i) {
    if (i <= index || i >= queue.length) return;
    final t = queue.removeAt(i);
    _ordered.removeWhere((e) => e.id == t.id);
    notifyListeners();
  }

  // ----- sleep timer -----
  DateTime? sleepAt;
  Timer? _sleepTimer;

  void setSleep(Duration? d) {
    _sleepTimer?.cancel();
    sleepAt = d == null ? null : DateTime.now().add(d);
    if (d != null) {
      _sleepTimer = Timer(d, () {
        sleepAt = null;
        _player.pause();
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    if (current == null || loading) return;
    await _player.playOrPause();
  }

  Future<void> seek(Duration d) async {
    if (current == null || loading) return;
    if (d < Duration.zero) d = Duration.zero;
    position.value = d;
    _endedFor = -1;
    await _player.seek(d);
  }

  void setVolume(double v) {
    volume = v.clamp(0, 100).toDouble();
    _player.setVolume(volume);
    app.volumeChanged();
    notifyListeners();
  }

  void toggleMute() {
    if (volume > 0) {
      _volumeBeforeMute = volume;
      setVolume(0);
    } else {
      setVolume(_volumeBeforeMute == 0 ? 70 : _volumeBeforeMute);
    }
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    final cur = current;
    if (shuffle) {
      _shuffleRest();
    } else if (cur != null) {
      queue = List.of(_ordered);
      index = queue.indexWhere((t) => t.id == cur.id);
    }
    notifyListeners();
  }

  void _shuffleRest() {
    if (index < 0 || index >= queue.length) return;
    final cur = queue[index];
    final rest = List.of(queue)..removeAt(index);
    rest.shuffle();
    queue = [cur, ...rest];
    index = 0;
  }

  void cycleRepeat() {
    repeat = Repeat.values[(repeat.index + 1) % Repeat.values.length];
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
