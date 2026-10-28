import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Jamendo hosts independent music released under Creative Commons licences.
/// API docs: https://developer.jamendo.com/v3.0
class JamendoService {
  JamendoService(this.clientId);

  final String clientId;
  static const _base = 'https://api.jamendo.com/v3.0';

  bool get configured => clientId.isNotEmpty;

  Future<List<Track>> search(String query, {int limit = 30, int offset = 0}) async {
    if (!configured) {
      throw Exception('Add your free Jamendo client ID in Settings first.');
    }
    final uri = Uri.parse('$_base/tracks/').replace(queryParameters: {
      'client_id': clientId,
      'format': 'json',
      'limit': '$limit',
      'offset': '$offset',
      'search': query,
      // High-quality VBR MP3 stream.
      'audioformat': 'mp32',
      'imagesize': '300',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Jamendo error ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final headers = body['headers'];
    if (headers is Map && headers['status'] != 'success') {
      throw Exception('Jamendo: ${headers['error_message'] ?? 'request failed'}');
    }
    final results = ((body['results'] ?? []) as List).cast<Map<String, dynamic>>();
    return results.map(_toTrack).toList();
  }

  /// Official download endpoint. It redirects to the file, so the HTTP client must
  /// follow redirects. Jamendo returns 404 if the artist disabled downloads.
  String downloadUrlFor(Track t, String format) {
    final id = t.id.split(':').last;
    return '$_base/tracks/file/?client_id=$clientId&id=$id'
        '&audioformat=$format&action=download';
  }

  Track _toTrack(Map<String, dynamic> r) {
    final id = r['id'].toString();
    final dur = r['duration'];
    return Track(
      id: 'jamendo:$id',
      source: 'jamendo',
      title: (r['name'] ?? '').toString(),
      artist: (r['artist_name'] ?? '').toString(),
      album: (r['album_name'] ?? '').toString(),
      artUrl: _nonEmpty(r['image']),
      streamUrl: _nonEmpty(r['audio']),
      downloadable: _truthy(r['audiodownload_allowed']),
      durationSec: dur is int ? dur : int.tryParse('$dur'),
    );
  }

  static String? _nonEmpty(dynamic v) {
    final s = (v ?? '').toString();
    return s.isEmpty ? null : s;
  }

  static bool _truthy(dynamic v) =>
      v == true || v == 1 || v == '1' || v == 'true';
}
