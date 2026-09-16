import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/songs/songs_bloc.dart';
import '../core/theme/app_colors.dart';
import '../widgets/songs/song_options_sheet.dart';
import '../widgets/songs/song_tile.dart';

/// Generic "title + list of songs" detail screen, shared by the Albums,
/// Artists and Folders tabs. Deliberately separate from PlaylistDetailPage,
/// which also carries playlist-only concepts (favourites/recently-played,
/// rename/delete, reordering) that don't apply here.
class SongListDetailPage extends StatelessWidget {
  const SongListDetailPage({
    required this.title,
    required this.subtitle,
    required this.songs,
    required this.accentColor,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<SongModel> songs;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              children: <Widget>[
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: songs.isEmpty
                ? const Center(
                    child: Text(
                      'No songs found',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : BlocBuilder<SongsBloc, SongsState>(
                    builder: (BuildContext context, SongsState state) {
                      final SongsBloc songsBloc = context.read<SongsBloc>();
                      return ListView.builder(
                        itemCount: songs.length,
                        itemBuilder: (BuildContext context, int index) {
                          final SongModel song = songs[index];
                          final bool isFavorite = songsBloc
                              .stateData
                              .favoriteIds
                              .contains(song.id);
                          return SongTile(
                            song: song,
                            queue: songs,
                            index: index,
                            onMoreTap: () => SongOptionsSheet.show(
                              context,
                              song: song,
                              isFavorite: isFavorite,
                              onToggleFavorite: () {
                                songsBloc.add(
                                  isFavorite
                                      ? RemoveFromFavorites(song.id)
                                      : AddToFavorites(song.id),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
