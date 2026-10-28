import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/spotify_screen.dart';
import 'services/download_service.dart';
import 'services/player_service.dart';
import 'services/playlist_store.dart';
import 'services/settings_store.dart';
import 'services/spotify_service.dart';
import 'widgets/mini_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.freeplay.channel.audio',
    androidNotificationChannelName: 'FreePlay playback',
    androidNotificationOngoing: true,
  );
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsStore(prefs);
  final downloads = DownloadService(prefs, settings);
  await downloads.load();
  final playlists = PlaylistStore(prefs);
  final spotify = SpotifyService(prefs);
  final player = PlayerService(downloads);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ChangeNotifierProvider<DownloadService>.value(value: downloads),
        ChangeNotifierProvider<PlaylistStore>.value(value: playlists),
        ChangeNotifierProvider<SpotifyService>.value(value: spotify),
        ChangeNotifierProvider<PlayerService>.value(value: player),
      ],
      child: const FreePlayApp(),
    ),
  );
}

class FreePlayApp extends StatelessWidget {
  const FreePlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FreePlay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    SearchScreen(),
    LibraryScreen(),
    SpotifyScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Android 13+ needs this for the playback notification (lock-screen controls).
    Permission.notification.request().catchError((_) => PermissionStatus.denied);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
              NavigationDestination(icon: Icon(Icons.library_music), label: 'Library'),
              NavigationDestination(icon: Icon(Icons.queue_music), label: 'Spotify'),
              NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ],
      ),
    );
  }
}
