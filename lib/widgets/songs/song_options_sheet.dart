import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../bloc/music_controller/music_controller_bloc.dart';
import '../../bloc/playlists/playlists_bloc.dart';
import '../../bloc/songs/songs_bloc.dart';
import '../common/sheet_action.dart';
import '../common/sheet_shell.dart';
import '../playlists/playlist_picker.dart';
import 'rename_song_dialog.dart';
import 'song_sheet_header.dart';

class SongOptionsSheet {
  static void show(
    BuildContext context, {
    required SongModel song,
    required bool isFavorite,
    required VoidCallback onToggleFavorite,
    VoidCallback? onRemoveFromPlaylist,
  }) {
    final PlaylistsBloc playlistsBloc = context.read<PlaylistsBloc>();
    final MusicControllerBloc musicBloc = context.read<MusicControllerBloc>();
    final SongsBloc songsBloc = context.read<SongsBloc>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return SheetShell(
          header: SongSheetHeader(song: song),
          body: SingleChildScrollView(
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 3.2,
              children: <Widget>[
                SheetAction(
                  icon: Icons.playlist_play_rounded,
                  label: 'Play Next',
                  onTap: () {
                    musicBloc.add(PlayNext(song));
                    Navigator.of(sheetContext).pop();
                  },
                ),
                SheetAction(
                  icon: Icons.queue_music_rounded,
                  label: 'Play Later',
                  onTap: () {
                    musicBloc.add(PlayLater(song));
                    Navigator.of(sheetContext).pop();
                  },
                ),
                SheetAction(
                  icon: Icons.playlist_add_rounded,
                  label: 'Add To Playlist',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    PlaylistPicker.show(context, playlistsBloc, song);
                  },
                ),
                SheetAction(
                  icon: Icons.drive_file_rename_outline_rounded,
                  label: 'Rename',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    RenameSongDialog.show(
                      context,
                      song: song,
                      songsBloc: songsBloc,
                    );
                  },
                ),
                SheetAction(
                  icon: isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: isFavorite ? 'Remove from Favourite' : 'Favourite',
                  onTap: () {
                    onToggleFavorite();
                    Navigator.of(sheetContext).pop();
                  },
                ),
                if (onRemoveFromPlaylist != null)
                  SheetAction(
                    icon: Icons.playlist_remove_rounded,
                    label: 'Remove from Playlist',
                    onTap: () {
                      onRemoveFromPlaylist();
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
