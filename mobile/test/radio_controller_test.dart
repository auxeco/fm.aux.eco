import 'dart:async';
import 'dart:convert';

import 'package:aux_fm/arylic/arylic_client.dart';
import 'package:aux_fm/audio/local_player.dart';
import 'package:aux_fm/controller/radio_controller.dart';
import 'package:aux_fm/controller/settings.dart';
import 'package:aux_fm/data/stations.dart';
import 'package:aux_fm/models/station.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePlayer implements LocalPlayer {
  final _playback = StreamController<LocalPlayback>.broadcast(sync: true);
  final _title = StreamController<String?>.broadcast(sync: true);
  final played = <String>[];
  int stops = 0;

  @override
  void Function()? onSkipToNext;
  @override
  void Function()? onSkipToPrevious;

  @override
  Stream<LocalPlayback> get playback => _playback.stream;
  @override
  Stream<String?> get streamTitle => _title.stream;

  @override
  Future<void> play(Station station) async {
    played.add(station.id);
    _playback.add(LocalPlayback.playing);
  }

  @override
  Future<void> stop() async {
    stops++;
    _playback.add(LocalPlayback.idle);
  }

  void emitTitle(String? t) => _title.add(t);
}

/// In-memory Arylic device.
class FakeAmp {
  final commands = <String>[];
  String status = 'stop';
  int vol = 30;
  bool online = true;

  Future<String> get(Uri uri) async {
    if (!online) throw TimeoutException('offline');
    final cmd = Uri.decodeQueryComponent(uri.query.substring(8));
    commands.add(cmd);
    if (cmd == 'getStatusEx') {
      return jsonEncode({'DeviceName': 'Up2Stream Amp'});
    }
    if (cmd == 'getPlayerStatus') {
      return jsonEncode({'status': status, 'vol': '$vol', 'mute': '0'});
    }
    if (cmd.startsWith('setPlayerCmd:play:')) status = 'play';
    if (cmd == 'setPlayerCmd:stop') status = 'stop';
    if (cmd.startsWith('setPlayerCmd:vol:')) vol = int.parse(cmd.split(':')[2]);
    return 'OK';
  }

  List<String> get actions =>
      commands.where((c) => c.startsWith('setPlayerCmd')).toList();
}

void main() {
  late FakePlayer player;
  late FakeAmp amp;

  Future<RadioController> make([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return RadioController(
      player: player,
      settings: await Settings.load(),
      ampFactory: (host) => ArylicClient(host, httpGet: amp.get),
      pollInterval: const Duration(hours: 1),
    );
  }

  setUp(() {
    player = FakePlayer();
    amp = FakeAmp();
  });

  test('plays stations on the phone by default', () async {
    final c = await make();
    await c.selectStation(stations[2]);
    expect(player.played, [stations[2].id]);
    expect(c.isPlaying, isTrue);
    expect(c.playsOnAmp, isFalse);
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

  test('connecting an amp hands playback over to it', () async {
    final c = await make();
    await c.selectStation(stations.first); // playing on phone
    await c.connectAmp(' 192.168.1.20 ');

    expect(c.ampName, 'Up2Stream Amp');
    expect(c.ampHost, '192.168.1.20');
    expect(c.playsOnAmp, isTrue);
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

  test('switching back to phone moves playback', () async {
    final c = await make();
    await c.connectAmp('amp');
    await c.play();
    await c.setOutput(Output.phone);
    expect(amp.actions.last, 'setPlayerCmd:stop');
    expect(player.played, [c.current.id]);
  });

  test('remembers the amp across launches', () async {
    final c = await make();
    await c.connectAmp('amp');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ampHost'), 'amp');
    expect(prefs.getBool('outputToAmp'), isTrue);

    final again = RadioController(
      player: player,
      settings: Settings(prefs),
      ampFactory: (host) => ArylicClient(host, httpGet: amp.get),
      pollInterval: const Duration(hours: 1),
    );
    await again.init();
    expect(again.playsOnAmp, isTrue);
    expect(again.ampName, 'Up2Stream Amp');
    expect(again.ampReachable, isTrue);
  });

  test('volume is sent to the amp', () async {
    final c = await make();
    await c.connectAmp('amp');
    await c.setAmpVolume(55);
    expect(amp.vol, 55);
    expect(c.ampStatus!.volume, 55);
  });

  test('unreachable amp reports an error instead of throwing', () async {
    final c = await make();
    await c.connectAmp('amp');
    amp.online = false;
    final errors = <String>[];
    c.errors.listen(errors.add);
    await c.play();
    await pumpEventQueue();
    expect(c.ampReachable, isFalse);
    expect(errors, hasLength(1));
  });

  test('a failed connect leaves state untouched', () async {
    final c = await make();
    amp.online = false;
    await expectLater(c.connectAmp('nope'), throwsA(isA<Exception>()));
    expect(c.hasAmp, isFalse);
    expect(c.output, Output.phone);
  });

  test('forgetting the amp returns to the phone', () async {
    final c = await make();
    await c.connectAmp('amp');
    await c.forgetAmp();
    expect(c.hasAmp, isFalse);
    expect(c.playsOnAmp, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ampHost'), isNull);
  });
}
