import 'package:on_audio_query/on_audio_query.dart';

import '../../bloc/songs/songs_bloc.dart';
import '../../service/lyrics_repository.dart';
import '../../service/songs_channel.dart';

Future<bool> performSongRename({
  required SongModel song,
  required String newTitle,
  required SongsBloc songsBloc,
}) async {
  final String trimmed = newTitle.trim();
  if (trimmed.isEmpty || trimmed == song.title) {
    return false;
  }

  final bool ok = await SongsChannel.instance.renameSong(
    songId: song.id,
    newTitle: trimmed,
  );
  if (!ok) {
    return false;
  }

  await LyricsRepository.instance.remapForRename(song, trimmed);
  songsBloc.add(FetchSongs(forceFetch: true));
  return true;
}
