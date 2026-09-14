import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../models/lyrics.dart';
import '../../models/online_lyrics_candidate.dart';
import '../../services/lrc_codec.dart';
import '../../services/lyrics_repository.dart';
import '../../services/online_lyrics_service.dart';
import '../../services/transcription_service.dart';
import '../music_controller_bloc.dart/music_controller_bloc.dart';

part 'lyrics_event.dart';
part 'lyrics_state.dart';

/// Owns lyric resolution + the active-line cursor + the "generate" flow.
///
/// It observes [MusicControllerBloc]: on a song change it resolves lyrics
/// (repository → sidecar), and on every position tick it advances the active
/// line. It never drives playback itself.
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
    // Pick up whatever is already playing.
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
  bool _aheadBusy = false;
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
          Duration(milliseconds: _musicBloc.stateData.position),
        ),
      );
    }
  }

  Future<void> _onSongChanged(
    LyricsSongChanged event,
    Emitter<LyricsState> emit,
  ) async {
    await _genSub?.cancel();
    _genSub = null;

    stateData
      ..song = event.song
      ..lyrics = null
      ..activeLine = -1
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

    // A newer song may have started while we were awaiting.
    if (_resolvingForSongId != song.id) {
      return;
    }

    stateData
      ..lyrics = found
      ..status = found == null ? LyricsStatus.absent : LyricsStatus.present
      // AI-sourced or picked-from-online lyrics always need a human look
      // before they're "final" - whether they were just generated live or
      // produced ahead of time in the background (see _maybeGenerateAhead),
      // the first time the user actually sees them they're still a draft.
      ..isDraft =
          found?.source == LyricsSource.ai ||
          found?.source == LyricsSource.online;
    emit(stateData);
    unawaited(_maybeGenerateAhead());
  }

  Future<void> _onTicked(
    LyricsTicked event,
    Emitter<LyricsState> emit,
  ) async {
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
    _genSub = _transcriber.transcribe(song).listen(
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

  Future<void> _onGenerationProgress(
    _LyricsGenerationProgress event,
    Emitter<LyricsState> emit,
  ) async {
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
    stateData
      ..status = stateData.lyrics == null
          ? LyricsStatus.absent
          : LyricsStatus.present
      ..progress = null
      ..phase = '';
    emit(stateData);
  }

  /// Fetches every LRCLIB candidate for the current song - never picks one
  /// automatically, that's the user's call from the picker sheet. Kept
  /// separate from [stateData.status] so the sheet can overlay whatever the
  /// panel is already showing (including an existing AI draft the user
  /// wants to check against an online result).
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
      final List<OnlineLyricsCandidate> results = await _onlineLyrics.search(song);
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

  /// The user tapped one row of the online candidate list. Same draft/save
  /// gate as an AI generation - a metadata match can still be the wrong
  /// version of a song, so it isn't trusted until saved.
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

  /// Generate-ahead: quietly transcribes the *next* queued song in the
  /// background so it's already synced by the time the user reaches it,
  /// instead of making them wait through the whole song first. Deliberately
  /// only one track ahead, one job at a time - running two Whisper isolates
  /// at once isn't worth the battery/CPU cost on a phone. Results are AI
  /// drafts like any other generation - the review/save gate in
  /// [_onSongChanged] still applies the first time the user actually looks.
  Future<void> _maybeGenerateAhead() async {
    if (_aheadBusy || stateData.status == LyricsStatus.generating) {
      return;
    }
    if (!await _transcriber.isReady()) {
      return;
    }

    final List<SongModel> queue = _musicBloc.stateData.queue;
    final int nextIndex = _musicBloc.stateData.index + 1;
    if (nextIndex < 0 || nextIndex >= queue.length) {
      return;
    }

    final SongModel next = queue[nextIndex];
    if (await _repository.has(next)) {
      return;
    }

    _aheadBusy = true;
    try {
      final List<LyricLine> lines = <LyricLine>[];
      await for (final TranscriptionProgress progress in _transcriber.transcribe(next)) {
        if (progress.partialLines.isNotEmpty) {
          lines
            ..clear()
            ..addAll(progress.partialLines);
        }
        // Yield to an interactive generation the user asked for directly -
        // breaking cancels this look-ahead job (its stream's onCancel tears
        // down the isolate/service/temp file).
        if (stateData.status == LyricsStatus.generating) {
          break;
        }
      }
      if (lines.isNotEmpty) {
        await _repository.save(next, Lyrics.synced(lines, LyricsSource.ai));

        // The user may have already reached this exact song while the
        // background job was still running - in which case _onSongChanged
        // resolved it as "absent" before the save above happened. Re-resolve
        // now rather than leaving that view stuck stale.
        if (stateData.song?.id == next.id) {
          add(LyricsSongChanged(next));
        }
      }
    } catch (_) {
      // Best-effort - the user can still hit Generate manually once they
      // reach this song.
    } finally {
      _aheadBusy = false;
    }
  }

  Future<void> _onSaveRequested(
    LyricsSaveRequested event,
    Emitter<LyricsState> emit,
  ) async {
    if (event.lyrics.isEmpty) {
      return;
    }
    // Saving is the "I've reviewed this" action, whether or not the text was
    // actually edited - graduate it out of draft status (AI-generated or
    // picked from the online list) so it doesn't nag again next time this
    // song plays.
    final bool wasDraftSource =
        event.lyrics.source == LyricsSource.ai ||
        event.lyrics.source == LyricsSource.online;
    final Lyrics reviewed = wasDraftSource
        ? event.lyrics.withSource(LyricsSource.edited)
        : event.lyrics;
    await _repository.save(event.song, reviewed);

    // Only touch the live state if we're still on that song.
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
