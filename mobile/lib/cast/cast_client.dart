import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'cast_message.dart';

typedef SocketConnector = Future<Socket> Function(
  String host,
  int port,
  Duration timeout,
);

class CastException implements Exception {
  CastException(this.message);
  final String message;
  @override
  String toString() => 'CastException: $message';
}

enum CastPlayerState { idle, buffering, playing, paused }

class CastStatus {
  const CastStatus({
    required this.playerState,
    required this.volume,
    required this.muted,
    this.title,
  });

  final CastPlayerState playerState;

  /// 0.0–1.0.
  final double volume;
  final bool muted;
  final String? title;

  bool get isPlaying =>
      playerState == CastPlayerState.playing ||
      playerState == CastPlayerState.buffering;
}

/// Minimal Google Cast (Cast v2) sender: plays a stream URL on a Chromecast,
/// Google / Nest speaker or speaker group through Google's Default Media
/// Receiver, and controls stop and volume.
///
/// Speaks the protocol directly over TLS (port 8009 by default), so it needs
/// no Google Play services.
class CastClient {
  CastClient(
    this.host, {
    this.port = 8009,
    SocketConnector? connector,
    this.timeout = const Duration(seconds: 5),
  }) : _connector = connector ?? _tlsConnect;

  static const defaultMediaReceiver = 'CC1AD845';

  static const _nsConnection = 'urn:x-cast:com.google.cast.tp.connection';
  static const _nsHeartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
  static const _nsReceiver = 'urn:x-cast:com.google.cast.receiver';
  static const _nsMedia = 'urn:x-cast:com.google.cast.media';
  static const _receiverId = 'receiver-0';
  static const _senderId = 'sender-auxfm';

  final String host;
  final int port;
  final Duration timeout;
  final SocketConnector _connector;

  Socket? _socket;
  Future<void>? _connecting;
  Timer? _heartbeat;
  int _requestId = 0;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  final _connectedTransports = <String>{};
  String? _transportId;

  Future<CastStatus> getStatus() async {
    final receiver = await _receiverStatus();
    final volume = receiver['volume'] as Map? ?? const {};
    var state = CastPlayerState.idle;
    String? title;
    final app = _mediaApp(receiver);
    if (app != null) {
      _useApp(app);
      final reply = await _request(_nsMedia, _transportId!, {
        'type': 'GET_STATUS',
      });
      final media = _firstMediaStatus(reply);
      if (media != null) {
        state = _playerState(media['playerState']);
        final metadata = (media['media'] as Map?)?['metadata'] as Map?;
        title = metadata?['title'] as String?;
      }
    }
    return CastStatus(
      playerState: state,
      volume: (volume['level'] as num?)?.toDouble() ?? 0,
      muted: volume['muted'] == true,
      title: title,
    );
  }

  /// Starts the Default Media Receiver if needed and plays [url] as a live
  /// stream.
  Future<void> load({
    required String url,
    required String title,
    String? subtitle,
    String? imageUrl,
    String contentType = 'audio/mpeg',
  }) async {
    await _launchApp();
    final reply = await _request(_nsMedia, _transportId!, {
      'type': 'LOAD',
      'autoplay': true,
      'media': {
        'contentId': url,
        'contentUrl': url,
        'streamType': 'LIVE',
        'contentType': contentType,
        'metadata': {
          'metadataType': 0,
          'title': title,
          'subtitle': ?subtitle,
          if (imageUrl != null)
            'images': [
              {'url': imageUrl},
            ],
        },
      },
    });
    if (reply['type'] != 'MEDIA_STATUS') {
      throw CastException(
        'Load failed: ${reply['type']} ${reply['reason'] ?? ''}'.trim(),
      );
    }
  }

  /// Stops playback by closing the media receiver app (the speaker goes
  /// back to idle). Leaves other apps (e.g. Spotify) alone.
  Future<void> stop() async {
    final app = _mediaApp(await _receiverStatus());
    if (app == null) return;
    await _request(_nsReceiver, _receiverId, {
      'type': 'STOP',
      'sessionId': app['sessionId'],
    });
    _connectedTransports.remove(_transportId);
    _transportId = null;
  }

  Future<void> setVolume(double level) => _request(_nsReceiver, _receiverId, {
    'type': 'SET_VOLUME',
    'volume': {'level': level.clamp(0.0, 1.0)},
  });

  Future<void> setMuted(bool muted) => _request(_nsReceiver, _receiverId, {
    'type': 'SET_VOLUME',
    'volume': {'muted': muted},
  });

  void close() {
    if (_socket != null) {
      _send(_nsConnection, _receiverId, {'type': 'CLOSE'});
    }
    _disconnected();
  }

  Future<void> _launchApp() async {
    var app = _mediaApp(await _receiverStatus());
    if (app == null) {
      final reply = await _request(_nsReceiver, _receiverId, {
        'type': 'LAUNCH',
        'appId': defaultMediaReceiver,
      });
      if (reply['type'] == 'LAUNCH_ERROR') {
        throw CastException('Launch failed: ${reply['reason'] ?? ''}');
      }
      app = _mediaApp(_status(reply));
      // Some devices reply before the app is listed; check again briefly.
      for (var i = 0; app == null && i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        app = _mediaApp(await _receiverStatus());
      }
      if (app == null) throw CastException('Media receiver did not start');
    }
    _useApp(app);
  }

  void _useApp(Map<dynamic, dynamic> app) {
    final transportId = app['transportId'] as String;
    _transportId = transportId;
    if (_connectedTransports.add(transportId)) {
      _send(_nsConnection, transportId, {'type': 'CONNECT'});
    }
  }

  Future<Map<dynamic, dynamic>> _receiverStatus() async =>
      _status(await _request(_nsReceiver, _receiverId, {'type': 'GET_STATUS'}));

  static Map<dynamic, dynamic> _status(Map<String, dynamic> reply) =>
      reply['status'] as Map? ?? const {};

  static Map<dynamic, dynamic>? _mediaApp(Map<dynamic, dynamic> status) {
    final apps = status['applications'] as List? ?? const [];
    for (final app in apps.whereType<Map<dynamic, dynamic>>()) {
      if (app['appId'] == defaultMediaReceiver) return app;
    }
    return null;
  }

  static Map<dynamic, dynamic>? _firstMediaStatus(Map<String, dynamic> reply) {
    final list = reply['status'];
    if (list is List && list.isNotEmpty && list.first is Map) {
      return list.first as Map;
    }
    return null;
  }

  static CastPlayerState _playerState(Object? value) => switch (value) {
    'PLAYING' => CastPlayerState.playing,
    'BUFFERING' || 'LOADING' => CastPlayerState.buffering,
    'PAUSED' => CastPlayerState.paused,
    _ => CastPlayerState.idle,
  };

  Future<Map<String, dynamic>> _request(
    String namespace,
    String destination,
    Map<String, dynamic> payload,
  ) async {
    await _ensureConnected();
    final id = ++_requestId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _send(namespace, destination, {...payload, 'requestId': id});
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(id);
      throw CastException('${payload['type']} timed out');
    }
  }

  Future<void> _ensureConnected() {
    if (_socket != null) return Future.value();
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    final Socket socket;
    try {
      socket = await _connector(host, port, timeout);
    } on Exception catch (e) {
      throw CastException('Cannot reach $host:$port ($e)');
    }
    final reader = CastFrameReader();
    _socket = socket;
    socket.listen(
      (data) {
        for (final message in reader.add(data)) {
          _onMessage(message);
        }
      },
      onError: (Object _) => _disconnected(),
      onDone: _disconnected,
      cancelOnError: true,
    );
    _send(_nsConnection, _receiverId, {'type': 'CONNECT'});
    _connectedTransports.add(_receiverId);
    _heartbeat = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _send(_nsHeartbeat, _receiverId, {'type': 'PING'}),
    );
  }

  void _onMessage(CastMessage message) {
    final json = message.json;
    final type = json['type'];
    if (message.namespace == _nsHeartbeat && type == 'PING') {
      _send(_nsHeartbeat, message.sourceId, {'type': 'PONG'});
      return;
    }
    if (message.namespace == _nsConnection && type == 'CLOSE') {
      _connectedTransports.remove(message.sourceId);
      if (message.sourceId == _transportId) _transportId = null;
      return;
    }
    final id = json['requestId'];
    if (id is int && id != 0) _pending.remove(id)?.complete(json);
  }

  void _send(String namespace, String destination, Map<String, dynamic> body) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(
        CastMessage(
          sourceId: _senderId,
          destinationId: destination,
          namespace: namespace,
          payload: jsonEncode(body),
        ).frame(),
      );
    } on Object {
      _disconnected();
    }
  }

  void _disconnected() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _socket?.destroy();
    _socket = null;
    _connectedTransports.clear();
    _transportId = null;
    final pending = _pending.values.toList();
    _pending.clear();
    for (final c in pending) {
      c.completeError(CastException('Connection to $host closed'));
    }
  }

  // Cast devices present self-signed device certificates.
  static Future<Socket> _tlsConnect(String host, int port, Duration timeout) =>
      SecureSocket.connect(
        host,
        port,
        timeout: timeout,
        onBadCertificate: (_) => true,
      );
}

/// Looks up a stream's MIME type (the Cast receiver needs it). Falls back to
/// `audio/mpeg`, which almost all radio streams are.
Future<String> streamContentType(
  String url, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
    final response = await request.close().timeout(timeout);
    final mime = response.headers.contentType?.mimeType;
    final socket = await response.detachSocket();
    socket.destroy();
    if (mime != null &&
        (mime.startsWith('audio/') || mime.contains('mpegurl'))) {
      return mime;
    }
  } on Object {
    // fall through to the default
  } finally {
    client.close(force: true);
  }
  return 'audio/mpeg';
}
