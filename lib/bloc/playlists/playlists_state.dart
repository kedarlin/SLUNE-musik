part of 'playlists_bloc.dart';

class PlaylistsState {}

class PlaylistsInitial extends PlaylistsState {}

class PlaylistsLoading extends PlaylistsState {}

class PlaylistsStateData extends PlaylistsState {
  List<Playlist> playlists = <Playlist>[];
}
