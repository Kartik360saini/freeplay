import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';
import '../util.dart';
import '../widgets/art_image.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ps = context.watch<PlayerService>();
    final player = ps.player;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Now playing')),
      body: StreamBuilder<int?>(
        stream: player.currentIndexStream,
        builder: (context, snap) {
          final i = snap.data;
          if (i == null || i < 0 || i >= ps.queue.length) {
            return const Center(child: Text('Nothing playing'));
          }
          final t = ps.queue[i];
          final source = t.localPath != null
              ? 'Playing from your phone · ${t.ext.toUpperCase()}'
              : 'Streaming';
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(child: Center(child: ArtImage(url: t.artUrl, size: 280))),
                Text(
                  t.title,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(t.artist, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(source, style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (context, p) {
                    final pos = p.data ?? Duration.zero;
                    final dur = player.duration ?? Duration.zero;
                    final maxMs = dur.inMilliseconds > 0 ? dur.inMilliseconds : 1;
                    final posMs = pos.inMilliseconds.clamp(0, maxMs).toDouble();
                    return Column(
                      children: [
                        Slider(
                          value: posMs,
                          max: maxMs.toDouble(),
                          onChanged: (v) =>
                              player.seek(Duration(milliseconds: v.toInt())),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formatDuration(pos)),
                              Text(formatDuration(dur)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StreamBuilder<bool>(
                      stream: player.shuffleModeEnabledStream,
                      builder: (context, s) {
                        final on = s.data ?? false;
                        return IconButton(
                          icon: Icon(Icons.shuffle,
                              color: on ? theme.colorScheme.primary : null),
                          onPressed: () async {
                            if (!on) await player.shuffle();
                            await player.setShuffleModeEnabled(!on);
                          },
                        );
                      },
                    ),
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.skip_previous),
                      onPressed: player.seekToPrevious,
                    ),
                    StreamBuilder<PlayerState>(
                      stream: player.playerStateStream,
                      builder: (context, s) {
                        final st = s.data;
                        final playing = st?.playing ?? false;
                        final busy = st?.processingState == ProcessingState.loading ||
                            st?.processingState == ProcessingState.buffering;
                        if (busy) {
                          return const SizedBox(
                            width: 64,
                            height: 64,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return IconButton.filled(
                          iconSize: 40,
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                          onPressed: playing ? player.pause : player.play,
                        );
                      },
                    ),
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.skip_next),
                      onPressed: player.seekToNext,
                    ),
                    StreamBuilder<LoopMode>(
                      stream: player.loopModeStream,
                      builder: (context, s) {
                        final mode = s.data ?? LoopMode.off;
                        return IconButton(
                          icon: Icon(
                            mode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                            color:
                                mode != LoopMode.off ? theme.colorScheme.primary : null,
                          ),
                          onPressed: () => player.setLoopMode(
                            mode == LoopMode.off
                                ? LoopMode.all
                                : (mode == LoopMode.all ? LoopMode.one : LoopMode.off),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
