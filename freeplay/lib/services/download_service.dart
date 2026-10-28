import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'jamendo_service.dart';
import 'settings_store.dart';

/// Downloads tracks into the app's private storage and remembers them.
class DownloadService extends ChangeNotifier {
  DownloadService(this._prefs, this._settings);

  final SharedPreferences _prefs;
  final SettingsStore _settings;
  static const _key = 'downloads_v1';

  final List<Track> downloaded = [];

  /// Track id -> 0..1 while a download is running.
  final Map<String, double> progress = {};

  /// Track id -> last error message.
  final Map<String, String> errors = {};

  Future<void> load() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      for (final j in list) {
        final t = Track.fromJson(j);
        final path = t.localPath;
        if (path != null && File(path).existsSync()) downloaded.add(t);
      }
    } catch (_) {
      // A corrupt list just means an empty library.
    }
  }

  bool isDownloaded(String id) => downloaded.any((t) => t.id == id);

  /// Returns the downloaded copy of [t] if there is one, otherwise [t].
  Track resolve(Track t) {
    for (final d in downloaded) {
      if (d.id == t.id) return d;
    }
    return t;
  }

  Future<void> downloadAll(List<Track> tracks) async {
    for (final t in tracks) {
      await download(t);
    }
  }

  Future<void> download(Track t) async {
    if (isDownloaded(t.id) || progress.containsKey(t.id)) return;

    String? url;
    var ext = t.ext;
    if (t.source == 'jamendo') {
      if (_settings.jamendoClientId.isEmpty) {
        _fail(t, 'Jamendo client ID missing (see Settings)');
        return;
      }
      final fmt = _settings.downloadFormat;
      url = JamendoService(_settings.jamendoClientId).downloadUrlFor(t, fmt);
      ext = fmt == 'flac' ? 'flac' : (fmt == 'ogg' ? 'ogg' : 'mp3');
    } else {
      url = t.downloadUrl;
    }
    if (url == null || !t.downloadable) {
      _fail(t, 'The artist has not allowed downloads for this track');
      return;
    }

    progress[t.id] = 0;
    errors.remove(t.id);
    notifyListeners();

    final client = http.Client();
    File? partial;
    try {
      final resp = await client.send(http.Request('GET', Uri.parse(url)));
      if (resp.statusCode != 200) {
        throw Exception('Server returned ${resp.statusCode}');
      }
      final dir = await _musicDir();
      final out = File('${dir.path}/${_fileName(t)}.$ext');
      partial = out;
      final sink = out.openWrite();
      final total = resp.contentLength ?? 0;
      var got = 0;
      var lastShown = 0.0;
      try {
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) {
            final p = got / total;
            if (p - lastShown >= 0.02) {
              lastShown = p;
              progress[t.id] = p;
              notifyListeners();
            }
          }
        }
      } finally {
        await sink.close();
      }
      downloaded.add(t.copyWith(localPath: out.path, ext: ext));
      partial = null;
      await _save();
    } catch (e) {
      errors[t.id] = e.toString().replaceFirst('Exception: ', '');
      try {
        if (partial != null && await partial.exists()) await partial.delete();
      } catch (_) {}
    } finally {
      client.close();
      progress.remove(t.id);
      notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    final idx = downloaded.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = downloaded.removeAt(idx);
    try {
      final f = File(t.localPath!);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    await _save();
    notifyListeners();
  }

  void _fail(Track t, String message) {
    errors[t.id] = message;
    notifyListeners();
  }

  Future<Directory> _musicDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/music');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _fileName(Track t) {
    final base =
        '${t.artist} - ${t.title}'.replaceAll(RegExp(r'[\\/:*?"<>|\n\r]'), '_');
    final short = base.length > 90 ? base.substring(0, 90) : base;
    return '$short [${t.id.hashCode.abs() % 100000}]';
  }

  Future<void> _save() async {
    await _prefs.setString(
      _key,
      jsonEncode(downloaded.map((t) => t.toJson()).toList()),
    );
  }
}
