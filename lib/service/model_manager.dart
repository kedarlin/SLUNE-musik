import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
