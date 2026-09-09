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

class ShuffleAll extends MusicControllerEvent {
  ShuffleAll(this.songs);
  final List<SongModel> songs;
}

class PlayNext extends MusicControllerEvent {
  PlayNext(this.song);
  final SongModel song;
}

class PlayLater extends MusicControllerEvent {
  PlayLater(this.song);
  final SongModel song;
}

class ReorderQueue extends MusicControllerEvent {
  ReorderQueue(this.oldIndex, this.newIndex);
  final int oldIndex;
  final int newIndex;
}

class RemoveFromQueue extends MusicControllerEvent {
  RemoveFromQueue(this.index);
  final int index;
}

class ClearQueue extends MusicControllerEvent {}

class JumpToQueueIndex extends MusicControllerEvent {
  JumpToQueueIndex(this.index);
  final int index;
}

class SetSleepTimer extends MusicControllerEvent {
  SetSleepTimer(this.duration);
  final Duration? duration;
}
