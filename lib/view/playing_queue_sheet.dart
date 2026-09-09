import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../core/bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import '../core/theme/app_colors.dart';

class PlayingQueueSheet {
  static void show(BuildContext context) {
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
        return BlocBuilder<MusicControllerBloc, MusicControllerState>(
          bloc: musicBloc,
          builder: (BuildContext context, MusicControllerState state) {
            final List<SongModel> queue = musicBloc.stateData.queue;

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12.r),
                  topRight: Radius.circular(12.r),
                ),
              ),
              constraints: BoxConstraints(maxHeight: 0.75.sh),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 8.w, 12.h),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Row(
                            children: <Widget>[
                              Text(
                                'Playing Queue',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                '(${queue.length})',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            musicBloc.add(ClearQueue());
                            Navigator.of(sheetContext).pop();
                          },
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 24.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => musicBloc.add(ToggleShuffle()),
                          icon: Icon(
                            Icons.shuffle_rounded,
                            size: 24.sp,
                            color: musicBloc.stateData.isShuffle
                                ? AppColors.accent
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: AppColors.divider, height: 1.h),
                  if (queue.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.h),
                      child: const Text(
                        'Queue is empty',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    Flexible(
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        itemCount: queue.length,
                        onReorder: (int oldIndex, int newIndex) {
                          musicBloc.add(ReorderQueue(oldIndex, newIndex));
                        },
                        itemBuilder: (BuildContext context, int index) {
                          final SongModel song = queue[index];
                          final bool isCurrent =
                              index == musicBloc.stateData.index;

                          return ColoredBox(
                            key: ValueKey<String>('${song.id}-$index'),
                            color: isCurrent
                                ? AppColors.accent.withValues(alpha: 0.12)
                                : AppColors.transparent,
                            child: ListTile(
                              leading: ReorderableDragStartListener(
                                index: index,
                                child: Icon(
                                  Icons.drag_handle_rounded,
                                  size: 22.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              title: Text(
                                song.title,
                                style: TextStyle(
                                  color: isCurrent
                                      ? AppColors.accent
                                      : AppColors.textPrimary,
                                  fontSize: 14.sp,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              subtitle: Text(
                                song.artist ?? 'Unknown Artist',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.sp,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              trailing: IconButton(
                                onPressed: () =>
                                    musicBloc.add(RemoveFromQueue(index)),
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 20.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              onTap: () =>
                                  musicBloc.add(JumpToQueueIndex(index)),
                            ),
                          );
                        },
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
