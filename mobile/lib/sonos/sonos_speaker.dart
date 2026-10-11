import '../models/station.dart';
import '../speakers/remote_speaker.dart';
import 'sonos_client.dart';
import 'sonos_discovery.dart';

typedef SonosClientFactory = SonosClient Function(String host, int port);

/// A Sonos room (or group) as an output. Commands go to the group's
/// coordinator; if the rooms were regrouped in the Sonos app since, the
/// new coordinator is looked up and the command retried.
class SonosSpeaker implements RemoteSpeaker {
  SonosSpeaker(this.room, {SonosClientFactory? clientFactory})
    : _clientFor = clientFactory ?? _defaultClient {
    _client = _clientFor(room.host, room.port);
  }

  static SonosClient _defaultClient(String host, int port) =>
      SonosClient(host, port: port);

  final SonosRoom room;
  final SonosClientFactory _clientFor;
  late SonosClient _client;

  @override
  String get id => 'sonos:${room.id}';
  @override
  String get name => room.label;
  @override
  SpeakerKind get kind => SpeakerKind.sonos;

  @override
  Future<SpeakerStatus> status() => _onCoordinator((c) async {
    final s = await c.status();
    return SpeakerStatus(
      playing:
          s.transport == SonosTransport.playing ||
          s.transport == SonosTransport.transitioning,
      loading: s.transport == SonosTransport.transitioning,
      volume: s.volume,
      muted: s.muted,
      title: s.title,
    );
  });

  @override
  Future<void> play(Station station) =>
      _onCoordinator((c) => c.playStream(station.url, station.name));
  @override
  Future<void> stop() => _onCoordinator((c) => c.stop());
  @override
  Future<void> setVolume(int volume) =>
      _onCoordinator((c) => c.setVolume(volume));
  @override
  Future<void> setMuted(bool muted) => _onCoordinator((c) => c.setMuted(muted));
  @override
  void dispose() {}

  Future<T> _onCoordinator<T>(Future<T> Function(SonosClient c) action) async {
    try {
      return await action(_client);
    } on SonosException catch (e) {
      // 800: this speaker no longer coordinates its group.
      if (e.code != 800) rethrow;
    }
    for (final group in await _client.zoneGroups()) {
      if (group.members.any((m) => m.id == room.id)) {
        final coordinator = group.coordinator;
        if (coordinator != null) {
          _client = _clientFor(coordinator.host, coordinator.port);
        }
        break;
      }
    }
    return action(_client);
  }
}
