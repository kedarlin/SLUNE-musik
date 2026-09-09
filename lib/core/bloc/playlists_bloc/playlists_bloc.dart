import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

import '../../models/playlist_model.dart';

part 'playlists_event.dart';
part 'playlists_state.dart';

class PlaylistsBloc extends Bloc<PlaylistsEvent, PlaylistsState> {
  PlaylistsBloc() : super(PlaylistsInitial()) {
    on<LoadPlaylists>(_loadPlaylists);
    on<CreatePlaylist>(_createPlaylist);
    on<RenamePlaylist>(_renamePlaylist);
    on<DeletePlaylist>(_deletePlaylist);
    on<AddSongToPlaylist>(_addSongToPlaylist);
    on<RemoveSongFromPlaylist>(_removeSongFromPlaylist);
    on<ReorderSongsInPlaylist>(_reorderSongsInPlaylist);
  }

  final PlaylistsStateData stateData = PlaylistsStateData();

  Box<Map<dynamic, dynamic>> get _box =>
      Hive.box<Map<dynamic, dynamic>>('playlists');

  Future<void> _loadPlaylists(
    LoadPlaylists event,
    Emitter<PlaylistsState> emit,
  ) async {
    stateData.playlists = _box.values.map(Playlist.fromMap).toList()
      ..sort((Playlist a, Playlist b) => a.createdAt.compareTo(b.createdAt));

    emit(stateData);
  }

  Future<void> _createPlaylist(
    CreatePlaylist event,
    Emitter<PlaylistsState> emit,
  ) async {
    final String id = DateTime.now().microsecondsSinceEpoch.toString();

    final Playlist playlist = Playlist(
      id: id,
      name: event.name,
      songIds: <int>[if (event.initialSongId != null) event.initialSongId!],
      createdAt: DateTime.now(),
    );

    await _box.put(id, playlist.toMap());

    add(LoadPlaylists());
  }

  Future<void> _renamePlaylist(
    RenamePlaylist event,
    Emitter<PlaylistsState> emit,
  ) async {
    final Map<dynamic, dynamic>? map = _box.get(event.playlistId);

    if (map == null) {
      return;
    }

    final Playlist playlist = Playlist.fromMap(map)..name = event.newName;

    await _box.put(event.playlistId, playlist.toMap());

    add(LoadPlaylists());
  }

  Future<void> _deletePlaylist(
    DeletePlaylist event,
    Emitter<PlaylistsState> emit,
  ) async {
    await _box.delete(event.playlistId);

    add(LoadPlaylists());
  }

  Future<void> _addSongToPlaylist(
    AddSongToPlaylist event,
    Emitter<PlaylistsState> emit,
  ) async {
    final Map<dynamic, dynamic>? map = _box.get(event.playlistId);

    if (map == null) {
      return;
    }

    final Playlist playlist = Playlist.fromMap(map);

    if (!playlist.songIds.contains(event.songId)) {
      playlist.songIds.add(event.songId);
      await _box.put(event.playlistId, playlist.toMap());
    }

    add(LoadPlaylists());
  }

  Future<void> _removeSongFromPlaylist(
    RemoveSongFromPlaylist event,
    Emitter<PlaylistsState> emit,
  ) async {
    final Map<dynamic, dynamic>? map = _box.get(event.playlistId);

    if (map == null) {
      return;
    }

    final Playlist playlist = Playlist.fromMap(map)
      ..songIds.remove(event.songId);

    await _box.put(event.playlistId, playlist.toMap());

    add(LoadPlaylists());
  }

  Future<void> _reorderSongsInPlaylist(
    ReorderSongsInPlaylist event,
    Emitter<PlaylistsState> emit,
  ) async {
    final Map<dynamic, dynamic>? map = _box.get(event.playlistId);

    if (map == null) {
      return;
    }

    final Playlist playlist = Playlist.fromMap(map);

    final int newIndex = event.newIndex > event.oldIndex
        ? event.newIndex - 1
        : event.newIndex;

    final int songId = playlist.songIds.removeAt(event.oldIndex);
    playlist.songIds.insert(newIndex, songId);

    await _box.put(event.playlistId, playlist.toMap());

    add(LoadPlaylists());
  }
}
