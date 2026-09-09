import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../ffi/audio_engine.dart';
import '../../../service/engine_service.dart';
import '../../../service/muxic_audio_handler.dart';
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
    on<ShuffleAll>(_onShuffleAll);
    on<PlayNext>(_onPlayNext);
    on<PlayLater>(_onPlayLater);
    on<ReorderQueue>(_onReorderQueue);
    on<RemoveFromQueue>(_onRemoveFromQueue);
    on<ClearQueue>(_onClearQueue);
    on<JumpToQueueIndex>(_onJumpToQueueIndex);
    on<SetSleepTimer>(_onSetSleepTimer);
    _startPositionPolling();
  }
  final SongsBloc songsBloc;
  Timer? _positionTimer;
  Timer? _sleepTimer;

  MuxicAudioHandler? audioHandler;

  bool _autoAdvancePending = false;

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
    stateData.queue = List<SongModel>.from(event.queue);
    stateData.song = event.song;
    stateData.index = event.index;

    emit(MusicLoading());

    await AndroidBridge.initialize();

    _engine.initialize();
    _engine.loadTrack(event.song.data);
    _engine.play();

    _autoAdvancePending = false;

    songsBloc.add(RecordRecentlyPlayed(event.song.id));

    audioHandler?.setCurrentSong(
      event.song,
      Duration(milliseconds: event.song.duration ?? 0),
    );

    stateData.isPlaying = true;
    stateData.position = 0;
    stateData.duration = 0;

    emit(MusicQueueChanged());
    emit(stateData);
  }

  Future<void> _onPositionUpdated(
    PositionUpdated event,
    Emitter<MusicControllerState> emit,
  ) async {
    stateData.position = _engine.position.inMilliseconds;
    stateData.duration = _engine.duration.inMilliseconds;
    stateData.isPlaying = _engine.isPlaying;

    if (stateData.song != null) {
      audioHandler?.setPlaybackState(
        isPlaying: stateData.isPlaying,
        position: Duration(milliseconds: stateData.position),
        hasNext: stateData.index < stateData.queue.length - 1,
        hasPrevious: stateData.index > 0,
      );
    }

    emit(MusicPositionChanging());
    emit(stateData);

    if (_engine.hasEnded && !_autoAdvancePending) {
      _autoAdvancePending = true;
      add(NextSong());
    }
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

    _engine.setSpeed(event.speed);
    stateData.speed = event.speed;
    emit(stateData);
  }

  Future<void> _onPitchChanged(
    PitchChanged event,
    Emitter<MusicControllerState> emit,
  ) async {
    emit(MusicPitchChanging());

    _engine.setPitch(event.pitch);
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
      final SongModel? current = stateData.song;
      final List<SongModel> songs = List<SongModel>.from(stateData.queue);

      if (current != null) {
        songs.removeWhere((SongModel s) => s.id == current.id);
      }
      songs.shuffle();

      stateData.queue = <SongModel>[if (current != null) current, ...songs];
      stateData.index = 0;
    } else {
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
    if (prev < 0) {
      if (stateData.repeatMode == RepeatMode.all &&
          stateData.queue.isNotEmpty) {
        add(
          InitAudio(
            song: stateData.queue.last,
            index: stateData.queue.length - 1,
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

  Future<void> _onShuffleAll(
    ShuffleAll event,
    Emitter<MusicControllerState> emit,
  ) async {
    if (event.songs.isEmpty) {
      return;
    }

    final List<SongModel> shuffled = List<SongModel>.from(event.songs)
      ..shuffle();

    stateData.isShuffle = true;

    add(InitAudio(song: shuffled.first, index: 0, queue: shuffled));
  }

  Future<void> _onPlayNext(
    PlayNext event,
    Emitter<MusicControllerState> emit,
  ) async {
    if (stateData.queue.isEmpty) {
      add(InitAudio(song: event.song, index: 0, queue: <SongModel>[event.song]));
      return;
    }

    final int insertAt = (stateData.index + 1).clamp(0, stateData.queue.length);
    stateData.queue.insert(insertAt, event.song);

    emit(MusicQueueChanged());
    emit(stateData);
  }

  Future<void> _onPlayLater(
    PlayLater event,
    Emitter<MusicControllerState> emit,
  ) async {
    if (stateData.queue.isEmpty) {
      add(InitAudio(song: event.song, index: 0, queue: <SongModel>[event.song]));
      return;
    }

    stateData.queue.add(event.song);

    emit(MusicQueueChanged());
    emit(stateData);
  }

  Future<void> _onReorderQueue(
    ReorderQueue event,
    Emitter<MusicControllerState> emit,
  ) async {
    final int newIndex = event.newIndex > event.oldIndex
        ? event.newIndex - 1
        : event.newIndex;

    if (event.oldIndex < 0 || event.oldIndex >= stateData.queue.length) {
      return;
    }

    final SongModel moved = stateData.queue.removeAt(event.oldIndex);
    stateData.queue.insert(newIndex, moved);

    if (event.oldIndex == stateData.index) {
      stateData.index = newIndex;
    } else if (event.oldIndex < stateData.index &&
        newIndex >= stateData.index) {
      stateData.index -= 1;
    } else if (event.oldIndex > stateData.index &&
        newIndex <= stateData.index) {
      stateData.index += 1;
    }

    emit(MusicQueueChanged());
    emit(stateData);
  }

  Future<void> _onRemoveFromQueue(
    RemoveFromQueue event,
    Emitter<MusicControllerState> emit,
  ) async {
    if (event.index < 0 || event.index >= stateData.queue.length) {
      return;
    }

    final bool removingCurrent = event.index == stateData.index;

    stateData.queue.removeAt(event.index);

    if (stateData.queue.isEmpty) {
      add(ClearQueue());
      return;
    }

    if (removingCurrent) {
      final int nextIndex = event.index.clamp(0, stateData.queue.length - 1);
      add(
        InitAudio(
          song: stateData.queue[nextIndex],
          index: nextIndex,
          queue: stateData.queue,
        ),
      );
      return;
    }

    if (event.index < stateData.index) {
      stateData.index -= 1;
    }

    emit(MusicQueueChanged());
    emit(stateData);
  }

  Future<void> _onClearQueue(
    ClearQueue event,
    Emitter<MusicControllerState> emit,
  ) async {
    _engine.pause();

    stateData.queue = <SongModel>[];
    stateData.song = null;
    stateData.index = 0;
    stateData.isPlaying = false;
    stateData.position = 0;
    stateData.duration = 0;

    emit(MusicQueueChanged());
    emit(stateData);
  }

  Future<void> _onJumpToQueueIndex(
    JumpToQueueIndex event,
    Emitter<MusicControllerState> emit,
  ) async {
    if (event.index < 0 || event.index >= stateData.queue.length) {
      return;
    }

    add(
      InitAudio(
        song: stateData.queue[event.index],
        index: event.index,
        queue: stateData.queue,
      ),
    );
  }

  Future<void> _onSetSleepTimer(
    SetSleepTimer event,
    Emitter<MusicControllerState> emit,
  ) async {
    _sleepTimer?.cancel();

    if (event.duration == null) {
      _sleepTimer = null;
      stateData.sleepTimerEndsAt = null;
      emit(stateData);
      return;
    }

    stateData.sleepTimerEndsAt = DateTime.now().add(event.duration!);

    _sleepTimer = Timer(event.duration!, () {
      _engine.pause();
      stateData.isPlaying = false;
      stateData.sleepTimerEndsAt = null;
      add(PositionUpdated());
    });

    emit(stateData);
  }

  @override
  Future<void> close() {
    _positionTimer?.cancel();
    _sleepTimer?.cancel();
    return super.close();
  }
}
