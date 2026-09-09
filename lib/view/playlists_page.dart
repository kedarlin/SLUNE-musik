import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../core/app_constants/playlist_constants.dart';
import '../core/bloc/playlists_bloc/playlists_bloc.dart';
import '../core/bloc/songs_bloc/songs_bloc.dart';
import '../core/common_widgets.dart/create_playlist_sheet.dart';
import '../core/common_widgets.dart/playlist_thumbnail.dart';
import '../core/common_widgets.dart/sheet_action.dart';
import '../core/models/playlist_model.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_colors.dart';

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  late PlaylistsBloc _playlistsBloc;
  late SongsBloc _songsBloc;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _playlistsBloc = BlocProvider.of<PlaylistsBloc>(context);
    _songsBloc = BlocProvider.of<SongsBloc>(context);
    _playlistsBloc.add(LoadPlaylists());

    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createPlaylist() async {
    final String? name = await CreatePlaylistSheet.show(context);

    if (name != null && name.isNotEmpty) {
      _playlistsBloc.add(CreatePlaylist(name));
    }
  }

  Future<void> _renamePlaylist(Playlist playlist) async {
    final String? name = await CreatePlaylistSheet.show(
      context,
      title: 'Rename Playlist',
      actionLabel: 'Save',
      initialValue: playlist.name,
    );

    if (name != null && name.isNotEmpty) {
      _playlistsBloc.add(RenamePlaylist(playlist.id, name));
    }
  }

  void _showPlaylistOptions(Playlist playlist) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(height: 8.h),
            SheetAction(
              icon: Icons.drive_file_rename_outline_rounded,
              label: 'Rename',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _renamePlaylist(playlist);
              },
            ),
            SheetAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _playlistsBloc.add(DeletePlaylist(playlist.id));
              },
            ),
            SizedBox(height: 8.h),
          ],
        );
      },
    );
  }

  bool _matchesQuery(String name) =>
      _query.isEmpty || name.toLowerCase().contains(_query);

  Widget _buildRow({
    required Widget thumbnail,
    required String name,
    required int songCount,
    required VoidCallback onTap,
    VoidCallback? onMoreTap,
  }) {
    return ListTile(
      leading: thumbnail,
      title: Text(
        name,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 15.sp),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: Text(
        '$songCount Song${songCount == 1 ? '' : 's'}',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
      ),
      contentPadding: EdgeInsets.only(left: 16.w, right: 4.w),
      onTap: onTap,
      trailing: onMoreTap == null
          ? null
          : IconButton(
              onPressed: onMoreTap,
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_vert_rounded,
                size: 22.sp,
                color: AppColors.textSecondary,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            spacing: 8.w,
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 44.h,
                  child: SearchBar(
                    controller: _searchController,
                    leading: Icon(
                      Icons.search_rounded,
                      size: 20.sp,
                      color: AppColors.textSecondary,
                    ),
                    hintText: 'Search Playlists...',
                    hintStyle: WidgetStatePropertyAll<TextStyle>(
                      TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                      ),
                    ),
                    shadowColor: const WidgetStatePropertyAll<Color>(
                      AppColors.transparent,
                    ),
                    backgroundColor: const WidgetStatePropertyAll<Color>(
                      AppColors.surface,
                    ),
                    padding: WidgetStatePropertyAll<EdgeInsets>(
                      EdgeInsets.symmetric(horizontal: 12.w),
                    ),
                    textStyle: WidgetStatePropertyAll<TextStyle>(
                      TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    shape: WidgetStatePropertyAll<OutlinedBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _createPlaylist,
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
            ],
          ),
        ),
        Expanded(
          child: BlocBuilder<PlaylistsBloc, PlaylistsState>(
            builder: (BuildContext context, PlaylistsState state) {
              final List<Playlist> playlists = _playlistsBloc.stateData.playlists
                  .where((Playlist p) => _matchesQuery(p.name))
                  .toList();

              return BlocBuilder<SongsBloc, SongsState>(
                builder: (BuildContext context, SongsState songsState) {
                  return ListView(
                    children: <Widget>[
                      if (_matchesQuery('My Favourites'))
                        _buildRow(
                          thumbnail: PlaylistThumbnail.favourites(),
                          name: 'My Favourites',
                          songCount: _songsBloc.stateData.favorites.length,
                          onTap: () => context.push(
                            AppRouter.playlistDetail(
                              BuiltInPlaylists.favourites,
                            ),
                          ),
                        ),
                      if (_matchesQuery('Recently Played'))
                        _buildRow(
                          thumbnail: PlaylistThumbnail.recentlyPlayed(),
                          name: 'Recently Played',
                          songCount: _songsBloc.stateData.recentlyPlayed.length,
                          onTap: () => context.push(
                            AppRouter.playlistDetail(
                              BuiltInPlaylists.recentlyPlayed,
                            ),
                          ),
                        ),
                      for (final Playlist playlist in playlists)
                        _buildRow(
                          thumbnail: PlaylistThumbnail.user(),
                          name: playlist.name,
                          songCount: playlist.songIds.length,
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
