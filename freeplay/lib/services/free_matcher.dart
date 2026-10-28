import '../models/models.dart';
import 'jamendo_service.dart';

/// Looks for free, downloadable versions of songs (for example from a Spotify playlist).
/// Jamendo is mostly independent artists, so many mainstream songs will have no match.
class FreeMatcher {
  FreeMatcher(this.jamendo);

  final JamendoService jamendo;

  /// Closest search results, for the user to pick from.
  Future<List<Track>> candidates(String title, String artist, {int limit = 8}) async {
    var r = await jamendo.search('$title $artist', limit: limit);
    if (r.isEmpty) r = await jamendo.search(title, limit: limit);
    return r;
  }

  /// A confident match (same title and a matching artist), or null.
  Future<Track?> bestMatch(String title, String artist) async {
    final r = await candidates(title, artist, limit: 10);
    final nt = _norm(title);
    final na = _norm(artist.split(',').first);
    if (nt.isEmpty || na.isEmpty) return null;
    for (final t in r) {
      final ta = _norm(t.artist);
      if (ta.isEmpty) continue;
      if (_norm(t.title) == nt && (ta.contains(na) || na.contains(ta))) return t;
    }
    return null;
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
}
