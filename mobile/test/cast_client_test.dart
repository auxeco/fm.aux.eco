import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aux_fm/cast/cast_client.dart';
import 'package:aux_fm/cast/cast_message.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_cast_device.dart';

void main() {
  group('CastMessage', () {
    test('round-trips through protobuf framing, split across chunks', () {
      final long = jsonEncode({'type': 'LOAD', 'pad': 'x' * 400});
      final a = CastMessage(
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: 'urn:x-cast:com.google.cast.receiver',
        payload: long,
      );
      const b = CastMessage(
        sourceId: 's',
        destinationId: 'd',
        namespace: 'n',
        payload: '{"type":"PING"}',
      );
      final bytes = Uint8List.fromList([...a.frame(), ...b.frame()]);
      final reader = CastFrameReader();
      final out = [
        ...reader.add(bytes.sublist(0, 3)),
        ...reader.add(bytes.sublist(3, 300)),
        ...reader.add(bytes.sublist(300)),
      ];
      expect(out, hasLength(2));
      expect(out[0].payload, long);
      expect(out[0].namespace, a.namespace);
      expect(out[1].json['type'], 'PING');
    });

    test('matches the reference protobuf encoding', () {
      const m = CastMessage(
        sourceId: 'a',
        destinationId: 'b',
        namespace: 'c',
        payload: 'd',
      );
      expect(m.encode(), [
        0x08, 0x00, // protocol_version
        0x12, 0x01, 0x61, // source_id
        0x1a, 0x01, 0x62, // destination_id
        0x22, 0x01, 0x63, // namespace
        0x28, 0x00, // payload_type
        0x32, 0x01, 0x64, // payload_utf8
      ]);
    });
  });

  group('CastClient against a fake device', () {
    late FakeCastDevice device;
    late CastClient client;

    setUp(() async {
      device = FakeCastDevice();
      await device.start();
      client = device.client();
    });

    tearDown(() async {
      client.close();
      await device.close();
    });

    test('idle device reports volume and no playback', () async {
      final s = await client.getStatus();
      expect(s.playerState, CastPlayerState.idle);
      expect(s.isPlaying, isFalse);
      expect(s.volume, 0.4);
    });

    test('load launches the media receiver and plays a live stream', () async {
      await client.load(
        url: 'https://stream-relay-geo.ntslive.net/stream',
        title: 'NTS 1',
        contentType: 'audio/mpeg',
      );
      expect(device.typesSent('receiver'), ['GET_STATUS', 'LAUNCH']);
      final load = device.received.firstWhere((m) => m.json['type'] == 'LOAD');
      expect(load.destinationId, 'web-7');
      final media = load.json['media'] as Map;
      expect(media['contentId'], 'https://stream-relay-geo.ntslive.net/stream');
      expect(media['streamType'], 'LIVE');
      expect((media['metadata'] as Map)['title'], 'NTS 1');
      // Connected to the app's transport before talking to it.
      final connects = device.received
          .where((m) => m.json['type'] == 'CONNECT')
          .map((m) => m.destinationId);
      expect(connects, ['receiver-0', 'web-7']);

      final s = await client.getStatus();
      expect(s.isPlaying, isTrue);
      expect(s.title, 'NTS 1');
    });

    test('reuses a running receiver instead of relaunching', () async {
      await client.load(url: 'u1', title: 'A');
      await client.load(url: 'u2', title: 'B');
      expect(device.typesSent('receiver'), [
        'GET_STATUS',
        'LAUNCH',
        'GET_STATUS',
      ]);
    });

    test('waits for an app that is listed late', () async {
      device.listAppLate = true;
      await client.load(url: 'u', title: 'A');
      expect(device.media, isNotNull);
    });

    test('stop closes the receiver app; volume and mute', () async {
      await client.load(url: 'u', title: 'A');
      await client.stop();
      expect(device.app, isNull);
      expect((await client.getStatus()).isPlaying, isFalse);

      await client.setVolume(0.75);
      await client.setMuted(true);
      expect(device.volume, 0.75);
      expect(device.muted, isTrue);
    });

    test('load failure throws', () async {
      device.failLoad = true;
      await expectLater(
        client.load(url: 'u', title: 'A'),
        throwsA(isA<CastException>()),
      );
    });

    test('reconnects after the device drops the connection', () async {
      await client.getStatus();
      device.dropConnections();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final s = await client.getStatus();
      expect(s.volume, 0.4);
      expect(
        device.received.where((m) => m.json['type'] == 'CONNECT').length,
        2,
      );
    });
  });

  test('unreachable device throws CastException', () async {
    final client = CastClient(
      'nowhere',
      connector: (h, p, t) => throw const SocketException('refused'),
    );
    await expectLater(client.getStatus(), throwsA(isA<CastException>()));
  });
}
