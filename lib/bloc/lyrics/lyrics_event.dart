part of 'lyrics_bloc.dart';

abstract class LyricsEvent {}

class LyricsSongChanged extends LyricsEvent {
  LyricsSongChanged(this.song);
  final SongModel? song;
}

class LyricsTicked extends LyricsEvent {
  LyricsTicked(this.position);
  final Duration position;
}

class LyricsOffsetAdjusted extends LyricsEvent {
  LyricsOffsetAdjusted(this.deltaMs);
  final int deltaMs;
}

class LyricsOffsetReset extends LyricsEvent {}

class LyricsGenerateRequested extends LyricsEvent {}

class LyricsGenerationCancelled extends LyricsEvent {}

class LyricsOnlineSearchRequested extends LyricsEvent {
  LyricsOnlineSearchRequested({this.query});
  final String? query;
}

class LyricsOnlineCandidateSelected extends LyricsEvent {
  LyricsOnlineCandidateSelected(this.candidate);
  final OnlineLyricsCandidate candidate;
}

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
