import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../bloc/music_controller/music_controller_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_slider_theme.dart';
import '../../service/speed_pitch_presets.dart';

const double _speedMin = 0.25;
const double _speedMax = 2.0;
const double _pitchMinSt = -6.0;
const double _pitchMaxSt = 6.0;
const List<double> _speedPresets = <double>[0.5, 0.85, 1.0, 1.25];

double ratioToSemitones(double ratio) => 12 * (math.log(ratio) / math.ln2);
double semitonesToRatio(double st) => math.pow(2, st / 12).toDouble();

class SpeedPitchSheet extends StatefulWidget {
  const SpeedPitchSheet({required this.musicBloc, super.key});

  final MusicControllerBloc musicBloc;

  static void show(BuildContext context, MusicControllerBloc musicBloc) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) =>
          SpeedPitchSheet(musicBloc: musicBloc),
    );
  }

  @override
  State<SpeedPitchSheet> createState() => _SpeedPitchSheetState();
}

class _SpeedPitchSheetState extends State<SpeedPitchSheet> {
  bool _linkPitchToSpeed = false;

  void _setSpeed(double speed) {
    widget.musicBloc.add(SpeedChanged(speed));
    if (_linkPitchToSpeed) {
      widget.musicBloc.add(PitchChanged(speed));
    }
  }

  void _setPitchSemitones(double st) {
    widget.musicBloc.add(PitchChanged(semitonesToRatio(st)));
  }

  Future<void> _saveAsPreset(double speed, double pitch) async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Text(
            'Save as preset',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 24,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
            decoration: const InputDecoration(hintText: 'Preset name'),
            onSubmitted: (String value) =>
                Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) {
      return;
    }
    setState(() => SpeedPitchPresets.save(name, speed, pitch));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicControllerBloc, MusicControllerState>(
      bloc: widget.musicBloc,
      builder: (BuildContext context, MusicControllerState state) {
        final double speed = widget.musicBloc.stateData.speed.clamp(
          _speedMin,
          _speedMax,
        );
        final double pitchSt = ratioToSemitones(
          widget.musicBloc.stateData.pitch,
        ).clamp(_pitchMinSt, _pitchMaxSt);

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            border: const Border(top: BorderSide(color: AppColors.divider)),
          ),
          padding: EdgeInsets.only(top: 10.h, bottom: 24.h),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: AppColors.disabled,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Speed & pitch',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          widget.musicBloc.add(SpeedChanged(1.0));
                          widget.musicBloc.add(PitchChanged(1.0));
                        },
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _GroupLabel('SPEED'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            '${speed.toStringAsFixed(2)}×',
                            style: TextStyle(
                              fontSize: 34.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: appSliderTheme(
                          inactiveColor: AppColors.surfaceHigh,
                        ),
                        child: Slider(
                          min: _speedMin,
                          max: _speedMax,
                          value: speed,
                          onChanged: _setSpeed,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          _EdgeLabel('${_speedMin.toStringAsFixed(2)}×'),
                          const _EdgeLabel('1.0×'),
                          _EdgeLabel('${_speedMax.toStringAsFixed(1)}×'),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: <Widget>[
                          for (final double preset in _speedPresets) ...<Widget>[
                            Expanded(
                              child: _PresetChip(
                                label: '${preset.toStringAsFixed(2)}×',
                                selected: (speed - preset).abs() < 0.005,
                                onTap: () => _setSpeed(preset),
                              ),
                            ),
                            if (preset != _speedPresets.last)
                              SizedBox(width: 8.w),
                          ],
                        ],
                      ),
                      if (SpeedPitchPresets.all.isNotEmpty) ...<Widget>[
                        SizedBox(height: 14.h),
                        const _GroupLabel('YOUR PRESETS'),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: <Widget>[
                            for (final SpeedPitchPreset preset
                                in SpeedPitchPresets.all)
                              GestureDetector(
                                onLongPress: () => setState(
                                  () => SpeedPitchPresets.delete(preset.name),
                                ),
                                child: _PresetChip(
                                  label: preset.name,
                                  selected:
                                      (speed - preset.speed).abs() < 0.005 &&
                                      (ratioToSemitones(
                                                widget.musicBloc.stateData
                                                    .pitch,
                                              ) -
                                              ratioToSemitones(preset.pitch))
                                          .abs() <
                                          0.05,
                                  onTap: () {
                                    _setSpeed(preset.speed);
                                    widget.musicBloc.add(
                                      PitchChanged(preset.pitch),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: Divider(
                    color: AppColors.divider,
                    height: 1.h,
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _GroupLabel('PITCH'),
                      Text(
                        '${pitchSt >= 0 ? '+' : ''}${pitchSt.round()} st',
                        style: TextStyle(
                          fontSize: 34.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      SliderTheme(
                        data: appSliderTheme(
                          inactiveColor: AppColors.surfaceHigh,
                        ),
                        child: Slider(
                          min: _pitchMinSt,
                          max: _pitchMaxSt,
                          value: pitchSt,
                          onChanged: _linkPitchToSpeed
                              ? null
                              : _setPitchSemitones,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          _EdgeLabel('${_pitchMinSt.round()} st'),
                          const _EdgeLabel('0'),
                          _EdgeLabel('+${_pitchMaxSt.round()} st'),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Link pitch to speed',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Classic tape slowdown',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _linkPitchToSpeed,
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppColors.accent,
                        inactiveThumbColor: AppColors.textTertiary,
                        inactiveTrackColor: AppColors.surfaceHigh,
                        onChanged: (bool value) {
                          setState(() => _linkPitchToSpeed = value);
                          if (value) {
                            _setPitchSemitones(ratioToSemitones(speed));
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(0, 48.h),
                            side: const BorderSide(color: AppColors.divider),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13.r),
                            ),
                          ),
                          onPressed: () => _saveAsPreset(
                            speed,
                            widget.musicBloc.stateData.pitch,
                          ),
                          child: Text(
                            'Save as preset',
                            style: TextStyle(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(0, 48.h),
                            backgroundColor: AppColors.accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13.r),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Apply',
                            style: TextStyle(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _EdgeLabel extends StatelessWidget {
  const _EdgeLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.disabled,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10.r),
      onTap: onTap,
      child: Container(
        height: 34.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.16)
              : AppColors.surfaceHigh,
          border: selected
              ? Border.all(color: AppColors.accent)
              : null,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
