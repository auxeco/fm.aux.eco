import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

/// Posts a SOAP request; returns the HTTP status and body.
typedef SoapPost = Future<(int, String)> Function(
  Uri uri,
  String soapAction,
  String body,
);

class SonosException implements Exception {
  SonosException(this.message, {this.code});
  final String message;

  /// UPnP error code, e.g. 800 when the speaker isn't its group's
  /// coordinator.
  final int? code;

  @override
  String toString() =>
      'SonosException: $message${code == null ? '' : ' ($code)'}';
}

class SonosMember {
  const SonosMember({
    required this.id,
    required this.name,
    required this.host,
    this.port = 1400,
    this.hidden = false,
  });

  /// RINCON_… id.
  final String id;
  final String name;
  final String host;
  final int port;

  /// Bridges, subwoofers, surrounds and the second speaker of a stereo pair.
  final bool hidden;
}

class SonosGroup {
  const SonosGroup({required this.coordinatorId, required this.members});
  final String coordinatorId;
  final List<SonosMember> members;

  SonosMember? get coordinator {
    for (final m in members) {
      if (m.id == coordinatorId) return m;
    }
    return null;
  }
}

enum SonosTransport { playing, transitioning, paused, stopped }

class SonosStatus {
  const SonosStatus({
    required this.transport,
    required this.volume,
    required this.muted,
    this.title,
  });

  final SonosTransport transport;

  /// 0–100.
  final int volume;
  final bool muted;

  /// What's on air, from the stream's metadata (Sonos reads ICY titles).
  final String? title;
}

/// Local control of a Sonos speaker (or the group it coordinates) through
/// its UPnP/SOAP interface on port 1400, as used by SoCo and Home
/// Assistant.
class SonosClient {
  SonosClient(
    this.host, {
    this.port = 1400,
    SoapPost? post,
    this.timeout = const Duration(seconds: 4),
  }) : _post = post ?? _httpPost(timeout);

  final String host;
  final int port;
  final Duration timeout;
  final SoapPost _post;

  static const _avTransport = (
    '/MediaRenderer/AVTransport/Control',
    'urn:schemas-upnp-org:service:AVTransport:1',
  );
  static const _groupRendering = (
    '/MediaRenderer/GroupRenderingControl/Control',
    'urn:schemas-upnp-org:service:GroupRenderingControl:1',
  );
  static const _topology = (
    '/ZoneGroupTopology/Control',
    'urn:schemas-upnp-org:service:ZoneGroupTopology:1',
  );

  /// Plays [url] as a radio station called [title].
  Future<void> playStream(String url, String title) async {
    await _call(_avTransport, 'SetAVTransportURI', {
      'InstanceID': '0',
      'CurrentURI': radioUri(url),
      'CurrentURIMetaData': radioMetadata(title),
    });
    await _call(_avTransport, 'Play', {'InstanceID': '0', 'Speed': '1'});
  }

  Future<void> stop() async {
    try {
      await _call(_avTransport, 'Stop', {'InstanceID': '0'});
    } on SonosException catch (e) {
      // 701: transition not available, i.e. already stopped.
      if (e.code != 701) rethrow;
    }
  }

  Future<SonosStatus> status() async {
    final transport = await _call(_avTransport, 'GetTransportInfo', {
      'InstanceID': '0',
    });
    final volume = await _call(_groupRendering, 'GetGroupVolume', {
      'InstanceID': '0',
    });
    final mute = await _call(_groupRendering, 'GetGroupMute', {
      'InstanceID': '0',
    });
    final position = await _call(_avTransport, 'GetPositionInfo', {
      'InstanceID': '0',
    });
    return SonosStatus(
      transport: switch (_value(transport, 'CurrentTransportState')) {
        'PLAYING' => SonosTransport.playing,
        'TRANSITIONING' => SonosTransport.transitioning,
        'PAUSED_PLAYBACK' => SonosTransport.paused,
        _ => SonosTransport.stopped,
      },
      volume: int.tryParse(_value(volume, 'CurrentVolume') ?? '') ?? 0,
      muted: _value(mute, 'CurrentMute') == '1',
      title: streamTitle(_value(position, 'TrackMetaData')),
    );
  }

  Future<void> setVolume(int volume) => _call(
    _groupRendering,
    'SetGroupVolume',
    {'InstanceID': '0', 'DesiredVolume': '${volume.clamp(0, 100)}'},
  );

  Future<void> setMuted(bool muted) => _call(_groupRendering, 'SetGroupMute', {
    'InstanceID': '0',
    'DesiredMute': muted ? '1' : '0',
  });

  /// The household's rooms and how they are grouped.
  Future<List<SonosGroup>> zoneGroups() async {
    final response = await _call(_topology, 'GetZoneGroupState');
    return parseZoneGroups(_value(response, 'ZoneGroupState') ?? '');
  }

  Future<XmlElement> _call(
    (String, String) service,
    String action, [
    Map<String, String> args = const {},
  ]) async {
    final (path, type) = service;
    final body = StringBuffer()
      ..write('<?xml version="1.0" encoding="utf-8"?>')
      ..write(
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">',
      )
      ..write('<s:Body><u:$action xmlns:u="$type">');
    for (final MapEntry(:key, :value) in args.entries) {
      body.write('<$key>${_escape(value)}</$key>');
    }
    body.write('</u:$action></s:Body></s:Envelope>');

    final (int, String) reply;
    try {
      reply = await _post(
        Uri(scheme: 'http', host: host, port: port, path: path),
        '"$type#$action"',
        body.toString(),
      );
    } on SonosException {
      rethrow;
    } on Exception catch (e) {
      throw SonosException('Cannot reach $host ($e)');
    }
    final (status, text) = reply;
    if (status != 200) {
      final code = RegExp(r'<errorCode>(\d+)</errorCode>').firstMatch(text);
      throw SonosException(
        '$action failed (HTTP $status)',
        code: code == null ? null : int.parse(code.group(1)!),
      );
    }
    try {
      return XmlDocument.parse(text).descendantElements
          .firstWhere((e) => e.localName == '${action}Response');
    } on Object {
      throw SonosException('Unexpected reply to $action');
    }
  }

  static String? _value(XmlElement response, String name) {
    for (final e in response.childElements) {
      if (e.localName == name) return e.innerText;
    }
    return null;
  }

  static String _escape(String s) => const HtmlEscape(
    HtmlEscapeMode(escapeLtGt: true, escapeQuot: true, escapeApos: true),
  ).convert(s);

  static SoapPost _httpPost(Duration timeout) => (uri, action, body) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'text/xml; charset="utf-8"')
        ..set('SOAPACTION', action);
      request.add(utf8.encode(body));
      final response = await request.close().timeout(timeout);
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      return (response.statusCode, text);
    } finally {
      client.close(force: true);
    }
  };
}

/// Sonos only plays internet radio from `x-rincon-mp3radio:` URIs (since
/// firmware 6.4.2); it takes the place of `http:` / `https:` (as in SoCo).
String radioUri(String url) {
  final colon = url.indexOf(':');
  return colon > 0 ? 'x-rincon-mp3radio${url.substring(colon)}' : url;
}

/// DIDL-Lite metadata that makes Sonos show [title] with radio controls.
String radioMetadata(String title) {
  final t = const HtmlEscape(HtmlEscapeMode.element).convert(title);
  return '<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" '
      'xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" '
      'xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">'
      '<item id="R:0/0/0" parentID="R:0/0" restricted="true">'
      '<dc:title>$t</dc:title>'
      '<upnp:class>object.item.audioItem.audioBroadcast</upnp:class>'
      '<desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">'
      'SA_RINCON65031_</desc></item></DIDL-Lite>';
}

/// The live "artist - title" Sonos reads from a radio stream, if any.
String? streamTitle(String? trackMetadata) {
  if (trackMetadata == null || !trackMetadata.contains('<')) return null;
  try {
    final doc = XmlDocument.parse(trackMetadata);
    for (final name in ['streamContent', 'title']) {
      for (final e in doc.descendantElements) {
        if (e.localName == name) {
          final text = e.innerText.trim();
          if (text.isNotEmpty && !text.startsWith('x-')) return text;
        }
      }
    }
  } on Object {
    // fall through
  }
  return null;
}

/// Parses the ZoneGroupState XML (S1: `<ZoneGroups>`, S2:
/// `<ZoneGroupState><ZoneGroups>`).
List<SonosGroup> parseZoneGroups(String xml) {
  if (xml.trim().isEmpty) return const [];
  final doc = XmlDocument.parse(xml);
  return [
    for (final group in doc.findAllElements('ZoneGroup'))
      SonosGroup(
        coordinatorId: group.getAttribute('Coordinator') ?? '',
        members: [
          // Direct children only: <Satellite> entries (surrounds, subs)
          // are nested inside their main speaker.
          for (final m in group.findElements('ZoneGroupMember'))
            if (Uri.tryParse(m.getAttribute('Location') ?? '')
                case final Uri location? when location.host.isNotEmpty)
              SonosMember(
                id: m.getAttribute('UUID') ?? '',
                name: m.getAttribute('ZoneName') ?? 'Sonos',
                host: location.host,
                port: location.hasPort ? location.port : 1400,
                hidden:
                    m.getAttribute('Invisible') == '1' ||
                    m.getAttribute('IsZoneBridge') == '1',
              ),
        ],
      ),
  ];
}
