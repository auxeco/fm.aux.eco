import 'dart:async';
import 'dart:convert';

import 'package:aux_fm/audio/local_player.dart';
import 'package:aux_fm/cast/cast_discovery.dart';
import 'package:aux_fm/models/station.dart';

class FakePlayer implements LocalPlayer {
  final _playback = StreamController<LocalPlayback>.broadcast(sync: true);
  final _title = StreamController<String?>.broadcast(sync: true);
  final played = <String>[];
  int stops = 0;

  @override
  MediaSessionDelegate? delegate;

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

/// In-memory Arylic device answering the HTTP API.
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

class FakeCastDiscovery implements CastDiscovery {
  final _changes = StreamController<List<CastDevice>>.broadcast(sync: true);
  @override
  List<CastDevice> devices = [];
  bool running = false;

  @override
  Stream<List<CastDevice>> get changes => _changes.stream;

  @override
  Future<void> start() async => running = true;

  @override
  Future<void> stop() async => running = false;

  void announce(List<CastDevice> list) {
    devices = list;
    _changes.add(list);
  }
}
