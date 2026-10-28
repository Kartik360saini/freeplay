import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App settings. API keys are typed into the app, so nothing secret lives in the code.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  String get jamendoClientId => _prefs.getString('jamendoClientId') ?? '';
  String get spotifyClientId => _prefs.getString('spotifyClientId') ?? '';

  /// "mp32" (high-quality VBR MP3), "flac" (lossless) or "ogg".
  String get downloadFormat => _prefs.getString('downloadFormat') ?? 'mp32';

  Future<void> setJamendoClientId(String v) async {
    await _prefs.setString('jamendoClientId', v.trim());
    notifyListeners();
  }

  Future<void> setSpotifyClientId(String v) async {
    await _prefs.setString('spotifyClientId', v.trim());
    notifyListeners();
  }

  Future<void> setDownloadFormat(String v) async {
    await _prefs.setString('downloadFormat', v);
    notifyListeners();
  }
}
