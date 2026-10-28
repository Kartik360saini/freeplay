import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/archive_service.dart';
import '../services/jamendo_service.dart';
import '../services/player_service.dart';
import '../services/settings_store.dart';
import '../util.dart';
import '../widgets/art_image.dart';
import '../widgets/track_tile.dart';
import 'archive_album_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _source = 'jamendo';
  bool _loading = false;
  bool _searched = false;
  String? _error;
  List<Track> _tracks = [];
  List<ArchiveAlbum> _albums = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    final settings = context.read<SettingsStore>();
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      if (_source == 'jamendo') {
        final r = await JamendoService(settings.jamendoClientId).search(q);
        if (mounted) setState(() => _tracks = r);
      } else {
        final r = await ArchiveService().search(q);
        if (mounted) setState(() => _albums = r);
      }
    } catch (e) {
      if (mounted) setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _play(int i) async {
    try {
      await context.read<PlayerService>().playQueue(_tracks, i);
    } catch (e) {
      if (mounted) snack(context, cleanError(e));
    }
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (!_searched) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Search freely licensed music.\nTap a song to play it, or use the arrow to download it.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_source == 'jamendo') {
      if (_tracks.isEmpty) return const Center(child: Text('No results'));
      return ListView.builder(
        itemCount: _tracks.length,
        itemBuilder: (_, i) => TrackTile(track: _tracks[i], onTap: () => _play(i)),
      );
    }
    if (_albums.isEmpty) return const Center(child: Text('No results'));
    return ListView.builder(
      itemCount: _albums.length,
      itemBuilder: (_, i) {
        final a = _albums[i];
        return ListTile(
          leading: ArtImage(url: a.artUrl),
          title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(a.creator, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => ArchiveAlbumScreen(album: a)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Song, artist or genre',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _search,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'jamendo', label: Text('Jamendo')),
                ButtonSegment(value: 'archive', label: Text('Internet Archive')),
              ],
              selected: {_source},
              onSelectionChanged: (s) {
                setState(() => _source = s.first);
                if (_ctrl.text.trim().isNotEmpty) _search();
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}
