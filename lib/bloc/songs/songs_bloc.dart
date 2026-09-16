import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;

import '../../core/app_constants/app_enums.dart';
import '../../models/folder_model.dart';

part 'songs_event.dart';
part 'songs_state.dart';

class SongsBloc extends Bloc<SongsEvent, SongsState> {
  SongsBloc() : super(SongsInitial()) {
    on<FetchSongs>(_fetchSongs);
    on<SearchSongs>(_searchSongs);
    on<AddToFavorites>(_addToFavorites);
    on<RemoveFromFavorites>(_removeFromFavorites);
    on<GetAllFavorites>(_getFavorites);
    on<ApplySongSort>(_applySongSort);
    on<RecordRecentlyPlayed>(_recordRecentlyPlayed);
    _restoreSortPreferences();
  }

  static const int _maxRecentlyPlayed = 50;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  Timer? _positionTimer;

  final SongsStateData stateData = SongsStateData();

  List<SongModel> _allSongs = <SongModel>[];

  Box<dynamic> get _settingsBox => Hive.box<dynamic>('settings');

  void _restoreSortPreferences() {
    final int fieldIndex =
        _settingsBox.get('sortField', defaultValue: SongSortField.date.index)
            as int;

    stateData.sortField = SongSortField
        .values[fieldIndex.clamp(0, SongSortField.values.length - 1)];

    stateData.sortAscending =
        _settingsBox.get('sortAscending', defaultValue: false) as bool;

    stateData.hideUnderOneMinute =
        _settingsBox.get('hideUnderOneMinute', defaultValue: false) as bool;
  }

  void _applySortAndFilter() {
    final List<SongModel> working = _allSongs.where((SongModel s) {
      if (!stateData.hideUnderOneMinute) {
        return true;
      }
      return (s.duration ?? 0) >= 60000;
    }).toList();

    working.sort((SongModel a, SongModel b) {
      int result;

      switch (stateData.sortField) {
        case SongSortField.title:
          result = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case SongSortField.length:
          result = (a.duration ?? 0).compareTo(b.duration ?? 0);
        case SongSortField.date:
          result = (a.dateAdded ?? 0).compareTo(b.dateAdded ?? 0);
        case SongSortField.size:
          result = a.size.compareTo(b.size);
      }

      return stateData.sortAscending ? result : -result;
    });

    stateData.songs = working;
    _computeFolders(working);
  }

  /// on_audio_query has no folder query type, unlike Album/Artist - folders
  /// are derived here by grouping each song's own file path.
  void _computeFolders(List<SongModel> songs) {
    final Map<String, int> counts = <String, int>{};
    for (final SongModel s in songs) {
      final String dir = p.dirname(s.data);
      counts[dir] = (counts[dir] ?? 0) + 1;
    }

    final List<FolderModel> folders =
        counts.entries
            .map(
              (MapEntry<String, int> e) => FolderModel(
                path: e.key,
                name: p.basename(e.key),
                songCount: e.value,
              ),
            )
            .toList()
          ..sort(
            (FolderModel a, FolderModel b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    stateData.folders = folders;
  }

  List<SongModel> songsInFolder(String path) => stateData.songs
      .where((SongModel s) => p.dirname(s.data) == path)
      .toList();

  // --- Hierarchical folder browsing (opt-in, see Settings) ---------------
  //
  // Linear mode (above) flattens every direct-parent directory into one
  // list. Hierarchical mode instead walks the real nested folder tree,
  // starting from the deepest directory every song's path has in common -
  // e.g. if everything lives under /storage/emulated/0/Music/<artist>/<album>,
  // browsing starts at .../Music rather than at the device's storage root.

  /// The starting point for hierarchical browsing, or null if there are no
  /// songs to derive one from.
  String? get folderRoot {
    if (stateData.songs.isEmpty) {
      return null;
    }
    final List<List<String>> allSegments = stateData.songs
        .map((SongModel s) => p.split(p.dirname(s.data)))
        .toList();
    final int minLength = allSegments
        .map((List<String> e) => e.length)
        .reduce((int a, int b) => a < b ? a : b);

    final List<String> common = <String>[];
    for (int i = 0; i < minLength; i++) {
      final String segment = allSegments.first[i];
      if (allSegments.every((List<String> s) => s[i] == segment)) {
        common.add(segment);
      } else {
        break;
      }
    }
    return common.isEmpty ? null : p.joinAll(common);
  }

  /// Segments of [path] below [base], or empty if [path] isn't under [base].
  List<String> _segmentsBelow(String path, String base) {
    if (path == base) {
      return <String>[];
    }
    final String prefix = base.endsWith(p.separator)
        ? base
        : '$base${p.separator}';
    if (!path.startsWith(prefix)) {
      return <String>[];
    }
    return p.split(path.substring(prefix.length));
  }

  /// Immediate subfolders of [path] that contain at least one song
  /// somewhere beneath them (folders with no music are never shown).
  List<FolderModel> subfoldersOf(String path) {
    final Map<String, int> counts = <String, int>{};
    for (final SongModel s in stateData.songs) {
      final String dir = p.dirname(s.data);
      final List<String> segments = _segmentsBelow(dir, path);
      if (segments.isEmpty) {
        continue; // song is directly in `path`, not a subfolder
      }
      final String childPath = p.join(path, segments.first);
      counts[childPath] = (counts[childPath] ?? 0) + 1;
    }

    final List<FolderModel> result =
        counts.entries
            .map(
              (MapEntry<String, int> e) => FolderModel(
                path: e.key,
                name: p.basename(e.key),
                songCount: e.value,
              ),
            )
            .toList()
          ..sort(
            (FolderModel a, FolderModel b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return result;
  }

  Future<void> _applySongSort(
    ApplySongSort event,
    Emitter<SongsState> emit,
  ) async {
    stateData.sortField = event.field;
    stateData.sortAscending = event.ascending;
    stateData.hideUnderOneMinute = event.hideUnderOneMinute;

    await _settingsBox.put('sortField', event.field.index);
    await _settingsBox.put('sortAscending', event.ascending);
    await _settingsBox.put('hideUnderOneMinute', event.hideUnderOneMinute);

    _applySortAndFilter();

    emit(SongsUpdated());
    emit(stateData);
  }

  Future<void> _fetchSongs(FetchSongs event, Emitter<SongsState> emit) async {
    if (stateData.songs.isNotEmpty && !event.forceFetch) {
      return;
    }

    emit(FetchSongsLoading());

    List<SongModel> fetched;
    try {
      fetched = await _audioQuery.querySongs(
        sortType: SongSortType.DATE_ADDED,
        orderType: OrderType.DESC_OR_GREATER,
        uriType: UriType.EXTERNAL,
      );
    } catch (_) {
      emit(stateData);
      return;
    }

    stateData.songById = <int, SongModel>{
      for (final SongModel s in fetched) s.id: s,
    };

    _allSongs = fetched;
    _applySortAndFilter();

    try {
      stateData.albums = await _audioQuery.queryAlbums();
      stateData.artists = await _audioQuery.queryArtists();
    } catch (_) {
      // Non-fatal: the Tracks/Playlists/Favourites tabs work without these.
    }

    emit(stateData);

    add(GetAllFavorites());
  }

  Future<void> _searchSongs(SearchSongs event, Emitter<SongsState> emit) async {
    emit(SearchSongsLoading());

    final String query = event.searchText.trim().toLowerCase();

    if (query.isEmpty) {
      stateData.searchSongs = <SongModel>[];
      return emit(stateData);
    }

    stateData.searchSongs = stateData.songs.where((SongModel s) {
      return s.title.toLowerCase().contains(query) ||
          (s.artist?.toLowerCase().contains(query) ?? false);
    }).toList();

    emit(stateData);
  }

  Future<void> _addToFavorites(
    AddToFavorites event,
    Emitter<SongsState> emit,
  ) async {
    final Box<List<int>> box = Hive.box<List<int>>('favorites');
    final List<int> current = List<int>.from(
      box.get('favoritesList', defaultValue: <int>[])!,
    );
    if (!current.contains(event.songId)) {
      current.add(event.songId);
      await box.put('favoritesList', current);
    }
    add(GetAllFavorites());
  }

  Future<void> _removeFromFavorites(
    RemoveFromFavorites event,
    Emitter<SongsState> emit,
  ) async {
    final Box<List<int>> box = Hive.box<List<int>>('favorites');
    final List<int> current = List<int>.from(
      box.get('favoritesList', defaultValue: <int>[])!,
    );
    if (current.contains(event.songId)) {
      current.remove(event.songId);
      await box.put('favoritesList', current);
    }
    add(GetAllFavorites());
  }

  List<int> get _recentlyPlayedIds => List<int>.from(
    _settingsBox.get('recentlyPlayed', defaultValue: <int>[]) as List<dynamic>,
  );

  void _rebuildRecentlyPlayed() {
    stateData.recentlyPlayed = _recentlyPlayedIds
        .map((int id) => stateData.songById[id])
        .whereType<SongModel>()
        .toList();
  }

  Future<void> _recordRecentlyPlayed(
    RecordRecentlyPlayed event,
    Emitter<SongsState> emit,
  ) async {
    final List<int> ids = _recentlyPlayedIds
      ..remove(event.songId)
      ..insert(0, event.songId);

    if (ids.length > _maxRecentlyPlayed) {
      ids.removeRange(_maxRecentlyPlayed, ids.length);
    }

    await _settingsBox.put('recentlyPlayed', ids);

    _rebuildRecentlyPlayed();

    emit(SongsUpdated());
    emit(stateData);
  }

  Future<void> _getFavorites(
    GetAllFavorites event,
    Emitter<SongsState> emit,
  ) async {
    final Box<List<int>> box = Hive.box<List<int>>('favorites');
    final List<int> ids = box.get('favoritesList', defaultValue: <int>[])!;

    stateData.favorites = ids
        .map((int id) => stateData.songById[id])
        .where((SongModel? s) => s != null)
        .cast<SongModel>()
        .toList();
    stateData.favoriteIds = ids.toSet();

    _rebuildRecentlyPlayed();

    emit(SongsUpdated());
    emit(stateData);
  }

  @override
  Future<void> close() {
    _positionTimer?.cancel();
    return super.close();
  }
}
