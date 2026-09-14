import 'dart:async';

import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// Playback state pushed from PlayerChannel (Kotlin) on every player event
/// and on a 200ms poll while a controller is connected.
class PlayerState {
  const PlayerState({
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.currentIndex,
    required this.hasNext,
    required this.hasPrevious,
  });

  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final int currentIndex;
  final bool hasNext;
  final bool hasPrevious;
}

/// Thin wrapper over the muxic/player MethodChannel + EventChannel, talking
/// to the Media3 MediaController connected to PlaybackService. Replaces
/// lib/ffi/audio_engine.dart (the native Oboe engine's FFI binding).
///
/// Every command is fire-and-forget from the bloc's point of view: failures
/// are swallowed here rather than thrown, matching the old FFI methods'
/// non-throwing void/bool contract, so a missed platform call never leaves
/// MusicControllerBloc's event handlers half-run.
class PlayerClient {
  PlayerClient._();

  static final PlayerClient instance = PlayerClient._();

  static const MethodChannel _method = MethodChannel('muxic/player');
  static const EventChannel _events = EventChannel('muxic/player_events');

  Stream<PlayerState>? _stateStream;

  Stream<PlayerState> get stateStream {
    return _stateStream ??= _events.receiveBroadcastStream().map((
      dynamic event,
    ) {
      final Map<dynamic, dynamic> map = event as Map<dynamic, dynamic>;
      return PlayerState(
        position: Duration(milliseconds: map['position'] as int? ?? 0),
        duration: Duration(milliseconds: map['duration'] as int? ?? 0),
        isPlaying: map['isPlaying'] as bool? ?? false,
        currentIndex: map['currentIndex'] as int? ?? 0,
        hasNext: map['hasNext'] as bool? ?? false,
        hasPrevious: map['hasPrevious'] as bool? ?? false,
      );
    });
  }

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      await _method.invokeMethod(method, args);
    } on PlatformException {
      // Swallowed by design - see class doc. The EventChannel stream is the
      // source of truth for state; a dropped command just means the UI
      // won't see the expected state change, rather than the bloc crashing.
    } on MissingPluginException {
      // Can happen very early during hot restart; same handling.
    }
  }

  static Map<String, dynamic> songToQueueItem(SongModel song) {
    return <String, dynamic>{
      'id': song.id,
      'uri': song.data,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'albumId': song.albumId,
    };
  }

  Future<void> setQueue({
    required List<SongModel> songs,
    required int startIndex,
    bool playWhenReady = true,
  }) {
    return _invoke('setQueue', <String, dynamic>{
      'items': songs.map(songToQueueItem).toList(),
      'startIndex': startIndex,
      'playWhenReady': playWhenReady,
    });
  }

  Future<void> play() => _invoke('play');

  Future<void> pause() => _invoke('pause');

  Future<void> stop() => _invoke('stop');

  Future<void> seekTo(Duration position) =>
      _invoke('seekTo', <String, dynamic>{'positionMs': position.inMilliseconds});

  Future<void> next() => _invoke('next');

  Future<void> previous() => _invoke('previous');

  Future<void> jumpTo(int index) =>
      _invoke('jumpTo', <String, dynamic>{'index': index});

  Future<void> setSpeed(double speed) =>
      _invoke('setSpeed', <String, dynamic>{'speed': speed});

  Future<void> setPitch(double pitch) =>
      _invoke('setPitch', <String, dynamic>{'pitch': pitch});

  Future<void> setShuffle(bool enabled) =>
      _invoke('setShuffle', <String, dynamic>{'enabled': enabled});

  /// [mode] matches RepeatMode's enum index (off=0, one=1, all=2), which is
  /// identical to Media3's own REPEAT_MODE_OFF/ONE/ALL constants.
  Future<void> setRepeat(int mode) =>
      _invoke('setRepeat', <String, dynamic>{'mode': mode});

  Future<void> addNext(SongModel song) =>
      _invoke('addNext', <String, dynamic>{'item': songToQueueItem(song)});

  Future<void> addLater(SongModel song) =>
      _invoke('addLater', <String, dynamic>{'item': songToQueueItem(song)});

  /// Replaces the whole queue with [songs] while leaving the currently-playing
  /// track (which must be at [currentIndex] in the new list) untouched, so it
  /// keeps playing without restarting. Used for the shuffle toggle. Falls back
  /// to a full [setQueue]-style reset natively if the current track isn't at
  /// [currentIndex] in the new list.
  Future<void> reorderKeepingCurrent({
    required List<SongModel> songs,
    required int currentIndex,
  }) {
    return _invoke('reorderKeepingCurrent', <String, dynamic>{
      'items': songs.map(songToQueueItem).toList(),
      'currentIndex': currentIndex,
    });
  }

  Future<void> moveItem(int from, int to) =>
      _invoke('moveItem', <String, dynamic>{'from': from, 'to': to});

  Future<void> removeItem(int index) =>
      _invoke('removeItem', <String, dynamic>{'index': index});

  Future<void> clearQueue() => _invoke('clearQueue');

  // --- audiofx panel ----------------------------------------------------
  //
  // These are intentionally primitive: the native AudioEffectsController
  // owns how each is realised (android.media.audiofx today, could change),
  // so this contract never has to change.

  Future<void> setEqEnabled(bool enabled) =>
      _invoke('setEqEnabled', <String, dynamic>{'enabled': enabled});

  /// Applies a device Equalizer preset (or -1 for custom) and returns the
  /// resulting per-band curve in millibels, so the UI sliders can follow it.
  /// Empty list if the query fails.
  Future<List<int>> setEqPreset(int preset) async {
    try {
      final dynamic raw = await _method.invokeMethod<dynamic>(
        'setEqPreset',
        <String, dynamic>{'preset': preset},
      );
      if (raw is List) {
        return raw.map<int>((dynamic e) => e as int).toList();
      }
      return <int>[];
    } on PlatformException {
      return <int>[];
    } on MissingPluginException {
      return <int>[];
    }
  }

  /// [levelMb] is millibels (e.g. -1500..1500). Switches the EQ to "custom".
  Future<void> setEqBand(int band, int levelMb) =>
      _invoke('setEqBand', <String, dynamic>{'band': band, 'level': levelMb});

  /// [strength] is 0..1000.
  Future<void> setBassBoost(int strength) =>
      _invoke('setBassBoost', <String, dynamic>{'strength': strength});

  /// [strength] is 0..1000.
  Future<void> setVirtualizer(int strength) =>
      _invoke('setVirtualizer', <String, dynamic>{'strength': strength});

  /// [preset] maps 1:1 onto PresetReverb PRESET_* constants (0..6).
  Future<void> setReverb(int preset) =>
      _invoke('setReverb', <String, dynamic>{'preset': preset});

  /// What the current device's audio effect stack actually supports. Returns
  /// null if the query fails or the player isn't connected yet.
  Future<AudioFxCaps?> getFxCaps() async {
    try {
      final dynamic raw = await _method.invokeMethod<dynamic>('getFxCaps');
      if (raw is! Map) {
        return null;
      }
      return AudioFxCaps.fromMap(Map<dynamic, dynamic>.from(raw));
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// Device audio-effect capabilities, queried from the native Equalizer /
/// BassBoost / Virtualizer / PresetReverb once playback is live.
class AudioFxCaps {
  const AudioFxCaps({
    required this.eqAvailable,
    required this.bandCount,
    required this.centerFreqsHz,
    required this.minLevelMb,
    required this.maxLevelMb,
    required this.presetNames,
    required this.bassBoostAvailable,
    required this.virtualizerAvailable,
    required this.reverbAvailable,
  });

  factory AudioFxCaps.fromMap(Map<dynamic, dynamic> map) {
    final List<int> freqsMilliHz =
        (map['centerFreqsMilliHz'] as List<dynamic>? ?? <dynamic>[])
            .map<int>((dynamic e) => e as int)
            .toList();
    return AudioFxCaps(
      eqAvailable: map['eqAvailable'] as bool? ?? false,
      bandCount: map['bandCount'] as int? ?? 0,
      centerFreqsHz: freqsMilliHz.map((int mHz) => mHz ~/ 1000).toList(),
      minLevelMb: map['minLevelMb'] as int? ?? -1500,
      maxLevelMb: map['maxLevelMb'] as int? ?? 1500,
      presetNames: (map['presetNames'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => e as String)
          .toList(),
      bassBoostAvailable: map['bassBoostAvailable'] as bool? ?? false,
      virtualizerAvailable: map['virtualizerAvailable'] as bool? ?? false,
      reverbAvailable: map['reverbAvailable'] as bool? ?? false,
    );
  }

  final bool eqAvailable;
  final int bandCount;
  final List<int> centerFreqsHz;
  final int minLevelMb;
  final int maxLevelMb;
  final List<String> presetNames;
  final bool bassBoostAvailable;
  final bool virtualizerAvailable;
  final bool reverbAvailable;
}
