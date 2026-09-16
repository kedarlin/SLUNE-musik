/// A folder derived from grouping songs by their file path's parent
/// directory - on_audio_query has no native folder query, so this is
/// computed client-side in SongsBloc.
class FolderModel {
  const FolderModel({
    required this.path,
    required this.name,
    required this.songCount,
  });

  final String path;
  final String name;
  final int songCount;
}
