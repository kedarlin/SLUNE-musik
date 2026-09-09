part of 'playlists_bloc.dart';

abstract class PlaylistsEvent {}

class LoadPlaylists extends PlaylistsEvent {}

class CreatePlaylist extends PlaylistsEvent {
  CreatePlaylist(this.name, {this.initialSongId});
  final String name;

  final int? initialSongId;
}

class RenamePlaylist extends PlaylistsEvent {
  RenamePlaylist(this.playlistId, this.newName);
  final String playlistId;
  final String newName;
}

class DeletePlaylist extends PlaylistsEvent {
  DeletePlaylist(this.playlistId);
  final String playlistId;
}

class AddSongToPlaylist extends PlaylistsEvent {
  AddSongToPlaylist(this.playlistId, this.songId);
  final String playlistId;
  final int songId;
}

class RemoveSongFromPlaylist extends PlaylistsEvent {
  RemoveSongFromPlaylist(this.playlistId, this.songId);
  final String playlistId;
  final int songId;
}

class ReorderSongsInPlaylist extends PlaylistsEvent {
  ReorderSongsInPlaylist(this.playlistId, this.oldIndex, this.newIndex);
  final String playlistId;
  final int oldIndex;
  final int newIndex;
}
