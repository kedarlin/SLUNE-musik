import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/music_controller/music_controller_bloc.dart';
import '../core/theme/app_colors.dart';
import '../widgets/common/equalizer_bars.dart';
import '../widgets/common/sheet_shell.dart';

class PlayingQueueSheet {
  static void show(BuildContext context) {
    final MusicControllerBloc musicBloc = context.read<MusicControllerBloc>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _QueueSheetBody(
          musicBloc: musicBloc,
          sheetContext: sheetContext,
        );
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

  double get _itemExtent => 64.h;

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
        if (curr is MusicQueueChanged) {
          return true;
        }
        return musicBloc.stateData.index != _lastRenderedIndex;
      },
      builder: (BuildContext context, MusicControllerState state) {
        final List<SongModel> queue = musicBloc.stateData.queue;
        _lastRenderedIndex = musicBloc.stateData.index;
        _scrollToCurrentAfterFrame();

        return SheetShell(
          header: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Up Next',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        musicBloc.add(ClearQueue());
                        Navigator.of(widget.sheetContext).pop();
                      },
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      InkWell(
                        onTap: () => musicBloc.add(ToggleShuffle()),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.shuffle_rounded,
                              size: 15.sp,
                              color: musicBloc.stateData.isShuffle
                                  ? AppColors.accent
                                  : AppColors.textTertiary,
                            ),
                            SizedBox(width: 5.w),
                            Text(
                              musicBloc.stateData.isShuffle
                                  ? 'Shuffle on'
                                  : 'Shuffle off',
                              style: TextStyle(
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w500,
                                color: musicBloc.stateData.isShuffle
                                    ? AppColors.accent
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${queue.length} track${queue.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: queue.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.h),
                  child: Text(
                    'Queue is empty',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.sp,
                    ),
                  ),
                )
              : ReorderableListView.builder(
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
                    final bool isPlaying =
                        isCurrent && musicBloc.stateData.isPlaying;

                    return _QueueRow(
                      key: ValueKey<String>('${song.id}-$index'),
                      song: song,
                      index: index,
                      isCurrent: isCurrent,
                      isPlaying: isPlaying,
                      onTap: () => musicBloc.add(JumpToQueueIndex(index)),
                      onRemove: () => musicBloc.add(RemoveFromQueue(index)),
                    );
                  },
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
    required this.isPlaying,
    required this.onTap,
    required this.onRemove,
    super.key,
  });

  final SongModel song;
  final int index;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isCurrent
          ? AppColors.accent.withValues(alpha: 0.07)
          : AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          child: Row(
            children: <Widget>[
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: EdgeInsets.only(right: 11.w),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    size: 18.sp,
                    color: AppColors.disabled,
                  ),
                ),
              ),
              SizedBox(
                width: 48.w,
                height: 48.w,
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
                    if (isCurrent)
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
              SizedBox(width: 13.w),
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
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      song.artist ?? 'Unknown Artist',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onRemove,
                child: Padding(
                  padding: EdgeInsets.all(6.w),
                  child: Icon(
                    Icons.close_rounded,
                    size: 17.sp,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
