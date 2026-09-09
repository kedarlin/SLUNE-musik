import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../core/app_constants/playlist_constants.dart';
import '../core/bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import '../core/bloc/playlists_bloc/playlists_bloc.dart';
import '../core/bloc/songs_bloc/songs_bloc.dart';
import '../core/common_widgets.dart/playlist_thumbnail.dart';
import '../core/common_widgets.dart/song_options_sheet.dart';
import '../core/common_widgets.dart/song_tile.dart';
import '../core/models/playlist_model.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/utils.dart';

class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({required this.playlistId, super.key});

  final String playlistId;

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  late PlaylistsBloc _playlistsBloc;
  late SongsBloc _songsBloc;
  late MusicControllerBloc _musicControllerBloc;

  @override
  void initState() {
    super.initState();
    _playlistsBloc = BlocProvider.of<PlaylistsBloc>(context);
    _songsBloc = BlocProvider.of<SongsBloc>(context);
    _musicControllerBloc = BlocProvider.of<MusicControllerBloc>(context);
  }

  bool get _isFavourites => widget.playlistId == BuiltInPlaylists.favourites;

  bool get _isRecentlyPlayed =>
      widget.playlistId == BuiltInPlaylists.recentlyPlayed;

  bool get _isUserPlaylist => !BuiltInPlaylists.isBuiltIn(widget.playlistId);

  Playlist? get _playlist {
    for (final Playlist playlist in _playlistsBloc.stateData.playlists) {
      if (playlist.id == widget.playlistId) {
        return playlist;
      }
    }
    return null;
  }

  String get _title {
    if (_isFavourites) {
      return 'My Favourites';
    }
    if (_isRecentlyPlayed) {
      return 'Recently Played';
    }
    return _playlist?.name ?? 'Playlist';
  }

  Color get _accentColor {
    if (_isFavourites) {
      return PlaylistColors.favouritesIcon;
    }
    if (_isRecentlyPlayed) {
      return PlaylistColors.recentIcon;
    }
    return PlaylistColors.userIcon;
  }

  Widget get _thumbnail {
    if (_isFavourites) {
      return PlaylistThumbnail.favourites(size: 64.w);
    }
    if (_isRecentlyPlayed) {
      return PlaylistThumbnail.recentlyPlayed(size: 64.w);
    }
    return PlaylistThumbnail.user(size: 64.w);
  }

  List<SongModel> get _songs {
    if (_isFavourites) {
      return _songsBloc.stateData.favorites;
    }
    if (_isRecentlyPlayed) {
      return _songsBloc.stateData.recentlyPlayed;
    }

    final Playlist? playlist = _playlist;
    if (playlist == null) {
      return <SongModel>[];
    }

    return playlist.songIds
        .map((int id) => _songsBloc.stateData.songById[id])
        .whereType<SongModel>()
        .toList();
  }

  void _playAll(List<SongModel> songs) {
    if (songs.isEmpty) {
      return;
    }

    _musicControllerBloc.add(
      InitAudio(song: songs.first, index: 0, queue: songs),
    );

    Utils.openPlayerBottomSheet(context, songs.first, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<PlaylistsBloc, PlaylistsState>(
        bloc: _playlistsBloc,
        builder: (BuildContext context, PlaylistsState state) {
          return BlocBuilder<SongsBloc, SongsState>(
            bloc: _songsBloc,
            builder: (BuildContext context, SongsState songsState) {
              final List<SongModel> songs = _songs;

              return Column(
                children: <Widget>[
                  _buildHeader(songs.length),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20.r),
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                16.w,
                                16.h,
                                16.w,
                                8.h,
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () => _playAll(songs),
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: AppColors.accent,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 22.w,
                                    vertical: 14.h,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28.r),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 24.sp,
                                  color: AppColors.white,
                                ),
                                label: Text(
                                  'Play All',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(child: _buildSongList(songs)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(int songCount) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            _accentColor.withValues(alpha: 0.85),
            _accentColor.withValues(alpha: 0.30),
          ],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        bottom: 28.h,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  size: 24.sp,
                  color: AppColors.white,
                ),
              ),
              const Spacer(),
            ],
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: <Widget>[
                _thumbnail,
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _title,
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '$songCount Song${songCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.85),
                          fontSize: 15.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongList(List<SongModel> songs) {
    if (songs.isEmpty) {
      return Center(
        child: Text(
          'No songs in this playlist yet',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      );
    }

    Widget buildTile(int index) {
      final SongModel song = songs[index];
      final bool isFavorite = _songsBloc.stateData.favoriteIds.contains(
        song.id,
      );

      return SongTile(
        key: ValueKey<String>('${song.id}-$index'),
        song: song,
        queue: songs,
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
            onRemoveFromPlaylist: _isUserPlaylist
                ? () => _playlistsBloc.add(
                    RemoveSongFromPlaylist(widget.playlistId, song.id),
                  )
                : null,
          );
        },
      );
    }

    if (!_isUserPlaylist) {
      return ListView.builder(
        itemCount: songs.length,
        itemBuilder: (BuildContext context, int index) => buildTile(index),
      );
    }

    return ReorderableListView.builder(
      itemCount: songs.length,
      onReorder: (int oldIndex, int newIndex) {
        _playlistsBloc.add(
          ReorderSongsInPlaylist(widget.playlistId, oldIndex, newIndex),
        );
      },
      itemBuilder: (BuildContext context, int index) => buildTile(index),
    );
  }
}
