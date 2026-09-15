import 'dart:io';

import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/lyrics.dart';

class TranscriptionProgress {
  const TranscriptionProgress({
    required this.fraction,
    required this.phase,
    this.partialLines = const <LyricLine>[],
  });

  final double? fraction;
  final String phase;

  final List<LyricLine> partialLines;
}

class TranscriptionException implements Exception {
  const TranscriptionException(this.message);
  final String message;
  @override
  String toString() => 'TranscriptionException: $message';
}

abstract class TranscriptionService {
  Future<bool> isReady();

  Future<String> unavailableReason();

  Stream<TranscriptionProgress> transcribe(SongModel song);
}

class UnavailableTranscriptionService implements TranscriptionService {
  const UnavailableTranscriptionService();

  static const String modelSubdir = 'models/asr';

  @override
  Future<bool> isReady() async {
    final Directory? dir = await _modelDir();
    if (dir == null || !dir.existsSync()) {
      return false;
    }
    return dir.listSync().isNotEmpty;
  }

  @override
  Future<String> unavailableReason() async =>
      'The offline lyrics engine (~166 MB) is not installed yet.';

  @override
  Stream<TranscriptionProgress> transcribe(SongModel song) async* {
    throw const TranscriptionException(
      'Lyrics generation is not available in this build.',
    );
  }

  static Future<Directory?> _modelDir() async {
    final Directory? base = await getExternalStorageDirectory();
    if (base == null) {
      return null;
    }
    return Directory(p.join(base.path, modelSubdir));
  }
}
