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

  final int duration;
  final bool instrumental;
  final String? plainLyrics;
  final String? syncedLyrics;

  bool get hasSynced => (syncedLyrics ?? '').trim().isNotEmpty;
  bool get hasPlain => (plainLyrics ?? '').trim().isNotEmpty;
  bool get hasAny => hasSynced || hasPlain;
}

class OnlineLyricsException implements Exception {
  OnlineLyricsException(this.message);

  final String message;

  @override
  String toString() => message;
}
