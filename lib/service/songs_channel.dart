import 'package:flutter/services.dart';

/// Bridges to the native muxic/songs channel - MediaStore file operations
/// on_audio_query itself doesn't expose (it only supports renaming
/// playlists, not the underlying audio files).
class SongsChannel {
  SongsChannel._();

  static final SongsChannel instance = SongsChannel._();

  static const MethodChannel _channel = MethodChannel('muxic/songs');

  /// Renames the audio file's title/display name via MediaStore. On Android
  /// 10+ this can show a one-time system consent dialog for media the app
  /// doesn't own (i.e. basically every pre-existing song) - the returned
  /// future doesn't resolve until that's answered.
  ///
  /// Returns false on failure (denied, or an OS-level error) rather than
  /// throwing - a failed rename should just leave the song as it was.
  Future<bool> renameSong({required int songId, required String newTitle}) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>('renameSong', <String, dynamic>{
        'songId': songId,
        'newTitle': newTitle,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
