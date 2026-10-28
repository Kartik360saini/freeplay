import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/settings_store.dart';
import '../services/spotify_service.dart';
import '../util.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _jamendo;
  late final TextEditingController _spotify;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsStore>();
    _jamendo = TextEditingController(text: s.jamendoClientId);
    _spotify = TextEditingController(text: s.spotifyClientId);
  }

  @override
  void dispose() {
    _jamendo.dispose();
    _spotify.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsStore>();
    final sp = context.watch<SpotifyService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Free music (Jamendo)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Jamendo needs a free Client ID before it will answer searches. '
            'Create an app on the Jamendo developer portal and paste its Client ID here.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open devportal.jamendo.com'),
              onPressed: () => launchUrl(
                Uri.parse('https://devportal.jamendo.com'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
          TextField(
            controller: _jamendo,
            decoration: InputDecoration(
              labelText: 'Jamendo Client ID',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Save',
                onPressed: () async {
                  await s.setJamendoClientId(_jamendo.text);
                  if (context.mounted) snack(context, 'Saved');
                },
              ),
            ),
          ),
          const Divider(height: 40),
          Text('Download quality', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButton<String>(
            isExpanded: true,
            value: s.downloadFormat,
            items: const [
              DropdownMenuItem(
                value: 'mp32',
                child: Text('MP3, high quality (VBR)'),
              ),
              DropdownMenuItem(
                value: 'flac',
                child: Text('FLAC, lossless (big files)'),
              ),
              DropdownMenuItem(value: 'ogg', child: Text('OGG Vorbis')),
            ],
            onChanged: (v) {
              if (v != null) s.setDownloadFormat(v);
            },
          ),
          const SizedBox(height: 4),
          const Text(
            'Streaming always uses the high-quality MP3 stream. Downloads use the '
            'format above when the source has it, otherwise the best MP3.',
          ),
          const Divider(height: 40),
          Text('Spotify', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(sp.connected ? 'Connected' : 'Not connected'),
          const SizedBox(height: 8),
          TextField(
            controller: _spotify,
            decoration: InputDecoration(
              labelText: 'Spotify Client ID',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Save',
                onPressed: () async {
                  await s.setSpotifyClientId(_spotify.text);
                  if (context.mounted) snack(context, 'Saved');
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          const SelectableText('Redirect URI to register: ${SpotifyService.redirectUri}'),
          if (sp.connected)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.tonal(
                  onPressed: sp.disconnect,
                  child: const Text('Disconnect Spotify'),
                ),
              ),
            ),
          const Divider(height: 40),
          Text('About', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'FreePlay plays audio only, with no ads. It plays and downloads music that '
            'artists have released for free (Creative Commons and similar licences). '
            'Spotify tracks can\'t be played or downloaded here.\n\n'
            'Downloads are stored privately inside the app (Library > Downloads) and '
            'are removed if you uninstall it. Check each track\'s licence if you plan '
            'to reuse it beyond personal listening.',
          ),
        ],
      ),
    );
  }
}
