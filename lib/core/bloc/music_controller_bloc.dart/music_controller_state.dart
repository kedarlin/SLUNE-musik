part of 'music_controller_bloc.dart';

class MusicControllerState {}

class MusicControllerInitial extends MusicControllerState {}

class MusicControllerStateData extends MusicControllerState {
  double speed = 0.875;
  double pitch = 0.925;
  int position = 0;
  int duration = 0;
  bool isPlaying = false;

  // NEW playback logic
  bool isShuffle = false;
  RepeatMode repeatMode = RepeatMode.off;

  // Current item
  SongModel? song;
  int index = 0;

  // Active queue (normal or shuffled)
  List<SongModel> queue = <SongModel>[];
}

class MusicLoading extends MusicControllerState {}

class MusicPlayPause extends MusicControllerState {}

class MusicSpeedChanging extends MusicControllerState {}

class MusicPitchChanging extends MusicControllerState {}

class MusicSeekLoading extends MusicControllerState {}

class MusicPositionChanging extends MusicControllerState {}

class MusicEnded extends MusicControllerState {}
