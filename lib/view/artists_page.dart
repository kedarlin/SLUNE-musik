import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/songs/songs_bloc.dart';
import '../core/theme/app_colors.dart';
import '../widgets/playlists/playlist_thumbnail.dart';
import 'song_list_detail_page.dart';

class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});

  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage>
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

  void _openArtist(ArtistModel artist) {
    final List<SongModel> songs = _songsBloc.stateData.songs
        .where((SongModel s) => s.artistId == artist.id)
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SongListDetailPage(
          title: artist.artist,
          subtitle: '${songs.length} Song${songs.length == 1 ? '' : 's'}',
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
              hintText: 'Search Artists...',
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
              final List<ArtistModel> artists = _songsBloc.stateData.artists
                  .where(
                    (ArtistModel a) =>
                        _query.isEmpty ||
                        a.artist.toLowerCase().contains(_query),
                  )
                  .toList();

              if (artists.isEmpty) {
                return const Center(
                  child: Text(
                    'No artists found',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return ListView.builder(
                itemCount: artists.length,
                itemBuilder: (BuildContext context, int index) {
                  final ArtistModel artist = artists[index];
                  return ListTile(
                    leading: PlaylistThumbnail.artist(size: 44.w),
                    title: Text(
                      artist.artist,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15.sp,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    subtitle: Text(
                      '${artist.numberOfTracks ?? 0} Song${artist.numberOfTracks == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.sp,
                      ),
                    ),
                    contentPadding: EdgeInsets.only(left: 16.w, right: 4.w),
                    onTap: () => _openArtist(artist),
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
