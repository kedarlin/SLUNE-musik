import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../bloc/music_controller/music_controller_bloc.dart';
import '../core/app_constants/app_enums.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_slider_theme.dart';
import '../service/player_client.dart';
import '../widgets/common/sheet_shell.dart';

class EqualizerSheet extends StatefulWidget {
  const EqualizerSheet({required this.musicBloc, super.key});

  final MusicControllerBloc musicBloc;

  @override
  State<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<EqualizerSheet> {
  AudioFxCaps? _caps;
  bool _loading = true;

  late bool _eqEnabled;
  late int _eqPreset;
  late List<int> _bands;
  late int _bassBoost;
  late int _virtualizer;
  late ReverbPreset _reverb;

  MusicControllerStateData get _data => widget.musicBloc.stateData;

  @override
  void initState() {
    super.initState();
    _eqEnabled = _data.eqEnabled;
    _eqPreset = _data.eqPreset;
    _bands = List<int>.from(_data.eqBands);
    _bassBoost = _data.bassBoost;
    _virtualizer = _data.virtualizer;
    _reverb = _data.reverbPreset;
    _loadCaps();
  }

  Future<void> _loadCaps() async {
    for (int attempt = 0; attempt < 6; attempt++) {
      final AudioFxCaps? caps = await PlayerClient.instance.getFxCaps();
      if (!mounted) {
        return;
      }
      if (caps != null) {
        setState(() {
          _caps = caps;
          _loading = false;
          if (caps.bandCount > 0 && _bands.length != caps.bandCount) {
            final List<int> sized = List<int>.filled(caps.bandCount, 0);
            for (int i = 0; i < caps.bandCount && i < _bands.length; i++) {
              sized[i] = _bands[i];
            }
            _bands = sized;
          }
        });
        widget.musicBloc.add(EqBandsInitialized(caps.bandCount));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool eqAvailable = _caps?.eqAvailable ?? false;

    return _loading
        ? Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Padding(
              padding: EdgeInsets.all(20.h),
              child: SizedBox(
                height: 200.h,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          )
        : SheetShell(
            header: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: <Widget>[
                  Text(
                    'Equalizer',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    padding: EdgeInsets.zero,
                    value: _eqEnabled && eqAvailable,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.accent,
                    inactiveThumbColor: AppColors.textTertiary,
                    inactiveTrackColor: AppColors.surfaceHigh,
                    onChanged: eqAvailable
                        ? (bool v) {
                            setState(() => _eqEnabled = v);
                            widget.musicBloc.add(EqEnabledChanged(v));
                          }
                        : null,
                  ),
                ],
              ),
            ),
            body: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                    Expanded(
                      child: ListView(
                        children: <Widget>[
                          _buildEqSection(),
                          SizedBox(height: 16.h),
                          _buildReverbRow(),
                          SizedBox(height: 20.h),
                          _buildStrengthRow(
                            label: 'Bass Boost',
                            available: _caps?.bassBoostAvailable ?? false,
                            value: _bassBoost,
                            onChanged: (int v) =>
                                setState(() => _bassBoost = v),
                            onChangeEnd: (int v) =>
                                widget.musicBloc.add(BassBoostChanged(v)),
                          ),
                          SizedBox(height: 16.h),
                          _buildStrengthRow(
                            label: 'Virtualizer',
                            available: _caps?.virtualizerAvailable ?? false,
                            value: _virtualizer,
                            onChanged: (int v) =>
                                setState(() => _virtualizer = v),
                            onChangeEnd: (int v) =>
                                widget.musicBloc.add(VirtualizerChanged(v)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
  }

  Widget _buildEqSection() {
    final bool eqAvailable = _caps?.eqAvailable ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!eqAvailable)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Text(
              'The equalizer is not available on this device.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
            ),
          )
        else
          IgnorePointer(
            ignoring: !_eqEnabled,
            child: AnimatedOpacity(
              opacity: _eqEnabled ? 1.0 : 0.35,
              duration: const Duration(milliseconds: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(height: 14.h),
                  _buildPresetChips(),
                  SizedBox(height: 16.h),
                  _buildBands(),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPresetChips() {
    final List<String> presets = _caps?.presetNames ?? <String>[];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _presetChip(
            'Custom',
            selected: _eqPreset < 0,
            onTap: () {
              final List<int> custom = _data.customEqBands.isNotEmpty
                  ? List<int>.from(_data.customEqBands)
                  : List<int>.from(_bands);
              setState(() {
                _eqPreset = -1;
                _bands = custom;
              });
              for (int b = 0; b < custom.length; b++) {
                widget.musicBloc.add(EqBandChanged(b, custom[b]));
              }
            },
          ),
          for (int i = 0; i < presets.length; i++)
            _presetChip(
              presets[i],
              selected: _eqPreset == i,
              onTap: () async {
                final List<int> curve = await PlayerClient.instance.setEqPreset(
                  i,
                );
                if (!mounted) {
                  return;
                }
                setState(() {
                  _eqPreset = i;
                  if (curve.isNotEmpty) {
                    _bands = curve;
                  }
                });
                widget.musicBloc.add(EqPresetSelected(i, curve));
              },
            ),
        ],
      ),
    );
  }

  Widget _presetChip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: Container(
          height: 32.h,
          padding: EdgeInsets.symmetric(horizontal: 13.w),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.16)
                : AppColors.surfaceHigh,
            border: selected ? Border.all(color: AppColors.accent) : null,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.accent : AppColors.textSecondary,
              fontSize: 12.sp,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBands() {
    final AudioFxCaps caps = _caps!;
    final double minMb = caps.minLevelMb.toDouble();
    final double maxMb = caps.maxLevelMb.toDouble();

    return SizedBox(
      height: 200.h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List<Widget>.generate(caps.bandCount, (int band) {
          final int levelMb = band < _bands.length ? _bands[band] : 0;
          final double clamped = levelMb.toDouble().clamp(minMb, maxMb);

          final int db = (levelMb / 100).round();

          return Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  db > 0 ? '+$db' : '$db',
                  style: TextStyle(
                    color: db > 0
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: appSliderTheme(),
                      child: Slider(
                        min: minMb,
                        max: maxMb,
                        value: clamped,
                        onChanged: (double v) {
                          setState(() {
                            if (_bands.length <= band) {
                              _bands = <int>[
                                ..._bands,
                                ...List<int>.filled(
                                  band + 1 - _bands.length,
                                  0,
                                ),
                              ];
                            }
                            _bands[band] = v.round();
                            _eqPreset = -1;
                          });
                        },
                        onChangeEnd: (double v) => widget.musicBloc.add(
                          EqBandChanged(band, v.round()),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  _formatFreq(
                    band < caps.centerFreqsHz.length
                        ? caps.centerFreqsHz[band]
                        : 0,
                  ),
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10.5.sp,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _formatFreq(int hz) {
    if (hz >= 1000) {
      final double k = hz / 1000;
      return k == k.roundToDouble()
          ? '${k.round()} kHz'
          : '${k.toStringAsFixed(1)} kHz';
    }
    return '$hz Hz';
  }

  Widget _buildReverbRow() {
    final bool available = _caps?.reverbAvailable ?? false;

    return Row(
      children: <Widget>[
        Text(
          'Reverb',
          style: TextStyle(
            color: available ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (!available)
          Text(
            'Unavailable',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12.sp),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final ReverbPreset preset in ReverbPreset.values) ...<Widget>[
                _reverbChip(preset),
                if (preset != ReverbPreset.values.last) SizedBox(width: 6.w),
              ],
            ],
          ),
      ],
    );
  }

  Widget _reverbChip(ReverbPreset preset) {
    final bool selected = preset == _reverb;

    return InkWell(
      borderRadius: BorderRadius.circular(15.r),
      onTap: () {
        setState(() => _reverb = preset);
        widget.musicBloc.add(ReverbPresetChanged(preset));
      },
      child: Container(
        height: 30.h,
        padding: EdgeInsets.symmetric(horizontal: 11.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.16)
              : AppColors.surfaceHigh,
          border: selected ? Border.all(color: AppColors.accent) : null,
          borderRadius: BorderRadius.circular(15.r),
        ),
        child: Text(
          preset.label,
          style: TextStyle(
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontSize: 11.5.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthRow({
    required String label,
    required bool available,
    required int value,
    required ValueChanged<int> onChanged,
    required ValueChanged<int> onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: available
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(value / 10).round()}%',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3.h,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.r),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 14.r),
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.surfaceHigh,
            thumbColor: Colors.white,
          ),
          child: Slider(
            max: 1000,
            value: value.toDouble().clamp(0, 1000),
            onChanged: available ? (double v) => onChanged(v.round()) : null,
            onChangeEnd: available
                ? (double v) => onChangeEnd(v.round())
                : null,
          ),
        ),
      ],
    );
  }
}
