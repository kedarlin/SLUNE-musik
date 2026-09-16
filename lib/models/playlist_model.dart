class Playlist {
  Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
    this.pinnedSpeed,
  });

  factory Playlist.fromMap(Map<dynamic, dynamic> map) => Playlist(
    id: map['id'] as String,
    name: map['name'] as String,
    songIds: List<int>.from(map['songIds'] as List<dynamic>),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    pinnedSpeed: (map['pinnedSpeed'] as num?)?.toDouble(),
  );

  final String id;
  String name;
  List<int> songIds;
  final DateTime createdAt;

  /// Speed the playlist is pinned to (Playlists' "carry a speed preset as
  /// part of their identity" concept) - null means no pin, plays at
  /// whatever the current session speed is.
  double? pinnedSpeed;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    'songIds': songIds,
    'createdAt': createdAt.millisecondsSinceEpoch,
    if (pinnedSpeed != null) 'pinnedSpeed': pinnedSpeed,
  };
}
