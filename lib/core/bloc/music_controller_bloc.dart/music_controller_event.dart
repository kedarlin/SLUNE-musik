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

/// Wraps a PlayerState pushed from PlayerClient's native EventChannel
/// stream - position/duration/isPlaying/currentIndex are all authoritative
/// from Media3, not computed here.
class PlayerStateReceived extends MusicControllerEvent {
  PlayerStateReceived(this.state);
  final PlayerState state;
}

class SeekTo extends MusicControllerEvent {
  SeekTo(this.position);
  final int position;
}

class NextSong extends MusicControllerEvent {}

class PreviousSong extends MusicControllerEvent {}

class ToggleShuffle extends MusicControllerEvent {}

class ChangeRepeatMode extends MusicControllerEvent {}

class LofiPresetChanged extends MusicControllerEvent {
  LofiPresetChanged(this.preset);
  final LofiPreset preset;
}

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

/// Internal-only: dispatched by the sleep timer's own Timer callback, since
/// bloc event handlers cannot emit() from outside an event handler.
class _SleepTimerFired extends MusicControllerEvent {}

/// Internal-only: dispatched once the song library is available, to restore
/// the queue / current track / position the user left the app on (paused).
class _RestoreLastSession extends MusicControllerEvent {}
