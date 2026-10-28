import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/download_service.dart';
import 'art_image.dart';
import 'playlist_sheet.dart';

/// One row for a playable track: art, title, download state and a menu.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.removeLabel,
    this.onRemove,
  });

  final Track track;
  final VoidCallback onTap;
  final String? removeLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadService>();
    final downloaded = dl.isDownloaded(track.id);
    final progress = dl.progress[track.id];
    final error = dl.errors[track.id];

    Widget status;
    if (downloaded) {
      status = const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.download_done),
      );
    } else if (progress != null) {
      status = Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            value: progress > 0 ? progress : null,
            strokeWidth: 3,
          ),
        ),
      );
    } else if (error != null) {
      status = IconButton(
        icon: const Icon(Icons.error_outline),
        tooltip: '$error (tap to retry)',
        onPressed: () => dl.download(track),
      );
    } else if (!track.downloadable) {
      status = const IconButton(onPressed: null, icon: Icon(Icons.download));
    } else {
      status = IconButton(
        icon: const Icon(Icons.download),
        tooltip: 'Download',
        onPressed: () => dl.download(track),
      );
    }

    final subtitle = [track.artist, if (track.album.isNotEmpty) track.album].join(' · ');

    return ListTile(
      leading: ArtImage(url: track.artUrl),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        error != null ? error : subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          status,
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'playlist') showAddToPlaylist(context, track);
              if (v == 'remove') onRemove?.call();
              if (v == 'delete') dl.delete(track.id);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'playlist', child: Text('Add to playlist')),
              if (onRemove != null)
                PopupMenuItem(value: 'remove', child: Text(removeLabel ?? 'Remove')),
              if (downloaded)
                const PopupMenuItem(value: 'delete', child: Text('Delete download')),
            ],
          ),
        ],
      ),
    );
  }
}
