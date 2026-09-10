enum Tabs { tracks, playlists, favorite }

enum RepeatMode { off, one, all }

enum SongSortField { title, length, date, size }

/// The "Lofi" colouring, applied natively by LofiAudioProcessor (low-pass +
/// high-pass + short feedback delay for depth). [wetLevel] is the 0..1 value
/// handed to the processor.
enum LofiPreset {
  off,
  lofi,
  deep;

  String get label {
    switch (this) {
      case LofiPreset.off:
        return 'Off';
      case LofiPreset.lofi:
        return 'Lofi';
      case LofiPreset.deep:
        return 'Deep';
    }
  }

  double get wetLevel {
    switch (this) {
      case LofiPreset.off:
        return 0.0;
      case LofiPreset.lofi:
        return 0.6;
      case LofiPreset.deep:
        return 1.0;
    }
  }
}
