import 'package:flutter/services.dart';

class NativeLyricsBridge {
  static const MethodChannel _channel = MethodChannel('muxic/lyrics');

  Future<int> decodeToWav({
    required String sourcePath,
    required String outputPath,
    bool enhanceVocals = true,
  }) async {
    final int? ms = await _channel
        .invokeMethod<int>('decodeToWav', <String, dynamic>{
          'sourcePath': sourcePath,
          'outputPath': outputPath,
          'enhanceVocals': enhanceVocals,
        });
    return ms ?? 0;
  }

  Future<void> cancelDecode(String outputPath) async {
    try {
      await _channel.invokeMethod('cancelDecode', <String, dynamic>{
        'outputPath': outputPath,
      });
    } on PlatformException {
    } on MissingPluginException {}
  }

  Future<void> startForegroundService(String title) async {
    try {
      await _channel.invokeMethod('startForegroundService', <String, dynamic>{
        'title': title,
      });
    } on PlatformException {
    } on MissingPluginException {}
  }

  Future<void> stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } on PlatformException {
    } on MissingPluginException {}
  }
}
