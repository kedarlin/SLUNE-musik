part of 'lyrics_bloc.dart';

abstract class LyricsEvent {}

/// The playing song changed (or stopped). Internal - fired from the
/// MusicControllerBloc subscription.
class LyricsSongChanged extends LyricsEvent {
  LyricsSongChanged(this.song);
  final SongModel? song;
}

/// A playback position tick. Internal.
class LyricsTicked extends LyricsEvent {
  LyricsTicked(this.position);
  final Duration position;
}

class LyricsGenerateRequested extends LyricsEvent {}

class LyricsGenerationCancelled extends LyricsEvent {}

/// User tapped "Search Online". Fetches the candidate list; never picks one
/// automatically.
class LyricsOnlineSearchRequested extends LyricsEvent {}

/// User picked a specific result out of the online candidate list.
class LyricsOnlineCandidateSelected extends LyricsEvent {
  LyricsOnlineCandidateSelected(this.candidate);
  final OnlineLyricsCandidate candidate;
}

/// Persist [lyrics] against [song] (from the editor, or "save draft"). [song]
/// is captured at dispatch time so a track change mid-save can't misfile it.
class LyricsSaveRequested extends LyricsEvent {
  LyricsSaveRequested(this.song, this.lyrics);
  final SongModel song;
  final Lyrics lyrics;
}

class LyricsDeleteRequested extends LyricsEvent {
  LyricsDeleteRequested(this.song);
  final SongModel song;
}

class _LyricsGenerationProgress extends LyricsEvent {
  _LyricsGenerationProgress(this.progress);
  final TranscriptionProgress progress;
}

class _LyricsGenerationDone extends LyricsEvent {
  _LyricsGenerationDone(this.lyrics);
  final Lyrics lyrics;
}

class _LyricsGenerationFailed extends LyricsEvent {
  _LyricsGenerationFailed(this.message);
  final String message;
}
