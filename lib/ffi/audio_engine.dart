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

typedef GetPositionSecondsNative = Double Function();
typedef GetPositionSeconds = double Function();

typedef GetDurationSecondsNative = Double Function();
typedef GetDurationSeconds = double Function();

typedef IsPlayingNative = Uint8 Function();
typedef IsPlaying = int Function();

typedef SetSpeedNative = Uint8 Function(Float speed);
typedef SetSpeed = int Function(double speed);

typedef SetPitchNative = Uint8 Function(Float pitch);
typedef SetPitch = int Function(double pitch);

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

  late final GetPositionSeconds _getPositionSeconds = _lib
      .lookupFunction<GetPositionSecondsNative, GetPositionSeconds>(
        'engine_get_position_seconds',
      );

  late final GetDurationSeconds _getDurationSeconds = _lib
      .lookupFunction<GetDurationSecondsNative, GetDurationSeconds>(
        'engine_get_duration_seconds',
      );

  late final IsPlaying _isPlaying = _lib.lookupFunction<
    IsPlayingNative,
    IsPlaying
  >('engine_is_playing');

  late final SetSpeed _setSpeed = _lib
      .lookupFunction<SetSpeedNative, SetSpeed>('engine_set_speed');

  late final SetPitch _setPitch = _lib
      .lookupFunction<SetPitchNative, SetPitch>('engine_set_pitch');

  /// Pitch-preserving time-stretch, done in-engine via SoundTouch.
  bool setSpeed(double speed) {
    return _setSpeed(speed) != 0;
  }

  /// Pitch shifting, done in-engine via SoundTouch.
  bool setPitch(double pitch) {
    return _setPitch(pitch) != 0;
  }

  bool seek(Duration position) {
    return _seek(position.inMicroseconds) != 0;
  }

  Duration get position =>
      Duration(microseconds: (_getPositionSeconds() * 1000000).round());

  Duration get duration =>
      Duration(microseconds: (_getDurationSeconds() * 1000000).round());

  bool get isPlaying => _isPlaying() != 0;

  bool loadTrack(String path) {
    final Pointer<Utf8> nativePath = path.toNativeUtf8();

    try {
      return _loadTrack(nativePath) != 0;
    } finally {
      malloc.free(nativePath);
    }
  }
}
