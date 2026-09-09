class Playlist {
  Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
  });

  factory Playlist.fromMap(Map<dynamic, dynamic> map) => Playlist(
    id: map['id'] as String,
    name: map['name'] as String,
    songIds: List<int>.from(map['songIds'] as List<dynamic>),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
  );

  final String id;
  String name;
  List<int> songIds;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    'songIds': songIds,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };
}
