import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/app_constants/app_enums.dart';
import '../../service/player_client.dart';
import '../songs/songs_bloc.dart';

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
    on<EqEnabledChanged>(_onEqEnabledChanged);
    on<EqPresetSelected>(_onEqPresetSelected);
    on<EqBandChanged>(_onEqBandChanged);
    on<BassBoostChanged>(_onBassBoostChanged);
    on<VirtualizerChanged>(_onVirtualizerChanged);
    on<ReverbPresetChanged>(_onReverbPresetChanged);
    on<EqBandsInitialized>(_onEqBandsInitialized);
    on<PlayerStateReceived>(_onPlayerStateReceived);
    on<ShuffleAll>(_onShuffleAll);
    on<PlayNext>(_onPlayNext);
    on<PlayLater>(_onPlayLater);
    on<ReorderQueue>(_onReorderQueue);
    on<RemoveFromQueue>(_onRemoveFromQueue);
    on<ClearQueue>(_onClearQueue);
    on<JumpToQueueIndex>(_onJumpToQueueIndex);
    on<SetAbLoopPointA>(_onSetAbLoopPointA);
    on<SetAbLoopPointB>(_onSetAbLoopPointB);
    on<ClearAbLoop>(_onClearAbLoop);
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

  void _restoreAudioFxPreferences() {
    stateData.speed = (_settingsBox.get('fxSpeed', defaultValue: 1.0) as num)
        .toDouble();
    stateData.pitch = (_settingsBox.get('fxPitch', defaultValue: 1.0) as num)
        .toDouble();

    stateData.eqEnabled =
        _settingsBox.get('fxEqEnabled', defaultValue: false) as bool;
    stateData.eqPreset =
        _settingsBox.get('fxEqPreset', defaultValue: -1) as int;
    stateData.eqBands =
        (_settingsBox.get('fxEqBands', defaultValue: <int>[]) as List<dynamic>)
            .map((dynamic e) => e as int)
            .toList();
    stateData.customEqBands =
        (_settingsBox.get('fxCustomEqBands', defaultValue: <int>[])
                as List<dynamic>)
            .map((dynamic e) => e as int)
            .toList();
    stateData.bassBoost = _settingsBox.get('fxBass', defaultValue: 0) as int;
    stateData.virtualizer = _settingsBox.get('fxVirt', defaultValue: 0) as int;

    final int reverbIndex =
        _settingsBox.get('fxReverb', defaultValue: 0) as int;
    stateData.reverbPreset = ReverbPreset
        .values[reverbIndex.clamp(0, ReverbPreset.values.length - 1)];
  }

  Future<void> _applyAudioFx() async {
    if (stateData.speed != 1.0) {
      await _player.setSpeed(stateData.speed);
    }
    if (stateData.pitch != 1.0) {
      await _player.setPitch(stateData.pitch);
    }

    if (stateData.eqEnabled) {
      await _player.setEqEnabled(true);
      if (stateData.eqPreset >= 0) {
        await _player.setEqPreset(stateData.eqPreset);
      } else {
        for (int band = 0; band < stateData.eqBands.length; band++) {
          await _player.setEqBand(band, stateData.eqBands[band]);
        }
      }
    }
    if (stateData.bassBoost > 0) {
      await _player.setBassBoost(stateData.bassBoost);
    }
    if (stateData.virtualizer > 0) {
      await _player.setVirtualizer(stateData.virtualizer);
    }
    if (stateData.reverbPreset != ReverbPreset.none) {
      await _player.setReverb(stateData.reverbPreset.index);
    }
  }

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

    if (_sessionRestored || stateData.queue.isNotEmpty) {
      return;
    }
    _sessionRestored = true;

    final List<dynamic> savedIds =
        _settingsBox.get('lastQueueIds', defaultValue: <int>[])
            as List<dynamic>;
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

    final int savedIndex =
        (_settingsBox.get('lastIndex', defaultValue: 0) as int).clamp(
          0,
          restored.length - 1,
        );
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

    if (stateData.index != previousIndex) {
      stateData.abLoopAMs = null;
      stateData.abLoopBMs = null;
    } else if (stateData.hasAbLoop &&
        stateData.position >= stateData.abLoopBMs!) {
      await _player.seekTo(Duration(milliseconds: stateData.abLoopAMs!));
      stateData.position = stateData.abLoopAMs!;
    }

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
    _persistSession();
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

    await _player.setRepeat(stateData.repeatMode.index);
    emit(stateData);
  }

  Future<void> _onEqBandsInitialized(
    EqBandsInitialized event,
    Emitter<MusicControllerState> emit,
  ) async {
    if (stateData.eqBands.length != event.bandCount) {
      final List<int> sized = List<int>.filled(event.bandCount, 0);
      for (
        int i = 0;
        i < event.bandCount && i < stateData.eqBands.length;
        i++
      ) {
        sized[i] = stateData.eqBands[i];
      }
      stateData.eqBands = sized;
    }
    emit(stateData);
  }

  Future<void> _onEqEnabledChanged(
    EqEnabledChanged event,
    Emitter<MusicControllerState> emit,
  ) async {
    stateData.eqEnabled = event.enabled;
    await _player.setEqEnabled(event.enabled);
    if (event.enabled) {
      if (stateData.eqPreset >= 0) {
        await _player.setEqPreset(stateData.eqPreset);
      } else {
        for (int band = 0; band < stateData.eqBands.length; band++) {
          await _player.setEqBand(band, stateData.eqBands[band]);
        }
      }
    }
    await _settingsBox.put('fxEqEnabled', event.enabled);
    emit(stateData);
  }

  Future<void> _onEqPresetSelected(
    EqPresetSelected event,
    Emitter<MusicControllerState> emit,
  ) async {
    stateData.eqPreset = event.preset;
    if (event.bandLevelsMb.isNotEmpty) {
      stateData.eqBands = List<int>.from(event.bandLevelsMb);
    }
    await _settingsBox.put('fxEqPreset', event.preset);
    await _settingsBox.put('fxEqBands', stateData.eqBands);
    emit(stateData);
  }

  Future<void> _onEqBandChanged(
    EqBandChanged event,
    Emitter<MusicControllerState> emit,
  ) async {
    if (event.band < 0) {
      return;
    }
    if (stateData.eqBands.length <= event.band) {
      stateData.eqBands = <int>[
        ...stateData.eqBands,
        ...List<int>.filled(event.band + 1 - stateData.eqBands.length, 0),
      ];
    }
    stateData.eqBands[event.band] = event.levelMb;
    stateData.eqPreset = -1;
    stateData.customEqBands = List<int>.from(stateData.eqBands);
    await _player.setEqBand(event.band, event.levelMb);
    await _settingsBox.put('fxEqPreset', -1);
    await _settingsBox.put('fxEqBands', stateData.eqBands);
    await _settingsBox.put('fxCustomEqBands', stateData.customEqBands);
    emit(stateData);
  }

  Future<void> _onBassBoostChanged(
    BassBoostChanged event,
    Emitter<MusicControllerState> emit,
  ) async {
    stateData.bassBoost = event.strength.clamp(0, 1000);
    await _player.setBassBoost(stateData.bassBoost);
    await _settingsBox.put('fxBass', stateData.bassBoost);
    emit(stateData);
  }

  Future<void> _onVirtualizerChanged(
    VirtualizerChanged event,
    Emitter<MusicControllerState> emit,
  ) async {
    stateData.virtualizer = event.strength.clamp(0, 1000);
    await _player.setVirtualizer(stateData.virtualizer);
    await _settingsBox.put('fxVirt', stateData.virtualizer);
    emit(stateData);
  }

  Future<void> _onReverbPresetChanged(
    ReverbPresetChanged event,
    Emitter<MusicControllerState> emit,
  ) async {
    stateData.reverbPreset = event.preset;
    await _player.setReverb(event.preset.index);
    await _settingsBox.put('fxReverb', event.preset.index);
    emit(stateData);
  }

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
      add(
        InitAudio(song: event.song, index: 0, queue: <SongModel>[event.song]),
      );
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
      add(
        InitAudio(song: event.song, index: 0, queue: <SongModel>[event.song]),
      );
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
    stateData.abLoopAMs = null;
    stateData.abLoopBMs = null;

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

  Future<void> _onSetAbLoopPointA(
    SetAbLoopPointA event,
    Emitter<MusicControllerState> emit,
  ) async {
    stateData.abLoopAMs = stateData.position;
    if (stateData.abLoopBMs != null &&
        stateData.abLoopBMs! <= stateData.abLoopAMs!) {
      stateData.abLoopBMs = null;
    }
    emit(stateData);
  }

  Future<void> _onSetAbLoopPointB(
    SetAbLoopPointB event,
    Emitter<MusicControllerState> emit,
  ) async {
    stateData.abLoopBMs = stateData.position;
    if (stateData.abLoopAMs != null &&
        stateData.abLoopAMs! >= stateData.abLoopBMs!) {
      stateData.abLoopAMs = null;
    }
    emit(stateData);
  }

  Future<void> _onClearAbLoop(
    ClearAbLoop event,
    Emitter<MusicControllerState> emit,
  ) async {
    stateData.abLoopAMs = null;
    stateData.abLoopBMs = null;
    emit(stateData);
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
