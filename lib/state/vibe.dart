import 'dart:math' as math;

import '../api/models.dart';
import '../api/yandex_api.dart';

/// Turns free text ("вайбовые песни для игры ночью") into a playable mix:
/// wave settings + themed Yandex playlists, boosted by the user's own taste.
class VibePlan {
  final WaveSettings settings;
  final List<String> queries;
  final List<String> tags; // human-readable understood tags
  final List<String> stationHints;
  final String text;
  VibePlan(this.settings, this.queries, this.tags, [this.stationHints = const [], this.text = '']);
}

class _Rule {
  final List<String> keys;
  final String? mood;
  final String? diversity;
  final String? language;
  final String? query;
  final String tag;
  final List<String> stations; // Yandex rotor station ids that fit
  const _Rule(this.keys, this.tag, {this.mood, this.diversity, this.language, this.query, this.stations = const []});
}

class VibeEngine {
  static const _rules = <_Rule>[
    // activities
    _Rule(['игр', 'гейм', 'катк', 'game', 'gaming'], 'для игр', mood: 'active', query: 'музыка для игр', stations: ['activity:gaming', 'genre:videogame', 'activity:workout']),
    _Rule(['трениров', 'спорт', 'зал', 'качал', 'бег', 'workout', 'gym'], 'тренировка',
        mood: 'active', query: 'для тренировки', stations: ['activity:workout', 'activity:run']),
    _Rule(['учеб', 'учёб', 'работ', 'фокус', 'концентр', 'focus', 'study', 'кодинг', 'код'], 'фокус',
        mood: 'calm', query: 'для концентрации', stations: ['activity:work-background', 'activity:study']),
    _Rule(['сон', 'спать', 'засып', 'sleep'], 'сон', mood: 'calm', query: 'для сна', stations: ['activity:fall-asleep', 'activity:sleep']),
    _Rule(['машин', 'дорог', 'драйв', 'drive', 'трасс', 'поездк'], 'дорога', mood: 'active', query: 'в дорогу', stations: ['activity:road-trip', 'activity:driving']),
    _Rule(['вечеринк', 'туса', 'тус', 'party', 'клуб', 'танц'], 'вечеринка', mood: 'fun', query: 'вечеринка', stations: ['activity:party', 'mood:party']),
    _Rule(['готов', 'кухн', 'утр', 'кофе'], 'утро', mood: 'fun', query: 'утреннее настроение', stations: ['activity:wake-up']),
    // time / atmosphere
    _Rule(['ноч', 'night', 'полноч', 'поздн'], 'ночь', query: 'ночной вайб', stations: ['mood:night', 'activity:night']),
    _Rule(['дожд', 'осен', 'rain'], 'дождь', mood: 'calm', query: 'дождливый вечер', stations: ['mood:rainy', 'mood:sad']),
    _Rule(['лет', 'солн', 'summer', 'пляж', 'мор'], 'лето', mood: 'fun', query: 'летнее настроение', stations: ['mood:summer', 'mood:happy']),
    _Rule(['зим', 'снег', 'новый год'], 'зима', mood: 'calm', query: 'зимнее настроение', stations: ['mood:winter']),
    // moods
    _Rule(['груст', 'печал', 'тоск', 'одинок', 'sad', 'депрес', 'плак'], 'грустное', mood: 'sad', query: 'грустные песни', stations: ['mood:sad']),
    _Rule(['спокой', 'расслаб', 'чил', 'chill', 'релакс', 'тих', 'мягк', 'атмосфер', 'вайбов'], 'спокойное',
        mood: 'calm', query: 'chill', stations: ['mood:calm', 'mood:chill']),
    _Rule(['весел', 'весёл', 'радост', 'позитив', 'happy', 'кайф'], 'весёлое', mood: 'fun', query: 'позитив', stations: ['mood:happy', 'mood:fun']),
    _Rule(['энерг', 'бодр', 'жестк', 'жёстк', 'агрессив', 'мощн', 'качов', 'качев'], 'бодрое',
        mood: 'active', query: 'энергичная музыка', stations: ['mood:energetic', 'mood:aggressive']),
    _Rule(['романт', 'любов', 'love', 'свидан'], 'романтика', mood: 'calm', query: 'о любви', stations: ['mood:romantic', 'mood:love']),
    // genres
    _Rule(['фонк', 'phonk'], 'фонк', mood: 'active', query: 'phonk', stations: ['genre:phonk']),
    _Rule(['рэп', 'реп', 'хип', 'rap', 'hip'], 'рэп', query: 'рэп', stations: ['genre:rap', 'genre:rusrap', 'genre:foreignrap']),
    _Rule(['рок', 'rock', 'панк'], 'рок', query: 'рок', stations: ['genre:rock', 'genre:rusrock']),
    _Rule(['метал', 'metal'], 'метал', mood: 'active', query: 'метал', stations: ['genre:metal']),
    _Rule(['электрон', 'техно', 'хаус', 'edm', 'house', 'techno'], 'электроника', query: 'электроника', stations: ['genre:electronics', 'genre:techno', 'genre:house']),
    _Rule(['лофи', 'lo-fi', 'lofi', 'лоу фай'], 'lo-fi', mood: 'calm', query: 'lofi', stations: ['genre:lofi']),
    _Rule(['синтвейв', 'synthwave', 'ретровейв', 'retrowave', '80'], 'синтвейв', query: 'synthwave', stations: ['genre:synthwave']),
    _Rule(['джаз', 'jazz'], 'джаз', mood: 'calm', query: 'джаз', stations: ['genre:jazz']),
    _Rule(['класси', 'classic', 'оркестр', 'пиано', 'пианино'], 'классика', mood: 'calm', query: 'классическая музыка', stations: ['genre:classicalmusic', 'genre:classical']),
    _Rule(['инди', 'indie'], 'инди', query: 'инди', stations: ['genre:indie']),
    _Rule(['поп', 'pop'], 'поп', query: 'поп', stations: ['genre:pop', 'genre:ruspop']),
    _Rule(['саундтрек', 'ost', 'эпич', 'кино'], 'эпичное', mood: 'active', query: 'эпичные саундтреки', stations: ['genre:soundtrack']),
    // language / novelty
    _Rule(['русск', 'на русском'], 'на русском', language: 'russian'),
    _Rule(['англ', 'зарубеж', 'иностран', 'english', 'foreign'], 'зарубежное', language: 'not-russian'),
    _Rule(['нов', 'незнаком', 'свеж', 'открыт'], 'новое для меня', diversity: 'discover'),
    _Rule(['любим', 'знаком', 'моё', 'мое'], 'любимое', diversity: 'favorite'),
    _Rule(['популяр', 'хит', 'топ'], 'хиты', diversity: 'popular'),
  ];

  static VibePlan parse(String text) {
    final t = text.toLowerCase().replaceAll('ё', 'е');
    final s = WaveSettings();
    final queries = <String>[];
    final tags = <String>[];
    for (final r in _rules) {
      if (r.keys.any((k) => t.contains(k.replaceAll('ё', 'е')))) {
        tags.add(r.tag);
        if (r.mood != null && s.mood == 'all') s.mood = r.mood!;
        if (r.diversity != null) s.diversity = r.diversity!;
        if (r.language != null) s.language = r.language!;
        if (r.query != null) queries.add(r.query!);
      }
    }
    // the raw text is often the best search query itself
    final cleaned = text.trim();
    final combined = queries.take(2).join(' ');
    final hints = <String>[
      for (final r in _rules)
        if (r.keys.any((k) => t.contains(k.replaceAll('ё', 'е')))) ...r.stations,
    ];
    return VibePlan(
        s, [if (cleaned.isNotEmpty) cleaned, if (combined.isNotEmpty) combined, ...queries.take(3)], tags, hints, cleaned);
  }

  static String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е');

  /// Picks Yandex radio stations that fit the request: rule hints that exist,
  /// plus stations whose russian name matches words of the request.
  static Future<List<String>> resolveStations(YandexApi api, VibePlan plan) async {
    List<(String, String)> all;
    try {
      all = await api.stations();
    } catch (_) {
      all = const [];
    }
    final ids = {for (final e in all) e.$1};
    final words = _norm(plan.text).split(RegExp(r'[^a-zа-я0-9]+')).where((w) => w.length >= 3).toList();
    final scored = <(int, String)>[];
    for (final (id, name) in all) {
      final nw = _norm(name).split(RegExp(r'[^a-zа-я0-9]+')).where((w) => w.length >= 3).toList();
      var score = 0;
      for (final w in words) {
        final stem = w.substring(0, math.min(5, w.length));
        if (nw.any((n) => n.startsWith(stem) || (n.length >= 4 && w.startsWith(n.substring(0, math.min(5, n.length)))))) {
          score += 2;
        }
      }
      if (score > 0) scored.add((score, id));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    final picked = <String>[];
    void add(String id) {
      if (!picked.contains(id) && picked.length < 4) picked.add(id);
    }

    for (final e in scored.take(2)) {
      add(e.$2);
    }
    for (final h in plan.stationHints) {
      if (ids.isEmpty || ids.contains(h)) add(h);
    }
    for (final e in scored.skip(2)) {
      add(e.$2);
    }
    return picked;
  }

  /// Builds the first batch. Returns tracks and a session that continues forever.
  static Future<(List<Track>, VibeSession)> start(YandexApi api, VibePlan plan, Set<String> liked) async {
    final session = VibeSession(api, plan, liked, await resolveStations(api, plan));
    final first = await session.more(null);
    return (first, session);
  }

  static Future<List<Track>> playlistMix(YandexApi api, VibePlan plan, Set<String> likedArtists) async {
    final rnd = math.Random();

    // 1) wave tuned to the vibe
    final waveF = () async {
      try {
        await api.setWaveSettings(plan.settings);
        return await api.waveTracks();
      } catch (_) {
        return <Track>[];
      }
    }();

    // 2) themed playlists from Yandex search
    final seen = <String>{};
    final playlists = <Playlist>[];
    for (final q in plan.queries.toSet().take(3)) {
      try {
        for (final p in (await api.searchPlaylists(q)).take(2)) {
          if (seen.add('${p.owner}:${p.kind}')) playlists.add(p);
        }
      } catch (_) {}
      if (playlists.length >= 4) break;
    }
    final lists = await Future.wait(playlists.take(4).map((p) async {
      try {
        return (await api.playlistTracks(p)).take(80).toList();
      } catch (_) {
        return <Track>[];
      }
    }));

    // 3) score: liked artists first, earlier playlists slightly higher, plus randomness
    final ids = <String>{};
    final scored = <(double, Track)>[];
    for (var li = 0; li < lists.length; li++) {
      for (final t in lists[li]) {
        if (!t.available || !ids.add(t.id)) continue;
        final artists = t.artists.toLowerCase().split(', ');
        final known = artists.any(likedArtists.contains);
        scored.add(((known ? 1.4 : 0) + (0.5 - li * 0.1) + rnd.nextDouble(), t));
      }
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    final themed = scored.take(36).map((e) => e.$2).toList();

    // 4) interleave: 2 themed + 1 from the tuned wave
    final wave = (await waveF).where((t) => ids.add(t.id)).toList();
    final out = <Track>[];
    var w = 0;
    for (var i = 0; i < themed.length; i++) {
      out.add(themed[i]);
      if (i % 2 == 1 && w < wave.length) out.add(wave[w++]);
    }
    out.addAll(wave.skip(w));
    return out;
  }
}

/// Endless vibe stream: round-robin over the chosen Yandex stations (each one
/// personalised by Yandex and continued with its own last track), plus the
/// tuned personal wave; themed playlists only as a fallback.
class VibeSession {
  final YandexApi api;
  final VibePlan plan;
  final Set<String> liked;
  final List<String> stations;
  final _last = <String, String>{};
  final _seen = <String>{};
  late final _PlaylistSession _fallback = _PlaylistSession(api, plan, liked);
  bool _waveTuned = false;

  VibeSession(this.api, this.plan, this.liked, this.stations);

  bool get _hasMood =>
      plan.settings.mood != 'all' || plan.settings.diversity != 'default' || plan.settings.language != 'any';

  Future<List<Track>> _station(String st) async {
    try {
      final t = await api.waveTracks(station: st, lastTrackId: _last[st]);
      if (t.isNotEmpty) _last[st] = t.last.id;
      return t;
    } catch (_) {
      return const [];
    }
  }

  Future<List<Track>> more(Track? last) async {
    final sources = <Future<List<Track>>>[
      for (final st in stations) _station(st),
      if (_hasMood || stations.isEmpty)
        () async {
          try {
            if (!_waveTuned) {
              await api.setWaveSettings(plan.settings);
              _waveTuned = true;
            }
            return await api.waveTracks(lastTrackId: _last['wave']);
          } catch (_) {
            return <Track>[];
          }
        }(),
    ];
    final lists = await Future.wait(sources);
    final out = <Track>[];
    var i = 0;
    while (true) {
      var added = false;
      for (final l in lists) {
        if (i < l.length) {
          added = true;
          final t = l[i];
          if (t.available && _seen.add(t.id)) out.add(t);
        }
      }
      if (!added) break;
      i++;
    }
    if (lists.isNotEmpty && lists.last.isNotEmpty && (_hasMood || stations.isEmpty)) _last['wave'] = lists.last.last.id;
    if (out.length < 6) {
      // nothing fitting on the radio side: dig into themed playlists
      final extra = last == null ? await VibeEngine.playlistMix(api, plan, liked) : await _fallback.more(last);
      for (final t in extra) {
        if (_seen.add(t.id)) out.add(t);
      }
    }
    return out;
  }
}

class _PlaylistSession {
  final YandexApi api;
  final VibePlan plan;
  final Set<String> liked;
  final _seenPlaylists = <String>{};
  int _round = 0;

  _PlaylistSession(this.api, this.plan, this.liked);

  Future<List<Track>> more(Track last) async {
    final rnd = math.Random();
    final queries = plan.queries.toSet().toList();
    final out = <Track>[];
    // try a few query/page combos until something new turns up
    for (var attempt = 0; attempt < 4 && out.length < 15 && queries.isNotEmpty; attempt++) {
      final q = queries[_round % queries.length];
      final page = _round ~/ queries.length;
      _round++;
      try {
        final pls = (await api.searchPlaylists(q, page: page))
            .where((p) => _seenPlaylists.add('${p.owner}:${p.kind}'))
            .take(2)
            .toList();
        for (final p in pls) {
          final tracks = (await api.playlistTracks(p)).where((t) => t.available).toList()..shuffle(rnd);
          tracks.sort((a, b) {
            final ka = a.artists.toLowerCase().split(', ').any(liked.contains) ? 0 : 1;
            final kb = b.artists.toLowerCase().split(', ').any(liked.contains) ? 0 : 1;
            return ka.compareTo(kb);
          });
          out.addAll(tracks.take(12));
        }
      } catch (_) {}
    }
    try {
      final wave = await api.waveTracks(station: 'track:${last.id}');
      for (var i = 0; i < wave.length; i++) {
        out.insert(math.min(out.length, i * 3 + 2), wave[i]);
      }
    } catch (_) {}
    return out;
  }
}
