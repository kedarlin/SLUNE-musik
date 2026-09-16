import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../models/lyrics.dart';
import '../../models/online_lyrics_candidate.dart';
import '../../service/lrc_codec.dart';
import '../../service/lyrics_repository.dart';
import '../../service/online_lyrics_service.dart';
import '../../service/transcription_service.dart';
import '../music_controller/music_controller_bloc.dart';

part 'lyrics_event.dart';
part 'lyrics_state.dart';

class LyricsBloc extends Bloc<LyricsEvent, LyricsState> {
  LyricsBloc(
    this._musicBloc, {
    LyricsRepository? repository,
    TranscriptionService? transcriber,
    OnlineLyricsService? onlineLyrics,
  }) : _repository = repository ?? LyricsRepository.instance,
       _transcriber = transcriber ?? const UnavailableTranscriptionService(),
       _onlineLyrics = onlineLyrics ?? OnlineLyricsService(),
       super(LyricsInitial()) {
    on<LyricsSongChanged>(_onSongChanged);
    on<LyricsTicked>(_onTicked);
    on<LyricsOffsetAdjusted>(_onOffsetAdjusted);
    on<LyricsOffsetReset>(_onOffsetReset);
    on<LyricsGenerateRequested>(_onGenerateRequested);
    on<LyricsGenerationCancelled>(_onGenerationCancelled);
    on<LyricsOnlineSearchRequested>(_onOnlineSearchRequested);
    on<LyricsOnlineCandidateSelected>(_onOnlineCandidateSelected);
    on<LyricsSaveRequested>(_onSaveRequested);
    on<LyricsDeleteRequested>(_onDeleteRequested);
    on<_LyricsGenerationProgress>(_onGenerationProgress);
    on<_LyricsGenerationDone>(_onGenerationDone);
    on<_LyricsGenerationFailed>(_onGenerationFailed);

    _musicSub = _musicBloc.stream.listen(_onMusicState);
    _onMusicState(_musicBloc.state);
  }

  final MusicControllerBloc _musicBloc;
  final LyricsRepository _repository;
  final TranscriptionService _transcriber;
  final OnlineLyricsService _onlineLyrics;

  final LyricsStateData stateData = LyricsStateData();

  StreamSubscription<MusicControllerState>? _musicSub;
  StreamSubscription<TranscriptionProgress>? _genSub;

  int? _resolvingForSongId;

  int? _generatingForSongId;
  int? _lastSeenSongId;

  void _onMusicState(MusicControllerState _) {
    final SongModel? song = _musicBloc.stateData.song;
    if (song?.id != _lastSeenSongId) {
      _lastSeenSongId = song?.id;
      add(LyricsSongChanged(song));
      return;
    }
    if (stateData.status == LyricsStatus.present &&
        (stateData.lyrics?.synced ?? false)) {
      add(
        LyricsTicked(
          Duration(
            milliseconds: _musicBloc.stateData.position + stateData.offsetMs,
          ),
        ),
      );
    }
  }

  Future<void> _onOffsetAdjusted(
    LyricsOffsetAdjusted event,
    Emitter<LyricsState> emit,
  ) async {
    stateData.offsetMs += event.deltaMs;
    final Lyrics? lyrics = stateData.lyrics;
    if (lyrics != null && lyrics.synced) {
      stateData.activeLine = lyrics.activeIndexAt(
        Duration(
          milliseconds: _musicBloc.stateData.position + stateData.offsetMs,
        ),
      );
    }
    emit(stateData);
  }

  Future<void> _onOffsetReset(
    LyricsOffsetReset event,
    Emitter<LyricsState> emit,
  ) async {
    stateData.offsetMs = 0;
    final Lyrics? lyrics = stateData.lyrics;
    if (lyrics != null && lyrics.synced) {
      stateData.activeLine = lyrics.activeIndexAt(
        Duration(milliseconds: _musicBloc.stateData.position),
      );
    }
    emit(stateData);
  }

  Future<void> _onSongChanged(
    LyricsSongChanged event,
    Emitter<LyricsState> emit,
  ) async {
    await _genSub?.cancel();
    _genSub = null;
    _generatingForSongId = null;

    stateData
      ..song = event.song
      ..lyrics = null
      ..activeLine = -1
      ..offsetMs = 0
      ..progress = null
      ..phase = ''
      ..errorMessage = null
      ..isDraft = false;

    if (event.song == null) {
      stateData.status = LyricsStatus.idle;
      emit(stateData);
      return;
    }

    stateData.status = LyricsStatus.loading;
    emit(stateData);

    final SongModel song = event.song!;
    _resolvingForSongId = song.id;

    Lyrics? found;
    try {
      found = await _repository.load(song);
    } catch (_) {
      found = null;
    }

    if (_resolvingForSongId != song.id) {
      return;
    }

    stateData
      ..lyrics = found
      ..status = found == null ? LyricsStatus.absent : LyricsStatus.present
      ..isDraft =
          found?.source == LyricsSource.ai ||
          found?.source == LyricsSource.online;
    emit(stateData);
  }

  Future<void> _onTicked(LyricsTicked event, Emitter<LyricsState> emit) async {
    final Lyrics? lyrics = stateData.lyrics;
    if (lyrics == null || !lyrics.synced) {
      return;
    }
    final int active = lyrics.activeIndexAt(event.position);
    if (active != stateData.activeLine) {
      stateData.activeLine = active;
      emit(stateData);
    }
  }

  Future<void> _onGenerateRequested(
    LyricsGenerateRequested event,
    Emitter<LyricsState> emit,
  ) async {
    final SongModel? song = stateData.song;
    if (song == null || stateData.status == LyricsStatus.generating) {
      return;
    }

    if (!await _transcriber.isReady()) {
      stateData
        ..status = LyricsStatus.failed
        ..errorMessage = await _transcriber.unavailableReason();
      emit(stateData);
      return;
    }

    stateData
      ..status = LyricsStatus.generating
      ..progress = null
      ..phase = 'Starting…'
      ..errorMessage = null
      ..lyrics = null
      ..activeLine = -1;
    emit(stateData);

    await _genSub?.cancel();
    _generatingForSongId = song.id;
    _genSub = _transcriber
        .transcribe(song)
        .listen(
          (TranscriptionProgress p) => add(_LyricsGenerationProgress(p)),
          onError: (Object error) =>
              add(_LyricsGenerationFailed(error.toString())),
          onDone: () {
            final Lyrics? partial = stateData.lyrics;
            if (partial != null && partial.synced) {
              add(_LyricsGenerationDone(partial));
            }
          },
          cancelOnError: true,
        );
  }

  bool _isStaleGeneration() => stateData.song?.id != _generatingForSongId;

  Future<void> _onGenerationProgress(
    _LyricsGenerationProgress event,
    Emitter<LyricsState> emit,
  ) async {
    if (_isStaleGeneration()) {
      return;
    }
    stateData
      ..progress = event.progress.fraction
      ..phase = event.progress.phase;
    if (event.progress.partialLines.isNotEmpty) {
      stateData.lyrics = Lyrics.synced(
        event.progress.partialLines,
        LyricsSource.ai,
      );
    }
    emit(stateData);
  }

  Future<void> _onGenerationDone(
    _LyricsGenerationDone event,
    Emitter<LyricsState> emit,
  ) async {
    await _genSub?.cancel();
    _genSub = null;
    if (_isStaleGeneration()) {
      _generatingForSongId = null;
      return;
    }
    _generatingForSongId = null;
    stateData
      ..lyrics = event.lyrics
      ..status = LyricsStatus.present
      ..isDraft = true
      ..progress = 1.0
      ..phase = 'Done';
    emit(stateData);
  }

  Future<void> _onGenerationFailed(
    _LyricsGenerationFailed event,
    Emitter<LyricsState> emit,
  ) async {
    await _genSub?.cancel();
    _genSub = null;
    if (_isStaleGeneration()) {
      _generatingForSongId = null;
      return;
    }
    _generatingForSongId = null;
    stateData
      ..status = LyricsStatus.failed
      ..errorMessage = event.message;
    emit(stateData);
  }

  Future<void> _onGenerationCancelled(
    LyricsGenerationCancelled event,
    Emitter<LyricsState> emit,
  ) async {
    await _genSub?.cancel();
    _genSub = null;
    _generatingForSongId = null;
    stateData
      ..status = stateData.lyrics == null
          ? LyricsStatus.absent
          : LyricsStatus.present
      ..progress = null
      ..phase = '';
    emit(stateData);
  }

  Future<void> _onOnlineSearchRequested(
    LyricsOnlineSearchRequested event,
    Emitter<LyricsState> emit,
  ) async {
    final SongModel? song = stateData.song;
    if (song == null || stateData.onlineSearching) {
      return;
    }
    stateData
      ..onlineSearching = true
      ..onlineCandidates = null
      ..onlineError = null;
    emit(stateData);

    try {
      final List<OnlineLyricsCandidate> results = await _onlineLyrics.search(
        song,
        manualQuery: event.query,
      );
      stateData
        ..onlineSearching = false
        ..onlineCandidates = results
        ..onlineError = results.isEmpty
            ? 'No lyrics found online for this song.'
            : null;
    } catch (error) {
      stateData
        ..onlineSearching = false
        ..onlineCandidates = null
        ..onlineError = error is OnlineLyricsException
            ? error.message
            : 'Something went wrong.';
    }
    emit(stateData);
  }

  Future<void> _onOnlineCandidateSelected(
    LyricsOnlineCandidateSelected event,
    Emitter<LyricsState> emit,
  ) async {
    if (stateData.song == null) {
      return;
    }
    final OnlineLyricsCandidate candidate = event.candidate;
    final Lyrics? lyrics = candidate.hasSynced
        ? LrcCodec.parse(candidate.syncedLyrics!, source: LyricsSource.online)
        : candidate.hasPlain
        ? Lyrics.plain(candidate.plainLyrics!, LyricsSource.online)
        : null;
    if (lyrics == null) {
      return;
    }

    stateData
      ..lyrics = lyrics
      ..status = LyricsStatus.present
      ..isDraft = true
      ..activeLine = -1
      ..onlineCandidates = null
      ..onlineError = null;
    emit(stateData);
  }

  Future<void> _onSaveRequested(
    LyricsSaveRequested event,
    Emitter<LyricsState> emit,
  ) async {
    if (event.lyrics.isEmpty) {
      return;
    }
    final bool wasDraftSource =
        event.lyrics.source == LyricsSource.ai ||
        event.lyrics.source == LyricsSource.online;
    final Lyrics reviewed = wasDraftSource
        ? event.lyrics.withSource(LyricsSource.edited)
        : event.lyrics;
    await _repository.save(event.song, reviewed);

    if (stateData.song?.id == event.song.id) {
      stateData
        ..lyrics = reviewed
        ..status = LyricsStatus.present
        ..isDraft = false
        ..activeLine = -1;
      emit(stateData);
    }
  }

  Future<void> _onDeleteRequested(
    LyricsDeleteRequested event,
    Emitter<LyricsState> emit,
  ) async {
    await _repository.delete(event.song);
    if (stateData.song?.id == event.song.id) {
      stateData
        ..lyrics = null
        ..status = LyricsStatus.absent
        ..isDraft = false
        ..activeLine = -1;
      emit(stateData);
    }
  }

  @override
  Future<void> close() {
    _musicSub?.cancel();
    _genSub?.cancel();
    return super.close();
  }
}
