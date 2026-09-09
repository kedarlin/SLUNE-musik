import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/playlists_bloc/playlists_bloc.dart';
import '../models/playlist_model.dart';
import '../theme/app_colors.dart';
import 'create_playlist_sheet.dart';
import 'playlist_thumbnail.dart';

class PlaylistPicker {
  static void show(
    BuildContext context,
    PlaylistsBloc playlistsBloc,
    SongModel song,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (BuildContext sheetContext) {
        return BlocBuilder<PlaylistsBloc, PlaylistsState>(
          bloc: playlistsBloc,
          builder: (BuildContext blocContext, PlaylistsState state) {
            final List<Playlist> playlists = playlistsBloc.stateData.playlists;

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 0.6.sh),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 8.h),
                    child: Text(
                      'Add To Playlist',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.only(bottom: 12.h),
                      children: <Widget>[
                        ListTile(
                          leading: Container(
                            width: 48.w,
                            height: 48.w,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Icon(
                              Icons.playlist_add_rounded,
                              size: 24.sp,
                              color: AppColors.accent,
                            ),
                          ),
                          title: Text(
                            'Create New Playlist',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15.sp,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                          ),
                          onTap: () async {
                            Navigator.of(sheetContext).pop();

                            final String? name =
                                await CreatePlaylistSheet.show(context);

                            if (name != null && name.isNotEmpty) {
                              playlistsBloc.add(
                                CreatePlaylist(name, initialSongId: song.id),
                              );
                            }
                          },
                        ),
                        for (final Playlist playlist in playlists)
                          ListTile(
                            leading: PlaylistThumbnail.user(size: 48.w),
                            title: Text(
                              playlist.name,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15.sp,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            subtitle: Text(
                              '${playlist.songIds.length} Song'
                              '${playlist.songIds.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13.sp,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                            ),
                            onTap: () {
                              playlistsBloc.add(
                                AddSongToPlaylist(playlist.id, song.id),
                              );
                              Navigator.of(sheetContext).pop();
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
