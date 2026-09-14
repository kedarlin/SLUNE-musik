import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../models/lyrics.dart';
import 'model_manager.dart';
import 'native_lyrics_bridge.dart';
import 'transcription_service.dart';

/// On-device lyrics transcription: VAD (Silero, via sherpa-onnx) splits the
/// decoded audio into speech-shaped segments, each is fed to an offline
/// Whisper (distil-small.en) recognizer independently. A VAD segment's start
/// time becomes the line's timestamp - this is what gives line-level sync
/// without needing word/segment timestamps out of Whisper itself.
///
/// Pipeline: native MediaCodec decode (file -> 16 kHz mono WAV) -> spawn a
/// Dart isolate (VAD + Whisper both run through FFI, off the UI thread) ->
/// stream lines back as they're produced.
class SherpaTranscriptionService implements TranscriptionService {
  SherpaTranscriptionService({ModelManager? models, NativeLyricsBridge? bridge})
    : _models = models ?? ModelManager(),
      _bridge = bridge ?? NativeLyricsBridge();

  final ModelManager _models;
  final NativeLyricsBridge _bridge;

  @override
  Future<bool> isReady() => _models.isReady();

  @override
  Future<String> unavailableReason() async =>
      'The offline lyrics engine (~200 MB) is not installed. Place the model '
      'files under Android/data/com.example.music/files/models/ (see '
      'docs/LYRICS_PLAN.md).';

  @override
  Stream<TranscriptionProgress> transcribe(SongModel song) {
    late StreamController<TranscriptionProgress> controller;
    Isolate? isolate;
    ReceivePort? receivePort;
    String? tempWavPath;
    bool cancelled = false;

    Future<void> cleanup() async {
      isolate?.kill(priority: Isolate.immediate);
      isolate = null;
      receivePort?.close();
      receivePort = null;
      await _bridge.stopForegroundService();
      final String? wavPath = tempWavPath;
      if (wavPath != null) {
        try {
          final File file = File(wavPath);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } on FileSystemException {
          // Best effort - a stray temp file is not worth failing over.
        }
      }
    }

    Future<void> run() async {
      try {
        await _bridge.startForegroundService('Generating lyrics — ${song.title}');
        controller.add(
          const TranscriptionProgress(fraction: null, phase: 'Decoding audio…'),
        );

        final Directory tempDir = await getTemporaryDirectory();
        final String wavPath = p.join(tempDir.path, 'lyrics_${song.id}.wav');
        tempWavPath = wavPath;

        await _bridge.decodeToWav(sourcePath: song.data, outputPath: wavPath);
        if (cancelled) {
          return;
        }

        controller.add(
          const TranscriptionProgress(fraction: 0, phase: 'Transcribing…'),
        );

        final ReceivePort port = ReceivePort();
        receivePort = port;
        isolate = await Isolate.spawn(_transcribeIsolateEntry, <String, dynamic>{
          'sendPort': port.sendPort,
          'wavPath': wavPath,
          'encoderPath': await _models.encoderPath(),
          'decoderPath': await _models.decoderPath(),
          'tokensPath': await _models.tokensPath(),
          'vadModelPath': await _models.vadModelPath(),
        });

        final List<LyricLine> lines = <LyricLine>[];

        await for (final dynamic raw in port) {
          if (cancelled) {
            break;
          }
          final Map<dynamic, dynamic> message = raw as Map<dynamic, dynamic>;

          switch (message['type']) {
            case 'line':
              final String text = (message['text'] as String? ?? '').trim();
              if (text.isNotEmpty) {
                lines.add(
                  LyricLine(
                    time: Duration(milliseconds: message['startMs'] as int? ?? 0),
                    text: text,
                  ),
                );
              }
              controller.add(
                TranscriptionProgress(
                  fraction: (message['fraction'] as num?)?.toDouble(),
                  phase: 'Transcribing…',
                  partialLines: List<LyricLine>.of(lines),
                ),
              );
            case 'progress':
              // A segment was filtered out (instrumental/hallucination) -
              // still move the percentage so the UI doesn't look stuck.
              controller.add(
                TranscriptionProgress(
                  fraction: (message['fraction'] as num?)?.toDouble(),
                  phase: 'Transcribing…',
                  partialLines: List<LyricLine>.of(lines),
                ),
              );
            case 'done':
              controller.add(
                TranscriptionProgress(
                  fraction: 1.0,
                  phase: 'Done',
                  partialLines: List<LyricLine>.of(lines),
                ),
              );
              await controller.close();
              return;
            case 'error':
              controller.addError(
                TranscriptionException(
                  message['message'] as String? ?? 'Unknown transcription error',
                ),
              );
              await controller.close();
              return;
          }
        }
      } catch (error) {
        if (!controller.isClosed) {
          controller.addError(TranscriptionException(error.toString()));
          await controller.close();
        }
      } finally {
        await cleanup();
      }
    }

    controller = StreamController<TranscriptionProgress>(
      onListen: run,
      onCancel: () {
        cancelled = true;
        return cleanup();
      },
    );
    return controller.stream;
  }
}

/// Runs entirely inside a spawned isolate - must be a top-level function.
/// Every sherpa-onnx object created here must be freed here; none of it can
/// cross the isolate boundary.
void _transcribeIsolateEntry(Map<String, dynamic> args) {
  final SendPort sendPort = args['sendPort'] as SendPort;

  sherpa_onnx.VoiceActivityDetector? vad;
  sherpa_onnx.OfflineRecognizer? recognizer;

  try {
    // Each isolate has its own FFI binding state - this must run here, not
    // just in the main isolate.
    sherpa_onnx.initBindings();

    final sherpa_onnx.VadModelConfig vadConfig = sherpa_onnx.VadModelConfig(
      sileroVad: sherpa_onnx.SileroVadModelConfig(
        model: args['vadModelPath'] as String,
        minSilenceDuration: 0.3,
        maxSpeechDuration: 10.0,
      ),
      debug: false,
    );
    vad = sherpa_onnx.VoiceActivityDetector(
      config: vadConfig,
      bufferSizeInSeconds: 30,
    );

    final sherpa_onnx.OfflineWhisperModelConfig whisperConfig =
        sherpa_onnx.OfflineWhisperModelConfig(
          encoder: args['encoderPath'] as String,
          decoder: args['decoderPath'] as String,
          language: 'en',
          task: 'transcribe',
        );
    final sherpa_onnx.OfflineModelConfig modelConfig = sherpa_onnx.OfflineModelConfig(
      whisper: whisperConfig,
      tokens: args['tokensPath'] as String,
      numThreads: 2,
      debug: false,
      modelType: 'whisper',
    );
    recognizer = sherpa_onnx.OfflineRecognizer(
      sherpa_onnx.OfflineRecognizerConfig(model: modelConfig),
    );

    final sherpa_onnx.WaveData wave = sherpa_onnx.readWave(args['wavPath'] as String);
    final Float32List samples = wave.samples;
    final double totalDurationSec = samples.length / 16000.0;

    const int windowSize = 512;
    int offset = 0;

    // Whisper tends to hallucinate short filler ("Thank you.", "...", a bare
    // music note) on instrumental/silent segments a full-mix VAD pass will
    // inevitably still flag as "speech" - drop those rather than surface them
    // as bogus lyric lines. The user reviewing/editing a draft is the real
    // accuracy net, but this cuts the obvious noise before it gets there.
    String? lastEmittedText;

    void drainSegments() {
      while (!vad!.isEmpty()) {
        final sherpa_onnx.SpeechSegment segment = vad.front();
        vad.pop();
        if (segment.samples.isEmpty) {
          continue;
        }

        final sherpa_onnx.OfflineStream stream = recognizer!.createStream();
        stream.acceptWaveform(samples: segment.samples, sampleRate: 16000);
        recognizer.decode(stream);
        final sherpa_onnx.OfflineRecognizerResult result = recognizer.getResult(stream);
        stream.free();

        final String text = result.text.trim();
        final double startSec = segment.start / 16000.0;
        final double? fraction = totalDurationSec > 0
            ? (startSec / totalDurationSec).clamp(0.0, 1.0)
            : null;

        if (_looksLikeLyric(text) && text != lastEmittedText) {
          lastEmittedText = text;
          sendPort.send(<String, dynamic>{
            'type': 'line',
            'startMs': (startSec * 1000).round(),
            'text': text,
            'fraction': fraction,
          });
        } else {
          // Still report progress so the UI's percentage keeps moving even
          // through stretches of filtered-out instrumental segments.
          sendPort.send(<String, dynamic>{'type': 'progress', 'fraction': fraction});
        }
      }
    }

    while (offset + windowSize <= samples.length) {
      vad.acceptWaveform(samples.sublist(offset, offset + windowSize));
      offset += windowSize;
      drainSegments();
    }
    vad.flush();
    drainSegments();

    sendPort.send(<String, dynamic>{'type': 'done'});
  } catch (error) {
    sendPort.send(<String, dynamic>{'type': 'error', 'message': error.toString()});
  } finally {
    vad?.free();
    recognizer?.free();
  }
}

/// Rejects empty output and punctuation/symbol-only output (no letters at
/// all) - the two shapes Whisper's instrumental-segment hallucinations
/// almost always take.
bool _looksLikeLyric(String text) {
  if (text.isEmpty) {
    return false;
  }
  return RegExp('[A-Za-z]').hasMatch(text);
}
