import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../cast/cast_discovery.dart';
import '../models/station.dart';

/// Where playback goes.
enum OutputKind { phone, amp, cast }

/// Persisted user choices.
class Settings {
  Settings(this._prefs);

  static Future<Settings> load() async =>
      Settings(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  String? get stationId => _prefs.getString('stationId');
  set stationId(String? v) => _set('stationId', v);

  String? get ampHost => _prefs.getString('ampHost');
  set ampHost(String? v) => _set('ampHost', v);

  String? get ampName => _prefs.getString('ampName');
  set ampName(String? v) => _set('ampName', v);

  /// Identifies the amp if its IP address changes.
  String? get ampUuid => _prefs.getString('ampUuid');
  set ampUuid(String? v) => _set('ampUuid', v);

  OutputKind get output => OutputKind.values.firstWhere(
    (k) => k.name == _prefs.getString('output'),
    orElse: () => OutputKind.phone,
  );
  set output(OutputKind v) => _prefs.setString('output', v.name);

  /// The last Cast speaker played on, so it can be used again before
  /// discovery finds it.
  CastDevice? get castDevice {
    final id = _prefs.getString('castId');
    final host = _prefs.getString('castHost');
    if (id == null || host == null) return null;
    return CastDevice(
      id: id,
      name: _prefs.getString('castName') ?? 'Speaker',
      host: host,
      port: _prefs.getInt('castPort') ?? 8009,
    );
  }

  set castDevice(CastDevice? d) {
    _set('castId', d?.id);
    _set('castName', d?.name);
    _set('castHost', d?.host);
    d == null ? _prefs.remove('castPort') : _prefs.setInt('castPort', d.port);
  }

  /// Built-in or custom stations the user removed from their list.
  Set<String> get hiddenStations =>
      (_prefs.getStringList('hiddenStations') ?? const []).toSet();
  set hiddenStations(Set<String> v) =>
      _prefs.setStringList('hiddenStations', v.toList());

  /// Stations from the extra catalog the user added to their list.
  Set<String> get addedStations =>
      (_prefs.getStringList('addedStations') ?? const []).toSet();
  set addedStations(Set<String> v) =>
      _prefs.setStringList('addedStations', v.toList());

  /// Stations the user entered themselves.
  List<Station> get customStations {
    final raw = _prefs.getString('customStations');
    if (raw == null) return const [];
    try {
      return [
        for (final s in jsonDecode(raw) as List)
          Station.fromJson(s as Map<String, dynamic>),
      ];
    } on Object {
      return const [];
    }
  }

  set customStations(List<Station> v) =>
      _prefs.setString('customStations', jsonEncode(v));

  bool get darkTheme => _prefs.getBool('darkTheme') ?? true;
  set darkTheme(bool v) => _prefs.setBool('darkTheme', v);

  void _set(String key, String? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, value);
}
