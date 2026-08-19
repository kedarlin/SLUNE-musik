import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef InitializeNative = Uint8 Function();
typedef Initialize = int Function();

typedef LoadTrackNative = Uint8 Function(Pointer<Utf8> path);
typedef LoadTrack = int Function(Pointer<Utf8> path);

typedef PlayNative = Void Function();
typedef Play = void Function();

typedef ReleaseNative = Void Function();
typedef Release = void Function();

typedef PauseNative = Void Function();
typedef Pause = void Function();

typedef SeekNative = Uint8 Function(Int64 positionUs);
typedef Seek = int Function(int positionUs);

class AudioEngine {
  AudioEngine._();

  static final AudioEngine instance = AudioEngine._();

  final DynamicLibrary _lib = Platform.isAndroid
      ? DynamicLibrary.open('libmuxic_engine.so')
      : throw UnsupportedError('Only Android is supported.');

  late final Initialize initialize = _lib
      .lookupFunction<InitializeNative, Initialize>('engine_initialize');

  late final LoadTrack _loadTrack = _lib
      .lookupFunction<LoadTrackNative, LoadTrack>('engine_load_track');

  late final Play play = _lib.lookupFunction<PlayNative, Play>('engine_play');

  late final Pause pause = _lib.lookupFunction<PauseNative, Pause>(
    'engine_pause',
  );

  late final Release release = _lib.lookupFunction<ReleaseNative, Release>(
    'engine_release',
  );

  late final Seek _seek = _lib.lookupFunction<SeekNative, Seek>('engine_seek');

  bool seek(Duration position) {
    return _seek(position.inMicroseconds) != 0;
  }

  bool loadTrack(String path) {
    final Pointer<Utf8> nativePath = path.toNativeUtf8();

    try {
      return _loadTrack(nativePath) != 0;
    } finally {
      malloc.free(nativePath);
    }
  }
}
