import 'package:aux_fm/data/stations.dart';
import 'package:aux_fm/voice/station_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? find(String q) => findStation(q, stations)?.id;

  test('matches names the way people say them', () {
    expect(find('NTS'), 'NTS');
    expect(find('NTS one'), 'NTS');
    expect(find('NTS two'), 'NTS2');
    expect(find('N.T.S. 2'), 'NTS2');
    expect(find('KEXP radio'), 'kexp');
    expect(find('dub lab'), 'dublab');
    expect(find('GDS FM'), 'gds.fm');
    expect(find('Worldwide'), 'worldwidefm');
    expect(find('Refuge'), 'rw');
    expect(find('Seoul Community Radio'), 'seoulcommunityradio');
    expect(find('Buena Vida'), 'rbv');
    expect(find('byte fm'), 'byte');
    expect(find('rinse'), 'rinse');
  });

  test('strips the app name and filler', () {
    expect(find('play WEFUNK on AUX FM'), 'wefunkradio');
    expect(find('NTS 2 on aux fm'), 'NTS2');
  });

  test('no match', () {
    expect(find(''), isNull);
    expect(find('jazz'), isNull);
    expect(find('aux fm'), isNull);
  });

  test('search lists the best match first', () {
    final results = searchStations('worldwide', stations).map((s) => s.id);
    expect(results.first, 'worldwidefm');
    expect(results, contains('rw'));
  });
}
