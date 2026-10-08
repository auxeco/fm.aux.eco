import '../models/station.dart';

enum LocalPlayback { idle, loading, playing, error }

/// Requests arriving through the OS media session: notification, lock
/// screen, headset buttons, voice assistant and Android Auto.
abstract class MediaSessionDelegate {
  List<Station> get stations;
  Station get current;
  Future<void> skipToNext();
  Future<void> skipToPrevious();

  /// Play pressed on a headset, the lock screen or by voice ("resume").
  Future<void> resumeFromSession();

  /// A station picked from a media browser (e.g. Android Auto).
  Future<void> playStationFromSession(Station station);

  /// A voice request such as "play NTS on AUX FM". Empty means "play
  /// something".
  Future<void> playFromSearch(String query);
}

/// Plays a station on the phone itself.
abstract class LocalPlayer {
  Stream<LocalPlayback> get playback;

  /// Live "now playing" text from the stream's ICY metadata, if any.
  Stream<String?> get streamTitle;

  Future<void> play(Station station);
  Future<void> stop();

  MediaSessionDelegate? delegate;
}
