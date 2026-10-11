import '../net/ssdp.dart';
import 'arylic_client.dart';

class DiscoveredAmp {
  const DiscoveredAmp({required this.host, required this.name, this.uuid});
  final String host;
  final String name;
  final String? uuid;
}

/// Finds Arylic / LinkPlay devices on the local network.
///
/// Sends an SSDP M-SEARCH for UPnP media renderers, then confirms each
/// responder by calling its Arylic HTTP API, so other renderers on the
/// network (TVs, Sonos, ...) are filtered out.
class ArylicDiscovery {
  static const _searchTargets = [
    'urn:schemas-upnp-org:device:MediaRenderer:1',
    'ssdp:all',
  ];

  Future<List<DiscoveredAmp>> discover({
    Duration listenFor = const Duration(seconds: 3),
  }) async {
    final hosts = await ssdpSearch(_searchTargets, listenFor: listenFor);
    final results = await Future.wait(hosts.map(_probe));
    return results.whereType<DiscoveredAmp>().toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<DiscoveredAmp?> _probe(String host) async {
    try {
      final info = await ArylicClient(
        host,
        timeout: const Duration(seconds: 2),
      ).getDeviceInfo();
      return DiscoveredAmp(host: host, name: info.name, uuid: info.uuid);
    } on Exception {
      return null;
    }
  }
}
