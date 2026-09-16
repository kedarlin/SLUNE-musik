import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../bloc/playlists/playlists_bloc.dart';
import '../bloc/songs/songs_bloc.dart';
import '../core/app_constants/playlist_constants.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_colors.dart';
import '../models/playlist_model.dart';
import '../widgets/common/sheet_action.dart';
import '../widgets/common/sheet_shell.dart';
import '../widgets/playlists/create_playlist_sheet.dart';
import '../widgets/playlists/playlist_speed_sheet.dart';

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({required this.searchController, super.key});

  final TextEditingController searchController;

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage>
    with AutomaticKeepAliveClientMixin {
  late PlaylistsBloc _playlistsBloc;
  late SongsBloc _songsBloc;

  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _playlistsBloc = BlocProvider.of<PlaylistsBloc>(context);
    _songsBloc = BlocProvider.of<SongsBloc>(context);
    _playlistsBloc.add(LoadPlaylists());

    widget.searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(
      () => _query = widget.searchController.text.trim().toLowerCase(),
    );
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  Future<void> _createPlaylist() async {
    final String? name = await CreatePlaylistSheet.show(context);

    if (name != null && name.isNotEmpty) {
      _playlistsBloc.add(CreatePlaylist(name));
    }
  }

  Future<void> _renamePlaylist(Playlist playlist) async {
    final int count = playlist.songIds.length;
    final String? name = await CreatePlaylistSheet.show(
      context,
      title: 'Rename playlist',
      subtitle: '$count track${count == 1 ? '' : 's'}',
      actionLabel: 'Save',
      initialValue: playlist.name,
    );

    if (name != null && name.isNotEmpty) {
      _playlistsBloc.add(RenamePlaylist(playlist.id, name));
    }
  }

  Future<void> _pinSpeed(Playlist playlist) async {
    final double? result = await PlaylistSpeedSheet.show(
      context,
      playlist.pinnedSpeed,
    );
    if (result == null) {
      return;
    }
    _playlistsBloc.add(
      SetPlaylistPinnedSpeed(
        playlist.id,
        result == PlaylistSpeedSheet.unpinSentinel ? null : result,
      ),
    );
  }

  void _showPlaylistOptions(Playlist playlist) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return SheetShell(
          showDivider: false,
          header: const SizedBox.shrink(),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SheetAction(
                icon: Icons.drive_file_rename_outline_rounded,
                label: 'Rename',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _renamePlaylist(playlist);
                },
              ),
              SheetAction(
                icon: Icons.speed_rounded,
                label: playlist.pinnedSpeed == null
                    ? 'Pin speed'
                    : 'Pin speed · ${playlist.pinnedSpeed!.toStringAsFixed(2)}×',
                iconColor: AppColors.accent,
                labelColor: AppColors.accent,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pinSpeed(playlist);
                },
              ),
              SheetAction(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                iconColor: AppColors.destructive,
                labelColor: AppColors.destructive,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _playlistsBloc.add(DeletePlaylist(playlist.id));
                },
              ),
              SizedBox(height: 8.h),
            ],
          ),
        );
      },
    );
  }

  bool _matchesQuery(String name) =>
      _query.isEmpty || name.toLowerCase().contains(_query);

  Widget _buildBadge({
    required IconData icon,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      width: 52.w,
      height: 52.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Icon(icon, size: 24.sp, color: foreground),
    );
  }

  Widget _buildRow({
    required Widget thumbnail,
    required String name,
    required int songCount,
    required VoidCallback onTap,
    double? pinnedSpeed,
    VoidCallback? onMoreTap,
    Widget? trailingChevron,
  }) {
    final String countText = '$songCount track${songCount == 1 ? '' : 's'}';
    final String subtitle = pinnedSpeed == null
        ? countText
        : '$countText · all ${pinnedSpeed.toStringAsFixed(2)}×';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
        child: Row(
          children: <Widget>[
            thumbnail,
            SizedBox(width: 13.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: pinnedSpeed == null
                          ? AppColors.textSecondary
                          : AppColors.accent,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            if (trailingChevron != null) trailingChevron,
            if (onMoreTap != null)
              IconButton(
                onPressed: onMoreTap,
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20.sp,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
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
              onPressed: _createPlaylist,
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
                Icons.playlist_add_rounded,
                size: 18.sp,
                color: AppColors.accent,
              ),
              label: Text(
                'New Playlist',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: BlocBuilder<PlaylistsBloc, PlaylistsState>(
            builder: (BuildContext context, PlaylistsState state) {
              final List<Playlist> playlists = _playlistsBloc
                  .stateData
                  .playlists
                  .where((Playlist p) => _matchesQuery(p.name))
                  .toList();

              return BlocBuilder<SongsBloc, SongsState>(
                builder: (BuildContext context, SongsState songsState) {
                  return ListView(
                    children: <Widget>[
                      if (_matchesQuery('My Favourites'))
                        _buildRow(
                          thumbnail: _buildBadge(
                            icon: Icons.favorite_rounded,
                            background: AppColors.badgePinkBg,
                            foreground: AppColors.badgePinkIcon,
                          ),
                          name: 'My Favourites',
                          songCount: _songsBloc.stateData.favorites.length,
                          onTap: () => context.push(
                            AppRouter.playlistDetail(
                              BuiltInPlaylists.favourites,
                            ),
                          ),
                          trailingChevron: Icon(
                            Icons.chevron_right_rounded,
                            size: 16.sp,
                            color: AppColors.disabled,
                          ),
                        ),
                      if (_matchesQuery('Recently Played'))
                        _buildRow(
                          thumbnail: _buildBadge(
                            icon: Icons.access_time_filled_rounded,
                            background: AppColors.badgeTanBg,
                            foreground: AppColors.badgeTanIcon,
                          ),
                          name: 'Recently Played',
                          songCount: _songsBloc.stateData.recentlyPlayed.length,
                          onTap: () => context.push(
                            AppRouter.playlistDetail(
                              BuiltInPlaylists.recentlyPlayed,
                            ),
                          ),
                          trailingChevron: Icon(
                            Icons.chevron_right_rounded,
                            size: 16.sp,
                            color: AppColors.disabled,
                          ),
                        ),
                      for (final Playlist playlist in playlists)
                        _buildRow(
                          thumbnail: _buildBadge(
                            icon: Icons.queue_music_rounded,
                            background: AppColors.iconBg,
                            foreground: AppColors.iconColor,
                          ),
                          name: playlist.name,
                          songCount: playlist.songIds.length,
                          pinnedSpeed: playlist.pinnedSpeed,
                          onTap: () => context.push(
                            AppRouter.playlistDetail(playlist.id),
                          ),
                          onMoreTap: () => _showPlaylistOptions(playlist),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
