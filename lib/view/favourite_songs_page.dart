import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../core/bloc/songs_bloc/songs_bloc.dart';
import '../core/common_widgets.dart/loader_widget.dart';
import '../core/common_widgets.dart/song_options_sheet.dart';
import '../core/common_widgets.dart/song_tile.dart';

class FavouriteSongsPage extends StatefulWidget {
  const FavouriteSongsPage({super.key});

  @override
  State<FavouriteSongsPage> createState() => _FavouriteSongsPageState();
}

class _FavouriteSongsPageState extends State<FavouriteSongsPage>
    with AutomaticKeepAliveClientMixin {
  late SongsBloc _songsBloc;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _songsBloc = BlocProvider.of<SongsBloc>(context);
    // Favourites are derived from the library - make sure it is loaded
    // (no-ops if it already is), then resolve the favourite ids.
    _songsBloc.add(FetchSongs());
    _songsBloc.add(GetAllFavorites());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    return Column(
      children: <Widget>[
        BlocBuilder<SongsBloc, SongsState>(
          builder: (BuildContext context, SongsState state) {
            if (state is FetchSongsLoading) {
              return const Center(child: CustomLoader());
            } else if (_songsBloc.stateData.favorites.isEmpty) {
              return const Center(child: Text('No favourite songs found'));
            }
            return Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _songsBloc.add(GetAllFavorites());
                },
                child: ListView.builder(
                  itemCount: _songsBloc.stateData.favorites.length,
                  itemBuilder: (BuildContext context, int index) {
                    final List<SongModel> list = _songsBloc.stateData.favorites;
                    final SongModel song = list[index];

                    return SongTile(
                      song: song,
                      queue: list,
                      index: index,
                      onMoreTap: () {
                        SongOptionsSheet.show(
                          context,
                          song: song,
                          isFavorite: true,
                          onToggleFavorite: () {
                            _songsBloc.add(RemoveFromFavorites(song.id));
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
