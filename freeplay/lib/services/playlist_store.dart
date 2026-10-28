import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Playlists that live on this phone.
class PlaylistStore extends ChangeNotifier {
  PlaylistStore(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  static const _key = 'playlists_v1';

  final List<LocalPlaylist> playlists = [];

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      for (final j in list) {
        playlists.add(LocalPlaylist.fromJson(j));
      }
    } catch (_) {
      // Corrupt data: start empty.
    }
  }

  Future<void> _save() async {
    await _prefs.setString(
      _key,
      jsonEncode(playlists.map((p) => p.toJson()).toList()),
    );
    notifyListeners();
  }

  LocalPlaylist? byId(String id) {
    for (final p in playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<LocalPlaylist> create(String name) async {
    final p = LocalPlaylist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
    );
    playlists.add(p);
    await _save();
    return p;
  }

  Future<void> rename(String id, String name) async {
    final p = byId(id);
    if (p == null) return;
    p.name = name;
    await _save();
  }

  Future<void> delete(String id) async {
    playlists.removeWhere((p) => p.id == id);
    await _save();
  }

  Future<void> addTrack(String id, Track t) async {
    final p = byId(id);
    if (p == null || p.tracks.any((x) => x.id == t.id)) return;
    p.tracks.add(t.localPath == null ? t : t.clearLocal());
    await _save();
  }

  Future<void> removeTrack(String id, String trackId) async {
    final p = byId(id);
    if (p == null) return;
    p.tracks.removeWhere((t) => t.id == trackId);
    await _save();
  }
}
