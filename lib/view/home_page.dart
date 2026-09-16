import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/music_controller/music_controller_bloc.dart';
import '../core/app_constants/app_enums.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/utils.dart';
import '../service/battery_optimization_helper.dart';
import '../widgets/common/scrolling_title.dart';
import 'albums_page.dart';
import 'artists_page.dart';
import 'audio_songs_page.dart';
import 'folders_page.dart';
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
  final FocusNode _searchFocusNode = FocusNode();

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
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    searchController.clear();
    setState(() => isSearching = false);
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: isSearching
              ? TextField(
                  controller: searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                  cursorColor: AppColors.accent,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Search',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                  ),
                )
              : const Text(
                  'SLUNE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
          backgroundColor: AppColors.background,
          leading: isSearching
              ? IconButton(
                  onPressed: _closeSearch,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textPrimary,
                    size: 24.sp,
                  ),
                )
              : null,
          actions: <Widget>[
            if (isSearching)
              IconButton(
                onPressed: searchController.clear,
                icon: Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                  size: 22.sp,
                ),
              )
            else ...<Widget>[
              IconButton(
                onPressed: _openSearch,
                icon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textPrimary,
                  size: 24.sp,
                ),
              ),
              IconButton(
                onPressed: () => context.push(AppRouter.settings),
                icon: Icon(
                  Icons.settings_outlined,
                  color: AppColors.textPrimary,
                  size: 24.sp,
                ),
              ),
            ],
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(36.h),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor: AppColors.accent,
              dividerColor: AppColors.divider,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              labelPadding: EdgeInsets.symmetric(horizontal: 18.w),
              labelStyle: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 15.sp,
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
          children: <Widget>[
            AllSongsPage(searchController: searchController),
            PlaylistsPage(searchController: searchController),
            AlbumsPage(searchController: searchController),
            ArtistsPage(searchController: searchController),
            FoldersPage(searchController: searchController),
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

                final double speed = _musicControllerBloc.stateData.speed;

                return GestureDetector(
                  onHorizontalDragEnd: (DragEndDetails details) {
                    final double? velocity = details.primaryVelocity;
                    if (velocity == null || velocity == 0) {
                      return;
                    }
                    _musicControllerBloc.add(
                      velocity < 0 ? NextSong() : PreviousSong(),
                    );
                  },
                  child: InkWell(
                    onTap: () {
                      Utils.openPlayerBottomSheet(
                        context,
                        song,
                        _musicControllerBloc.stateData.index,
                      );
                    },
                    child: SafeArea(
                      top: false,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          border: Border(
                            top: BorderSide(color: AppColors.divider),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 2.h,
                              backgroundColor: AppColors.divider,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.accent,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 10.h,
                              ),
                              child: Row(
                                children: <Widget>[
                                  QueryArtworkWidget(
                                    id: song.id,
                                    keepOldArtwork: true,
                                    type: ArtworkType.AUDIO,
                                    artworkHeight: 40.w,
                                    artworkWidth: 40.w,
                                    artworkBorder: BorderRadius.circular(8.r),
                                    nullArtworkWidget: Container(
                                      height: 40.w,
                                      width: 40.w,
                                      decoration: BoxDecoration(
                                        color: AppColors.iconBg,
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.music_note_rounded,
                                        size: 18.sp,
                                        color: AppColors.iconColor,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        ScrollingTitle(
                                          text: song.title,
                                          height: 18.h,
                                          alignment: Alignment.centerLeft,
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 13.5.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          (speed - 1.0).abs() > 0.01
                                              ? '${song.artist ?? 'Unknown Artist'} · ${speed.toStringAsFixed(2)}×'
                                              : song.artist ??
                                                    'Unknown Artist',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color:
                                                (speed - 1.0).abs() > 0.01
                                                ? AppColors.accent
                                                : AppColors.textSecondary,
                                            fontSize: 11.5.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
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
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 26.sp,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        PlayingQueueSheet.show(context),
                                    icon: Icon(
                                      Icons.queue_music_rounded,
                                      size: 22.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
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
