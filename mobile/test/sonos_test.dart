import 'package:aux_fm/models/station.dart';
import 'package:aux_fm/sonos/sonos_client.dart';
import 'package:aux_fm/sonos/sonos_discovery.dart';
import 'package:aux_fm/sonos/sonos_speaker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_sonos.dart';

const nts = Station(
  id: 'NTS',
  name: 'NTS 1',
  url: 'https://stream-relay-geo.ntslive.net/stream?x=1&y=2',
  description: '',
);

String household({required String livingRoom, String kitchen = ''}) =>
    '<ZoneGroupState><ZoneGroups>'
    '<ZoneGroup Coordinator="RINCON_A" ID="RINCON_A:1">'
    '<ZoneGroupMember UUID="RINCON_A" Location="$livingRoom" '
    'ZoneName="Living Room">'
    '<Satellite UUID="RINCON_SUB" Location="http://10.0.0.9:1400/x.xml" '
    'ZoneName="Living Room" Invisible="1"/>'
    '</ZoneGroupMember>'
    '<ZoneGroupMember UUID="RINCON_B" '
    'Location="${kitchen.isEmpty ? 'http://10.0.0.6:1400/x.xml' : kitchen}" '
    'ZoneName="Kitchen"/>'
    '</ZoneGroup>'
    '<ZoneGroup Coordinator="RINCON_C" ID="RINCON_C:2">'
    '<ZoneGroupMember UUID="RINCON_C" Location="http://10.0.0.7:1400/x.xml" '
    'ZoneName="Bedroom"/></ZoneGroup>'
    '<ZoneGroup Coordinator="RINCON_BR" ID="RINCON_BR:3">'
    '<ZoneGroupMember UUID="RINCON_BR" Location="http://10.0.0.8:1400/x.xml" '
    'ZoneName="BRIDGE" IsZoneBridge="1"/></ZoneGroup>'
    '</ZoneGroups><VanishedDevices/></ZoneGroupState>';

void main() {
  test('radio URIs use the scheme Sonos accepts for internet radio', () {
    expect(
      radioUri('https://a.example/live?x=1'),
      'x-rincon-mp3radio://a.example/live?x=1',
    );
    expect(
      radioUri('http://1.2.3.4:8000/radio.mp3'),
      'x-rincon-mp3radio://1.2.3.4:8000/radio.mp3',
    );
  });

  test('stream titles come from the radio metadata', () {
    expect(streamTitle(null), isNull);
    expect(streamTitle('NOT_IMPLEMENTED'), isNull);
    expect(
      streamTitle(
        '<DIDL-Lite xmlns:r="r" xmlns:dc="d"><item>'
        '<dc:title>x-sonosapi-stream:1</dc:title>'
        '<r:streamContent>Floating Points - Silhouettes</r:streamContent>'
        '</item></DIDL-Lite>',
      ),
      'Floating Points - Silhouettes',
    );
  });

  test('rooms: one per group, hidden players left out', () {
    final rooms = roomsFromGroups(
      parseZoneGroups(household(livingRoom: 'http://10.0.0.5:1400/x.xml')),
    );
    expect(rooms.map((r) => r.label), ['Bedroom', 'Living Room + Kitchen']);
    final living = rooms.last;
    expect(living.id, 'RINCON_A');
    expect(living.host, '10.0.0.5');
    expect(living.port, 1400);
  });

  test('zone groups from older (S1) firmware parse too', () {
    final groups = parseZoneGroups(
      '<ZoneGroups><ZoneGroup Coordinator="RINCON_X" ID="g">'
      '<ZoneGroupMember UUID="RINCON_X" Location="http://10.1.1.1:1400/d.xml" '
      'ZoneName="Office"/></ZoneGroup></ZoneGroups>',
    );
    expect(roomsFromGroups(groups).single.name, 'Office');
  });

  group('SonosClient against a fake player', () {
    late FakeSonos sonos;
    setUp(() async {
      sonos = FakeSonos();
      await sonos.start();
    });
    tearDown(() => sonos.close());

    test('plays a station as radio and reads status', () async {
      final c = sonos.client();
      await c.playStream(nts.url, 'NTS 1 & friends');
      expect(sonos.actions, ['SetAVTransportURI', 'Play']);
      expect(
        sonos.uri,
        'x-rincon-mp3radio://stream-relay-geo.ntslive.net/stream?x=1&y=2',
      );
      expect(
        sonos.metadata,
        contains('<dc:title>NTS 1 &amp; friends</dc:title>'),
      );
      expect(sonos.metadata, contains('object.item.audioItem.audioBroadcast'));

      sonos.streamContent = 'Live from London';
      final s = await c.status();
      expect(s.transport, SonosTransport.playing);
      expect(s.volume, 25);
      expect(s.title, 'Live from London');
    });

    test('stop, group volume and mute', () async {
      final c = sonos.client();
      await c.stop(); // already stopped: Sonos answers 701, not an error
      await c.playStream(nts.url, 'NTS 1');
      await c.stop();
      expect(sonos.state, 'STOPPED');
      await c.setVolume(140);
      await c.setMuted(true);
      expect(sonos.volume, 100);
      expect(sonos.muted, isTrue);
    });

    test('errors carry the UPnP code', () async {
      sonos.coordinator = false;
      await expectLater(
        sonos.client().stop(),
        throwsA(isA<SonosException>().having((e) => e.code, 'code', 800)),
      );
    });

    test('unreachable player', () async {
      await expectLater(
        SonosClient('127.0.0.1', port: 1).status(),
        throwsA(isA<SonosException>()),
      );
    });
  });

  test('a regrouped room sends commands to its new coordinator', () async {
    final kitchen = FakeSonos()..coordinator = false;
    final living = FakeSonos();
    await kitchen.start();
    await living.start();
    addTearDown(kitchen.close);
    addTearDown(living.close);
    String groups() =>
        household(livingRoom: living.location, kitchen: kitchen.location);
    kitchen.groupsXml = groups;
    living.groupsXml = groups;

    // The user picked Kitchen when it was on its own; since then it was
    // grouped with the Living Room, which now coordinates.
    final speaker = SonosSpeaker(
      SonosRoom(
        id: 'RINCON_B',
        name: 'Kitchen',
        host: kitchen.host,
        port: kitchen.port,
      ),
    );
    await speaker.play(nts);
    expect(kitchen.actions, ['SetAVTransportURI', 'GetZoneGroupState']);
    expect(living.actions, ['SetAVTransportURI', 'Play']);
    expect((await speaker.status()).playing, isTrue);
  });
}
