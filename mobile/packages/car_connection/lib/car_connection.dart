import 'package:flutter/services.dart';

/// Whether the phone is connected to a car head unit.
class CarConnection {
  static const _channel = MethodChannel('eco.aux.fm/car_connection');

  /// True when projecting to Android Auto or running on Android Automotive
  /// OS. False on other platforms or if the state is unknown.
  static Future<bool> isConnected() async {
    try {
      final type = await _channel.invokeMethod<int>('connectionType');
      return (type ?? 0) != 0;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
