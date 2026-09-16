import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../bloc/playlists/playlists_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../models/playlist_model.dart';
import '../common/sheet_shell.dart';
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
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return BlocBuilder<PlaylistsBloc, PlaylistsState>(
          bloc: playlistsBloc,
          builder: (BuildContext blocContext, PlaylistsState state) {
            final List<Playlist> playlists = playlistsBloc.stateData.playlists;

            return SheetShell(
              header: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Add to playlist',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      '${song.title} · ${song.artist ?? 'Unknown Artist'}',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              body: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.only(bottom: 12.h),
                children: <Widget>[
                  InkWell(
                    onTap: () async {
                      Navigator.of(sheetContext).pop();

                      final String? name = await CreatePlaylistSheet.show(
                        context,
                      );

                      if (name != null && name.isNotEmpty) {
                        playlistsBloc.add(
                          CreatePlaylist(name, initialSongId: song.id),
                        );
                      }
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 8.h,
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 52.w,
                            height: 52.w,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              border: Border.all(color: AppColors.accent),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 22.sp,
                              color: AppColors.accent,
                            ),
                          ),
                          SizedBox(width: 13.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'New playlist',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 15.5.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Starts with this track',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    color: AppColors.divider,
                    height: 1.h,
                    thickness: 1,
                    indent: 20.w,
                    endIndent: 20.w,
                  ),
                  for (final Playlist playlist in playlists)
                    _PlaylistRow(
                      playlist: playlist,
                      inPlaylist: playlist.songIds.contains(song.id),
                      onToggle: (bool inPlaylist) {
                        playlistsBloc.add(
                          inPlaylist
                              ? RemoveSongFromPlaylist(playlist.id, song.id)
                              : AddSongToPlaylist(playlist.id, song.id),
                        );
                      },
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

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.playlist,
    required this.inPlaylist,
    required this.onToggle,
  });

  final Playlist playlist;
  final bool inPlaylist;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onToggle(inPlaylist),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        child: Row(
          children: <Widget>[
            PlaylistThumbnail.user(size: 52.w),
            SizedBox(width: 13.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    playlist.name,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    '${playlist.songIds.length} track'
                    '${playlist.songIds.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 26.w,
              height: 26.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: inPlaylist ? AppColors.accent : Colors.transparent,
                border: inPlaylist
                    ? null
                    : Border.all(color: AppColors.disabled),
                shape: BoxShape.circle,
              ),
              child: inPlaylist
                  ? Icon(Icons.check_rounded, size: 14.sp, color: Colors.white)
                  : Icon(
                      Icons.add_rounded,
                      size: 13.sp,
                      color: AppColors.textSecondary,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
