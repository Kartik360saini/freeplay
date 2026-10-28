import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/download_service.dart';
import '../services/player_service.dart';
import '../services/playlist_store.dart';
import '../util.dart';
import '../widgets/track_tile.dart';

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlaylistStore>();
    final pl = store.byId(playlistId);
    if (pl == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This playlist was deleted.')),
      );
    }

    Future<void> play(int i) async {
      try {
        await context.read<PlayerService>().playQueue(pl.tracks, i);
      } catch (e) {
        if (context.mounted) snack(context, cleanError(e));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(pl.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Rename',
            onPressed: () async {
              final n = await promptForText(
                context,
                title: 'Rename playlist',
                initial: pl.name,
              );
              if (n != null) await store.rename(pl.id, n);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete playlist',
            onPressed: () async {
              final ok = await confirm(context, 'Delete "${pl.name}"?');
              if (!ok) return;
              await store.delete(pl.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: pl.tracks.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Empty. Add songs from Search with the ⋮ menu.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => play(0),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play all'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          context.read<DownloadService>().downloadAll(pl.tracks);
                          snack(context, 'Downloading ${pl.tracks.length} tracks…');
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Download all'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: pl.tracks.length,
                    itemBuilder: (_, i) {
                      final t = pl.tracks[i];
                      return TrackTile(
                        track: t,
                        onTap: () => play(i),
                        removeLabel: 'Remove from playlist',
                        onRemove: () => store.removeTrack(pl.id, t.id),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
