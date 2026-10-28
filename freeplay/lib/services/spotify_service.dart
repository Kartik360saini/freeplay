import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SpotifyTrack {
  const SpotifyTrack({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.uri,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String artists;
  final String album;
  final String uri;
  final String? imageUrl;

  static SpotifyTrack? tryParse(dynamic t) {
    if (t is! Map) return null;
    final id = t['id'];
    if (id == null) return null;
    final artists =
        ((t['artists'] ?? []) as List).map((a) => (a as Map)['name']).join(', ');
    final album = (t['album'] ?? {}) as Map;
    final images = (album['images'] ?? []) as List;
    return SpotifyTrack(
      id: '$id',
      name: '${t['name'] ?? ''}',
      artists: artists,
      album: '${album['name'] ?? ''}',
      uri: '${t['uri'] ?? 'spotify:track:$id'}',
      imageUrl: images.isNotEmpty ? '${(images.first as Map)['url']}' : null,
    );
  }
}

class SpotifyPlaylist {
  const SpotifyPlaylist({
    required this.id,
    required this.name,
    this.imageUrl,
    this.trackCount,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final int? trackCount;
}

/// Spotify login (PKCE, no client secret needed) and the parts of the Web API that
/// still work for apps in Spotify's "development mode".
///
/// Note: since February 2026 the owner of a development-mode app must have Spotify
/// Premium, and at most 5 other users can be added to it.
class SpotifyService extends ChangeNotifier {
  SpotifyService(this._prefs);

  final SharedPreferences _prefs;

  static const redirectScheme = 'freeplay';
  static const redirectUri = 'freeplay://callback';
  static const searchPageSize = 10; // development mode caps search at 10 per page
  static const _scopes = 'playlist-read-private playlist-read-collaborative '
      'playlist-modify-private playlist-modify-public user-library-read';

  String? get _access => _prefs.getString('sp_access');
  String? get _refresh => _prefs.getString('sp_refresh');
  int get _expiresAt => _prefs.getInt('sp_expires') ?? 0;

  bool get connected => _refresh != null;

  // ---------------------------------------------------------------- auth

  Future<void> connect(String clientId) async {
    final verifier = _randomString(96);
    final challenge = base64UrlEncode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final state = _randomString(16);
    final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'scope': _scopes,
      'state': state,
    });
    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: redirectScheme,
    );
    final cb = Uri.parse(result);
    final error = cb.queryParameters['error'];
    if (error != null) throw Exception('Spotify login was refused: $error');
    if (cb.queryParameters['state'] != state) {
      throw Exception('Spotify login failed (state mismatch). Try again.');
    }
    final code = cb.queryParameters['code'];
    if (code == null) throw Exception('Spotify did not return a login code.');
    await _tokenRequest({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      'client_id': clientId,
      'code_verifier': verifier,
    }, clientId);
  }

  Future<void> disconnect() async {
    for (final k in ['sp_access', 'sp_refresh', 'sp_expires', 'sp_client']) {
      await _prefs.remove(k);
    }
    notifyListeners();
  }

  Future<void> _tokenRequest(Map<String, String> body, String clientId) async {
    final res = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception('Spotify login failed (${res.statusCode}): ${res.body}');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    await _prefs.setString('sp_access', j['access_token'] as String);
    final refresh = j['refresh_token'];
    if (refresh != null) await _prefs.setString('sp_refresh', refresh as String);
    final expiresIn = (j['expires_in'] as num).toInt();
    await _prefs.setInt(
      'sp_expires',
      DateTime.now().millisecondsSinceEpoch + (expiresIn - 60) * 1000,
    );
    await _prefs.setString('sp_client', clientId);
    notifyListeners();
  }

  Future<String> _token() async {
    final access = _access;
    if (access != null && DateTime.now().millisecondsSinceEpoch < _expiresAt) {
      return access;
    }
    final client = _prefs.getString('sp_client');
    final refresh = _refresh;
    if (client == null || refresh == null) {
      throw Exception('Not connected to Spotify.');
    }
    await _tokenRequest({
      'grant_type': 'refresh_token',
      'refresh_token': refresh,
      'client_id': client,
    }, client);
    return _access!;
  }

  // ----------------------------------------------------------------- API

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    final res = await http.get(
      Uri.https('api.spotify.com', '/v1$path', query),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.https('api.spotify.com', '/v1$path'),
      headers: {
        'Authorization': 'Bearer ${await _token()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode >= 300) {
      var msg = res.body;
      try {
        msg = (jsonDecode(res.body) as Map)['error']['message'] as String;
      } catch (_) {}
      if (res.statusCode == 403) {
        msg = '$msg\n\nSpotify only allows this if the app owner has Premium and '
            'your account is added under User Management in the developer dashboard.';
      }
      throw Exception('Spotify ${res.statusCode}: $msg');
    }
    if (res.body.isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<SpotifyPlaylist>> myPlaylists({int max = 200}) async {
    final out = <SpotifyPlaylist>[];
    var offset = 0;
    while (out.length < max) {
      final j = await _get('/me/playlists', {'limit': '50', 'offset': '$offset'});
      final items = ((j['items'] ?? []) as List).whereType<Map>().toList();
      for (final p in items) {
        final images = (p['images'] ?? []) as List;
        final counts = (p['items'] ?? p['tracks']);
        out.add(SpotifyPlaylist(
          id: '${p['id']}',
          name: '${p['name'] ?? ''}',
          imageUrl: images.isNotEmpty ? '${(images.first as Map)['url']}' : null,
          trackCount: counts is Map ? (counts['total'] as num?)?.toInt() : null,
        ));
      }
      if (j['next'] == null || items.isEmpty) break;
      offset += 50;
    }
    return out;
  }

  /// Only works for playlists you own or collaborate on (Spotify restriction).
  Future<List<SpotifyTrack>> playlistTracks(String id, {int max = 500}) async {
    final out = <SpotifyTrack>[];
    var offset = 0;
    while (out.length < max) {
      final j = await _get('/playlists/$id/items', {'limit': '50', 'offset': '$offset'});
      final items = ((j['items'] ?? []) as List).whereType<Map>().toList();
      for (final e in items) {
        final t = SpotifyTrack.tryParse(e['track'] ?? e['item']);
        if (t != null) out.add(t);
      }
      if (j['next'] == null || items.isEmpty) break;
      offset += 50;
    }
    return out;
  }

  Future<List<SpotifyTrack>> likedSongs({int max = 200}) async {
    final out = <SpotifyTrack>[];
    var offset = 0;
    while (out.length < max) {
      final j = await _get('/me/tracks', {'limit': '50', 'offset': '$offset'});
      final items = ((j['items'] ?? []) as List).whereType<Map>().toList();
      for (final e in items) {
        final t = SpotifyTrack.tryParse(e['track']);
        if (t != null) out.add(t);
      }
      if (j['next'] == null || items.isEmpty) break;
      offset += 50;
    }
    return out;
  }

  Future<List<SpotifyTrack>> search(String query, {int offset = 0}) async {
    final j = await _get('/search', {
      'q': query,
      'type': 'track',
      'limit': '$searchPageSize',
      'offset': '$offset',
    });
    final items = (((j['tracks'] ?? {}) as Map)['items'] ?? []) as List;
    return items.map(SpotifyTrack.tryParse).whereType<SpotifyTrack>().toList();
  }

  Future<SpotifyPlaylist> createPlaylist(String name) async {
    final j = await _post('/me/playlists', {'name': name, 'public': false});
    return SpotifyPlaylist(id: '${j['id']}', name: '${j['name'] ?? name}');
  }

  Future<void> addToPlaylist(String playlistId, SpotifyTrack t) async {
    await _post('/playlists/$playlistId/items', {
      'uris': [t.uri],
    });
  }

  static String _randomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
