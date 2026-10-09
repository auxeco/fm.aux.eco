import 'package:aux_fm/arylic/arylic_client.dart';
import 'package:aux_fm/arylic/arylic_discovery.dart';
import 'package:aux_fm/cast/cast_discovery.dart';
import 'package:aux_fm/controller/radio_controller.dart';
import 'package:aux_fm/controller/settings.dart';
import 'package:aux_fm/data/stations.dart';
import 'package:aux_fm/speakers/remote_speaker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_cast_device.dart';
import 'fakes/fakes.dart';

void main() {
  late FakePlayer player;
  late FakeAmp amp;
  late FakeCastDevice nest;
  late FakeCastDiscovery discovery;
  late bool inCar;
  late List<DiscoveredAmp> network; // what an amp search finds
  late int locateCalls;
  final createdCast = <CastDevice>[];

  const kitchen = CastDevice(
    id: 'nest-1',
    name: 'Kitchen speaker',
    host: '192.168.1.40',
    model: 'Google Nest Mini',
  );

  RadioController build(Settings settings) => RadioController(
    player: player,
    settings: settings,
    ampFactory: (host) => ArylicClient(host, httpGet: amp.get),
    castFactory: (device) {
      createdCast.add(device);
      return CastSpeaker(
        device,
        client: nest.client(),
        contentType: (_) async => 'audio/mpeg',
      );
    },
    castDiscovery: discovery,
    isInCar: () async => inCar,
    locateAmps: () async {
      locateCalls++;
      return network;
    },
    pollInterval: const Duration(hours: 1),
  );

  Future<RadioController> make([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    final c = build(await Settings.load());
    await c.init();
    return c;
  }

  setUp(() async {
    player = FakePlayer();
    amp = FakeAmp();
    nest = FakeCastDevice();
    await nest.start();
    discovery = FakeCastDiscovery();
    inCar = false;
    network = [];
    locateCalls = 0;
    createdCast.clear();
  });

  tearDown(() => nest.close());

  group('phone', () {
    test('plays stations on the phone by default', () async {
      final c = await make();
      await c.selectStation(stations[2]);
      expect(player.played, [stations[2].id]);
      expect(c.isPlaying, isTrue);
      expect(c.isRemote, isFalse);
      expect(c.targetName, 'Phone');
      player.emitTitle('Some DJ – Some Show');
      expect(c.nowPlaying, 'Some DJ – Some Show');
    });

    test('restores last station and wraps next / previous', () async {
      final c = await make({'stationId': stations.last.id});
      expect(c.current.id, stations.last.id);
      await c.next();
      expect(c.current.id, stations.first.id);
      await c.previous();
      expect(c.current.id, stations.last.id);
    });
  });

  group('Arylic amp', () {
    test('connecting hands playback over to the amp', () async {
      final c = await make();
      await c.selectStation(stations.first); // playing on phone
      await c.connectAmp(' 192.168.1.20 ');

      expect(c.ampName, 'Up2Stream Amp');
      expect(c.ampHost, '192.168.1.20');
      expect(c.ampSelected, isTrue);
      expect(player.stops, 1);
      expect(amp.actions, ['setPlayerCmd:play:${stations.first.url}']);
      expect(c.isPlaying, isTrue);
    });

    test('station changes and stop go to the amp', () async {
      final c = await make();
      await c.connectAmp('amp');
      await c.selectStation(stations[3]);
      await c.togglePlay();
      expect(amp.actions, [
        'setPlayerCmd:play:${stations[3].url}',
        'setPlayerCmd:stop',
      ]);
      expect(c.isPlaying, isFalse);
      expect(player.played, isEmpty);
    });

    test('switching back to the phone moves playback', () async {
      final c = await make();
      await c.connectAmp('amp');
      await c.play();
      await c.selectPhone();
      expect(amp.actions.last, 'setPlayerCmd:stop');
      expect(player.played, [c.current.id]);
    });

    test('is remembered across launches', () async {
      final c = await make();
      await c.connectAmp('amp');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ampHost'), 'amp');
      expect(prefs.getString('output'), 'amp');

      final again = build(Settings(prefs));
      await again.init();
      expect(again.ampSelected, isTrue);
      expect(again.ampName, 'Up2Stream Amp');
      expect(again.remoteReachable, isTrue);
    });

    test('finds the remembered amp again after an IP change', () async {
      final c = await make();
      amp.address = '192.168.1.20';
      await c.connectAmp('192.168.1.20');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ampUuid'), 'FF31F09E-0001');

      // Overnight the router hands the amp a new address.
      amp.address = '192.168.1.57';
      network = [
        const DiscoveredAmp(
          host: '192.168.1.57',
          name: 'Up2Stream Amp',
          uuid: 'FF31F09E-0001',
        ),
      ];
      final again = build(Settings(prefs));
      await again.init();
      await pumpEventQueue();

      expect(locateCalls, 1);
      expect(again.ampHost, '192.168.1.57');
      expect(again.ampSelected, isTrue);
      expect(again.remoteReachable, isTrue);
      expect(prefs.getString('ampHost'), '192.168.1.57');
      await again.play();
      expect(amp.actions.last, startsWith('setPlayerCmd:play:'));
    });

    test('also when the amp is remembered but not selected', () async {
      final c = await make();
      amp.address = '192.168.1.20';
      await c.connectAmp('192.168.1.20');
      await c.selectPhone();
      amp.address = '192.168.1.57';
      network = [
        const DiscoveredAmp(
          host: '192.168.1.57',
          name: 'Up2Stream Amp',
          uuid: 'FF31F09E-0001',
        ),
      ];
      final again = build(Settings(await SharedPreferences.getInstance()));
      await again.init();
      await pumpEventQueue();
      expect(again.ampHost, '192.168.1.57');
      expect(again.isRemote, isFalse);
    });

    test('does not switch to a different amp with the same name', () async {
      final c = await make();
      amp.address = '192.168.1.20';
      await c.connectAmp('192.168.1.20');
      amp.address = '192.168.1.57';
      network = [
        const DiscoveredAmp(
          host: '192.168.1.99',
          name: 'Up2Stream Amp',
          uuid: 'SOMEONE-ELSES',
        ),
      ];
      final again = build(Settings(await SharedPreferences.getInstance()));
      await again.init();
      await pumpEventQueue();
      expect(again.ampHost, '192.168.1.20');
      expect(again.remoteReachable, isFalse);
    });

    test('an amp saved without uuid is found again by name', () async {
      amp.address = '192.168.1.57';
      network = [
        const DiscoveredAmp(
          host: '192.168.1.57',
          name: 'Up2Stream Amp',
          uuid: 'FF31F09E-0001',
        ),
      ];
      final c = await make({
        'ampHost': '192.168.1.20',
        'ampName': 'Up2Stream Amp',
        'output': 'amp',
      });
      await pumpEventQueue();
      expect(c.ampHost, '192.168.1.57');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ampUuid'), 'FF31F09E-0001');
    });

    test('volume is sent to the amp', () async {
      final c = await make();
      await c.connectAmp('amp');
      await c.setRemoteVolume(55);
      expect(amp.vol, 55);
      expect(c.remoteStatus!.volume, 55);
    });

    test('unreachable amp reports an error instead of throwing', () async {
      final c = await make();
      await c.connectAmp('amp');
      amp.online = false;
      final errors = <String>[];
      c.errors.listen(errors.add);
      await c.play();
      await pumpEventQueue();
      expect(c.remoteReachable, isFalse);
      expect(errors, hasLength(1));
    });

    test('a failed connect leaves state untouched', () async {
      final c = await make();
      amp.online = false;
      await expectLater(c.connectAmp('nope'), throwsA(isA<Exception>()));
      expect(c.hasAmp, isFalse);
      expect(c.isRemote, isFalse);
    });

    test('forgetting the amp returns to the phone', () async {
      final c = await make();
      await c.connectAmp('amp');
      await c.forgetAmp();
      expect(c.hasAmp, isFalse);
      expect(c.isRemote, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ampHost'), isNull);
    });
  });

  group('Google Cast', () {
    test('lists speakers found on the network', () async {
      final c = await make();
      expect(discovery.running, isTrue);
      discovery.announce([kitchen]);
      expect(c.castDevices.single.name, 'Kitchen speaker');
    });

    test('selecting a speaker moves playback to it', () async {
      final c = await make();
      await c.selectStation(stations[1]); // on phone
      await c.selectCast(kitchen);

      expect(player.stops, 1);
      expect(c.targetName, 'Kitchen speaker');
      expect(c.isCastSelected(kitchen), isTrue);
      final media = nest.media!['media'] as Map;
      expect(media['contentId'], stations[1].url);
      expect(c.isPlaying, isTrue);
      // The speaker echoes our title back; don't show it as "now playing".
      expect(c.nowPlaying, isNull);
    });

    test('stop and volume go to the speaker', () async {
      final c = await make();
      await c.selectCast(kitchen);
      await c.play();
      await c.setRemoteVolume(70);
      expect(nest.volume, 0.7);
      await c.stop();
      expect(nest.app, isNull);
      expect(c.isPlaying, isFalse);
    });

    test('is remembered across launches', () async {
      final c = await make();
      await c.selectCast(kitchen);
      final prefs = await SharedPreferences.getInstance();
      final again = build(Settings(prefs));
      await again.init();
      expect(again.targetName, 'Kitchen speaker');
      expect(createdCast.last.host, '192.168.1.40');
    });

    test('follows the speaker to a new IP address', () async {
      final c = await make();
      await c.selectCast(kitchen);
      discovery.announce([
        const CastDevice(
          id: 'nest-1',
          name: 'Kitchen speaker',
          host: '192.168.1.99',
        ),
      ]);
      expect(createdCast.last.host, '192.168.1.99');
      expect(c.isCastSelected(kitchen), isTrue);
    });

    test('switching from the amp to a speaker hands over', () async {
      final c = await make();
      await c.connectAmp('amp');
      await c.play();
      await c.selectCast(kitchen);
      expect(amp.actions.last, 'setPlayerCmd:stop');
      expect(nest.media, isNotNull);
      expect(c.hasAmp, isTrue); // still known, just not selected
    });
  });

  group('station list', () {
    test('a station the user adds is in the list after a restart', () async {
      final c = await make();
      final mine = c.addStation(name: 'Radio Mine', url: 'https://mine/s');
      expect(c.stations.last.id, mine.id);
      await c.selectStation(mine);
      expect(player.played.last, mine.id);

      final again = build(Settings(await SharedPreferences.getInstance()));
      expect(again.stations.last.name, 'Radio Mine');
      expect(again.current.id, mine.id);
    });

    test('next / previous only go through the user\'s list', () async {
      final c = await make();
      for (final s in stations.skip(2)) {
        c.setStationEnabled(s, false);
      }
      expect(c.stations.map((s) => s.id), [stations[0].id, stations[1].id]);
      await c.next();
      await c.next();
      expect(c.current.id, stations[0].id);
    });

    test('deleting the playing station stops it', () async {
      final c = await make();
      final mine = c.addStation(name: 'Radio Mine', url: 'https://mine/s');
      await c.selectStation(mine);
      expect(await c.removeStation(mine), isTrue);
      expect(player.stops, 1);
      expect(c.current.id, stations.first.id);
      expect(c.stations.any((s) => s.id == mine.id), isFalse);
    });
  });

  group('voice and Android Auto', () {
    test('"play KEXP on AUX FM" plays on the selected speaker', () async {
      final c = await make();
      await c.connectAmp('amp');
      await c.playFromSearch('KEXP on AUX FM');
      expect(c.current.id, 'kexp');
      expect(amp.actions.last, 'setPlayerCmd:play:${c.current.url}');
    });

    test('an empty or unknown request plays the current station', () async {
      final c = await make({'stationId': 'dublab'});
      await c.playFromSearch('');
      expect(player.played, ['dublab']);
      await c.playFromSearch('something we do not have');
      expect(player.played, ['dublab', 'dublab']);
    });

    test('in the car, playback stays on the phone', () async {
      final c = await make();
      await c.connectAmp('amp');
      amp.status = 'play'; // someone is listening at home
      inCar = true;
      await c.playStationFromSession(stations[4]);
      expect(c.isRemote, isFalse);
      expect(player.played, [stations[4].id]);
      // The amp at home was left alone.
      expect(amp.actions.where((a) => a.contains('play:')), isEmpty);
      expect(amp.actions, isNot(contains('setPlayerCmd:stop')));
    });

    test('resume from a headset or lock screen follows the speaker', () async {
      final c = await make();
      await c.selectCast(kitchen);
      await c.resumeFromSession();
      expect(nest.media, isNotNull);
      expect(player.played, isEmpty);
    });

    test('next / previous from the media session', () async {
      final c = await make();
      await c.skipToNext();
      expect(c.current.id, stations[1].id);
      await c.skipToPrevious();
      expect(c.current.id, stations[0].id);
    });
  });
}
