import 'package:aux_fm/controller/settings.dart';
import 'package:aux_fm/controller/station_library.dart';
import 'package:aux_fm/models/station.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const a = Station(id: 'a', name: 'A', url: 'https://a/s', description: '');
const b = Station(id: 'b', name: 'B', url: 'https://b/s', description: '');
const x = Station(id: 'x', name: 'X', url: 'https://x/s', description: '');

void main() {
  late StationLibrary lib;
  late Settings settings;

  Future<StationLibrary> make([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    settings = await Settings.load();
    return StationLibrary(settings, selection: const [a, b], more: const [x]);
  }

  setUp(() async => lib = await make());

  List<String> ids(List<Station> l) => l.map((s) => s.id).toList();

  test('starts with the AUX FM selection; extras are opt-in', () {
    expect(ids(lib.enabled), ['a', 'b']);
    expect(ids(lib.all), ['a', 'b', 'x']);
    expect(lib.isEnabled(x), isFalse);
  });

  test('adding extras and removing built-ins is remembered', () async {
    expect(lib.setEnabled(x, true), isTrue);
    expect(lib.setEnabled(a, false), isTrue);
    expect(ids(lib.enabled), ['b', 'x']);
    final reloaded = StationLibrary(
      Settings(await SharedPreferences.getInstance()),
      selection: const [a, b],
      more: const [x],
    );
    expect(ids(reloaded.enabled), ['b', 'x']);
  });

  test('the last station cannot be removed', () {
    expect(lib.setEnabled(a, false), isTrue);
    expect(lib.setEnabled(b, false), isFalse);
    expect(ids(lib.enabled), ['b']);
  });

  test('custom stations are added to the end and can be deleted', () async {
    final s = lib.addCustom(name: ' My Radio ', url: ' https://my/s ');
    expect(s.name, 'My Radio');
    expect(s.url, 'https://my/s');
    expect(ids(lib.enabled), ['a', 'b', s.id]);
    expect(lib.byId(s.id)?.subtitle, 'my');

    final reloaded = StationLibrary(
      Settings(await SharedPreferences.getInstance()),
      selection: const [a, b],
      more: const [x],
    );
    expect(reloaded.custom.single.name, 'My Radio');

    expect(lib.setEnabled(s, false), isTrue);
    expect(lib.isEnabled(s), isFalse);
    expect(lib.removeCustom(s), isTrue);
    expect(lib.custom, isEmpty);
  });

  test('a station removed from a newer app version just disappears', () async {
    lib = await make({
      'hiddenStations': ['gone'],
      'addedStations': ['also-gone', 'x'],
    });
    expect(ids(lib.enabled), ['a', 'b', 'x']);
  });

  test('validates what the user typed', () {
    expect(validateStation('', 'https://a/s'), isNotNull);
    expect(validateStation('A', 'a/s'), isNotNull);
    expect(validateStation('A', 'ftp://a/s'), isNotNull);
    expect(validateStation('A', 'https://'), isNotNull);
    expect(validateStation('A', 'https://a.example/stream'), isNull);
    expect(validateStation('A', 'http://1.2.3.4:8000/radio.mp3'), isNull);
  });
}
