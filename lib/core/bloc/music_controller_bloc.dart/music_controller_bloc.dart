import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../service/player_client.dart';
import '../../app_constants/app_enums.dart';
import '../songs_bloc/songs_bloc.dart';

part 'music_controller_event.dart';
part 'music_controller_state.dart';

/// Public event/state surface is unchanged from the native-engine version,
/// so every view file compiles and behaves the same without edits.
///
/// Internally, ExoPlayer (via PlayerClient/PlayerChannel/PlaybackService) now
/// owns the queue, decode, buffering, and playback position - this bloc
/// mirrors that into MusicControllerStateData for the UI rather than
/// computing it by hand. That hand-computed index arithmetic is what caused
/// the previous-track RangeError in the old engine; every queue mutation
/// here forwards to PlayerClient's incremental Media3 calls and then trusts
/// the next PlayerStateReceived event for the authoritative currentIndex,
/// rather than re-deriving it locally.
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
    on<LofiPresetChanged>(_onLofiPresetChanged);
    on<PlayerStateReceived>(_onPlayerStateReceived);
    on<ShuffleAll>(_onShuffleAll);
    on<PlayNext>(_onPlayNext);
    on<PlayLater>(_onPlayLater);
    on<ReorderQueue>(_onReorderQueue);
    on<RemoveFromQueue>(_onRemoveFromQueue);
    on<ClearQueue>(_onClearQueue);
    on<JumpToQueueIndex>(_onJumpToQueueIndex);
    on<SetSleepTimer>(_onSetSleepTimer);
    on<_SleepTimerFired>(_onSleepTimerFired);
    on<_RestoreLastSession>(_onRestoreLastSession);

    _playerStateSubscription = _player.stateStream.listen(
      (PlayerState state) => add(PlayerStateReceived(state)),
    );

    _restoreAudioFxPreferences();
    _scheduleSessionRestore();
  }

  final SongsBloc songsBloc;
  final PlayerClient _player = PlayerClient.instance;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<SongsState>? _songsSubscription;
  Timer? _sleepTimer;
  bool _sessionRestored = false;
  int _lastPersistedPositionMs = 0;

  final MusicControllerStateData stateData = MusicControllerStateData();

  Box<dynamic> get _settingsBox => Hive.box<dynamic>('settings');

  /// Speed / pitch / lofi are sticky across sessions and across tracks - the
  /// user sets a "slowed + lofi" vibe once and it stays until changed.
  void _restoreAudioFxPreferences() {
    stateData.speed =
        (_settingsBox.get('fxSpeed', defaultValue: 1.0) as num).toDouble();
    stateData.pitch =
        (_settingsBox.get('fxPitch', defaultValue: 1.0) as num).toDouble();

    final int lofiIndex = _settingsBox.get('fxLofi', defaultValue: 0) as int;
    stateData.lofiPreset =
        LofiPreset.values[lofiIndex.clamp(0, LofiPreset.values.length - 1)];
  }

  /// Pushes the restored speed/pitch/lofi to the player. Called after a
  /// queue is (re)set, since a fresh ExoPlayer starts at 1.0x / no lofi.
  Future<void> _applyAudioFx() async {
    if (stateData.speed != 1.0) {
      await _player.setSpeed(stateData.speed);
    }
    if (stateData.pitch != 1.0) {
      await _player.setPitch(stateData.pitch);
    }
    if (stateData.lofiPreset != LofiPreset.off) {
      await _player.setLofi(stateData.lofiPreset.wetLevel);
    }
  }

  // --- Last-session persistence -------------------------------------------
  //
  // The last queue (song ids only), current index and position are stored in
  // the Hive settings box so reopening the app restores where the user left
  // off - paused, not auto-playing. Cost is a list of ints plus two ints:
  // a few KB at most for a large library, the same shape as the existing
  // favorites / recently-played data.

  void _scheduleSessionRestore() {
    if (songsBloc.stateData.songs.isNotEmpty) {
      add(_RestoreLastSession());
      return;
    }
    _songsSubscription = songsBloc.stream.listen((_) {
      if (!_sessionRestored && songsBloc.stateData.songs.isNotEmpty) {
        add(_RestoreLastSession());
      }
    });
  }

  Future<void> _onRestoreLastSession(
    _RestoreLastSession event,
    Emitter<MusicControllerState> emit,
  ) async {
    await _songsSubscription?.cancel();
    _songsSubscription = null;

    // Never clobber a session the user has already started this launch.
    if (_sessionRestored || stateData.queue.isNotEmpty) {
      return;
    }
    _sessionRestored = true;

    final List<dynamic> savedIds =
        _settingsBox.get('lastQueueIds', defaultValue: <int>[]) as List<dynamic>;
    if (savedIds.isEmpty) {
      return;
    }

    final Map<int, SongModel> byId = songsBloc.stateData.songById;
    final List<SongModel> restored = savedIds
        .map((dynamic id) => byId[id as int])
        .whereType<SongModel>()
        .toList();
    if (restored.isEmpty) {
      return;
    }

    final int savedIndex = (_settingsBox.get('lastIndex', defaultValue: 0) as int)
        .clamp(0, restored.length - 1);
    final int savedPosition =
        _settingsBox.get('lastPositionMs', defaultValue: 0) as int;

    stateData.queue = restored;
    stateData.index = savedIndex;
    _syncSongAndIndex();

    await _player.setQueue(
      songs: restored,
      startIndex: savedIndex,
      playWhenReady: false,
    );
    await _applyAudioFx();
    if (savedPosition > 0) {
      await _player.seekTo(Duration(milliseconds: savedPosition));
    }

    stateData.isPlaying = false;
    stateData.position = savedPosition;
    _lastPersistedPositionMs = savedPosition;

    emit(MusicQueueChanged());
    emit(stateData);
  }

  /// Fire-and-forget write of the current queue/index/position. Hive applies
  /// it in memory immediately and flushes to disk in the background.
  void _persistSession() {
    if (stateData.queue.isEmpty) {
      _settingsBox
        ..delete('lastQueueIds')
        ..delete('lastIndex')
        ..delete('lastPositionMs');
      _lastPersistedPositionMs = 0;
      return;
    }

    _settingsBox.put(
      'lastQueueIds',
      stateData.queue.map((SongModel s) => s.id).toList(),
    );
    _settingsBox.put('lastIndex', stateData.index);
    _settingsBox.put('lastPositionMs', stateData.position);
    _lastPersistedPositionMs = stateData.position;
  }

  /// Keeps `song`/`index` consistent with `queue` after a local mutation,
  /// as a bounds-safety net for the brief window before the next
  /// PlayerStateReceived event corrects `index` from Media3's own timeline.
  void _syncSongAndIndex() {
    if (stateData.queue.isEmpty) {
      stateData.index = 0;
      stateData.song = null;
      return;
    }

    stateData.index = stateData.index.clamp(0, stateData.queue.length - 1);
    stateData.song = stateData.queue[stateData.index];
  }

  Future<void> _onInit(
    InitAudio event,
    Emitter<MusicControllerState> emit,
  ) async {
    stateData.queue = List<SongModel>.from(event.queue);
    stateData.index = event.index;
    _syncSongAndIndex();

    emit(MusicLoading());

    await _player.setQueue(songs: stateData.queue, startIndex: stateData.index);
    await _applyAudioFx();

    if (stateData.song != null) {
      songsBloc.add(RecordRecentlyPlayed(stateData.song!.id));
    }

    stateData.isPlaying = true;
    stateData.position = 0;
    stateData.duration = 0;

    _persistSession();

    emit(MusicQueueChanged());
    emit(stateData);
  }

  Future<void> _onPlayerStateReceived(
    PlayerStateReceived event,
    Emitter<MusicControllerState> emit,
  ) async {
    final PlayerState playerState = event.state;
    final int previousIndex = stateData.index;

    stateData.position = playerState.position.inMilliseconds;
    stateData.duration = playerState.duration.inMilliseconds;
    stateData.isPlaying = playerState.isPlaying;

    if (stateData.queue.isNotEmpty) {
      stateData.index = playerState.currentIndex.clamp(
        0,
        stateData.queue.length - 1,
      );
      stateData.song = stateData.queue[stateData.index];

      if (stateData.index != previousIndex) {
        songsBloc.add(RecordRecentlyPlayed(stateData.song!.id));
      }
    }

    // Persist on a track change or every ~5s of playback, not every tick.
    if (stateData.queue.isNotEmpty &&
        (stateData.index != previousIndex ||
            (stateData.position - _lastPersistedPositionMs).abs() >= 5000)) {
      _persistSession();
    }

    emit(MusicPositionChanging());
    emit(stateData);
  }

  Future<void> _onPlayPauseToggled(
    PlayPauseToggled event,
    Emitter<MusicControllerState> emit,
  ) async {
    if (stateData.isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }

    stateData.isPlaying = !stateData.isPlaying;
    emit(stateData);
  }

  Future<void> _onSpeedChanged(
    SpeedChanged event,
    Emitter<MusicControllerState> emit,
  ) async {
    emit(MusicSpeedChanging());

    await _player.setSpeed(event.speed);
    stateData.speed = event.speed;
    await _settingsBox.put('fxSpeed', event.speed);
    emit(stateData);
  }

  Future<void> _onPitchChanged(
    PitchChanged event,
    Emitter<MusicControllerState> emit,
  ) async {
    emit(MusicPitchChanging());

    await _player.setPitch(event.pitch);
    stateData.pitch = event.pitch;
    await _settingsBox.put('fxPitch', event.pitch);
    emit(stateData);
  }

  Future<void> _onSeekTo(
    SeekTo event,
    Emitter<MusicControllerState> emit,
  ) async {
    emit(MusicSeekLoading());

    await _player.seekTo(Duration(milliseconds: event.position));
    stateData.position = event.position;
    emit(stateData);
  }

  /// Physically reorders `queue` (rather than using Media3's own
  /// shuffle-order mode) so the Playing Queue sheet keeps showing songs in
  /// actual upcoming-play order, matching the existing view's expectations.
  Future<void> _onToggleShuffle(
    ToggleShuffle event,
    Emitter<MusicControllerState> emit,
  ) async {
    stateData.isShuffle = !stateData.isShuffle;

    final SongModel? current = stateData.song;

    if (stateData.isShuffle) {
      final List<SongModel> songs = List<SongModel>.from(stateData.queue);

      if (current != null) {
        songs.removeWhere((SongModel s) => s.id == current.id);
      }
      songs.shuffle();

      stateData.queue = <SongModel>[if (current != null) current, ...songs];
    } else {
      stateData.queue = List<SongModel>.from(songsBloc.stateData.songs);
    }

    stateData.index = current == null
        ? 0
        : stateData.queue.indexWhere((SongModel s) => s.id == current.id);
    if (stateData.index < 0) {
      stateData.index = 0;
    }

    // Swap the queue around the currently-playing track without restarting
    // it - shuffle only ever reorders the *other* items relative to it.
    await _player.reorderKeepingCurrent(
      songs: stateData.queue,
      currentIndex: stateData.index,
    );

    _persistSession();
    emit(MusicQueueChanged());
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

    // RepeatMode's index matches Media3's REPEAT_MODE_OFF/ONE/ALL directly.
    await _player.setRepeat(stateData.repeatMode.index);
    emit(stateData);
  }

  Future<void> _onLofiPresetChanged(
    LofiPresetChanged event,
    Emitter<MusicControllerState> emit,
  ) async {
    await _player.setLofi(event.preset.wetLevel);
    stateData.lofiPreset = event.preset;
    await _settingsBox.put('fxLofi', event.preset.index);
    emit(stateData);
  }

  /// Media3 handles repeat/shuffle-aware navigation itself (confirmed: an
  /// explicit skip under REPEAT_MODE_ONE moves to the actual next/previous
  /// item rather than replaying the current one - matching standard player
  /// conventions rather than the old hand-rolled special case).
  Future<void> _onNextSong(
    NextSong event,
    Emitter<MusicControllerState> emit,
  ) async {
    await _player.next();
  }

  Future<void> _onPreviousSong(
    PreviousSong event,
    Emitter<MusicControllerState> emit,
  ) async {
    await _player.previous();
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
    await _player.addNext(event.song);

    _persistSession();
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
    await _player.addLater(event.song);

    _persistSession();
    emit(MusicQueueChanged());
    emit(stateData);
  }

  Future<void> _onReorderQueue(
    ReorderQueue event,
    Emitter<MusicControllerState> emit,
  ) async {
    if (event.oldIndex < 0 || event.oldIndex >= stateData.queue.length) {
      return;
    }

    final int newIndex = event.newIndex > event.oldIndex
        ? event.newIndex - 1
        : event.newIndex;

    final SongModel moved = stateData.queue.removeAt(event.oldIndex);
    stateData.queue.insert(newIndex, moved);

    // Non-disruptive: Media3 updates its own currentIndex without
    // interrupting whatever is currently playing.
    await _player.moveItem(event.oldIndex, newIndex);

    _syncSongAndIndex();
    _persistSession();
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

    stateData.queue.removeAt(event.index);
    // If this was the currently-playing item, Media3 advances to the next
    // one itself (per repeat mode) - no manual "what plays now" logic needed.
    await _player.removeItem(event.index);

    if (stateData.queue.isEmpty) {
      add(ClearQueue());
      return;
    }

    _syncSongAndIndex();
    _persistSession();
    emit(MusicQueueChanged());
    emit(stateData);
  }

  Future<void> _onClearQueue(
    ClearQueue event,
    Emitter<MusicControllerState> emit,
  ) async {
    await _player.clearQueue();

    stateData.queue = <SongModel>[];
    stateData.song = null;
    stateData.index = 0;
    stateData.isPlaying = false;
    stateData.position = 0;
    stateData.duration = 0;

    _persistSession();
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

    await _player.jumpTo(event.index);
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

    _sleepTimer = Timer(event.duration!, () => add(_SleepTimerFired()));

    emit(stateData);
  }

  Future<void> _onSleepTimerFired(
    _SleepTimerFired event,
    Emitter<MusicControllerState> emit,
  ) async {
    await _player.pause();
    stateData.isPlaying = false;
    stateData.sleepTimerEndsAt = null;
    emit(stateData);
  }

  @override
  Future<void> close() {
    _persistSession();
    _playerStateSubscription?.cancel();
    _songsSubscription?.cancel();
    _sleepTimer?.cancel();
    return super.close();
  }
}
