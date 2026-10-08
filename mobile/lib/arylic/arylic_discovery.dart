import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'arylic_client.dart';

class DiscoveredAmp {
  const DiscoveredAmp({required this.host, required this.name});
  final String host;
  final String name;
}

/// Finds Arylic / LinkPlay devices on the local network.
///
/// Sends an SSDP M-SEARCH for UPnP media renderers, then confirms each
/// responder by calling its Arylic HTTP API, so other renderers on the
/// network (TVs, Sonos, ...) are filtered out.
class ArylicDiscovery {
  static final _multicast = InternetAddress('239.255.255.250');
  static const _port = 1900;
  static const _searchTargets = [
    'urn:schemas-upnp-org:device:MediaRenderer:1',
    'ssdp:all',
  ];

  Future<List<DiscoveredAmp>> discover({
    Duration listenFor = const Duration(seconds: 3),
  }) async {
    final hosts = await _ssdpHosts(listenFor);
    final results = await Future.wait(hosts.map(_probe));
    return results.whereType<DiscoveredAmp>().toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<Set<String>> _ssdpHosts(Duration listenFor) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final hosts = <String>{};
    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      final text = utf8.decode(datagram.data, allowMalformed: true);
      if (text.startsWith('HTTP/1.1 200') || text.startsWith('NOTIFY')) {
        hosts.add(datagram.address.address);
      }
    });
    for (final st in _searchTargets) {
      final message =
          'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 2\r\n'
          'ST: $st\r\n\r\n';
      socket.send(utf8.encode(message), _multicast, _port);
    }
    await Future<void>.delayed(listenFor);
    await sub.cancel();
    socket.close();
    return hosts;
  }

  Future<DiscoveredAmp?> _probe(String host) async {
    try {
      final info = await ArylicClient(
        host,
        timeout: const Duration(seconds: 2),
      ).getDeviceInfo();
      return DiscoveredAmp(host: host, name: info.name);
    } on Exception {
      return null;
    }
  }
}
