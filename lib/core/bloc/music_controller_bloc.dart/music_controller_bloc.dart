import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../service/audio_service.dart';
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
    on<NativePlaybackEvent>(_onNativeEvent);
    _listenToNativePlayer();
  }
  final SongsBloc songsBloc;
  // ignore: unused_field, strict_raw_type, always_specify_types
  StreamSubscription? _nativeSub;

  final MusicControllerStateData stateData = MusicControllerStateData();

  void _listenToNativePlayer() {
    _nativeSub = NativeAudio.events().listen(
      (Map<String, dynamic> data) => add(NativePlaybackEvent(data)),
      // ignore: always_specify_types
      onError: (err, stack) {
        // optional: emit an error state
      },
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

    await NativeAudio.load(
      uri: event.song.data,
      title: event.song.title,
      id: event.song.id.toString(),
      artist: event.song.artist,
    );

    await NativeAudio.speedPitch(stateData.speed, stateData.pitch);

    stateData.isPlaying = true;
    // ensure position/duration reset or fetched by native events
    stateData.position = 0;
    stateData.duration = 0;

    emit(stateData);
  }

  Future<void> _onNativeEvent(
    NativePlaybackEvent event,
    Emitter<MusicControllerState> emit,
  ) async {
    final Map<String, dynamic> data = event.data;

    // Handle commands from notification / BT / headset
    if (data.containsKey('command')) {
      final dynamic cmd = data['command'];
      if (cmd == 'next') {
        add(NextSong());
        return;
      }
      if (cmd == 'previous') {
        add(PreviousSong());
        return;
      }
    }

    // Normal playback updates
    stateData.position = data['position'] as int? ?? 0;
    stateData.duration = data['duration'] as int? ?? 0;
    stateData.isPlaying = data['isPlaying'] as bool? ?? false;

    emit(MusicPositionChanging());
    emit(stateData);

    // Media3 Player STATE_ENDED = 4
    if (data['state'] == 4) {
      emit(MusicEnded());
      add(NextSong());
    }
  }

  Future<void> _onPlayPauseToggled(
    PlayPauseToggled event,
    Emitter<MusicControllerState> emit,
  ) async {
    await NativeAudio.speedPitch(stateData.speed, stateData.pitch);
    if (stateData.isPlaying) {
      await NativeAudio.pause();
    } else {
      await NativeAudio.play();
    }

    stateData.isPlaying = !stateData.isPlaying;
    emit(stateData);
  }

  Future<void> _onSpeedChanged(
    SpeedChanged event,
    Emitter<MusicControllerState> emit,
  ) async {
    emit(MusicSpeedChanging());

    await NativeAudio.speedPitch(event.speed, stateData.pitch);
    stateData.speed = event.speed;
    emit(stateData);
  }

  Future<void> _onPitchChanged(
    PitchChanged event,
    Emitter<MusicControllerState> emit,
  ) async {
    emit(MusicPitchChanging());

    await NativeAudio.speedPitch(stateData.speed, event.pitch);
    stateData.pitch = event.pitch;
    emit(stateData);
  }

  Future<void> _onSeekTo(
    SeekTo event,
    Emitter<MusicControllerState> emit,
  ) async {
    emit(MusicSeekLoading());

    await NativeAudio.seek(event.position);
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
    _nativeSub?.cancel();
    return super.close();
  }
}
