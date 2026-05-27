part of 'music_controller_bloc.dart';

abstract class MusicControllerEvent {}

class InitAudio extends MusicControllerEvent {
  InitAudio({required this.song, required this.index, required this.queue});

  final SongModel song;
  final int index;
  final List<SongModel> queue;
}

class PlayPauseToggled extends MusicControllerEvent {}

class SpeedChanged extends MusicControllerEvent {
  SpeedChanged(this.speed);
  final double speed;
}

class PitchChanged extends MusicControllerEvent {
  PitchChanged(this.pitch);
  final double pitch;
}

class PositionUpdated extends MusicControllerEvent {}

class SeekTo extends MusicControllerEvent {
  SeekTo(this.position);
  final int position;
}

class NextSong extends MusicControllerEvent {}

class PreviousSong extends MusicControllerEvent {}

class ToggleShuffle extends MusicControllerEvent {}

class ChangeRepeatMode extends MusicControllerEvent {}

class NativePlaybackEvent extends MusicControllerEvent {
  NativePlaybackEvent(this.data);
  final Map<String, dynamic> data;
}
