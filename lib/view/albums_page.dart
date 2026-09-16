import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/songs/songs_bloc.dart';
import '../core/theme/app_colors.dart';
import 'song_list_detail_page.dart';

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage>
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
              hintText: 'Search Albums...',
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

              return ListView.builder(
                itemCount: albums.length,
                itemBuilder: (BuildContext context, int index) {
                  final AlbumModel album = albums[index];
                  return ListTile(
                    leading: QueryArtworkWidget(
                      id: album.id,
                      type: ArtworkType.ALBUM,
                      artworkHeight: 48.w,
                      artworkWidth: 48.w,
                      artworkBorder: BorderRadius.circular(8.r),
                      nullArtworkWidget: Container(
                        height: 48.w,
                        width: 48.w,
                        decoration: BoxDecoration(
                          color: AppColors.iconBg,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          Icons.album_rounded,
                          size: 22.sp,
                          color: AppColors.iconColor,
                        ),
                      ),
                    ),
                    title: Text(
                      album.album,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15.sp,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    subtitle: Text(
                      '${album.artist ?? 'Unknown Artist'} • ${album.numOfSongs} Song${album.numOfSongs == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.sp,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    contentPadding: EdgeInsets.only(left: 16.w, right: 4.w),
                    onTap: () => _openAlbum(album),
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
