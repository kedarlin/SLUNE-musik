part of 'music_controller_bloc.dart';

class MusicControllerState {}

class MusicControllerInitial extends MusicControllerState {}

class MusicControllerStateData extends MusicControllerState {
  double speed = 1.0;
  double pitch = 1.0;
  int position = 0;
  int duration = 0;
  bool isPlaying = false;

  bool isShuffle = false;
  RepeatMode repeatMode = RepeatMode.off;

  bool eqEnabled = false;
  int eqPreset = -1;
  List<int> eqBands = <int>[];

  List<int> customEqBands = <int>[];
  int bassBoost = 0;
  int virtualizer = 0;
  ReverbPreset reverbPreset = ReverbPreset.none;

  SongModel? song;
  int index = 0;

  List<SongModel> queue = <SongModel>[];

  DateTime? sleepTimerEndsAt;

  int? abLoopAMs;
  int? abLoopBMs;

  bool get hasAbLoop => abLoopAMs != null && abLoopBMs != null;
}

class MusicLoading extends MusicControllerState {}

class MusicPlayPause extends MusicControllerState {}

class MusicSpeedChanging extends MusicControllerState {}

class MusicPitchChanging extends MusicControllerState {}

class MusicSeekLoading extends MusicControllerState {}

class MusicPositionChanging extends MusicControllerState {}

class MusicQueueChanged extends MusicControllerState {}
