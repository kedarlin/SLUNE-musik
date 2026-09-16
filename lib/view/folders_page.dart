import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive/hive.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/songs/songs_bloc.dart';
import '../core/theme/app_colors.dart';
import '../models/folder_model.dart';
import '../widgets/playlists/playlist_thumbnail.dart';
import 'hierarchical_folder_page.dart';
import 'song_list_detail_page.dart';

/// Two folder-browsing modes, chosen in Settings ("Folder browsing"):
/// linear (every folder that directly contains a song, flattened - the
/// default) or hierarchical (the real nested tree, drilling down folder by
/// folder via [HierarchicalFolderPage]).
class FoldersPage extends StatefulWidget {
  const FoldersPage({super.key});

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage>
    with AutomaticKeepAliveClientMixin {
  late SongsBloc _songsBloc;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _songsBloc = BlocProvider.of<SongsBloc>(context);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFolder(FolderModel folder) {
    final List<SongModel> songs = _songsBloc.songsInFolder(folder.path);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SongListDetailPage(
          title: folder.name,
          subtitle: '${songs.length} Song${songs.length == 1 ? '' : 's'}',
          songs: songs,
          accentColor: AppColors.accent,
        ),
      ),
    );
  }

  bool get _hierarchical =>
      Hive.box<dynamic>(
            'settings',
          ).get('hierarchicalFolders', defaultValue: false)
          as bool;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_hierarchical) {
      final String? root = _songsBloc.folderRoot;
      return root == null
          ? const Center(
              child: Text(
                'No folders found',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : FolderLevelListView(path: root);
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: SizedBox(
            height: 44.h,
            child: SearchBar(
              controller: _searchController,
              leading: Icon(
                Icons.search_rounded,
                size: 20.sp,
                color: AppColors.textSecondary,
              ),
              hintText: 'Search Folders...',
              hintStyle: WidgetStatePropertyAll<TextStyle>(
                TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
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
        Expanded(
          child: BlocBuilder<SongsBloc, SongsState>(
            builder: (BuildContext context, SongsState state) {
              final List<FolderModel> folders = _songsBloc.stateData.folders
                  .where(
                    (FolderModel f) =>
                        _query.isEmpty || f.name.toLowerCase().contains(_query),
                  )
                  .toList();

              if (folders.isEmpty) {
                return const Center(
                  child: Text(
                    'No folders found',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return ListView.builder(
                itemCount: folders.length,
                itemBuilder: (BuildContext context, int index) {
                  final FolderModel folder = folders[index];
                  return ListTile(
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
                    onTap: () => _openFolder(folder),
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
