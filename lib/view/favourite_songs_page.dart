import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import '../core/bloc/songs_bloc/songs_bloc.dart';
import '../core/common_widgets.dart/loader_widget.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/utils.dart';

class FavouriteSongsPage extends StatefulWidget {
  const FavouriteSongsPage({super.key});

  @override
  State<FavouriteSongsPage> createState() => _FavouriteSongsPageState();
}

class _FavouriteSongsPageState extends State<FavouriteSongsPage> {
  late MusicControllerBloc _musicControllerBloc;
  late SongsBloc _songsBloc;

  @override
  void initState() {
    super.initState();
    _musicControllerBloc = BlocProvider.of<MusicControllerBloc>(context);
    _songsBloc = BlocProvider.of<SongsBloc>(context);
    _songsBloc.add(GetAllFavorites());
    _requestPermissionAndLoadSongs();
  }

  Future<void> _requestPermissionAndLoadSongs() async {
    final PermissionStatus permissionStatus = await Permission.audio.request();
    if (!permissionStatus.isGranted) {
      final PermissionStatus storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        BlocBuilder<SongsBloc, SongsState>(
          builder: (BuildContext context, SongsState state) {
            if (state is FetchSongsLoading) {
              return const Center(child: CustomLoader());
            } else if (_songsBloc.stateData.favorites.isEmpty) {
              return const Center(child: Text('No favourite songs found'));
            }
            return Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _songsBloc.add(GetAllFavorites());
                },
                child: ListView.builder(
                  itemCount: _songsBloc.stateData.favorites.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SongModel song =
                        _songsBloc.stateData.favorites[index];
                    return ListTile(
                      leading: QueryArtworkWidget(
                        id: song.id,
                        type: ArtworkType.AUDIO,
                        artworkHeight: 40.w,
                        artworkWidth: 40.w,
                        keepOldArtwork: true,
                        nullArtworkWidget: Container(
                          height: 40.w,
                          width: 40.w,
                          decoration: BoxDecoration(
                            color: AppColors.iconBg,
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 18.sp,
                            color: AppColors.iconColor,
                          ),
                        ),
                      ),
                      title: Text(
                        song.title,
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 14.sp,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      subtitle: Text(
                        song.artist ?? 'Unknown Artist',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 12.sp,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      onTap: () {
                        final List<SongModel> favList =
                            _songsBloc.stateData.favorites;

                        _musicControllerBloc.add(
                          InitAudio(
                            song: favList[index],
                            index: index,
                            queue: favList,
                          ),
                        );

                        Utils.openPlayerBottomSheet(
                          context,
                          favList[index],
                          index,
                        );
                      },
                      contentPadding: EdgeInsets.only(left: 16.w),
                      trailing: IconButton(
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            backgroundColor: AppColors.bottomSheetBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16.r),
                              ),
                            ),
                            builder: (BuildContext context) => Container(
                              decoration: BoxDecoration(
                                color: AppColors.bottomSheetBg,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12.r),
                                  topRight: Radius.circular(12.r),
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: <Widget>[
                                    ListTile(
                                      leading: QueryArtworkWidget(
                                        id: song.id,
                                        type: ArtworkType.AUDIO,
                                        artworkHeight: 40.w,
                                        artworkWidth: 40.w,
                                        keepOldArtwork: true,
                                        nullArtworkWidget: Container(
                                          height: 40.w,
                                          width: 40.w,
                                          decoration: BoxDecoration(
                                            color: AppColors.iconBg,
                                            borderRadius: BorderRadius.circular(
                                              6.r,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.music_note_rounded,
                                            size: 18.sp,
                                            color: AppColors.iconColor,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        song.title,
                                        style: TextStyle(
                                          color: AppColors.white,
                                          fontSize: 14.sp,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      subtitle: Text(
                                        song.artist ?? 'Unknown Artist',
                                        style: TextStyle(
                                          color: AppColors.white,
                                          fontSize: 12.sp,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      contentPadding: EdgeInsets.only(
                                        left: 16.w,
                                      ),
                                    ),
                                    Divider(
                                      color: AppColors.blue1,
                                      height: 1.h,
                                    ),
                                    ListTile(
                                      leading: Icon(
                                        Icons.favorite,
                                        size: 18.sp,
                                        color: AppColors.grey2,
                                      ),
                                      title: Text(
                                        'Add to Favourites',
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          color: AppColors.grey2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 24.sp,
                          color: AppColors.grey7,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
