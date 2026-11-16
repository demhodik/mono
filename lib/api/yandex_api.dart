import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Minimal client for the (unofficial) Yandex Music API.
/// Works only with the owner's own OAuth token — personal use.
class YandexApi {
  static const _base = 'https://api.music.yandex.net';
  static const _signSalt = 'XGRlBW9FXlekgbPrRHuSiA';

  /// Client id of the official Yandex Music app (implicit OAuth flow).
  static const oauthUrl =
      'https://oauth.yandex.ru/authorize?response_type=token&client_id=23cabbbdc6cd418abb4b39c32c41195d';

  final String token;
  String? uid;
  String? displayName;

  YandexApi(this.token);

  final _client = http.Client();

  Map<String, String> get _headers => {
        'Authorization': 'OAuth $token',
        'X-Yandex-Music-Client': 'YandexMusicAndroid/24023621',
        'Accept-Language': 'ru',
      };

  dynamic _decode(http.Response r) {
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw ApiException('Токен недействителен или устарел. Войди заново.', r.statusCode);
    }
    if (r.statusCode >= 400) {
      throw ApiException('Ошибка Яндекса (${r.statusCode})', r.statusCode);
    }
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    return body is Map ? body['result'] : body;
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    var uri = Uri.parse('$_base$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    final r = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  Future<dynamic> _postForm(String path, Map<String, String> form) async {
    final r = await _client
        .post(Uri.parse('$_base$path'), headers: _headers, body: form)
        .timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  Future<dynamic> _postJson(String path, Object data) async {
    final r = await _client
        .post(Uri.parse('$_base$path'),
            headers: {..._headers, 'Content-Type': 'application/json'}, body: jsonEncode(data))
        .timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  // ---------- account ----------

  Future<void> init() async {
    final r = await _get('/account/status');
    final acc = r is Map ? r['account'] : null;
    if (acc is! Map || acc['uid'] == null) {
      throw ApiException('Не удалось получить аккаунт. Проверь токен.');
    }
    uid = acc['uid'].toString();
    displayName = (acc['displayName'] ?? acc['login'] ?? acc['firstName'])?.toString();
  }

  // ---------- tracks ----------

  List<Track> _tracks(dynamic list) =>
      (list is List ? list : const []).map(Track.fromJson).whereType<Track>().toList();

  Future<List<Track>> tracksByIds(List<String> ids) async {
    final out = <Track>[];
    for (var i = 0; i < ids.length; i += 100) {
      final chunk = ids.sublist(i, i + 100 > ids.length ? ids.length : i + 100);
      final r = await _postForm('/tracks', {'track-ids': chunk.join(','), 'with-positions': 'false'});
      out.addAll(_tracks(r));
    }
    return out;
  }

  /// Direct stream URL for a track (best available mp3).
  Future<String> streamUrl(String trackId) async {
    final infos = await _get('/tracks/$trackId/download-info');
    if (infos is! List || infos.isEmpty) {
      throw ApiException('Трек недоступен для прослушивания');
    }
    final mp3 = infos.whereType<Map>().where((m) => m['codec'] == 'mp3').toList();
    final pool = mp3.isNotEmpty ? mp3 : infos.whereType<Map>().toList();
    pool.sort((a, b) => ((b['bitrateInKbps'] as num?) ?? 0).compareTo((a['bitrateInKbps'] as num?) ?? 0));
    final info = pool.first;
    final codec = info['codec']?.toString() ?? 'mp3';
    var infoUrl = info['downloadInfoUrl'].toString();
    infoUrl += infoUrl.contains('?') ? '&format=json' : '?format=json';

    final r = await _client.get(Uri.parse(infoUrl), headers: _headers).timeout(const Duration(seconds: 20));
    final text = utf8.decode(r.bodyBytes);
    String host, path, ts, s;
    if (text.trimLeft().startsWith('<')) {
      String tag(String name) =>
          RegExp('<$name>([^<]*)</$name>').firstMatch(text)?.group(1) ?? '';
      host = tag('host');
      path = tag('path');
      ts = tag('ts');
      s = tag('s');
    } else {
      final j = jsonDecode(text) as Map;
      host = j['host'].toString();
      path = j['path'].toString();
      ts = j['ts'].toString();
      s = j['s'].toString();
    }
    if (host.isEmpty || path.isEmpty) throw ApiException('Не удалось получить ссылку на трек');
    final sign = md5.convert(utf8.encode('$_signSalt${path.substring(1)}$s')).toString();
    return 'https://$host/get-$codec/$sign/$ts$path';
  }

  Future<List<Track>> search(String text) async {
    final r = await _get('/search', {'text': text, 'type': 'track', 'page': '0', 'nocorrect': 'false'});
    final tracks = r is Map ? r['tracks'] : null;
    return _tracks(tracks is Map ? tracks['results'] : null);
  }

  Future<List<Playlist>> searchPlaylists(String text) async {
    final r = await _get('/search', {'text': text, 'type': 'playlist', 'page': '0', 'nocorrect': 'false'});
    final pl = r is Map ? r['playlists'] : null;
    final res = pl is Map ? pl['results'] : null;
    return (res is List ? res : const []).map(Playlist.fromJson).whereType<Playlist>().toList();
  }

  // ---------- lyrics ----------

  static const _lyricsKey = 'p93jhgh689SBReK6ghtw62';
  final _lyricsCache = <String, Lyrics>{};

  Future<Lyrics> lyrics(Track track) async {
    final trackId = track.id;
    final cached = _lyricsCache[trackId];
    if (cached != null) return cached;

    Future<Lyrics?> yandex(String format) async {
      final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final sign = base64.encode(Hmac(sha256, utf8.encode(_lyricsKey)).convert(utf8.encode('$trackId$ts')).bytes);
      try {
        final r = await _get('/tracks/$trackId/lyrics', {'format': format, 'timeStamp': ts, 'sign': sign});
        final url = r is Map ? r['downloadUrl']?.toString() : null;
        if (url == null) return null;
        final resp = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        final text = utf8.decode(resp.bodyBytes);
        if (format == 'LRC') {
          final l = Lyrics.parseLrc(text);
          return l.synced ? l : null;
        }
        return text.trim().isEmpty ? null : Lyrics(plain: text);
      } catch (_) {
        return null;
      }
    }

    // Free open lyrics database as a fallback (lrclib.net).
    Map? lrclibData;
    Future<Map?> lrclib() async {
      if (lrclibData != null) return lrclibData;
      final artist = track.artists.split(', ').first;
      final title = track.title.replaceAll(RegExp(r'\s*\(.*?\)'), '');
      try {
        final get = Uri.https('lrclib.net', '/api/get', {
          'artist_name': artist,
          'track_name': title,
          if (track.duration > Duration.zero) 'duration': '${track.duration.inSeconds}',
        });
        var r = await _client.get(get, headers: {'User-Agent': 'Mono (personal player)'}).timeout(const Duration(seconds: 12));
        if (r.statusCode == 200) return lrclibData = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
        final search = Uri.https('lrclib.net', '/api/search', {'track_name': title, 'artist_name': artist});
        r = await _client.get(search, headers: {'User-Agent': 'Mono (personal player)'}).timeout(const Duration(seconds: 12));
        if (r.statusCode == 200) {
          final list = jsonDecode(utf8.decode(r.bodyBytes));
          if (list is List && list.isNotEmpty) {
            final withSync = list.whereType<Map>().where((m) => (m['syncedLyrics'] ?? '').toString().isNotEmpty);
            return lrclibData = (withSync.isNotEmpty ? withSync.first : list.first) as Map;
          }
        }
      } catch (_) {}
      return null;
    }

    Future<Lyrics?> lrclibSynced() async {
      final m = await lrclib();
      final t = m?['syncedLyrics']?.toString() ?? '';
      if (t.isEmpty) return null;
      final l = Lyrics.parseLrc(t);
      return l.synced ? l : null;
    }

    Future<Lyrics?> lrclibPlain() async {
      final t = (await lrclib())?['plainLyrics']?.toString() ?? '';
      return t.trim().isEmpty ? null : Lyrics(plain: t);
    }

    final result = await yandex('LRC') ?? await lrclibSynced() ?? await yandex('TEXT') ?? await lrclibPlain() ?? const Lyrics();
    _lyricsCache[trackId] = result;
    return result;
  }

  // ---------- library ----------

  Future<List<String>> likedIds() async {
    final r = await _get('/users/$uid/likes/tracks');
    final list = (r is Map && r['library'] is Map) ? r['library']['tracks'] : null;
    if (list is! List) return [];
    return list.whereType<Map>().map((m) => m['id'].toString()).toList();
  }

  Future<List<Track>> likedTracks() async => tracksByIds(await likedIds());

  Future<void> setLike(String trackId, bool like) async {
    await _postForm(
        '/users/$uid/likes/tracks/${like ? 'add-multiple' : 'remove'}', {'track-ids': trackId});
  }

  Future<List<Playlist>> playlists() async {
    final r = await _get('/users/$uid/playlists/list');
    return (r is List ? r : const []).map(Playlist.fromJson).whereType<Playlist>().toList();
  }

  Future<List<Track>> playlistTracks(Playlist p) async {
    final r = await _get('/users/${p.owner.isEmpty ? uid : p.owner}/playlists/${p.kind}', {'rich-tracks': 'true'});
    final items = r is Map ? r['tracks'] : null;
    if (items is! List) return [];
    final full = <Track>[];
    final missing = <String>[];
    for (final it in items.whereType<Map>()) {
      final t = Track.fromJson(it['track']);
      if (t != null) {
        full.add(t);
      } else if (it['id'] != null) {
        missing.add(it['id'].toString());
      }
    }
    if (missing.isNotEmpty) full.addAll(await tracksByIds(missing));
    return full;
  }

  // ---------- discovery ----------

  Future<List<Track>> chart() async {
    final r = await _get('/landing3/chart');
    final chart = r is Map ? r['chart'] : null;
    final list = chart is Map ? chart['tracks'] : null;
    if (list is! List) return [];
    return list.whereType<Map>().map((m) => Track.fromJson(m['track'])).whereType<Track>().toList();
  }

  Future<List<Album>> newReleases() async {
    final r = await _get('/landing3/new-releases');
    final ids = r is Map ? r['newReleases'] : null;
    if (ids is! List || ids.isEmpty) return [];
    final res = await _postForm('/albums', {'album-ids': ids.take(60).join(',')});
    return (res is List ? res : const []).map(Album.fromJson).whereType<Album>().toList();
  }

  Future<List<Track>> albumTracks(String albumId) async {
    final r = await _get('/albums/$albumId/with-tracks');
    final volumes = r is Map ? r['volumes'] : null;
    if (volumes is! List) return [];
    return volumes.whereType<List>().expand((v) => _tracks(v)).toList();
  }

  // ---------- Моя волна ----------

  static const _wave = 'user:onyourwave';

  Future<void> setWaveSettings(WaveSettings s) async {
    await _postJson('/rotor/station/$_wave/settings3', {
      'moodEnergy': s.mood,
      'diversity': s.diversity,
      'language': s.language,
      'type': 'rotor',
    });
  }

  /// Next batch of wave tracks. Pass the last played id to continue the stream.
  Future<List<Track>> waveTracks({String? lastTrackId}) async {
    final r = await _get('/rotor/station/$_wave/tracks', {
      'settings2': 'true',
      if (lastTrackId != null) 'queue': lastTrackId,
    });
    final seq = r is Map ? r['sequence'] : null;
    if (seq is! List) return [];
    return seq.whereType<Map>().map((m) => Track.fromJson(m['track'])).whereType<Track>().toList();
  }

  Future<void> waveFeedback(String type, {Track? track, double? playedSeconds}) async {
    try {
      await _postJson('/rotor/station/$_wave/feedback', {
        'type': type,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'from': 'desktop_win-home-playlist_of_the_day-playlist-default',
        if (track != null) 'trackId': track.fullId,
        if (playedSeconds != null) 'totalPlayedSeconds': playedSeconds,
      });
    } catch (_) {
      // feedback is best-effort
    }
  }
}
