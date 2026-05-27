import 'dart:convert';
import 'package:flutter/services.dart';

class NativeAudio {
  static const MethodChannel _method = MethodChannel('native_audio');
  static const EventChannel _events = EventChannel('native_audio_events');

  static Stream<Map<String, dynamic>>? _cachedStream;

  /// Load a song into Media3 service
  static Future<void> load({
    required String uri,
    required String title,
    required String id,
    String? artist,
    Uint8List? artwork,
  }) {
    return _method.invokeMethod('load', <String, Object?>{
      'uri': uri,
      'title': title,
      'id': id,
      'artist': artist,
      'artwork': artwork,
    });
  }

  /// Play
  static Future<void> play() => _method.invokeMethod('play');

  /// Pause
  static Future<void> pause() => _method.invokeMethod('pause');

  /// Seek
  static Future<void> seek(int pos) =>
      _method.invokeMethod('seek', <String, int>{'position': pos});

  /// Change speed + pitch
  static Future<void> speedPitch(double speed, double pitch) =>
      _method.invokeMethod('speedPitch', <String, double>{
        'speed': speed,
        'pitch': pitch,
      });

  /// Optional (native can trigger these for some devices)
  static Future<void> next() => _method.invokeMethod('next');
  static Future<void> previous() => _method.invokeMethod('previous');

  static Future<void> loadPlaylist(
    List<Map<String, dynamic>> queue,
    int index,
  ) => _method.invokeMethod('loadPlaylist', <Object>[queue, index]);

  /// Stream from EventChannel
  static Stream<Map<String, dynamic>> events() {
    _cachedStream ??= _events.receiveBroadcastStream().map((dynamic raw) {
      final Map<String, dynamic> map =
          json.decode(raw as String) as Map<String, dynamic>;
      return map;
    });
    return _cachedStream!;
  }
}
