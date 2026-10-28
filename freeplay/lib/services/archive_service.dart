import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class ArchiveAlbum {
  const ArchiveAlbum({
    required this.identifier,
    required this.title,
    required this.creator,
  });

  final String identifier;
  final String title;
  final String creator;

  String get artUrl => 'https://archive.org/services/img/$identifier';
}

/// Searches the Internet Archive for audio that carries a Creative Commons licence
/// or sits in the "netlabels" collection (labels that release music for free).
class ArchiveService {
  static const _headers = {'User-Agent': 'FreePlay/1.0 (personal music player)'};

  Future<List<ArchiveAlbum>> search(String query, {int rows = 25}) async {
    final terms = query
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return [];
    final all = terms.join(' AND ');
    final q = '(title:($all) OR creator:($all)) AND mediatype:audio '
        'AND (licenseurl:*creativecommons.org* OR collection:netlabels)';
    final uri = Uri.https('archive.org', '/advancedsearch.php', {
      'q': q,
      'fl[]': ['identifier', 'title', 'creator'],
      'sort[]': 'downloads desc',
      'rows': '$rows',
      'page': '1',
      'output': 'json',
    });
    final res =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw Exception('Internet Archive error ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = (body['response']['docs'] as List).cast<Map<String, dynamic>>();
    return docs
        .map((d) => ArchiveAlbum(
              identifier: '${d['identifier']}',
              title: _first(d['title']),
              creator: _first(d['creator']),
            ))
        .toList();
  }

  /// Lists the tracks of one archive item. Streams the best MP3 (or OGG/FLAC if there
  /// is no MP3) and downloads FLAC when [preferFlac] is set and the item has it.
  Future<List<Track>> tracksFor(ArchiveAlbum album, {bool preferFlac = false}) async {
    final res = await http
        .get(Uri.https('archive.org', '/metadata/${album.identifier}'),
            headers: _headers)
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw Exception('Internet Archive error ${res.statusCode}');
    }
    final meta = jsonDecode(res.body) as Map<String, dynamic>;
    final files = ((meta['files'] ?? []) as List).cast<Map<String, dynamic>>();

    // base name -> kind ("mp3" | "ogg" | "flac") -> best file of that kind
    final groups = <String, Map<String, Map<String, dynamic>>>{};
    for (final f in files) {
      final name = '${f['name'] ?? ''}';
      final format = '${f['format'] ?? ''}';
      final kind = _kind(format);
      if (kind == null || name.isEmpty) continue;
      final base = name.replaceFirst(RegExp(r'\.[^./]+$'), '').toLowerCase();
      final g = groups.putIfAbsent(base, () => {});
      final existing = g[kind];
      if (existing == null || _rank(format) > _rank('${existing['format']}')) {
        g[kind] = f;
      }
    }

    final entries = <_Entry>[];
    for (final g in groups.values) {
      final mp3 = g['mp3'];
      final ogg = g['ogg'];
      final flac = g['flac'];
      final streamFile = mp3 ?? ogg ?? flac;
      if (streamFile == null) continue;
      final dlFile = (preferFlac ? (flac ?? mp3 ?? ogg) : (mp3 ?? ogg ?? flac))!;
      final streamName = '${streamFile['name']}';
      final dlName = '${dlFile['name']}';
      final title = '${streamFile['title'] ?? ''}'.trim();
      final creator = '${streamFile['creator'] ?? ''}'.trim();
      final track = Track(
        id: 'archive:${album.identifier}/$streamName',
        source: 'archive',
        title: title.isNotEmpty ? title : _prettyName(streamName),
        artist: creator.isNotEmpty ? creator : album.creator,
        album: album.title,
        artUrl: album.artUrl,
        streamUrl: _url(album.identifier, streamName),
        downloadUrl: _url(album.identifier, dlName),
        ext: dlName.contains('.') ? dlName.split('.').last.toLowerCase() : 'mp3',
        downloadable: true,
        durationSec: _length(streamFile['length']),
      );
      final order = int.tryParse('${streamFile['track'] ?? ''}'.split('/').first) ?? 9999;
      entries.add(_Entry(order, streamName, track));
    }
    entries.sort((a, b) {
      final c = a.order.compareTo(b.order);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return entries.map((e) => e.track).toList();
  }

  static String _first(dynamic v) {
    if (v is List) return v.isEmpty ? '' : '${v.first}';
    return '${v ?? ''}';
  }

  static String? _kind(String format) {
    final f = format.toLowerCase();
    if (f.contains('flac')) return 'flac';
    if (f.contains('ogg vorbis')) return 'ogg';
    if (f.contains('mp3')) return 'mp3';
    return null;
  }

  static int _rank(String format) {
    final f = format.toLowerCase();
    if (f.contains('vbr')) return 250;
    if (f.contains('24bit')) return 50;
    final m = RegExp(r'(\d+)\s*kbps').firstMatch(f);
    if (m != null) return int.parse(m.group(1)!);
    return f.contains('flac') ? 100 : 1;
  }

  static int? _length(dynamic v) {
    final s = '${v ?? ''}';
    if (s.isEmpty) return null;
    if (s.contains(':')) {
      final parts = s.split(':').map((p) => int.tryParse(p) ?? 0).toList();
      var total = 0;
      for (final p in parts) {
        total = total * 60 + p;
      }
      return total;
    }
    final d = double.tryParse(s);
    return d?.round();
  }

  static String _prettyName(String file) =>
      file.replaceFirst(RegExp(r'\.[^./]+$'), '').replaceAll('_', ' ');

  static String _url(String identifier, String name) {
    final path = name.split('/').map(Uri.encodeComponent).join('/');
    return 'https://archive.org/download/$identifier/$path';
  }
}

class _Entry {
  _Entry(this.order, this.name, this.track);
  final int order;
  final String name;
  final Track track;
}
