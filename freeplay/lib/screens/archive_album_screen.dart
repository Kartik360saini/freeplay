import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/archive_service.dart';
import '../services/download_service.dart';
import '../services/player_service.dart';
import '../services/settings_store.dart';
import '../util.dart';
import '../widgets/track_tile.dart';

class ArchiveAlbumScreen extends StatefulWidget {
  const ArchiveAlbumScreen({super.key, required this.album});

  final ArchiveAlbum album;

  @override
  State<ArchiveAlbumScreen> createState() => _ArchiveAlbumScreenState();
}

class _ArchiveAlbumScreenState extends State<ArchiveAlbumScreen> {
  late final Future<List<Track>> _future;
  List<Track> _loaded = [];

  @override
  void initState() {
    super.initState();
    final preferFlac = context.read<SettingsStore>().downloadFormat == 'flac';
    _future = ArchiveService()
        .tracksFor(widget.album, preferFlac: preferFlac)
        .then((t) {
      if (mounted) setState(() => _loaded = t);
      return t;
    });
  }

  Future<void> _play(int i) async {
    try {
      await context.read<PlayerService>().playQueue(_loaded, i);
    } catch (e) {
      if (mounted) snack(context, cleanError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.album.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_for_offline),
            tooltip: 'Download all',
            onPressed: _loaded.isEmpty
                ? null
                : () {
                    context.read<DownloadService>().downloadAll(_loaded);
                    snack(context, 'Downloading ${_loaded.length} tracks…');
                  },
          ),
        ],
      ),
      floatingActionButton: _loaded.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _play(0),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play all'),
            ),
      body: FutureBuilder<List<Track>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(cleanError(snap.error!), textAlign: TextAlign.center),
              ),
            );
          }
          final tracks = snap.data!;
          if (tracks.isEmpty) {
            return const Center(child: Text('No audio files found in this item.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: tracks.length,
            itemBuilder: (_, i) => TrackTile(track: tracks[i], onTap: () => _play(i)),
          );
        },
      ),
    );
  }
}
