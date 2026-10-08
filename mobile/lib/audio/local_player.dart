import '../models/station.dart';

enum LocalPlayback { idle, loading, playing, error }

/// Plays a station on the phone itself.
abstract class LocalPlayer {
  Stream<LocalPlayback> get playback;

  /// Live "now playing" text from the stream's ICY metadata, if any.
  Stream<String?> get streamTitle;

  Future<void> play(Station station);
  Future<void> stop();

  /// Called when next / previous is pressed on the notification,
  /// lock screen or a headset.
  void Function()? onSkipToNext;
  void Function()? onSkipToPrevious;
}
