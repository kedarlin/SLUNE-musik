import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../core/bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import '../ffi/audio_engine.dart';

class MuxicAudioHandler extends BaseAudioHandler with SeekHandler {
  MuxicAudioHandler(this._bloc);

  final MusicControllerBloc _bloc;
  final AudioEngine _engine = AudioEngine.instance;

  static const double _duckVolume = 0.3;

  bool _pausedByInterruption = false;

  Future<void> configureSession() async {
    final AudioSession session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    session.interruptionEventStream.listen((AudioInterruptionEvent event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _engine.setVolume(_duckVolume);
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (_bloc.stateData.isPlaying) {
              _pausedByInterruption = true;
              _bloc.add(PlayPauseToggled());
            }
        }
        return;
      }

      switch (event.type) {
        case AudioInterruptionType.duck:
          _engine.setVolume(1.0);
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          if (_pausedByInterruption && !_bloc.stateData.isPlaying) {
            _bloc.add(PlayPauseToggled());
          }
          _pausedByInterruption = false;
      }
    });

    session.becomingNoisyEventStream.listen((_) {
      if (_bloc.stateData.isPlaying) {
        _bloc.add(PlayPauseToggled());
      }
    });
  }

  void setCurrentSong(SongModel song, Duration duration) {
    mediaItem.add(
      MediaItem(
        id: song.id.toString(),
        title: song.title,
        artist: song.artist ?? 'Unknown Artist',
        album: song.album,
        duration: duration,
        artUri: song.albumId == null
            ? null
            : Uri.parse(
                'content://media/external/audio/albumart/${song.albumId}',
              ),
      ),
    );
  }

  void setPlaybackState({
    required bool isPlaying,
    required Duration position,
    required bool hasNext,
    required bool hasPrevious,
  }) {
    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: isPlaying,
        updatePosition: position,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (!_bloc.stateData.isPlaying) {
      _bloc.add(PlayPauseToggled());
    }
  }

  @override
  Future<void> pause() async {
    if (_bloc.stateData.isPlaying) {
      _bloc.add(PlayPauseToggled());
    }
  }

  @override
  Future<void> seek(Duration position) async {
    _bloc.add(SeekTo(position.inMilliseconds));
  }

  @override
  Future<void> skipToNext() async {
    _bloc.add(NextSong());
  }

  @override
  Future<void> skipToPrevious() async {
    _bloc.add(PreviousSong());
  }

  @override
  Future<void> stop() async {
    if (_bloc.stateData.isPlaying) {
      _bloc.add(PlayPauseToggled());
    }

    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );

    await super.stop();
  }
}
