import '../models/lyrics.dart';

/// Parses and writes the LRC lyric format.
///
/// Handles the common subset: `[ti:]` / `[ar:]` / `[al:]` / `[offset:]`
/// metadata, `[mm:ss.xx]` (or `.xxx`) line timestamps, multiple timestamps on
/// one line, and plain (untimed) text as a fallback.
class LrcCodec {
  const LrcCodec._();

  static final RegExp _tag = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
  static final RegExp _meta = RegExp(r'^\[(ti|ar|al|by|offset|length):(.*)\]$');

  /// Returns null if [content] has no usable lyric content at all.
  static Lyrics? parse(String content, {LyricsSource source = LyricsSource.lrc}) {
    if (content.trim().isEmpty) {
      return null;
    }

    Duration offset = Duration.zero;
    final List<LyricLine> lines = <LyricLine>[];
    final List<String> plainLines = <String>[];

    for (final String rawLine in content.split(RegExp(r'\r\n|\r|\n'))) {
      final String line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        continue;
      }

      final RegExpMatch? metaMatch = _meta.firstMatch(line.trim());
      if (metaMatch != null) {
        if (metaMatch.group(1) == 'offset') {
          offset = Duration(
            milliseconds: int.tryParse(metaMatch.group(2)!.trim()) ?? 0,
          );
        }
        continue;
      }

      final Iterable<RegExpMatch> stamps = _tag.allMatches(line);
      if (stamps.isEmpty) {
        plainLines.add(line.trim());
        continue;
      }

      final String text = line.replaceAll(_tag, '').trim();
      for (final RegExpMatch stamp in stamps) {
        final int minutes = int.parse(stamp.group(1)!);
        final int seconds = int.parse(stamp.group(2)!);
        final String? fracRaw = stamp.group(3);
        int millis = 0;
        if (fracRaw != null) {
          final String frac = fracRaw.padRight(3, '0').substring(0, 3);
          millis = int.parse(frac);
        }
        final Duration t =
            Duration(minutes: minutes, seconds: seconds, milliseconds: millis) +
            offset;
        lines.add(
          LyricLine(
            time: t.isNegative ? Duration.zero : t,
            text: text,
          ),
        );
      }
    }

    if (lines.isNotEmpty) {
      return Lyrics.synced(lines, source);
    }
    if (plainLines.isNotEmpty) {
      return Lyrics.plain(plainLines.join('\n'), source);
    }
    return null;
  }

  static String serialize(Lyrics lyrics, {String? title, String? artist}) {
    final StringBuffer buffer = StringBuffer();
    if (title != null && title.isNotEmpty) {
      buffer.writeln('[ti:$title]');
    }
    if (artist != null && artist.isNotEmpty) {
      buffer.writeln('[ar:$artist]');
    }
    buffer.writeln('[re:Muxic]');

    if (lyrics.synced) {
      for (final LyricLine line in lyrics.lines) {
        buffer.writeln('${_stamp(line.time)}${line.text}');
      }
    } else if (lyrics.plainText != null) {
      lyrics.plainText!.split('\n').forEach(buffer.writeln);
    }
    return buffer.toString();
  }

  static String _stamp(Duration d) {
    final int totalMs = d.inMilliseconds;
    final int minutes = totalMs ~/ 60000;
    final int seconds = (totalMs % 60000) ~/ 1000;
    final int hundredths = (totalMs % 1000) ~/ 10;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    final String xx = hundredths.toString().padLeft(2, '0');
    return '[$mm:$ss.$xx]';
  }
}
