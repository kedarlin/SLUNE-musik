part of 'songs_bloc.dart';

class SongsState {}

class MusicControllerInitial extends SongsState {}

class SongsStateData extends SongsState {
  List<SongModel> songs = <SongModel>[];
  List<SongModel> searchSongs = <SongModel>[];
  List<SongModel> favorites = <SongModel>[];

  // NEW: for instant lookup instead of scanning list
  Map<int, SongModel> songById = <int, SongModel>{};
}

class FetchSongsLoading extends SongsState {}

class SearchSongsLoading extends SongsState {}
