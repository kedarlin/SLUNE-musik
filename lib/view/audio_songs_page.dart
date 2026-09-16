import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../bloc/music_controller/music_controller_bloc.dart';
import '../bloc/songs/songs_bloc.dart';
import '../core/app_constants/app_enums.dart';
import '../core/theme/app_colors.dart';
import '../widgets/songs/song_list_skeleton.dart';
import '../widgets/songs/song_options_sheet.dart';
import '../widgets/songs/song_tile.dart';
import '../widgets/songs/sort_options_dialog.dart';

class AllSongsPage extends StatefulWidget {
  const AllSongsPage({required this.searchController, super.key});

  final TextEditingController searchController;

  @override
  State<AllSongsPage> createState() => _AllSongsPageState();
}

class _AllSongsPageState extends State<AllSongsPage>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late SongsBloc _songsBloc;
  bool isSearching = false;
  bool _checkingPermission = true;
  bool _permissionDenied = false;
  Timer? _debounce;
  final ScrollController _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _songsBloc = BlocProvider.of<SongsBloc>(context);
    _requestPermissionThenLoadSongs();
    widget.searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      isSearching = widget.searchController.text.isNotEmpty;
    });

    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _songsBloc.add(SearchSongs(searchText: widget.searchController.text));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _permissionDenied) {
      _requestPermissionThenLoadSongs(promptIfDenied: false);
    }
  }

  Future<void> _requestPermissionThenLoadSongs({
    bool promptIfDenied = true,
  }) async {
    final bool granted = await _resolveMediaPermission(
      allowRequest: promptIfDenied,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _checkingPermission = false;
      _permissionDenied = !granted;
    });

    if (granted) {
      _songsBloc.add(FetchSongs());

      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  Future<bool> _resolveMediaPermission({required bool allowRequest}) async {
    Future<PermissionStatus> resolve(Permission permission) async {
      final PermissionStatus status = await permission.status;
      if (status.isGranted || !allowRequest || status.isPermanentlyDenied) {
        return status;
      }
      return permission.request();
    }

    if ((await resolve(Permission.audio)).isGranted) {
      return true;
    }
    return (await resolve(Permission.storage)).isGranted;
  }

  Future<void> _onGrantPermissionPressed() async {
    final PermissionStatus audioStatus = await Permission.audio.status;
    final PermissionStatus storageStatus = await Permission.storage.status;

    if (audioStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }

    await _requestPermissionThenLoadSongs();
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

  Widget _buildPermissionPrompt() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.folder_off_rounded,
            size: 48.sp,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 16.h),
          Text(
            'Muxic needs permission to read the audio files on your '
            'device to show your songs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
          ),
          SizedBox(height: 20.h),
          FilledButton(
            onPressed: _onGrantPermissionPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              minimumSize: Size(0, 46.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13.r),
              ),
            ),
            child: Text(
              'Grant permission',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.searchController.removeListener(_onSearchChanged);
    _debounce?.cancel();
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 4.h),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _shuffleAll,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.divider, width: 1.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13.r),
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
          ),
        ),
        BlocBuilder<SongsBloc, SongsState>(
          builder: (BuildContext context, SongsState state) {
            if (_permissionDenied && !isSearching) {
              return Expanded(child: _buildPermissionPrompt());
            }
            if (_checkingPermission || state is FetchSongsLoading) {
              return const Expanded(child: SongListSkeleton());
            } else if ((!isSearching && _songsBloc.stateData.songs.isEmpty) ||
                (isSearching && _songsBloc.stateData.searchSongs.isEmpty)) {
              return const Center(child: Text('No songs found'));
            }
            return Expanded(
              child: Column(
                children: <Widget>[
                  _buildCountRow(),
                  Expanded(child: _buildList()),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatTotalSize(int bytes) {
    final double gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 0.1) {
      return '${gb.toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  static const Map<SongSortField, String> _sortFieldLabels =
      <SongSortField, String>{
        SongSortField.title: 'Title',
        SongSortField.length: 'Length',
        SongSortField.date: 'Date added',
        SongSortField.size: 'File size',
      };

  Widget _buildCountRow() {
    final List<SongModel> list = isSearching
        ? _songsBloc.stateData.searchSongs
        : _songsBloc.stateData.songs;
    final int totalBytes = list.fold<int>(0, (int sum, SongModel s) => sum + s.size);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            '${list.length} track${list.length == 1 ? '' : 's'} · '
            '${_formatTotalSize(totalBytes)}',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w500,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(15.r),
            onTap: _openSortDialog,
            child: Container(
              height: 30.h,
              padding: EdgeInsets.symmetric(horizontal: 11.w),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(15.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _sortFieldLabels[_songsBloc.stateData.sortField] ??
                        'Title',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15.sp,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
                onRefresh: () async {
                  if (isSearching) {
                    return;
                  }
                  _songsBloc.add(FetchSongs(forceFetch: true));
                },
                child: RawScrollbar(
                  controller: _listScrollController,
                  thumbColor: AppColors.textSecondary.withValues(alpha: 0.6),
                  radius: Radius.circular(8.r),
                  thickness: 4.w,
                  thumbVisibility: false,
                  child: ListView.builder(
                    controller: _listScrollController,
                    addAutomaticKeepAlives: false,
                    itemCount: isSearching
                        ? _songsBloc.stateData.searchSongs.length
                        : _songsBloc.stateData.songs.length,
                    itemBuilder: (BuildContext context, int index) {
                      final List<SongModel> displayList = isSearching
                          ? _songsBloc.stateData.searchSongs
                          : _songsBloc.stateData.songs;
                      final SongModel song = displayList[index];
                      final bool isFavorite = _songsBloc.stateData.favoriteIds
                          .contains(song.id);

                      final List<SongModel> fullList =
                          _songsBloc.stateData.songs;
                      final int fullIndex = isSearching
                          ? fullList.indexWhere(
                              (SongModel s) => s.id == song.id,
                            )
                          : index;
                      final List<SongModel> queue = fullIndex >= 0
                          ? fullList
                          : displayList;
                      final int queueIndex = fullIndex >= 0 ? fullIndex : index;

                      return Padding(
                        padding: EdgeInsetsGeometry.only(bottom: 8.h),
                        child: SongTile(
                          song: song,
                          queue: queue,
                          index: queueIndex,
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
  }
}
