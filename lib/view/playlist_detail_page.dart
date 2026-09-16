import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/music_controller/music_controller_bloc.dart';
import '../bloc/playlists/playlists_bloc.dart';
import '../bloc/songs/songs_bloc.dart';
import '../core/app_constants/playlist_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/utils.dart';
import '../models/playlist_model.dart';
import '../widgets/songs/song_options_sheet.dart';
import '../widgets/songs/song_tile.dart';

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

    final double? pinnedSpeed = _playlist?.pinnedSpeed;
    if (pinnedSpeed != null) {
      _musicControllerBloc.add(SpeedChanged(pinnedSpeed));
    }

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
                  if (songs.isNotEmpty) _buildActionRow(songs),
                  Expanded(child: _buildSongList(songs)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(int songCount) {
    return Padding(
      padding: EdgeInsets.fromLTRB(6.w, 8.h, 18.w, 4.h),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.arrow_back_rounded,
              size: 22.sp,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  '$songCount track${songCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(List<SongModel> songs) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 4.h, 18.w, 12.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: Size(0, 46.h),
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13.r),
                ),
              ),
              onPressed: () => _playAll(songs),
              icon: Icon(
                Icons.play_arrow_rounded,
                size: 18.sp,
                color: Colors.white,
              ),
              label: Text(
                'Play all ${songs.length}',
                style: TextStyle(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Container(
            width: 46.h,
            height: 46.h,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(13.r),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () =>
                  _musicControllerBloc.add(ShuffleAll(songs)),
              icon: Icon(
                Icons.shuffle_rounded,
                size: 19.sp,
                color: AppColors.textPrimary,
              ),
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
        queueSpeed: _playlist?.pinnedSpeed,
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
