import '../net/ssdp.dart';
import 'sonos_client.dart';

/// A Sonos room or group of rooms, as one output.
class SonosRoom {
  const SonosRoom({
    required this.id,
    required this.name,
    required this.host,
    this.port = 1400,
    this.otherRooms = const [],
  });

  /// RINCON_… id of the room that coordinates the group.
  final String id;
  final String name;
  final String host;
  final int port;

  /// Other rooms grouped with this one in the Sonos app.
  final List<String> otherRooms;

  String get label =>
      otherRooms.isEmpty ? name : '$name + ${otherRooms.join(' + ')}';
}

/// One output per Sonos group, named after its rooms; hidden players
/// (bridges, subs, surrounds) are left out.
List<SonosRoom> roomsFromGroups(List<SonosGroup> groups) {
  final rooms = <SonosRoom>[];
  for (final g in groups) {
    final coordinator = g.coordinator;
    if (coordinator == null || coordinator.hidden) continue;
    final others = <String>{
      for (final m in g.members)
        if (!m.hidden && m.name != coordinator.name) m.name,
    }.toList()..sort();
    rooms.add(
      SonosRoom(
        id: coordinator.id,
        name: coordinator.name,
        host: coordinator.host,
        port: coordinator.port,
        otherRooms: others,
      ),
    );
  }
  return rooms..sort((a, b) => a.label.compareTo(b.label));
}

/// Finds Sonos speakers with an SSDP search, then asks one of them for
/// the household's rooms and groups.
class SonosDiscovery {
  Future<List<SonosRoom>> discover({
    Duration listenFor = const Duration(seconds: 2),
  }) async {
    final hosts = await ssdpSearch(
      const ['urn:schemas-upnp-org:device:ZonePlayer:1'],
      listenFor: listenFor,
      accept: (r) => r.contains('ZonePlayer') || r.contains('Sonos'),
    );
    for (final host in hosts) {
      try {
        return roomsFromGroups(await SonosClient(host).zoneGroups());
      } on Exception {
        continue;
      }
    }
    return const [];
  }
}
