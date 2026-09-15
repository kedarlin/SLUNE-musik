enum LyricsSource { tag, lrc, ai, edited, online }

class LyricLine {
  const LyricLine({required this.time, required this.text});

  final Duration time;
  final String text;

  LyricLine copyWith({Duration? time, String? text}) =>
      LyricLine(time: time ?? this.time, text: text ?? this.text);
}

class Lyrics {
  Lyrics({
    required this.lines,
    required this.source,
    required this.updatedAt,
    this.plainText,
  });

  factory Lyrics.plain(String text, LyricsSource source) => Lyrics(
    lines: const <LyricLine>[],
    source: source,
    updatedAt: DateTime.now(),
    plainText: text.trim(),
  );

  factory Lyrics.synced(
    List<LyricLine> lines,
    LyricsSource source, {
    DateTime? updatedAt,
  }) {
    final List<LyricLine> sorted = List<LyricLine>.of(lines)
      ..sort((LyricLine a, LyricLine b) => a.time.compareTo(b.time));
    return Lyrics(
      lines: sorted,
      source: source,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  final List<LyricLine> lines;
  final LyricsSource source;
  final DateTime updatedAt;
  final String? plainText;

  Lyrics withSource(LyricsSource newSource) => Lyrics(
    lines: lines,
    source: newSource,
    updatedAt: DateTime.now(),
    plainText: plainText,
  );

  bool get synced => lines.isNotEmpty;

  bool get isEmpty =>
      lines.isEmpty && (plainText == null || plainText!.trim().isEmpty);

  int activeIndexAt(Duration position) {
    if (lines.isEmpty) {
      return -1;
    }
    int lo = 0;
    int hi = lines.length - 1;
    int result = -1;
    while (lo <= hi) {
      final int mid = (lo + hi) >> 1;
      if (lines[mid].time <= position) {
        result = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return result;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'source': source.name,
    'updatedAt': updatedAt.toIso8601String(),
    'plainText': plainText,
    'lines': lines
        .map(
          (LyricLine l) => <String, dynamic>{
            'ms': l.time.inMilliseconds,
            'text': l.text,
          },
        )
        .toList(),
  };

  static Lyrics? fromJson(Map<dynamic, dynamic> json) {
    final LyricsSource source = LyricsSource.values.firstWhere(
      (LyricsSource s) => s.name == json['source'],
      orElse: () => LyricsSource.edited,
    );
    final DateTime updatedAt =
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now();
    final List<dynamic> rawLines =
        json['lines'] as List<dynamic>? ?? <dynamic>[];
    final List<LyricLine> lines = rawLines
        .map(
          (dynamic e) => LyricLine(
            time: Duration(
              milliseconds: (e as Map<dynamic, dynamic>)['ms'] as int? ?? 0,
            ),
            text: e['text'] as String? ?? '',
          ),
        )
        .toList();

    if (lines.isNotEmpty) {
      return Lyrics.synced(lines, source, updatedAt: updatedAt);
    }
    final String? plain = json['plainText'] as String?;
    if (plain != null && plain.trim().isNotEmpty) {
      return Lyrics(
        lines: const <LyricLine>[],
        source: source,
        updatedAt: updatedAt,
        plainText: plain,
      );
    }
    return null;
  }
}
