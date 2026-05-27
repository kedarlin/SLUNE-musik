import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import '../core/bloc/songs_bloc/songs_bloc.dart';
import '../core/common_widgets.dart/loader_widget.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/utils.dart';
import '../service/audio_service.dart';

class AllSongsPage extends StatefulWidget {
  const AllSongsPage({super.key});

  @override
  State<AllSongsPage> createState() => _AllSongsPageState();
}

class _AllSongsPageState extends State<AllSongsPage> {
  late MusicControllerBloc _musicControllerBloc;
  late SongsBloc _songsBloc;
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();
  Timer? _debounce;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _musicControllerBloc = BlocProvider.of<MusicControllerBloc>(context);
    _songsBloc = BlocProvider.of<SongsBloc>(context);
    _songsBloc.add(FetchSongs());
    _requestPermissionAndLoadSongs();
    searchController.addListener(() {
      setState(() {
        isSearching = searchController.text.isNotEmpty;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.unfocus();
    });
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
        Container(
          height: 64.h,
          padding: EdgeInsets.all(12.w),
          child: Row(
            spacing: 8.w,
            children: <Widget>[
              Flexible(
                child: SearchBar(
                  leading: Icon(
                    Icons.search_rounded,
                    size: 20.sp,
                    color: AppColors.grey7,
                  ),
                  focusNode: _searchFocusNode,
                  controller: searchController,
                  hintText: 'Search songs...',
                  hintStyle: WidgetStatePropertyAll<TextStyle>(
                    TextStyle(color: AppColors.grey7, fontSize: 16.sp),
                  ),
                  shadowColor: const WidgetStatePropertyAll<Color>(
                    AppColors.transparent,
                  ),
                  padding: WidgetStatePropertyAll<EdgeInsets>(
                    EdgeInsets.symmetric(horizontal: 12.w),
                  ),
                  backgroundColor: const WidgetStatePropertyAll<Color>(
                    AppColors.grey1,
                  ),
                  textStyle: WidgetStatePropertyAll<TextStyle>(
                    TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTapOutside: (PointerDownEvent event) {
                    _searchFocusNode.unfocus();
                    FocusScope.of(context).unfocus();
                  },
                  shape: WidgetStatePropertyAll<OutlinedBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  trailing: <Widget>[
                    IconButton(
                      onPressed: () {
                        if (searchController.text.isNotEmpty) {
                          searchController.clear();
                        } else {}
                      },
                      icon:
                          isSearching
                              ? Icon(
                                Icons.close,
                                size: 24.sp,
                                color: AppColors.grey7,
                              )
                              : const Text(''),
                    ),
                  ],
                  onChanged: (String value) {
                    if (_debounce?.isActive ?? false) {
                      _debounce!.cancel();
                    }

                    _debounce = Timer(const Duration(milliseconds: 300), () {
                      _songsBloc.add(
                        SearchSongs(searchText: searchController.text),
                      );
                    });
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: AppColors.grey7, width: 1.w),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  backgroundColor: AppColors.transparent,
                ),
                child: Icon(
                  size: 18.sp,
                  Icons.sort_rounded,
                  color: AppColors.grey7,
                ),
              ),
            ],
          ),
        ),
        BlocBuilder<SongsBloc, SongsState>(
          builder: (BuildContext context, SongsState state) {
            if (state is FetchSongsLoading) {
              return const Center(child: CustomLoader());
            } else if ((!isSearching && _songsBloc.stateData.songs.isEmpty) ||
                (isSearching && _songsBloc.stateData.searchSongs.isEmpty)) {
              return const Center(child: Text('No songs found'));
            }
            return Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (isSearching) {
                    return;
                  }
                  _songsBloc.add(FetchSongs(forceFetch: true));
                },
                child: ListView.builder(
                  itemCount:
                      isSearching
                          ? _songsBloc.stateData.searchSongs.length
                          : _songsBloc.stateData.songs.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SongModel song =
                        isSearching
                            ? _songsBloc.stateData.searchSongs[index]
                            : _songsBloc.stateData.songs[index];
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
                        final List<SongModel> list =
                            isSearching
                                ? _songsBloc.stateData.searchSongs
                                : _songsBloc.stateData.songs;

                        _musicControllerBloc.add(
                          InitAudio(
                            song: list[index],
                            index: index,
                            queue: list,
                          ),
                        );
                        NativeAudio.loadPlaylist(
                          list
                              .map(
                                (SongModel song) => <String, String>{
                                  'uri': song.data,
                                  'title': song.title,
                                  'id': song.id.toString(),
                                },
                              )
                              .toList(),
                          index,
                        );

                        Utils.openPlayerBottomSheet(
                          context,
                          list[index],
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
                            builder:
                                (BuildContext context) => Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.bottomSheetBg,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(12.r),
                                      topRight: Radius.circular(12.r),
                                    ),
                                  ),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: 0.5.sh,
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
                                                  borderRadius:
                                                      BorderRadius.circular(
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
                                            onTap: () {
                                              _songsBloc.add(
                                                AddToFavorites(song.id),
                                              );
                                              context.pop();
                                            },
                                          ),
                                        ],
                                      ),
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
