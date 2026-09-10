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

class _AllSongsPageState extends State<AllSongsPage>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late SongsBloc _songsBloc;
  bool isSearching = false;
  bool _checkingPermission = true;
  bool _permissionDenied = false;
  final TextEditingController searchController = TextEditingController();
  Timer? _debounce;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _songsBloc = BlocProvider.of<SongsBloc>(context);
    _requestPermissionThenLoadSongs();
    searchController.addListener(() {
      setState(() {
        isSearching = searchController.text.isNotEmpty;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.unfocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have granted the permission from the system Settings
    // screen after tapping the button below - re-check on resume.
    if (state == AppLifecycleState.resumed && _permissionDenied) {
      _requestPermissionThenLoadSongs(promptIfDenied: false);
    }
  }

  /// Waits for the media permission before dispatching [FetchSongs], so the
  /// query never runs unauthorized (which returns an empty list). When the
  /// permission is denied, drives the in-list "Grant permission" prompt
  /// instead.
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
      // Not forced: SongsBloc no-ops if the library is already loaded, so
      // re-entering this tab / page never re-runs the query.
      _songsBloc.add(FetchSongs());

      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  /// Returns whether audio/storage access is available, requesting it from
  /// the user when [allowRequest] is set and the OS still allows a prompt.
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

    // Once the OS marks a permission permanently denied, request() no longer
    // shows a dialog - the app settings screen is the only way back.
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
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 20.h),
          FilledButton(
            onPressed: _onGrantPermissionPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
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
    _debounce?.cancel();
    searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
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
            if (_permissionDenied && !isSearching) {
              return Expanded(child: _buildPermissionPrompt());
            }
            if (_checkingPermission || state is FetchSongsLoading) {
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
                    final List<SongModel> displayList = isSearching
                        ? _songsBloc.stateData.searchSongs
                        : _songsBloc.stateData.songs;
                    final SongModel song = displayList[index];
                    final bool isFavorite = _songsBloc.stateData.favoriteIds
                        .contains(song.id);

                    // Playing a song always queues the full library so
                    // next/previous works - even when tapped from a filtered
                    // search result. Fall back to the visible list if the
                    // song somehow isn't in the library list.
                    final List<SongModel> fullList = _songsBloc.stateData.songs;
                    final int fullIndex = fullList.indexWhere(
                      (SongModel s) => s.id == song.id,
                    );
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
          },
        ),
      ],
    );
  }
}
