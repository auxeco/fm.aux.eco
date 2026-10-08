import '../models/station.dart';

const _numbers = {
  'one': '1',
  'two': '2',
  'three': '3',
  'four': '4',
  'five': '5',
};

/// Lowercase, number words to digits, then letters and digits only, so
/// "N.T.S. One" and "nts1" compare equal.
String _normalize(String text) {
  final words = text
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((w) => _numbers[w] ?? w)
      .join();
  return words.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Removes the app name and filler a voice assistant may leave in the query
/// ("play NTS on AUX FM", "NTS radio").
String _cleanQuery(String query) => query
    .toLowerCase()
    .replaceAll(RegExp(r'\b(on|in|from|with)\s+aux\s*fm\b'), ' ')
    .replaceAll(RegExp(r'\b(play|listen to|put on|radio|station)\b'), ' ')
    .trim();

/// Finds the station a spoken or typed [query] refers to, or null.
///
/// Matches name, hashtag and id. An exact match wins over a prefix match,
/// which wins over a substring match; ties go to the first station in the
/// list.
Station? findStation(String query, List<Station> stations) {
  final q = _normalize(_cleanQuery(query));
  if (q.isEmpty) return null;
  Station? best;
  var bestScore = 0;
  for (final station in stations) {
    for (final key in {station.name, station.hashtag ?? '', station.id}) {
      final k = _normalize(key);
      if (k.isEmpty) continue;
      // Very short keys (hashtag "rw") only count as exact matches.
      final short = k.length < 3;
      final score = switch (k) {
        _ when k == q => 3,
        _ when k.startsWith(q) || (!short && q.startsWith(k)) => 2,
        _ when k.contains(q) || (!short && q.contains(k)) => 1,
        _ => 0,
      };
      if (score > bestScore) {
        best = station;
        bestScore = score;
      }
    }
  }
  return best;
}

/// Stations matching [query], best first, for search results.
List<Station> searchStations(String query, List<Station> stations) {
  final first = findStation(query, stations);
  final q = _normalize(_cleanQuery(query));
  return [
    ?first,
    for (final s in stations)
      if (s != first &&
          q.isNotEmpty &&
          (_normalize(s.name).contains(q) ||
              _normalize(s.description).contains(q)))
        s,
  ];
}
