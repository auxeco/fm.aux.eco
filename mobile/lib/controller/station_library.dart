import '../data/more_stations.dart' as data;
import '../data/stations.dart' as data;
import '../models/station.dart';
import 'settings.dart';

/// All stations the app knows, and which of them are in the user's list.
///
/// - The AUX FM selection is in the list unless the user removed it.
/// - Extra catalog stations are only in the list once the user adds them.
/// - Stations the user enters are added to the list straight away.
class StationLibrary {
  StationLibrary(
    this._settings, {
    this.selection = data.stations,
    this.more = data.moreStations,
  });

  final Settings _settings;
  final List<Station> selection;
  final List<Station> more;

  List<Station> get custom => _settings.customStations;

  List<Station> get all => [...selection, ...more, ...custom];

  /// The station list shown in the app, in this order.
  List<Station> get enabled => all.where(isEnabled).toList();

  bool isEnabled(Station s) => more.any((m) => m.id == s.id)
      ? _settings.addedStations.contains(s.id)
      : !_settings.hiddenStations.contains(s.id);

  Station? byId(String? id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Adds [s] to or removes it from the list. The last station can't be
  /// removed; returns false then.
  bool setEnabled(Station s, bool on) {
    if (isEnabled(s) == on) return true;
    if (!on && enabled.length <= 1) return false;
    if (more.any((m) => m.id == s.id)) {
      final added = _settings.addedStations;
      on ? added.add(s.id) : added.remove(s.id);
      _settings.addedStations = added;
    } else {
      final hidden = _settings.hiddenStations;
      on ? hidden.remove(s.id) : hidden.add(s.id);
      _settings.hiddenStations = hidden;
    }
    return true;
  }

  Station addCustom({required String name, required String url}) {
    final station = Station(
      id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      url: url.trim(),
      description: '',
    );
    _settings.customStations = [...custom, station];
    return station;
  }

  /// Deletes a station the user entered. Like [setEnabled], refuses to
  /// delete the last station in the list.
  bool removeCustom(Station s) {
    if (isEnabled(s) && enabled.length <= 1) return false;
    _settings.customStations = [
      for (final c in custom)
        if (c.id != s.id) c,
    ];
    final hidden = _settings.hiddenStations..remove(s.id);
    _settings.hiddenStations = hidden;
    return true;
  }
}

/// Checks what the user typed in "Add a station". Returns an error message,
/// or null if it looks usable.
String? validateStation(String name, String url) {
  if (name.trim().isEmpty) return 'Give the station a name.';
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    return 'Enter the stream address, starting with https:// or http://';
  }
  return null;
}
