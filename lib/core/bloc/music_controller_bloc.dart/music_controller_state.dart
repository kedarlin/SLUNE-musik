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

  // --- audiofx panel ---
  bool eqEnabled = false;
  int eqPreset = -1; // -1 = custom
  List<int> eqBands = <int>[]; // millibels per band; length == caps.bandCount
  int bassBoost = 0; // 0..1000
  int virtualizer = 0; // 0..1000
  ReverbPreset reverbPreset = ReverbPreset.none;

  SongModel? song;
  int index = 0;

  List<SongModel> queue = <SongModel>[];

  DateTime? sleepTimerEndsAt;

  // --- A-B repeat ---
  // Ephemeral (never persisted, never survives a track change) - a practice
  // tool for looping a section of the *current* song, not a saved setting.
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
