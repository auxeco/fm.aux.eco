import '../arylic/arylic_client.dart';
import '../cast/cast_client.dart';
import '../cast/cast_discovery.dart';
import '../models/station.dart';

enum SpeakerKind { arylic, cast }

class SpeakerStatus {
  const SpeakerStatus({
    required this.playing,
    required this.volume,
    required this.muted,
    this.loading = false,
    this.title,
  });

  final bool playing;
  final bool loading;

  /// 0–100.
  final int volume;
  final bool muted;

  /// What the speaker says it is playing (stream metadata), if anything.
  final String? title;

  SpeakerStatus copyWith({int? volume, bool? muted}) => SpeakerStatus(
    playing: playing,
    loading: loading,
    volume: volume ?? this.volume,
    muted: muted ?? this.muted,
    title: title,
  );
}

/// A speaker on the network that plays stations itself: the phone only
/// sends it the stream URL and acts as a remote.
abstract class RemoteSpeaker {
  /// Stable identity, e.g. `arylic:192.168.1.20` or `cast:<device id>`.
  String get id;
  String get name;
  SpeakerKind get kind;

  Future<SpeakerStatus> status();
  Future<void> play(Station station);
  Future<void> stop();
  Future<void> setVolume(int volume);
  Future<void> setMuted(bool muted);
  void dispose();
}

class ArylicSpeaker implements RemoteSpeaker {
  ArylicSpeaker(this.client, this.name);

  final ArylicClient client;
  @override
  final String name;

  @override
  String get id => 'arylic:${client.host}';
  @override
  SpeakerKind get kind => SpeakerKind.arylic;

  @override
  Future<SpeakerStatus> status() async {
    final s = await client.getPlayerStatus();
    return SpeakerStatus(
      playing: s.isPlaying,
      loading: s.playback == AmpPlayback.loading,
      volume: s.volume,
      muted: s.muted,
      title: s.title,
    );
  }

  @override
  Future<void> play(Station station) => client.playUrl(station.url);
  @override
  Future<void> stop() => client.stop();
  @override
  Future<void> setVolume(int volume) => client.setVolume(volume);
  @override
  Future<void> setMuted(bool muted) => client.setMuted(muted);
  @override
  void dispose() {}
}

typedef ContentTypeLookup = Future<String> Function(String url);

class CastSpeaker implements RemoteSpeaker {
  CastSpeaker(
    this.device, {
    CastClient? client,
    this._contentType = streamContentType,
  }) : client = client ?? CastClient(device.host, port: device.port);

  final CastDevice device;
  final CastClient client;
  final ContentTypeLookup _contentType;

  static const _artwork = 'https://fm.aux.eco/favicon.png';

  @override
  String get id => 'cast:${device.id}';
  @override
  String get name => device.name;
  @override
  SpeakerKind get kind => SpeakerKind.cast;

  @override
  Future<SpeakerStatus> status() async {
    final s = await client.getStatus();
    return SpeakerStatus(
      playing: s.isPlaying,
      loading: s.playerState == CastPlayerState.buffering,
      volume: (s.volume * 100).round(),
      muted: s.muted,
      title: s.title,
    );
  }

  @override
  Future<void> play(Station station) async => client.load(
    url: station.url,
    title: station.name,
    subtitle: 'AUX FM',
    imageUrl: _artwork,
    contentType: await _contentType(station.url),
  );

  @override
  Future<void> stop() => client.stop();
  @override
  Future<void> setVolume(int volume) => client.setVolume(volume / 100);
  @override
  Future<void> setMuted(bool muted) => client.setMuted(muted);
  @override
  void dispose() => client.close();
}
