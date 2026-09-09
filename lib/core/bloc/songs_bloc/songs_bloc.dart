import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../app_constants/app_enums.dart';

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

    stateData.sortField =
        SongSortField.values[fieldIndex.clamp(0, SongSortField.values.length - 1)];

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

    final List<SongModel> fetched = await _audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
    );

    stateData.songById = <int, SongModel>{
      for (final SongModel s in fetched) s.id: s,
    };

    _allSongs = fetched;
    _applySortAndFilter();

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
