import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import '../theme/app_colors.dart';
import '../utils/utils.dart';

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
    return ListTile(
      leading: QueryArtworkWidget(
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
      title: Text(
        song.title,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: Text(
        song.artist ?? 'Unknown Artist',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
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
  }
}
