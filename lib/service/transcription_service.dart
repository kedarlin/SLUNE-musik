import 'dart:io';

import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/lyrics.dart';

/// Progress of an in-flight transcription job.
class TranscriptionProgress {
  const TranscriptionProgress({
    required this.fraction,
    required this.phase,
    this.partialLines = const <LyricLine>[],
  });

  /// 0..1, or null if indeterminate.
  final double? fraction;
  final String phase;

  /// Lines produced so far, so the UI can stream them in top-down.
  final List<LyricLine> partialLines;
}

class TranscriptionException implements Exception {
  const TranscriptionException(this.message);
  final String message;
  @override
  String toString() => 'TranscriptionException: $message';
}

/// On-device lyric transcription. Phase B plugs a `sherpa-onnx` Whisper
/// implementation in behind this interface; the rest of the app only ever
/// talks to the interface, so nothing else changes when the engine lands.
abstract class TranscriptionService {
  /// Whether the model files are present and the engine can run.
  Future<bool> isReady();

  /// A human-readable reason [isReady] returned false (for the UI).
  Future<String> unavailableReason();

  /// Transcribes [song] to timed lines. Emits [TranscriptionProgress] as it
  /// goes; the returned future completes with the final lyrics.
  ///
  /// Implementations must honour cancellation via [onCancelSignal] (completing
  /// it should abort the job with a [TranscriptionException]).
  Stream<TranscriptionProgress> transcribe(SongModel song);
}

/// The default implementation until the real engine is wired: reports the
/// engine as not installed and refuses to run. Keeps the UI flow complete.
class UnavailableTranscriptionService implements TranscriptionService {
  const UnavailableTranscriptionService();

  static const String modelSubdir = 'models/asr';

  @override
  Future<bool> isReady() async {
    final Directory? dir = await _modelDir();
    if (dir == null || !dir.existsSync()) {
      return false;
    }
    // The real check (a specific ONNX/tokens file set) lands with the engine.
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
