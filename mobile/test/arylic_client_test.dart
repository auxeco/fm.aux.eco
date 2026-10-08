import 'dart:convert';
import 'dart:io';

import 'package:aux_fm/arylic/arylic_client.dart';
import 'package:flutter_test/flutter_test.dart';

String hex(String s) =>
    utf8.encode(s).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('decodeLinkPlayText', () {
    test('decodes hex-encoded UTF-8', () {
      expect(decodeLinkPlayText(hex('Zürich Nights')), 'Zürich Nights');
    });
    test('leaves plain text alone', () {
      expect(decodeLinkPlayText('NTS 1'), 'NTS 1');
      expect(decodeLinkPlayText('ABBA'), 'ABBA'); // invalid UTF-8 as hex
      expect(decodeLinkPlayText('1234'), '1234'); // control chars as hex
      expect(decodeLinkPlayText(''), '');
    });
  });

  group('ArylicClient against a fake device', () {
    late HttpServer server;
    late List<String> commands;
    late ArylicClient client;
    var status = <String, Object>{};

    setUp(() async {
      commands = [];
      status = {
        'status': 'play',
        'vol': '42',
        'mute': '0',
        'mode': '10',
        'Title': hex('Live from Glasgow'),
        'Artist': hex('Unknown'),
      };
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) {
        expect(req.uri.path, '/httpapi.asp');
        // Read the raw query: the device parses `command=` itself.
        final raw = req.uri.query;
        expect(raw, startsWith('command='));
        final cmd = Uri.decodeQueryComponent(raw.substring('command='.length));
        commands.add(cmd);
        final body = switch (cmd) {
          'getStatusEx' => jsonEncode({
            'DeviceName': 'Living Room',
            'firmware': '4.6.1',
          }),
          'getPlayerStatus' => jsonEncode(status),
          'bogus' => 'unknown command',
          _ => 'OK',
        };
        req.response
          ..write(body)
          ..close();
      });
      client = ArylicClient('127.0.0.1:${server.port}');
    });

    tearDown(() => server.close(force: true));

    test('reads device info', () async {
      final info = await client.getDeviceInfo();
      expect(info.name, 'Living Room');
      expect(info.firmware, '4.6.1');
    });

    test('reads player status and decodes metadata', () async {
      final s = await client.getPlayerStatus();
      expect(s.playback, AmpPlayback.playing);
      expect(s.isPlaying, isTrue);
      expect(s.volume, 42);
      expect(s.muted, isFalse);
      expect(s.title, 'Live from Glasgow');
      expect(s.artist, isNull); // "Unknown" is dropped
    });

    test('plays a stream URL with query string intact', () async {
      const url =
          'https://uplink.byte.fm/bytefm-main/mp3-128/?ar-distributor=ffa0';
      await client.playUrl(url);
      expect(commands.single, 'setPlayerCmd:play:$url');
    });

    test('transport and volume commands', () async {
      await client.stop();
      await client.pause();
      await client.resume();
      await client.setVolume(150);
      await client.setMuted(true);
      expect(commands, [
        'setPlayerCmd:stop',
        'setPlayerCmd:pause',
        'setPlayerCmd:resume',
        'setPlayerCmd:vol:100',
        'setPlayerCmd:mute:1',
      ]);
    });

    test('non-OK replies throw', () async {
      await expectLater(
        client.command('bogus').then((b) => b),
        completion('unknown command'),
      );
      final failing = ArylicClient('h', httpGet: (_) async => 'Failed');
      await expectLater(failing.stop(), throwsA(isA<ArylicException>()));
    });
  });

  test('falls back to HTTPS when HTTP is unreachable', () async {
    final seen = <String>[];
    final client = ArylicClient(
      '10.0.0.9',
      httpGet: (uri) async {
        seen.add(uri.scheme);
        if (uri.scheme == 'http') throw const SocketException('refused');
        return 'OK';
      },
    );
    await client.stop();
    await client.pause();
    expect(seen, ['http', 'https', 'https']);
  });
}
