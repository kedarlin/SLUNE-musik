import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../core/app_constants/app_enums.dart';
import '../core/bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/utils.dart';
import '../ffi/audio_engine.dart';
import 'audio_songs_page.dart';
import 'favourite_songs_page.dart';

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

  final AudioEngine engine = AudioEngine.instance;

  @override
  void initState() {
    super.initState();
    engine.initialize();
    engine.play();
    // engine.pause();
    // engine.release();

    _musicControllerBloc = BlocProvider.of<MusicControllerBloc>(context);
    musicListener();
    _tabController = TabController(length: Tabs.values.length, vsync: this);
  }

  void musicListener() {
    WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
      _musicControllerBloc.stream.listen((MusicControllerState state) {
        if (mounted) {
          if (state is MusicEnded) {
            _musicControllerBloc.add(NextSong());
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: AppColors.darkBlue,
        appBar: AppBar(
          title: const Text(
            'SLUNE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppColors.darkBlue,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorColor: AppColors.lightBlue,
              dividerColor: AppColors.grey1,
              labelPadding: EdgeInsets.all(20.w),
              labelStyle: TextStyle(
                color: AppColors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(
                color: AppColors.grey2,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
              tabs: List<Widget>.generate(Tabs.values.length, (int index) {
                return Text(Tabs.values[index].name.toUpperCase());
              }),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const <Widget>[
            AllSongsPage(),
            Center(child: Text('Favorites')),
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
                return InkWell(
                  onTap: () {
                    Utils.openPlayerBottomSheet(
                      context,
                      song,
                      _musicControllerBloc.stateData.index,
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: 4.w),
                    // padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: AppColors.blue1,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(44.r),
                        bottomRight: Radius.circular(44.r),
                      ),
                    ),
                    child: Row(
                      spacing: 6.w,
                      children: <Widget>[
                        QueryArtworkWidget(
                          id: song.id,
                          keepOldArtwork: true,
                          type: ArtworkType.AUDIO,
                          artworkHeight: 52.w,
                          artworkWidth: 52.w,
                          artworkBorder: BorderRadius.circular(6.r),
                          nullArtworkWidget: Container(
                            height: 52.w,
                            width: 52.w,
                            decoration: BoxDecoration(
                              color: AppColors.iconBg,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Icon(
                              Icons.music_note_rounded,
                              size: 18.sp,
                              color: AppColors.iconColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            song.title,
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 14.sp,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24.r),
                            border: Border.all(
                              width: 2.w,
                              color: AppColors.white,
                            ),
                          ),
                          child: IconButton(
                            onPressed: () {
                              _musicControllerBloc.add(PlayPauseToggled());
                            },
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              _musicControllerBloc.stateData.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              size: 20.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}
