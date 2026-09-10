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
        return _QueueSheetBody(musicBloc: musicBloc, sheetContext: sheetContext);
      },
    );
  }
}

class _QueueSheetBody extends StatefulWidget {
  const _QueueSheetBody({required this.musicBloc, required this.sheetContext});

  final MusicControllerBloc musicBloc;
  final BuildContext sheetContext;

  @override
  State<_QueueSheetBody> createState() => _QueueSheetBodyState();
}

class _QueueSheetBodyState extends State<_QueueSheetBody> {
  final ScrollController _scrollController = ScrollController();

  // Fixed row height: keeps ReorderableListView layout O(1) (no measuring
  // 100 children) and makes the scroll-to-current offset exact.
  double get _itemExtent => 60.h;

  int _lastRenderedIndex = -1;
  bool _didInitialScroll = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentAfterFrame() {
    if (_didInitialScroll) {
      return;
    }
    _didInitialScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final int index = widget.musicBloc.stateData.index;
      final double target = (index * _itemExtent).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final MusicControllerBloc musicBloc = widget.musicBloc;

    return BlocBuilder<MusicControllerBloc, MusicControllerState>(
      bloc: musicBloc,
      buildWhen: (MusicControllerState prev, MusicControllerState curr) {
        // Ignore the ~200ms position ticks; rebuild only when the queue
        // itself or the current track changes.
        if (curr is MusicQueueChanged) {
          return true;
        }
        return musicBloc.stateData.index != _lastRenderedIndex;
      },
      builder: (BuildContext context, MusicControllerState state) {
        final List<SongModel> queue = musicBloc.stateData.queue;
        _lastRenderedIndex = musicBloc.stateData.index;
        _scrollToCurrentAfterFrame();

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12.r),
              topRight: Radius.circular(12.r),
            ),
          ),
          constraints: BoxConstraints(maxHeight: 0.5.sh),
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
                        Navigator.of(widget.sheetContext).pop();
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
                    scrollController: _scrollController,
                    itemExtent: _itemExtent,
                    buildDefaultDragHandles: false,
                    itemCount: queue.length,
                    onReorder: (int oldIndex, int newIndex) {
                      musicBloc.add(ReorderQueue(oldIndex, newIndex));
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final SongModel song = queue[index];
                      final bool isCurrent = index == musicBloc.stateData.index;

                      return _QueueRow(
                        key: ValueKey<String>('${song.id}-$index'),
                        song: song,
                        index: index,
                        isCurrent: isCurrent,
                        onTap: () => musicBloc.add(JumpToQueueIndex(index)),
                        onRemove: () => musicBloc.add(RemoveFromQueue(index)),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.song,
    required this.index,
    required this.isCurrent,
    required this.onTap,
    required this.onRemove,
    super.key,
  });

  final SongModel song;
  final int index;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isCurrent
          ? AppColors.accent.withValues(alpha: 0.12)
          : AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Row(
            children: <Widget>[
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    size: 22.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
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
                    Text(
                      song.artist ?? 'Unknown Artist',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.close_rounded,
                  size: 20.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
