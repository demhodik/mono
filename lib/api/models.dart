String? coverUrl(String? uri, [int size = 400]) {
  if (uri == null || uri.isEmpty) return null;
  final u = uri.replaceAll('%%', '${size}x$size');
  return u.startsWith('http') ? u : 'https://$u';
}

String _artists(dynamic list) {
  if (list is! List) return '';
  return list
      .map((a) => (a is Map ? a['name'] : null)?.toString() ?? '')
      .where((s) => s.isNotEmpty)
      .join(', ');
}

class ArtistRef {
  final String id;
  final String name;
  const ArtistRef(this.id, this.name);
  @override
  bool operator ==(Object o) => o is ArtistRef && o.id == id;
  @override
  int get hashCode => id.hashCode;
}

class Track {
  final String id;
  final String title;
  final String artists;
  final String? albumId;
  final String? cover;
  final Duration duration;
  final bool available;
  final bool hasSyncLyrics;
  final bool hasLyrics;
  final List<ArtistRef> artistRefs;
  final String albumTitle;

  Track({
    required this.id,
    required this.title,
    required this.artists,
    this.albumId,
    this.cover,
    this.duration = Duration.zero,
    this.available = true,
    this.hasSyncLyrics = false,
    this.hasLyrics = false,
    this.artistRefs = const [],
    this.albumTitle = '',
  });

  String coverOf([int size = 400]) => coverUrl(cover, size) ?? '';

  static Track? fromJson(dynamic j) {
    if (j is! Map) return null;
    final id = j['id']?.toString();
    if (id == null) return null;
    final albums = j['albums'];
    String? albumId;
    var albumTitle = '';
    String? cover = j['coverUri']?.toString();
    final refs = <ArtistRef>[];
    if (j['artists'] is List) {
      for (final a in j['artists']) {
        if (a is Map && a['id'] != null) refs.add(ArtistRef(a['id'].toString(), a['name']?.toString() ?? ''));
      }
    }
    if (albums is List && albums.isNotEmpty && albums.first is Map) {
      albumId = albums.first['id']?.toString();
      albumTitle = albums.first['title']?.toString() ?? '';
      cover ??= albums.first['coverUri']?.toString();
    }
    var title = j['title']?.toString() ?? 'Без названия';
    final version = j['version']?.toString();
    if (version != null && version.isNotEmpty) title = '$title ($version)';
    return Track(
      id: id,
      title: title,
      artists: _artists(j['artists']),
      albumId: albumId,
      cover: cover ?? j['ogImage']?.toString(),
      duration: Duration(milliseconds: (j['durationMs'] as num?)?.toInt() ?? 0),
      available: j['available'] != false,
      artistRefs: refs,
      albumTitle: albumTitle,
      hasSyncLyrics: j['lyricsInfo'] is Map && j['lyricsInfo']['hasAvailableSyncLyrics'] == true,
      hasLyrics: j['lyricsInfo'] is Map &&
          (j['lyricsInfo']['hasAvailableTextLyrics'] == true || j['lyricsInfo']['hasAvailableSyncLyrics'] == true),
    );
  }

  /// Same shape the API uses, so history can be restored with [fromJson].
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artists': [
          for (final a in artistRefs) {'id': a.id, 'name': a.name},
        ],
        'albums': [
          if (albumId != null) {'id': albumId, 'title': albumTitle},
        ],
        'coverUri': cover,
        'durationMs': duration.inMilliseconds,
      };

  /// Full id used by some endpoints: "trackId:albumId".
  String get fullId => albumId == null ? id : '$id:$albumId';
}

class Album {
  @override
  bool operator ==(Object o) => o is Album && o.id == id;
  @override
  int get hashCode => id.hashCode;
  final String id;
  final String title;
  final String artists;
  final String? cover;
  final int? year;

  Album({required this.id, required this.title, required this.artists, this.cover, this.year});

  String coverOf([int size = 400]) => coverUrl(cover, size) ?? '';

  static Album? fromJson(dynamic j) {
    if (j is! Map || j['id'] == null) return null;
    return Album(
      id: j['id'].toString(),
      title: j['title']?.toString() ?? '',
      artists: _artists(j['artists']),
      cover: j['coverUri']?.toString(),
      year: (j['year'] as num?)?.toInt(),
    );
  }
}

class Playlist {
  @override
  bool operator ==(Object o) => o is Playlist && o.kind == kind && o.owner == owner;
  @override
  int get hashCode => Object.hash(kind, owner);
  final String kind;
  final String owner;
  final String title;
  final int trackCount;
  final String? cover;

  Playlist({required this.kind, required this.owner, required this.title, required this.trackCount, this.cover});

  String coverOf([int size = 400]) => coverUrl(cover, size) ?? '';

  static Playlist? fromJson(dynamic j) {
    if (j is! Map || j['kind'] == null) return null;
    String? cover;
    final c = j['cover'];
    if (c is Map) {
      cover = c['uri']?.toString();
      final items = c['itemsUri'];
      if (cover == null && items is List && items.isNotEmpty) cover = items.first.toString();
    }
    cover ??= j['ogImage']?.toString();
    final owner = j['owner'] is Map ? j['owner']['uid']?.toString() : null;
    return Playlist(
      kind: j['kind'].toString(),
      owner: owner ?? j['uid']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      trackCount: (j['trackCount'] as num?)?.toInt() ?? 0,
      cover: cover,
    );
  }
}

/// Settings of "Моя волна".
class WaveSettings {
  String mood; // all, active, fun, calm, sad
  String diversity; // default, favorite, discover, popular
  String language; // any, russian, not-russian

  WaveSettings({this.mood = 'all', this.diversity = 'default', this.language = 'any'});
}

class LyricLine {
  final Duration time;
  final String text;
  const LyricLine(this.time, this.text);
}

class Lyrics {
  /// Time-synced lines (karaoke). Empty if only plain text exists.
  final List<LyricLine> lines;
  final String plain;
  const Lyrics({this.lines = const [], this.plain = ''});
  bool get synced => lines.isNotEmpty;
  bool get isEmpty => lines.isEmpty && plain.trim().isEmpty;

  static Lyrics parseLrc(String text) {
    final out = <LyricLine>[];
    final re = RegExp(r'\[(\d+):(\d+(?:[.,]\d+)?)\]');
    for (final raw in text.split('\n')) {
      final ms = re.allMatches(raw).toList();
      if (ms.isEmpty) continue;
      final words = raw.replaceAll(re, '').trim();
      for (final m in ms) {
        final min = int.parse(m.group(1)!);
        final sec = double.parse(m.group(2)!.replaceAll(',', '.'));
        out.add(LyricLine(Duration(milliseconds: ((min * 60 + sec) * 1000).round()), words));
      }
    }
    out.sort((a, b) => a.time.compareTo(b.time));
    return Lyrics(lines: out);
  }

  /// Index of the line active at [pos], or -1.
  int indexAt(Duration pos) {
    var lo = 0, hi = lines.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].time <= pos) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }
}

class Artist {
  final String id;
  final String name;
  final String? cover;
  const Artist({required this.id, required this.name, this.cover});
  String coverOf([int size = 400]) => coverUrl(cover, size) ?? '';

  static Artist? fromJson(dynamic j) {
    if (j is! Map || j['id'] == null) return null;
    final c = j['cover'];
    return Artist(
      id: j['id'].toString(),
      name: j['name']?.toString() ?? '',
      cover: (c is Map ? c['uri']?.toString() : null) ?? j['ogImage']?.toString(),
    );
  }
}

class ArtistInfo {
  final Artist artist;
  final List<Track> popular;
  final List<Album> albums;
  const ArtistInfo(this.artist, this.popular, this.albums);
}

class SearchResult {
  final List<Track> tracks;
  final List<Album> albums;
  final List<Artist> artists;
  final List<Playlist> playlists;
  const SearchResult({this.tracks = const [], this.albums = const [], this.artists = const [], this.playlists = const []});
  bool get isEmpty => tracks.isEmpty && albums.isEmpty && artists.isEmpty && playlists.isEmpty;
}
