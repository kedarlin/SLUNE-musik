import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_slider_theme.dart';
import '../common/sheet_shell.dart';

const double _speedMin = 0.25;
const double _speedMax = 2.0;
const List<double> _presets = <double>[0.5, 0.85, 1.0, 1.15, 1.25];

/// Lets a playlist "carry its speed as part of its identity" (1e) - pin a
/// fixed speed that's applied whenever that playlist is played.
///
/// Return value: null means cancelled (dismissed/back - leave the existing
/// pin untouched); [unpinSentinel] means "explicitly clear the pin"; any
/// other value is the speed to pin.
class PlaylistSpeedSheet extends StatefulWidget {
  const PlaylistSpeedSheet({required this.initialSpeed, super.key});

  final double? initialSpeed;

  /// Sentinel returned by [show] to mean "explicitly clear the pin" -
  /// distinct from null (cancelled, no change). Not a valid real speed.
  static const double unpinSentinel = -1.0;

  static Future<double?> show(BuildContext context, double? initialSpeed) {
    return showModalBottomSheet<double?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) =>
          PlaylistSpeedSheet(initialSpeed: initialSpeed),
    );
  }

  @override
  State<PlaylistSpeedSheet> createState() => _PlaylistSpeedSheetState();
}

class _PlaylistSpeedSheetState extends State<PlaylistSpeedSheet> {
  late double _speed = widget.initialSpeed ?? 1.0;

  @override
  Widget build(BuildContext context) {
    final bool pinned = widget.initialSpeed != null;

    return SheetShell(
      showDivider: false,
      header: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Pin playlist speed',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'Every track in this playlist plays at this ratio',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${_speed.toStringAsFixed(2)}×',
              style: TextStyle(
                fontSize: 34.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
            SliderTheme(
              data: appSliderTheme(inactiveColor: AppColors.surfaceHigh),
              child: Slider(
                min: _speedMin,
                max: _speedMax,
                value: _speed.clamp(_speedMin, _speedMax),
                onChanged: (double value) => setState(() => _speed = value),
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: <Widget>[
                for (final double preset in _presets) ...<Widget>[
                  Expanded(
                    child: _PresetChip(
                      label: '${preset.toStringAsFixed(2)}×',
                      selected: (_speed - preset).abs() < 0.005,
                      onTap: () => setState(() => _speed = preset),
                    ),
                  ),
                  if (preset != _presets.last) SizedBox(width: 6.w),
                ],
              ],
            ),
            SizedBox(height: 20.h),
            Row(
              children: <Widget>[
                if (pinned) ...<Widget>[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(0, 46.h),
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13.r),
                        ),
                      ),
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(PlaylistSpeedSheet.unpinSentinel),
                      child: Text(
                        'Unpin',
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                ],
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(0, 46.h),
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13.r),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(_speed),
                    child: Text(
                      pinned ? 'Update pin' : 'Pin · ${_speed.toStringAsFixed(2)}×',
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
          ],
        ),
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
        height: 32.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.16)
              : AppColors.surfaceHigh,
          border: selected ? Border.all(color: AppColors.accent) : null,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
