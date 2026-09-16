import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../bloc/music_controller/music_controller_bloc.dart';
import '../../bloc/playlists/playlists_bloc.dart';
import '../../bloc/songs/songs_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../view/equalizer_sheet.dart';
import '../common/sheet_action.dart';
import '../common/sheet_shell.dart';
import '../playlists/playlist_picker.dart';
import '../songs/rename_song_dialog.dart';
import '../songs/song_sheet_header.dart';

class PlayerOptionsSheet {
  static void show(BuildContext context, {required SongModel song}) {
    final PlaylistsBloc playlistsBloc = context.read<PlaylistsBloc>();
    final MusicControllerBloc musicBloc = context.read<MusicControllerBloc>();
    final SongsBloc songsBloc = context.read<SongsBloc>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return BlocBuilder<SongsBloc, SongsState>(
          bloc: songsBloc,
          builder: (BuildContext context, SongsState state) {
            final bool isFavorite = songsBloc.stateData.favoriteIds.contains(
              song.id,
            );

            return SheetShell(
              header: SongSheetHeader(song: song),
              body: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SheetAction(
                      icon: isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      iconColor: isFavorite ? AppColors.accent : null,
                      labelColor: isFavorite ? AppColors.accent : null,
                      label: isFavorite
                          ? 'Remove from Favourite'
                          : 'Favourite',
                      onTap: () {
                        songsBloc.add(
                          isFavorite
                              ? RemoveFromFavorites(song.id)
                              : AddToFavorites(song.id),
                        );
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
                      icon: Icons.graphic_eq_rounded,
                      label: 'Equalizer',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: Colors.transparent,
                          builder: (BuildContext eqContext) =>
                              EqualizerSheet(musicBloc: musicBloc),
                        );
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
            );
          },
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
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) =>
          _SleepTimerSheet(musicBloc: musicBloc),
    );
  }
}

class _SleepTimerOption {
  const _SleepTimerOption(this.label, {this.minutes, this.endOfTrack = false});

  final String label;
  final int? minutes;
  final bool endOfTrack;
}

const List<_SleepTimerOption> _sleepTimerOptions = <_SleepTimerOption>[
  _SleepTimerOption('15m', minutes: 15),
  _SleepTimerOption('30m', minutes: 30),
  _SleepTimerOption('1h', minutes: 60),
  _SleepTimerOption('End of\ntrack', endOfTrack: true),
];

class _SleepTimerSheet extends StatefulWidget {
  const _SleepTimerSheet({required this.musicBloc});

  final MusicControllerBloc musicBloc;

  @override
  State<_SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<_SleepTimerSheet> {
  int _selected = 1;

  @override
  Widget build(BuildContext context) {
    final _SleepTimerOption option = _sleepTimerOptions[_selected];

    return SheetShell(
      showDivider: false,
      header: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Sleep timer',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'Fades out over the last 20 seconds',
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                for (int i = 0; i < _sleepTimerOptions.length; i++) ...<Widget>[
                  Expanded(child: _buildChip(i)),
                  if (i != _sleepTimerOptions.length - 1) SizedBox(width: 8.w),
                ],
              ],
            ),
            SizedBox(height: 20.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(0, 46.h),
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13.r),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(0, 46.h),
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13.r),
                      ),
                    ),
                    onPressed: () {
                      widget.musicBloc.add(
                        option.endOfTrack
                            ? SetSleepTimer(songCount: 1)
                            : SetSleepTimer(
                                duration: Duration(minutes: option.minutes!),
                              ),
                      );
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Start · ${option.label.replaceAll('\n', ' ')}',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(int index) {
    final bool selected = index == _selected;
    final _SleepTimerOption option = _sleepTimerOptions[index];

    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: () => setState(() => _selected = index),
      child: Container(
        height: 52.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.16)
              : AppColors.surfaceHigh,
          border: selected ? Border.all(color: AppColors.accent) : null,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Text(
          option.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
