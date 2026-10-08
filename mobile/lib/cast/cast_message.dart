import 'dart:convert';
import 'dart:typed_data';

/// A Cast v2 channel message (the `CastMessage` protobuf from Chromium's
/// `cast_channel.proto`). Only string payloads are used.
class CastMessage {
  const CastMessage({
    required this.sourceId,
    required this.destinationId,
    required this.namespace,
    required this.payload,
  });

  final String sourceId;
  final String destinationId;
  final String namespace;
  final String payload;

  /// Payload parsed as JSON, or an empty map if it is not a JSON object.
  Map<String, dynamic> get json {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // fall through
    }
    return const {};
  }

  /// Protobuf encoding without the length prefix.
  Uint8List encode() {
    final out = BytesBuilder();
    void varint(int value) {
      while (value >= 0x80) {
        out.addByte((value & 0x7f) | 0x80);
        value >>= 7;
      }
      out.addByte(value);
    }

    void string(int field, String value) {
      final bytes = utf8.encode(value);
      varint(field << 3 | 2);
      varint(bytes.length);
      out.add(bytes);
    }

    varint(1 << 3); // protocol_version = CASTV2_1_0 (0)
    varint(0);
    string(2, sourceId);
    string(3, destinationId);
    string(4, namespace);
    varint(5 << 3); // payload_type = STRING (0)
    varint(0);
    string(6, payload);
    return out.toBytes();
  }

  /// Encoded message with the 4-byte big-endian length prefix used on the
  /// wire.
  Uint8List frame() {
    final body = encode();
    final framed = Uint8List(4 + body.length);
    ByteData.sublistView(framed).setUint32(0, body.length);
    framed.setRange(4, framed.length, body);
    return framed;
  }

  static CastMessage decode(Uint8List bytes) {
    var pos = 0;
    int varint() {
      var result = 0;
      var shift = 0;
      while (true) {
        if (pos >= bytes.length) throw const FormatException('Truncated');
        final b = bytes[pos++];
        result |= (b & 0x7f) << shift;
        if (b < 0x80) return result;
        shift += 7;
      }
    }

    final strings = <int, String>{};
    while (pos < bytes.length) {
      final key = varint();
      final field = key >> 3;
      switch (key & 7) {
        case 0:
          varint();
        case 2:
          final len = varint();
          if (pos + len > bytes.length) {
            throw const FormatException('Truncated');
          }
          strings[field] = utf8.decode(
            bytes.sublist(pos, pos + len),
            allowMalformed: true,
          );
          pos += len;
        case 1:
          pos += 8;
        case 5:
          pos += 4;
        default:
          throw FormatException('Unsupported wire type in key $key');
      }
    }
    return CastMessage(
      sourceId: strings[2] ?? '',
      destinationId: strings[3] ?? '',
      namespace: strings[4] ?? '',
      payload: strings[6] ?? '',
    );
  }

  @override
  String toString() =>
      'CastMessage($sourceId → $destinationId $namespace '
      '$payload)';
}

/// Splits a byte stream into length-prefixed Cast messages.
class CastFrameReader {
  final _buffer = BytesBuilder(copy: false);

  /// Adds received bytes and returns every message completed by them.
  List<CastMessage> add(List<int> chunk) {
    _buffer.add(chunk);
    final data = _buffer.takeBytes();
    final messages = <CastMessage>[];
    var pos = 0;
    while (data.length - pos >= 4) {
      final len = ByteData.sublistView(data, pos, pos + 4).getUint32(0);
      if (data.length - pos - 4 < len) break;
      messages.add(
        CastMessage.decode(Uint8List.sublistView(data, pos + 4, pos + 4 + len)),
      );
      pos += 4 + len;
    }
    if (pos < data.length) _buffer.add(Uint8List.sublistView(data, pos));
    return messages;
  }
}
