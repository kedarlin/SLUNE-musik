part of 'playlists_bloc.dart';

abstract class PlaylistsEvent {}

class LoadPlaylists extends PlaylistsEvent {
  LoadPlaylists({this.force = false});

  /// When false, a load is skipped if playlists are already in memory - so
  /// re-entering the Playlists tab doesn't re-read Hive. CRUD handlers pass
  /// true to refresh after a change.
  final bool force;
}

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
