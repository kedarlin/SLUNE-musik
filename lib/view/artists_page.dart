import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/songs/songs_bloc.dart';
import '../core/theme/app_colors.dart';
import '../widgets/playlists/playlist_thumbnail.dart';
import 'song_list_detail_page.dart';

class ArtistsPage extends StatefulWidget {
  const ArtistsPage({required this.searchController, super.key});

  final TextEditingController searchController;

  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage>
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

              return Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 4.h),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${artists.length} artist${artists.length == 1 ? '' : 's'}',
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
                      itemCount: artists.length,
                      itemBuilder: (BuildContext context, int index) {
                        final ArtistModel artist = artists[index];
                        final int tracks = artist.numberOfTracks ?? 0;
                        final int albums = artist.numberOfAlbums ?? 0;
                        return ListTile(
                          leading: PlaylistThumbnail.artist(size: 48.w),
                          title: Text(
                            artist.artist,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          subtitle: Text(
                            '$tracks track${tracks == 1 ? '' : 's'} · '
                            '$albums album${albums == 1 ? '' : 's'}',
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
                          onTap: () => _openArtist(artist),
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
