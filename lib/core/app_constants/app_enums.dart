enum Tabs { tracks, playlists, favorite }

enum RepeatMode { off, one, all }

enum SongSortField { title, length, date, size }

enum ReverbPreset {
  none,
  smallRoom,
  mediumRoom,
  largeRoom,
  mediumHall,
  largeHall,
  plate;

  String get label {
    switch (this) {
      case ReverbPreset.none:
        return 'None';
      case ReverbPreset.smallRoom:
        return 'Small Room';
      case ReverbPreset.mediumRoom:
        return 'Medium Room';
      case ReverbPreset.largeRoom:
        return 'Large Room';
      case ReverbPreset.mediumHall:
        return 'Medium Hall';
      case ReverbPreset.largeHall:
        return 'Large Hall';
      case ReverbPreset.plate:
        return 'Plate';
    }
  }
}
