part of 'lyrics_bloc.dart';

enum LyricsStatus { idle, loading, present, absent, generating, failed }

class LyricsState {}

class LyricsInitial extends LyricsState {}

class LyricsStateData extends LyricsState {
  LyricsStatus status = LyricsStatus.idle;

  SongModel? song;
  Lyrics? lyrics;

  int activeLine = -1;

  double? progress;
  String phase = '';

  String? errorMessage;

  bool isDraft = false;

  bool onlineSearching = false;
  List<OnlineLyricsCandidate>? onlineCandidates;
  String? onlineError;

  bool get hasSyncedLyrics =>
      status == LyricsStatus.present && (lyrics?.synced ?? false);

  @override
  bool operator ==(Object other) => false;

  @override
  int get hashCode => identityHashCode(this);
}
