import 'package:flutter/services.dart';

class SongsChannel {
  SongsChannel._();

  static final SongsChannel instance = SongsChannel._();

  static const MethodChannel _channel = MethodChannel('muxic/songs');

  Future<bool> renameSong({
    required int songId,
    required String newTitle,
  }) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'renameSong',
        <String, dynamic>{'songId': songId, 'newTitle': newTitle},
      );
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
