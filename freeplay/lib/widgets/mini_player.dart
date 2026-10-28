import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../screens/now_playing_screen.dart';
import '../services/player_service.dart';
import 'art_image.dart';

/// Small bar above the navigation bar showing what is playing.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final ps = context.watch<PlayerService>();
    final player = ps.player;
    return StreamBuilder<int?>(
      stream: player.currentIndexStream,
      builder: (context, snap) {
        final i = snap.data;
        if (i == null || i < 0 || i >= ps.queue.length) {
          return const SizedBox.shrink();
        }
        final t = ps.queue[i];
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NowPlayingScreen()),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  dense: true,
                  leading: ArtImage(url: t.artUrl, size: 40),
                  title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle:
                      Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    builder: (context, s) {
                      final st = s.data;
                      final playing = st?.playing ?? false;
                      final busy = st?.processingState == ProcessingState.loading ||
                          st?.processingState == ProcessingState.buffering;
                      if (busy) {
                        return const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        );
                      }
                      return IconButton(
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        onPressed: playing ? player.pause : player.play,
                      );
                    },
                  ),
                ),
                StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (context, p) {
                    final total = player.duration?.inMilliseconds ?? 0;
                    final pos = p.data?.inMilliseconds ?? 0;
                    return LinearProgressIndicator(
                      value: total > 0 ? (pos / total).clamp(0.0, 1.0) : 0,
                      minHeight: 2,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
