import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/download_service.dart';
import '../services/player_service.dart';
import '../services/playlist_store.dart';
import '../util.dart';
import '../widgets/track_tile.dart';
import 'playlist_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Downloads'), Tab(text: 'Playlists')],
          ),
        ),
        body: const TabBarView(children: [_DownloadsTab(), _PlaylistsTab()]),
      ),
    );
  }
}

class _DownloadsTab extends StatelessWidget {
  const _DownloadsTab();

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadService>();
    final tracks = dl.downloaded;
    if (tracks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nothing downloaded yet.\nDownloaded songs play offline, with no ads.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (_, i) => TrackTile(
        track: tracks[i],
        onTap: () async {
          try {
            await context.read<PlayerService>().playQueue(tracks, i);
          } catch (e) {
            if (context.mounted) snack(context, cleanError(e));
          }
        },
      ),
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlaylistStore>();
    final lists = store.playlists;
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('New playlist'),
          onTap: () async {
            final name = await promptForText(
              context,
              title: 'New playlist',
              hint: 'Name',
            );
            if (name != null) await store.create(name);
          },
        ),
        for (final p in lists)
          ListTile(
            leading: const Icon(Icons.queue_music),
            title: Text(p.name),
            subtitle: Text('${p.tracks.length} tracks'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlaylistScreen(playlistId: p.id),
              ),
            ),
          ),
        if (lists.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No playlists yet. Create one, then add songs from Search with the ⋮ menu.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
