import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../core/app_constants/app_enums.dart';
import '../core/bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/utils.dart';
import '../service/battery_optimization_helper.dart';
import 'audio_songs_page.dart';
import 'favourite_songs_page.dart';
import 'playing_queue_sheet.dart';
import 'playlists_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const String routePath = '/homepage';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MusicControllerBloc _musicControllerBloc;
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _musicControllerBloc = BlocProvider.of<MusicControllerBloc>(context);
    _tabController = TabController(length: Tabs.values.length, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        BatteryOptimizationHelper.promptForBackgroundReliability(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'SLUNE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppColors.background,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(36.h),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorColor: AppColors.accent,
              indicatorWeight: 3,
              dividerColor: AppColors.divider,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              labelPadding: EdgeInsets.symmetric(horizontal: 18.w),
              labelStyle: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
              tabs: List<Widget>.generate(Tabs.values.length, (int index) {
                final String name = Tabs.values[index].name;
                return Tab(
                  child: Text('${name[0].toUpperCase()}${name.substring(1)}'),
                );
              }),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const <Widget>[
            AllSongsPage(),
            PlaylistsPage(),
            FavouriteSongsPage(),
          ],
        ),
        bottomNavigationBar:
            BlocBuilder<MusicControllerBloc, MusicControllerState>(
              builder: (BuildContext context, MusicControllerState state) {
                final SongModel? song = _musicControllerBloc.stateData.song;
                if (song == null) {
                  return const SizedBox();
                }
                final int duration = _musicControllerBloc.stateData.duration;
                final double progress = duration > 0
                    ? (_musicControllerBloc.stateData.position / duration)
                          .clamp(0.0, 1.0)
                    : 0.0;

                return GestureDetector(
                  // Swipe left -> next song, swipe right -> previous song.
                  onHorizontalDragEnd: (DragEndDetails details) {
                    final double? velocity = details.primaryVelocity;
                    if (velocity == null || velocity == 0) {
                      return;
                    }
                    _musicControllerBloc.add(
                      velocity < 0 ? NextSong() : PreviousSong(),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 4, 8.w, 16.h),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(32.r),
                      onTap: () {
                        Utils.openPlayerBottomSheet(
                          context,
                          song,
                          _musicControllerBloc.stateData.index,
                        );
                      },
                      child: Container(
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(32.r),
                            bottomRight: Radius.circular(32.r),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Transform.scale(
                                  scale: 1.1,
                                  child: QueryArtworkWidget(
                                    id: song.id,
                                    keepOldArtwork: true,
                                    type: ArtworkType.AUDIO,
                                    artworkHeight: 44.w,
                                    artworkWidth: 44.w,
                                    artworkBorder: BorderRadius.circular(4.r),
                                    nullArtworkWidget: Container(
                                      height: 44.w,
                                      width: 44.w,
                                      decoration: BoxDecoration(
                                        color: AppColors.iconBg,
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.music_note_rounded,
                                        size: 20.sp,
                                        color: AppColors.iconColor,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Text(
                                    song.title,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13.sp,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    _musicControllerBloc.add(
                                      PlayPauseToggled(),
                                    );
                                  },
                                  icon: Icon(
                                    _musicControllerBloc.stateData.isPlaying
                                        ? Icons.pause_circle_outline_rounded
                                        : Icons.play_circle_outline_rounded,
                                    size: 32.sp,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      PlayingQueueSheet.show(context),
                                  icon: Icon(
                                    Icons.queue_music_rounded,
                                    size: 26.sp,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 2.h,
                              backgroundColor: AppColors.divider,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}
