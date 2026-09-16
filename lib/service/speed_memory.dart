import 'package:hive/hive.dart';

/// Optional per-track playback speed memory (Settings > "Remember speed per
/// track"). When enabled, each song reopens at whatever speed it was last
/// played at instead of the app's current session speed. Stored in the
/// existing 'settings' Hive box, keyed by song id - no separate box needed.
class SpeedMemory {
  SpeedMemory._();

  static const String _enabledKey = 'rememberSpeedPerTrack';
  static const String _mapKey = 'speedPerTrackMap';

  static Box<dynamic> get _box => Hive.box<dynamic>('settings');

  static bool get enabled => _box.get(_enabledKey, defaultValue: false) as bool;

  static set enabled(bool value) => _box.put(_enabledKey, value);

  static double? speedFor(int songId) {
    final Map<dynamic, dynamic>? map =
        _box.get(_mapKey) as Map<dynamic, dynamic>?;
    final dynamic value = map?[songId.toString()];
    return value is num ? value.toDouble() : null;
  }

  static void remember(int songId, double speed) {
    if (!enabled) {
      return;
    }
    final Map<dynamic, dynamic> map = Map<dynamic, dynamic>.from(
      _box.get(_mapKey, defaultValue: <dynamic, dynamic>{})
          as Map<dynamic, dynamic>,
    );
    map[songId.toString()] = speed;
    _box.put(_mapKey, map);
  }
}
