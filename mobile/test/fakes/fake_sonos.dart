import 'dart:convert';
import 'dart:io';

import 'package:aux_fm/sonos/sonos_client.dart';
import 'package:xml/xml.dart';

/// A Sonos player answering the UPnP/SOAP control API on localhost.
class FakeSonos {
  late HttpServer _server;
  final calls = <(String action, Map<String, String> args)>[];

  String uri = '';
  String metadata = '';
  String state = 'STOPPED';
  int volume = 25;
  bool muted = false;
  String? streamContent;

  /// Not its group's coordinator: transport commands fail with 800.
  bool coordinator = true;

  /// GetZoneGroupState reply, built from [groupsXml].
  String Function() groupsXml = () =>
      '<ZoneGroupState><ZoneGroups/>'
      '</ZoneGroupState>';

  int get port => _server.port;
  String get host => '127.0.0.1';
  String get location => 'http://$host:$port/xml/device_description.xml';

  SonosClient client() => SonosClient(host, port: port);

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> close() => _server.close(force: true);

  List<String> get actions => [for (final c in calls) c.$1];

  Future<void> _handle(HttpRequest req) async {
    final body = await utf8.decoder.bind(req).join();
    final soapAction = req.headers.value('SOAPACTION') ?? '';
    final action = soapAction.replaceAll('"', '').split('#').last;
    final xml = XmlDocument.parse(body);
    final call = xml.descendantElements.firstWhere(
      (e) => e.localName == action,
    );
    final args = {for (final a in call.childElements) a.localName: a.innerText};
    calls.add((action, args));

    void reply(Map<String, String> out) {
      final fields = out.entries
          .map((e) => '<${e.key}>${_esc(e.value)}</${e.key}>')
          .join();
      req.response
        ..headers.contentType = ContentType('text', 'xml', charset: 'utf-8')
        ..write(
          '<?xml version="1.0"?><s:Envelope '
          'xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>'
          '<u:${action}Response xmlns:u="urn:x">$fields'
          '</u:${action}Response></s:Body></s:Envelope>',
        )
        ..close();
    }

    void fail(int code) {
      req.response
        ..statusCode = 500
        ..write(
          '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">'
          '<s:Body><s:Fault><detail><UPnPError '
          'xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>$code'
          '</errorCode></UPnPError></detail></s:Fault></s:Body></s:Envelope>',
        )
        ..close();
    }

    final transport =
        req.uri.path.contains('AVTransport') ||
        req.uri.path.contains('GroupRendering');
    if (transport && !coordinator) return fail(800);

    switch (action) {
      case 'SetAVTransportURI':
        uri = args['CurrentURI']!;
        metadata = args['CurrentURIMetaData']!;
        state = 'STOPPED';
        reply({});
      case 'Play':
        state = 'PLAYING';
        reply({});
      case 'Stop':
        if (state == 'STOPPED') return fail(701);
        state = 'STOPPED';
        reply({});
      case 'GetTransportInfo':
        reply({'CurrentTransportState': state});
      case 'GetGroupVolume':
        reply({'CurrentVolume': '$volume'});
      case 'SetGroupVolume':
        volume = int.parse(args['DesiredVolume']!);
        reply({});
      case 'GetGroupMute':
        reply({'CurrentMute': muted ? '1' : '0'});
      case 'SetGroupMute':
        muted = args['DesiredMute'] == '1';
        reply({});
      case 'GetPositionInfo':
        reply({
          'TrackMetaData': streamContent == null
              ? 'NOT_IMPLEMENTED'
              : '<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" '
                    'xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" '
                    'xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">'
                    '<item><dc:title>x-sonosapi-stream:abc</dc:title>'
                    '<r:streamContent>${_esc(streamContent!)}'
                    '</r:streamContent></item></DIDL-Lite>',
        });
      case 'GetZoneGroupState':
        reply({'ZoneGroupState': groupsXml()});
      default:
        fail(401);
    }
  }

  static String _esc(String s) => const HtmlEscape().convert(s);
}
