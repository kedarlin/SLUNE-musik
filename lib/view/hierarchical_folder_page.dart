import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;

import '../bloc/songs/songs_bloc.dart';
import '../core/theme/app_colors.dart';
import '../models/folder_model.dart';
import '../widgets/playlists/playlist_thumbnail.dart';
import '../widgets/songs/song_options_sheet.dart';
import '../widgets/songs/song_tile.dart';

/// One level of the real nested folder tree - shows this folder's
/// subfolders (tap to drill in further) above the songs that live directly
/// in it. Opt-in alternative to FoldersPage's flat list (see the Settings
/// "Folder browsing" toggle).
class HierarchicalFolderPage extends StatelessWidget {
  const HierarchicalFolderPage({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    final SongsBloc songsBloc = BlocProvider.of<SongsBloc>(context);

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
          p.basename(path),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: FolderLevelListView(path: path),
    );
  }
}

/// The subfolders+songs list for one folder level - shared by
/// [HierarchicalFolderPage] (pushed detail views) and [FoldersPage] (the
/// tab's own root level, which has no separate AppBar to push under).
class FolderLevelListView extends StatelessWidget {
  const FolderLevelListView({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    final SongsBloc songsBloc = BlocProvider.of<SongsBloc>(context);

    return BlocBuilder<SongsBloc, SongsState>(
      builder: (BuildContext context, SongsState state) {
        final List<FolderModel> subfolders = songsBloc.subfoldersOf(path);
        final List<SongModel> songs = songsBloc.songsInFolder(path);

        if (subfolders.isEmpty && songs.isEmpty) {
          return const Center(
            child: Text(
              'No songs found',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView(
          children: <Widget>[
            for (final FolderModel folder in subfolders)
              ListTile(
                leading: PlaylistThumbnail.folder(size: 44.w),
                title: Text(
                  folder.name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.sp,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: Text(
                  '${folder.songCount} Song${folder.songCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                  ),
                ),
                contentPadding: EdgeInsets.only(left: 16.w, right: 4.w),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        HierarchicalFolderPage(path: folder.path),
                  ),
                ),
              ),
            if (subfolders.isNotEmpty && songs.isNotEmpty)
              Divider(color: AppColors.divider, height: 1.h),
            for (int i = 0; i < songs.length; i++)
              SongTile(
                song: songs[i],
                queue: songs,
                index: i,
                onMoreTap: () {
                  final SongModel song = songs[i];
                  final bool isFavorite = songsBloc.stateData.favoriteIds
                      .contains(song.id);
                  SongOptionsSheet.show(
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
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
