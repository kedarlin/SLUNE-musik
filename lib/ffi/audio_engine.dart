import 'dart:ffi';

import 'dart:io';

typedef InitializeNative = Uint8 Function();
typedef Initialize = int Function();

typedef PlayNative = Void Function();
typedef Play = void Function();

typedef ReleaseNative = Void Function();
typedef Release = void Function();

typedef PauseNative = Void Function();
typedef Pause = void Function();

class AudioEngine {
  AudioEngine._();

  static final AudioEngine instance = AudioEngine._();

  final DynamicLibrary _lib = Platform.isAndroid
      ? DynamicLibrary.open('libmuxic_engine.so')
      : throw UnsupportedError('Only Android is supported.');

  late final Initialize initialize = _lib
      .lookupFunction<InitializeNative, Initialize>('engine_initialize');

  late final Play play = _lib.lookupFunction<PlayNative, Play>('engine_play');

  late final Pause pause = _lib.lookupFunction<PauseNative, Pause>(
    'engine_pause',
  );

  late final Release release = _lib.lookupFunction<ReleaseNative, Release>(
    'engine_release',
  );
}
