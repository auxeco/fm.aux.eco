import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Performs a GET request and returns the response body.
typedef HttpGet = Future<String> Function(Uri uri);

class ArylicException implements Exception {
  ArylicException(this.message);
  final String message;
  @override
  String toString() => 'ArylicException: $message';
}

class ArylicDeviceInfo {
  const ArylicDeviceInfo({
    required this.name,
    this.firmware,
    this.project,
    this.uuid,
  });

  factory ArylicDeviceInfo.fromJson(Map<String, dynamic> json) {
    final name = (json['DeviceName'] ?? json['ssid'] ?? 'Arylic').toString();
    return ArylicDeviceInfo(
      name: name,
      firmware: json['firmware']?.toString(),
      project: json['project']?.toString(),
      // Stable device identity; MAC as a fallback on firmware without uuid.
      uuid: (json['uuid'] ?? json['MAC'])?.toString(),
    );
  }

  final String name;
  final String? firmware;
  final String? project;
  final String? uuid;
}

enum AmpPlayback { playing, paused, stopped, loading, unknown }

class ArylicPlayerStatus {
  const ArylicPlayerStatus({
    required this.playback,
    required this.volume,
    required this.muted,
    this.title,
    this.artist,
    this.mode,
  });

  factory ArylicPlayerStatus.fromJson(Map<String, dynamic> json) {
    final playback = switch (json['status']?.toString()) {
      'play' => AmpPlayback.playing,
      'pause' => AmpPlayback.paused,
      'stop' || 'none' => AmpPlayback.stopped,
      'load' || 'loading' => AmpPlayback.loading,
      _ => AmpPlayback.unknown,
    };
    return ArylicPlayerStatus(
      playback: playback,
      volume: int.tryParse(json['vol']?.toString() ?? '') ?? 0,
      muted: json['mute']?.toString() == '1',
      title: _meta(json['Title']),
      artist: _meta(json['Artist']),
      mode: int.tryParse(json['mode']?.toString() ?? ''),
    );
  }

  final AmpPlayback playback;

  /// 0–100.
  final int volume;
  final bool muted;
  final String? title;
  final String? artist;

  /// Input / source mode as reported by the device (e.g. 10+ = network).
  final int? mode;

  bool get isPlaying =>
      playback == AmpPlayback.playing || playback == AmpPlayback.loading;

  static String? _meta(Object? raw) {
    if (raw == null) return null;
    final text = decodeLinkPlayText(raw.toString()).trim();
    if (text.isEmpty || text.toLowerCase().startsWith('unknow')) return null;
    return text;
  }
}

/// LinkPlay firmware (which Arylic devices run) hex-encodes metadata strings
/// on most versions and sends plain text on others. Decode only when the
/// value is clearly hex-encoded UTF-8.
String decodeLinkPlayText(String value) {
  if (value.isEmpty ||
      value.length.isOdd ||
      !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
    return value;
  }
  final bytes = <int>[
    for (var i = 0; i < value.length; i += 2)
      int.parse(value.substring(i, i + 2), radix: 16),
  ];
  final String decoded;
  try {
    decoded = utf8.decode(bytes);
  } on FormatException {
    return value;
  }
  // Reject results containing control characters: the input was plain text
  // that merely looked like hex (e.g. "1234").
  if (decoded.runes.any((r) => r < 0x20 && r != 0x09)) return value;
  return decoded;
}

/// Client for the HTTP API of Arylic / LinkPlay devices (Up2Stream Amp etc.).
///
/// All commands go to `http://<host>/httpapi.asp?command=<cmd>`. Some newer
/// firmware only answers over HTTPS with a self-signed certificate, so the
/// client falls back to HTTPS when plain HTTP cannot connect.
class ArylicClient {
  ArylicClient(
    this.host, {
    HttpGet? httpGet,
    this.timeout = const Duration(seconds: 4),
  }) : _get = httpGet ?? _defaultGet(host, timeout);

  final String host;
  final Duration timeout;
  final HttpGet _get;
  bool _useHttps = false;

  Future<ArylicDeviceInfo> getDeviceInfo() async =>
      ArylicDeviceInfo.fromJson(_decodeJson(await command('getStatusEx')));

  Future<ArylicPlayerStatus> getPlayerStatus() async =>
      ArylicPlayerStatus.fromJson(
        _decodeJson(await command('getPlayerStatus')),
      );

  /// Start playing a stream URL on the device.
  Future<void> playUrl(String url) =>
      _expectOk('setPlayerCmd:play:${Uri.encodeComponent(url)}');

  Future<void> pause() => _expectOk('setPlayerCmd:pause');
  Future<void> resume() => _expectOk('setPlayerCmd:resume');
  Future<void> stop() => _expectOk('setPlayerCmd:stop');

  Future<void> setVolume(int volume) =>
      _expectOk('setPlayerCmd:vol:${volume.clamp(0, 100)}');

  Future<void> setMuted(bool muted) =>
      _expectOk('setPlayerCmd:mute:${muted ? 1 : 0}');

  /// Sends a raw API command and returns the response body.
  ///
  /// [cmd] must already be URL-safe: the device expects literal `:`
  /// separators, so it is not re-encoded here.
  Future<String> command(String cmd) async {
    try {
      return await _get(_uri(cmd, https: _useHttps));
    } on Exception catch (e) {
      final unreachable = e is SocketException || e is TimeoutException;
      if (_useHttps || !unreachable) rethrow;
    }
    final body = await _get(_uri(cmd, https: true));
    _useHttps = true;
    return body;
  }

  Uri _uri(String cmd, {required bool https}) =>
      Uri.parse('${https ? 'https' : 'http'}://$host/httpapi.asp?command=$cmd');

  Future<void> _expectOk(String cmd) async {
    final body = (await command(cmd)).trim();
    if (body.toUpperCase() != 'OK') {
      throw ArylicException('"$cmd" failed: $body');
    }
  }

  Map<String, dynamic> _decodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // fall through
    }
    throw ArylicException('Unexpected response: $body');
  }

  static HttpGet _defaultGet(String host, Duration timeout) {
    final client = HttpClient()
      ..connectionTimeout = timeout
      // The HTTPS fallback targets a LAN device with a self-signed
      // certificate; trust it for that host only.
      ..badCertificateCallback = (cert, certHost, port) => certHost == host;
    return (uri) async {
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw ArylicException('HTTP ${response.statusCode} from $uri');
      }
      return body;
    };
  }
}
