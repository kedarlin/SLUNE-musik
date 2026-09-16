part of 'songs_bloc.dart';

class SongsState {}

class SongsInitial extends SongsState {}

class SongsStateData extends SongsState {
  List<SongModel> songs = <SongModel>[];
  List<SongModel> searchSongs = <SongModel>[];
  List<SongModel> favorites = <SongModel>[];
  Set<int> favoriteIds = <int>{};

  List<SongModel> recentlyPlayed = <SongModel>[];

  List<AlbumModel> albums = <AlbumModel>[];
  List<ArtistModel> artists = <ArtistModel>[];
  List<FolderModel> folders = <FolderModel>[];

  Map<int, SongModel> songById = <int, SongModel>{};

  SongSortField sortField = SongSortField.date;
  bool sortAscending = false;
  bool hideUnderOneMinute = true;
}

class FetchSongsLoading extends SongsState {}

class SearchSongsLoading extends SongsState {}

class SongsUpdated extends SongsState {}
