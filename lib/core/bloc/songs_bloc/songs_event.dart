part of 'songs_bloc.dart';

abstract class SongsEvent {}

class FetchSongs extends SongsEvent {
  FetchSongs({this.forceFetch = false});
  final bool forceFetch;
}

class SearchSongs extends SongsEvent {
  SearchSongs({required this.searchText});
  final String searchText;
}

class AddToFavorites extends SongsEvent {
  AddToFavorites(this.songId);
  final int songId;
}

class RemoveFromFavorites extends SongsEvent {
  RemoveFromFavorites(this.songId);
  final int songId;
}

class GetAllFavorites extends SongsEvent {}
