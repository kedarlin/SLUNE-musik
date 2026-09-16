import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive/hive.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/songs/songs_bloc.dart';
import '../core/theme/app_colors.dart';
import '../models/folder_model.dart';
import 'hierarchical_folder_page.dart';
import 'song_list_detail_page.dart';

/// Two folder-browsing modes, chosen in Settings ("Folder browsing"):
/// linear (every folder that directly contains a song, flattened - the
/// default) or hierarchical (the real nested tree, drilling down folder by
/// folder via [HierarchicalFolderPage]).
class FoldersPage extends StatefulWidget {
  const FoldersPage({required this.searchController, super.key});

  final TextEditingController searchController;

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage>
    with AutomaticKeepAliveClientMixin {
  late SongsBloc _songsBloc;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _songsBloc = BlocProvider.of<SongsBloc>(context);
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

              return Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 4.h),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${folders.length} folder${folders.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: folders.length,
                      itemBuilder: (BuildContext context, int index) {
                        final FolderModel folder = folders[index];
                        return ListTile(
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
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            size: 16.sp,
                            color: AppColors.disabled,
                          ),
                          contentPadding: EdgeInsets.only(
                            left: 18.w,
                            right: 12.w,
                          ),
                          onTap: () => _openFolder(folder),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
