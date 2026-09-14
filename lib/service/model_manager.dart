import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Locates the offline lyrics engine's model files.
///
/// Nothing is bundled in the APK. The files below are dropped manually today
/// (or fetched from a cloud endpoint later) into the app's own external
/// files directory - no runtime permission needed, and it's removed cleanly
/// on uninstall:
///
/// ```
/// Android/data/com.example.music/files/models/asr/distil-small.en-encoder.int8.onnx
/// Android/data/com.example.music/files/models/asr/distil-small.en-decoder.int8.onnx
/// Android/data/com.example.music/files/models/asr/distil-small.en-tokens.txt
/// Android/data/com.example.music/files/models/vad/silero_vad.onnx
/// ```
///
/// These are the standard sherpa-onnx release asset names for the
/// distil-whisper `distil-small.en` int8 export and the Silero VAD model.
class ModelManager {
  static const String asrSubdir = 'models/asr';
  static const String vadSubdir = 'models/vad';

  static const String encoderFileName = 'distil-small.en-encoder.int8.onnx';
  static const String decoderFileName = 'distil-small.en-decoder.int8.onnx';
  static const String tokensFileName = 'distil-small.en-tokens.txt';
  static const String vadFileName = 'silero_vad.onnx';

  Future<Directory> _baseDir() async =>
      await getExternalStorageDirectory() ??
      await getApplicationDocumentsDirectory();

  Future<String> asrDirPath() async =>
      p.join((await _baseDir()).path, asrSubdir);

  Future<String> vadDirPath() async =>
      p.join((await _baseDir()).path, vadSubdir);

  Future<String> encoderPath() async =>
      p.join(await asrDirPath(), encoderFileName);

  Future<String> decoderPath() async =>
      p.join(await asrDirPath(), decoderFileName);

  Future<String> tokensPath() async =>
      p.join(await asrDirPath(), tokensFileName);

  Future<String> vadModelPath() async =>
      p.join(await vadDirPath(), vadFileName);

  /// True only when every required model file is present.
  Future<bool> isReady() async {
    final List<String> required = <String>[
      await encoderPath(),
      await decoderPath(),
      await tokensPath(),
      await vadModelPath(),
    ];
    for (final String path in required) {
      if (!File(path).existsSync()) {
        return false;
      }
    }
    return true;
  }
}
