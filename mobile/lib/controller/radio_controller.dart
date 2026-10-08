import 'dart:async';

import 'package:flutter/foundation.dart';

import '../arylic/arylic_client.dart';
import '../audio/local_player.dart';
import '../data/stations.dart' as data;
import '../models/station.dart';
import 'settings.dart';

enum Output { phone, amp }

typedef AmpFactory = ArylicClient Function(String host);

/// App state: current station, where it plays (phone or Arylic amp), and
/// the connected amp's status.
class RadioController extends ChangeNotifier {
  RadioController({
    required this._player,
    required Settings settings,
    AmpFactory? ampFactory,
    List<Station> stations = data.stations,
    this.pollInterval = const Duration(seconds: 3),
  }) : _settings = settings,
       _ampFactory = ampFactory ?? ArylicClient.new,
       stations = List.unmodifiable(stations),
       _current = stations.firstWhere(
         (s) => s.id == settings.stationId,
         orElse: () => stations.first,
       ),
       _output = settings.outputToAmp ? Output.amp : Output.phone,
       _darkTheme = settings.darkTheme {
    _player.onSkipToNext = next;
    _player.onSkipToPrevious = previous;
    _subs.add(
      _player.playback.listen((p) {
        _local = p;
        notifyListeners();
      }),
    );
    _subs.add(
      _player.streamTitle.listen((t) {
        _streamTitle = t;
        notifyListeners();
      }),
    );
  }

  final LocalPlayer _player;
  final Settings _settings;
  final AmpFactory _ampFactory;
  final Duration pollInterval;
  final List<Station> stations;
  final _subs = <StreamSubscription<Object?>>[];
  final _errors = StreamController<String>.broadcast();

  Station _current;
  Output _output;
  bool _darkTheme;
  LocalPlayback _local = LocalPlayback.idle;
  String? _streamTitle;

  ArylicClient? _amp;
  String? _ampName;
  ArylicPlayerStatus? _ampStatus;
  bool _ampReachable = false;
  bool _ampBusy = false;
  Timer? _poll;
  bool _foreground = true;

  /// User-facing error messages (show as a snackbar).
  Stream<String> get errors => _errors.stream;

  Station get current => _current;
  Output get output => _output;
  bool get darkTheme => _darkTheme;

  bool get hasAmp => _amp != null;
  String? get ampHost => _amp?.host;
  String? get ampName => _ampName;
  ArylicPlayerStatus? get ampStatus => _ampStatus;
  bool get ampReachable => _ampReachable;

  /// True when playback is routed to the amp.
  bool get playsOnAmp => _output == Output.amp && _amp != null;

  bool get isPlaying => playsOnAmp
      ? (_ampStatus?.isPlaying ?? false)
      : _local == LocalPlayback.playing || _local == LocalPlayback.loading;

  bool get isLoading => playsOnAmp
      ? _ampBusy || _ampStatus?.playback == AmpPlayback.loading
      : _local == LocalPlayback.loading;

  /// Track / show currently on air, when the stream reports it.
  String? get nowPlaying => playsOnAmp ? _ampStatus?.title : _streamTitle;

  /// Reconnects to the remembered amp, if any.
  Future<void> init() async {
    final host = _settings.ampHost;
    if (host == null) return;
    _amp = _ampFactory(host);
    _ampName = _settings.ampName;
    _startPolling();
    await refreshAmp();
  }

  Future<void> selectStation(Station station) async {
    _current = station;
    _settings.stationId = station.id;
    notifyListeners();
    await play();
  }

  Future<void> togglePlay() => isPlaying ? stop() : play();

  Future<void> play() async {
    if (playsOnAmp) {
      await _ampCommand((amp) => amp.playUrl(_current.url));
    } else {
      await _player.play(_current);
    }
  }

  Future<void> stop() async {
    if (playsOnAmp) {
      await _ampCommand((amp) => amp.stop());
    } else {
      await _player.stop();
    }
  }

  Future<void> next() => _step(1);
  Future<void> previous() => _step(-1);

  Future<void> _step(int delta) {
    final i = stations.indexWhere((s) => s.id == _current.id);
    final n = stations.length;
    return selectStation(stations[(i + delta + n) % n]);
  }

  /// Switches output; whatever was playing moves to the new output.
  Future<void> setOutput(Output output) async {
    if (output == _output) return;
    if (output == Output.amp && _amp == null) return;
    final wasPlaying = isPlaying;
    if (wasPlaying) await stop();
    _output = output;
    _settings.outputToAmp = output == Output.amp;
    notifyListeners();
    if (wasPlaying) await play();
  }

  void toggleTheme(bool dark) {
    _darkTheme = dark;
    _settings.darkTheme = dark;
    notifyListeners();
  }

  /// Connects to the amp at [host] (IP address or hostname). Throws if the
  /// device does not answer the Arylic API.
  Future<void> connectAmp(String host, {bool switchOutput = true}) async {
    final client = _ampFactory(host.trim());
    final info = await client.getDeviceInfo();
    _amp = client;
    _ampName = info.name;
    _ampReachable = true;
    _settings
      ..ampHost = client.host
      ..ampName = info.name;
    notifyListeners();
    _startPolling();
    await refreshAmp();
    if (switchOutput) await setOutput(Output.amp);
  }

  Future<void> forgetAmp() async {
    if (_output == Output.amp) {
      _output = Output.phone;
      _settings.outputToAmp = false;
    }
    _poll?.cancel();
    _amp = null;
    _ampName = null;
    _ampStatus = null;
    _ampReachable = false;
    _settings
      ..ampHost = null
      ..ampName = null;
    notifyListeners();
  }

  Future<void> setAmpVolume(int volume) async {
    final status = _ampStatus;
    if (status != null) {
      _ampStatus = ArylicPlayerStatus(
        playback: status.playback,
        volume: volume,
        muted: status.muted,
        title: status.title,
        artist: status.artist,
        mode: status.mode,
      );
      notifyListeners();
    }
    await _ampCommand((amp) => amp.setVolume(volume));
  }

  Future<void> setAmpMuted(bool muted) =>
      _ampCommand((amp) => amp.setMuted(muted));

  Future<void> refreshAmp() async {
    final amp = _amp;
    if (amp == null) return;
    try {
      final status = await amp.getPlayerStatus();
      if (!identical(amp, _amp)) return;
      _ampStatus = status;
      _ampReachable = true;
    } on Exception {
      if (!identical(amp, _amp)) return;
      _ampReachable = false;
    }
    notifyListeners();
  }

  /// Polling only runs while the app is visible.
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) {
      _startPolling();
      unawaited(refreshAmp());
    } else {
      _poll?.cancel();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    if (_amp == null || !_foreground) return;
    _poll = Timer.periodic(pollInterval, (_) => refreshAmp());
  }

  Future<void> _ampCommand(
    Future<void> Function(ArylicClient amp) action,
  ) async {
    final amp = _amp;
    if (amp == null) return;
    _ampBusy = true;
    notifyListeners();
    try {
      await action(amp);
      _ampReachable = true;
    } on Exception catch (e) {
      _ampReachable = false;
      _errors.add('${_ampName ?? 'Amp'} did not respond: $e');
    } finally {
      _ampBusy = false;
    }
    await refreshAmp();
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _errors.close();
    super.dispose();
  }
}
