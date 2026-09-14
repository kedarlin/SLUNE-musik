import 'package:flutter/services.dart';

/// Thin wrapper over the muxic/lyrics MethodChannel - the native half of
/// lyrics generation (MediaCodec decode to a 16 kHz mono WAV, and the
/// foreground-service keep-alive signal). The actual VAD + Whisper inference
/// happens in Dart (sherpa_onnx) - see [SherpaTranscriptionService].
class NativeLyricsBridge {
  static const MethodChannel _channel = MethodChannel('muxic/lyrics');

  /// Decodes [sourcePath] to a 16 kHz mono 16-bit WAV at [outputPath].
  /// Returns the decoded duration in milliseconds.
  ///
  /// [enhanceVocals] applies a cheap vocal-frequency bandpass before
  /// resampling - a small SNR nudge for the ASR pass, not real vocal
  /// separation (no such model ships with the offline engine).
  Future<int> decodeToWav({
    required String sourcePath,
    required String outputPath,
    bool enhanceVocals = true,
  }) async {
    final int? ms = await _channel.invokeMethod<int>('decodeToWav', <String, dynamic>{
      'sourcePath': sourcePath,
      'outputPath': outputPath,
      'enhanceVocals': enhanceVocals,
    });
    return ms ?? 0;
  }

  Future<void> startForegroundService(String title) async {
    try {
      await _channel.invokeMethod('startForegroundService', <String, dynamic>{
        'title': title,
      });
    } on PlatformException {
      // Non-fatal: worst case the process can be reclaimed under memory
      // pressure while backgrounded, same as any best-effort background job.
    } on MissingPluginException {
      // ignore
    }
  }

  Future<void> stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }
}
