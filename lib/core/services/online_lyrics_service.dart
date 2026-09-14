import 'package:dio/dio.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/online_lyrics_candidate.dart';

/// Looks up lyrics on LRCLIB (lrclib.net) - a free, open, no-API-key lyrics
/// database. This is the *only* network access anywhere in the app, and it
/// is entirely opt-in: nothing here is ever called automatically, only from
/// the user tapping "Search Online".
///
/// Deliberately returns every candidate the search turns up rather than
/// guessing at a "best match" - the user picks the one that's actually their
/// song from a list, the same way they'd pick a `.lrc` file off disk. Only
/// the song's own title/artist is sent; no device identifiers, no
/// analytics, nothing else.
class OnlineLyricsService {
  OnlineLyricsService()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

  final Dio _dio;

  static const String _baseUrl = 'https://lrclib.net/api/search';

  Future<List<OnlineLyricsCandidate>> search(SongModel song) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        _baseUrl,
        queryParameters: <String, dynamic>{
          'track_name': song.title,
          if (_knownArtist(song.artist) != null)
            'artist_name': _knownArtist(song.artist),
        },
      );
      final List<dynamic> raw = (response.data as List<dynamic>?) ?? const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(OnlineLyricsCandidate.fromJson)
          .where((OnlineLyricsCandidate c) => c.hasAny || c.instrumental)
          .toList();
    } on DioException catch (e) {
      throw OnlineLyricsException(_messageFor(e));
    }
  }

  /// `null` for empty/missing artist tags and on_audio_query's own
  /// "<unknown>" placeholder - sending that as a literal search term would
  /// only narrow results away from the right song.
  String? _knownArtist(String? artist) {
    final String a = (artist ?? '').trim();
    if (a.isEmpty || a.toLowerCase() == '<unknown>') {
      return null;
    }
    return a;
  }

  String _messageFor(DioException e) {
    const Set<DioExceptionType> connectivityIssues = <DioExceptionType>{
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    };
    return connectivityIssues.contains(e.type)
        ? 'No internet connection.'
        : 'Could not reach the lyrics service.';
  }
}
