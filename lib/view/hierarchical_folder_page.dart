import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;

import '../bloc/music_controller/music_controller_bloc.dart';
import '../bloc/songs/songs_bloc.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/utils.dart';
import '../models/folder_model.dart';
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
      body: FolderLevelListView(path: path, showBreadcrumb: true),
    );
  }
}

/// The subfolders+songs list for one folder level - shared by
/// [HierarchicalFolderPage] (pushed detail views) and [FoldersPage] (the
/// tab's own root level, which has no separate AppBar to push under).
class FolderLevelListView extends StatelessWidget {
  const FolderLevelListView({
    required this.path,
    this.showBreadcrumb = false,
    super.key,
  });

  final String path;
  final bool showBreadcrumb;

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

        return Column(
          children: <Widget>[
            if (showBreadcrumb) _Breadcrumb(path: path, root: songsBloc.folderRoot),
            Expanded(
              child: ListView(
                children: <Widget>[
                  for (final FolderModel folder in subfolders)
                    ListTile(
                      leading: Container(
                        width: 44.w,
                        height: 44.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.badgeGoldBg,
                          borderRadius: BorderRadius.circular(9.r),
                        ),
                        child: Icon(
                          Icons.folder_rounded,
                          size: 22.sp,
                          color: AppColors.badgeGoldIcon,
                        ),
                      ),
                      title: Text(
                        folder.name,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      subtitle: Text(
                        '${folder.songCount} track${folder.songCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: 16.sp,
                        color: AppColors.disabled,
                      ),
                      contentPadding: EdgeInsets.only(left: 18.w, right: 12.w),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              HierarchicalFolderPage(path: folder.path),
                        ),
                      ),
                    ),
                  if (subfolders.isNotEmpty && songs.isNotEmpty)
                    Divider(
                      color: AppColors.divider,
                      height: 1.h,
                      indent: 18.w,
                      endIndent: 18.w,
                    ),
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
                  SizedBox(height: songs.isEmpty ? 0 : 84.h),
                ],
              ),
            ),
            if (songs.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 18.h),
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
                        onPressed: () {
                          context.read<MusicControllerBloc>().add(
                            InitAudio(song: songs.first, index: 0, queue: songs),
                          );
                          Utils.openPlayerBottomSheet(context, songs.first, 0);
                        },
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
                        onPressed: () => context.read<MusicControllerBloc>().add(
                          ShuffleAll(songs),
                        ),
                        icon: Icon(
                          Icons.shuffle_rounded,
                          size: 19.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.path, required this.root});

  final String path;
  final String? root;

  @override
  Widget build(BuildContext context) {
    final List<String> all = p.split(path);
    final List<String> rootSegments = root == null ? <String>[] : p.split(root!);
    final List<String> relative = all.length > rootSegments.length
        ? all.sublist(rootSegments.length - 1)
        : all;
    final List<String> segments = relative.length > 3
        ? relative.sublist(relative.length - 3)
        : relative;

    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 12.h),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (int i = 0; i < segments.length; i++) ...<Widget>[
            if (i != 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Text(
                  '/',
                  style: TextStyle(
                    color: AppColors.disabled,
                    fontSize: 11.5.sp,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            Text(
              segments[i],
              style: TextStyle(
                color: i == segments.length - 1
                    ? AppColors.accent
                    : AppColors.textTertiary,
                fontSize: 11.5.sp,
                fontWeight: i == segments.length - 1
                    ? FontWeight.w600
                    : FontWeight.w500,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
