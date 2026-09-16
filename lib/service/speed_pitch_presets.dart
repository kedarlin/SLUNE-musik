import 'package:hive/hive.dart';

class SpeedPitchPreset {
  const SpeedPitchPreset({
    required this.name,
    required this.speed,
    required this.pitch,
  });

  factory SpeedPitchPreset.fromMap(Map<dynamic, dynamic> map) =>
      SpeedPitchPreset(
        name: map['name'] as String,
        speed: (map['speed'] as num).toDouble(),
        pitch: (map['pitch'] as num).toDouble(),
      );

  final String name;
  final double speed;
  final double pitch;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name,
    'speed': speed,
    'pitch': pitch,
  };
}

/// User-saved named speed+pitch presets ("Save as preset" in the Speed &
/// Pitch sheet) - stored in the existing 'settings' box, no separate box.
class SpeedPitchPresets {
  SpeedPitchPresets._();

  static const String _key = 'speedPitchPresets';

  static Box<dynamic> get _box => Hive.box<dynamic>('settings');

  static List<SpeedPitchPreset> get all {
    final List<dynamic>? raw = _box.get(_key) as List<dynamic>?;
    if (raw == null) {
      return const <SpeedPitchPreset>[];
    }
    return raw
        .map(
          (dynamic e) => SpeedPitchPreset.fromMap(e as Map<dynamic, dynamic>),
        )
        .toList();
  }

  static void save(String name, double speed, double pitch) {
    final List<SpeedPitchPreset> presets = List<SpeedPitchPreset>.from(all)
      ..removeWhere((SpeedPitchPreset p) => p.name == name)
      ..add(SpeedPitchPreset(name: name, speed: speed, pitch: pitch));
    _box.put(
      _key,
      presets.map((SpeedPitchPreset p) => p.toMap()).toList(),
    );
  }

  static void delete(String name) {
    final List<SpeedPitchPreset> presets = List<SpeedPitchPreset>.from(all)
      ..removeWhere((SpeedPitchPreset p) => p.name == name);
    _box.put(
      _key,
      presets.map((SpeedPitchPreset p) => p.toMap()).toList(),
    );
  }
}
