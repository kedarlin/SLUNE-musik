import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../bloc/music_controller/music_controller_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/utils.dart';
import '../../service/speed_memory.dart';
import '../common/equalizer_bars.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    required this.song,
    required this.queue,
    required this.index,
    required this.onMoreTap,
    this.queueSpeed,
    super.key,
  });

  final SongModel song;
  final List<SongModel> queue;
  final int index;
  final VoidCallback onMoreTap;

  /// When this tile's queue comes from a playlist pinned to a speed (1e),
  /// the speed to force on tap - overrides any per-track remembered speed,
  /// since the pin is a deliberate playlist-level choice.
  final double? queueSpeed;

  static String _formatDuration(int? ms) {
    if (ms == null || ms <= 0) {
      return '--:--';
    }
    final int totalSeconds = ms ~/ 1000;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicControllerBloc, MusicControllerState>(
      buildWhen: (MusicControllerState previous, MusicControllerState current) {
        final bool wasCurrent =
            previous is MusicControllerStateData &&
            previous.song?.id == song.id;
        final bool isCurrent =
            current is MusicControllerStateData && current.song?.id == song.id;
        if (wasCurrent != isCurrent) {
          return true;
        }
        if (!isCurrent) {
          return false;
        }
        final bool wasPlaying =
            previous is MusicControllerStateData && previous.isPlaying;
        return wasPlaying != current.isPlaying;
      },
      builder: (BuildContext context, MusicControllerState state) {
        final MusicControllerStateData stateData = context
            .read<MusicControllerBloc>()
            .stateData;
        final bool isCurrentSong = stateData.song?.id == song.id;
        final bool isPlaying = isCurrentSong && stateData.isPlaying;
        final Color titleColor = isCurrentSong
            ? AppColors.accent
            : AppColors.textPrimary;
        final double? rememberedSpeed = SpeedMemory.enabled
            ? SpeedMemory.speedFor(song.id)
            : null;
        final bool showSpeed =
            rememberedSpeed != null && (rememberedSpeed - 1.0).abs() > 0.01;
        final Color metaColor = isCurrentSong
            ? AppColors.accent
            : AppColors.textSecondary;

        return Material(
          color: isCurrentSong
              ? AppColors.accent.withValues(alpha: 0.07)
              : Colors.transparent,
          child: ListTile(
            leading: SizedBox(
              height: 48.w,
              width: 48.w,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    artworkHeight: 48.w,
                    artworkWidth: 48.w,
                    artworkBorder: BorderRadius.circular(9.r),
                    keepOldArtwork: true,
                    nullArtworkWidget: Container(
                      height: 48.w,
                      width: 48.w,
                      decoration: BoxDecoration(
                        color: AppColors.iconBg,
                        borderRadius: BorderRadius.circular(9.r),
                      ),
                      child: Icon(
                        Icons.music_note_rounded,
                        size: 22.sp,
                        color: AppColors.iconColor,
                      ),
                    ),
                  ),
                  if (isCurrentSong)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9.r),
                      child: Container(
                        height: 48.w,
                        width: 48.w,
                        color: Colors.black.withValues(alpha: 0.55),
                        alignment: Alignment.center,
                        child: EqualizerBars(
                          isPlaying: isPlaying,
                          barWidth: 2.5.w,
                          height: 16.h,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            title: Text(
              song.title,
              style: TextStyle(
                color: titleColor,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            subtitle: Text.rich(
              TextSpan(
                text:
                    '${song.artist ?? 'Unknown Artist'} · ${_formatDuration(song.duration)}',
                style: TextStyle(
                  color: metaColor,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w500,
                ),
                children: showSpeed
                    ? <InlineSpan>[
                        TextSpan(
                          text:
                              ' · ${rememberedSpeed.toStringAsFixed(2)}×',
                          style: const TextStyle(color: AppColors.accent),
                        ),
                      ]
                    : null,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            onTap: () {
              final MusicControllerBloc musicBloc = context
                  .read<MusicControllerBloc>();
              musicBloc.add(
                InitAudio(song: song, index: index, queue: queue),
              );
              if (queueSpeed != null) {
                musicBloc.add(SpeedChanged(queueSpeed!));
              }

              Utils.openPlayerBottomSheet(context, song, index);
            },
            contentPadding: EdgeInsets.only(left: 16.w, right: 4.w),
            visualDensity: VisualDensity.compact,
            trailing: IconButton(
              onPressed: onMoreTap,
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_vert_rounded,
                size: 22.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
      },
    );
  }
}
