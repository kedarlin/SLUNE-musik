/// One search result from the online lyrics lookup (LRCLIB). Purely a data
/// holder - the user picks one of these from a list, nothing is ever
/// auto-selected.
class OnlineLyricsCandidate {
  const OnlineLyricsCandidate({
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.duration,
    required this.instrumental,
    required this.plainLyrics,
    required this.syncedLyrics,
  });

  factory OnlineLyricsCandidate.fromJson(Map<String, dynamic> json) {
    String asString(dynamic v) => (v as String?)?.trim() ?? '';
    return OnlineLyricsCandidate(
      trackName: asString(json['trackName']),
      artistName: asString(json['artistName']),
      albumName: asString(json['albumName']),
      duration: ((json['duration'] as num?) ?? 0).round(),
      instrumental: json['instrumental'] as bool? ?? false,
      plainLyrics: json['plainLyrics'] as String?,
      syncedLyrics: json['syncedLyrics'] as String?,
    );
  }

  final String trackName;
  final String artistName;
  final String albumName;

  /// Seconds.
  final int duration;
  final bool instrumental;
  final String? plainLyrics;
  final String? syncedLyrics;

  bool get hasSynced => (syncedLyrics ?? '').trim().isNotEmpty;
  bool get hasPlain => (plainLyrics ?? '').trim().isNotEmpty;
  bool get hasAny => hasSynced || hasPlain;
}

/// Thrown by [OnlineLyricsService] for anything that isn't a plain "no
/// results" - a dropped connection, a timeout, a bad response. Kept distinct
/// from an empty result list so the UI can tell "you're offline" apart from
/// "this song just isn't in the database".
class OnlineLyricsException implements Exception {
  OnlineLyricsException(this.message);

  final String message;

  @override
  String toString() => message;
}
