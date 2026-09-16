import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/songs/songs_bloc.dart';
import '../core/theme/app_colors.dart';
import 'song_list_detail_page.dart';

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({required this.searchController, super.key});

  final TextEditingController searchController;

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage>
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

  void _openAlbum(AlbumModel album) {
    final List<SongModel> songs = _songsBloc.stateData.songs
        .where((SongModel s) => s.albumId == album.id)
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SongListDetailPage(
          title: album.album,
          subtitle: album.artist ?? 'Unknown Artist',
          songs: songs,
          accentColor: AppColors.accent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: <Widget>[
        Expanded(
          child: BlocBuilder<SongsBloc, SongsState>(
            builder: (BuildContext context, SongsState state) {
              final List<AlbumModel> albums = _songsBloc.stateData.albums
                  .where(
                    (AlbumModel a) =>
                        _query.isEmpty ||
                        a.album.toLowerCase().contains(_query),
                  )
                  .toList();

              if (albums.isEmpty) {
                return const Center(
                  child: Text(
                    'No albums found',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 8.h),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${albums.length} album${albums.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.fromLTRB(18.w, 4.h, 18.w, 20.h),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 18.h,
                            crossAxisSpacing: 16.w,
                            childAspectRatio: 0.78,
                          ),
                      itemCount: albums.length,
                      itemBuilder: (BuildContext context, int index) {
                        final AlbumModel album = albums[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(12.r),
                          onTap: () => _openAlbum(album),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              AspectRatio(
                                aspectRatio: 1,
                                child: QueryArtworkWidget(
                                  id: album.id,
                                  type: ArtworkType.ALBUM,
                                  artworkBorder: BorderRadius.circular(12.r),
                                  nullArtworkWidget: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.iconBg,
                                      borderRadius: BorderRadius.circular(
                                        12.r,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.album_rounded,
                                      size: 30.sp,
                                      color: AppColors.iconColor,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 9.h),
                              Text(
                                album.album,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                '${album.numOfSongs} track${album.numOfSongs == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
