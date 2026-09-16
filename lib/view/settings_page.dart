import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive/hive.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../bloc/music_controller/music_controller_bloc.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_slider_theme.dart';
import '../service/model_manager.dart';
import '../service/player_client.dart';
import '../service/speed_memory.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ModelManager _models = ModelManager();
  Box<dynamic> get _settingsBox => Hive.box<dynamic>('settings');

  late bool _vocalEnhance =
      _settingsBox.get('vocalEnhanceEnabled', defaultValue: true) as bool;
  late bool _hierarchicalFolders =
      _settingsBox.get('hierarchicalFolders', defaultValue: false) as bool;
  late bool _rememberSpeedPerTrack = SpeedMemory.enabled;

  bool? _modelsReady;
  int? _modelsSizeBytes;
  int? _cacheSizeBytes;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadModelInfo();
    _loadCacheInfo();
    _loadAppVersion();
  }

  Future<void> _loadModelInfo() async {
    final bool ready = await _models.isReady();
    final List<String> paths = <String>[
      await _models.encoderPath(),
      await _models.decoderPath(),
      await _models.tokensPath(),
      await _models.vadModelPath(),
    ];
    final int size = paths.fold<int>(0, (int sum, String path) {
      final File file = File(path);
      return sum + (file.existsSync() ? file.lengthSync() : 0);
    });
    if (!mounted) {
      return;
    }
    setState(() {
      _modelsReady = ready;
      _modelsSizeBytes = size;
    });
  }

  Future<List<File>> _cacheFiles() async {
    final Directory tempDir = await getTemporaryDirectory();
    if (!tempDir.existsSync()) {
      return <File>[];
    }
    return tempDir
        .listSync()
        .whereType<File>()
        .where(
          (File f) =>
              p.basename(f.path).startsWith('lyrics_') &&
                  f.path.endsWith('.wav') ||
              f.path.endsWith('.lrc'),
        )
        .toList();
  }

  Future<void> _loadCacheInfo() async {
    final List<File> files = await _cacheFiles();
    final int size = files.fold<int>(
      0,
      (int sum, File f) => sum + (f.existsSync() ? f.lengthSync() : 0),
    );
    if (!mounted) {
      return;
    }
    setState(() => _cacheSizeBytes = size);
  }

  Future<void> _loadAppVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() => _appVersion = '${info.version} (${info.buildNumber})');
  }

  static String _formatBytes(int? bytes) {
    if (bytes == null) {
      return '…';
    }
    if (bytes <= 0) {
      return '0 MB';
    }
    final double mb = bytes / (1024 * 1024);
    if (mb < 1) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  Future<void> _onVocalEnhanceChanged(bool value) async {
    setState(() => _vocalEnhance = value);
    await _settingsBox.put('vocalEnhanceEnabled', value);
  }

  void _onRememberSpeedPerTrackChanged(bool value) {
    setState(() => _rememberSpeedPerTrack = value);
    SpeedMemory.enabled = value;
  }

  Future<void> _onHierarchicalFoldersChanged(bool value) async {
    setState(() => _hierarchicalFolders = value);
    await _settingsBox.put('hierarchicalFolders', value);
  }

  Future<void> _confirmClearModels() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text(
          'Delete model files?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'This removes the offline lyrics engine (${_formatBytes(_modelsSizeBytes)}). '
          "You'll need to reinstall the model files before generating lyrics offline again.",
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    for (final Future<String> pathFuture in <Future<String>>[
      _models.encoderPath(),
      _models.decoderPath(),
      _models.tokensPath(),
      _models.vadModelPath(),
    ]) {
      final File file = File(await pathFuture);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    await _loadModelInfo();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Model files deleted')));
  }

  Future<void> _clearCache() async {
    final List<File> files = await _cacheFiles();
    for (final File file in files) {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    await _loadCacheInfo();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming in a future update')),
    );
  }

  void _showPrivacyNote() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text(
          'Privacy',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Lyrics generation runs entirely on your device — nothing about '
          'your library or listening leaves it. Search Online is the only '
          "feature that makes a network request: it sends just the song's "
          'title and artist to LRCLIB to look up existing lyrics. No device '
          'identifiers, analytics, or other data are sent, and nothing in '
          'the app ever opens an external link.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        children: <Widget>[
          const _SectionHeader('General'),
          _SettingsTile(
            title: 'App Language',
            subtitle: 'System default',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
            onTap: () => _showComingSoon('Multiple languages'),
          ),
          const _SectionHeader('Library'),
          _SettingsSwitchTile(
            title: 'Hierarchical folders',
            subtitle:
                'Off by default (flat list of every folder with music). '
                'When on, the Folders tab drills down through the real '
                'nested folder tree instead.',
            value: _hierarchicalFolders,
            onChanged: _onHierarchicalFoldersChanged,
          ),
          const _SectionHeader('Playback'),
          _SettingsSwitchTile(
            title: 'Remember speed per track',
            subtitle: 'Each song reopens at its last ratio',
            value: _rememberSpeedPerTrack,
            onChanged: _onRememberSpeedPerTrackChanged,
          ),
          BlocBuilder<MusicControllerBloc, MusicControllerState>(
            builder: (BuildContext context, MusicControllerState state) {
              final MusicControllerBloc musicBloc = context
                  .read<MusicControllerBloc>();
              final int crossfadeMs = musicBloc.stateData.crossfadeMs;
              return _SettingsTile(
                title: 'Crossfade',
                subtitle: crossfadeMs <= 0
                    ? 'Off'
                    : '${(crossfadeMs / 1000).toStringAsFixed(1)}s between tracks',
                trailing: SizedBox(
                  width: 140.w,
                  child: SliderTheme(
                    data: appSliderTheme(),
                    child: Slider(
                      max: 12000,
                      divisions: 24,
                      value: crossfadeMs.toDouble().clamp(0, 12000),
                      onChanged: (double value) =>
                          musicBloc.add(CrossfadeChanged(value.round())),
                    ),
                  ),
                ),
              );
            },
          ),
          BlocBuilder<MusicControllerBloc, MusicControllerState>(
            builder: (BuildContext context, MusicControllerState state) {
              final MusicControllerBloc musicBloc = context
                  .read<MusicControllerBloc>();
              return _SettingsSwitchTile(
                title: 'Resume on Bluetooth connect',
                subtitle:
                    'Off by default - unplugging/replugging wired '
                    'headphones always resumes; a Bluetooth device only '
                    'resumes playback when this is on.',
                value: musicBloc.stateData.resumeOnBluetoothEnabled,
                onChanged: (bool value) =>
                    musicBloc.add(ResumeOnBluetoothChanged(value)),
              );
            },
          ),
          BlocBuilder<MusicControllerBloc, MusicControllerState>(
            builder: (BuildContext context, MusicControllerState state) {
              final MusicControllerBloc musicBloc = context
                  .read<MusicControllerBloc>();
              return _SettingsSwitchTile(
                title: 'Rewind/fast-forward in notification',
                subtitle:
                    'Off by default - shows previous/next track buttons. '
                    'When on, shows rewind/fast-forward within the current '
                    'track instead.',
                value: musicBloc.stateData.seekButtonsEnabled,
                onChanged: (bool value) =>
                    musicBloc.add(SeekButtonsChanged(value)),
              );
            },
          ),
          BlocBuilder<MusicControllerBloc, MusicControllerState>(
            builder: (BuildContext context, MusicControllerState state) {
              final String bucket = context
                  .read<MusicControllerBloc>()
                  .stateData
                  .outputBucket;
              final String label = switch (bucket) {
                'wired' => 'Wired headphones',
                'bluetooth' => 'Bluetooth',
                _ => 'Speaker',
              };
              return _SettingsTile(
                title: 'Equalizer output profile',
                subtitle:
                    'Currently: $label - EQ/bass/reverb are remembered '
                    'separately per output and switch automatically.',
              );
            },
          ),
          const _SectionHeader('Audio Quality'),
          BlocBuilder<MusicControllerBloc, MusicControllerState>(
            builder: (BuildContext context, MusicControllerState state) {
              final MusicControllerBloc musicBloc = context
                  .read<MusicControllerBloc>();
              final int preampMb = musicBloc.stateData.preampMb;
              return _SettingsTile(
                title: 'Preamp',
                subtitle:
                    '${preampMb >= 0 ? '+' : ''}${(preampMb / 100).toStringAsFixed(1)} dB '
                    'added to every equalizer band',
                trailing: SizedBox(
                  width: 140.w,
                  child: SliderTheme(
                    data: appSliderTheme(),
                    child: Slider(
                      min: -1200,
                      max: 1200,
                      divisions: 24,
                      value: preampMb.toDouble().clamp(-1200, 1200),
                      onChanged: (double value) =>
                          musicBloc.add(PreampChanged(value.round())),
                    ),
                  ),
                ),
              );
            },
          ),
          BlocBuilder<MusicControllerBloc, MusicControllerState>(
            builder: (BuildContext context, MusicControllerState state) {
              final MusicControllerBloc musicBloc = context
                  .read<MusicControllerBloc>();
              return _SettingsSwitchTile(
                title: 'Mono audio',
                subtitle:
                    'Plays the full mix through both channels equally - '
                    'useful with one earbud or a single-speaker dock. '
                    'Briefly interrupts playback when toggled.',
                value: musicBloc.stateData.monoEnabled,
                onChanged: (bool value) => musicBloc.add(MonoChanged(value)),
              );
            },
          ),
          BlocBuilder<MusicControllerBloc, MusicControllerState>(
            builder: (BuildContext context, MusicControllerState state) {
              final MusicControllerBloc musicBloc = context
                  .read<MusicControllerBloc>();
              return _SettingsSwitchTile(
                title: 'Hi-Res output mode',
                subtitle:
                    'Requests float PCM output and turns off EQ/bass/virtualizer/reverb '
                    '(they would recolor a bit-perfect signal). Actual direct-output '
                    'support is device- and file-dependent - see the row below.',
                value: musicBloc.stateData.hiResEnabled,
                onChanged: (bool value) => musicBloc.add(HiResChanged(value)),
              );
            },
          ),
          const _FormatInfoTile(),
          const _SectionHeader('Lyrics'),
          _SettingsSwitchTile(
            title: 'Vocal enhancement',
            subtitle:
                'Boosts vocal frequencies before offline transcription, for '
                'slightly better accuracy on lofi/echoey recordings.',
            value: _vocalEnhance,
            onChanged: _onVocalEnhanceChanged,
          ),
          _SettingsTile(
            title: 'Offline model files',
            subtitle: _modelsReady == null
                ? 'Checking…'
                : _modelsReady!
                ? 'Installed • ${_formatBytes(_modelsSizeBytes)}'
                : 'Not installed',
            trailing: (_modelsReady ?? false)
                ? TextButton(
                    onPressed: _confirmClearModels,
                    child: const Text('Delete'),
                  )
                : null,
          ),
          _SettingsTile(
            title: 'Clear generation cache',
            subtitle:
                'Temporary audio files created while generating lyrics '
                '(${_formatBytes(_cacheSizeBytes)})',
            trailing: TextButton(
              onPressed: _clearCache,
              child: const Text('Clear'),
            ),
          ),
          const _SectionHeader('About'),
          _SettingsTile(title: 'Version', subtitle: _appVersion ?? '…'),
          _SettingsTile(
            title: 'Open source licenses',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Slune',
              applicationVersion: _appVersion,
            ),
          ),
          _SettingsTile(
            title: 'Privacy',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
            onTap: _showPrivacyNote,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 24.h, 18.w, 8.h),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 18.w),
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                subtitle!,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
      trailing: trailing,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.accent,
        inactiveThumbColor: AppColors.textTertiary,
        inactiveTrackColor: AppColors.surfaceHigh,
        onChanged: onChanged,
      ),
      onTap: () => onChanged(!value),
    );
  }
}

/// Shows the currently-playing track's real format (sample rate/bit depth/
/// codec/bitrate) and the honest direct-output status for it on this
/// device - re-queried whenever the current song changes.
class _FormatInfoTile extends StatefulWidget {
  const _FormatInfoTile();

  @override
  State<_FormatInfoTile> createState() => _FormatInfoTileState();
}

class _FormatInfoTileState extends State<_FormatInfoTile> {
  int? _songIdForInfo;
  Map<String, dynamic>? _formatInfo;
  String? _hiResSupport;

  Future<void> _load(String sourcePath, int songId) async {
    final Map<String, dynamic> info = await PlayerClient.instance.getFormatInfo(
      sourcePath,
    );
    final String support = await PlayerClient.instance.getHiResSupport(
      sourcePath,
    );
    if (!mounted || _songIdForInfo != songId) {
      return;
    }
    setState(() {
      _formatInfo = info;
      _hiResSupport = support;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicControllerBloc, MusicControllerState>(
      builder: (BuildContext context, MusicControllerState state) {
        final SongModel? song = context
            .read<MusicControllerBloc>()
            .stateData
            .song;
        if (song == null) {
          return const _SettingsTile(
            title: 'Playing track format',
            subtitle: 'No song is currently playing',
          );
        }

        final int songId = song.id;
        final String sourcePath = song.data;
        if (_songIdForInfo != songId) {
          _songIdForInfo = songId;
          _formatInfo = null;
          _hiResSupport = null;
          _load(sourcePath, songId);
        }

        final Map<String, dynamic>? info = _formatInfo;
        if (info == null) {
          return const _SettingsTile(
            title: 'Playing track format',
            subtitle: 'Checking…',
          );
        }

        final int? sampleRate = info['sampleRateHz'] as int?;
        final int? bitDepth = info['bitDepth'] as int?;
        final int? bitrate = info['bitrateBps'] as int?;
        final String mime = (info['mimeType'] as String? ?? '')
            .replaceFirst('audio/', '')
            .toUpperCase();

        final List<String> parts = <String>[
          if (mime.isNotEmpty) mime,
          if (sampleRate != null)
            '${(sampleRate / 1000).toStringAsFixed(1)} kHz',
          if (bitDepth != null) '$bitDepth-bit' else 'lossy',
          if (bitrate != null) '${(bitrate / 1000).round()} kbps',
        ];

        final String directLabel = switch (_hiResSupport) {
          'direct' => 'Direct output active for this file',
          'mixed' => 'Falls back to the shared mixer on this device',
          _ => 'Direct-output status unknown',
        };

        return _SettingsTile(
          title: 'Playing track format',
          subtitle: '${parts.join(' · ')}\n$directLabel',
        );
      },
    );
  }
}
