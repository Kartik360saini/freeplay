import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/models.dart';
import 'download_service.dart';

/// Audio-only player with a lock-screen / notification control and background playback.
/// There are no ads and no video: it only plays files from the free sources.
class PlayerService extends ChangeNotifier {
  PlayerService(this._downloads);

  final DownloadService _downloads;
  final AudioPlayer player = AudioPlayer();

  List<Track> queue = [];

  Future<void> playQueue(List<Track> tracks, int index) async {
    final playable = <Track>[];
    var start = 0;
    for (var i = 0; i < tracks.length; i++) {
      final t = _downloads.resolve(tracks[i]);
      if (t.localPath == null && t.streamUrl == null) continue;
      if (i == index) start = playable.length;
      playable.add(t);
    }
    if (playable.isEmpty) throw Exception('Nothing playable here.');

    queue = playable;
    notifyListeners();
    await player.setAudioSource(
      ConcatenatingAudioSource(children: playable.map(_source).toList()),
      initialIndex: start,
    );
    player.play();
  }

  AudioSource _source(Track t) {
    final tag = MediaItem(
      id: t.id,
      title: t.title,
      artist: t.artist,
      album: t.album,
      artUri: t.artUrl == null ? null : Uri.parse(t.artUrl!),
      duration: t.durationSec == null ? null : Duration(seconds: t.durationSec!),
    );
    final path = t.localPath;
    if (path != null && File(path).existsSync()) {
      return AudioSource.uri(Uri.file(path), tag: tag);
    }
    return AudioSource.uri(Uri.parse(t.streamUrl!), tag: tag);
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
