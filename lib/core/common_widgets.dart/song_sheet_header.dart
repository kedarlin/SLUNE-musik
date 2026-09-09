import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../theme/app_colors.dart';

class SongSheetHeader extends StatelessWidget {
  const SongSheetHeader({required this.song, super.key});

  final SongModel song;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: QueryArtworkWidget(
        id: song.id,
        type: ArtworkType.AUDIO,
        artworkHeight: 44.w,
        artworkWidth: 44.w,
        artworkBorder: BorderRadius.circular(6.r),
        keepOldArtwork: true,
        nullArtworkWidget: Container(
          height: 44.w,
          width: 44.w,
          decoration: BoxDecoration(
            color: AppColors.iconBg,
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Icon(
            Icons.music_note_rounded,
            size: 20.sp,
            color: AppColors.iconColor,
          ),
        ),
      ),
      title: Text(
        song.title,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 15.sp),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: Text(
        song.artist ?? 'Unknown Artist',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
    );
  }
}
