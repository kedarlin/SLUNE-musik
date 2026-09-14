import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/songs_bloc/songs_bloc.dart';
import '../services/lyrics_repository.dart';
import '../services/songs_channel.dart';

/// Renames [song]'s underlying audio file via MediaStore (title + display
/// name), remaps any saved lyrics to the new content key - lyrics are keyed
/// in part by title, so a rename would otherwise orphan them - and
/// refreshes [songsBloc] so the new name shows up everywhere. Returns
/// whether it succeeded.
///
/// Known limitation: if [song] is the one currently loaded in
/// MusicControllerBloc's queue, that in-memory copy (and the native
/// player's own metadata) keeps showing the old title until the next song
/// change or app restart - only the library list and lyrics mapping are
/// refreshed immediately here.
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
