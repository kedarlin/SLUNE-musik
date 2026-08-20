import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:on_audio_query/on_audio_query.dart';

part 'songs_event.dart';
part 'songs_state.dart';

class SongsBloc extends Bloc<SongsEvent, SongsState> {
  SongsBloc() : super(MusicControllerInitial()) {
    on<FetchSongs>(_fetchSongs);
    on<SearchSongs>(_searchSongs);
    on<AddToFavorites>(_addToFavorites);
    on<RemoveFromFavorites>(_removeFromFavorites);
    on<GetAllFavorites>(_getFavorites);
  }
  final OnAudioQuery _audioQuery = OnAudioQuery();
  Timer? _positionTimer;

  final SongsStateData stateData = SongsStateData();

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

    // Build fast lookup map
    stateData.songById = <int, SongModel>{
      for (final SongModel s in fetched) s.id: s,
    };

    // Cache songs
    stateData.songs = fetched;

    emit(stateData);
  }

  Future<void> _searchSongs(SearchSongs event, Emitter<SongsState> emit) async {
    emit(SearchSongsLoading());

    final String query = event.searchText.trim().toLowerCase();

    if (query.isEmpty) {
      // Empty search → show nothing or entire list based on your UI logic
      stateData.searchSongs = <SongModel>[];
      return emit(stateData);
    }

    // Filter on cached list
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

    emit(stateData);
  }

  @override
  Future<void> close() {
    _positionTimer?.cancel();
    return super.close();
  }
}
