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

  // LyricsBloc holds exactly one of these, mutates its fields in place, and
  // calls emit(stateData) with that SAME instance every time (see every
  // handler in lyrics_bloc.dart). bloc's own emit() skips notifying
  // listeners whenever the new state is `==` the state already held -
  // and the default Object `==` is reference/identity equality, so without
  // this override every emit after the very first one is silently dropped:
  // the mutation still happens, but nothing is ever told about it.
  //
  // This is exactly what caused two real bugs: the "Search Online" sheet
  // (its own route, with nothing else forcing it to rebuild) stayed stuck
  // on "Searching online…" until an unrelated drag gesture happened to
  // rebuild it top-down; and the auto-centering scroll in LyricsView, which
  // only runs from BlocConsumer's `listener` (which - unlike `builder` -
  // has no other way to fire) essentially only ever ran once per app
  // session. Overriding `==` to always report "different" makes every
  // emit() call actually notify, which is what this mutate-then-emit
  // pattern needs to behave correctly everywhere it's used.
  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) => false;

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => identityHashCode(this);
}
