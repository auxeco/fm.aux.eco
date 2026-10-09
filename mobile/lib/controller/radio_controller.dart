import 'dart:async';

import 'package:flutter/foundation.dart';

import '../arylic/arylic_client.dart';
import '../arylic/arylic_discovery.dart';
import '../audio/local_player.dart';
import '../cast/cast_client.dart';
import '../cast/cast_discovery.dart';
import '../data/stations.dart' as data;
import '../models/station.dart';
import '../speakers/remote_speaker.dart';
import '../voice/station_search.dart';
import 'settings.dart';

typedef AmpFactory = ArylicClient Function(String host);
typedef CastSpeakerFactory = RemoteSpeaker Function(CastDevice device);
typedef CarCheck = Future<bool> Function();
typedef AmpLocator = Future<List<DiscoveredAmp>> Function();

/// App state: current station, which speaker plays it (this phone, the
/// Arylic amp or a Google Cast speaker), and that speaker's status.
class RadioController extends ChangeNotifier implements MediaSessionDelegate {
  RadioController({
    required this._player,
    required Settings settings,
    AmpFactory? ampFactory,
    CastSpeakerFactory? castFactory,
    this._castDiscovery,
    CarCheck? isInCar,
    AmpLocator? locateAmps,
    List<Station> stations = data.stations,
    this.pollInterval = const Duration(seconds: 3),
  }) : _settings = settings,
       _ampFactory = ampFactory ?? ArylicClient.new,
       _castFactory = castFactory ?? CastSpeaker.new,
       _isInCar = isInCar ?? _never,
       _locateAmps = locateAmps ?? ArylicDiscovery().discover,
       stations = List.unmodifiable(stations),
       _current = stations.firstWhere(
         (s) => s.id == settings.stationId,
         orElse: () => stations.first,
       ),
       _darkTheme = settings.darkTheme {
    _player.delegate = this;
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

  static Future<bool> _never() async => false;

  final LocalPlayer _player;
  final Settings _settings;
  final AmpFactory _ampFactory;
  final CastSpeakerFactory _castFactory;
  final CastDiscovery? _castDiscovery;
  final CarCheck _isInCar;
  final AmpLocator _locateAmps;
  final Duration pollInterval;
  @override
  final List<Station> stations;
  final _subs = <StreamSubscription<Object?>>[];
  final _errors = StreamController<String>.broadcast();

  Station _current;
  bool _darkTheme;
  LocalPlayback _local = LocalPlayback.idle;
  String? _streamTitle;

  ArylicSpeaker? _amp;
  RemoteSpeaker? _target;
  SpeakerStatus? _remoteStatus;
  bool _remoteReachable = true;
  bool _remoteBusy = false;
  List<CastDevice> _castDevices = const [];
  StreamSubscription<List<CastDevice>>? _castSub;
  Timer? _poll;
  bool _foreground = true;
  DateTime? _lastLocate;

  /// User-facing error messages (show as a snackbar).
  Stream<String> get errors => _errors.stream;

  @override
  Station get current => _current;
  bool get darkTheme => _darkTheme;

  /// The speaker playing the radio; null means this phone.
  RemoteSpeaker? get target => _target;
  bool get isRemote => _target != null;
  String get targetName => _target?.name ?? 'Phone';
  SpeakerStatus? get remoteStatus => _remoteStatus;
  bool get remoteReachable => _remoteReachable;

  bool get hasAmp => _amp != null;
  String? get ampHost => _amp?.client.host;
  String? get ampName => _amp?.name;
  bool get ampSelected => _target != null && identical(_target, _amp);

  /// Google Cast speakers currently visible on the network.
  List<CastDevice> get castDevices => _castDevices;
  bool isCastSelected(CastDevice d) => _target?.id == 'cast:${d.id}';

  bool get isPlaying => isRemote
      ? (_remoteStatus?.playing ?? false)
      : _local == LocalPlayback.playing || _local == LocalPlayback.loading;

  bool get isLoading => isRemote
      ? _remoteBusy || (_remoteStatus?.loading ?? false)
      : _local == LocalPlayback.loading;

  /// Track / show currently on air, when the stream reports it.
  String? get nowPlaying {
    if (!isRemote) return _streamTitle;
    final title = _remoteStatus?.title;
    // Cast speakers echo back the station name we sent; that's not news.
    if (title == null || title.toLowerCase() == _current.name.toLowerCase()) {
      return null;
    }
    return title;
  }

  /// Restores the remembered amp and speaker, starts Cast discovery.
  Future<void> init() async {
    final host = _settings.ampHost;
    if (host != null) {
      _amp = ArylicSpeaker(_ampFactory(host), _settings.ampName ?? 'Amp');
    }
    switch (_settings.output) {
      case OutputKind.amp when _amp != null:
        _target = _amp;
      case OutputKind.cast:
        final device = _settings.castDevice;
        if (device != null) _target = _castFactory(device);
      default:
        break;
    }
    notifyListeners();
    _startPolling();
    await refreshRemote();
    await _startCastDiscovery();
    // In the background: can take a few seconds if the amp moved.
    if (_amp != null && !ampSelected) unawaited(_checkAmp());
  }

  Future<void> selectStation(Station station) async {
    _current = station;
    _settings.stationId = station.id;
    notifyListeners();
    await play();
  }

  Future<void> togglePlay() => isPlaying ? stop() : play();

  Future<void> play() async {
    if (_target != null) {
      await _remoteCommand((s) => s.play(_current));
    } else {
      await _player.play(_current);
    }
  }

  Future<void> stop() async {
    if (_target != null) {
      await _remoteCommand((s) => s.stop());
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

  // ---- Speakers ----

  Future<void> selectPhone() => _switchTo(null);

  Future<void> selectAmp() async {
    final amp = _amp;
    if (amp != null) await _switchTo(amp);
  }

  Future<void> selectCast(CastDevice device) async {
    if (isCastSelected(device)) return;
    await _switchTo(_castFactory(device));
  }

  /// Moves playback to [next]; whatever was playing continues there.
  Future<void> _switchTo(RemoteSpeaker? next) async {
    if (next?.id == _target?.id) return;
    final wasPlaying = isPlaying;
    if (wasPlaying) await stop();
    _setTarget(next);
    notifyListeners();
    await refreshRemote();
    if (wasPlaying) await play();
  }

  void _setTarget(RemoteSpeaker? next) {
    final old = _target;
    if (old != null && !identical(old, next) && !identical(old, _amp)) {
      old.dispose();
    }
    _target = next;
    _remoteStatus = null;
    _remoteReachable = true;
    _settings.output = switch (next?.kind) {
      null => OutputKind.phone,
      SpeakerKind.arylic => OutputKind.amp,
      SpeakerKind.cast => OutputKind.cast,
    };
    if (next is CastSpeaker) _settings.castDevice = next.device;
    _startPolling();
  }

  /// Connects to the Arylic amp at [host] (IP address or hostname). Throws
  /// if the device does not answer the Arylic API.
  Future<void> connectAmp(String host, {bool select = true}) async {
    final client = _ampFactory(host.trim());
    final info = await client.getDeviceInfo();
    final amp = ArylicSpeaker(client, info.name);
    final wasSelected = ampSelected;
    _amp = amp;
    _settings
      ..ampHost = client.host
      ..ampName = info.name
      ..ampUuid = info.uuid;
    if (wasSelected) _setTarget(amp);
    notifyListeners();
    if (select) {
      await _switchTo(amp);
    } else {
      await refreshRemote();
    }
  }

  Future<void> forgetAmp() async {
    if (ampSelected) _setTarget(null);
    _amp = null;
    _settings
      ..ampHost = null
      ..ampName = null
      ..ampUuid = null;
    notifyListeners();
  }

  Future<void> setRemoteVolume(int volume) async {
    final status = _remoteStatus;
    if (status != null) {
      _remoteStatus = status.copyWith(volume: volume);
      notifyListeners();
    }
    await _remoteCommand((s) => s.setVolume(volume));
  }

  Future<void> setRemoteMuted(bool muted) =>
      _remoteCommand((s) => s.setMuted(muted));

  Future<void> refreshRemote() async {
    final target = _target;
    if (target == null) return;
    try {
      final status = await target.status();
      if (!identical(target, _target)) return;
      _remoteStatus = status;
      _remoteReachable = true;
    } on Exception {
      if (!identical(target, _target)) return;
      _remoteReachable = false;
      if (identical(target, _amp)) unawaited(_relocateAmp());
    }
    notifyListeners();
  }

  /// Makes sure the remembered amp still answers at its saved address.
  Future<void> _checkAmp() async {
    final amp = _amp;
    if (amp == null) return;
    try {
      await amp.client.getDeviceInfo();
    } on Exception {
      await _relocateAmp();
    }
  }

  /// The remembered amp stopped answering, most likely because the router
  /// gave it a new IP address. Searches the network for the same device (by
  /// uuid, or by name for amps saved before uuids were stored) and moves
  /// over to its new address. At most once a minute.
  Future<void> _relocateAmp() async {
    final amp = _amp;
    if (amp == null) return;
    final now = DateTime.now();
    final last = _lastLocate;
    if (last != null && now.difference(last) < const Duration(minutes: 1)) {
      return;
    }
    _lastLocate = now;
    final List<DiscoveredAmp> found;
    try {
      found = await _locateAmps();
    } on Object {
      return;
    }
    final uuid = _settings.ampUuid;
    final match = found
        .where((d) => uuid != null ? d.uuid == uuid : d.name == amp.name)
        .firstOrNull;
    if (match == null || match.host == amp.client.host) return;
    if (!identical(amp, _amp)) return; // replaced meanwhile
    final moved = ArylicSpeaker(_ampFactory(match.host), amp.name);
    final wasSelected = ampSelected;
    _amp = moved;
    _settings
      ..ampHost = match.host
      ..ampUuid = match.uuid ?? uuid;
    _lastLocate = null;
    if (wasSelected) {
      _setTarget(moved);
      notifyListeners();
      await refreshRemote();
    } else {
      notifyListeners();
    }
  }

  Future<void> _remoteCommand(
    Future<void> Function(RemoteSpeaker speaker) action,
  ) async {
    final target = _target;
    if (target == null) return;
    _remoteBusy = true;
    notifyListeners();
    try {
      await action(target);
      _remoteReachable = true;
    } on Exception catch (e) {
      _remoteReachable = false;
      _errors.add('${target.name} did not respond: ${_describe(e)}');
    } finally {
      _remoteBusy = false;
    }
    await refreshRemote();
  }

  static String _describe(Exception e) => switch (e) {
    ArylicException(:final message) => message,
    CastException(:final message) => message,
    _ => e.toString(),
  };

  // ---- Cast discovery ----

  Future<void> _startCastDiscovery() async {
    final discovery = _castDiscovery;
    if (discovery == null) return;
    _castSub ??= discovery.changes.listen(_onCastDevices);
    try {
      await discovery.start();
    } on Object {
      return; // Not supported here (or no network); Cast is optional.
    }
    _onCastDevices(discovery.devices);
  }

  void _onCastDevices(List<CastDevice> devices) {
    _castDevices = devices;
    // Follow the selected speaker if its address changed (DHCP).
    final target = _target;
    if (target is CastSpeaker) {
      for (final d in devices) {
        if (d.id == target.device.id &&
            (d.host != target.device.host || d.port != target.device.port)) {
          _setTarget(_castFactory(d));
          break;
        }
      }
    }
    notifyListeners();
  }

  // ---- Media session (voice, Android Auto, notification) ----

  @override
  Future<void> skipToNext() => next();

  @override
  Future<void> skipToPrevious() => previous();

  @override
  Future<void> resumeFromSession() async {
    await _phoneIfInCar();
    await play();
  }

  @override
  Future<void> playStationFromSession(Station station) async {
    await _phoneIfInCar();
    await selectStation(station);
  }

  @override
  Future<void> playFromSearch(String query) async {
    await _phoneIfInCar();
    await selectStation(findStation(query, stations) ?? _current);
  }

  /// In the car, sound must come from the phone, never a speaker at home.
  /// Leaves the home speaker alone; someone may be listening there.
  Future<void> _phoneIfInCar() async {
    if (_target != null && await _isInCar()) {
      _setTarget(null);
      notifyListeners();
    }
  }

  // ---- Misc ----

  void toggleTheme(bool dark) {
    _darkTheme = dark;
    _settings.darkTheme = dark;
    notifyListeners();
  }

  /// Polling and network discovery only run while the app is visible.
  void setForeground(bool foreground) {
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (foreground) {
      _startPolling();
      unawaited(refreshRemote());
      unawaited(_startCastDiscovery());
    } else {
      _poll?.cancel();
      unawaited(_castDiscovery?.stop());
    }
  }

  void _startPolling() {
    _poll?.cancel();
    if (_target == null || !_foreground) return;
    _poll = Timer.periodic(pollInterval, (_) => refreshRemote());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _castSub?.cancel();
    unawaited(_castDiscovery?.stop());
    if (!identical(_target, _amp)) _target?.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    _errors.close();
    super.dispose();
  }
}
