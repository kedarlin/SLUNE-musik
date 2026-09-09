import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import '../core/bloc/songs_bloc/songs_bloc.dart';
import '../core/common_widgets.dart/loader_widget.dart';
import '../core/common_widgets.dart/song_options_sheet.dart';
import '../core/common_widgets.dart/song_tile.dart';
import '../core/common_widgets.dart/sort_options_dialog.dart';
import '../core/theme/app_colors.dart';

class AllSongsPage extends StatefulWidget {
  const AllSongsPage({super.key});

  @override
  State<AllSongsPage> createState() => _AllSongsPageState();
}

class _AllSongsPageState extends State<AllSongsPage> {
  late SongsBloc _songsBloc;
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();
  Timer? _debounce;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
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

    if (!await Permission.notification.isGranted) {
      await Permission.notification.request();
    }
  }

  Future<void> _openSortDialog() async {
    final SortOptionsResult? result = await SortOptionsDialog.show(
      context,
      field: _songsBloc.stateData.sortField,
      ascending: _songsBloc.stateData.sortAscending,
      hideUnderOneMinute: _songsBloc.stateData.hideUnderOneMinute,
    );

    if (result == null) {
      return;
    }

    _songsBloc.add(
      ApplySongSort(
        field: result.field,
        ascending: result.ascending,
        hideUnderOneMinute: result.hideUnderOneMinute,
      ),
    );
  }

  void _shuffleAll() {
    final List<SongModel> list = isSearching
        ? _songsBloc.stateData.searchSongs
        : _songsBloc.stateData.songs;

    if (list.isEmpty) {
      return;
    }

    context.read<MusicControllerBloc>().add(ShuffleAll(list));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            spacing: 8.w,
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 44.h,
                  child: SearchBar(
                    leading: Icon(
                      Icons.search_rounded,
                      size: 20.sp,
                      color: AppColors.textSecondary,
                    ),
                    focusNode: _searchFocusNode,
                    controller: searchController,
                    hintText: 'Search songs...',
                    hintStyle: WidgetStatePropertyAll<TextStyle>(
                      TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                      ),
                    ),
                    shadowColor: const WidgetStatePropertyAll<Color>(
                      AppColors.transparent,
                    ),
                    padding: WidgetStatePropertyAll<EdgeInsets>(
                      EdgeInsets.symmetric(horizontal: 12.w),
                    ),
                    backgroundColor: const WidgetStatePropertyAll<Color>(
                      AppColors.surface,
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
                      if (isSearching)
                        IconButton(
                          onPressed: searchController.clear,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.close,
                            size: 20.sp,
                            color: AppColors.textSecondary,
                          ),
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
              ),
              OutlinedButton.icon(
                onPressed: _shuffleAll,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.divider, width: 1.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  minimumSize: Size(0, 44.h),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppColors.transparent,
                ),
                icon: Icon(
                  Icons.shuffle_rounded,
                  size: 17.sp,
                  color: AppColors.textPrimary,
                ),
                label: Text(
                  'Shuffle All',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: _openSortDialog,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32.w),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.swap_vert_rounded,
                  size: 24.sp,
                  color: AppColors.textPrimary,
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
                  itemCount: isSearching
                      ? _songsBloc.stateData.searchSongs.length
                      : _songsBloc.stateData.songs.length,
                  itemBuilder: (BuildContext context, int index) {
                    final List<SongModel> list = isSearching
                        ? _songsBloc.stateData.searchSongs
                        : _songsBloc.stateData.songs;
                    final SongModel song = list[index];
                    final bool isFavorite = _songsBloc.stateData.favoriteIds
                        .contains(song.id);

                    return Padding(
                      padding: EdgeInsetsGeometry.only(bottom: 8.h),
                      child: SongTile(
                        song: song,
                        queue: list,
                        index: index,
                        onMoreTap: () {
                          SongOptionsSheet.show(
                            context,
                            song: song,
                            isFavorite: isFavorite,
                            onToggleFavorite: () {
                              _songsBloc.add(
                                isFavorite
                                    ? RemoveFromFavorites(song.id)
                                    : AddToFavorites(song.id),
                              );
                            },
                          );
                        },
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
