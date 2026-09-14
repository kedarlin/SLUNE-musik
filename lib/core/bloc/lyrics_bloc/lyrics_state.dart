part of 'lyrics_bloc.dart';

enum LyricsStatus { idle, loading, present, absent, generating, failed }

class LyricsState {}

class LyricsInitial extends LyricsState {}

class LyricsStateData extends LyricsState {
  LyricsStatus status = LyricsStatus.idle;

  SongModel? song;
  Lyrics? lyrics;

  /// Active line index for [lyrics] (-1 = before the first line / not synced).
  int activeLine = -1;

  /// Generation progress (0..1 or null) + a short phase label.
  double? progress;
  String phase = '';

  String? errorMessage;

  /// True when [lyrics] is an unsaved AI/online draft awaiting the user's OK.
  bool isDraft = false;

  // --- "Search Online" picker (transient - not persisted, independent of
  // [status] so the picker overlays whatever the main panel is already
  // showing rather than replacing it) ---
  bool onlineSearching = false;
  List<OnlineLyricsCandidate>? onlineCandidates;
  String? onlineError;

  bool get hasSyncedLyrics =>
      status == LyricsStatus.present && (lyrics?.synced ?? false);
}
