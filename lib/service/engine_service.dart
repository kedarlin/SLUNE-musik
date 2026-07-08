import 'package:flutter/services.dart';

class AndroidBridge {
  static const MethodChannel _channel = MethodChannel('muxic/native');

  static Future<void> initialize() async {
    await _channel.invokeMethod('initializeAndroid');
  }
}
