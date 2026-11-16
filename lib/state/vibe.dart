import 'dart:math' as math;

import '../api/models.dart';
import '../api/yandex_api.dart';

/// Turns free text ("вайбовые песни для игры ночью") into a playable mix:
/// wave settings + themed Yandex playlists, boosted by the user's own taste.
class VibePlan {
  final WaveSettings settings;
  final List<String> queries;
  final List<String> tags; // human-readable understood tags
  VibePlan(this.settings, this.queries, this.tags);
}

class _Rule {
  final List<String> keys;
  final String? mood;
  final String? diversity;
  final String? language;
  final String? query;
  final String tag;
  const _Rule(this.keys, this.tag, {this.mood, this.diversity, this.language, this.query});
}

class VibeEngine {
  static const _rules = <_Rule>[
    // activities
    _Rule(['игр', 'гейм', 'катк', 'game', 'gaming'], 'для игр', mood: 'active', query: 'музыка для игр'),
    _Rule(['трениров', 'спорт', 'зал', 'качал', 'бег', 'workout', 'gym'], 'тренировка',
        mood: 'active', query: 'для тренировки'),
    _Rule(['учеб', 'учёб', 'работ', 'фокус', 'концентр', 'focus', 'study', 'кодинг', 'код'], 'фокус',
        mood: 'calm', query: 'для концентрации'),
    _Rule(['сон', 'спать', 'засып', 'sleep'], 'сон', mood: 'calm', query: 'для сна'),
    _Rule(['машин', 'дорог', 'драйв', 'drive', 'трасс', 'поездк'], 'дорога', mood: 'active', query: 'в дорогу'),
    _Rule(['вечеринк', 'туса', 'тус', 'party', 'клуб', 'танц'], 'вечеринка', mood: 'fun', query: 'вечеринка'),
    _Rule(['готов', 'кухн', 'утр', 'кофе'], 'утро', mood: 'fun', query: 'утреннее настроение'),
    // time / atmosphere
    _Rule(['ноч', 'night', 'полноч', 'поздн'], 'ночь', query: 'ночной вайб'),
    _Rule(['дожд', 'осен', 'rain'], 'дождь', mood: 'calm', query: 'дождливый вечер'),
    _Rule(['лет', 'солн', 'summer', 'пляж', 'мор'], 'лето', mood: 'fun', query: 'летнее настроение'),
    _Rule(['зим', 'снег', 'новый год'], 'зима', mood: 'calm', query: 'зимнее настроение'),
    // moods
    _Rule(['груст', 'печал', 'тоск', 'одинок', 'sad', 'депрес', 'плак'], 'грустное', mood: 'sad', query: 'грустные песни'),
    _Rule(['спокой', 'расслаб', 'чил', 'chill', 'релакс', 'тих', 'мягк', 'атмосфер', 'вайбов'], 'спокойное',
        mood: 'calm', query: 'chill'),
    _Rule(['весел', 'весёл', 'радост', 'позитив', 'happy', 'кайф'], 'весёлое', mood: 'fun', query: 'позитив'),
    _Rule(['энерг', 'бодр', 'жестк', 'жёстк', 'агрессив', 'мощн', 'качов', 'качев'], 'бодрое',
        mood: 'active', query: 'энергичная музыка'),
    _Rule(['романт', 'любов', 'love', 'свидан'], 'романтика', mood: 'calm', query: 'о любви'),
    // genres
    _Rule(['фонк', 'phonk'], 'фонк', mood: 'active', query: 'phonk'),
    _Rule(['рэп', 'реп', 'хип', 'rap', 'hip'], 'рэп', query: 'рэп'),
    _Rule(['рок', 'rock', 'панк'], 'рок', query: 'рок'),
    _Rule(['метал', 'metal'], 'метал', mood: 'active', query: 'метал'),
    _Rule(['электрон', 'техно', 'хаус', 'edm', 'house', 'techno'], 'электроника', query: 'электроника'),
    _Rule(['лофи', 'lo-fi', 'lofi', 'лоу фай'], 'lo-fi', mood: 'calm', query: 'lofi'),
    _Rule(['синтвейв', 'synthwave', 'ретровейв', 'retrowave', '80'], 'синтвейв', query: 'synthwave'),
    _Rule(['джаз', 'jazz'], 'джаз', mood: 'calm', query: 'джаз'),
    _Rule(['класси', 'classic', 'оркестр', 'пиано', 'пианино'], 'классика', mood: 'calm', query: 'классическая музыка'),
    _Rule(['инди', 'indie'], 'инди', query: 'инди'),
    _Rule(['поп', 'pop'], 'поп', query: 'поп'),
    _Rule(['саундтрек', 'ost', 'эпич', 'кино'], 'эпичное', mood: 'active', query: 'эпичные саундтреки'),
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
    return VibePlan(s, [if (cleaned.isNotEmpty) cleaned, if (combined.isNotEmpty) combined, ...queries.take(3)], tags);
  }

  /// Builds the mix. [likedArtists] are lower-cased names from the user's likes.
  static Future<List<Track>> build(YandexApi api, VibePlan plan, Set<String> likedArtists) async {
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

/// Keeps a vibe going forever: every call digs into the next page of themed
/// playlists (rotating through all understood queries), mixed with the tuned wave.
class VibeSession {
  final YandexApi api;
  final VibePlan plan;
  final Set<String> liked;
  final _seenPlaylists = <String>{};
  int _round = 0;

  VibeSession(this.api, this.plan, this.liked);

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
