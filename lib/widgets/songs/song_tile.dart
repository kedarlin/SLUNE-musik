import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../bloc/music_controller/music_controller_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/utils.dart';
import '../common/equalizer_bars.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    required this.song,
    required this.queue,
    required this.index,
    required this.onMoreTap,
    super.key,
  });

  final SongModel song;
  final List<SongModel> queue;
  final int index;
  final VoidCallback onMoreTap;

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

        return ListTile(
          leading: SizedBox(
            height: 46.w,
            width: 46.w,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                QueryArtworkWidget(
                  id: song.id,
                  type: ArtworkType.AUDIO,
                  artworkHeight: 46.w,
                  artworkWidth: 46.w,
                  artworkBorder: BorderRadius.circular(8.r),
                  keepOldArtwork: true,
                  nullArtworkWidget: Container(
                    height: 44.w,
                    width: 44.w,
                    decoration: BoxDecoration(
                      color: AppColors.iconBg,
                      borderRadius: BorderRadius.circular(8.r),
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
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      height: 46.w,
                      width: 46.w,
                      color: Colors.black.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: EqualizerBars(
                        isPlaying: isPlaying,
                        barWidth: 3.w,
                        height: 16.h,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          title: Text(
            song.title,
            style: TextStyle(color: titleColor, fontSize: 14.sp),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          subtitle: Text(
            song.artist ?? 'Unknown Artist',
            style: TextStyle(
              color: isCurrentSong ? AppColors.accent : AppColors.textSecondary,
              fontSize: 13.sp,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          onTap: () {
            context.read<MusicControllerBloc>().add(
              InitAudio(song: song, index: index, queue: queue),
            );

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
        );
      },
    );
  }
}
