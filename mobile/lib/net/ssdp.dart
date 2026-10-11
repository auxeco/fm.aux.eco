import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Sends SSDP (UPnP) M-SEARCH requests and returns the addresses of the
/// devices that answered. [accept] filters on the raw response text.
Future<Set<String>> ssdpSearch(
  List<String> searchTargets, {
  Duration listenFor = const Duration(seconds: 3),
  bool Function(String response)? accept,
}) async {
  final multicast = InternetAddress('239.255.255.250');
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final hosts = <String>{};
  final sub = socket.listen((event) {
    if (event != RawSocketEvent.read) return;
    final datagram = socket.receive();
    if (datagram == null) return;
    final text = utf8.decode(datagram.data, allowMalformed: true);
    final isReply =
        text.startsWith('HTTP/1.1 200') || text.startsWith('NOTIFY');
    if (isReply && (accept == null || accept(text))) {
      hosts.add(datagram.address.address);
    }
  });
  for (final st in searchTargets) {
    final message =
        'M-SEARCH * HTTP/1.1\r\n'
        'HOST: 239.255.255.250:1900\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 2\r\n'
        'ST: $st\r\n\r\n';
    socket.send(utf8.encode(message), multicast, 1900);
  }
  await Future<void>.delayed(listenFor);
  await sub.cancel();
  socket.close();
  return hosts;
}
