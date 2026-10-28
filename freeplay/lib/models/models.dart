/// A playable track from one of the free sources (Jamendo or Internet Archive).
class Track {
  const Track({
    required this.id,
    required this.source,
    required this.title,
    required this.artist,
    this.album = '',
    this.artUrl,
    this.streamUrl,
    this.downloadUrl,
    this.ext = 'mp3',
    this.downloadable = false,
    this.durationSec,
    this.localPath,
  });

  /// Unique across sources, e.g. "jamendo:123" or "archive:identifier/file.mp3".
  final String id;

  /// "jamendo" or "archive".
  final String source;
  final String title;
  final String artist;
  final String album;
  final String? artUrl;
  final String? streamUrl;
  final String? downloadUrl;
  final String ext;
  final bool downloadable;
  final int? durationSec;
  final String? localPath;

  Track copyWith({String? localPath, String? ext}) => Track(
        id: id,
        source: source,
        title: title,
        artist: artist,
        album: album,
        artUrl: artUrl,
        streamUrl: streamUrl,
        downloadUrl: downloadUrl,
        ext: ext ?? this.ext,
        downloadable: downloadable,
        durationSec: durationSec,
        localPath: localPath ?? this.localPath,
      );

  Track clearLocal() => Track(
        id: id,
        source: source,
        title: title,
        artist: artist,
        album: album,
        artUrl: artUrl,
        streamUrl: streamUrl,
        downloadUrl: downloadUrl,
        ext: ext,
        downloadable: downloadable,
        durationSec: durationSec,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'title': title,
        'artist': artist,
        'album': album,
        'artUrl': artUrl,
        'streamUrl': streamUrl,
        'downloadUrl': downloadUrl,
        'ext': ext,
        'downloadable': downloadable,
        'durationSec': durationSec,
        'localPath': localPath,
      };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: j['id'] as String,
        source: (j['source'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        artist: (j['artist'] ?? '') as String,
        album: (j['album'] ?? '') as String,
        artUrl: j['artUrl'] as String?,
        streamUrl: j['streamUrl'] as String?,
        downloadUrl: j['downloadUrl'] as String?,
        ext: (j['ext'] ?? 'mp3') as String,
        downloadable: j['downloadable'] == true,
        durationSec: j['durationSec'] as int?,
        localPath: j['localPath'] as String?,
      );
}

/// A playlist stored on this phone.
class LocalPlaylist {
  LocalPlaylist({required this.id, required this.name, List<Track>? tracks})
      : tracks = tracks ?? [];

  final String id;
  String name;
  final List<Track> tracks;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };

  factory LocalPlaylist.fromJson(Map<String, dynamic> j) => LocalPlaylist(
        id: j['id'] as String,
        name: j['name'] as String,
        tracks: ((j['tracks'] ?? []) as List)
            .map((e) => Track.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
