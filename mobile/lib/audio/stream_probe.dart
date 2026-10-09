import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// What the start of a stream URL turned out to be.
class StreamProbe {
  StreamProbe(this.status, this.type, this.bytes, this.kind, [this.error]);

  final int status;
  final String type;
  final int bytes;

  /// mp3, aac, ogg, flac, hls, playlist, html or unknown, sniffed from the
  /// bytes rather than trusting the Content-Type.
  final String kind;
  final String? error;

  /// The URL delivers audio the player can use directly.
  bool get ok =>
      error == null &&
      status == 200 &&
      (kind == 'hls' ||
          (bytes >= 8192 &&
              const {'mp3', 'aac', 'ogg', 'flac'}.contains(kind)));

  String get summary => [
    ok ? 'OK  ' : 'FAIL',
    '$status'.padLeft(3),
    kind.padRight(8),
    '${bytes ~/ 1024}k'.padLeft(4),
    type.padRight(24),
    if (error != null) 'error=$error',
  ].join(' ');
}

/// Fetches the first ~32 KB of [url] and works out whether it is a stream.
Future<StreamProbe> probeStream(
  String url, {
  Duration timeout = const Duration(seconds: 8),
  String userAgent = 'AUX-FM/1.0',
}) async {
  final client = HttpClient()
    ..connectionTimeout = timeout
    ..userAgent = userAgent;
  try {
    final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
    request.maxRedirects = 8;
    final response = await request.close().timeout(timeout);
    final type = response.headers.contentType?.mimeType ?? '-';
    final body = <int>[];
    try {
      await for (final chunk in response.timeout(timeout)) {
        body.addAll(chunk);
        if (body.length >= 32 * 1024) break;
      }
    } on TimeoutException {
      // Keep what arrived.
    }
    return StreamProbe(
      response.statusCode,
      type,
      body.length,
      sniffStream(type, body),
    );
  } on Object catch (e) {
    return StreamProbe(0, '-', 0, '-', e.toString().split('\n').first);
  } finally {
    client.close(force: true);
  }
}

/// Identifies a stream from its first bytes.
String sniffStream(String type, List<int> b) {
  String head(int n) =>
      String.fromCharCodes(b.take(n).where((c) => c >= 32 && c < 127));
  if (b.length >= 3 && head(3) == 'ID3') return 'mp3';
  if (b.length >= 4 && head(4) == 'OggS') return 'ogg';
  if (b.length >= 4 && head(4) == 'fLaC') return 'flac';
  final text = head(64).toLowerCase();
  if (text.startsWith('#extm3u')) {
    return utf8.decode(b, allowMalformed: true).contains('#EXT-X-')
        ? 'hls'
        : 'playlist';
  }
  if (text.startsWith('[playlist]') || text.startsWith('http')) {
    return 'playlist';
  }
  if (text.contains('<html') || text.contains('<!doctype')) return 'html';
  // Count frame syncs to avoid false positives on random bytes.
  var mp3 = 0, adts = 0;
  for (var i = 0; i + 1 < b.length && i < 16384; i++) {
    if (b[i] != 0xFF) continue;
    final n = b[i + 1];
    if ((n & 0xF6) == 0xF0) {
      adts++;
    } else if ((n & 0xE0) == 0xE0) {
      mp3++;
    }
  }
  if (adts >= 4 && adts >= mp3) return 'aac';
  if (mp3 >= 4) return 'mp3';
  if (type.startsWith('audio/')) return type.split('/').last;
  return 'unknown';
}
