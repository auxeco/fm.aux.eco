import 'package:shared_preferences/shared_preferences.dart';

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

  bool get outputToAmp => _prefs.getBool('outputToAmp') ?? false;
  set outputToAmp(bool v) => _prefs.setBool('outputToAmp', v);

  bool get darkTheme => _prefs.getBool('darkTheme') ?? true;
  set darkTheme(bool v) => _prefs.setBool('darkTheme', v);

  void _set(String key, String? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, value);
}
