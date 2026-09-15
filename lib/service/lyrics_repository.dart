import 'dart:io';

import 'package:hive/hive.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/lyrics.dart';
import 'lrc_codec.dart';

class LyricsRepository {
  LyricsRepository._();

  static final LyricsRepository instance = LyricsRepository._();

  static const String boxName = 'lyrics';

  Box<Map<dynamic, dynamic>> get _box =>
      Hive.box<Map<dynamic, dynamic>>(boxName);

  Directory? _lyricsDir;

  Future<Directory> _dir() async {
    if (_lyricsDir != null) {
      return _lyricsDir!;
    }
    final Directory base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(base.path, 'lyrics'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return _lyricsDir = dir;
  }

  static String contentKey(SongModel song) {
    return _keyFor(
      size: _safeSize(song),
      duration: song.duration ?? 0,
      title: song.title,
    );
  }

  static int _safeSize(SongModel song) {
    try {
      return song.size;
    } catch (_) {
      return 0;
    }
  }

  static String _keyFor({
    required int size,
    required int duration,
    required String title,
  }) => _fnv1a('$size|$duration|${title.trim().toLowerCase()}');

  static String _fnv1a(String input) {
    int hash = 0x811c9dc5;
    const int prime = 0x01000193;
    for (final int codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * prime) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<Lyrics?> load(SongModel song) async {
    final String key = contentKey(song);

    final Map<dynamic, dynamic>? record = _box.get(key);
    if (record != null) {
      final Lyrics? stored = Lyrics.fromJson(record);
      if (stored != null && !stored.isEmpty) {
        return stored;
      }
    }

    final Lyrics? fromAppFile = await _readLrc(
      File(p.join((await _dir()).path, '$key.lrc')),
      LyricsSource.lrc,
    );
    if (fromAppFile != null) {
      return fromAppFile;
    }

    return _readSidecar(song);
  }

  Future<void> save(SongModel song, Lyrics lyrics) async {
    if (lyrics.isEmpty) {
      return;
    }
    final String key = contentKey(song);
    await _box.put(key, lyrics.toJson());

    try {
      final File file = File(p.join((await _dir()).path, '$key.lrc'));
      await file.writeAsString(
        LrcCodec.serialize(lyrics, title: song.title, artist: song.artist),
      );
    } on FileSystemException {}
  }

  Future<void> delete(SongModel song) async {
    final String key = contentKey(song);
    await _box.delete(key);
    try {
      final File file = File(p.join((await _dir()).path, '$key.lrc'));
      if (file.existsSync()) {
        await file.delete();
      }
    } on FileSystemException {}
  }

  Future<void> remapForRename(SongModel oldSong, String newTitle) async {
    final String oldKey = contentKey(oldSong);
    final String newKey = _keyFor(
      size: _safeSize(oldSong),
      duration: oldSong.duration ?? 0,
      title: newTitle,
    );
    if (oldKey == newKey) {
      return;
    }

    final Map<dynamic, dynamic>? record = _box.get(oldKey);
    if (record != null) {
      await _box.put(newKey, record);
      await _box.delete(oldKey);
    }

    try {
      final Directory dir = await _dir();
      final File oldFile = File(p.join(dir.path, '$oldKey.lrc'));
      if (oldFile.existsSync()) {
        await oldFile.rename(p.join(dir.path, '$newKey.lrc'));
      }
    } on FileSystemException {}
  }

  Future<bool> has(SongModel song) async => (await load(song)) != null;

  Future<String> exportForShare(SongModel song, Lyrics lyrics) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String sanitized = song.title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final String fileName = sanitized.isEmpty ? 'lyrics' : sanitized;
    final File file = File(p.join(tempDir.path, '$fileName.lrc'));
    await file.writeAsString(
      LrcCodec.serialize(lyrics, title: song.title, artist: song.artist),
    );
    return file.path;
  }

  Future<Lyrics?> _readLrc(File file, LyricsSource source) async {
    try {
      if (!file.existsSync()) {
        return null;
      }
      return LrcCodec.parse(await file.readAsString(), source: source);
    } on FileSystemException {
      return null;
    }
  }

  Future<Lyrics?> _readSidecar(SongModel song) async {
    try {
      final String path = song.data;
      if (path.isEmpty) {
        return null;
      }
      final String dir = p.dirname(path);
      final String stem = p.basenameWithoutExtension(path);
      for (final String name in <String>['$stem.lrc', '$stem.LRC']) {
        final Lyrics? found = await _readLrc(
          File(p.join(dir, name)),
          LyricsSource.lrc,
        );
        if (found != null) {
          return found;
        }
      }
    } on FileSystemException {}
    return null;
  }
}
