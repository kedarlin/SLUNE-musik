import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import '../bloc/playlists_bloc/playlists_bloc.dart';
import '../theme/app_colors.dart';
import 'playlist_picker.dart';
import 'sheet_action.dart';
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

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12.r),
              topRight: Radius.circular(12.r),
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 0.6.sh),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SongSheetHeader(song: song),
                  Divider(color: AppColors.divider, height: 1.h),
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
                  SizedBox(height: 8.h),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
