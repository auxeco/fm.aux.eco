import 'package:shared_preferences/shared_preferences.dart';

import '../cast/cast_discovery.dart';

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

  bool get darkTheme => _prefs.getBool('darkTheme') ?? true;
  set darkTheme(bool v) => _prefs.setBool('darkTheme', v);

  void _set(String key, String? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, value);
}
