import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/free_matcher.dart';
import '../services/jamendo_service.dart';
import '../services/player_service.dart';
import '../services/playlist_store.dart';
import '../services/settings_store.dart';
import '../services/spotify_service.dart';
import '../util.dart';
import '../widgets/art_image.dart';
import '../widgets/track_tile.dart';

class SpotifyScreen extends StatelessWidget {
  const SpotifyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<SpotifyService>().connected;
    return connected ? const _SpotifyHome() : const _SpotifyConnect();
  }
}

// ------------------------------------------------------------------ connect

class _SpotifyConnect extends StatefulWidget {
  const _SpotifyConnect();

  @override
  State<_SpotifyConnect> createState() => _SpotifyConnectState();
}

class _SpotifyConnectState extends State<_SpotifyConnect> {
  bool _busy = false;

  Future<void> _connect() async {
    final settings = context.read<SettingsStore>();
    final sp = context.read<SpotifyService>();
    var id = settings.spotifyClientId;
    if (id.isEmpty) {
      final entered = await promptForText(
        context,
        title: 'Spotify Client ID',
        hint: 'From developer.spotify.com/dashboard',
      );
      if (entered == null || !mounted) return;
      await settings.setSpotifyClientId(entered);
      id = entered;
    }
    setState(() => _busy = true);
    try {
      await sp.connect(id);
    } catch (e) {
      if (mounted) snack(context, cleanError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Spotify')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.queue_music, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Connect your Spotify account',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Browse your playlists and liked songs, search Spotify, create playlists, '
            'and look up free, downloadable versions of songs on Jamendo.\n\n'
            'Spotify songs themselves can\'t be played or downloaded inside this app; '
            'that stays in the official Spotify app.',
          ),
          const SizedBox(height: 16),
          Text('Setup', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const SelectableText(
            '1. Open developer.spotify.com/dashboard and create an app.\n'
            '2. Add this Redirect URI: freeplay://callback\n'
            '3. Copy the app\'s Client ID into this app.\n\n'
            'Since February 2026 Spotify only lets the owner of a developer app use '
            'the API if the owner has Premium. If that isn\'t you, ask someone with '
            'Premium to create the app and add your Spotify email under User '
            'Management (up to 5 users).',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _connect,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text('Connect Spotify'),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- home

class _SpotifyHome extends StatelessWidget {
  const _SpotifyHome();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Spotify'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Playlists'), Tab(text: 'Liked'), Tab(text: 'Search')],
          ),
        ),
        body: const TabBarView(
          children: [_PlaylistsTab(), _LikedTab(), _SearchTab()],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- playlists

class _PlaylistsTab extends StatefulWidget {
  const _PlaylistsTab();

  @override
  State<_PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<_PlaylistsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<SpotifyPlaylist>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<SpotifyService>().myPlaylists();
  }

  Future<void> _create() async {
    final sp = context.read<SpotifyService>();
    final name = await promptForText(
      context,
      title: 'New Spotify playlist',
      hint: 'Name',
    );
    if (name == null) return;
    try {
      await sp.createPlaylist(name);
      if (mounted) setState(_load);
    } catch (e) {
      if (mounted) snack(context, cleanError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New playlist'),
      ),
      body: FutureBuilder<List<SpotifyPlaylist>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message: cleanError(snap.error!),
              onRetry: () => setState(_load),
            );
          }
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('No playlists'));
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              return ListTile(
                leading: ArtImage(url: p.imageUrl),
                title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: p.trackCount == null ? null : Text('${p.trackCount} tracks'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SpotifyPlaylistScreen(playlist: p),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SpotifyPlaylistScreen extends StatefulWidget {
  const SpotifyPlaylistScreen({super.key, required this.playlist});

  final SpotifyPlaylist playlist;

  @override
  State<SpotifyPlaylistScreen> createState() => _SpotifyPlaylistScreenState();
}

class _SpotifyPlaylistScreenState extends State<SpotifyPlaylistScreen> {
  late Future<List<SpotifyTrack>> _future;
  List<SpotifyTrack> _loaded = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context
        .read<SpotifyService>()
        .playlistTracks(widget.playlist.id)
        .then((t) {
      if (mounted) setState(() => _loaded = t);
      return t;
    });
  }

  Future<void> _matchAll() async {
    final settings = context.read<SettingsStore>();
    final store = context.read<PlaylistStore>();
    final matcher = FreeMatcher(JamendoService(settings.jamendoClientId));
    if (!matcher.jamendo.configured) {
      snack(context, 'Add your Jamendo client ID in Settings first.');
      return;
    }
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final status = ValueNotifier<String>('Starting…');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Looking for free versions'),
          content: ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (_, v, __) => Text(v),
          ),
        ),
      ),
    );

    final list = _loaded.take(100).toList();
    final found = <Track>[];
    for (var i = 0; i < list.length; i++) {
      status.value = 'Checking ${i + 1} of ${list.length}\n${list[i].name}';
      try {
        final m = await matcher.bestMatch(list[i].name, list[i].artists);
        if (m != null) found.add(m);
      } catch (_) {
        // Skip tracks that fail; keep going.
      }
    }
    navigator.pop();
    status.dispose();

    if (found.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No free versions found. Jamendo is mostly independent artists.'),
      ));
      return;
    }
    final pl = await store.create('${widget.playlist.name} (free matches)');
    for (final t in found) {
      await store.addTrack(pl.id, t);
    }
    messenger.showSnackBar(SnackBar(
      content: Text(
        'Matched ${found.length} of ${list.length}. Saved as "${pl.name}" in Library.',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.travel_explore),
            tooltip: 'Find free versions of these songs',
            onPressed: _loaded.isEmpty ? null : _matchAll,
          ),
        ],
      ),
      body: FutureBuilder<List<SpotifyTrack>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message: cleanError(snap.error!),
              onRetry: () => setState(_load),
            );
          }
          final tracks = snap.data!;
          if (tracks.isEmpty) return const Center(child: Text('No tracks'));
          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (_, i) => _SpotifyTrackTile(track: tracks[i]),
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------------- liked

class _LikedTab extends StatefulWidget {
  const _LikedTab();

  @override
  State<_LikedTab> createState() => _LikedTabState();
}

class _LikedTabState extends State<_LikedTab> with AutomaticKeepAliveClientMixin {
  late Future<List<SpotifyTrack>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<SpotifyService>().likedSongs();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<SpotifyTrack>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorView(
            message: cleanError(snap.error!),
            onRetry: () => setState(_load),
          );
        }
        final tracks = snap.data!;
        if (tracks.isEmpty) return const Center(child: Text('No liked songs'));
        return ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (_, i) => _SpotifyTrackTile(track: tracks[i]),
        );
      },
    );
  }
}

// ------------------------------------------------------------------- search

class _SearchTab extends StatefulWidget {
  const _SearchTab();

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> with AutomaticKeepAliveClientMixin {
  final _ctrl = TextEditingController();
  final List<SpotifyTrack> _results = [];
  bool _loading = false;
  bool _more = false;
  String? _error;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run({bool next = false}) async {
    final q = next ? _query : _ctrl.text.trim();
    if (q.isEmpty) return;
    final sp = context.read<SpotifyService>();
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      if (!next) {
        _results.clear();
        _query = q;
      }
    });
    try {
      final r = await sp.search(q, offset: next ? _results.length : 0);
      if (mounted) {
        setState(() {
          _results.addAll(r);
          _more = r.length >= SpotifyService.searchPageSize;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _run(),
            decoration: InputDecoration(
              hintText: 'Search Spotify',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _run,
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        Expanded(
          child: ListView(
            children: [
              for (final t in _results) _SpotifyTrackTile(track: t),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_loading && _more)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: TextButton(
                      onPressed: () => _run(next: true),
                      child: const Text('Load more'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ track actions

class _SpotifyTrackTile extends StatelessWidget {
  const _SpotifyTrackTile({required this.track});

  final SpotifyTrack track;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ArtImage(url: track.imageUrl),
      title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${track.artists} · ${track.album}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _showFreeMatches(context, track),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'free') _showFreeMatches(context, track);
          if (v == 'open') {
            await launchUrl(
              Uri.parse('https://open.spotify.com/track/${track.id}'),
              mode: LaunchMode.externalApplication,
            );
          }
          if (v == 'add' && context.mounted) {
            await _addToSpotifyPlaylist(context, track);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'free', child: Text('Find a free version')),
          PopupMenuItem(value: 'open', child: Text('Open in Spotify')),
          PopupMenuItem(value: 'add', child: Text('Add to a Spotify playlist')),
        ],
      ),
    );
  }
}

Future<void> _addToSpotifyPlaylist(BuildContext context, SpotifyTrack t) async {
  final sp = context.read<SpotifyService>();
  try {
    final lists = await sp.myPlaylists();
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<SpotifyPlaylist>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in lists)
              ListTile(
                leading: ArtImage(url: p.imageUrl, size: 40),
                title: Text(p.name),
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await sp.addToPlaylist(picked.id, t);
    if (context.mounted) snack(context, 'Added to ${picked.name}');
  } catch (e) {
    if (context.mounted) snack(context, cleanError(e));
  }
}

Future<void> _showFreeMatches(BuildContext context, SpotifyTrack t) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FreeMatchSheet(track: t),
  );
}

class _FreeMatchSheet extends StatefulWidget {
  const _FreeMatchSheet({required this.track});

  final SpotifyTrack track;

  @override
  State<_FreeMatchSheet> createState() => _FreeMatchSheetState();
}

class _FreeMatchSheetState extends State<_FreeMatchSheet> {
  late final Future<List<Track>> _future;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsStore>();
    _future = FreeMatcher(JamendoService(settings.jamendoClientId))
        .candidates(widget.track.name, widget.track.artists);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Closest free matches for "${widget.track.name}"',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Track>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          cleanError(snap.error!),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final r = snap.data!;
                  if (r.isEmpty) {
                    return const Center(child: Text('No free version found.'));
                  }
                  return ListView.builder(
                    itemCount: r.length,
                    itemBuilder: (ctx, i) => TrackTile(
                      track: r[i],
                      onTap: () async {
                        try {
                          await ctx.read<PlayerService>().playQueue(r, i);
                        } catch (e) {
                          if (ctx.mounted) snack(ctx, cleanError(e));
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
