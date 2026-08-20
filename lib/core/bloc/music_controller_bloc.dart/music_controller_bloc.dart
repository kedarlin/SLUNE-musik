import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../ffi/audio_engine.dart';
import '../../../service/engine_service.dart';
import '../../app_constants/app_enums.dart';
import '../songs_bloc/songs_bloc.dart';

part 'music_controller_event.dart';
part 'music_controller_state.dart';

class MusicControllerBloc
    extends Bloc<MusicControllerEvent, MusicControllerState> {
  MusicControllerBloc(this.songsBloc) : super(MusicControllerInitial()) {
    on<InitAudio>(_onInit);
    on<PlayPauseToggled>(_onPlayPauseToggled);
    on<SpeedChanged>(_onSpeedChanged);
    on<PitchChanged>(_onPitchChanged);
    on<SeekTo>(_onSeekTo);
    on<NextSong>(_onNextSong);
    on<PreviousSong>(_onPreviousSong);
    on<ToggleShuffle>(_onToggleShuffle);
    on<ChangeRepeatMode>(_onChangeRepeatMode);
    on<PositionUpdated>(_onPositionUpdated);
    _startPositionPolling();
  }
  final SongsBloc songsBloc;
  Timer? _positionTimer;

  final AudioEngine _engine = AudioEngine.instance;

  final MusicControllerStateData stateData = MusicControllerStateData();

  void _startPositionPolling() {
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => add(PositionUpdated()),
    );
  }

  Future<void> _onInit(
    InitAudio event,
    Emitter<MusicControllerState> emit,
  ) async {
    // set queue from UI
    stateData.queue = List<SongModel>.from(event.queue);
    stateData.song = event.song;
    stateData.index = event.index;

    emit(MusicLoading());

    await AndroidBridge.initialize();

    _engine.initialize();
    _engine.loadTrack(event.song.data);
    _engine.play();

    stateData.isPlaying = true;
    // position/duration are picked up by the next position poll
    stateData.position = 0;
    stateData.duration = 0;

    emit(stateData);
  }

  Future<void> _onPositionUpdated(
    PositionUpdated event,
    Emitter<MusicControllerState> emit,
  ) async {
    stateData.position = _engine.position.inMilliseconds;
    stateData.duration = _engine.duration.inMilliseconds;
    stateData.isPlaying = _engine.isPlaying;

    emit(MusicPositionChanging());
    emit(stateData);
  }

  Future<void> _onPlayPauseToggled(
    PlayPauseToggled event,
    Emitter<MusicControllerState> emit,
  ) async {
    if (stateData.isPlaying) {
      _engine.pause();
    } else {
      _engine.play();
    }

    stateData.isPlaying = !stateData.isPlaying;
    emit(stateData);
  }

  Future<void> _onSpeedChanged(
    SpeedChanged event,
    Emitter<MusicControllerState> emit,
  ) async {
    emit(MusicSpeedChanging());

    // Native time-stretching isn't implemented yet (roadmap milestone 9);
    // this only updates UI state until the engine supports it.
    stateData.speed = event.speed;
    emit(stateData);
  }

  Future<void> _onPitchChanged(
    PitchChanged event,
    Emitter<MusicControllerState> emit,
  ) async {
    emit(MusicPitchChanging());

    // Native pitch shifting isn't implemented yet (roadmap milestone 10);
    // this only updates UI state until the engine supports it.
    stateData.pitch = event.pitch;
    emit(stateData);
  }

  Future<void> _onSeekTo(
    SeekTo event,
    Emitter<MusicControllerState> emit,
  ) async {
    emit(MusicSeekLoading());

    _engine.seek(Duration(milliseconds: event.position));
    stateData.position = event.position;
    emit(stateData);
  }

  Future<void> _onToggleShuffle(
    ToggleShuffle event,
    Emitter<MusicControllerState> emit,
  ) async {
    stateData.isShuffle = !stateData.isShuffle;

    if (stateData.isShuffle) {
      // Shuffle queue except currently playing song
      final SongModel? current = stateData.song;
      final List<SongModel> songs = List<SongModel>.from(stateData.queue);

      // remove by id
      if (current != null) {
        songs.removeWhere((SongModel s) => s.id == current.id);
      }
      songs.shuffle();

      stateData.queue = <SongModel>[if (current != null) current, ...songs];
      stateData.index = 0;
    } else {
      // Restore original order
      stateData.queue = List<SongModel>.from(songsBloc.stateData.songs);
      stateData.index = stateData.queue.indexWhere(
        (SongModel s) => s.id == stateData.song?.id,
      );
    }

    emit(stateData);
  }

  Future<void> _onChangeRepeatMode(
    ChangeRepeatMode event,
    Emitter<MusicControllerState> emit,
  ) async {
    switch (stateData.repeatMode) {
      case RepeatMode.off:
        stateData.repeatMode = RepeatMode.one;
      case RepeatMode.one:
        stateData.repeatMode = RepeatMode.all;
      case RepeatMode.all:
        stateData.repeatMode = RepeatMode.off;
    }
    emit(stateData);
  }

  Future<void> _onNextSong(
    NextSong event,
    Emitter<MusicControllerState> emit,
  ) async {
    if (stateData.repeatMode == RepeatMode.one) {
      add(
        InitAudio(
          song: stateData.song!,
          index: stateData.index,
          queue: stateData.queue,
        ),
      );
      return;
    }
    final int next = stateData.index + 1;
    if (next >= stateData.queue.length) {
      if (stateData.repeatMode == RepeatMode.all) {
        add(
          InitAudio(
            song: stateData.queue.first,
            index: 0,
            queue: stateData.queue,
          ),
        );
      }
      return;
    }
    add(
      InitAudio(
        song: stateData.queue[next],
        index: next,
        queue: stateData.queue,
      ),
    );
  }

  Future<void> _onPreviousSong(
    PreviousSong event,
    Emitter<MusicControllerState> emit,
  ) async {
    if (stateData.repeatMode == RepeatMode.one) {
      add(
        InitAudio(
          song: stateData.song!,
          index: stateData.index,
          queue: stateData.queue,
        ),
      );
      return;
    }
    final int prev = stateData.index - 1;
    if (prev >= stateData.queue.length) {
      if (stateData.repeatMode == RepeatMode.all) {
        add(
          InitAudio(
            song: stateData.queue.first,
            index: 0,
            queue: stateData.queue,
          ),
        );
      }
      return;
    }
    add(
      InitAudio(
        song: stateData.queue[prev],
        index: prev,
        queue: stateData.queue,
      ),
    );
  }

  @override
  Future<void> close() {
    _positionTimer?.cancel();
    return super.close();
  }
}
