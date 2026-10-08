import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';

class CastDevice {
  const CastDevice({
    required this.id,
    required this.name,
    required this.host,
    this.port = 8009,
    this.model,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String? model;
}

/// Keeps a live list of Google Cast devices on the network.
abstract class CastDiscovery {
  List<CastDevice> get devices;
  Stream<List<CastDevice>> get changes;
  Future<void> start();
  Future<void> stop();
}

/// mDNS (`_googlecast._tcp`) discovery through the OS service browser
/// (NsdManager on Android, Bonjour on iOS).
class BonsoirCastDiscovery implements CastDiscovery {
  static const _type = '_googlecast._tcp';

  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _sub;
  final _byService = <String, CastDevice>{};
  final _changes = StreamController<List<CastDevice>>.broadcast();

  @override
  List<CastDevice> get devices {
    final list = _byService.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Stream<List<CastDevice>> get changes => _changes.stream;

  @override
  Future<void> start() async {
    if (_discovery != null) return;
    final discovery = BonsoirDiscovery(type: _type);
    _discovery = discovery;
    await discovery.initialize();
    _sub = discovery.eventStream?.listen((event) {
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent():
          event.service.resolve(discovery.serviceResolver);
        case BonsoirDiscoveryServiceResolvedEvent():
          _add(event.service);
        case BonsoirDiscoveryServiceUpdatedEvent():
          _add(event.service);
        case BonsoirDiscoveryServiceLostEvent():
          if (_byService.remove(event.service.name) != null) _emit();
        default:
          break;
      }
    });
    await discovery.start();
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _discovery?.stop();
    _discovery = null;
  }

  void _add(BonsoirService service) {
    final host = _pickAddress(service.hostAddresses);
    if (host == null) return;
    final attrs = service.attributes;
    _byService[service.name] = CastDevice(
      id: attrs['id'] ?? service.name,
      name: attrs['fn'] ?? service.name,
      host: host,
      port: service.port,
      model: attrs['md'],
    );
    _emit();
  }

  void _emit() => _changes.add(devices);

  /// Prefers IPv4; IPv6 link-local addresses need a zone and are skipped.
  static String? _pickAddress(List<String> addresses) {
    String? fallback;
    for (final a in addresses) {
      final parsed = InternetAddress.tryParse(a);
      if (parsed == null) continue;
      if (parsed.type == InternetAddressType.IPv4) return a;
      if (!parsed.isLinkLocal) fallback ??= a;
    }
    return fallback;
  }
}
