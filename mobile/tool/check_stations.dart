// Checks that radio stream URLs actually deliver audio.
//
//   dart run tool/check_stations.dart                 # the app's stations
//   dart run tool/check_stations.dart --candidates f  # a list to evaluate
//
// A candidates file has one entry per line:
//   Name | https://stream.url      probe this URL
//   ? Name                         look the station up on radio-browser.info
//                                  and probe what it lists
// Blank lines and lines starting with # are ignored.
//
// Exits with 1 if any of the app's stations fails. Runs in CI
// (.github/workflows/stations.yml); stream hosts are often unreachable from
// sandboxes and corporate proxies.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aux_fm/audio/stream_probe.dart';
import 'package:aux_fm/data/more_stations.dart';
import 'package:aux_fm/data/stations.dart';

const _timeout = Duration(seconds: 12);
const _agent =
    'AUX-FM-station-check/1.0 (+https://github.com/auxeco/fm.aux.eco)';

Future<void> main(List<String> args) async {
  final i = args.indexOf('--candidates');
  if (i >= 0 && i + 1 < args.length) {
    await _candidates(File(args[i + 1]).readAsLinesSync());
    return;
  }
  var failed = 0;
  for (final (group, list) in [
    ('AUX FM selection', stations),
    ('More stations', moreStations),
  ]) {
    stdout.writeln('\n== $group ==');
    for (final s in list) {
      final p = await probeStream(s.url, timeout: _timeout);
      if (!p.ok) failed++;
      stdout.writeln('${p.summary}  ${s.name}  ${s.url}');
    }
  }
  stdout.writeln('\n$failed failing');
  exitCode = failed == 0 ? 0 : 1;
}

Future<void> _candidates(List<String> lines) async {
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('?')) {
      final name = line.substring(1).trim();
      stdout.writeln('\n?? $name');
      for (final hit in await _lookup(name)) {
        final p = await probeStream(hit.url, timeout: _timeout);
        stdout.writeln(
          '${p.summary}  ${hit.name} [${hit.codec} ${hit.bitrate}k '
          '${hit.country}] ${hit.url}  home=${hit.homepage}',
        );
      }
    } else {
      final parts = line.split('|');
      final name = parts.first.trim();
      final url = parts.length > 1 ? parts[1].trim() : name;
      final p = await probeStream(url, timeout: _timeout);
      stdout.writeln('${p.summary}  $name  $url');
    }
  }
}

class _Hit {
  _Hit(
    this.name,
    this.url,
    this.codec,
    this.bitrate,
    this.country,
    this.homepage,
  );
  final String name, url, codec, country, homepage;
  final int bitrate;
}

/// radio-browser.info, the open radio directory.
Future<List<_Hit>> _lookup(String name) async {
  for (final server in [
    'de1.api.radio-browser.info',
    'fi1.api.radio-browser.info',
    'de2.api.radio-browser.info',
  ]) {
    final client = HttpClient()
      ..connectionTimeout = _timeout
      ..userAgent = _agent;
    try {
      final uri = Uri.https(server, '/json/stations/search', {
        'name': name,
        'limit': '6',
        'order': 'clickcount',
        'reverse': 'true',
        'hidebroken': 'true',
      });
      final request = await client.getUrl(uri).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      final json = await response.transform(utf8.decoder).join();
      final list = jsonDecode(json) as List;
      return [
        for (final s in list.cast<Map<String, dynamic>>())
          _Hit(
            '${s['name']}'.trim(),
            '${s['url_resolved'] ?? s['url']}'.trim(),
            '${s['codec']}',
            (s['bitrate'] as num?)?.toInt() ?? 0,
            '${s['countrycode']}',
            '${s['homepage']}',
          ),
      ];
    } on Object catch (e) {
      stdout.writeln('   lookup via $server failed: $e');
    } finally {
      client.close(force: true);
    }
  }
  return const [];
}
