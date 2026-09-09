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

class PlayerOptionsSheet {
  static void show(BuildContext context, {required SongModel song}) {
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
                    icon: Icons.playlist_add_rounded,
                    label: 'Add To Playlist',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      PlaylistPicker.show(context, playlistsBloc, song);
                    },
                  ),
                  SheetAction(
                    icon: Icons.info_outline_rounded,
                    label: 'Properties',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showProperties(context, song);
                    },
                  ),
                  SheetAction(
                    icon: Icons.access_time_rounded,
                    label: 'Set Sleep Timer',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showSleepTimer(context, musicBloc);
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

  static String _formatDuration(int? ms) {
    if (ms == null || ms <= 0) {
      return 'Unknown';
    }
    final int totalSeconds = ms ~/ 1000;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String _formatSize(int bytes) {
    if (bytes <= 0) {
      return 'Unknown';
    }
    final double mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  static void _showProperties(BuildContext context, SongModel song) {
    final Map<String, String> rows = <String, String>{
      'Title': song.title,
      'Artist': song.artist ?? 'Unknown',
      'Album': song.album ?? 'Unknown',
      'Duration': _formatDuration(song.duration),
      'Size': _formatSize(song.size),
      'Format': song.fileExtension,
      'Path': song.data,
    };

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceHigh,
          title: Text(
            'Properties',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18.sp),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows.entries.map((MapEntry<String, String> entry) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        entry.value,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
          ],
        );
      },
    );
  }

  static void _showSleepTimer(
    BuildContext context,
    MusicControllerBloc musicBloc,
  ) {
    const List<int> presets = <int>[15, 30, 45, 60];

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          backgroundColor: AppColors.surfaceHigh,
          title: Text(
            'Sleep Timer',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18.sp),
          ),
          children: <Widget>[
            for (final int minutes in presets)
              SimpleDialogOption(
                onPressed: () {
                  musicBloc.add(SetSleepTimer(Duration(minutes: minutes)));
                  Navigator.of(dialogContext).pop();
                },
                child: Text(
                  '$minutes minutes',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.sp,
                  ),
                ),
              ),
            SimpleDialogOption(
              onPressed: () {
                musicBloc.add(SetSleepTimer(null));
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Off',
                style: TextStyle(color: AppColors.accent, fontSize: 15.sp),
              ),
            ),
          ],
        );
      },
    );
  }
}
