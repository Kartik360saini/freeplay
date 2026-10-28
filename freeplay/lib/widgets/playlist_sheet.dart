import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/playlist_store.dart';
import '../util.dart';

/// Bottom sheet to add [track] to a local playlist (or to a new one).
Future<void> showAddToPlaylist(BuildContext context, Track track) async {
  final store = context.read<PlaylistStore>();
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('New playlist'),
            onTap: () async {
              Navigator.pop(ctx);
              final name = await promptForText(
                context,
                title: 'New playlist',
                hint: 'Name',
              );
              if (name == null) return;
              final pl = await store.create(name);
              await store.addTrack(pl.id, track);
              if (context.mounted) snack(context, 'Added to ${pl.name}');
            },
          ),
          for (final pl in store.playlists)
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(pl.name),
              subtitle: Text('${pl.tracks.length} tracks'),
              onTap: () async {
                Navigator.pop(ctx);
                await store.addTrack(pl.id, track);
                if (context.mounted) snack(context, 'Added to ${pl.name}');
              },
            ),
        ],
      ),
    ),
  );
}
