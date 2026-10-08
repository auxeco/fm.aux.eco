import 'dart:convert';
import 'dart:io';

import 'package:aux_fm/cast/cast_client.dart';
import 'package:aux_fm/cast/cast_message.dart';

/// A Cast device speaking the real wire protocol over plain TCP on
/// localhost (TLS is the only thing skipped).
class FakeCastDevice {
  late ServerSocket _server;
  final received = <CastMessage>[];
  final _clients = <Socket>[];

  double volume = 0.4;
  bool muted = false;
  Map<String, dynamic>? app; // running Default Media Receiver
  Map<String, dynamic>? media; // current media status
  bool listAppLate = false; // LAUNCH reply omits the app (seen on devices)
  bool failLoad = false;

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((socket) {
      _clients.add(socket);
      final reader = CastFrameReader();
      socket.listen((data) {
        for (final m in reader.add(data)) {
          received.add(m);
          _handle(socket, m);
        }
      });
    });
  }

  Future<void> close() async {
    for (final c in _clients) {
      c.destroy();
    }
    await _server.close();
  }

  /// Simulates the device dropping the connection.
  void dropConnections() {
    for (final c in _clients) {
      c.destroy();
    }
    _clients.clear();
  }

  SocketConnector get connector =>
      (host, port, timeout) =>
          Socket.connect(InternetAddress.loopbackIPv4, _server.port);

  CastClient client() => CastClient('fake-cast', connector: connector);

  List<String> typesSent(String namespaceSuffix) => received
      .where((m) => m.namespace.endsWith(namespaceSuffix))
      .map((m) => m.json['type'] as String)
      .toList();

  void _handle(Socket socket, CastMessage m) {
    final json = m.json;
    final id = json['requestId'];
    void reply(String ns, Map<String, dynamic> body) {
      socket.add(
        CastMessage(
          sourceId: m.destinationId,
          destinationId: m.sourceId,
          namespace: ns,
          payload: jsonEncode({...body, 'requestId': ?id}),
        ).frame(),
      );
    }

    Map<String, dynamic> receiverStatus({bool hideApp = false}) => {
      'type': 'RECEIVER_STATUS',
      'status': {
        'volume': {'level': volume, 'muted': muted},
        if (app != null && !hideApp) 'applications': [app],
      },
    };

    switch ((m.namespace.split('.').last, json['type'])) {
      case ('heartbeat', 'PING'):
        reply(m.namespace, {'type': 'PONG'});
      case ('receiver', 'GET_STATUS'):
        reply(m.namespace, receiverStatus());
      case ('receiver', 'LAUNCH'):
        app = {
          'appId': json['appId'],
          'sessionId': 'session-1',
          'transportId': 'web-7',
          'displayName': 'Default Media Receiver',
        };
        reply(m.namespace, receiverStatus(hideApp: listAppLate));
      case ('receiver', 'STOP'):
        app = null;
        media = null;
        reply(m.namespace, receiverStatus());
      case ('receiver', 'SET_VOLUME'):
        final v = json['volume'] as Map;
        volume = (v['level'] as num?)?.toDouble() ?? volume;
        muted = (v['muted'] as bool?) ?? muted;
        reply(m.namespace, receiverStatus());
      case ('media', 'LOAD') when m.destinationId == app?['transportId']:
        if (failLoad) {
          reply(m.namespace, {'type': 'LOAD_FAILED'});
          return;
        }
        media = {
          'mediaSessionId': 1,
          'playerState': 'PLAYING',
          'media': json['media'],
        };
        reply(m.namespace, {
          'type': 'MEDIA_STATUS',
          'status': [media],
        });
      case ('media', 'GET_STATUS'):
        reply(m.namespace, {
          'type': 'MEDIA_STATUS',
          'status': [?media],
        });
      default:
        break;
    }
  }
}
